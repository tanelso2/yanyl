import
    sequtils,
    streams,
    strformat,
    strutils,
    sugar,
    tables,
    yaml,
    yaml/dom

type
  YNodeKind* = enum
    ynString, ynList, ynMap, ynNil
  YNode* = object
    case kind*: YNodeKind
    of ynNil:
      discard
    of ynString:
      strVal*: string
    of ynList:
      listVal*: seq[YNode]
    of ynMap:
      mapVal*: TableRef[string, YNode]

proc newYList*(elems: seq[YNode]): YNode =
    YNode(kind:ynList, listVal: elems)

proc newYMap*(t: TableRef[string,YNode]): YNode =
    YNode(kind: ynMap, mapVal: t)

proc newYMap*(a: openArray[(string,YNode)]): YNode =
    a.newTable().newYMap()

proc newYString*(s: string): YNode =
    YNode(kind: ynString, strVal: s)

proc newYList*(elems: seq[string]): YNode =
    YNode(kind:ynList, listVal: elems.map(newYString))

proc newYNil*(): YNode =
  YNode(kind: ynNil)

template expectYString*(n, body: untyped) =
    case n.kind
    of ynString:
        body
    else:
        raise newException(ValueError, "expected string YNode")

template expectYList*(n, body: untyped) =
    case n.kind
    of ynList:
        body
    else:
        raise newException(ValueError, "expected list YNode")

template expectYMap*(n, body: untyped) =
    case n.kind
    of ynMap:
        body
    else:
        raise newException(ValueError, "expected map YNode")

# HACKY AND I DON'T LIKE IT
# Added because the compiler was unable to find ofYaml[T]
# when evaluating ofYaml[seq[T]] 
proc ofYaml*[T](n: YNode, t: typedesc[T]): T =
    raise newException(ValueError, fmt"No implementation of ofYaml for type {$t}")

proc toYaml*(s: string): YNode =
    newYString(s)

proc toYaml*(i: int): YNode =
    newYString($i)

proc toYaml*(f: float): YNode =
    newYString($f)

proc toYaml*(b: bool): YNode =
    newYString($b)

proc toYaml*[T](l: seq[T]): YNode =
    let elems = collect:
        for x in l:
            toYaml(x)
    return elems.newYList()

proc toYaml*[T](o: Option[T]): YNode =
  if o.isSome():
    toYaml(o.get())
  else:
    newYNil()

proc toYaml*[T](t: Table[string, T]): YNode =
  let m = collect:
    for k,v in t.pairs:
      (k, toYaml(v))
  newYMap(m.newTable())

proc toYaml*[T](t: TableRef[string, T]): YNode =
  let m = collect:
    for k,v in t.pairs:
      (k, toYaml(v))
  newYMap(m.newTable())

proc get*(n: YNode, k: string): YNode =
    ## Get the map value associated with `k`
    ## Throws if `n` is not a map
    expectYMap n:
        result = n.mapVal[k]

proc elems*(n: YNode): seq[YNode] =
    expectYList n:
        result = n.listVal

proc str*(n: YNode): string =
    expectYString n:
        result = n.strVal

proc getStr*(n: YNode, k: string): string =
    expectYMap n:
        n.get(k).str()

proc toInt*(n: YNode): int =
    expectYString n:
        result = parseInt(n.strVal)

proc toFloat*(n: YNode): float =
    expectYString n:
        result = parseFloat(n.strVal)

proc ofYaml*[T](n: YNode, t: typedesc[seq[T]]): seq[T] =
    expectYList n:
        result = collect:
            for x in n.elems():
                ofYaml(x, T)

proc ofYaml*[T](n: YNode, t: typedesc[Option[T]]): Option[T] =
  case n.kind
  of ynNil:
    return none(T)
  else:
    return some(ofYaml(n, T))

proc ofYaml*(n: YNode, t: typedesc[int]): int =
    n.toInt()

proc ofYaml*(n: YNode, t: typedesc[float]): float =
    n.toFloat()

proc ofYaml*(n: YNode, t: typedesc[string]): string =
    n.str()

proc ofYaml*(n: YNode, t: typedesc[bool]): bool =
    parseBool(n.str())

proc ofYaml*[T](n: YNode, t: typedesc[Table[string, T]]): Table[string, T] =
  expectYMap n:
    let m = collect:
      for k,v in n.mapVal.pairs:
        {k: ofYaml(v, T)}
    return m

proc ofYaml*[T](n: YNode, t: typedesc[TableRef[string, T]]): TableRef[string, T] =
  expectYMap n:
    let m = collect:
      for k,v in n.mapVal.pairs:
        (k, ofYaml(v, T))
    return m.newTable()

proc get*[T](n: YNode, k: string, t: typedesc[T]): T =
  expectYMap n:
    result = n.get(k).ofYaml(t)

proc get*[T](n: YNode, k: string, t: typedesc[Option[T]]): Option[T] =
  expectYMap n:
    let m = n.mapVal
    if k in m:
      some(ofYaml(m[k], T))
    else:
      none(T)


proc simplifyName(k: YamlNode): string =
  case k.kind
  of yScalar:
    return k.content
  else:
    raise newException(ValueError, "Cannot simplify the name of a non-scalar")

proc translate(n: YamlNode): YNode =
  case n.kind
  of yMapping:
    let t = newTable[string,YNode](n.fields.len)
    for k,v in n.fields.pairs:
      let name = simplifyName(k)
      t[name] = translate(v)
    result = newYMap(t)
  of ySequence:
    let elems = n.elems.mapIt(translate(it))
    result = newYList(elems)
  else:
    let content = n.content
    if content == "null":
      result = newYNil()
    else:
      result = newYString(n.content)

proc loadNode*(s: string | Stream): YNode =
    ## Load a YNode from a YAML string or stream
    var node: YamlNode
    load(s,node)
    return translate(node)

proc newline(i: int): string =
    "\n" & repeat(' ', i)

proc needsMultipleLines(n: YNode): bool =
  case n.kind
  of ynNil, ynString:
    false
  of ynList:
    len(n.listVal) > 0
  of ynMap:
    len(n.mapVal) > 0

proc toString*(n: YNode, indentLevel=0): string =
    ## Convert a YNode to a YAML string

    proc newline(): string =
        newline(indentLevel)

    case n.kind
    of ynString:
        let s = n.strVal
        if len(s) > 0:
            return s
        else:
            return "\"\""
    of ynMap:
        let fields = n.mapVal
        let s = collect:
            for k,v in fields.pairs:
              if needsMultipleLines v:
                let newIndent = indentLevel+2
                let vstr = v.toString(indentLevel=newIndent)
                fmt"{k}:{newline(newIndent)}{vstr}"
              else:
                let newIndent = indentLevel + len(k) + 2
                let vstr = v.toString(indentLevel=newIndent)
                fmt"{k}: {vstr}"
        case len(s)
        of 0:
            return "{}"
        else:
            return s.join(newline())
    of ynNil:
      return "null" 
    of ynList:
        let elems = n.listVal
        case len(elems)
        of 0: 
            return "[]"
        else:
            return elems
                .mapIt(toString(it,indentLevel=indentLevel+2))
                .mapIt("- $1" % it)
                .join(newline())
    

proc `==`*(a: YNode, b: YNode): bool =
    ## Compare two yaml documents for equality 
    if a.kind != b.kind:
        return false
    else:
        case a.kind
        of ynNil:
          # Two nil vals equal each other
          return true
        of ynString:
            return a.strVal == b.strVal
        of ynList:
            let la = a.elems()
            let lb = b.elems()
            return la == lb
        of ynMap:
            let ma = a.mapVal
            let mb = b.mapVal
            return ma == mb

proc ofYamlStr*[T](s: string, t:typedesc[T]): T =
    s.loadNode().ofYaml(t)

proc toYamlStr*[T](x: T): string =
    x.toYaml().toString()
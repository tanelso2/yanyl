import
    fusion/matching,
    options,
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
  runnableExamples:
    let list = @[newYNil(), newYNil()]
    let node = newYList(list)
    doAssert node.kind == ynList
    doAssert node.listVal.len == 2

  YNode(kind:ynList, listVal: elems)

proc newYMap*(t: TableRef[string,YNode]): YNode =
    YNode(kind: ynMap, mapVal: t)

proc newYMap*(a: openArray[(string,YNode)]): YNode =
    a.newTable().newYMap()

proc newYMapRemoveNils*(a: openArray[(string, YNode)]): YNode =
  runnableExamples:
    import std/tables
    let node = newYMapRemoveNils(
                [("a", newYString("astring")), 
                 ("b", newYNil())])
    doAssert node.kind == ynMap
    doAssert node.mapVal.len == 1

  let t = collect:
    for (k,v) in a.items:
      if v.kind != ynNil:
        (k, v)
  return t.newTable().newYMap()

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

proc toYaml*(s: string): YNode =
    newYString(s)

proc toYaml*(i: int): YNode =
    newYString($i)

proc toYaml*(f: float): YNode =
    newYString($f)

proc toYaml*(b: bool): YNode =
    newYString($b)

proc toYaml*(c: char): YNode =
  newYString($c)

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
  ## 
  ## Throws if `n` is not a map
  runnableExamples:
    let m = newYMap({
      "a": newYString("astring")
    })
    let a = m.get("a")
    doAssert a.kind == ynString
    doAssert a.strVal == "astring"

  expectYMap n:
      result = n.mapVal[k]

proc elems*(n: YNode): seq[YNode] =
  ## Get the list value of the node
  ## 
  ## Throws if `n` is not a list
  runnableExamples:
    let l = newYList(@[newYNil(),
                       newYString("abc")])
    let items = l.elems()
    doAssert len(items) == 2
    doAssert items[0].kind == ynNil
    doAssert items[1].strVal == "abc"

  expectYList n:
      result = n.listVal

proc str*(n: YNode): string =
  ## Get the string value of the node
  ## 
  ## Throws if `n` is not a string
  runnableExamples:
    let s = newYString("abc")
    doAssert s.str() == "abc"

  expectYString n:
      result = n.strVal

proc getStr*(n: YNode, k: string): string =
    expectYMap n:
        n.get(k).str()

proc toInt*(n: YNode): int =
  ## Get the int value of the node
  ## 
  ## Throws if `n` is not a string
  runnableExamples:
    let n = newYString("123")
    doAssert n.toInt() == 123

  expectYString n:
      result = parseInt(n.strVal)

proc toFloat*(n: YNode): float =
  ## Get the float value of the node
  ## 
  ## Throws if `n` is not a string
  runnableExamples:
    let n = newYString("3.14")
    doAssert n.toFloat() == 3.14 

  expectYString n:
      result = parseFloat(n.strVal)

proc toChar*(n: YNode): char =
  ## Get the char value of the node
  ## 
  ## Throws if `n` is not a string
  runnableExamples:
    let n = newYString("8")
    doAssert n.toChar() == '8'

  expectYString n:
    let s = n.strVal
    if len(s) == 1:
      result = s[0]
    else:
      raise newException(ValueError, "Cannot make a char out of a string than isn't length 1")

proc ofYaml*[T](n: YNode, t: typedesc[seq[T]]): seq[T] =
  runnableExamples:
    let l = newYList(@[
      newYString("1"),
      newYString("2"),
      newYString("3")
    ])
    let res = ofYaml(l, seq[int])
    doAssert res.len == 3
    doAssert res[0] == 1
    doAssert res[1] == 2
    doAssert res[2] == 3

  mixin ofYaml
  expectYList n:
      result = collect:
          for x in n.elems():
              ofYaml(x, T)

proc ofYaml*[T](n: YNode, t: typedesc[Option[T]]): Option[T] =
  runnableExamples:
    import std/options

    let n1 = newYNil()
    let o1 = ofYaml(n1, Option[string])
    doAssert o1.isNone
    let n2 = newYString("heyo")
    let o2 = ofYaml(n2, Option[string])
    doAssert o2.isSome
    doAssert o2.get() == "heyo"

  case n.kind
  of ynNil:
    return none(T)
  else:
    return some(ofYaml(n, T))

proc ofYaml*(n: YNode, t: typedesc[int]): int =
  runnableExamples:
    let n = newYString("8675309")
    doAssert ofYaml(n, int) == 8675309

  n.toInt()

proc ofYaml*(n: YNode, t: typedesc[float]): float =
  runnableExamples:
    let n = newYString("3.14")
    doAssert ofYaml(n, float) == 3.14

  n.toFloat()

proc ofYaml*(n: YNode, t: typedesc[string]): string =
  runnableExamples:
    let n = newYString("yep")
    doAssert ofYaml(n, string) == "yep"

  n.str()

proc ofYaml*(n: YNode, t: typedesc[char]): char =
  n.toChar()

proc ofYaml*(n: YNode, t: typedesc[bool]): bool =
  runnableExamples:
    doAssert ofYaml(newYString("true"), bool) == true
    doAssert ofYaml(newYString("false"), bool) == false

  parseBool(n.str())

proc ofYaml*[T](n: YNode, t: typedesc[ref T]): ref T =
  ofYaml(n, T)

proc toYaml*[T](x: ref T): YNode =
  toYaml()

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
  runnableExamples:
    let sample = """
      s: x
      i: 3
      f: 0.32
    """
    let n = sample.loadNode()
    doAssert n.kind == ynMap
    doAssert n.get("s", string) == "x"
    doAssert n.get("i", int) == 3
    doAssert n.get("f", float) == 0.32

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
    

proc `==`*(a: YNode, b: YNode): bool {.noSideEffect.} =
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
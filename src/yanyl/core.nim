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
    ynString, ynList, ynMap
  YNode* = object
    case kind*: YNodeKind
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

proc get*(n: YNode, k: string): YNode =
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
    result = newYString(n.content)

proc loadNode*(s: string | Stream): YNode =
    var node: YamlNode
    load(s,node)
    return translate(node)

proc newline(i: int): string =
    "\n" & repeat(' ', i)

proc toString*(n: YNode, indentLevel=0): string =

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
                case v.kind
                of ynString:
                    let newIndent = indentLevel + len(k) + 2
                    let vstr = v.toString(indentLevel=newIndent)
                    fmt"{k}: {vstr}"
                else:
                    let newIndent = indentLevel+2
                    let vstr = v.toString(indentLevel=newIndent)
                    fmt"{k}:{newline(newIndent)}{vstr}"
        case len(s)
        of 0:
            return "{}"
        else:
            return s.join(newline())
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

# HACKY AND I DON'T LIKE IT
# Added because the compiler was unable to find ofYaml[T]
# when evaluating ofYaml[seq[T]] 
proc ofYaml*[T](n: YNode, t: typedesc[T]): T =
    raise newException(ValueError, "No implementation of ofYaml for type")
    

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

proc ofYaml*[T](n: YNode, t: typedesc[seq[T]]): seq[T] =
    expectYList n:
        result = collect:
            for x in n.elems():
                ofYaml(x, T)

proc ofYaml*(n: YNode, t: typedesc[int]): int =
    n.toInt()

proc ofYaml*(n: YNode, t: typedesc[float]): float =
    n.toFloat()

proc ofYaml*(n: YNode, t: typedesc[string]): string =
    n.str()

proc ofYaml*(n: YNode, t: typedesc[bool]): bool =
    parseBool(n.str())

proc `==`*(a: YNode, b: YNode): bool =
    if a.kind != b.kind:
        return false
    else:
        case a.kind
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
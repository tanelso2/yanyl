import
    macros,
    sequtils,
    yanyl,
    yanyl/reflection,
    test_utils/yaml_testing,
    unittest

type
    Simple = object of RootObj
        a: string
    Simple2 = object of RootObj
        a: string

proc ofYaml(n: YNode, t: typedesc[Simple]): Simple =
    assertYMap n
    let a = n.get("a").ofYaml( typeof Simple.a )
    result = Simple(a: a)

proc toYaml(x: Simple): YNode =
    {
        "a": toYaml(x.a)
    }.newYMap()

# macro dumpDefn(v: untyped) =
#     quote do:
#         echo treeRepr(getImpl(`v`))

# template dumpDef(v: typed) = dumpDefn(v)

# dumpDef(ofYaml)
# dumpDef(toYaml)

macro dumpTypeImpl(x: typed) =
    echo newLit(x.getTypeImpl.treeRepr)

# dumpTypeImpl Simple

macro dumpImpl(x: typed) =
    echo newLit(x.getImpl.treeRepr)

dumpImpl Simple

macro dumpTypeKind(x: typed) =
    echo newLit($x.typeKind)

# dumpTypeKind Simple

macro dumpResolvedTypeKind(x: typed) =
    echo newLit($x.getType().typeKind)

# dumpResolvedTypeKind Simple

macro dumpTypeInst(x: typed) = 
    echo newLit(x.getTypeInst().treeRepr)

# dumpTypeInst Simple

expandMacros:
    deriveYaml Simple2

import
    tables

echo string
echo typeof string

dumpTree:
    typeof typedesc[string]
    typeof string

let s = newYString("hello").ofYaml(string)
echo s

let simpleStr = """
a: hello
"""
checkRoundTrip simpleStr

var a = simpleStr.loadNode().ofYaml(Simple)
checkRoundTrip a
check a.a == "hello"

var a2 = simpleStr.loadNode().ofYaml(Simple2)
checkRoundTrip a2
check a2.a == "hello"

type
    Example = object of RootObj
        i: int
        s: string
        f: float

expandMacros:
    deriveYaml Example

let example = """
i: 3
s: hey
f: 0.2
"""
let e = example.ofYamlStr(Example)
check e.i == 3
check e.s == "hey"
check e.f == 0.2

type
    Example2 = object of Example
        i2: int

deriveYaml Example2

# echo (typeof Example2.i2)
# echo (typeof Example2.i)

# expandMacros:
#     deriveYaml Example2

let example2 = """
i: 3
i2: 4
s: hey
f: 0.2
"""
let e2: Example2 = example2.loadNode().ofYaml(Example2)
check e2.i == 3
check e2.s == "hey"
check e2.f == 0.2
check e2.i2 == 4


type
    Base = object of RootObj
        a: string
    RBase = ref object of Base
    Deriv = object of Base
        b: int
    Complex = object of RootObj
        c: string
        d: Base
    VKind = enum
        vk1, vk2
    Variant = object of RootObj
        c: string
        case kind: VKind
        of vk1:
            v1: string
        of vk2:
            v2: float

dumpImpl Base
dumpImpl RBase
dumpImpl Deriv
dumpImpl Variant
dumpImpl Complex

let cs = """
c: def
d:
  a: abc
"""

deriveYamls:
    Base
    RBase
    Deriv
    VKind
    Variant
    Complex

let c: Complex = cs.loadNode().ofYaml(Complex) 

check c.c == "def"
check c.d.a == "abc"
checkRoundTrip c

type
    MyEnum = enum
        my1, my2, my3

deriveYaml MyEnum

type
    MyVariant = object
        c: string
        case kind: MyEnum
        of my1:
            i: int
        of my2:
            discard
        of my3:
            s: string

# proc ofYaml(n: YNode, t: typedesc[MyVariant]): MyVariant =
#   assertYMap n
#   let kind = ofYaml(n.get("kind"), MyEnum)
#   case kind
#   of my1:
#       result = MyVariant(kind: my1,
#                           c: ofYaml(n.get("c"), string),
#                           i: ofYaml(n.get("i"), int)
#       )
#   of my2:
#       result = MyVariant(kind: my2,
#                           c: ofYaml(n.get("c", string)))
#   of my3:
#       result = MyVariant(kind: my3,
#                           c: ofYaml(n.get("c", string)),
#                           s: ofYaml(n.get("s", string))
#       )

# dumpTree:
#     proc toYaml(x: MyVariant): YNode =
#         case x.kind
#         of my1:
#             result = newYMap({
#                 "kind": toYaml(x.kind),
#                 "c": toYaml(x.c),
#                 "i": toYaml(x.i)
#             })
#         of my2:
#             result = newYMap({
#                 "kind": toYaml(x.kind),
#                 "c": toYaml(x.c),
#             })
#         of my3:
#             result = newYMap({
#                 "kind": toYaml(x.kind),
#                 "c": toYaml(x.c),
#                 "s": toYaml(x.s)
#             })

expandMacros:
    deriveYaml MyVariant

# Testing the types from tyaml_extension

dumpTree:
    type 
        MountKind* = enum
            mkTmpfs = "tmpfs"
            mkS3fs = "s3fs"
        Mount* = object
            mountPoint: string
            name: string
            case kind: MountKind
            of mkTmpfs:
            discard
            of mkS3fs:
            key: string
            secret: string
            bucket: string
        Con* = object of RootObj
            name*: string
            mounts*: seq[Mount]

type 
    MountKind* = enum
        mkTmpfs = "tmpfs"
        mkS3fs = "s3fs"
    Mount* = object
        mountPoint: string
        name: string
        case kind: MountKind
        of mkTmpfs:
            discard
        of mkS3fs:
            key: string
            secret: string
            bucket: string
    Con* = object of RootObj
        name*: string
        mounts*: seq[Mount]

macro dumpFields(x: typed) =
  echo newLit($collectObjFieldsForType(x.getImpl()))

dumpFields Mount

expandMacros:
    deriveYamls:
        MountKind
        Mount
        Con


let noMounts = Con(name:"example", mounts: @[])

let m = Mount(mountPoint: "/etc/tmpfs", kind: mkTmpfs, name: "tmp")

var c2 = Con(name: "c2", mounts: @[m])

echod m.toYaml().toString()

echod noMounts.toYaml().toString()
echod c2.toYaml().toString()

let cy: YNode = c2.toYaml()

let m2: Mount = ofYaml(m.toYaml(), Mount)
check m2.name == m.name
check m2.mountPoint == m.mountPoint
check m2.kind == m.kind
checkRoundTrip m2


let c3: Con = ofYaml(cy, Con)
check c3.name == c2.name
check len(c3.mounts) == 1
check c3.mounts[0].name == m2.name
checkRoundTrip c3

checkRoundTrip cy

import
    strformat,
    tables,
    unittest

import
    yanyl

import
  test_utils/yaml_testing

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

proc ofYaml(n: YNode, t: typedesc[MountKind]): MountKind =
  assertYString n
  case n.strVal
  of $mkTmpfs:
      result = mkTmpfs
  of $mkS3fs:
      result = mkS3fs
  else:
      raise newException(ValueError, fmt"unknown kind {n.strVal}")


proc ofYaml(n: YNode, t: typedesc[Mount]): Mount =
    assertYMap n
    let kind = ofYaml(n.get("kind"), MountKind)
    let mountPoint = n.get("mountPoint").str()
    let name = n.getStr("name")
    case kind
    of mkS3fs:
        let key = n.get("key").str()
        let secret = n.getStr("secret")
        let bucket = n.getStr("bucket")
        result = Mount(kind: kind,
                       mountPoint: mountPoint,
                       key: key,
                       secret: secret,
                       bucket: bucket,
                       name: name)
    of mkTmpfs:
        result = Mount(kind: kind,
                       mountPoint: mountPoint,
                       name: name)

proc ofYaml(n: YNode, t: typedesc[Con]): Con =
    assertYMap n
    let name = n.getStr("name")
    let mounts: seq[Mount] = ofYaml(n.get("mounts"), seq[Mount])
    return Con(name: name, mounts: mounts)

proc toYaml(m: Mount): YNode =
    let common = {
        "kind": toYaml($m.kind),
        "mountPoint": toYaml(m.mountPoint),
        "name": toYaml(m.name)
    }
    var extra: seq[(string,YNode)]
    case m.kind
    of mkTmpfs:
        extra = @[]
    of mkS3fs:
        extra = @[ 
            ("key", toYaml(m.key)),
            ("secret", toYaml(m.secret)),
            ("bucket", toYaml(m.bucket))
        ]
    let t = newTable[string,YNode]()
    for _,(k,v) in common:
        t[k] = v
    for _,(k,v) in extra:
        t[k] = v

    return newYMap(t)


proc toYaml(c: Con): YNode =
    {
     "name": toYaml(c.name),
     "mounts": toYaml(c.mounts)
    }.newYMap()

let noMounts = Con(name:"example", mounts: @[])

let m = Mount(mountPoint: "/etc/tmpfs", kind: mkTmpfs, name: "tmp")

var c2 = Con(name: "c2", mounts: @[m])

echod m.toYaml().toString()

echod noMounts.toYaml().toString()
echod c2.toYaml().toString()

let cy: YNode = c2.toYaml()

let m2 = ofYaml(m.toYaml(), Mount)
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

# var s = newFileStream("out.yaml", fmWrite)
# dump(noMounts, s)
# s.close()

# s = newFileStream("out2.yaml", fmWrite)
# dump(c2,s)
# s.close()

# import std/typeinfo

# var x: Any

# x = c2.toAny

# # echo x.kind
# # for (name,i) in x.fields:
# #   echo name

# import macros

# macro dumpTypeImpl(x: typed): untyped =
#   newLit(x.getTypeImpl.repr)

# # echo c2.dumpTypeImpl()

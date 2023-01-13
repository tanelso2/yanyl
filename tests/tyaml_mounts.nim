import
  yanyl,
  test_utils/yaml_testing,
  unittest

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

var sample: string = """
name: personal-website
mounts:
- name: m1
  mountPoint: /mnt/m1
  kind: tmpfs
"""

var c: Con = ofYamlStr(sample, Con)
check c.name == "personal-website"
check c.mounts[0].name == "m1"
check c.mounts[0].mountPoint == "/mnt/m1"
check c.mounts[0].kind == mkTmpfs

sample = """
name: nginx
mounts:
- name: cache
  mountPoint: /mnt/cache
  kind: tmpfs
- name: data
  mountPoint: /mnt/data
  kind: s3fs
  bucket: abc
  key: akey
  secret: asecret
"""
c = ofYamlStr(sample, Con)
check c.name == "nginx"
check c.mounts.len() == 2
let m0 = c.mounts[0]
check m0.name == "cache"
check m0.kind == mkTmpfs
check m0.mountPoint == "/mnt/cache"
let m1 = c.mounts[1]
check m1.name == "data"
check m1.kind == mkS3fs
check m1.mountPoint == "/mnt/data"
check m1.bucket == "abc"
check m1.key == "akey"
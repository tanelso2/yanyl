import
  yanyl,
  unittest

type
  E = enum
    eStr, eInt
  Size = enum
    sLarge, sMid
  V = object of RootObj
    case kind: E
    of eStr:
      s: string
    of eInt:
      i: int
    case size: Size 
    of sLarge:
      s2: string
    else:
      s3: string

var v: V = V(kind: eInt, i: 32, size: sLarge, s3: "hi")

deriveYamls:
  E
  Size
  V


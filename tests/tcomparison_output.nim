import
  yaml,
  yanyl

type
  Obj = object of RootObj
    i*: int
    s*: string

deriveYaml Obj

var o = Obj(i: 42, s: "Hello galaxy")
# NimYAML
echo dump(o)
# Yanyl
echo toYamlStr(o)
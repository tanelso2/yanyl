import
  yanyl,
  test_utils/yaml_testing,
  unittest

type
  Example = enum
    e1,e2,e3

deriveYaml Example

check toYamlStr(e1) == "e1"
check toYamlStr(e2) == "e2"
check toYamlStr(e3) == "e3"

let e: Example = ofYamlStr("e1", Example)
check e == e1

type
  CustomVal = enum
    cv1 = "1"
    cv2 

deriveYaml CustomVal 

check ofYamlStr("1", CustomVal) == cv1
check ofYamlStr("cv2", CustomVal) == cv2
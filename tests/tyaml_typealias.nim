import 
  macros,
  sequtils,
  tables,
  unittest,
  yanyl


type
  IntList = seq[int]
  Dict = TableRef[string, string]
  MyInt = int

expandMacros:
  deriveYamls:
    IntList
    Dict
    MyInt

var sample: string = """
- 7
- 8
- 9
"""
let il: IntList = ofYamlStr(sample, IntList)
check il.len() == 3
check il[0] == 7
check il[1] == 8
check il[2] == 9

sample = """
a: x
b: y
c: z
"""
let dict: Dict = ofYamlStr(sample, Dict)
check dict.len() == 3
check dict["a"] == "x"
check dict["b"] == "y"
check dict["c"] == "z"

check ofYamlStr("3", MyInt) == 3
check ofYamlStr("-78", MyInt) == -78
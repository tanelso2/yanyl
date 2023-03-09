import
  yanyl,
  unittest

type
  Base = ref object of RootObj
    name: string
  A = ref object of Base
    val: int
  B = ref object of Base
    otherVal: bool

deriveYamls:
  Base
  A
  B

var item: Base
var items: seq[Base]

let sample = """
name: Bob
val: 10
"""

item = ofYamlStr(sample, Base)
check item.name == "Bob"

let samples = """
- name: Bill
  val: 10
- name: Denise
  otherVal: true
"""

items = ofYamlStr(samples, seq[Base])
check len(items) == 2
check items[0].name == "Bill"
check items[1].name == "Denise"

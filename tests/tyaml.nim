import 
  std/tables,
  unittest

import 
  yanyl

import
  test_utils/yaml_testing

let sampleNodeStr = """
{ "i": 1, "f": 0.1, "s": "hello"}
"""
checkRoundTrip sampleNodeStr

var mynode: YNode 
mynode = loadNode(sampleNodeStr)
checkRoundTrip mynode
check mynode.kind == ynMap
check mynode.mapVal.len() == 3
check mynode.get("i").toInt() == 1
check mynode.get("f").toFloat() == 0.1
check mynode.get("s").str() == "hello"

var sampleStr = """
a:
- 1
- 2
- 3
b: false
"""
checkRoundTrip sampleStr

mynode = loadNode(sampleStr)
checkRoundTrip mynode
check mynode.kind == ynMap
check mynode.mapVal.len() == 2
let a = mynode.get("a")
check a.kind == ynList
check a.elems().len() == 3
check a.elems()[0].str() == "1"
check mynode.get("b").kind == ynString

let intList: YNode = newYList(@[
    newYString("1"), 
    newYString("2"), 
    newYString("3")
])

checkRoundTrip intList

let heteroList: YNode = newYList(@[
  newYString("1"), 
  newYString("2"), 
  newYList(@[newYString("3"), newYString("4")]),
  newYString("5")
])
checkRoundTrip heteroList


let smallList: YNode = newYList(@["a", "b", "c", "d"])
checkRoundTrip smallList

let t = {
  "x": smallList, 
  "y": newYString("yay"),
  "z": heteroList,
  "z2": heteroList,
}.newTable()

let mapExample: YNode = newYMap(t)
checkRoundTrip mapExample

let t2 = {
  "apple": newYString("red"),
  "orange": heteroList,
  "banana": mapExample
}.newTable()

let map2: YNode = newYMap(t2)
checkRoundTrip map2


# Check Maps under lists
let map3 = newYMap({
  "example1": newYList(@[newYString("0.12"), map2]),
  "example2": mapExample
})

checkRoundTrip map3

var s = """
a: 1
b: 2
c: 
  d: 4
  e: 5
  f: 
   - 6
   - 7
   - 8
"""
checkRoundTrip s

# Empty list
let emptyNodes: seq[YNode] = @[]
let emptyList = newYList(emptyNodes)
checkRoundTrip emptyList
let emptyList2 = emptyList.toString().loadNode()
assert emptyList2.kind == ynList
assert emptyList2.listVal.len() == 0

# empty map
let emptyMap = newYMap(newTable[string,YNode]())
checkRoundTrip emptyMap
let emptyMap2 = emptyMap.toString().loadNode()
checkRoundTrip emptyMap2
assert emptyMap2.kind == ynMap
assert emptyMap2.mapVal.len() == 0

# empty string
let emptyString = newYString("")
checkRoundTrip emptyString
let emptyStringList = newYList(@[emptyString, emptyString])
checkRoundTrip emptyStringList
let emptyStringMap = newYMap({"a": emptyString, "b": newYString("1")})
checkRoundTrip emptyStringMap
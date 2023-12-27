import
  yanyl

let s = """
a: 1
b: 3
c:
  - a
  - b
  - c
"""

let y: YNode = s.loadNode()
assert y.kind == ynMap
assert y.get("a").kind == ynString
assert y.get("a").strVal == "1"
assert y.get("b").kind == ynString
assert y.get("b").strVal == "3"
let c = y.get("c")
assert c.kind == ynList
let firstElem = c.elems()[0]
assert firstElem.kind == ynString
assert firstElem.strVal == "a"

import
  streams

let s2 = newFileStream("tests/example.yaml")
let y2: YNode = s2.loadNode()
assert y2.kind == ynMap
assert y2.get("name").kind == ynString
assert y2.get("name").strVal == "Peter Parker"
assert y2.get("occupation").kind == ynString
assert y2.get("occupation").strVal == "Photographer"
assert y2.get("aliases").kind == ynList
let aliases = y2.get("aliases").elems()
let tiger = aliases[0]
assert tiger.kind == ynString
assert tiger.strVal == "Tiger"


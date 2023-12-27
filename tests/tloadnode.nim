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
assert y.get("c").kind == ynList
# assert y.get("d").kind == ynString

import
  streams

let s2 = newFileStream("tests/example.yaml")
let y2: YNode = s2.loadNode()
assert y2.get("name").kind == ynString

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
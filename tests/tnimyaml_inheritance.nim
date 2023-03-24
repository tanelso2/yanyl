discard """
# This is expected to fail
# See https://github.com/flyx/NimYAML/issues/131
exitcode: 1
"""

import
    yaml

type
    Parent = object of RootObj
        i*: int
    Child = object of Parent
        s*: string

let sample = """
i: 4
s: hello
"""
var c: Child
load(sample, c)
assert c.i == 4
assert c.s == "hello"

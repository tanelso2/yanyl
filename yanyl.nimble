# Package
# Yet Another Nim Yaml Library
# YANYL
version       = "0.0.1"
author        = "Thomas Nelson"
description   = "A library for working with YAML in Nim"
license       = "Unlicense"
srcDir        = "src"


# Dependencies

requires "nim >= 1.6.8"
requires "yaml"
requires "https://github.com/tanelso2/nim_utils >= 0.3.0"

task test, "Runs the tests":
  exec "testament p 'tests/t*.nim'"

task genDocs, "Generate the docs":
  exec "nim doc --project --out:docs src/yanyl.nim"
  exec "cp docs/theindex.html docs/index.html"

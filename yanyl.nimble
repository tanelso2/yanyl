# Package
# Yet Another Nim Yaml Library
# YANYL
version       = "1.2.0"
author        = "Thomas Nelson"
description   = "A library for working with YAML in Nim"
license       = "Unlicense"
srcDir        = "src"


# Dependencies

requires "nim >= 2.0.2"
requires "fusion"
requires "yaml == 2.0.0"

import
  strformat

task test, "Runs the tests":
  exec "testament p 'tests/t*.nim'"

task genDocs, "Generate the docs":
  let gitHash = gorge "git rev-parse --short HEAD"
  let url = "https://github.com/tanelso2/yanyl"
  exec fmt"nim doc --project --git.url:{url} --git.commit:{gitHash} --git.devel:main --outdir:docs src/yanyl.nim"
  exec "cp docs/yanyl.html docs/index.html"

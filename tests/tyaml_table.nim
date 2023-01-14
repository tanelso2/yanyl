import
  yanyl,
  std/options,
  std/tables,
  unittest

type
  Dotfile* = object
    path*: string
    gitPath*: string

deriveYaml Dotfile

var sample = """
all:
- path: ~/.zshrc
  gitPath: .zshrc
"""
let t = ofYamlStr(sample, Table[string, seq[Dotfile]])
check t["all"].len() == 1
check t["all"][0].path == "~/.zshrc"
check "work" in t == false

let tr = ofYamlStr(sample, TableRef[string, seq[Dotfile]])
check tr["all"].len() == 1
check tr["all"][0].path == "~/.zshrc"

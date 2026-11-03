import unittest, os
from sugar import collect
from algorithm import sorted
from sequtils import toSeq

import nasher/utils/shared
import nasher/utils/nwscript

suite "Issue #90: ensure includes/excludes with relative paths correctly parsed":
  test "Works when nasher package is a library containing files":
    withDir "tests/corpus/issue-90/lib":
      let
        target = parsePackageFile(getPackageFile())[0]
        actual = target.getSourceFiles
        expected = collect:
          for file in walkFiles("src/*"):
            if file.splitFile.name[0] != '_':
              file.absolutePath
      check:
        actual.sorted == expected.sorted

  test "Works when nasher package sources files from another directory":
    withDir "tests/corpus/issue-90/pkg":
      let
        target = parsePackageFile(getPackageFile())[0]
        actual = target.getSourceFiles
        expected = collect:
          for file in walkFiles("../lib/src/*"):
            if file.splitFile.name[0] != '_':
              file.absolutePath
      check:
        actual.sorted == expected.sorted

suite "Issue #126: nwscript files with multi-line comments successfully parsed":
  test "Executables correctly identified":
    var results: seq[bool]
    let expected = @[false, true, true, true, false, false]
    withDir "tests/corpus/issue-126/executable":
      for file in walkFiles("*.nss"):
        results.add file.executable
    check results == expected

  template checkIncludes(script: string, scripts: seq[string]) =
    check script.included.toSeq == scripts

  test "Includes correctly identified":
    var results: seq[bool]
    let expected = @[false, true, true, true, false]
    withDir "tests/corpus/issue-126/included":
      checkIncludes("i1.nss", @["c"])
      checkIncludes("i2.nss", @["b"])
      checkIncludes("i3.nss", @["b"])
      checkIncludes("i4.nss", @["a", "b", "c", "e"])

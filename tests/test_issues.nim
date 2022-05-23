import unittest, os
from sugar import collect
from algorithm import sorted

import nasher/utils/shared

suite "Issues":
  test "Issue #90":
    ## Ensure includes/excludes with relative paths correctly parsed

    withDir "tests/corpus/issue-90/lib":
      # This nasher package is a library containing files
      let
        target = parsePackageFile(getPackageFile())[0]
        actual = getSourceFiles(target.includes, target.excludes)
        expected = collect:
          for file in walkFiles("src/*"):
            if file.splitFile.name[0] != '_':
              file.absolutePath
      check:
        actual.sorted == expected.sorted

    withDir "tests/corpus/issue-90/pkg":
      # This nasher package sources files from another directory
      let
        target = parsePackageFile(getPackageFile())[0]
        actual = getSourceFiles(target.includes, target.excludes)
        expected = collect:
          for file in walkFiles("../lib/src/*"):
            if file.splitFile.name[0] != '_':
              file.absolutePath
      check:
        actual.sorted == expected.sorted

import unittest
from sequtils import zip
from strutils import contains, `%`

import nasher/pkgparser

proc dumpTarget(target: Target) =
  ## Helps debug failing tests
  echo "Target: ", target.name
  for key, value in target.fieldPairs:
    echo "  ", key, ": ", value

template checkErrorMsg(msg: string, body: untyped) =
  ## Runs ``body`` and checks that any raised exception message contains
  ## ``msg``.
  try:
    body
  except:
    check msg in getCurrentExceptionMsg()
    raise

suite "Package file validation":

  const pkg = """
  target.name = "demo"
  target.file = "demo.mod"
  """

  test "Error on invalid TOML":
    expect TomlError:
      discard parsePackageString("[package")

  test "Error if [target] not an array or table":
    check:
      parsePackageString("""
        [target]
        name = "foo"
        file = "bar.mod"

          [target.sources]
          includes = ["foo"]
        """).len == 1

      # This syntax is preferred since it can be easily expanded
      parsePackageString("""
        [[target]]
        name = "foo"
        file = "bar.mod"

          [target.sources]
          includes = ["foo"]
        """).len == 1

      # For convenience, the rest of the tests will use this syntax when there
      # is only one target.
      parsePackageString("""
        target.name = "foo"
        target.file = "bar.mod"
        target.sources.includes = ["foo"]
        """).len == 1

    expect PackageError:
      checkErrorMsg "[target] must be TOML table or array of tables":
        discard parsePackageString("""
          target = "foo"
          """)

  test "Error on target with no 'name', 'file', or 'sources.includes' field":
    expect PackageError:
      checkErrorMsg "target missing required field \"name\"":
        discard parsePackageString("""
          target.file = "demo.mod"
          target.sources.includes = ["foo"]
          """)

    expect PackageError:
      checkErrorMsg "target missing required field \"file\"":
        discard parsePackageString("""
          target.name = "demo"
          target.sources.includes = ["foo"]
          """)

    expect PackageError:
      checkErrorMsg "target missing required field \"sources.includes\"":
        discard parsePackageString("""
          target.name = "demo"
          target.file = "demo.mod"
          """)

  test "Error if a top-level string field is not a string":
    expect PackageError:
      checkErrorMsg "expected target.name to be String but got Int":
        discard parsePackageString("""
          target.name = 0
          """)

    expect PackageError:
      checkErrorMsg "expected target.file to be String but got Int":
        discard parsePackageString("""
          target.file = 0
          """)

    for field in ["description", "branch", "modName", "modMinGameVersion"]:
      expect PackageError:
        checkErrorMsg "expected target.$1 to be String but got Int" % [field]:
          discard parsePackageString(pkg & "target." & field & " = 0")

  test "Error if 'flags' field is not a string array":
    expect PackageError:
      checkErrorMsg "expected target.flags to be Array but got String":
        discard parsePackageString(pkg & "target.flags = \"-lowqey\"")

    expect PackageError:
      checkErrorMsg "expected all items in target.flags to be String but got Int":
        discard parsePackageString(pkg & "target.flags = [1, 2, 3]")

  test "Error if '{sources,aliases,rules}' field is not a table":
    for field in ["sources", "aliases", "rules"]:
      expect PackageError:
        checkErrorMsg "expected target." & field & " to be Table but got String":
          discard parsePackageString(pkg & "target." & field & " =  \"foo\"")

  test "Error if unknown keys in 'sources' field":
    expect PackageError:
      checkErrorMsg "unknown key target.sources.foo":
        discard parsePackageString(pkg & "target.sources.foo = 0")

  test "Error if 'sources.{includes,excludes,filters}' field is not a string array":
    for field in ["includes", "excludes", "filters"]:
      expect PackageError:
        checkErrorMsg "expected target.sources.$1 to be Array but got String" % [field]:
          discard parsePackageString(pkg & "target.sources." & field & " = \"foo\"")
      
      expect PackageError:
        checkErrorMsg "expected all items in target.sources.$1 to be String but got Int" % [field]:
          discard parsePackageString(pkg & "target.sources." & field & " = [1, 2, 3]")

  test "Error if any fields in 'aliases' are not strings":
    expect PackageError:
      checkErrorMsg "expected target.aliases.foo to be String but got Int":
        discard parsePackageString(pkg & "target.aliases.foo = 0")

  test "Error if any fields in 'rules' are not strings":
    expect PackageError:
      checkErrorMsg "expected target.rules.\"foo\" to be String but got Int":
        discard parsePackageString(pkg & "target.rules.foo = 0")

  test "Error if unknown key encountered":
    expect PackageError:
      checkErrorMsg "unknown key target.foo":
        discard parsePackageString(pkg & "target.foo = \"bar\"")


suite "Package file parsing":
  test "Empty package file yields empty target list":
    check parsePackageString("").len == 0

  test "No targets defined yields empty target list":
    check parsePackageString("""
      [package]
      name = "Test Package"
      file = "core_framework.mod"
      description = "The package description"

        [package.sources]
        includes = ["src/**/*.{nss,json}"]

        [package.rules]
        "*" = "src"

        [package.aliases]
        sm-utils = "sm-utils/src"
        """).len == 0
  
  test "target.file inherits package.file":
    let targets =
      parsePackageString("""
        [package]
        file = "foo.mod"

          [package.sources]
          includes = ["src/*"]

        [[target]]
        name = "no-file"

        [[target]]
        name = "some-file"
        file = "bar.mod"
      """)

    check:
      targets[0].file == "foo.mod"
      targets[1].file == "bar.mod"

  test "[target.sources.$field] inherits [package.sources.$field]":
    let targets = parsePackageString("""
      [package]
      file = "demo.mod"

        [package.sources]
        includes = ["foo/*"]
        excludes = ["foo/bar_*"]
        filters = ["*.ncs"]

      [[target]]
      name = "no-sources"

      [[target]]
      name = "some-sources"

        [target.sources]
        excludes = ["foo/baz_*"]

      [[target]]
      name = "all-sources"

        [target.sources]
        includes = ["foo/*", "bar/*"]
        excludes = ["foo/test_*", "bar/test_*"]
        filters = ["*.ncs", "*.ndb"]
      """)
    
    check:
      targets[0].includes == @["foo/*"]
      targets[0].excludes == @["foo/bar_*"]
      targets[0].filters == @["*.ncs"]
      
      targets[1].includes == @["foo/*"]
      targets[1].excludes == @["foo/baz_*"]
      targets[1].filters == @["*.ncs"]

      targets[2].includes == @["foo/*", "bar/*"]
      targets[2].excludes == @["foo/test_*", "bar/test_*"]
      targets[2].filters == @["*.ncs", "*.ndb"]
  
  test "[target.rules] inherits [package.rules]":
    let targets =
      parsePackageString("""
        [package]
        file = "demo.mod"

          [package.sources]
          includes = ["src/*"]

          [package.rules]
          "foo_*" = "src/foo"

        [[target]]
        name = "no-rules"

        [[target]]
        name = "some-rules"

          [target.rules]
          "bar_*" = "src/bar"
        """)

    check:
      targets[0].rules == @[(pattern: "foo_*", dest: "src/foo")]
      targets[1].rules == @[(pattern: "bar_*", dest: "src/bar")]

  test "[target.aliases] merges [package.aliases]":
    let targets = parsePackageString("""
      [package]
      file = "demo.mod"
        
        [package.sources]
        includes = ["src/*"]

        [package.aliases]
        foo = "foo/*"
        bar = "bar/*"

      [[target]]
      name = "no-aliases"
      
      [[target]]
      name = "some-aliases"
        
        [target.aliases]
        bar = "qux/*"
        baz = "baz/*"
      """)
    let
      aliases: seq[StringTableRef] = @[
        newStringTable({"foo": "foo/*", "bar": "bar/*"}),
        newStringTable({"foo": "foo/*", "bar": "qux/*", "baz": "baz/*"}) ]

    check:
      $targets[0].aliases == $aliases[0]
      $targets[1].aliases == $aliases[1]
  
  test "Parse package string":
    let pkg = """
      [package]
      name = "Test Package"
      description = "The package description"

        [package.sources]
        includes = ["src/**/*.{nss,json}"]

        [package.rules]
        "*" = "src"

        [package.aliases]
        sm-utils = "sm-utils/src"

      [[target]]
      name = "module"
      file = "core_framework.mod"
      description = "A demo module"

      [[target]]
      name = "erf"
      file = "core_framework.erf"
      description = "An importable erf"

        [target.sources]
        excludes = ["src/test_*.nss", "src/_*.nss"]
        filters = ["*.ncs"]

        [target.aliases]
        core = "src/core"
        sm-utils = "src/utils"
        """

    let
      targetA = Target(name: "module",
                       file: "core_framework.mod",
                       description: "A demo module",
                       includes: @["src/**/*.{nss,json}"],
                       rules: @[(pattern: "*", dest: "src")],
                       aliases: newStringTable({"sm-utils": "sm-utils/src"}))
      targetB = Target(name: "erf",
                       file: "core_framework.erf",
                       description: "An importable erf",
                       includes: @["src/**/*.{nss,json}"],
                       excludes: @["src/test_*.nss", "src/_*.nss"],
                       filters: @["*.ncs"],
                       rules: @[(pattern: "*", dest: "src")],
                       aliases: newStringTable({"sm-utils": "src/utils", "core": "src/core"}))
      manual = @[targetA, targetB]
      parsed = parsePackageString(pkg)
    
    check parsed.len == manual.len
    for (a, b) in zip(manual, parsed):
      for key, valA, valB in fieldPairs(a, b):
        when valA is StringTableRef:
          check $valA == $valB
        else:
          check valA == valB

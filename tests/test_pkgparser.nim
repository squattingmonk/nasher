import unittest, os
from sequtils import zip
from strutils import contains, `%`

import nasher/utils/pkgparser

proc dumpTarget(target: Target) =
  ## Helps debug failing tests
  echo "Target: ", target.name
  for key, value in fieldPairs(target[]):
    echo "  ", key, ": ", value

template checkErrorMsg(msg: string, body: untyped) =
  ## Runs `body` and checks that any raised exception message contains `msg`.
  try:
    body
  except:
    check msg in getCurrentExceptionMsg()
    raise

suite "nasher.cfg parsing":
  test "Error on malformed syntax":
    expect PackageError:
      discard parsePackageString("""
      [package
      name = "foo"
      """)

  test "Empty package file yields empty target list":
    check parsePackageString("").len == 0

  test "No targets defined yields empty target list":
    check:
      parsePackageString("""
      [package]
      name = "foo"
      file = "bar"
      """).len == 0

  test "Error if [package] section occurs after other sections":
    expect PackageError:
      checkErrorMsg "[package] section must be declared before other sections":
        discard parsePackageString("""
        [sources]
        [package]
        """)

  test "Error on duplicate [package] section":
    expect PackageError:
      checkErrorMsg "duplicate [package] section":
        discard parsePackageString("""
        [package]
        [package]
        """)

  test "No error if [package] section absent":
    let targets = parsePackageString("""
    [target]
    name = "foo"
    """)
    check: targets.len == 1

  test "[sources] and [rules] can be top-level sections":
    check parsePackageString("""
    [sources]
    [rules]

    [target]
    name = "foo"
    """).len == 1

  test "[sources] and [rules] sections can belong to [package] or [target]":
    let targets = parsePackageString("""
    [package]

      [sources]
      include = "foo"

      [rules]
      foo = "foo"

    [target]
    name = "bar"

      [sources]
      include = "bar"

      [rules]
      bar = "bar"

    [target]
    name = "foo"
    """)

    check:
      targets.len == 2
      targets[0].includes == @["bar"]
      targets[0].rules == @[(pattern: "bar", dest: "bar")]

      targets[1].includes == @["foo"]
      targets[1].rules == @[(pattern: "foo", dest: "foo")]

  test "[package.{sources,rules}] must be declared inside [package] or at top-level":
    check parsePackageString("""
    [package]
      [package.sources]
      [package.rules]
    """).len == 0

    check parsePackageString("""
    [package.sources]
    [package.rules]
    """).len == 0

    for section in ["sources", "rules"]:
      expect PackageError:
        checkErrorMsg "[package.$1] must be declared within [package]" % section:
          discard parsePackageString("""
          [target]
          name = "foo"
            [package.$1]
          """ % section)

  test "[target.{sources,rules}] must be declared inside [target]":
    check parsePackageString("""
    [target]
    name = "foo"
      [target.sources]
      [target.rules]
    """).len == 1

    for section in ["sources", "rules"]:
      expect PackageError:
        checkErrorMsg "[target.$1] must be declared within [target]" % section:
          discard parsePackageString("""
          [package]
          name = "foo"
          [target.$1]
          """ % section)

  test "Error on unknown key in [*.sources]":
    for context in ["package", "target"]:
      expect PackageError:
        checkErrorMsg "invalid key \"foo\" for section [$1.sources]" % context:
          discard parsePackageString("""
          [$1]
          name = "foo"

            [$1.sources]
            foo = "bar"
          """ % context)

      expect PackageError:
        checkErrorMsg "invalid key \"foo\" for section [$1.sources]" % context:
          discard parsePackageString("""
          [$1]
          name = "foo"

            [sources]
            foo = "bar"
          """ % context)

  test "One target per [target] section":
    let targets = parsePackageString("""
    [package]
    name = "foo"
    file = "bar.mod"

    [target]
    name = "one"

    [target]
    name = "two"
    """)

    check:
      targets.len == 2
      targets[0].name == "one"
      targets[1].name == "two"

  test "Error if target has no name":
    expect PackageError:
      checkErrorMsg "target 1 does not have a name":
        discard parsePackageString("""
        [target]
        file = "foo.mod"
        """)

    expect PackageError:
      checkErrorMsg "target 2 does not have a name":
        discard parsePackageString("""
        [target]
        name = "foo"

        [target]
        file = "bar.mod"
        """)

  test "Error on invalid target name":
    expect PackageError:
      checkErrorMsg "invalid target name":
        discard parsePackageString("""
        [target]
        name = "all"
        """)

    expect PackageError:
      checkErrorMsg "invalid character \"F\" in target name \"Foo\"":
        discard parsePackageString("""
        [target]
        name = "Foo"
        """)

  test "Error on duplicate target name":
    let pkg = parsePackageString("""
      [package]
      name = "foo"

      [target]
      name = "foo"
      """)
    check:
      pkg.len == 1
      pkg[0].name == "foo"

    expect PackageError:
      checkErrorMsg "duplicate target name":
        discard parsePackageString("""
          [target]
          name = "foo"

          [target]
          name = "foo"
          """)

  test "{package,target}.{version,url,author} fields ignored":
    check:
      parsePackageString("""
      [package]
      version = "0.1.0"
      url = "www.example.com"
      author = "John Doe <johndoe@example.com>"

      [target]
      name = "foo"
      version = "0.1.0"
      url = "www.example.com"
      author = "John Doe <johndoe@example.com>"
      """).len == 1

  test "target.{name,description} not inherited from [package]":
    expect PackageError:
      checkErrorMsg "target 1 does not have a name":
        discard parsePackageString("""
        [package]
        name = "foo"

        [target]
        """)

    let target = parsePackageString("""
    [package]
    name = "foo"
    description = "bar"

    [target]
    name = "bar"
    """)[0]
    check:
      target.description == ""

  test "target.{file,branch,modName,modMinGameVersion} inherit from [package]":
    let targets = parsePackageString("""
    [package]
    file = "foo.mod"
    branch = "master"
    modName = "foobar"
    modMinGameVersion = "1.73"

    [target]
    name = "no-inherit"
    file = "bar.mod"
    branch = "baz"
    modName = "qux"
    modMinGameVersion = "1.69"

    [target]
    name = "inherit"
    """)
    check:
      targets.len == 2
      targets[0].file == "bar.mod"
      targets[0].branch == "baz"
      targets[0].modName == "qux"
      targets[0].modMinGameVersion == "1.69"

      targets[1].file == "foo.mod"
      targets[1].branch == "master"
      targets[1].modName == "foobar"
      targets[1].modMinGameVersion == "1.73"

  test "target.{includes,excludes,filters,flags} inherit from [package]":
    let targets = parsePackageString("""
    [package]
    include = "foo/*"
    exclude = "bar/*"
    filter = "*.ncs"
    flags = "--foo"

    [target]
    name = "bar"
    include = "bar/*"
    exclude = "foo/*"
    filter = "*.ndb"
    flags = "--bar"

    [target]
    name = "foo"
    """)
    check:
      targets.len == 2
      targets[0].name == "bar"
      targets[0].includes == @["bar/*"]
      targets[0].excludes == @["foo/*"]
      targets[0].filters == @["*.ndb"]
      targets[0].flags == @["--bar"]
      targets[1].name == "foo"
      targets[1].includes == @["foo/*"]
      targets[1].excludes == @["bar/*"]
      targets[1].filters == @["*.ncs"]
      targets[1].flags == @["--foo"]

  test "target.{includes,excludes,filters,flags} values added to seq when seen multiple times":
    let target = parsePackageString("""
      [target]
      name = "foo"
      include = "foo"
      include = "bar"
      exclude = "baz"
      exclude = "qux"
      filter = "*.foo"
      filter = "*.bar"
      flags = "--foo"
      flags = "--bar"
      """)[0]
    check:
      target.includes == @["foo", "bar"]
      target.excludes == @["baz", "qux"]
      target.filters == @["*.foo", "*.bar"]
      target.flags == @["--foo", "--bar"]

  test "Unpack rules added to seq":
    let target = parsePackageString("""
    [rules]
    foo = "foo/"
    bar = "bar/"

    [target]
    name = "foo"
    """)[0]
    check:
      target.rules == @[(pattern: "foo", dest: "foo/"), (pattern: "bar", dest: "bar/")]

  test "Unpack rules inherited from [package]":
    let targets = parsePackageString("""
    [rules]
    foo = "foo/"

    [target]
    name = "bar"
    bar = "bar/"

    [target]
    name = "foo"
    """)
    check:
      targets.len == 2
      targets[0].rules == @[(pattern: "bar", dest: "bar/")]
      targets[1].rules == @[(pattern: "foo", dest: "foo/")]

  test "Unknown keys in [target] treated as unpack rules":
    let target = parsePackageString("""
    [target]
    name = "foo"
    foo = "foo/"
    bar = "bar/"
    """)[0]
    check:
      target.rules == @[(pattern: "foo", dest: "foo/"), (pattern: "bar", dest: "bar/")]

  test "Parse package string":
    let pkg = """
      [package]
      name = "Test Package"
      description = "The package description"

        [package.sources]
        include = "src/**/*.{nss,json}"

        [package.rules]
        "*" = "src"

      [target]
      name = "module"
      file = "core_framework.mod"
      description = "A demo module"

      [target]
      name = "erf"
      file = "core_framework.erf"
      description = "An importable erf"

        [target.sources]
        exclude = "src/test_*.nss"
        exclude = "src/_*.nss"
        filter = "*.ncs"
      """

    let
      targetA = Target(name: "module",
                       file: "core_framework.mod",
                       description: "A demo module",
                       includes: @["src/**/*.{nss,json}"],
                       rules: @[(pattern: "*", dest: "src")])
      targetB = Target(name: "erf",
                       file: "core_framework.erf",
                       description: "An importable erf",
                       includes: @["src/**/*.{nss,json}"],
                       excludes: @["src/test_*.nss", "src/_*.nss"],
                       filters: @["*.ncs"],
                       rules: @[(pattern: "*", dest: "src")])
      manual = @[targetA, targetB]
      parsed = parsePackageString(pkg)

    check parsed.len == manual.len
    for (a, b) in zip(manual, parsed):
      check a == b

suite "nasher.cfg backwards compatibility":
  const
    dir = "tests/corpus"
    packages = @[
      "https://github.com/squattingmonk/nasher", ## Example from readme
      "https://github.com/squattingmonk/sm-utils",
      "https://github.com/squattingmonk/nwn-core-framework",
      "https://github.com/tinygiant/darksun-sot",
      "https://github.com/tinygiant98/darksun-resources",
      "https://github.com/Kaikas/mintarn",
      "https://github.com/b5635/the-frozen-north"]

  # Since we know that cfg files parse correctly now, we only have to check
  # whether these files throw exceptions.
  for package in packages:
    test package:
      discard parsePackageFile(dir / package.lastPathPart.addFileExt("cfg"))

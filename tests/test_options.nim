import unittest, strutils

import nasher/utils/[options, cli]

suite "Options table access":
  setup:
    let opts = newOptions()

  test "New options table is empty by default":
    check:
      opts.len == 0

  test "Setting and getting a key is case- and style-insensitive":
    opts["foo"] = "bar"
    check:
      opts["foo"] == "bar"
      opts["FOO"] == "bar"
      opts["F_O_O"] == "bar"

    opts["F_O_O"] = "baz"
    check:
      opts["foo"] == "baz"
      opts["FOO"] == "baz"
      opts["F_O_O"] == "baz"

  test "Parsing error throws exception":
     expect SyntaxError:
       opts.parseString("""
       foo = "bar
       """)

  test "Reloading adds new keys":
    opts.parseString("""
    foo = "bar"
    bar = "baz"
    """)
    opts.parseString("""
    baz = "qux"
    """)

    check:
      opts.len == 3
      opts["foo"] == "bar"
      opts["bar"] == "baz"
      opts["baz"] == "qux"

  test "Reloading overwrites existing keys":
    opts.parseString("""
    foo = "bar"
    bar = "baz"
    """)
    opts.parseString("""
    bar = "qux"
    """)

    check:
      opts.len == 2
      opts["foo"] == "bar"
      opts["bar"] == "qux"

  test "Return default value if key not present":
    check:
      opts.get("foo") == ""
      opts.get("foo", "bar") == "bar"
      opts.get("foo", true) == true
      opts.get("foo", 1) == 1

    check:
      opts.get(@["foo", "bar"], "baz") == "baz"
      opts.get(@["foo", "baz"], true) == true
      opts.get(@["foo", "qux"], 1) == 1

    opts.parseString("""
    bar = "foobar"
    baz = false
    qux = 2
    """)
    check:
      opts.get(@["foo", "bar"], "baz") == "foobar"
      opts.get(@["foo", "baz"], true) == false
      opts.get(@["foo", "qux"], 1) == 2

  test "Return on/off, true/false, 1/0 as bool values":
    opts.parseString("""
    a = on
    b = off
    c = true
    d = false
    e = 1
    f = 0
    """)

    check:
      opts.get("a", false) == true
      opts.get("b", false) == false
      opts.get("c", false) == true
      opts.get("d", false) == false
      opts.get("e", false) == true
      opts.get("f", false) == false

  test "Return bool flag with no value as true":
    opts.parseString("foo")

    check:
      opts.get("foo", false) == true
      opts.get("bar", false) == false

  test "Return default value if option cannot be converted to default's type":
    opts.parseString("""
    foo = "bar"
    """)

    check:
      opts.get("foo", false) == false
      opts.get("foo", 0) == 0

  test "Return int flag with no value as default":
    opts.parseString("foo")
    check: opts.get("foo", 0) == 0

  test "Return numbers as int values":
    opts.parseString("a = 1")
    check: opts.get("a", 0) == 1

  test "Non-string values converted to string when setting":
    opts["foo"] = true
    opts["bar"] = 1
    check:
      opts.get("foo") == "true"
      opts.get("bar") == "1"

  test "Return value if set; put if not set or not convertible":
    opts["strval1"] = "foo"
    opts["intval1"] = 1
    opts["boolval1"] = true

    check:
      opts.getOrPut("strval1", "bar") == "foo"
      opts.getOrPut("strval2", "bar") == "bar"
      opts["strval1"] == "foo"
      opts["strval2"] == "bar"

      opts.getOrPut("intval1", 2) == 1
      opts.getOrPut("intval2", 2) == 2
      opts["intval1"] == "1"
      opts["intval2"] == "2"

      opts.getOrPut("boolval1", false) == true
      opts.getOrPut("boolval2", false) == false
      opts["boolval1"] == "true"
      opts["boolval2"] == "false"

    check:
      opts.getOrPut("strval1", true) == true
      opts.getOrPut("strval2", 1) == 1
      opts["strval1"] == "true"
      opts["strval2"] == "1"

      opts.getOrPut("intval1", "foo") == "1"
      opts.getOrPut("intval2", true) == true
      opts["intval1"] == "1"
      opts["intval2"] == "true"

      opts.getOrPut("boolval1", "foo") == "true"
      opts.getOrPut("boolval2", 1) == 1
      opts["boolval1"] == "true"
      opts["boolval2"] == "1"

suite "Config file options parsing":
  setup:
    var opts: Options
    
    template withConfig(cfg: string, body: untyped): untyped =
      opts = newOptions()
      opts.parseString(cfg)
      body

  test "Internal or cli-only keys skipped":
    withConfig(internalKeys.join(" = foo\n")):
      check opts.len == 0

    withConfig(cliKeys.join(" = foo\n")):
      check opts.len == 0

  test "Parse [no-]color as key/value pairs or options":
    for key in ["--color", "color = true", "no-color = false"]:
      withConfig(key):
        check:
          opts.len == 1
          getShowColor()

    for key in ["--no-color", "color = false", "no-color = true"]:
      withConfig(key):
        check:
          opts.len == 1
          not getShowColor()

    for key in ["color = auto", "no-color = auto"]:
      withConfig(key):
        check:
          opts.len == 1
          getShowColor() == stdout.isatty

suite "Command-line options parsing":
  setup:
    var opts: Options

    template withParams(params: varargs[string], body: untyped): untyped =
      for param in params:
        opts = newOptions()
        opts.parseCommandLine(param)
        body

  test "Empty command-line yields empty table":
    withParams "":
      check opts.len == 0
  
  test "Long options with no values normalized":
    withParams "--abort_on_compile_error", "--abortOnCompileError":
      check:
        opts.len == 1
        opts.hasKey("abortOnCompileError")

  test "Parse single key-value pair":
    withParams "--modMinGameVersion 1.74":
      check:
        opts.len == 1
        opts["modMinGameVersion"] == "1.74"

  test "Parse multiple key-value pairs":
    withParams "--modMinGameVersion 1.74 --modName demo":
      check:
        opts.len == 2
        opts["modMinGameVersion"] == "1.74"
        opts["modName"] == "demo"

  test "Parse words inside quotes as single value":
    withParams "--modName \"Demo Module\"":
      check:
        opts.len == 1
        opts["modName"] == "Demo Module"
 
  test "Parse first argument as command":
    withParams "init":
      check:
        opts.len == 1
        opts["command"] == "init"

  test "Valid commands limited":
    for command in nasherCommands:
      withParams command:
        check opts["command"] == command

  test "Show help on unrecognized command":
    withParams "foo":
      check:
        not opts.hasKey("command")
        opts["help"] == "true"

  test "Syntax error when trying to set internal option":
    for param in internalKeys:
      expect SyntaxError:
        withParams "--" & param:
          discard

  test "Positional arguments for init":
    withParams "init":
      check:
        opts["command"] == "init"
        "directory" notin opts
        "file" notin opts
        "help" notin opts

    withParams "init foo":
      check:
        opts["command"] == "init"
        opts["directory"] == "foo"
        "file" notin opts
        "help" notin opts

    withParams "init foo bar":
      check:
        opts["command"] == "init"
        opts["directory"] == "foo"
        opts["file"] == "bar"
        "help" notin opts

    withParams "init foo bar baz":
      check:
        opts["command"] == "init"
        opts["directory"] == "foo"
        opts["file"] == "bar"
        opts["help"] == "true"

  test "Positional arguments for unpack":
    withParams "unpack":
      check:
        opts["command"] == "unpack"
        "directory" notin opts
        "file" notin opts
        "help" notin opts

    withParams "unpack foo":
      check:
        opts["command"] == "unpack"
        opts["target"] == "foo"
        "file" notin opts
        "help" notin opts

    withParams "unpack foo bar":
      check:
        opts["command"] == "unpack"
        opts["target"] == "foo"
        opts["file"] == "bar"
        "help" notin opts

    withParams "unpack foo bar baz":
      check:
        opts["command"] == "unpack"
        opts["target"] == "foo"
        opts["file"] == "bar"
        opts["help"] == "true"

  test "Positional arguments for list":
    withParams "list":
      check:
        opts["command"] == "list"
        "target" notin opts

    withParams "list foo":
      check:
        opts["command"] == "list"
        opts["target"] == "foo"

    withParams "list foo bar":
      check:
        opts["command"] == "list"
        opts["target"] == "foo"
        opts["help"] == "true"

  test "Positional arguments for pack loop added to target list":
    let commands = ["convert", "compile", "pack", "install", "play", "test", "serve"]
    for command in commands:
      withParams command & " foo":
        check:
          opts["command"] == command
          opts["targets"] == "foo"

    for command in commands:
      withParams command & " foo bar":
        check:
          opts["command"] == command
          opts["targets"] == "foo;bar"

  test "No value required for -h or --help":
    withParams "-h", "--help":
      check: opts["help"] == "true"

  test "No value required for -v or --version":
    withParams "-v", "--version":
      check: opts["version"] == "true"

  test "Parse --[no-]color as flags or options":
    withParams "--color", "--color=true", "--no-color=false":
      check getShowColor()

    withParams "--no-color", "--no-color=true", "--color=false":
      check not getShowColor()
    
    withParams "--color=auto", "--no-color=auto":
      check getShowColor() == stdout.isatty

    for params in ["--color=foo", "--no-color=foo"]:
      expect SyntaxError:
        withParams params:
          discard

  test "Set forced answer with --yes, --no, and --default":
    withParams "-y", "--yes":
      check getForceAnswer() == Yes

    withParams "-n", "--no":
      check getForceAnswer() == No

    withParams "--default":
      check getForceAnswer() == Default

  test "Set verbosity with --debug, --verbose, and --quiet":
    withParams "--debug":
      check getLogLevel() == DebugPriority

    withParams "--verbose":
      check getLogLevel() == LowPriority

    withParams "--quiet":
      check getLogLevel() == HighPriority

  test "Set config operation with --get, --set, --unset, or --list":
    withParams "config -g", "config --get":
      check opts["configOp"] == "get"

    withParams "config -s", "config --set":
      check opts["configOp"] == "set"

    withParams "config -u", "config --unset":
      check opts["configOp"] == "unset"

    withParams "config -l", "config --list":
      check opts["configOp"] == "list"

  test "Set config scope with --global or --local":
    withParams "config --global":
      check opts["configScope"] == "global"

    withParams "config --local":
      check opts["configScope"] == "local"

  test "Set config key and value as arguments":
    withParams "config foo":
      check:
        opts["configKey"] == "foo"
        "configValue" notin opts

    withParams "config foo bar":
      check:
        opts["configKey"] == "foo"
        opts["configValue"] == "bar"

    withParams "config -- nssFlags -lowqey":
      check:
        opts["configKey"] == "nssFlags"
        opts["configValue"] == "-lowqey"

  test "Set config key and value as option":
    withParams "config --foo":
      check:
        opts["configKey"] == "foo"
        opts["configValue"] == ""

    withParams "config --foo bar":
      check:
        opts["configKey"] == "foo"
        opts["configValue"] == "bar"

    withParams "config --nssFlags -lowqey":
      check:
        opts["configKey"] == "nssFlags"
        opts["configValue"] == "-lowqey"

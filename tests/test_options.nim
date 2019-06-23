import os, unittest

import nasher/options

suite "Command-line flags":
  test "Show help when no arguments given":
    check parseCmdLine(@[""]).showHelp

  test "Show help when unknown command given":
    check:
      parseCmdLine(@["foo"]).showHelp

  test "Show help with -h, --help":
    check:
      parseCmdLine(@["-h"]).showHelp
      parseCmdLine(@["--help"]).showHelp

  test "Show help for command with -h, --help":
    let
      short = parseCmdLine(@["list", "-h"])
      long = parseCmdLine(@["list", "--help"])

    check:
      short.showHelp and short.cmd.kind == ckList
      long.showHelp and long.cmd.kind == ckList

  test "Show version with -v, --version":
    check:
      parseCmdLine(@["-v"]).showVersion
      parseCmdLine(@["--version"]).showVersion

  test "Load additional configs with -c , --config":
    var
      configs = @[getUserCfgFile()]
    
    check: # User config only
      parseCmdLine(@[""]).configs == configs
      parseCmdLine(@["init"]).configs == configs
    
    configs.add(getPkgCfgFile("foo"))
    check: # User + package config
      parseCmdLine(@["unpack", "bar.mod", "foo"]).configs == configs
    
    configs = @["a.cfg"]
    check: # Override default configs
      parseCmdLine(@["-c: a.cfg"]).configs == configs
      parseCmdLine(@["--config: a.cfg"]).configs == configs

    configs.add("b.cfg")
    check: # Override default configs with multiple configs
      parseCmdLine(@["-c: a.cfg", "-c = b.cfg"]).configs == configs
      parseCmdLine(@["--config: a.cfg", "--config = b.cfg"]).configs == configs



  test "Unknown flag raises exception":
    expect NasherError:
      discard parseCmdLine(@["-z"])

    expect NasherError:
      discard parseCmdLine(@["--foo"])

suite "init":
  test "'nasher init' initializes to current directory":
    let
      opts = parseCmdLine(@["init"])

    check:
      opts.cmd.kind == ckInit
      opts.cmd.dir == getCurrentDir()
      opts.cmd.file == ""

  test "'nasher init foo' initializes to foo":
    let
      opts = parseCmdLine(@["init", "foo"])

    check:
      opts.cmd.kind == ckInit
      opts.cmd.dir == "foo"
      opts.cmd.file == ""

  test "'nasher init foo bar.mod' initializes foo with contents of bar.mod":
    let
      opts = parseCmdLine(@["init", "foo", "bar.mod"])

    check:
      opts.cmd.kind == ckInit
      opts.cmd.dir == "foo"
      opts.cmd.file == "bar.mod"

suite "unpack":
  test "'nasher unpack' shows help for command":
    let
      opts = parseCmdLine(@["unpack"])

    check:
      opts.cmd.kind == ckUnpack
      opts.cmd.file == ""
      opts.showHelp

  test "'nasher unpack bar.mod' unpacks bar.mod to ./src":
    let
      opts = parseCmdLine(@["unpack", "bar.mod"])

    check:
      opts.cmd.kind == ckUnpack
      opts.cmd.file == "bar.mod"
      opts.cmd.dir == getCurrentDir() / "src"

  test "'nasher unpack bar.mod foo' unpacks bar.mod to foo":
    let
      opts = parseCmdLine(@["unpack", "bar.mod", "foo"])

    check:
      opts.cmd.kind == ckUnpack
      opts.cmd.file == "bar.mod"
      opts.cmd.dir == "foo"

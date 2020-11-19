import os, strformat
import nasher/[init, list, config, unpack, convert, compile, pack, install, launch]
import nasher/utils/[cli, git, options, shared]

const
  NimblePkgVersion {.strdefine.} = "devel"

  helpAll = """
  nasher: a build tool for Neverwinter Nights projects

  Usage:
    nasher init [options] [<dir> [<file>]]
    nasher list [options]
    nasher (convert|compile|pack|install|play|test|serve) [options] [<target>...]
    nasher unpack [options] [<target> [<file>]]
    nasher config [options] <key> [<value>]

  Commands:
    init           Initializes a nasher repository
    list           Lists the names and descriptions of all build targets
    convert        Converts all json sources to their gff targets
    compile        Compiles all nss sources for a build target
    pack           Converts, compiles, and packs all sources for a build target
    install        As pack, but installs the target file to the NWN install path
    serve          As install, but starts the module with nwserver after installing
    play           As install, but starts the module with nwmain after installing
    test           As play, but automatically selects the first localvault PC
    unpack         Unpacks a target's installed file into the source tree
    config         Gets, sets, or unsets user-defined configuration options

  Global Options:
    -h, --help     Display help for nasher or one of its commands
    -v, --version  Display version information

  Logging:
    --debug        Enable debug logging
    --verbose      Enable additional messages about normal operation
    --quiet        Disable all logging except errors
    --no-color     Disable color output (automatic if not a tty)
  """

proc ctrlCQuit {.noconv.} =
  quit(QuitFailure)

when isMainModule:
  setControlCHook(ctrlCQuit)
  try:
    var
      opts = getOptions()
      pkg = new(PackageRef)
      branch = opts.get("branch", "none")

    let
      cmd = opts.get("command")
      help = opts.get("help", not opts.hasKey("command"))
      version = opts.get("version", false)
      dir = opts.getOrPut("directory", getCurrentDir())

    if version:
      echo "nasher " & NimblePkgVersion
      quit(QuitSuccess)

    if help:
      case cmd
      of "config": help(helpConfig)
      of "init": help(helpInit)
      of "list": help(helpList)
      of "convert": help(helpConvert)
      of "compile": help(helpCompile)
      of "pack": help(helpPack)
      of "install": help(helpInstall)
      of "unpack": help(helpUnpack)
      of "play", "test", "serve": help(helpLaunch)
      else: help(helpAll)

    if cmd notin ["init", "config", "list"]:
      opts.verifyBinaries

    if cmd notin ["init", "config"] and
       not loadPackageFile(pkg, getPackageFile()):
         fatal("This is not a nasher project. Please run nasher init.")

    case cmd
    of "config":
      config(opts)
    of "init":
      if init(opts, pkg):
        unpack(opts, pkg)
    of "unpack":
      unpack(opts, pkg)
    of "list":
      list(opts, pkg)
    of "convert", "compile", "pack", "install", "play", "test", "serve":
      let targets = pkg.getTargets(opts.get("targets"))
      for target in targets:
        opts["target"] = target.name
        if branch == "none":
          branch = target.branch
        if branch.len > 0:
          display("VCS Branch:", gitSetBranch(dir, branch))

        if convert(opts, pkg) and
           compile(opts, pkg) and
           pack(opts, pkg) and
           install(opts, pkg):
             launch(opts)
    else:
      help(helpAll, QuitFailure)
  except NasherError:
    error(getCurrentExceptionMsg())
    quit(QuitFailure)
  except:
    error("An unknown error occurred. Please file a bug report at " &
          "https://github.com/squattingmonk/nasher.nim/issues using the " &
          "stack trace info below:")
    raise

import nasher/[init, list, config, unpack, convert, compile, pack, install, launch]
import nasher/utils/[cli, options, shared]

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

when isMainModule:
  var
    opts = getOptions()
    pkg = new(PackageRef)

  let
    cmd = opts.get("command")
    help = opts.get("help", false)
    version = opts.get("version", false)

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

  if cmd notin ["config", "list"] and not opts.verifyBinaries:
    fatal("Could not locate required binaries. Aborting...")

  if cmd notin ["init", "config", "unpack"] and
     not loadPackageFile(pkg, getPackageFile()):
       fatal("This is not a nasher project. Please run nasher init.")

  case cmd
  of "config":
    config(opts)
  of "init":
    init(opts, pkg)
    unpack(opts, pkg)
  of "unpack":
    unpack(opts, pkg)
  of "list":
    list(opts, pkg)
  of "convert", "compile", "pack", "install", "play", "test", "serve":
    let targets = pkg.getTargets(opts.get("targets"))
    for target in targets:
      opts["target"] = target.name
      if convert(opts, pkg) and
         compile(opts, pkg) and
         pack(opts, pkg) and
         install(opts, pkg):
           launch(opts)
  else:
    help(helpAll, QuitFailure)

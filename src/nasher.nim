import os
import nasher/[init, list, config, unpack, convert, compile, pack, install, launch]
import nasher/utils/[git, shared]

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

template withTargets(pkgFile: string, opts: Options, body: untyped): untyped =
  ## Iterates over the targets in `pkgFile`, running `body` on all those wanted
  ## by `opts`. If the user or target has specified a git branch, the 
  let targets = parsePackageFile(pkgFile)
  if targets.len == 0:
    fatal("No targets found. Please check your nasher.cfg.")

  try:
    for target {.inject.} in targets.filter(opts.get("targets")):
      let branch  = opts.get("branch", target.branch)
      if branch.len > 0:
        display("Git Branch:", gitSetBranch(dir, branch))
      body
  except KeyError as e:
    fatal(e.msg)

when isMainModule:
  setControlCHook(ctrlCQuit)
  try:
    var
      opts = newOptions()
      globalConfigFile = getConfigFile()
      localConfigFile = getConfigFile(getCurrentDir())

    if fileExists(globalConfigFile):
      opts.parseFile(globalConfigFile)
    if fileExists(localConfigFile):
      opts.parseFile(localConfigFile)

    opts.parseCommandLine

    if opts.get("version", false):
      echo "nasher " & NimblePkgVersion
      quit()

    if opts.get("help", not opts.hasKey("command")):
      help(
        case opts.get("command")
        of "config": helpConfig
        of "init": helpInit
        of "list": helpList
        of "convert": helpConvert
        of "compile": helpCompile
        of "pack": helpPack
        of "install": helpInstall
        of "unpack": helpUnpack
        of "play", "test", "serve": helpLaunch
        else: helpAll)

    let
      cmd = opts.get("command")
      dir = opts.getOrPut("directory", getCurrentDir())
      pkgFile = getPackageFile()

    if not fileExists(pkgFile) and cmd != "init" and
      not (cmd == "config" and opts.get("configScope", "global") == "global"):
        fatal("This is not a nasher project. Please run 'nasher init'.")

    withEnv([("NWN_ROOT", getNwnRootDir()),
             ("NWN_HOME", getNwnHomeDir())]):
      case cmd
      of "config":
        config(opts)
      of "init":
        if init(opts):
          withTargets(getPackageFile(dir), opts):
            unpack(opts, target)
      of "list":
        list()
      of "unpack", "convert", "compile", "pack", "install", "play", "test", "serve":
        withTargets(pkgFile, opts):
          if cmd == "unpack":
            unpack(opts, target)
          else:
            var updatedNss: seq[string]
            if convert(opts, target, updatedNss) and
               compile(opts, target, updatedNss) and
               pack(opts, target) and
               install(opts, target):
                 launch(opts, target)
      else:
        help(helpAll, QuitFailure)
  except SyntaxError, PackageError:
    fatal(getCurrentExceptionMsg())
  except:
    error("An unknown error occurred. Please file a bug report at " &
          "https://github.com/squattingmonk/nasher/issues using the " &
          "stack trace info below:")
    raise

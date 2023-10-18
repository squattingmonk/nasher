import os
import nasher/[init, list, config, unpack, convert, compile, pack, install, launch]
import nasher/utils/[git, shared]

const
  NimblePkgVersion {.strdefine.} = "devel"

  helpAll = """
nasher: a build tool for Neverwinter Nights projects

Usage:
  nasher init [options] [<dir> [<file>]]
  nasher list [options] [<target>...]
  nasher (convert|compile|pack|install|play|test|serve) [options] [<target>...]
  nasher unpack [options] [<target>...]
  nasher config [options] <key> [<value>]

Commands:
  init                   Create a new nasher project
  list                   List the names, files, and descriptions of targets
  convert                Convert json sources to gff
  compile                Convert gff, then compile nss scripts
  pack                   Convert gff, compile scripts, then pack a target
  install                As pack, but install the target file after packing
  serve                  As install, but load the installed module with nwserver
  play                   As install, but load the installed module with nwmain
  test                   As play, but play as the first localvault PC
  unpack                 Unpack an installed file into the source tree
  config                 Get, set, or unset user-defined configuration options

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
        if not opts.hasKey("targets"):
          opts["targets"] = "all"
        var hasRun = false
        withTargets(pkgFile, opts):
          if hasRun:
            stdout.write("\n")
          list(target)
          hasRun = true
      of "unpack", "convert", "compile", "pack", "install", "play", "test", "serve":
        withTargets(pkgFile, opts):
          if cmd == "unpack":
            unpack(opts, target)
          else:
            var updatedNss: seq[string]
            var exitCode = QuitSuccess
            if convert(opts, target, updatedNss) and
               compile(opts, target, updatedNss, exitCode) and
               pack(opts, target) and
               install(opts, target):
                 launch(opts, target)
            if exitCode != QuitSuccess:
              quit(exitCode)
      else:
        help(helpAll, QuitFailure)
  except SyntaxError, PackageError:
    fatal(getCurrentExceptionMsg())
  except CatchableError:
    error("An unknown error occurred. Please file a bug report at " &
          "https://github.com/squattingmonk/nasher/issues using the " &
          "stack trace info below:")
    raise

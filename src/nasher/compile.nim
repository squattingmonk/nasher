from sequtils import toSeq
import os, tables, strtabs, strutils

import utils/[cli, compiler, options, shared]

const
  helpCompile* = """
  Usage:
    nasher compile [options] [<target>]

  Description:
    Compiles all nss sources for <target>. If <target> is not supplied, the first
    target supplied by the config files will be compiled. The input and output
    files are placed in .nasher/cache/<target>.

    Compilation of scripts is handled automatically by 'nasher pack', so you only
    need to use this if you want to compile the scripts without converting gff
    sources and packing the target file.

  Options:
    --clean        Clears the cache directory before compiling

  Global Options:
    -h, --help     Display help for nasher or one of its commands
    -v, --version  Display version information

  Logging:
    --debug        Enable debug logging
    --verbose      Enable additional messages about normal operation
    --quiet        Disable all logging except errors
    --no-color     Disable color output (automatic if not a tty)
  """

proc compile*(opts: Options, pkg: PackageRef) =
  let
    cmd = opts["command"]

  if opts.getBoolOrDefault("help"):
    # Make sure the correct command handles showing the help text
    if cmd == "compile": help(helpCompile)
    else: return

  let
    cacheDir = opts["directory"]
    target = pkg.getTarget(opts["target"])
    compiler = opts.getOrDefault("nssCompiler", findExe("nwnsc"))
    userFlags = opts.getOrDefault("nssFlags", "-lowqey")
    targetFlags = target.flags.join(" ")

  withDir(cacheDir):
    let
      scripts = toSeq(walkFiles("*.nss"))

    # TODO: async
    # TODO: Only compile scripts that have not been compiled since update
    if scripts.len > 0:
      display("Compiling", $scripts.len & " scripts")
      let errCode = runCompiler(compiler, [userFlags, targetFlags, "*.nss"])
      if errCode != 0 and cmd in ["pack", "install"] and
        not askIf("Do you want to continue $1ing anyway?" % [cmd]):
          quit(QuitFailure)
    else:
      display("Skipping", "compilation: nothing to compile")

  # Prevent falling through to the next function if we were called directly
  if cmd == "compile":
    quit(QuitSuccess)

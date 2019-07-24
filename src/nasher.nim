import nasher/[init, list, config, unpack, convert, compile, pack, install]
import nasher/utils/[cli, options, shared]

const
  nasherVersion = "0.4.1"

  helpAll = """
  nasher: a build tool for Neverwinter Nights projects

  Usage:
    nasher init [options] [<dir> [<file>]]
    nasher list [options]
    nasher compile [options] [<target>]
    nasher pack [options] [<target>]
    nasher install [options] [<target>]
    nasher unpack [options] <file> [<dir>]
    nasher config [options] <key> [<value>]

  Commands:
    init           Initializes a nasher repository
    list           Lists the names and descriptions of all build targets
    convert        Converts all json sources to their gff targets
    compile        Compiles all nss sources for a build target
    pack           Converts, compiles, and packs all sources for a build target
    install        As pack, but installs the target file to the NWN install path
    unpack         Unpacks a file into the source tree
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
    cmd = opts.getOrDefault("command")
    version = opts.getBoolOrDefault("version")

  if version:
    echo "nasher " & nasherVersion
    quit(QuitSuccess)

  case cmd
  of "config":
    config(opts)
  of "init":
    init(opts, pkg)
    unpack(opts, pkg)
  of "list":
    list(opts, pkg)
  of "convert", "compile", "pack", "install":
    convert(opts, pkg)
    compile(opts, pkg)
    pack(opts, pkg)
    install(opts, pkg)
  of "unpack":
    unpack(opts, pkg)
  else:
    help(helpAll, QuitFailure)

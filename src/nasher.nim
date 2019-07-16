import nasher/[init, list, unpack, compile, pack, install]
import nasher/[cli, shared]
from nasher/config import Config
from nasher/options import parseCmdLine

const
  nasherVersion = "0.3.0"

  helpAll = """
  nasher: a build tool for Neverwinter Nights projects

  Usage:
    nasher init [options] [<dir> [<file>]]
    nasher list [options]
    nasher compile [options] [<target>]
    nasher pack [options] [<target>]
    nasher install [options] [<target>]
    nasher unpack [options] <file> [<dir>]

  Commands:
    init           Initializes a nasher repository
    list           Lists the names and descriptions of all build targets
    compile        Compiles all nss sources for a build target
    pack           Converts, compiles, and packs all sources for a build target
    install        As pack, but installs the target file to the NWN install path
    unpack         Unpacks a file into the source tree

  Global Options:
    -h, --help     Display help for nasher or one of its commands
    -v, --version  Display version information
    --config FILE  Use FILE rather than the package config file

  Logging:
    --debug        Enable debug logging
    --verbose      Enable additional messages about normal operation
    --quiet        Disable all logging except errors
    --no-color     Disable color output (automatic if not a tty)
  """

when isMainModule:
  var
    opts = parseCmdLine()
    cfg: Config

  let
    cmd = opts.get("command")
    version = opts.getBool("version")

  if version:
    echo "nasher " & nasherVersion
    quit(QuitSuccess)

  case cmd
  of "init":
    init(opts, cfg)
    unpack(opts, cfg)
  of "list":
    list(opts, cfg)
  of "compile", "pack", "install":
    compile(opts, cfg)
    pack(opts, cfg)
    install(opts, cfg)
  of "unpack":
    unpack(opts, cfg)
  else:
    help(helpAll, QuitFailure)

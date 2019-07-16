from tables import len, values
from strutils import join, split
import cli, config, shared

const
  helpList = """
  Usage:
    nasher list [options]

  Description:
    Lists the names of all build targets. These names can be passed to the compile
    or pack commands. If called with --verbose, also lists the descriptions,
    source files, and the filename of the final target.

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

proc list*(opts: Options, cfg: var Config) =
  if opts.getBool("help"):
    help(helpList)

  if not isNasherProject():
    fatal("This is not a nasher project. Please run nasher init.")

  let config = opts.get("config", getPkgCfgFile())
  cfg = initConfig(getGlobalCfgFile(), config)

  if cfg.targets.len > 0:
    var hasRun = false
    for target in cfg.targets.values:
      if hasRun:
        stdout.write("\n")
      display("Target:", target.name)
      display("Description:", target.description)
      display("File:", target.file)
      display("Sources:", target.sources.join("\n"))
      hasRun = true
  else:
    fatal("No targets found. Please check your nasher.cfg.")

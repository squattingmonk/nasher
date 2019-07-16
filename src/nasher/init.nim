import os
import cli, config, shared

const
  helpInit = """
  Usage:
    nasher init [options] [<dir> [<file>]]

  Description:
    Initializes a directory as a nasher project. If supplied, <dir> will be
    created if needed and set as the project root; otherwise, the current
    directory will be the project root.

    If supplied, <file> will be unpacked into the project root's source tree.

  Options:
    --default      Automatically accept the default answers to prompts

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

proc init*(opts: Options, cfg: var Config) =
  if opts.getBool("help"):
    help(helpInit)

  let
    dir = opts.get("directory", getCurrentDir())
    pkgFile = dir / "nasher.cfg"

  if not existsFile(pkgFile):
    display("Initializing", "into " & dir)
    cfg = initConfig(getPkgCfgFile(), pkgFile)

    # Check if we should unpack a file
    if opts.get("file") == "":
      success("project initialized")
      quit(QuitSuccess)
  else:
    fatal(dir & " is already a nasher project")

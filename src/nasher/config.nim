import os
from strutils import escape
import utils/[cli, options, shared]

const
  helpConfig* = """
  Usage:
    nasher config [options] <key> [<value>]

  Description:
    Gets, sets, or unsets user-defined configuration options. These options can be
    local (package-specific) or global (across all packages). Regardless, they
    override default nasher settings.

    Global configuration is stored %APPDATA%\nasher\user.cfg on Windows or in
    $XDG_CONFIG/nasher/user.cfg on Linux and Mac. These values apply to all
    packages.

    Local (package-level) configuration is stored in .nasher/user.cfg in the
    package root directory. Any values defined here take precedence over those in
    the global config file. This file will be ignored by git.

  Options:
    --global       Apply to all packages (default)
    --local        Apply to the current package only
    -g, --get      Get the value of <key> (default when <value> is not passed)
    -s, --set      Set <key> to <value> (default when <value> is passed)
    -u, --unset    Delete the key/value pair for <key>
    -l, --list     Lists all key/value pairs in the config file

  Global Options:
    -h, --help     Display help for nasher or one of its commands
    -v, --version  Display version information

  Logging:
    --debug        Enable debug logging
    --verbose      Enable additional messages about normal operation
    --quiet        Disable all logging except errors
    --no-color     Disable color output (automatic if not a tty)
  """

proc getConfigCmd(opts: Options): string =
  result = opts.get("configOp")
  case result
  of "list":
    if "configKey" in opts or "configValue" in opts:
      result = ""
  of "get", "unset":
    if "configKey" notin opts or "configValue" in opts:
      result = ""
  of "set":
    if "configKey" notin opts or "configValue" notin opts:
      result = ""
  of "":
    if "configKey" in opts and "configValue" in opts:
      result = "set"
    elif "configKey" in opts:
      result = "get"
  else:
    result = ""

proc writeConfigFile(opts: Options, file: string) =
  try:
    createDir(file.splitFile.dir)
    opts.writeFile(file)
  except:
    fatal(getCurrentExceptionMsg())

proc config*(opts: Options) =
  let cmd = opts.getConfigCmd
  if cmd == "":
    help(helpConfig)

  let
    dir = opts.get("directory", getCurrentDir())
    scope = opts.get("configScope", "global")
    file = getConfigFile(if scope == "local": dir else: "")
    cfg = newOptions()

  if fileExists(file):
    cfg.parseFile(file)

  case cmd
  of "list":
    for key, val in cfg.sortedPairs:
      echo key, " = ", val.escape
  of "get":
    let key = opts["configKey"]
    if cfg.hasKey(key):
      echo cfg[key]
  of "set":
    cfg[opts["configKey"]] = opts["configValue"]
    cfg.writeConfigFile(file)
  of "unset":
    cfg.del(opts["configKey"])
    cfg.writeConfigFile(file)
  else:
    assert false

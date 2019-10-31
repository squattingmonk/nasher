import os
from algorithm import sorted
from sequtils import toSeq
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
    --get          Get the value of <key> (default when <value> is not passed)
    --set          Set <key> to <value> (default when <value> is passed)
    --unset        Delete the key/value pair for <key>
    --list         Lists all key/value pairs in the config file

  Global Options:
    -h, --help     Display help for nasher or one of its commands
    -v, --version  Display version information

  Logging:
    --debug        Enable debug logging
    --verbose      Enable additional messages about normal operation
    --quiet        Disable all logging except errors
    --no-color     Disable color output (automatic if not a tty)
  """

proc parseConfigCmd(opts: Options): string =
  result = opts.get("config")
  case result
  of "list":
    if "key" in opts or "value" in opts:
      result = ""
  of "get", "unset":
    if "value" in opts or "key" notin opts:
      result = ""
  of "set":
    if "key" notin opts or "value" notin opts:
      result = ""
  of "":
    if "key" in opts and "value" in opts:
      result = "set"
    elif "key" in opts:
      result = "get"
  else:
    result = ""

proc config*(opts: Options) =
  let cmd = opts.parseConfigCmd
  if cmd == "":
    help(helpConfig)

  let
    dir = opts.get("directory", getCurrentDir())
    level = opts.get("level", "global")

  if level == "local" and not existsPackageFile(dir):
    fatal("This is not a nasher repository. Please run init")

  let file = getConfigFile(if level == "local": dir else: "")
  var cfg = newOptions(file)

  case cmd
  of "list":
    let keys = toSeq(cfg.keys).sorted
    for key in keys:
      echo key, " = ", cfg[key]
  of "get":
    let key = opts["key"]
    if cfg.hasKey(key):
      echo cfg[key]
  of "set":
    cfg[opts["key"]] = opts["value"]
    cfg.writeConfigFile(file)
  of "unset":
    cfg.del(opts["key"])
    cfg.writeConfigFile(file)
  else:
    assert false

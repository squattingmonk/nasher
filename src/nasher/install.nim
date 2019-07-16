import os, strformat

import cli, config, shared

const
  helpInstall* = """
  Usage:
    nasher install [options] [<target>]

  Description:
    Converts, compiles, and packs all sources for <target>, then installs the
    packed file into the NWN installation directory. If <target> is not supplied,
    the first target found in the config files will be packed and installed.

    The location of the NWN install can be set in the [User] section of the global
    nasher configuration file (default '~/Documents/Neverwinter Nights').

    If the file to be installed would overwrite an existing file, you will be
    prompted to overwrite it. The default answer is to keep the newer file.

  Options:
    --clean        clears the cache directory before packing
    --yes, --no    Automatically answer yes/no to the overwrite prompt
    --default      Automatically accept the default answer to the overwrite prompt

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

proc install*(opts: Options, cfg: var Config) =
  if opts.getBool("help"):
    help(helpInstall)

  let
    file = getPkgRoot() / opts.get("file")
    dir = opts.get("install", getNwnInstallDir())

  display("Installing", file & " into " & dir)
  if not existsFile(file):
    fatal(fmt"Cannot install {file}: file does not exist")

  let
    fileTime = file.getLastModificationTime
    fileName = file.extractFilename
    installDir = expandTilde(
      case fileName.splitFile.ext
      of ".erf": dir / "erf"
      of ".hak": dir / "hak"
      of ".mod": dir / "modules"
      else: dir)

  if not existsDir(installDir):
    fatal(fmt"Cannot install to {installDir}: directory does not exist")

  let installed = installDir / fileName
  if existsFile(installed):
    let
      installedTime = installed.getLastModificationTime
      timeDiff = getTimeDiff(fileTime, installedTime)
      defaultAnswer = if timeDiff > 0: Yes else: No
    
    hint(getTimeDiffHint(fileName, installed, timeDiff))
    if not askIf(fmt"{installed} already exists. Overwrite?", defaultAnswer):
      quit(QuitSuccess)

  copyFile(file, installed)
  setLastModificationTime(installed, fileTime)
  success("installed " & fileName)

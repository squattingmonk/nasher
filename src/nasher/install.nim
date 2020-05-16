import os, strformat

import utils/[cli, nwn, options, shared]

const
  helpInstall* = """
  Usage:
    nasher install [options] [<target>...]

  Description:
    Converts, compiles, and packs all sources for <target>, then installs the
    packed file into the NWN installation directory. If <target> is not supplied,
    the first target found in the package will be packed and installed.

    If the file to be installed would overwrite an existing file, you will be
    prompted to overwrite it. The default answer is to keep the newer file.

    The default install location is '~/Documents/Neverwinter Nights' for Windows
    and Mac or `~/.local/share/Neverwinter Nights` on Linux.

  Options:
    --clean        Clears the cache directory before packing
    --yes, --no    Automatically answer yes/no to prompts
    --default      Automatically accept the default answer to prompts

  Global Options:
    -h, --help     Display help for nasher or one of its commands
    -v, --version  Display version information

  Logging:
    --debug        Enable debug logging
    --verbose      Enable additional messages about normal operation
    --quiet        Disable all logging except errors
    --no-color     Disable color output (automatic if not a tty)
  """

proc install*(opts: Options, pkg: PackageRef): bool =
  let
    cmd = opts["command"]
    file = opts["file"]
    dir = opts.getOrPut("installDir", getNwnInstallDir()).expandPath

  if opts.get("noInstall", false):
    return cmd != "install"

  display("Installing", file & " into " & dir)
  if not existsFile(file):
    fatal(fmt"Cannot install {file}: file does not exist")

  if not existsDir(dir):
    fatal(fmt"Cannot install to {dir}: directory does not exist")

  let
    (_, name, ext) = file.splitFile
    fileTime = file.getLastModificationTime
    fileName = name & ext
    installDir =
      case ext
      of ".erf": dir / "erf"
      of ".hak": dir / "hak"
      of ".mod": dir / "modules"
      of ".tlk": dir / "tlk"
      else: dir

  if not existsDir(installDir):
    createDir(installDir)

  let installed = installDir / fileName
  if existsFile(installed):
    let
      installedTime = installed.getLastModificationTime
      timeDiff = getTimeDiff(fileTime, installedTime)
      defaultAnswer = if timeDiff >= 0: Yes else: No

    hint(getTimeDiffHint("The file to be installed", timeDiff))
    if not askIf(fmt"{installed} already exists. Overwrite?", defaultAnswer):
      return ext == ".mod" and cmd != "install" and
             askIf(fmt"Do you still wish to {cmd} {filename}?")

  copyFile(file, installed)
  setLastModificationTime(installed, fileTime)

  if (ext == ".mod" and opts.get("useModuleFolder", true)):
    let
      modFolder = installDir / name
      erfUtil = opts.get("erfUtil")
      erfFlags = opts.get("erfFlags")

    if not existsDir(modFolder):
      createDir(modFolder)

    withDir(modFolder):
      for file in walkFiles("*"):
        file.removeFile

      display("Extracting", fmt"module to {modFolder}")
      extractErf(installed, erfUtil, erfFlags)

  success("installed " & fileName)

  # Prevent falling through to the next function if we were called directly
  return cmd != "install"

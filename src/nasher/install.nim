import os, strformat, strutils

import utils/[nwn, shared]

const helpInstall* = """
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
$#
""" % InstallOpts

proc install*(opts: Options, target: Target): bool =
  let
    cmd = opts["command"]
    file = target.file
    dir = opts.getOrPut("installDir", getNwnHomeDir()).expandPath

  if opts.get("noInstall", false):
    return cmd != "install"

  display("Installing", file & " into " & dir)
  if not fileExists(file):
    fatal(fmt"Cannot install {file}: file does not exist")

  if not dirExists(dir):
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

  if not dirExists(installDir):
    createDir(installDir)

  let installed = installDir / fileName
  if fileExists(installed):
    let
      installedTime = installed.getLastModificationTime
      timeDiff = getTimeDiff(fileTime, installedTime)
      currentAnswer = getForceAnswer()
      defaultAnswer = if timeDiff >= 0: Yes else: No

    # Here we temporarily override the user's forced answer. We do this so if
    # the user passed both --yes / --no and --overwriteInstalledFile=ask, we can
    # ask the user for input. After we ask, we set the forced answer back so any
    # other prompts will be answered as the user intended.
    case opts.get("overwriteInstalledFile", "")
    of "ask": setForceAnswer(None)
    of "default": setForceAnswer(Default)
    of "always": setForceAnswer(Yes)
    of "never": setForceAnswer(No)
    of "": discard
    else:
      fatal("--overwriteInstalledFile must be one of [ask, default, always, never]")

    hint(getTimeDiffHint("The file to be installed", timeDiff))
    if not askIf(fmt"{installed} already exists. Overwrite?", defaultAnswer):
      setForceAnswer(currentAnswer)
      return ext == ".mod" and cmd != "install" and
             askIf(fmt"Do you still wish to {cmd} {filename}?")
    setForceAnswer(currentAnswer)

  copyFile(file, installed)
  setLastModificationTime(installed, fileTime)

  if (ext == ".mod" and opts.get("useModuleFolder", true)):
    let
      modFolder = installDir / name
      erfUtil = opts.findBin("erfUtil", "nwn_erf", "erf utility")
      erfFlags = opts.get("erfFlags")

    if not dirExists(modFolder):
      createDir(modFolder)

    withDir(modFolder):
      for file in walkFiles("*"):
        file.removeFile

      display("Extracting", fmt"module to {modFolder}")
      extractErf(installed, erfUtil, erfFlags)

  success("installed " & fileName)

  # Prevent falling through to the next function if we were called directly
  return cmd != "install"

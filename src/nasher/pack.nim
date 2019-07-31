import os, strformat
from sequtils import toSeq

import utils/[cli, nwn, options, shared]

const
  helpPack* = """
  Usage:
    nasher pack [options] [<target>]

  Description:
    Converts, compiles, and packs all sources for <target>. If <target> is not
    supplied, the first target supplied by the config files will be packed. The
    assembled files are placed in $PKG_ROOT/.nasher/build/<target>, but the packed
    file is placed in $PKG_ROOT.

    If the packed file would overwrite an existing file, you will be prompted to
    overwrite the file. The newly packaged file will have a modification time
    equal to the modification time of the newest source file. If the packed file
    is newer than the existing file, the default is to overwrite the existing file.

  Options:
    --clean        Clears the cache directory before packing
    --yes, --no    Automatically answer yes/no to the overwrite prompt
    --default      Automatically accept the default answer to the overwrite prompt

  Global Options:
    -h, --help     Display help for nasher or one of its commands
    -v, --version  Display version information

  Logging:
    --debug        Enable debug logging
    --verbose      Enable additional messages about normal operation
    --quiet        Disable all logging except errors
    --no-color     Disable color output (automatic if not a tty)
  """

proc getNewestFile(dir: string): string =
  for file in walkFiles(dir / "*"):
    if file.splitFile.ext == ".ncs":
      continue
    try:
      if fileNewer(file, result):
        result = file
    except OSError:
      # This is the first file we've checked
      result = file

proc pack*(opts: Options, pkg: PackageRef): bool =
  let
    file = opts["file"]
    target = opts["target"]
    cacheDir = opts["directory"]
    fileTime = getNewestFile(cacheDir).getLastModificationTime

  display("Packing", fmt"files for target {target} into {file}")
  if existsFile(file):
    let
      packTime = file.getLastModificationTime
      timeDiff = getTimeDiff(fileTime, packTime)
      defaultAnswer = if timeDiff > 0: Yes else: No
    
    hint(getTimeDiffHint("The packed file", timeDiff))
    if not askIf(fmt"{file} already exists. Overwrite?", defaultAnswer):
      return false

  let
    sourceFiles = toSeq(walkFiles(cacheDir / "*"))
    root = getPackageRoot(cacheDir)
    bin = opts.get("erfUtil", findExe("nwn_erf", root))
    args = opts.get("erfFlags")

  createErf(sourceFiles, file, bin, args)
  success("packed " & file)
  setLastModificationTime(file, fileTime)

  # Prevent falling through to the next function if we were called directly
  return opts["command"] != "pack"

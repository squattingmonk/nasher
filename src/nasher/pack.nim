import os, strformat

import glob

import utils/[cli, manifest, nwn, options, shared]

const
  helpPack* = """
  Usage:
    nasher pack [options] [<target>...]

  Description:
    Converts, compiles, and packs all sources for <target>. If <target> is not
    supplied, the first target supplied by the config files will be packed. The
    assembled files are placed in $PKG_ROOT/.nasher/cache/<target>, but the packed
    file is placed in $PKG_ROOT.

    If the packed file would overwrite an existing file, you will be prompted to
    overwrite the file. The newly packaged file will have a modification time
    equal to the modification time of the newest source file. If the packed file
    is older than the existing file, the default is to keep the existing file.

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
    cmd = opts["command"]

  if opts.get("noPack", false):
    return cmd != "pack"

  let
    file = opts["file"]
    target = opts["target"]
    cacheDir = opts["directory"]
    fileTime = getNewestFile(cacheDir).getLastModificationTime

  display("Packing", fmt"files for target {target} into {file}")

  if fileExists(file):
    let
      packTime = file.getLastModificationTime
      timeDiff = getTimeDiff(fileTime, packTime)
      defaultAnswer = if timeDiff >= 0: Yes else: No

    hint(getTimeDiffHint("The file to be packed", timeDiff))
    if not askIf(fmt"{file} already exists. Overwrite?", defaultAnswer):
      return cmd != "pack" and askIf(fmt"Continue installing {file}?")
  else:
    file.parentDir.createDir

  let
    bin = opts.get("erfUtil")
    args = opts.get("erfFlags")

  var
    manifest = newManifest(target)

  if file.getFileExt == "tlk":
    let fileName = file.extractFilename
    try:
      copyFile(cacheDir / fileName, file)
    except OSError:
      fatal(fmt"No file found. Does {fileName}.json exist in the source tree?")
  else:
    let packDir = ".nasher" / "pack"
    removeDir(packDir)
    copyDirWithPermissions(cacheDir, packDir)
    const globOpts = {IgnoreCase, Hidden, Files}
    for filter in pkg.getTarget(target).filters:
      for file in glob.walkGlob(filter, packDir, globOpts):
        info("Filtering", file)
        removeFile(packDir / file)

    createErf(packDir, file, bin, args)

  for file in walkFiles(cacheDir / "*"):
    if file.splitFile.ext != ".ncs":
      manifest.add(file, fileTime)

  manifest.write

  success("packed " & file)
  setLastModificationTime(file, fileTime)

  # Prevent falling through to the next function if we were called directly
  return cmd != "pack"

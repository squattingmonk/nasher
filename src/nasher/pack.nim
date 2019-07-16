import os, strformat
from sequtils import toSeq

import cli, config, shared, utils

const
  helpPack = """
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

proc pack*(opts: Options, cfg: var Config) =
  let
    cmd = opts.get("command")

  if opts.getBool("help"):
    # Make sure the correct command handles showing the help text
    if cmd == "pack": help(helpPack)
    else: return

  let
    file = opts.get("file")
    target = opts.get("target")
    cacheDir = opts.get("directory")
    fileTime = getNewestFile(cacheDir).getLastModificationTime
    packed = relativePath(getPkgRoot() / file, getCurrentDir())

  display("Packing", fmt"files for target {target} into {file}")
  if existsFile(packed):
    let
      installedTime = packed.getLastModificationTime
      timeDiff = getTimeDiff(fileTime, installedTime)
      defaultAnswer = if timeDiff > 0: Yes else: No
    
    hint(getTimeDiffHint("The packed file", timeDiff))
    if not askIf(fmt"{packed} already exists. Overwrite?", defaultAnswer):
      quit(QuitSuccess)

  let
    sourceFiles = toSeq(walkFiles(cacheDir / "*"))
    exitCode = createErf(file, sourceFiles)

  if exitCode == 0:
    success("packed " & file)
    setLastModificationTime(packed, fileTime)

    # Prevent falling through to the next function if we were called directly
    if cmd == "pack":
      quit(QuitSuccess)
  else:
    fatal("Something went wrong!")

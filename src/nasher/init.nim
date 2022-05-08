import os
import utils/[cli, git, options]

const
  helpInit* = """
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

  Logging:
    --debug        Enable debug logging
    --verbose      Enable additional messages about normal operation
    --quiet        Disable all logging except errors
    --no-color     Disable color output (automatic if not a tty)
  """

proc init*(opts: Options, pkg: PackageRef): bool =
  let
    dir = opts.getOrPut("directory", getCurrentDir())
    file = dir / "nasher.cfg"

  if fileExists(file):
    fatal(dir & " is already a nasher project")

  display("Initializing", "into " & dir)

  try:
    createDir(dir)
  except OSError:
    fatal("Could not create package directory: " & getCurrentExceptionMsg())
  except IOError:
    fatal("Could not create package directory: a file named " & dir & " already exists")

  display("Creating", "package file at " & file)
  var f: File
  if open(f, file, fmWrite):
    try:
      f.write(genPackageText(opts))
    finally:
      f.close
  else:
    error("Cannot open " & file)
    fatal("Could not create package file at " & file)
    writeFile(file, genPackageText(opts))
  success("created package file")

  # TODO: support hg
  if opts.getOrPut("vcs", "git") == "git":
    try:
      display("Initializing", "git repository")
      if gitInit(dir):
        gitIgnore(dir)
      success("initialized git repository")
    except:
      error("Could not initialize git repository: " & getCurrentExceptionMsg())

  success("project initialized")

  # Check if we should unpack a file
  if opts.hasKey("file"):
    opts.verifyBinaries
    result = true

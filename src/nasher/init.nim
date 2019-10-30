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

proc init*(opts: Options, pkg: PackageRef) =
  let
    dir = opts.getOrPut("directory", getCurrentDir())
    file = dir / "nasher.cfg"

  if existsFile(file):
    fatal(dir & " is already a nasher project")

  display("Initializing", "into " & dir)

  try:
    display("Creating", "package file at " & file)
    createDir(dir)
    writeFile(file, genPackageText(opts))
    success("created package file")
  except:
    fatal("Could not create package file at " & file)

  # TODO: support hg
  if opts.getOrPut("vcs", "git") == "git":
    try:
      display("Initializing", "git repository")
      if gitInit(dir):
        gitIgnore(dir)
      success("initialized git repository")
    except:
      error("Could not initialize git repository: " & getCurrentExceptionMsg())

  # Check if we should unpack a file
  if opts.get("file") == "":
    success("project initialized")
    quit(QuitSuccess)

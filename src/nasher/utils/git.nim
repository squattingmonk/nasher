import os, osproc, strutils, uri

from shared import withDir

proc gitExecCmd(cmd: string, default = ""): string =
  ## Runs ``cmd``, returning its output on success or ``default`` on error.
  let (output, errCode) = execCmdEx(cmd)
  if errCode != 0:
    default
  else:
    # Remove trailing newline
    output.strip

proc gitUser*: string =
  ## Returns the configured git username or "" on failure.
  gitExecCmd("git config --get user.name")

proc gitEmail*: string =
  ## Returns the configured git email or "" on failure.
  gitExecCmd("git config --get user.email")

proc gitRepo*(dir = getCurrentDir()): bool =
  ## Returns whether ``dir`` is a git repo.
  withDir(dir):
    gitExecCmd("git rev-parse --is-inside-work-tree") != "true"

proc gitRemote*(dir = getCurrentDir()): string =
  ## Returns the remote for the git project in ``dir``. Supports ssh formatted
  ## remotes.
  withDir(dir):
    result = gitExecCmd("git ls-remote --get-url")

    if result != "":
      if result.endsWith(".git"):
        result.setLen(result.len - 4)

      if result.parseUri.scheme == "":
        let ssh = parseUri("ssh://" & result)
        result = ("https://$1/$2$3") % [ssh.hostname, ssh.port, ssh.path]

proc gitInit*(dir = getCurrentDir()): bool =
  ## Initializes dir as a git repository and returns whether the operation was
  ## successful. Will throw an OSError if dir does not exist.
  withDir(dir):
     execCmdEx("git init").exitCode == 0

proc gitIgnore*(dir = getCurrentDir(), force = false) =
  ## Creates a .gitignore file in ``dir`` if one does not already exist or if
  ## ``force`` is true. Will throw an OSError if ``dir`` does not exist.
  const
    file = ".gitignore"
    text = """
    # Ignore packed files
    *.erf
    *.hak
    *.mod

    # Ignore the nasher directory
    .nasher/
    """
  if force or not existsFile(dir / file):
    writeFile(dir / file, text.unindent(4))

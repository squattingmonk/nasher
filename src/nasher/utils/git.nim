import os, osproc, strformat, strutils, uri
import cli

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
    gitExecCmd("git rev-parse --is-inside-work-tree") == "true"

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
  ## successful. Will throw an OSError if dir does not exist.  Init empty commit
  ## made on branch `master` to force branch recognition
  var exitCode: int

  withDir(dir):
    exitCode = execCmdEx("git init").exitCode
    if exitCode == 0:
      discard execCmdEx("git commit --allow-empty -m \"root commit\"")

  result = exitCode == 0

proc gitExistsBranch(dir: string, branch: string): bool =
  ## Determines if passed branch exists in passed repository
  withDir(dir):
    gitExecCmd("git show-ref --verify refs/heads/" & branch, "error") != "error"
    #gitExecCmd("git branch --list " & branch, "error") != "error"

proc gitBranch*(dir = getCurrentDir()): string =
  ## Return name of the current branch
  withDir(dir):
    gitExecCmd("git rev-parse --abbrev-ref HEAD", "master")

proc gitCheckoutBranch(dir: string, branch: string, create = false) =
  # Checkout desired branch, if it exists.  If not, prompts for creation or
  # uses of current branch
  if not gitExistsBranch(dir, branch):
    if create:
      withDir(dir):
        discard execCmdEx("git checkout -b " & branch)
    else:
      if askIf(fmt"Git branch '{branch}' was not found.  Create it?"):
        gitCheckoutBranch(dir, branch, true)
  else:
    withDir(dir):
      discard execCmdEx("git checkout " & branch)

proc gitSetBranch*(dir = getCurrentDir(), branch: string) =
  ## Called if the branch option was specified in configuration or command line.  If the current
  ## branch is not the specified branch, will checkout the specified branch, if it exists
  if gitRepo(dir):
    if branch.len > 0 and gitBranch(dir) != branch:
      gitCheckoutBranch(dir, branch)
    else:
      if branch.len == 0:
        error("git branch could not be determined, using current branch.")

    display("Git Branch:", gitBranch(dir))

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
    *.tlk

    # Ignore the nasher directory
    .nasher/
    """
  if force or not existsFile(dir / file):
    writeFile(dir / file, text.unindent(4))

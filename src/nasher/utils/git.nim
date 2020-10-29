import os, osproc, strformat, strutils, uri
import cli

from shared import withDir

var lastError: string

proc gitExecCmd(cmd: string, default = ""): string =
  ## Runs ``cmd``, returning its output on success or ``default`` on error.
  let (output, errCode) = execCmdEx(cmd)
  if errCode != 0:
    lastError = output.strip
    default
  else:
    # Remove trailing newline
    lastError = ""
    output.strip

proc gitUser*: string =
  ## Returns the configured git username or "" on failure.
  gitExecCmd("git config --get user.name")

proc gitEmail*: string =
  ## Returns the configured git email or "" on failure.
  gitExecCmd("git config --get user.email")

proc gitRemote*(repo = getCurrentDir()): string =
  ## Returns the remote for the git project in ``dir``. Supports ssh formatted
  ## remotes.
  withDir(repo):
    result = gitExecCmd("git ls-remote --get-url")

    if result != "":
      if result.endsWith(".git"):
        result.setLen(result.len - 4)

      if result.parseUri.scheme == "":
        let ssh = parseUri("ssh://" & result)
        result = ("https://$1/$2$3") % [ssh.hostname, ssh.port, ssh.path]

proc gitInit*(repo = getCurrentDir()): bool =
  ## Initializes dir as a git repository and returns whether the operation was
  ## successful. Will throw an OSError if dir does not exist.
  withDir(repo):
    execCmdEx("git init").exitCode == 0

proc empty(repo: string): bool =
  # Check if repo has any commits
  withDir(repo):
    gitExecCmd("git branch --list", "none").len == 0

proc exists(repo: string): bool =
  # Check for repo existence
  withDir(repo):
    gitExecCmd("git rev-parse --is-inside-work-tree") == "true"

proc exists(branch: string, repo: string): bool =
  # Check for branch existence
  withDir(repo):
    gitExecCmd("git show-ref --verify refs/heads/" & branch, "error") != "error"

proc checkout(branch: string, repo: string, create = false): bool = 
  # Checkout desired branch, if it exists.  If not, prompts for creation or
  # uses of current branch.  If can't checkout because of an error, do something else?
  if create:
    withDir(repo):
      gitExecCmd("git checkout -b " & branch, "error") != "error"
  else:
    withDir(repo):
      gitExecCmd("git checkout " & branch, "error") != "error"

proc branch(repo: string, default = ""): string =
  # Gets the current repo branch
  withDir(repo):
    gitExecCmd("git rev-parse --abbrev-ref HEAD", default)

proc create(repo: string, branch: string):bool =
  # Wrapper function for checkout; creates a new git branch in repo
  branch.checkout(repo, true)

proc gitSetBranch*(repo = getCurrentDir(), branch: string): string =
  ## Called if the branch option was specified in configuration or command line
  if repo.exists:
    if branch.exists(repo):
      if repo.branch == branch:
        result = branch
      else:
        if branch.checkout(repo):
          result = repo.branch
        else:
          error(lastError)
          fatal(fmt"You must resolve the git repo error before you can continue on branch {branch}")
    else:
      if repo.empty:
        let question = "Nasher cannot determine the status of this repo because there have not been any commits. " &
                       fmt"Continue the operation on branch {branch}?"

        if askIf(question):
          if repo.create(branch): 
            if branch != "master":
              warning("check repo structure, orphan branch may have been created")

            result = branch
          else: fatal(fmt"branch {branch} could not be created")
        else:
          fatal("operation aborted by user")
      else:
        if repo.create(branch): result = branch
  else:
    result = "this folder is not a git repository"

proc gitIgnore*(repo = getCurrentDir(), force = false) =
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
  if force or not fileExists(repo / file):
    writeFile(repo / file, text.unindent(4))
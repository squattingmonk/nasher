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
  ## successful. Will throw an OSError if dir does not exist.
  withDir(dir):
    execCmdEx("git init").exitCode == 0

proc empty(repo: string): bool =
  # See if this is a new repo with no commits yet
  withDir(repo):
    gitExecCmd("git branch --list", "none").len == 0

proc exists(repo: string): bool =
  # Check for repo existence
  gitRepo(repo)

proc exists(branch: string, dir: string): bool =
  # Check for branch existence
  withDir(dir):
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

proc create(branch: string, repo: string):bool =
  branch.checkout(repo, true)

proc gitSetBranch*(repo = getCurrentDir(), branch: string): string =
  ## Called if the branch option was specified in configuration or command line
  if repo.exists:
    #Specific branch requested
    if branch.exists(repo):
      # Requested branch exists
      if repo.branch == branch:
        # We're already on the requested branch
        result = branch
      else:
        # We're not on the requested branch, switch
        if branch.checkout(repo):
          # We've switched to the requested branch successfully
          result = repo.branch
        else:
          # Some error preventing the switch, uncommitted or unmerged?
          # Do something to resolve the issue...


          result = "none"
    else:
      # Requested branch doesn't exist
      if repo.empty:
        # Repo doesn't have any commits yet
        let question = "Nasher cannot determine the status of this repo because there have not been any commits. " &
                       fmt"Continue the operation on branch {branch}?"

        if askIf(question):
          if branch.create(repo): 
            if branch != "master":
              warning("check repo structure, orphan branch may have been created")

            result = branch
          else: fatal(fmt"branch {branch} could not be created")
        else:
          fatal("operation aborted by user")
      else:
        # There are commits, just that this branch doesn't exist yet
        if branch.create(repo):
          result = branch
  else:
    result = "none"

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
  if force or not fileExists(dir / file):
    writeFile(dir / file, text.unindent(4))

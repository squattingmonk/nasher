import os, osproc, strformat, strutils, uri
import cli

from shared import withDir

proc gitUser*: string =
  ## Returns the configured git username or "" on failure.
  let gitResult = execCmdEx("git config --get user.name")

  if gitResult.exitCode == 0:
    gitResult.output.strip
  else: ""

proc gitEmail*: string =
  ## Returns the configured git email or "" on failure.
  let gitResult = execCmdEx("git config --get user.email")

  if gitResult.exitCode == 0:
    gitResult.output.strip
  else: ""

proc gitRemote*(repo = getCurrentDir()): string =
  withDir(repo):
    let url = execCmdEx("git ls-remote --get-url")
    result = url.output

    if url.exitCode == 0:
      if result.endsWith(".git"):
        result.setLen(result.len - 4)

      if result.parseUri.scheme == "":
        let ssh = parseUri("ssh://" & result)
        result = ("https://$1/$2$3") % [ssh.hostname, ssh.port, ssh.path]
    else: result = ""

proc gitInit*(repo = getCurrentDir()): bool =
  ## Initializes dir as a git repository and returns whether the operation was
  ## successful. Will throw an OSError if dir does not exist.
  withDir(repo):
    execCmdEx("git init").exitCode == 0

proc empty(repo: string): bool =
  ## Check if repo has any commits
  withDir(repo):
    execCmdEx("git branch --list").output.strip == ""

proc exists(repo: string): bool =
  ## Check for repo existence
  withDir(repo):
    execCmdEx("git rev-parse --is-inside-work-tree").output.strip == "true"

proc exists(branch: string, repo: string): bool =
  ## Check for branch existence
  withDir(repo):
    execCmdEx(fmt"git show-ref --verify refs/heads/{branch}").exitCode == 0
  
proc branch(repo: string, default = ""): string =
  ## Gets the current repo branch
  withDir(repo):
    execCmdEx("git rev-parse --abbrev-ref HEAD").output.strip

proc checkout(branch: string, repo: string, create = false, throw = false): bool = 
  ## Checkout desired branch, if it exists. If not, prompts for creation or
  ## uses of current branch. If can't checkout because of an error, do something else?
  var
    flag = ""
    suffix = ""
  
  if create:
    flag = "-b "
    if repo.branch != "master" and not repo.empty and "master".exists(repo):
      const
        choiceMaster = "Create branch from master"
        choiceCurrent = "Create branch from current branch"
        choiceQuit = "Abort the operation"
        
      let 
        question = fmt"This operation will create a branch from {repo.branch} instead of master. What would you like to do?"
        choices = [choiceMaster, choiceCurrent, choiceQuit]

      case choose(question, choices)
      of choiceMaster:
        suffix = " master"
      of choiceQuit:
        quit(QuitSuccess)

  withDir(repo):
    let gitResult = execCmdEx(fmt"git checkout {flag}{branch}{suffix}")

    result = gitResult.exitCode == 0
    if not result and throw:
      error(gitResult.output)

proc create(repo: string, branch: string):bool =
  ## Wrapper function for checkout; creates a new git branch in repo
  branch.checkout(repo, create = true)

proc gitSetBranch*(repo = getCurrentDir(), branch: string): string =
  ## Called if the branch option was specified in configuration or command line
  if repo.exists:
    if branch.exists(repo):
      if repo.branch == branch:
        result = branch
      else:
        if branch.checkout(repo, throw = true):
          result = repo.branch
        else:
          fatal(fmt"{branch} could not be checked out. Resolve all git repo errors before continuing.")
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
    result = "this folder is not a vcs repository"

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

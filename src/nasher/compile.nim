from sequtils import distribute, apply
import os, tables, strtabs, strutils, pegs, sequtils

import utils/[cli, compiler, options, shared]

const
  helpCompile* = """
  Usage:
    nasher compile [options] [<target>...]

  Description:
    Compiles all nss sources for <target>. If <target> is not supplied, the first
    target supplied by the config files will be compiled. The input and output
    files are placed in .nasher/cache/<target>.

    Compilation of scripts is handled automatically by 'nasher pack', so you only
    need to use this if you want to compile the scripts without converting gff
    sources and packing the target file.

  Options:
    --clean            Clears the cache directory before compiling
    -f, --file:<file>  Compiles <file> only. Can be repeated.
    --branch:<branch>  Selects git branch before operation.

  Global Options:
    -h, --help         Display help for nasher or one of its commands
    -v, --version      Display version information

  Logging:
    --debug            Enable debug logging
    --verbose          Enable additional messages about normal operation
    --quiet            Disable all logging except errors
    --no-color         Disable color output (automatic if not a tty)
  """


proc executable(script: string): bool =
  ## Returns whether ``script`` contains a main() or StartingConditional()
  ## function and is thus executable nwscript.
  var
    comment: bool

  let
    pExec = peg"""
      execfunc <- (mlcomment / \s)* (main / conditional) \s* '(' \s* ')'
      main <- 'void' \s+ 'main'
      conditional <- 'int' \s+ 'StartingConditional'
      mlcomment <- @ '*/'
      """
    pCommentOpen = peg"""
      copen <- (@ strlit)* @ '/*' !@ '*/'
      strlit <- '"' @ '"'
      """
    pCommentClose = peg"@ '*/'"

  for line in script.lines:
    if comment:
      if line.match(pCommentClose):
        comment = false
      else:
        continue
    if line.match(pExec):
      return true
    elif line.match(pCommentOpen):
      comment = true

iterator getIncluded(file: string): string =
  ## Yields all files inluded in the nwscript file ``file``.
  var
    comment: bool

  let
    pInclude = peg"""
      file <- ^\s* '#include' \s+ '"' {\ident+} '"' (\s / comment)*$
      comment <- '/*' @ '*/' / '//' .*
      """
    pCommentOpen = peg"""
      open <- (@ strlit)* @ '/*' !@ '*/'
      strlit <- '"' @ '"'
      """
    pCommentClose = peg"""
      close <- @ '*/'
      """

  for line in file.lines:
    if comment:
      if line.match(pCommentClose):
        comment = false
    else:
      if line =~ pInclude:
        yield matches[0]
      elif line.match(pCommentOpen):
        comment = true

proc getIncludes(scripts: seq[string]): Table[string, seq[string]] =
  ## Returns a table listing scripts included by each script in ``scripts``.
  for script in scripts:
    for name in script.getIncluded:
      let file = name.addFileExt("nss")
      debug(script & " includes " & file)
      if result.hasKeyOrPut(script, @[file]) and file notin result[script]:
        result[script].add(file)

proc getIncludesUpdated(file: string,
                        scripts: Table[string, seq[string]],
                        updated: var Table[string, bool]): bool =
  ## Returns whether ``file`` includes a script that has been updated. Will
  ## follow nested includes.
  if updated.hasKeyOrPut(file, false):
    return updated[file]

  if scripts.hasKey(file):
    for script in scripts[file]:
      if script.getIncludesUpdated(scripts, updated):
        updated[file] = true
        return true

proc getUpdated(pkg: PackageRef, files: seq[string]): seq[string] =
  let included = files.getIncludes
  var updated: Table[string, bool]

  for file in pkg.updated:
    updated[file] = true

  for file in files:
    if file.getIncludesUpdated(included, updated):
      result.add(file)

  pkg.updated = result

proc confirmCompilation(dir: string, executables: seq[string]) =
  let
    compiled = toSeq(walkFiles(dir / "*.ncs")).mapIt(it.splitFile.name) 

  var
    unmatchedNcs: seq[string]

  for executable in executables:
    if executable.changeFileExt("ncs") notin compiled:
      unmatchedNcs.add(executable.changeFileExt("nss"))

  if unmatchedNcs.len > 0:
    warning("The following executable scripts do not have matching .ncs files due to an unknown nwnsc error: " & unmatchedNcs.join(", "))
  else:
    success("All executable scripts have a matching compiled (.ncs) script");

proc compile*(opts: Options, pkg: PackageRef): bool =
  let
    cmd = opts["command"]
    target = pkg.getTarget(opts["target"])

  var
    executables: seq[string]

  if opts.get("noCompile", false):
    return cmd != "compile"

  withDir(opts["directory"]):
    # If we are only compiling one file...
    var scripts: seq[string]
    if cmd == "compile" and opts.hasKey("files"):
      for file in opts["files"].split(';'):
        let
          fileName = file.extractFilename
          pkgRoot = getPackageRoot()

        if file == fileName and fileExists(file):
          info("Found", fileName & " in target cache")
          scripts.add(fileName)
        elif (fileExists(file) and target.isSrcFile(file.relativePath(pkgRoot))) or # absolute
             (fileExists(pkgRoot / file) and target.isSrcFile(file)):               # relative
               info("Found", fileName & " at " & file)
               scripts.add(fileName)
        else:
          fatal("Cannot compile $1: not in sources for target \"$2\"" %
                [file, target.name])
    else:
      # Only compile scripts that have not been compiled since update
      var files: seq[string]

      for file in walkFiles("*.nss"):
        files.add(file)
        if file.executable:
          executables.add(file)
        
          if file notin pkg.updated:
            let compiled = file.changeFileExt("ncs")
            if not fileExists(compiled) or file.fileNewer(compiled):
              debug("Recompiling", "executable script " & file)
              pkg.updated.add(file)

      scripts = pkg.getUpdated(files)

    let
      compiler = opts.get("nssCompiler")
      userFlags = opts.get("nssFlags", "-lowqey").parseCmdLine

    if scripts.len > 0:
      var errors = false
      let
        chunkSize = opts.get("nssChunks", 500)
        chunks = scripts.len div chunkSize + 1
      display("Compiling", $scripts.len & " scripts")
      for chunk in distribute(scripts, chunks):
        let args = userFlags & target.flags & chunk
        if runCompiler(compiler, args) != 0:
          errors = true

      if errors:
        warning("Errors encountered during compilation (see above)")
        if cmd in ["pack", "install", "serve", "test", "play"] and not
          askIf("Do you want to continue $#ing?" % [cmd]):
            return false
      success("compiled " & $scripts.len & " scripts")
    else:
      display("Skipping", "compilation: nothing to compile")

    confirmCompilation(opts["directory"], executables)

  # Prevent falling through to the next function if we were called directly
  return cmd != "compile"

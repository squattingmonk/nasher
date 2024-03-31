import os, tables, strtabs, strutils, pegs, sequtils

import utils/[compiler, shared]

const helpCompile* = """
Usage:
  nasher compile [options] [<target>...]

Description:
  Compiles all nss sources for <target>. If <target> is not supplied, the first
  target supplied by the config files will be compiled. The input files are
  placed in .nasher/cache/<target>.  The output files are placed in the same
  folder unless the compiler flags `-b` (for nwnsc`) or `-o`/`-d` (for
  nwn_script_comp) are specified.

  Compilation of scripts is handled automatically by 'nasher pack', so you only
  need to use this if you want to compile the scripts without converting gff
  sources and packing the target file.

Options:
$#
""" % CompileOpts

proc isSrcFile(target: Target, file: string): bool =
  ## Returns whether `file` is a source file of `target`.
  file.matchesAny(target.includes) and not file.matchesAny(target.excludes)

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

proc getUpdated(updatedNSS: var seq[string], files: seq[string]): seq[string] =
  let included = files.getIncludes
  var updated: Table[string, bool]

  for file in updatedNss:
    updated[file] = true

  for file in files:
    if file.getIncludesUpdated(included, updated):
      result.add(file)

  updatedNss = result

proc getFlags(compiler: Compiler, opts: Options, target: Target): seq[string] =
  let nssFlags = opts.get("nssFlags", compilerFlags[compiler.ord]).parseCmdLine
  var flags = nssFlags & target.flags

  case compiler:
    of Organic:
      let
        installDir = opts.get("installDir", getEnv("NWN_HOME")).expandPath
        rootDir = getNwnRootDir().expandPath

      if installDir.len > 0: flags = flags & "--userdirectory" & installDir
      if rootDir.len > 0: flags = flags & "--root" & rootDir

      result = flags & "-c"
    of Legacy:
      result = flags

proc compile*(opts: Options, target: Target, updatedNss: var seq[string], exitCode: var int): bool =
  let
    cmd = opts["command"]
    cacheDir = (".nasher" / "cache" / target.name)
    abortOnCompileError =
      if opts.hasKey("abortOnCompileError"):
        if opts.get("abortOnCompileError", false): Answer.No
        else: Answer.Yes
      else: Answer.None

  var
    executables: seq[string]

  if opts.get("noCompile", false):
    return cmd != "compile"

  let
    bin = opts.findBin("nssCompiler", $Compiler.low, "script compiler")
    compiler = parseEnum[Compiler](bin.splitPath.tail.splitFile.name, Compiler.low)

  withDir(cacheDir):
    # If we are only compiling one file...
    var scripts: seq[string]
    let skips = target.skips.mapIt(it.extractFilename)

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

          if file notin updatedNss:
            let compiled = file.changeFileExt("ncs")
            if not fileExists(compiled) or file.fileNewer(compiled):
              debug("Recompiling", "executable script " & file)
              updatedNss.add(file)

      scripts = getUpdated(updatedNss, files)
      for script in scripts:
        ## Ensure any updated scripts have their compiled version deleted so
        ## they will be re-compiled if compilation fails for some reason.
        removeFile(script.changeFileExt("ncs"))
        removeFile(script.changeFileExt("ndb"))
      
    scripts.keepItIf(it notin skips)
    if scripts.len > 0:
      let
        chunkSize = opts.get("nssChunks", 500)
        chunks = scripts.len div chunkSize + 1
      display("Compiling", $scripts.len & " scripts")
      for chunk, scripts in distribute(scripts, chunks):
        if chunks > 1:
          info("Compiling", "$1 scripts (chunk $2/$3)" % [$scripts.len, $(chunk + 1), $chunks])

        let args = compiler.getFlags(opts, target) & scripts
        if runCompiler(bin, args) != 0:
          warning("Errors encountered during compilation (see above)")
          if chunk + 1 < chunks:
            let forced = getForceAnswer()
            if abortOnCompileError != Answer.None:
              setForceAnswer(abortOnCompileError)
            hint("This was chunk $1 out of $2" % [$(chunk + 1), $chunks])
            if not askIf("Do you want to continue compiling?"):
              setForceAnswer(forced)
              exitCode = QuitFailure
              return false
    else:
      display("Skipping", "compilation: nothing to compile")

    executables.keepItIf(not fileExists(it.changeFileExt("ncs")) and it notin skips)
    if executables.len > 0:
      warning("Compiled only $1 of $2 scripts. The following executable scripts do not have matching .ncs:\n$3" %
        [$(scripts.len - executables.len), $scripts.len, executables.join(", ")])
      if cmd in ["pack", "install", "serve", "test", "play"]:
        let forced = getForceAnswer()
        if abortOnCompileError != Answer.None:
          setForceAnswer(abortOnCompileError)
        if not askIf("Do you want to continue to $#?" % [cmd]):
          setForceAnswer(forced)
          exitCode = QuitFailure
          return false
        setForceAnswer(forced)
      else:
        exitCode = QuitFailure
    else:
      success("All executable scripts have a matching compiled (.ncs) script file", LowPriority);
      if scripts.len > 0:
        success("Compiled $1 scripts" % $scripts.len)

  # Prevent falling through to the next function if we were called directly
  return cmd != "compile"

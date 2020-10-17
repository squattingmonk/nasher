from sequtils import distribute, apply
import os, tables, strscans, strtabs, strutils

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

  Global Options:
    -h, --help         Display help for nasher or one of its commands
    -v, --version      Display version information

  Logging:
    --debug            Enable debug logging
    --verbose          Enable additional messages about normal operation
    --quiet            Disable all logging except errors
    --no-color         Disable color output (automatic if not a tty)
  """

const
  patternMain = "$svoid$smain$s($s)"
  patternCond = "$sint$sStartingConditional$s($s)"

proc executable(script: string): bool =
  ## Returns whether ``script`` contains a main() or StartingConditional()
  ## function and is thus executable nwscript.
  for line in script.lines:
    if scanf(line, patternMain) or scanf(line, patternCond):
      return true

iterator getIncluded(file: string): string =
  ## Yields all files inluded in the nwscript file ``file``.
  var included: string

  for line in file.lines:
    # Cannot just search for ascii identifiers because nwscript files can start
    # with a number
    if scanf(line, "$s#include$s\"$*\"", included):
      var i = 0
      while i < included.len and included[i] in IdentChars:
        i.inc

      if i == included.len:
        yield included

proc getIncludes(scripts: seq[string]): Table[string, seq[string]] =
  ## Returns a table listing scripts included by each script in ``scripts``.
  for script in scripts:
    for name in script.getIncluded:
      let file = name.addFileExt("nss")
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

proc compile*(opts: Options, pkg: PackageRef): bool =
  let
    cmd = opts["command"]
    target = pkg.getTarget(opts["target"])

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
        if file notin pkg.updated and file.executable:
          let compiled = file.changeFileExt("ncs")
          if not fileExists(compiled) or file.fileNewer(compiled):
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

  # Prevent falling through to the next function if we were called directly
  return cmd != "compile"

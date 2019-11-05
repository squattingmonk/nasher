from sequtils import toSeq, concat, deduplicate
import os, tables, strtabs, strutils

import utils/[cli, compiler, options, shared]

import regex

const
  helpCompile* = """
  Usage:
    nasher compile [options] [<target>]

  Description:
    Compiles all nss sources for <target>. If <target> is not supplied, the first
    target supplied by the config files will be compiled. The input and output
    files are placed in .nasher/cache/<target>.

    Compilation of scripts is handled automatically by 'nasher pack', so you only
    need to use this if you want to compile the scripts without converting gff
    sources and packing the target file.

  Options:
    --clean        Clears the cache directory before compiling

  Global Options:
    -h, --help     Display help for nasher or one of its commands
    -v, --version  Display version information

  Logging:
    --debug        Enable debug logging
    --verbose      Enable additional messages about normal operation
    --quiet        Disable all logging except errors
    --no-color     Disable color output (automatic if not a tty)
  """

proc executable(script: string): bool =
  let text = readFile(script)
  text.contains(re"(void[\t ]+main|int[\t ]+StartingConditional)")

proc getIncludedBy(scripts: seq[string]): Table[string, seq[string]] =
  ## Returns a table listing scripts that include a file in ``scripts``.
  for script in scripts:
    let text = readFile(script)
    for match in text.findAll(re"""(?m:^\s*#include\s+"(.*)"\s*$)"""):
      let dependency = text[match.group(0)[0]] & ".nss"
      if result.hasKeyOrPut(dependency, @[script]) and
         script notin result[dependency]:
           result[dependency].add(script)

proc getAllIncludedBy(file: string,
                      scripts: Table[string, seq[string]],
                      processed: var Table[string, bool]): seq[string] =
  ## Lists all scripts in ``scripts`` that include ``file``, even through
  ## intermediates. ``processed`` is used to track whether a script has already
  ## been checked.
  if not scripts.hasKey(file):
    return @[]

  result = scripts[file]
  for script in scripts[file]:
    if not processed.hasKeyOrPut(script, true):
      result = result.concat(script.getAllIncludedBy(scripts, processed))
  result = result.deduplicate

proc compile*(opts: Options, pkg: PackageRef): bool =
  let
    cmd = opts["command"]

  if opts.get("noCompile", false):
    return cmd != "compile"

  withDir(opts["directory"]):
    # Only compile scripts that have not been compiled since update
    let
      files = toSeq(walkFiles("*.nss"))

    for file in files:
      if file notin pkg.updated and file.executable:
        let compiled = file.changeFileExt("ncs")
        if not existsFile(compiled) or file.fileNewer(compiled):
          pkg.updated.add(file)

    var
      processed: Table[string, bool]
      included = getIncludedBy(files)
      toCompile = pkg.updated

    for script in pkg.updated:
      let included = script.getAllIncludedBy(included, processed)
      toCompile = toCompile.concat(included).deduplicate

    let
      root = getPackageRoot()
      scripts = toCompile.len
      target = pkg.getTarget(opts["target"])
      compiler = opts.get("nssCompiler", findExe("nwnsc", root))
      userFlags = opts.get("nssFlags", "-lowqey").parseCmdLine
      args = userFlags & target.flags & toCompile

    if scripts > 0:
      display("Compiling", $scripts  & " scripts")
      if runCompiler(compiler, args) != 0:
        warning("Errors encountered during compilation (see above)")
        if cmd in ["pack", "install"] and not
          askIf("Do you want to continue $#ing?" % [cmd]):
            return false
    else:
      display("Skipping", "compilation: nothing to compile")

  # Prevent falling through to the next function if we were called directly
  return cmd != "compile"

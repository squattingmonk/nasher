from sequtils import toSeq
import os, tables, strtabs, strutils

import utils/[cli, compiler, options, shared]

import regex

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

proc getIncludes(scripts: seq[string]): Table[string, seq[string]] =
  ## Returns a table listing scripts included by each script in ``scripts``.
  for script in scripts:
    let text = readFile(script)
    for match in text.findAll(re"""(?m:^\s*#include\s+"(.*)"\s*$)"""):
      let included = text[match.group(0)[0]] & ".nss"
      if result.hasKeyOrPut(script, @[included]) and
        included notin result[script]:
          result[script].add(included)

proc getIncludesUpdated(file: string,
                        scripts: Table[string, seq[string]],
                        updated: var Table[string, bool]): bool =
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

    let
      scripts = pkg.getUpdated(files)
      target = pkg.getTarget(opts["target"])
      compiler = opts.get("nssCompiler")
      userFlags = opts.get("nssFlags", "-lowqey").parseCmdLine
      args = userFlags & target.flags & scripts

    if scripts.len > 0:
      display("Compiling", $scripts.len  & " scripts")
      if runCompiler(compiler, args) != 0:
        warning("Errors encountered during compilation (see above)")
        if cmd in ["pack", "install"] and not
          askIf("Do you want to continue $#ing?" % [cmd]):
            return false
    else:
      display("Skipping", "compilation: nothing to compile")

  # Prevent falling through to the next function if we were called directly
  return cmd != "compile"

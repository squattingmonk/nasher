import os, parseopt, parsecfg, streams, strformat, strtabs, strutils
from sequtils import toSeq
from algorithm import sorted
export strtabs

import cli, git, shared

type
  Options* = StringTableRef

  Package = object
    name*, description*, version*, url*: string
    authors*, includes*, excludes*, filters*, flags*, updated*: seq[string]
    targets*: seq[Target]
    rules*: seq[Rule]

  PackageRef* = ref Package

  Target = object
    name*, file*, description*: string
    includes*, excludes*, filters*, flags*: seq[string]
    rules*: seq[Rule]

  Rule* = tuple[pattern, dir: string]

const
  nasherCommands =
    ["init", "list", "config", "convert", "compile", "pack", "install", "play",
     "test", "serve", "unpack"]

proc `[]=`*[T: int | bool](opts: Options, key: string, value: T) =
  ## Overloaded ``[]=`` operator that converts value to a string before setting
  ## as to opts[key]
  opts[key] = $value

proc hasKeyOrPut*[T: string|int|bool](
  opts: Options, key: string, value: T): bool =
  ## Returns true if ``key`` is in ``opts``. Otherwise, sets ``opts[key]`` to
  ## ``value`` and returns false. If ``value`` is not a string, it will be
  ## converted to one.
  if hasKey(opts, key):
    result = true
  else:
    opts[key] = value

proc getOrPut*[T: string|bool](opts: Options, key: string, value: T): T =
  ## Returns the value located at opts[key]. If the key does not exist, it is
  ## set to value, which is returned.
  if opts.contains(key):
    when T is bool:
      try:
        let tmpValue = opts[key]
        result = tmpValue == "" or tmpValue.parseBool
      except ValueError:
        result = value
    else:
      result = opts[key]
  else:
    opts[key] = value
    result = value

proc getBoolOrDefault(opts: Options, key: string, default = false): bool =
  ## Returns the boolean value located at opts[key]; "" is treated as true. If
  ## there is no value or it cannot be conveted to a bool, returns default.
  result = default
  if opts.contains(key):
    try:
      let value = opts[key]
      result = value == "" or value.parseBool
    except ValueError:
      discard

proc getIntOrDefault(opts: Options, key: string, default = 0): int =
  ## Returns the integer value located at opts[key]. If there is no value or it
  ## cannot be conveted to an int, returns ``default``.
  result = default
  if opts.contains(key):
    try:
      let value = opts[key]
      result = value.parseInt
    except ValueError:
      discard

proc get*[T: string|bool|int](opts: Options, key: string, default: T = ""): T =
  ## Alias for ``getOrDefault`` and ``getBoolOrDefault``, depending on the type
  ## of ``default``.
  when T is bool:
    opts.getBoolOrDefault(key, default)
  elif T is int:
    opts.getIntOrDefault(key, default)
  else:
    opts.getOrDefault(key, default)

proc getPackageRoot*(baseDir = getCurrentDir()): string =
  ## Returns the first parent of baseDir that contains a nasher config
  result = baseDir.absolutePath()

  for dir in parentDirs(result):
    if existsFile(dir / "nasher.cfg"):
      return dir

proc getConfigFile*(pkgDir = ""): string =
  ## Returns the configuration file for the package owning ``pkgDir``, or the
  ## global configuration file if ``pkgDir`` is blank.
  if pkgDir.len > 0:
    getPackageRoot(pkgDir) / ".nasher" / "user.cfg"
  else:
    getConfigDir() / "nasher" / "user.cfg"

proc getPackageFile*(baseDir = getCurrentDir()): string =
  getPackageRoot(baseDir) / "nasher.cfg"

proc existsPackageFile*(dir = getCurrentDir()): bool =
  existsFile(getPackageFile(dir))

proc parseConfigFile*(opts: Options, file: string) =
  ## Loads all all values from ``file`` into opts. This provides user-defined
  ## defaults to options. It runs before the command-line options are processed,
  ## so the user can override these commands as needed.
  const prohibited =
    ["command", "config", "level", "directory", "file", "target", "targets",
     "help", "version"]

  let fileStream = newFileStream(file)

  if fileStream.isNil:
    return

  var p: CfgParser
  open(p, fileStream, file)
  while true:
    var e = p.next
    case e.kind
    of cfgEof: break
    of cfgKeyValuePair, cfgOption:
      if e.key notin prohibited:
        opts[e.key] = e.value
    else: discard
  close(p)

proc writeConfigFile*(opts: Options, file: string) =
  ## Converts ``opts`` into a config file named ``file``.
  let
    keys = toSeq(opts.keys).sorted
    dir = file.splitFile.dir

  try:
    createDir(dir)
    var s = openFileStream(file, fmWrite)
    for key in keys:
      s.writeLine(key & " = " & opts[key].escape)
    s.close
  except:
    fatal(getCurrentExceptionMsg())

proc putKeyOrHelp(opts: Options, keys: varargs[string], value: string) =
  ## Sets the first key in ``keys`` that does not exist to ``value``. If all
  ## keys already have a value, sets the help key to true.
  for key in keys:
    if key notin opts:
      opts[key] = value
      return

  opts["help"] = true

proc parseCmdLine(opts: Options) =
  ## Parses the command line and stores the user input into opts.
  for kind, key, val in getopt():
    case kind
    of cmdArgument:
      case opts.get("command")
      of "init":
        opts.putKeyOrHelp("directory", "file", key)
      of "config":
        opts.putKeyOrHelp("key", "value", key)
      of "list":
        opts.putKeyOrHelp("target", key)
      of "compile", "convert", "pack", "install", "play", "test", "serve":
        if opts.hasKeyOrPut("targets", key):
          opts["targets"] = opts["targets"] & ";" & key
      of "unpack":
        opts.putKeyOrHelp("target", "file", key)
      else:
        if key in nasherCommands:
          opts["command"] = key
        else: break
    of cmdLongOption, cmdShortOption:
      case key
      of "h", "help", "command":
        opts["help"] = true
      of "v", "version":
        opts["version"] = true
      of "no-color":
        cli.setShowColor(false)
      of "debug":
        cli.setLogLevel(DebugPriority)
      of "verbose":
        cli.setLogLevel(LowPriority)
      of "quiet":
        cli.setLogLevel(HighPriority)
      of "n", "no":
        cli.setForceAnswer(No)
      of "y", "yes":
        cli.setForceAnswer(Yes)
      of "default":
        cli.setForceAnswer(Default)
      else:
        case opts.get("command")
        of "config":
          case key
          of "g", "get": opts.putKeyOrHelp("config", "get")
          of "s", "set": opts.putKeyOrHelp("config", "set")
          of "u", "unset": opts.putKeyOrHelp("config", "unset")
          of "l", "list": opts.putKeyOrHelp("config", "list")
          of "global", "local": opts.putKeyOrHelp("level", key)
          of "d", "dir", "directory": opts.putKeyOrHelp("directory", val)
          else:
            opts.putKeyOrHelp("key", key)
            opts.putKeyOrHelp("value", val)
        else:
          opts[key] = val
    else: discard

proc dumpOptions(opts: Options) =
  ## Prints the values of options used in most of the nasher commands if debug
  ## mode is on.
  if not isLogging(DebugPriority):
    return

  debug("Args:", commandLineParams().join("\n"))
  debug("Command:", opts.get("command"))
  debug("Targets:", opts.get("targets"))
  debug("File:", opts.get("file"))
  debug("Directory:", opts.get("directory"))
  if opts.get("command") == "config":
    debug("Operation:", opts.get("config"))
    debug("Key:", opts.get("key"))
    debug("Value:", opts.get("value"))
  debug("Help:", $opts.get("help", false))
  debug("Version:", $opts.get("version", false))
  debug("Force:", $cli.getForceAnswer())
  stdout.write("\n")

proc newOptions*(file: string): Options =
  result = newStringTable(modeStyleInsensitive)
  result.parseConfigFile(file)

proc getOptions*: Options =
  ## Returns a string table of options obtained from the config file and command
  ## line input. Options are case and style insensitive (i.e., "someValue" ==
  ## "some_value").
  result = newStringTable(modeStyleInsensitive)
  result.parseConfigFile(getConfigFile())
  result.parseConfigFile(getConfigFile(getCurrentDir()))
  result.parseCmdLine

  # Some options imply others
  if result.getOrPut("clean", false):
    result["noInstall"] = false
    result["noPack"] = false

  if result.getOrPut("noInstall", false):
    result["noPack"] = true

  if result.getOrPut("noPack", false):
    result["noCompile"] = true
    result["noConvert"] = true

  result.dumpOptions

proc verifyBinaries*(opts: Options) =
  ## Verifies that the required binaries are available to nasher.
  debug("Verifying", "binaries...")
  let
    root = getPackageRoot()
    bins = [(flag: "nssCompiler", default: "nwnsc", desc: "script compiler"),
            (flag: "erfUtil", default: "nwn_erf", desc: "erf utility"),
            (flag: "gffUtil", default: "nwn_gff", desc: "gff utility"),
            (flag: "tlkUtil", default: "nwn_tlk", desc: "tlk utility")]

  var fail = false

  let
    cmds = ["compile", "pack", "install", "play", "test", "serve"]
    start = if opts["command"] notin cmds or opts.get("noCompile", false): 1
            else: 0

  for bin in bins[start..^1]:
    if opts.hasKeyOrPut(bin.flag, findExe(bin.default, root)):
      opts[bin.flag] = opts[bin.flag].expandPath

    let path = opts[bin.flag]
    info("Located", bin.desc & " at " & path)

    if not existsFile(path):
      let
        file = path.extractFilename
        msg =
          if file.len == 0:
            "is " & bin[1] & " installed?"
          elif file == path:
            file & " not found in $PATH."
          else:
            path & " does not exist."
      error("Could not locate " & bin[2] & ": " & msg)
      fail = true

  if fail:
    fatal("Could not locate required binaries. Aborting...")

proc initTarget: Target =
  result.name = ""

proc validTargetChars(name: string): bool =
  name.allCharsInSet({'a'..'z', '0'..'9', '_', '-'})

proc addTarget(pkg: PackageRef, target: var Target) =
  ## Adds target to pkg's list of targets. If target has no items in the include
  ## or exclude list, that list is copied from pkg.
  if target.name.len() > 0:
    if target.name == "all" or not target.name.validTargetChars:
      fatal("Illegal target name " & target.name.escape)

    if target.includes.len == 0:
      target.includes = pkg.includes
    if target.excludes.len == 0:
      target.excludes = pkg.excludes
    if target.filters.len == 0:
      target.filters = pkg.filters
    if target.flags.len == 0:
      target.flags = pkg.flags
    if target.rules.len == 0:
      target.rules = pkg.rules
    pkg.targets.add(target)
  target = initTarget()

proc parsePackageFile(pkg: PackageRef, file: string) =
  ## Loads the configuration for the package from file.
  let fileStream = newFileStream(file)

  if fileStream.isNil:
    fatal("Could not load package file " & file)

  var
    p: CfgParser
    section, key: string
    target: Target

  open(p, fileStream, file)
  while true:
    var e = p.next
    case e.kind
    of cfgEof: break
    of cfgSectionStart:
      pkg.addTarget(target)
      debug("Section:", fmt"[{e.section}]")
      section = e.section.toLower
    of cfgKeyValuePair, cfgOption:
      key = e.key.toLower
      debug("Option:", fmt"{key} = {e.value}")
      case section
      of "package", "sources":
        case key
        of "name": pkg.name = e.value
        of "description": pkg.description = e.value
        of "version": pkg.version = e.value
        of "url": pkg.url = e.value
        of "author": pkg.authors.add(e.value)
        of "source", "include": pkg.includes.add(e.value)
        of "exclude": pkg.excludes.add(e.value)
        of "filter": pkg.filters.add(e.value)
        of "flags": pkg.flags.add(e.value)
        else:
          pkg.rules.add((e.key, e.value))
      of "target":
        case key
        of "name": target.name = e.value.toLower
        of "description": target.description = e.value
        of "file": target.file = e.value
        of "source", "include": target.includes.add(e.value)
        of "exclude": target.excludes.add(e.value)
        of "filter": target.filters.add(e.value)
        of "flags": target.flags.add(e.value)
        else:
          target.rules.add((e.key, e.value))
      of "rules":
        pkg.rules.add((e.key, e.value))
      else:
        discard
    of cfgError:
      fatal(e.msg)
  pkg.addTarget(target)
  close(p)

proc dumpPackage(pkg: PackageRef) =
  ## Prints the structure of pkg if debug if mode is on.
  if not isLogging(DebugPriority):
    return

  stdout.write("\n")
  debug("Beginning", "configuration dump")
  stdout.write("\n")

  debug("Package:", pkg.name)
  debug("Description:", pkg.description)
  debug("Version:", pkg.version)
  debug("URL:", pkg.url)
  debug("Authors:", pkg.authors.join("\n"))
  debug("Includes:", pkg.includes.join("\n"))
  debug("Excludes:", pkg.excludes.join("\n"))
  debug("Filters:", pkg.filters.join("\n"))
  debug("Flags:", pkg.flags.join("\n"))

  for pattern, dir in pkg.rules.items:
    debug("Rule:", fmt"{pattern} -> {dir}")

  for target in pkg.targets:
    stdout.write("\n")
    debug("Target:", target.name)
    debug("Description:", target.description)
    debug("File:", target.file)
    debug("Includes:", target.includes.join("\n"))
    debug("Excludes:", target.excludes.join("\n"))
    debug("Filters:", target.filters.join("\n"))
    debug("Flags:", target.flags.join("\n"))

    for pattern, dir in target.rules.items:
      debug("Rule:", fmt"{pattern} -> {dir}")

  stdout.write("\n")

proc loadPackageFile*(pkg: PackageRef, file: string): bool =
  ## Initializes ``pkg`` with the contents of ``file``. Returns whether the
  ## operation was successful.
  if existsFile(file):
    pkg.parsePackageFile(file)
    pkg.dumpPackage
    result = true

proc getTarget*(pkg: PackageRef, name = ""): Target =
  ## Returns the target specified by the user, or the first target found in the
  ## package file if the user did not specify a target.
  if name.len > 0:
    let wanted = name.toLower
    for target in pkg.targets:
      if target.name == wanted:
        return target
    fatal("Unknown target " & wanted)
  else:
    try:
      result = pkg.targets[0]
    except IndexError:
      fatal("No targets found. Please check your nasher.cfg file.")

proc getTargets*(pkg: PackageRef, names = ""): seq[Target] =
  ## Returns a sequence of targets whose names are in the semicolon-separated
  ## list ``names``. If ``names`` is ``"all"``, will return a list of all
  ## targets for the package. If ``names`` is empty, will return the first
  ## target.
  if pkg.targets.len == 0:
    fatal("No targets found. Please check your nasher.cfg file.")

  case names
  of "":
    result = @[pkg.targets[0]]
  of "all":
    result = pkg.targets
  else:
    for name in names.split(";"):
      if name == "all":
        return pkg.targets
      result.add(pkg.getTarget(name))

# ----- Package Generation -----------------------------------------------------

proc addLine(s: var string, line = "") =
  s.add(line & "\n")

proc addPair(s: var string, key, value: string) =
  s.addLine(key & " = " & value.escape)

proc genSrcText(pattern = ""): string =
  hint("Add individual source files or use a glob to match multiple files. " &
       "For instance, you can match all nss and json files in subdirectories " &
       "of src/ with the pattern \"src/**/*.{nss,json}\".")
  var
    defaultSrc = pattern
  while true:
    let answer = ask("Include pattern:", defaultSrc)
    if answer.isEmptyOrWhitespace:
      break
    result.addPair("include", answer)
    defaultSrc = ""
    if not askIf("Include another source pattern?", allowed = NotYes):
      break

  if askIf("Do you wish to exclude any files matching the include patterns?"):
    while true:
      let answer = ask("Exclude pattern:", allowBlank = false)
      if answer.isEmptyOrWhitespace:
        break
      result.addPair("exclude", answer)
      if not askIf("Exclude another source pattern?", allowed = NotYes):
        break

proc genRuleText: string =
  const
    choiceSrc = "Put all files in src/"
    choiceSrcType = "Put all files in src/, organized by extension"
    choiceCustom = "Customize rules"
    choices = [choiceSrc, choiceSrcType, choiceCustom]

  result.addLine("[Rules]")
  hint("When unpacking, new files are extracted to directories based on " &
       "a list of rule. Each rule contains a pattern and a destination. The " &
       "file name is compared against each rule's pattern until a match is " &
       "found. The file is then extracted to that rule's destination. If no " &
       "match is found, it is extracted into \"unknown\".")
  case choose("How do you want to sort files?", choices)
  of choiceSrc:
    result.addPair("*".escape, "src")
  of choiceSrcType:
    result.addPair("*".escape, "src/$ext")
  of choiceCustom:
    var
      pattern, dir: string
      patternHint =
        "Patterns can be specific file names or a glob pattern matching " &
        "multiple files. For instance, you can match all nss files with the " &
        "pattern \"*.nss\"."
      dirHint =
        "A destination is a directory path relative to the project root. " &
        "It can make use of the special variable \"$ext\" to match the " &
        "file's extension. For example \"src/$ext\" maps foo.nss to " &
        "src/nss but maps module.ifo to src/ifo."

    while true:
      hint(patternHint)
      patternHint = ""
      pattern = ask("File pattern:", allowBlank = false)

      hint(dirHint)
      dirHint = ""
      dir = ask("Destination:")

      result.addPair(pattern.escape, dir)

      if not askIf("Do you wish to add another rule?", allowed = NotYes):
        break

proc genTargetText(defaultName: string): string =
  result.addLine("[Target]")
  result.addPair("name", ask("Target name:", defaultName))
  result.addPair("file", ask("File to generate:", "demo.mod"))
  result.addPair("description", ask("File description:"))

  hint("Adding a list of sources for this target will limit the target " &
       "to those sources. If you don't add sources to this target, it will " &
       "default to using the sources defined for the whole package.")
  if askIf("Do you wish to list source files specific to this target?"):
    result.add(genSrcText())

proc genPackageText*(opts: Options): string =
  display("Generating", "package config file")

  if not opts.get("skipPkgInfo", false):
    let
      defaultUrl = opts.get("url", gitRemote())

    result.addLine("[Package]")
    result.addPair("name", ask("Package name:"))
    result.addPair("description", ask("Package description:"))
    result.addPair("version", ask("Package version:"))
    result.addPair("url", ask("Package URL:", defaultUrl))

    var
      defaultAuthor = opts.get("userName", gitUser())
      defaultEmail = opts.get("userEmail", gitEmail())

    hint("Add each package author separately. If additional people contribute " &
         "to the project later, you can add separate lines for them in the " &
         "package config file.")
    while true:
      let authorName = ask("Author name:", defaultAuthor)

      if authorName.isEmptyOrWhitespace:
        break

      let
        authorEmail = ask("Author email:",
                          if authorName == defaultAuthor: defaultEmail else: "")

      if authorEmail.isEmptyOrWhitespace:
        result.addPair("author", authorName)
      else:
        result.addPair("author", "$1 <$2>" % [authorName, authorEmail])

      if not askIf("Do you wish to add another author?", allowed = NotYes):
        break

      defaultAuthor = ""
      defaultEmail = ""

    result.addLine

  hint("Adding sources tells nasher where to look when packing and " &
       "unpacking files. When adding sources, you should be sure to add " &
       "patterns that match every source file in your project. Otherwise, " &
       "nasher might not be able to properly update files when unpacking.")
  result.addLine("[Sources]")
  result.add(genSrcText("src/**/*.{nss,json}"))

  result.addLine
  result.add(genRuleText())

  hint("Build targets are used by the convert, compile, pack, and install " &
       "commands to map source files to an output file. Each target must " &
       "have a unique name to identify it. You can have multiple targets " &
       "(e.g., one for an installable erf and one for a demo module). The " &
       "first target defined in a package config will be the default.")
  var targetName = "default"
  while true:
    result.addLine
    result.add(genTargetText(targetName))
    targetName = ""

    if not askIf("Do you wish to add another target?", allowed = NotYes):
      break

import os, parseopt, parsecfg, streams, strformat, strtabs, strutils
export strtabs

import cli, git

type
  Options* = StringTableRef

  Package = object
    name*, description*, version*, url*: string
    authors*, sources*, flags*: seq[string]
    targets*: seq[Target]
    rules*: seq[Rule]

  PackageRef* = ref Package

  Target = object
    name*, file*, description*: string
    sources*, flags*: seq[string]

  Rule* = tuple[pattern, dir: string]

const
  nasherCommands =
    ["init", "list", "convert", "compile", "pack", "install", "unpack"]

proc `[]=`*[T: int | bool](opts: Options, key: string, value: T) =
  ## Overloaded ``[]=`` operator that converts value to a string before setting
  ## as to opts[key]
  opts[key] = $value

proc hasKeyOrPut*[T: string|int|bool](
  opts: Options, key: string, value: T): bool =
  ## Returns true if ``key`` in in ``opts``. Otherwise, sets ``opts[key]`` to
  ## ``value`` and returns false. If ``value`` is not a string, it will be
  ## converted to one.
  if hasKey(opts, key):
    result = true
  else:
    opts[key] = value

proc getOrPut*(opts: Options, key, value: string): string =
  ## Returns the value located at opts[key]. If the key does not exist, it is
  ## set to value, which is returned.
  if opts.contains(key):
    result = opts[key]
  else:
    opts[key] = value
    result = value

proc getBoolOrPut*(opts: Options, key: string, value: bool): bool =
  ## Returns the value located at opts[key]. If the key does not exist, it is
  ## set to value, which is returned. If the key exists but cannot be converted
  ## to a bool, value is returned.
  if opts.contains(key):
    try:
      let tmpValue = opts[key]
      result = tmpValue == "" or tmpValue.parseBool
    except ValueError:
      result = value
  else:
    opts[key] = value
    result = value

proc getBoolOrDefault*(opts: Options, key: string, default = false): bool =
  ## Returns the boolean value located at opts[key]; "" is treated as true. If
  ## there is no value or it cannot be conveted to a bool, returns default.
  result = default
  if opts.contains(key):
    try:
      let value = opts[key]
      result = value == "" or value.parseBool
    except ValueError:
      discard

proc parseConfigFile(opts: Options) =
  ## Loads all all values from $CONFIG/nasher/user.cfg into opts. This provides
  ## user-defined defaults to options. It runs before the command-line options
  ## are processed, so the user can override these commands as needed.
  let
    file = getConfigDir() / "nasher" / "user.cfg"
    fileStream = newFileStream(file)

  if fileStream.isNil:
    return

  var p: CfgParser
  open(p, fileStream, file)
  while true:
    var e = p.next
    case e.kind
    of cfgEof: break
    of cfgKeyValuePair, cfgOption:
      opts[e.key] = e.value
    else: discard
  close(p)

proc parseCmdLine(opts: Options) =
  ## Parses the command line and stores the user input into opts.
  for kind, key, val in getopt():
    case kind
    of cmdArgument:
      case opts.getOrDefault("command")
      of "init":
        if opts.hasKeyOrPut("directory", key) and
           opts.hasKeyOrPut("file", key):
           opts["help"] = true
      of "list", "compile", "convert", "pack", "install":
        if opts.hasKeyOrPut("target", key):
           opts["help"] = true
      of "unpack":
        if opts.hasKeyOrPut("file", key):
           opts["help"] = true
      else:
        if key in nasherCommands:
          opts["command"] = key
        else: break
    of cmdLongOption, cmdShortOption:
      case key
      of "h", "help":
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
        opts[key] = val
    else: discard

proc dumpOptions(opts: Options) =
  ## Prints the values of options used in most of the nasher commands if debug
  ## mode is on.
  if not isLogging(DebugPriority):
    return

  debug("Args:", commandLineParams().join("\n"))
  debug("Command:", opts.getOrDefault("command"))
  debug("Target:", opts.getOrDefault("target"))
  debug("File:", opts.getOrDefault("file"))
  debug("Directory:", opts.getOrDefault("directory"))
  debug("Config:", opts.getOrDefault("config"))
  debug("Help:", $opts.getBoolOrDefault("help"))
  debug("Version:", $opts.getBoolOrDefault("version"))
  debug("Force:", $cli.getForceAnswer())
  stdout.write("\n")

proc getOptions*: Options =
  ## Returns a string table of options obtained from the config file and command
  ## line input. Options are case and style insensitive (i.e., "someValue" ==
  ## "some_value").
  result = newStringTable(modeStyleInsensitive)
  result.parseConfigFile
  result.parseCmdLine
  result.dumpOptions

proc initTarget: Target =
  result.name = ""

proc addTarget(pkg: PackageRef, target: var Target) =
  ## Adds target to pkg's list of targets. If target has no sources, the sources
  ## are copied from pkg.
  if target.name.len() > 0:
    if target.sources.len == 0:
      target.sources = pkg.sources
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
      section = e.section.normalize
    of cfgKeyValuePair, cfgOption:
      key = e.key.normalize
      debug("Option:", fmt"{key} = {e.value}")
      case section
      of "package", "sources":
        case key
        of "name": pkg.name = e.value
        of "description": pkg.description = e.value
        of "version": pkg.version = e.value
        of "url": pkg.url = e.value
        of "author": pkg.authors.add(e.value)
        of "source": pkg.sources.add(e.value)
        of "flags": pkg.flags.add(e.value)
        else:
          error(fmt"Unknown key/value pair: {key} = {e.value}")
      of "target":
        case key
        of "name": target.name = e.value.normalize
        of "description": target.description = e.value
        of "file": target.file = e.value
        of "source": target.sources.add(e.value)
        of "flags": pkg.flags.add(e.value)
        else:
          error(fmt"Unknown key/value pair '{key} = {e.value}'")
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
  debug("Sources:", pkg.sources.join("\n"))
  debug("Flags:", pkg.flags.join("\n"))

  for pattern, dir in pkg.rules.items:
    debug("Rule:", fmt"{pattern} -> {dir}")

  for target in pkg.targets:
    stdout.write("\n")
    debug("Target:", target.name)
    debug("Description:", target.description)
    debug("File:", target.file)
    debug("Sources:", target.sources.join("\n"))
    debug("Flags:", target.flags.join("\n"))

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
  if pkg.targets.len == 0:
    fatal("No targets found. Please check your nasher.cfg file.")

  if name.len > 0:
    for target in pkg.targets:
      if target.name == name:
        return target
      fatal("Unknown target " & name)
  else:
    result = pkg.targets[0]

# ----- Package Generation -----------------------------------------------------

proc addLine(s: var string, line = "") =
  s.add(line & "\n")

proc addPair(s: var string, key, value: string) =
  s.addLine(key & " = " & value.escape)

proc genSrcText: string =
  hint("Add individual source files or use a glob to match multiple files. " &
       "For instance, you can match all nss and json files in subdirectories " &
       "of src/ with the pattern \"src/**/*.{nss,json}\".")
  var
    defaultSrc = "src/**/*.{nss,json}"
  while true:
    result.addPair("source", ask("Source pattern:", defaultSrc, allowBlank = false))
    defaultSrc = ""
    if not askIf("Do you wish to add another source pattern?", allowed = NotYes):
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
  if askIf("Do you wish to add source files specific to this target?"):
    result.add(genSrcText())

proc genPackageText*(opts: Options): string =
  display("Generating", "package config file")

  let
    defaultUrl = opts.getOrDefault("url", gitRemote())

  result.addLine("[Package]")
  result.addPair("name", ask("Package name:"))
  result.addPair("description", ask("Package description:"))
  result.addPair("version", ask("Package version:"))
  result.addPair("url", ask("Package URL:", defaultUrl))

  var
    defaultAuthor = opts.getOrDefault("userName", gitUser())
    defaultEmail = opts.getOrDefault("userEmail", gitEmail())

  hint("Add each package author separately. If additional people contribute " &
       "to the project later, you can add separate lines for them in the " &
       "package config file.")
  while true:
    let
      authorName = ask("Author name:", defaultAuthor, allowBlank = false)
      authorEmail = ask("Author email:",
                        if authorName == defaultAuthor: defaultEmail else: "")

    if authorEmail.isNilOrWhitespace:
      result.addPair("author", authorName)
    else:
      result.addPair("author", "$1 <$2>" % [authorName, authorEmail])

    if not askIf("Do you wish to add another author?", allowed = NotYes):
      break

    defaultAuthor = ""
    defaultEmail = ""

  hint("Adding sources tells nasher where to look when packing and " &
       "unpacking files. When adding sources, you should be sure to add " &
       "patterns that match every source file in your project. Otherwise, " &
       "nasher might not be able to properly update files when unpacking.")
  result.addLine
  result.addLine("[Sources]")
  result.add(genSrcText())

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

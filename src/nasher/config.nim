import os, osproc, parsecfg, streams, strformat, strutils, tables

import common
export common

type
  Config* = object
    user*: User
    pkg*: Package
    compiler*: tuple[binary: string, flags: seq[string]]
    targets*: OrderedTable[string, Target]
    rules*: seq[Rule]

  User* = tuple[name, email, install: string]

  Compiler* = tuple[binary: string, flags: seq[string]]

  Package* = object
    name*, description*, version*, url*: string
    authors*, sources*: seq[string]

  Target* = object
    name*, file*, description*: string
    sources*: seq[string]

  SourceMap* = Table[string, seq[string]]

  Rule* = tuple[pattern, dir: string]

proc addLine(s: var string, line = "") =
  s.add(line & "\n")

proc addPair(s: var string, key, value: string) =
  s.addLine("$1 = \"$2\"" % [key, value])

proc genGlobalCfgText: string =
  display("Generating", "global config file")
  hint("User information will be automatically filled into the authors " &
       "section of new packages created using nasher init.")
  let
    defaultName = execCmdOrDefault("git config --get user.name").strip
    defaultEmail = execCmdOrDefault("git config --get user.email").strip

  result.addLine("[User]")
  result.addPair("name", ask("What is your name?", defaultName))
  result.addPair("email", ask("What is your email?", defaultEmail))
  result.addPair("install", ask("Where is Neverwinter Nights installed?",
                                getNwnInstallDir()))

  hint("If the compiler binary is in your $PATH, you can just enter the " &
       "name of the binary. Otherwise, you should put the absolute path " &
       "to the compiler binary.")
  result.addLine
  result.addLine("[Compiler]")
  result.addPair(
    "binary", ask("What is the command to run your script compiler?", "nwnsc"))

  hint("Any flags entered here will be passed to the compiler for every " &
       "package. Package configs can specify extra flags on a per-target " &
       "basis if needed.")
  let
    flags = ask("What script compiler flags should always be used?", "-lowqey")

  for flag in flags.split:
    result.addPair("flags", flag)

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

proc genPkgCfgText(user: User): string =
  display("Generating", "package config file")

  let
    defaultUrl = execCmdOrDefault("git remote get-url origin").strip

  result.addLine("[Package]")
  result.addPair("name", ask("Package name:"))
  result.addPair("description", ask("Package description:"))
  result.addPair("version", ask("Package version:", "0.1.0"))
  result.addPair("url", ask("Package URL:", defaultUrl))

  var
    defaultAuthor = user.name
    defaultEmail = user.email

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
  result.add(genSrcText())

  result.addLine
  result.add(genRuleText())

  hint("Build targets are used by the compile, pack, and install commands " &
       "to map source files to an output file. Each target must have a " &
       "unique name to identify it. You can have multiple targets (e.g., " &
       "one for an installable erf and one for a demo module). The first " &
       "target defined in a package config will be the default.")
  var targetName = "default"
  while true:
    result.addLine
    result.add(genTargetText(targetName))
    targetName = ""

    if not askIf("Do you wish to add another target?", allowed = NotYes):
      break

proc writeCfgFile(fileName, text: string) =
  tryOrQuit("Could not create config file at " & fileName):
    display("Creating", "configuration file at " & fileName)
    createDir(fileName.splitFile().dir)
    writeFile(fileName, text)
    success("created configuration file")

proc genCfgFile(file: string, user: User) =
  if file == getGlobalCfgFile():
    writeCfgFile(file, genGlobalCfgText())
  else:
    writeCfgFile(file, genPkgCfgText(user))

proc initConfig*(): Config =
  result.user.install = getNwnInstallDir()
  result.compiler.binary = "nwnsc"

proc initTarget(): Target =
  result.name = ""

proc addTarget(cfg: var Config, target: var Target) =
  if target.name.len() > 0:
    if target.sources.len == 0:
      target.sources = cfg.pkg.sources
    cfg.targets[target.name] = target
  target = initTarget()

proc parseUser(cfg: var Config, key, value: string) =
  case key
  of "name": cfg.user.name = value
  of "email": cfg.user.email = value
  of "install": cfg.user.install = value
  else:
    error(fmt"Unknown key/value pair '{key}={value}'")

proc parseCompiler(cfg: var Config, key, value: string) =
  case key
  of "binary": cfg.compiler.binary = value
  of "flags": cfg.compiler.flags.add(value)
  else:
    error(fmt"Unknown key/value pair '{key}={value}'")

proc parsePackage(cfg: var Config, key, value: string) =
  case key
  of "name": cfg.pkg.name = value
  of "description": cfg.pkg.description = value
  of "version": cfg.pkg.version = value
  of "author": cfg.pkg.authors.add(value)
  of "url": cfg.pkg.url = value
  of "source": cfg.pkg.sources.add(value)
  else:
    error(fmt"Unknown key/value pair '{key}={value}'")

proc parseRule(cfg: var Config, key, value: string) =
  cfg.rules.add((key, value))

proc parseTarget(target: var Target, key, value: string) =
  case key
  of "name": target.name = value.normalize
  of "description": target.description = value
  of "file": target.file = value
  of "source": target.sources.add(value)
  else:
    error(fmt"Unknown key/value pair '{key}={value}'")

proc parseConfig*(cfg: var Config, fileName: string) =
  var f = newFileStream(fileName)
  if isNil(f):
    fatal(fmt"Cannot open config file: {fileName}")
    quit(QuitFailure)

  debug("File:", fileName)
  var p: CfgParser
  var section, key: string
  var target: Target
  p.open(f, fileName)
  while true:
    var e = p.next()
    case e.kind
    of cfgEof: break
    of cfgSectionStart:
      cfg.addTarget(target)
      debug("Section:", fmt"[{e.section}]")
      section = e.section.normalize
    of cfgKeyValuePair, cfgOption:
      key = e.key.normalize
      debug("Option:", fmt"{key}: {e.value}")
      tryOrQuit(fmt"Error parsing {fileName}: {getCurrentExceptionMsg()}"):
        case section
        of "user":
          parseUser(cfg, key, e.value)
        of "compiler":
          parseCompiler(cfg, key, e.value)
        of "package":
          parsePackage(cfg, key, e.value)
        of "rules":
          parseRule(cfg, e.key, e.value)
        of "target":
          parseTarget(target, key, e.value)
        else:
          discard
    of cfgError:
      fatal(e.msg)
  cfg.addTarget(target)
  p.close()

proc dumpConfig(cfg: Config) =
  if not isLogging(DebugPriority):
    return

  sandwich:
    debug("Beginning", "configuration dump")

  debug("User:", cfg.user.name)
  debug("Email:", cfg.user.email)
  debug("Compiler:", cfg.compiler.binary)
  debug("Flags:", cfg.compiler.flags.join("\n"))
  debug("NWN Install:", cfg.user.install)
  debug("Package:", cfg.pkg.name)
  debug("Description:", cfg.pkg.description)
  debug("Version:", cfg.pkg.version)
  debug("URL:", cfg.pkg.url)
  debug("Authors:", cfg.pkg.authors.join("\n"))
  debug("Sources:", cfg.pkg.sources.join("\n"))

  for pattern, dir in cfg.rules.items:
    debug("Rule:", pattern & " -> " & dir)

  try:
    for target in cfg.targets.values:
      stdout.write("\n")
      debug("Target:", target.name)
      debug("Description:", target.description)
      debug("File:", target.file)
      debug("Sources:", target.sources.join("\n"))
  except IndexError:
    discard

  sandwich:
    debug("Ending", "configuration dump")

proc loadConfig*(cfg: var Config, file: string) =
  if not existsFile(file):
    genCfgFile(file, cfg.user)
  cfg.parseConfig(file)

proc loadConfigs*(files: seq[string]): Config =
  result = initConfig()
  var hasRun = false
  for file in files:
    doAfterDebug(hasRun):
      stdout.write("\n")
    result.loadConfig(file)

  result.dumpConfig()

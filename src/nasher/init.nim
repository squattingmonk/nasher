import std/[os, strutils]
import utils/[git, shared]

const helpInit* = """
Usage:
  nasher init [options] [<dir> [<file>]]

Description:
  Initializes a directory as a nasher project. If supplied, <dir> will be
  created if needed and set as the project root; otherwise, the current
  directory will be the project root.

  If supplied, <file> will be unpacked into the project root's source tree.

Options:
  --vcs:<vcs>            The version control system to use for the project
                         [choices: git (default), none]
  --skipPkgInfo          Skip the optional [package] generation prompts
  --url:<url>            The url for the project
  --userName:<name>      The package author's name (default git user.name)
  --userEmail:<email>    The package author's email (default git user.email)

"""

proc genPackageText(opts: Options): string

proc init*(opts: Options): bool =
  let
    dir = opts.getOrPut("directory", getCurrentDir())
    file = dir / "nasher.cfg"

  if fileExists(file):
    fatal(dir & " is already a nasher project")

  display("Initializing", "into " & dir)

  try:
    createDir(dir)
  except OSError:
    fatal("Could not create package directory: " & getCurrentExceptionMsg())
  except IOError:
    fatal("Could not create package directory: a file named " & dir & " already exists")

  display("Creating", "package file at " & file)
  var f: File
  if open(f, file, fmWrite):
    try:
      f.write(genPackageText(opts))
    finally:
      f.close
  else:
    error("Cannot open " & file)
    fatal("Could not create package file at " & file)

  success("created package file")

  # TODO: support hg
  if opts.getOrPut("vcs", "git") == "git":
    try:
      display("Initializing", "git repository")
      if gitInit(dir):
        gitIgnore(dir)
      success("initialized git repository")
    except CatchableError:
      error("Could not initialize git repository: " & getCurrentExceptionMsg())

  success("project initialized")

  # Check if we should unpack a file
  return opts.hasKey("file")

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
    result.addPair("  include", answer)
    defaultSrc = ""
    if not askIf("Include another source pattern?", allowed = NotYes):
      break

  if askIf("Do you wish to exclude any files matching the include patterns?"):
    while true:
      let answer = ask("Exclude pattern:", allowBlank = false)
      if answer.isEmptyOrWhitespace:
        break
      result.addPair("  exclude", answer)
      if not askIf("Exclude another source pattern?", allowed = NotYes):
        break

proc genRuleText(): string =
  const
    choiceSrc = "Put all files in src/"
    choiceSrcType = "Put all files in src/, organized by extension"
    choiceCustom = "Customize rules"
    choices = [choiceSrc, choiceSrcType, choiceCustom]

  hint("When unpacking, new files are extracted to directories based on " &
       "a list of rules. Each rule contains a pattern and a destination. The " &
       "file name is compared against each rule's pattern until a match is " &
       "found. The file is then extracted to that rule's destination. If no " &
       "match is found, it is extracted into \"unknown\".")
  case choose("How do you want to sort files?", choices)
  of choiceSrc:
    result.addPair("  " & "*".escape, "src")
  of choiceSrcType:
    result.addPair("  " & "*".escape, "src/$ext")
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

      result.addPair("  " & pattern.escape, dir)

      if not askIf("Do you wish to add another rule?", allowed = NotYes):
        break

proc genTargetText(defaultName: string): string =
  result.addLine("[target]")
  result.addPair("name", ask("Target name:", defaultName))
  result.addPair("file", ask("File to generate:", "demo.mod"))
  result.addPair("description", ask("File description:"))

  hint("Adding a list of sources for this target will limit the target " &
       "to those sources. If you don't add sources to this target, it will " &
       "default to using the sources defined for the whole package.")
  if askIf("Do you wish to list source files specific to this target?"):
    result.addLine("  [target.sources]")
    result.add(genSrcText())

  hint("If you don't add unpack rules to this target, it will default to " &
       "using the unpack rules defined for the whole package.")
  if askIf("Do you wish to list unpack rules specific to this target?"):
    result.addLine("  [target.rules]")
    result.add(genRuleText())

proc genPackageText(opts: Options): string =
  display("Generating", "package config file")

  result.addLine("[package]")
  if not opts.get("skipPkgInfo", false):
    let
      defaultUrl = opts.getOrDefault("url", gitRemote())

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
  result.addLine("  [package.sources]")
  result.add(genSrcText("src/**/*.{nss,json}"))

  result.addLine
  result.addLine("  [package.rules]")
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



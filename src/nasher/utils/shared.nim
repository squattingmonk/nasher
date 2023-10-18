import std/[os, times, strformat, strutils, strtabs, tables, json]
from sequtils import mapIt, toSeq, deduplicate
from unicode import toLower
from sugar import collect

when defined(Windows):
  import registry

from glob import walkGlob, defaultGlobOptions, GlobOption

import cli, target, options
export cli, target, options

type
  MultiSrcAction* {.pure.} = enum
    None = "", Choose = "choose", Default = "default", Error = "error"

const GlobalOpts = """
Global Options:
  -h, --help             Display help for nasher or one of its commands
  -v, --version          Display version information
  -y, --yes              Automatically answer yes to all prompts
  -n, --no               Automatically answer no to all prompts
  -d, --default          Automatically accept the default answer to prompts

Logging:
  --quiet                Disable all logging except errors
  --verbose              Enable additional messages about normal operation
  --debug                Enable debug logging (implies --verbose)
  --no-color             Disable color output (automatic if not a tty)
"""

const PackLoopOpts = """
  --clean                Clear the cache directory before operation
  --branch:<branch>      Select git branch <branch> before operation
  --modName:<name>       Name for a module file
  --modMinGameVersion:<ver>
                         Minimum game version required to run a module
  --modDescription:<description>
                         Sets the module's description, viewable in module
                         properties
  --onMultipleSources:<method>
                         How to handle multiple sources for the same file
                         [choices: choose (default), default (accept the first),
                         error (fail)]. Overrides --yes/--no if explicitly set.
  --removeUnusedAreas    Remove references to unused areas in module.ifo (note:
                         disable if you have areas present only in a hak or
                         override) [default: true]
"""

const UtilOpts = """
Utility Options:
  --gffUtil:<bin>        Binary to convert GFF files[default: nwn_gff]
  --gffFormat:<fmt>      GFF source file format [choices: json (default), nwnt]
  --gffFlags:<flags>     Flags to pass to $gffUtil [default: -p]
  --tlkUtil:<bin>        Binary to convert TLK files [default: nwn_tlk]
  --tlkFormat:<fmt>      TLK source file format [choices: json (default), csv]
  --tlkFlags:<flags>     Flags to pass to $tlkUtil [default: ""]
  --erfUtil:<bin>        Binary for packing erf/hak/mod files [default: nwn_erf]
  --erfFlags:<flags>     Flags to pass to $erfUtil [default: ""]
"""

const CompilerOpts = """
Compiler Options:
  --abortOnCompileError  Quit if an error was encountered during compilation
  --nssCompiler:<bin>    Binary for compiling nss scripts [default: nwnsc]
  --nssFlags:<flags>     Flags to pass to the compiler [default: -lowqey]
  --nssChunks:<n>        Max scripts to compile per compiler exec [default: 500]
"""

const ConvertOpts* = """
$#
$#""" % [PackLoopOpts, UtilOpts]

const CompileOpts* = """
  -f, --file:<file>      Compiles <file> only; repeatable
  --noConvert            Do not re-convert gff files before compiling
$#
$#
$#""" % [PackLoopOpts, UtilOpts, CompilerOpts]

const PackOpts* = """
  --noCompile            Do not re-compile scripts before packing
  --noConvert            Do not re-convert gff files before compiling
  --packUnchanged        Pack a target even if the source files are unchanged
  --overwritePackedFile:<method>
                         Whether to overwrite existing packed files of the same
                         name in the output directory [choices: ask (default),
                         default (overwrite if existing file is older, skip if
                         newer), never, always]
$#
$#
$#""" % [PackLoopOpts, UtilOpts, CompilerOpts]

const InstallOpts* = """
  --noPack               Do not re-pack file before installing
$#
Installation Options:
  --installDir:<dir>     Location for installed files (i.e., dir containing erf,
                         hak, modules, and tlk dirs) [default: $$NWN_HOME]
  --overwriteInstalledFile:<method>
                         Whether to overwrite existing files of the same name in
                         the install directory [choices: ask (default), default
                         (overwrite if existing file is older, skip if newer),
                         never, always (will lose any changes from the toolset)]
  --useModuleFolder      Treat modules in $$installDir/modules as folders instead
                         of .mod files (note: EE only) [default: true]
""" % PackOpts

const LaunchOpts* = """
  --noInstall            Do not re-install file before launching
$#
Launch Options:
  --gameBin              Path to the nwmain binary file
  --serverBin            Path to the nwserver binary file
""" % InstallOpts

const UnpackOpts* = """
  --file:<file>          A file to unpack into the target's source tree. Only
                         needed if not using <target>'s default file.
  --truncateFloats:<n>   Max number of decimal places floats in GFF files may
                         have [range: 0-32, default: 4]
  --removeDeleted        Remove source files not present in the file being
                         unpacked [default: false]
  --branch:<branch>      Select git branch <branch> before operation
  --installDir:<dir>     Location for installed files (i.e., dir containing erf,
                         hak, modules, and tlk dirs) [default: $NWN_HOME]
  --useModuleFolder      Treat modules in $installDir/modules as folders instead
                         of .mod files (note: EE only) [default: true]
""" & UtilOpts

proc help*(helpMessage: string, errorCode = QuitSuccess) =
  ## Quits with a formatted help message, sending errorCode
  quit(strip(helpMessage & GlobalOpts), errorCode)

proc getPackageRoot*(baseDir = getCurrentDir()): string =
  ## Returns the first parent of baseDir that contains a nasher config
  result = baseDir.absolutePath()

  for dir in parentDirs(result):
    if fileExists(dir / "nasher.cfg"):
      return dir

proc getConfigFile*(pkgDir = ""): string =
  ## Returns the configuration file for the package owning `pkgDir`, or the
  ## global configuration file if `pkgDir` is blank.
  if pkgDir.len > 0:
    getPackageRoot(pkgDir) / ".nasher" / "user.cfg"
  else:
    getConfigDir() / "nasher" / "user.cfg"

proc getPackageFile*(baseDir = getCurrentDir()): string =
  getPackageRoot(baseDir) / "nasher.cfg"

proc existsPackageFile*(dir = getCurrentDir()): bool =
  fileExists(getPackageFile(dir))

proc matchesAny*(s: string, patterns: seq[string]): bool =
  ## Returns whether ``s`` matches any glob pattern in ``patterns``.
  for pattern in patterns:
    if glob.matches(s, pattern):
      return true

iterator walkSourceFiles*(target: Target): string =
  ## Yields all files in the source tree matching include patterns while not
  ## matching exclude patterns.
  const globOpts = defaultGlobOptions - {GlobOption.DirLinks} + {GlobOption.Absolute}
  let excluded = collect:
    for pattern in target.excludes:
      for file in walkGlob(pattern, options = globOpts):
        file
  for pattern in target.includes:
    for file in walkGlob(pattern, options = globOpts):
      if file notin excluded:
        yield file

proc getSourceFiles*(target: Target): seq[string] =
  ## Returns all files in the source tree matching include patterns while not
  ## matching exclude patterns.
  toSeq(target.walkSourceFiles).deduplicate

proc getTimeDiff*(a, b: Time): int =
  ## Compares two times and returns the difference in seconds. If 0, the files
  ## are the same age. If positive, a is newer than b. If negative, b is newer
  ## than a.
  (a - b).inSeconds.int

proc getTimeDiffHint*(file: string, diff: int): string =
  ## Returns a message stating whether file a is newer than, older than, or the
  ## same age as file b, based on the value of diff.
  if diff > 0: file & " is newer than the existing file"
  elif diff < 0: file & " is older than the existing file"
  else: file & " is the same age as the existing file"

proc fileOlder*(file: string, time: Time): bool =
  ## Checks whether file is older than a time. Only checks seconds since copying
  ## modification times results in unequal nanoseconds.
  if fileExists(file):
    getTimeDiff(time, file.getLastModificationTime) > 0
  else: true

proc fileNewer*(file: string, time: Time): bool =
  if fileExists(file):
    getTimeDiff(time, file.getLastModificationTime) < 0
  else: false

proc getNwnHomeDir*: string =
  if existsEnv("NWN_HOME"):
    getEnv("NWN_HOME")
  else:
    when defined(Linux):
      getHomeDir() / ".local" / "share" / "Neverwinter Nights"
    else:
      getHomeDir() / "Documents" / "Neverwinter Nights"

proc getNwnRootDir*: string =
  if existsEnv("NWN_ROOT"):
    result = getEnv("NWN_ROOT")
    if dirExists(result / "data"):
      info("Located", "$NWN_ROOT at " & result)
      return result

  # Steam Install
  var path: string
  block steam:
    const steamPath = "Steam" / "steamapps" / "common" / "Neverwinter Nights"
    when defined(Linux):
      path = getHomeDir() / ".local" / "share" / steamPath
    elif defined(MacOSX):
      path = getHomeDir() / "Library" / "Application Support" / steamPath
    elif defined(Windows):
      path = getEnv("PROGRAMFILES(X86)") / steamPath
      if not dirExists(path / "data"):
        try:
          path = getUnicodeValue(r"SOFTWARE\WOW6432Node\Valve\Steam", "InstallPath", HKEY_LOCAL_MACHINE)
          path = path / "steamapps" / "common" / "Neverwinter Nights"
        except OSError:
          break steam
    else:
      raise newException(ValueError, "Could not locate NWN root: unsupported OS")
    if dirExists(path / "data"):
      info("Located", "Steam installation at " & path)
      return path

  # Beamdog Install
  # 00785: Stable
  # 00829: Development
  block beamdog:
    const
      settings = "Beamdog Client" / "settings.json"
      releases = ["00829", "00785"]

    when defined(Linux):
      let settingsFile = getConfigDir() / settings
    elif defined(MacOSX):
      let settingsFile = getHomeDir() / "Library" / "Application Support" / settings
    elif defined(Windows):
      let settingsFile = getHomeDir() / "AppData" / "Roaming" / settings
    else:
      raise newException(ValueError, "Could not locate NWN root: unsupported OS")
    if fileExists(settingsFile):
      let data = json.parseFile(settingsFile)
      doAssert(data.hasKey("folders"))
      doAssert(data["folders"].kind == JArray)

      for release in releases:
        for folder in data["folders"].getElems.mapIt(it.getStr / release):
          if dirExists(folder / "data"):
            info("Located", "Beamdog installation at " & folder)
            return folder

  # GOG Install
  block gog:
    when defined(Linux) or defined(MacOSX):
      path = getHomeDir() / "GOG Games" / "Neverwinter Nights Enhanced Edition"
    elif defined(Windows):
      path = getEnv("PROGRAMFILES(X86)") / "GOG Galaxy" / "Games" / "Neverwinter Nights Enhanced Edition"
      if not dirExists(path / "data"):
        try:
          path = getUnicodeValue(r"SOFTWARE\WOW6432Node\GOG.com\Games\1097893768", "path", HKEY_LOCAL_MACHINE)
        except OSError:
          break gog
    else:
      raise newException(ValueError, "Could not locate NWN root: unsupported OS")
    if dirExists(path / "data"):
      info("Located", "GOG installation at " & path)
      return path

  warning("Could not locate NWN root. Try setting the NWN_ROOT environment " &
    "variable to the path of your NWN installation.")


template withDir*(dir: string, body: untyped): untyped =
  let curDir = getCurrentDir()
  try:
    setCurrentDir(dir)
    body
  finally:
    setCurrentDir(curDir)

template withEnv*(envs: openarray[(string, string)], body: untyped): untyped =
  ## Executes ``body`` with all environment variables in ``envs``, then returns
  ## the environment variables to their previous values.
  var
    prevValues: seq[(string, string)]
    noValues: seq[string]
  for (name, value) in envs:
    if existsEnv(name):
      prevValues.add((name, getEnv(name)))
    else:
      noValues.add(name)
    putEnv(name, value)

  body

  for (name, value) in prevValues:
    putEnv(name, value)
  for name in noValues:
    delEnv(name)

proc getFileExt*(file: string): string =
  ## Returns the file extension without the leading "."
  file.splitFile.ext.strip(chars = {ExtSep})

proc normalizeFilename*(file: string): string =
  ## Converts ``file``'s filename to lowercase
  let (dir, fileName) = file.splitPath
  dir / fileName.toLower

proc expandPath*(path: string, keepUnknownKeys = false): string =
  ## Expands the tilde and any environment variables in ``path``. If
  ## ``keepUnknownKeys`` is ``true``, will leave unknown variables in place
  ## rather than replacing them with an empty string.
  let flags = {useEnvironment, if keepUnknownKeys: useKey else: useEmpty}
  result = `%`(path.expandTilde, newStringTable(modeCaseSensitive), flags)

proc findBin*(opts: Options, flag, bin, desc: string): string =
  ## Checks `opts` for the location of the binary `bin` stored at `opts[flag]`
  ## and returns the absolute path with envvars resolved. `desc` is a
  ## description of the binary for error messages.
  result =
    if flag in opts:
      opts[flag].expandPath.absolutePath
    else:
      withDir getPackageRoot():
        findExe(bin)
  if result.len == 0:
    fatal("Could not locate $1: is $2 installed?" % [desc, bin])
  elif not fileExists(result):
    fatal("Could not locate $1: $2 does not exist" % [desc, result])
  elif fpUserExec notin getFilePermissions(result):
    fatal("Cannot execute $1: check permissions for $2" % [desc, result])
  info("Located", "$1 at $2" % [desc, result])

proc outFile*(srcFile: string): string =
  ## Returns the filename of the converted source file
  let (_, name, ext) = srcFile.splitFile
  if ext == ".json" or ext == ".nwnt": name
  else: name & ext

proc chooseFile*(file: string, choices: seq[string], action: MultiSrcAction): string =
  ## Presents the user with a list of possible locations for `file`, possibly
  ## allowing them to choose a location based on `action`. Returns the chosen
  ## location.
  case action
  of Error:
    fatal("Multiple locations for $1:\n$2" % [file, choices.join("\n")])
  else:
    let current = getForceAnswer()
    case action
    of Choose: setForceAnswer(None)
    of Default: setForceAnswer(Default)
    else: discard
    result = choose(fmt"Multiple locations available for {file}. Please choose:", choices)
    setForceAnswer(current)

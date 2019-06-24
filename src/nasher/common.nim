import os, strformat

const nasherVersion* = "nasher 0.1.0"

type
  NasherError* = object of Exception

template tryOrQuit*(msg: string, statements: untyped) =
  try:
    statements
  except:
    quit(msg, QuitFailure)

template tryOrQuit*(statements: untyped) =
  try:
    statements
  except:
    quit(getCurrentExceptionMsg(), QuitFailure)

proc getPkgRoot*(baseDir: string): string =
  ## Returns the first parent of baseDir that contains a nasher config
  result = baseDir.absolutePath()

  for dir in parentDirs(result):
    if existsFile(dir / "nasher.cfg"):
      return dir

proc getUserCfgFile*: string =
  getConfigDir() / "nasher" / "nasher.cfg"

proc getPkgCfgFile*(baseDir = getCurrentDir()): string =
  getPkgRoot(baseDir) / "nasher.cfg"

proc getSrcDir*(baseDir = getCurrentDir()): string =
  getPkgRoot(baseDir) / "src"

proc getCacheDir*(file: string, baseDir = getCurrentDir()): string =
  getPkgRoot(baseDir) / ".nasher" / "cache" / file.extractFilename()

proc getBuildDir*(build: string, baseDir = getCurrentDir()): string =
  getPkgRoot(baseDir) / ".nasher" / "build" / build

proc isNasherProject*(dir = getCurrentDir()): bool =
  existsFile(getPkgCfgFile(dir))


let
  nwnInstallDir* = getHomeDir() / "Documents" / "Neverwinter Nights"

const
  help* = """
    nasher: a utility for version-controlling Neverwinter Nights development

    Usage:
      nasher init [<dir>]
      nasher compile [<build>]
      nasher build [<build>]
      nasher unpack <file> [<dir>] 
      nasher install <file> [<dir>]
      nasher (list | clean | clobber)

    Commands:
      init <dir>            Initializes a nasher repository in <dir>
      list                  Lists the names and descriptions of all builds
      clean                 Removes the build directory
      clobber               Removes the build directory and all built products
      compile <build>       Compiles all nss sources for <build>
      build <build>         Converts, compiles, and packs <build>'s sources
      unpack <file>         Unpacks <file> into the source tree
      unpack <file> <dir>   Unpacks <file> into the source tree in <dir>
      install <file> <dir>  Installs <file> at <dir> (defaults to the NWN install)

    Global Options:
      -h, --help            Display help for nasher or one of its commands
      -v, --version         Display version information

    Logging:
      --verbose             Turn on debug logging
      --quiet               Turn off all logging except errors
    """


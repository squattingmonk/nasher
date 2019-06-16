import os, strformat

export os, strformat

const nasherVersion* = "nasher 0.1.0"

type
  NasherError* = object of Exception

proc getPkgRoot*: string =
  result = getCurrentDir()

  for dir in parentDirs(result):
    if existsDir(dir / ".nasher"):
      return dir

let
  nwnInstallDir* = getHomeDir() / "Documents" / "Neverwinter Nights"
  userCfgFile* = getConfigDir() / "nasher" / "nasher.cfg"
  pkgCfgFile* = getPkgRoot() / "nasher.cfg"
  buildDir* = getPkgRoot() / ".nasher"
  srcDir* = getPkgRoot() / "src"

const help* = """
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


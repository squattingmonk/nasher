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

proc getPkgRoot*(baseDir = getCurrentDir()): string =
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

template withDir*(dir: string, body: untyped): untyped =
  let curDir = getCurrentDir()
  try:
    setCurrentDir(dir)
    body
  finally:
    setCurrentDir(curDir)

let
  nwnInstallDir* = getHomeDir() / "Documents" / "Neverwinter Nights"

const helpAll* = """
nasher: a build tool for Neverwinter Nights projects

Usage:
  nasher init [options] [<dir> [<file>]]
  nasher list [options]
  nasher compile [options] [<target>]
  nasher pack [options] [<target>]
  nasher install [options] [<target>]
  nasher unpack [options] <file> [<dir>]

Commands:
  init           Initializes a nasher repository
  list           Lists the names and descriptions of all build targets
  compile        Compiles all nss sources for a build target
  pack           Converts, compiles, and packs all sources for a build target
  install        As pack, but installs the target file to the NWN install path
  unpack         Unpacks a file into the source tree
"""

const helpOptions* ="""
Global Options:
  -h, --help     Display help for nasher or one of its commands
  -v, --version  Display version information
  --config FILE  Use FILE rather than default config files (can be repeated)

Logging:
  --debug        Enable debug logging
  --verbose      Enable additional messages about normal operation
  --quiet        Disable all logging except fatal errors
"""

const helpInit* = """
Usage:
  nasher init [options] [<dir> [<file>]]

Description:
  Initializes a directory as a nasher project. If supplied, <dir> will be
  created if needed and set as the project root; otherwise, the current
  directory will be the project root.

  If supplied, <file> will be unpacked into the project root's source tree.
"""

const helpList* = """
Usage:
  nasher list [options]

Description:
  Lists the names of all build targets. These names can be passed to the compile
  or pack commands. If called with --verbose, also lists the descriptions,
  source files, and the filename of the final target.
"""

const helpCompile* = """
Usage:
  nasher compile [options] [<target>]

Description:
  Compiles all nss sources for <target>. If <target> is not supplied, the first
  target supplied by the config files will be compiled. The input and output
  files are placed in $PKG_ROOT/.nasher/build/<target>.

  Compilation of scripts is handled automatically by 'nasher pack', so you only
  need to use this if you want to compile the scripts without converting gff
  sources and packing the target file.
"""

const helpPack* = """
Usage:
  nasher pack [options] [<target>]

Description:
  Converts, compiles, and packs all sources for <target>. If <target> is not
  supplied, the first target supplied by the config files will be packed. The
  assembled files are placed in $PKG_ROOT/.nasher/build/<target>, but the packed
  file is placed in $PKG_ROOT.

  If the packed file would overwrite an existing file, you will be prompted to
  overwrite the file. The newly packaged file will have a modification time
  equal to the modification time of the newest source file. If the packed file
  is newer than the existing file, the default is to overwrite the existing file.

Options:
  --yes, --no    Automatically answer yes/no to the overwrite prompt
  --default      Automatically accept the default answer to the overwrite prompt
"""

const helpInstall* = """
Usage:
  nasher install [options] [<target>]

Description:
  Converts, compiles, and packs all sources for <target>, then installs the
  packed file into the NWN installation directory. If <target> is not supplied,
  the first target found in the config files will be packed and installed.

  The location of the NWN install can be set in the [User] section of the global
  nasher configuration file (default '~/Documents/Neverwinter Nights').

  If the file to be installed would overwrite an existing file, you will be
  prompted to overwrite it. The default answer is to keep the newer file.

Options:
  --yes, --no    Automatically answer yes/no to the overwrite prompt
  --default      Automatically accept the default answer to the overwrite prompt
"""

const helpUnpack* = """
Usage:
  nasher unpack [options] <file> [<dir>]

Description:
  Unpacks <file> into the source tree (default: $PKG_ROOT/src), or <dir> if
  supplied.

  By default, the files are placed directly into the source folder. To customize
  the location of a file in the source tree, you can add a [FileMap] section to
  the package config. Each pattern in the filemap is tried until one matches the
  file. When a match is found, it is placed into the appropriate folder.

  If an unpacked source would overwrite an existing source, you will be prompted
  to overwrite the file. The newly unpacked file will have a modification time
  less than or equal to the modification time of the file being unpacked. If the
  source file is newer than the existing file, the default is to overwrite the
  existing file.

Options:
  --yes, --no    Automatically answer yes/no to the overwrite prompt
  --default      Automatically accept the default answer to the overwrite prompt
"""

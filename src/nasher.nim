import os, osproc, strutils, logging

import nasher/common
import nasher/config
import nasher/opts
import nasher/erf
import nasher/gff

proc showHelp(kind: CommandKind) =
  echo help

proc isNasherProject(): bool =
  existsFile(getPkgCfgFile())

proc nasherUnpack(dir, file: string, cfg: var Config) =
  if not existsFile(file):
    fatal(fmt"Cannot unpack file {file}: file does not exist")
    quit(QuitFailure)

  let cacheDir = file.getCacheDir()

  try:
    createDir(cacheDir)
  except OSError:
    let msg = osErrorMsg(osLastError())
    fatal(fmt"Could not create build directory {cacheDir}: {msg}")
    quit(QuitFailure)

  try:
    extractErf(file, cacheDir)
  except IOError:
    fatal(fmt"Could not extract {file}")
    quit(QuitFailure)

  for ext in GffExtensions:
    createDir(dir / ext)
    for file in walkFiles(cacheDir / "*".addFileExt(ext)):
      gffConvert(file, dir / ext)

  createDir(dir / "nss")
  for file in walkFiles(cacheDir / "*".addFileExt("nss")):
    copyFileWithPermissions(file, dir / "nss" / file.extractFilename())

proc nasherInit(dir, file: string) =
  let userCfgFile = getUserCfgFile()
  if not existsFile(userCfgFile):
    # TODO: allow user to input desired values before writing
    writeCfgFile(userCfgFile, userCfgText)

  let pkgCfgFile = dir / "nasher.cfg"
  if not existsFile(pkgCfgFile):
    notice(fmt"Initializing into {dir}...")
    # TODO: allow user to input desired values before writing
    writeCfgFile(pkgCfgFile, pkgCfgText)
    notice("Successfully initialized project")
  else:
    error(fmt"{dir} is already a nasher project")
    quit(QuitFailure)

  if file.len() > 0:
    setCurrentDir(dir)
    var cfg = loadConfig()
    let filePath = file.relativePath(dir)
    nasherUnpack(getSrcDir(), filePath, cfg)

proc nasherList() =
  echo "Listing builds..."

proc nasherCompile(build: string) =
  echo fmt"Compiling build {build}..."

proc nasherBuild(build: string) =
  echo fmt"Building {build}..."

proc nasherInstall(file, dir: string) =
  echo fmt"Installing {file} into {dir}..."

proc nasherClean() =
  echo "Cleaning..."

proc nasherClobber() =
  echo "Clobbering..."


# proc nasherCompile() =
#   if not existsDir(buildDir):
#     try:
#       say "Compiling scripts..."
#       say "  * Creating build directory at " & buildDir
#       createDir(buildDir)
#     except:
#       quit "Error: could not create build directory"

#   let
#     config = loadConfig(config_file)
#     compiler = config.getOption("compiler", "binary")
#     flags = config.getOption("compiler", "flags")

#   # TODO: handle files from build section
#   let files = @(args["<file>"])
#   var outfile: string

#   for file in files:
#     for file in glob.walkGlob(file):
#       outfile = "-r " & buildDir / splitFile(file).name & ".ncs"
#       echo "{compiler} {flags} {outfile} {file}".fmt

# proc nasherBuild(build: string = "build") =
#   let config = loadConfig(config_file)
#   let filename = config.getOption(build, "file")
#   let filetype = splitFile(filename).ext.substr(1)
#   case filetype
#     of "erf", "hak", "mod":
#       say "Building " & filename
#     else:
#       quit "Error: cannot build {filename}: invalid file type".fmt

#   try:
#     say "  * Creating build directory at " & buildDir
#     createDir(buildDir)
#   except:
#     quit "Error: could not create build directory"

#   setCurrentDir(root_dir)
#   say "  * Converting to gff..."
#   for file in walkGlob(config.getSectionValue(build, "gff")):
#     discard execCmd("nwn-gff -i " & file & " -o " & build_dir / splitFile(file).name)

#   say "  * Compiling scripts..."
#   for file in walkGlob(config.getSectionValue(build, "nss")):
#     copyFileWithPermissions(file, build_dir / file.extractFilename())

#   nasherCompile()

#   say " * Packing file..."
#   let cmd = @["nwn-erf", if existsFile(filename): "-a" else: "-c",
#               "--" & filetype, "-f " & filename, build_dir / "*"]
#   discard execCmd(cmd.join(" "))




when isMainModule:
  let args = parseCmdLine()

  setLogFilter(args.verbosity)
  addHandler(newConsoleLogger(fmtStr = "[$levelname]: "))
  debug(args)

  if args.cmd.kind notin {cmdNil, cmdInit}:
    if not isNasherProject():
      fatal("This is not a nasher project. Please run nasher init.")
      quit(QuitFailure)

  var cfg: Config
  if args.cmd.kind in {cmdList, cmdCompile, cmdBuild}:
    cfg = loadConfig()

  
  if args.showHelp:
    showHelp(args.cmd.kind)
  else:
    case args.cmd.kind
    of cmdClean:
      nasherClean()
    of cmdClobber:
      nasherClean()
      nasherClobber()
    of cmdList:
      nasherList()
    of cmdInit:
      nasherInit(args.cmd.dir, args.cmd.file)
    of cmdCompile:
      nasherCompile(args.cmd.build)
    of cmdBuild:
      nasherBuild(args.cmd.build)
    of cmdUnpack:
      nasherUnpack(args.cmd.dir, args.cmd.file, cfg)
    of cmdInstall:
      nasherInstall(args.cmd.dir, args.cmd.file)
    of cmdNil:
      echo nasherVersion

  # if args["clean"]:
  #   removeDir(build_dir)
  # elif args["clobber"]:
  #   removeDir(build_dir)
  #   for file in walkGlob("*.{erf,hak,mod}", root = root_dir):
  #     removeFile(file)

import os, osproc, strutils, logging

import nasher/common
import nasher/config
import nasher/opts

proc showHelp(kind: CommandKind) =
  echo help

proc isNasherProject(): bool =
  existsFile(pkgCfgFile)

proc nasherInit(dir: string) =
  if not existsFile(userCfgFile):
    # TODO: allow user to input desired values before writing
    writeCfgFile(userCfgFile, userCfgText)

  let nasherFile = dir / "nasher.cfg"
  if not existsFile(nasherFile):
    notice(fmt"Initializing into {dir}...")
    # TODO: allow user to input desired values before writing
    writeCfgFile(nasherFile, pkgCfgText)
    notice("Successfully initialized project")
  else:
    error(fmt"{dir} is already a nasher project")
    quit(QuitFailure)

proc nasherList() =
  echo "Listing builds..."

proc nasherCompile(build: string) =
  echo fmt"Compiling build {build}..."

proc nasherBuild(build: string) =
  echo fmt"Building {build}..."

proc nasherUnpack(file, dir: string) =
  echo fmt"Unpacking {file} into {dir}..."

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
      nasherInit(args.cmd.dir)
    of cmdCompile:
      nasherCompile(args.cmd.build)
    of cmdBuild:
      nasherBuild(args.cmd.build)
    of cmdUnpack:
      nasherUnpack(args.cmd.file, args.cmd.dir)
    of cmdInstall:
      nasherInstall(args.cmd.file, args.cmd.dir)
    of cmdNil:
      echo nasherVersion

  # if args["clean"]:
  #   removeDir(build_dir)
  # elif args["clobber"]:
  #   removeDir(build_dir)
  #   for file in walkGlob("*.{erf,hak,mod}", root = root_dir):
  #     removeFile(file)

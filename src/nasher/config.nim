import logging, os, osproc, parsecfg, streams, strutils, tables

import common

const userCfgText* = """
[User]
name = ""
email = ""
install = "~/Documents/Neverwinter Nights"

[Compiler]
binary = "nwnsc"
flags = "-lowqey"

[ErfUtil]
binary = "nwn_erf"
flags = ""

[GffUtil]
binary = "nwn_gff"
flags = "-p"
"""

const pkgCfgText* = """
[Package]
name = "Demo Package"
description = "This is a demo package"
version = "0.1.0"
author = "Squatting Monk <squattingmonk@gmail.com>"
url = "www.example.com"
flat = false

[Build]
name = "demo"
description = "This is a demo module"
file = "demo.mod"
source = "src/*"
source = "demo/src/*"
"""


type
  Config* = object
    install*: string
    user*: tuple[name, email: string]
    name*, description*, version*, url*: string
    flat*: bool
    compiler*, erf*, gff*: tuple[binary: string, flags: seq[string]]
    authors*: seq[string]
    builds*: Table[string, Build]

  Build = object
    name*, file*, description*: string
    sources*: seq[string]

proc writeCfgFile*(fileName, text: string) =
  let
    absPath = if fileName.isAbsolute(): fileName else: getCurrentDir() / fileName
    relPath = absPath.relativePath(getCurrentDir())

  try:
    notice(fmt"Creating configuration file at {relPath}")
    createDir(fileName.splitFile().dir)
    writeFile(fileName, text)
  except IOError:
    fatal(fmt"Could not create config file at {relPath}")
    quit(QuitFailure)

proc initConfig(): Config =
  result.install = getHomeDir() / "Documents" / "Neverwinter Nights"
  result.compiler = ("nwnsc", @["-lowqey"])
  result.erf = ("nwn_erf", @[""])
  result.gff = ("nwn_gff", @[""])

proc initBuild(): Build =
  result

proc addBuild(cfg: var Config, build: Build) =
  if build.name.len() > 0:
    cfg.builds[build.name.normalize()] = build

proc parseConfig*(fileName: string, cfg: var Config) =
  var f = newFileStream(fileName)
  if not isNil(f):
    info(fmt"Reading config file {fileName}")
    var p: CfgParser
    var section, key: string
    var build = initBuild()
    p.open(f, fileName)
    while true:
      var e = p.next()
      case e.kind
      of cfgEof: break
      of cfgSectionStart:
        cfg.addBuild(build)
        debug(fmt"Parsing section [{e.section}]")
        section = e.section.normalize()
      of cfgKeyValuePair, cfgOption:
        key = e.key.normalize()
        debug(fmt"Found key/value pair {key}: {e.value}")
        case section
        of "user":
          case key:
          of "name": cfg.user.name = e.value
          of "email": cfg.user.email = e.value
          of "install": cfg.install = e.value
          else: discard
        of "compiler":
          case key
          of "binary": cfg.compiler.binary = e.value
          of "flags": cfg.compiler.flags.add(e.value)
          else: discard
        of "erfutil":
          case key
          of "binary": cfg.erf.binary = e.value
          of "flags": cfg.erf.flags.add(e.value)
          else: discard
        of "gffutil":
          case key
          of "binary": cfg.gff.binary = e.value
          of "flags": cfg.gff.flags.add(e.value)
          else: discard
        of "package":
          case key
          of "name": cfg.name = e.value
          of "description": cfg.description = e.value
          of "version": cfg.version = e.value
          of "author": cfg.authors.add(e.value)
          of "url": cfg.url = e.value
          of "flat":
            try:
              cfg.flat = e.value.parseBool()
            except ValueError:
              let shortName = fileName.extractFilename()
              error(fmt"Unknown value '{e.value}' for key '{e.key}' in {shortName}")
          else: discard
        of "build":
          case key
          of "name": build.name = e.value
          of "description": build.description = e.value
          of "file": build.file = e.value
          of "source": build.sources.add(e.value)
          else: discard
        else:
          info(fmt"Unkown section [{section}]")
      of cfgError:
        error(e.msg)
    p.close()
  else:
    fatal(fmt"Cannot open {fileName}")
    quit(QuitFailure)

proc dumpConfig(cfg: Config) =
  if getLogFilter() != lvlDebug:
    return

  debug("Dumping config...")
  debug "user.name: ", cfg.user.name.escape()
  debug "user.email: ", cfg.user.name.escape()
  debug "install: ", cfg.install.escape()
  debug "name: ", cfg.name.escape()
  debug "description: ", cfg.description.escape()
  debug "version: ", cfg.version.escape()
  debug "url: ", cfg.url.escape()
  debug "flat: ", cfg.flat
  for author in cfg.authors:
    debug "author: ", author

  for key, build in cfg.builds.pairs():
    debug "builds[", key, "].name: ", build.name.escape()
    debug "builds[", key, "].description: ", build.description.escape()
    debug "builds[", key, "].file: ", build.file.escape()
    for source in build.sources:
      debug "builds[", key, "].source: ", source.escape()

  debug("End dump")


proc loadConfig*(): Config =
  result = initConfig()
  parseConfig(userCfgFile, result)
  parseConfig(pkgCfgFile, result)
  dumpConfig(result)

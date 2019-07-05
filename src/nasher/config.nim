import os, osproc, parsecfg, streams, strformat, strutils, tables

import common
export common


const globalCfgText* = """
[User]
name = ""
email = ""
install = "~/Documents/Neverwinter Nights"

[Compiler]
binary = "nwnsc"
flags = "-lowqey"
"""

const pkgCfgText* = """
[Package]
name = "Demo Package"
description = "This is a demo package"
version = "0.1.0"
author = "Squatting Monk <squattingmonk@gmail.com>"
url = "www.example.com"

[Target]
name = "sm-utils"
description = "These are utilities"
file = "sm_utils.erf"
source = "../sm-utils/src/*"

[Target]
name = "Demo"
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
    compiler*: tuple[binary: string, flags: seq[string]]
    authors*: seq[string]
    targets*: OrderedTable[string, Target]

  Target* = object
    name*, file*, description*: string
    sources*: seq[string]

proc writeCfgFile*(fileName, text: string) =
  tryOrQuit("Could not create config file at " & fileName):
    display("Creating", "configuration file at " & fileName)
    createDir(fileName.splitFile().dir)
    writeFile(fileName, text)

proc initConfig(): Config =
  result.install = getNwnInstallDir()
  result.compiler.binary = "nwnsc"

proc initTarget(): Target =
  result.name = ""

proc addTarget(cfg: var Config, target: Target) =
  if target.name.len() > 0:
    cfg.targets[target.name] = target

proc parseUser(cfg: var Config, key, value: string) =
  case key
  of "name": cfg.user.name = value
  of "email": cfg.user.email = value
  of "install": cfg.install = value
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
  of "name": cfg.name = value
  of "description": cfg.description = value
  of "version": cfg.version = value
  of "author": cfg.authors.add(value)
  of "url": cfg.url = value
  of "flat": cfg.flat = parseBool(value)
  else:
    error(fmt"Unknown key/value pair '{key}={value}'")

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
    error(fmt"Cannot open config file: {fileName}")
    quit(QuitFailure)

  debug("File:", fileName)
  var p: CfgParser
  var section, key: string
  var target: Target
  var hasRun = false
  p.open(f, fileName)
  while true:
    var e = p.next()
    case e.kind
    of cfgEof: break
    of cfgSectionStart:
      cfg.addTarget(target)

      debug("Section:", fmt"[{e.section}]")
      section = e.section.normalize
      target = initTarget()

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
        of "target":
          parseTarget(target, key, e.value)
        else:
          discard
    of cfgError:
      error(e.msg)
  cfg.addTarget(target)
  p.close()

proc dumpConfig(cfg: Config) =
  if not isLogging(Debug):
    return

  sandwich:
    debug("Beginning", "configuration dump")

  debug("User:", cfg.user.name)
  debug("Email:", cfg.user.email)
  debug("Compiler:", cfg.compiler.binary)
  debug("Flags:", cfg.compiler.flags.join("\n"))
  debug("NWN Install:", cfg.install)
  debug("Package:", cfg.name)
  debug("Description:", cfg.description)
  debug("Version:", cfg.version)
  debug("URL:", cfg.url)
  debug("Authors:", cfg.authors.join("\n"))

  for target in cfg.targets.values:
    stdout.write("\n")
    debug("Target:", target.name)
    debug("Description:", target.description)
    debug("File:", target.file)
    debug("Sources:", target.sources.join("\n"))

  sandwich:
    debug("Ending", "configuration dump")


proc loadConfig*(configs: seq[string]): Config =
  result = initConfig()
  var hasRun = false
  for config in configs:
    doAfterDebug(hasRun):
      stdout.write("\n")
    result.parseConfig(config)
  result.dumpConfig()

import osproc, parseutils, sequtils, streams, strutils

import cli

proc parseCompilerOutput(line: var string) =
  ## Intercepts nwnsc's output and converts it into nasher's cli format
  var
    token: string
    parsed = line.parseUntil(token, ':') + 2

  case token
  of "Compiling":
    info("Compiling", line[parsed..^1])
  of "Error":
    error(line[parsed..^1])
  else:
    if token == line:
      discard
    else:
      var lines = line.split(':').mapIt(it.strip)
      if lines.contains("Error"):
        error(lines.filterIt(it != "Error").join("\n"))
      elif lines.contains("Warning"):
        warning(lines.filterIt(it != "Warning").join("\n"))
      else:
        display(lines.join("\n"))

proc runCompiler*(cmd: string, args: openArray[string] = []): int =
  ## Runs the nwnsc compiler and returns its error code
  result = -1
  let
    params = args.filterIt(it.len > 0)
    options = {poUsePath, poStdErrToStdOut}

  var
    p = startProcess(cmd, args = params, options = options)
    s = p.outputStream
    line = ""

  while true:
    if s.readLine(line):
      line.parseCompilerOutput
    else:
      result = p.peekExitCode
      if result != -1:
        break

  p.close()

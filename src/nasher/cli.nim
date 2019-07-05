import sequtils, strutils, terminal

type
  CLI = ref object
    showColor: bool
    logLevel: Priority
    forceAnswer: Answer

  DisplayType* = enum
    Error, Warning, Message, Success

  Priority* = enum
    Debug, Low, Medium, High

  Answer* = enum
    None, No, Yes, Default

const
  colWidth = len("Initializing")
  foregrounds:array[Error .. Success, ForegroundColor] =
    [fgRed, fgYellow, fgCyan, fgGreen]
  styles: array[Debug .. High, set[Style]] =
    [{styleDim}, {styleDim}, {}, {styleBright}]

var cli = CLI(showColor: stdout.isatty, logLevel: Medium, forceAnswer: None)

proc setLogLevel*(level: Priority) =
  cli.logLevel = level

proc isLogging*(level: Priority): bool =
  cli.logLevel <= level

proc setShowColor*(val: bool) =
  cli.showColor = val

proc setForceAnswer*(val: Answer) =
  cli.forceAnswer = val

proc displayCategory(category: string, displayType: DisplayType, priority: Priority) =
  let
    offset = max(0, colWidth - category.len)
    text =
      if stdout.isatty: "$#$# " % [spaces(offset), category]
      else: category & " "

  if cli.showColor:
    if priority != Debug:
      setForegroundColor(stdout, foregrounds[displayType])
    writeStyled(text, styles[priority])
    resetAttributes()
  else:
    stdout.write(text)

proc displayLine(category, line: string, displayType: DisplayType, priority: Priority) =
  displayCategory(category, displayType, priority)
  echo(line)

proc getMsgWidth(category: string): int =
  let maxWidth = if stdout.isatty: terminalWidth() - category.len else: 80
  result = maxWidth - colWidth - 1

proc display*(category, msg: string, displayType = Message, priority = Medium) =
  ## Displayes a message in the format "{category} {msg}" if the log level is at
  ## or below the given priority. The message is styled based on displayType.
  if priority < cli.logLevel:
    return

  # Word wrap each line so it fits in the terminal
  let
    width = getMsgWidth(category)
    lines = msg.splitLines.mapIt(it.wordWrap(width)).join("\n").splitLines

  var i = 0
  for line in lines:
    if line.len == 0: continue
    displayLine(if i == 0: category else: "...", line, displayType, priority)
    i.inc

proc display*(msg: string, displayType = Message, priority = Medium) =
  ## Convenience proc to display a message with no category
  display("", msg, displayType, priority)

proc debug*(category, msg: string) =
  ## Convenience proc for displaying debug messages
  display(category, msg, priority = Debug)

proc debug*(msg: string) =
  ## Convenience proc for displaying debug messages with a default category
  debug("Debug:", msg)

proc info*(category, msg: string) =
  ## Convenience proc for displaying low priority messages
  display(category, msg, priority = Low)

proc warning*(msg: string, priority: Priority = Medium) =
  ## Convenience proc for displaying warnings
  display("Warning:", msg, displayType = Warning, priority = priority)

proc error*(msg: string) =
  ## Convenience proc for displaying errors
  display("Error:", msg, displayType = Error, priority = High)

proc fatal*(msg: string) =
  ## Displays msg as an error, then quits, sending an error code
  error(msg)
  quit(QuitFailure)

proc success*(msg: string, priority: Priority = Medium) =
  display("Success:", msg, displayType = Success, priority = priority)

proc prompt*(question: string, default: Answer = No): bool =
  ## Displays a yes/no question/answer prompt to the user. If the user does not
  ## choose an answer or that answer cannot be converted into a bool, the
  ## default answer is chosen instead. If the user has passed a --yes, --no, or
  ## --default flag, the appropriate choice will be selected.
  let forceAnswer =
    if cli.forceAnswer == Default: default
    else: cli.forceAnswer

  case forceAnswer
  of Yes:
    display("Prompt:", question & " -> [forced yes]", Warning, High)
    result = true
  of No:
    display("Prompt:", question & " -> [forced no]", Warning, High)
    result = false
  else:
    let tip = if default == Yes: " (Y/n)" else: " (y/N)"
    display("Prompt:", question & tip, Warning, High)
    displayCategory("Answer:", Warning, High)
    let answer = stdin.readLine
    try:
      result = answer.parseBool
    except ValueError:
      result = default == Yes

  debug("Answer:", $result)

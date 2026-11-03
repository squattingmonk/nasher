import pegs, streams, strutils

let
  pCommentOpen = peg"""
    open <- code* unclosed
    code <- strlit / mlcomment / !(mlstart / slstart) .
    unclosed <- mlstart !@ mlend
    strlit <- '"' ('\\' . / [^"])* '"'
    mlcomment <- mlstart @ mlend
    mlstart <- '/*'
    mlend <- '*/'
    slstart <- '//'
    """

  pCommentClose = peg"""
    close <- @ '*/'
    """

  pExec = peg"""
    execfunc <- (mlcomment / \s)* (main / conditional) \s* '(' \s* ')'
    main <- 'void' \s+ 'main'
    conditional <- 'int' \s+ 'StartingConditional'
    mlcomment <- @ '*/'
    """

  pInclude = peg"""
    file <- skip* '#include' \s+ '"' {\ident+} '"' skip* (slstart / mlstart / !.)
    skip <- \s / mlcomment
    mlcomment <- mlstart @ mlend
    mlstart <- '/*'
    mlend <- '*/'
    slstart <- '//'
    """

iterator codeLines(s: Stream): string =
  ## Yields each line of `s` that is not entirely inside a multi-line comment.
  ## If a line closes a multi-line comment, only the text after the `*/` is
  ## yielded. Single-line comments and comments opened and closed on the same
  ## line are left in place for the caller to skip.
  var
    line: string
    comment = false

  while s.readLine(line):
    if comment:
      let closeLen = line.matchLen(pCommentClose)
      if closeLen >= 0:
        comment = false
        line = line[closeLen .. ^1]
      else:
        continue

    yield line
    if line.match(pCommentOpen):
      comment = true

proc executable*(script: string): bool =
  ## Returns whether `script` contains a main() or StartingConditional()
  ## function and is thus executable nwscript.
  for line in openFileStream(script).codeLines:
    if line.match(pExec):
      return true

iterator included*(script: string): string =
  ## Yields all files inluded in the nwscript file `script`.
  for line in openFileStream(script).codeLines:
    if line =~ pInclude:
      yield matches[0].toLower

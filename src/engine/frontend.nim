import ../chess

import std/parseutils
import std/strutils
import std/sequtils
import std/options
import std/streams
import std/re

#[
  Simple UCI compliant controls
  https://gist.github.com/aliostad/f4470274f39d29b788c1b09519e67372
  http://wbec-ridderkerk.nl/html/UCIProtocol.html

  Application split into multiple parts:
    Front end handles IO, parsing
    Middle end manages state, timings, start/stop
    Back end handles computation
]#
#[
  Handled by front-end:
    uci ->
      id ...
      id ...
      uciok

    debug [ on | off ] -> [ignore]

    ponderhit -> [ignore]

    quit

    isready ->
      readyok

    ucinewgame -> [ignore]

  Passed to middle/back-end
    position [ fen | startpos ] moves ...

    go
        ponder
        wtime
        btime
        winc
        binc
        movestogo
        depth
        nodes
        mate
        movetime
        infinite

    stop

e.g.
go wtime 131000 btime 114260 winc 3000 binc 3000
info depth 6 seldepth 6 multipv 1 score cp 1026 nodes 322 nps 322000 tbhits 0 time 1 pv b3b5 d8c8 d2a5 e7d8 b5c5 g6f8
bestmove b3b5 ponder d8c8

]#

type
  CommandType* = enum
    cmdGo, cmdPosition, cmdStop, cmdNewgame

  GoCommand* = object
    wtime*: int
    btime*: int
    winc*: int
    binc*: int
    movestogo*: int
    depth*: int
    nodes*: int
    movetime*: int
    mate*: int
    infinite*: bool
    ponder*: bool

  PositionCommand* = object
    fen*: string
    moves*: seq[Move]

  Command* = object
    case kind*: CommandType
    of cmdGo:
      go*: GoCommand
    of cmdPosition:
      pos*: PositionCommand
    of cmdStop:
      discard
    of cmdNewgame:
      discard

  SearchInfo* = object
    depth*: int
    time*: int
    nodes*: int
    pv*: seq[Move]
    score*: int

  SearchResult* = object
    bestmove*: Move


func splitCmd(command: string): tuple[cmd: string, rest: string] =
  let s = splitWhitespace(command, 1)
  if len(s) > 0:
    result.cmd = s[0].toLowerAscii()
  if len(s) > 1:
    result.rest = s[1]


let algebraicMovePattern = re"^[a-h][1-8][a-h][1-8][nbrq]?$"

proc parseAlgebraic(s: string): Option[Move] =
  let algebraic = s.toLowerAscii().replace('o','0')

  if match(algebraic, algebraicMovePattern):
    let src = square(int(algebraic[0]) - int('a'), int(algebraic[1]) - int('1'))
    let dst = square(int(algebraic[2]) - int('a'), int(algebraic[3]) - int('1'))
    let special =
      if len(algebraic) > 4:
        case algebraic[4]:
        of 'n': promoteKnight
        of 'b': promoteBishop
        of 'r': promoteRook
        of 'q': promoteQueen
        else : raiseAssert("Logic error")
      else:
        normal

    result = some(Move(
      src:src,
      dst:dst,
      special:special,
    ))


func `$`*(si: SearchInfo): string =
  result = "info"
  if si.depth >= 0:
    result.add(" depth ")
    result.add($si.depth)
  if si.time > 0:
    result.add(" time ")
    result.add($si.time)
  if si.nodes > 0:
    result.add(" nodes ")
    result.add($si.nodes)
  if si.time > 0 and si.nodes > 0:
    result.add(" nps ")
    result.add($(1000 * si.nodes / si.time))

  result.add(" score cp ")
  result.add($si.score)

  if len(si.pv) > 0:
    result.add(" pv")
    for m in si.pv:
      result.add(' ')
      result.add(uci(m))


func `$`*(sr: SearchResult): string =
  result = "bestmove "
  result.add(uci(sr.bestmove))


func parseGoCommand(command: string): GoCommand =
  var word, args: string
  args = command

  proc next(): bool =
    (word, args) = splitCmd(args)
    len(word) > 0

  while next():
    var x: int
    for name, value in fieldPairs(result):
      if word == name:
        when value is int:
          if next() and parseSaturatedNatural(word, x) > 0:
            value = x
        when value is bool:
          value = true


proc parsePositionCommand(command: string): PositionCommand =
  let parts = split(command, "moves", 1)
  if len(parts) > 0:
    let (cmd, args) = splitCmd(parts[0])
    if cmd == "startpos":
      result.fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    elif cmd == "fen":
      result.fen = args

  if len(parts) > 1:
    for move in splitWhitespace(parts[1]):
      let mv = parseAlgebraic(move)
      if isSome(mv):
        result.moves.add(get(mv))


proc RunUCIFrontEnd*(name: string, input: Stream, channel: ptr Channel[Command]) =
  for line in lines(input):
    let (cmd, args) = splitCmd(line)

    if false: discard
    elif cmd == "uci":
      echo "id name " & name
      echo "id author Greg"
      echo "uciok"
    elif cmd == "quit":
      quit(QuitSuccess)
    elif cmd == "isready":
      echo "readyok"
    elif cmd == "position":
      let pos = Command(kind: cmdPosition, pos: parsePositionCommand(args))
      channel[].send(pos)
    elif cmd == "ucinewgame":
      discard
    elif cmd == "stop":
      let stop = Command(kind: cmdStop)
      channel[].send(stop)
    elif cmd == "go":
      let go = Command(kind: cmdGo, go: parseGoCommand(args))
      channel[].send(go)


proc showError*(s: string) =
  echo "info string | Error | " & s
  echo "info string | Error | " & getCurrentExceptionMsg()


proc toBoard*(pos: PositionCommand): Board =
  try:
    result = fromFen(pos.fen)
  except FenError:
    showError("Unable to parse fen")
    result = fromFen(startposFen)

  for move in pos.moves:
    let ml = if (result.player == black):
      result.flip()
      var m = pseudoMoves(result)
      m.apply(proc(x:Move):Move=x.flip)
      result.flip()
      m
    else:
      pseudoMoves(result)

    for movegen in ml:
      if move.src == movegen.src and move.dst == movegen.dst:
        if move.special == normal or move.special == movegen.special:
          discard makeMove(result, movegen)

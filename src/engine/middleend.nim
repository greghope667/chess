#[
  Rngines that simply provide a search(board, depth) function
  can use this to handle the front end. Ignores all `go` command
  options
]#

import ../chess
import frontend
import std/[times, streams]

type SearchFunction* = proc(b: var Board, depth: int): tuple[move:Move, score:int, nodes:int] {.thread.}

var
  board: Board
  channel: Channel[Command]
  worker: Thread[void]
  search*: SearchFunction

proc doSearch() =
  var si: SearchInfo
  var sr: SearchResult

  let startTime = cpuTime()

  si.depth = 4
  let flip = board.player == black

  if flip:
    board.flip()

  (sr.bestmove, si.score, si.nodes) = search(board, si.depth)

  if flip:
    sr.bestmove = sr.bestmove.flip()
    board.flip()

  si.pv.add(sr.bestmove)

  let endTime = cpuTime()
  si.time = int(1000 * (endTime - startTime))

  echo si
  echo sr

proc backEnd() =
  while true:
    let cmd = channel.recv()
    case cmd.kind:
    of cmdGo:
      doSearch()
    of cmdPosition:
      board = toBoard(cmd.pos)
    else:
      discard

proc run*(name: string) =
  channel.open()
  createThread(worker, backEnd)
  RunUciFrontEnd(name, newFileStream stdin, addr channel)
  quit(QuitSuccess)

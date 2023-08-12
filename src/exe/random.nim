import ../chess
import ../engine/middleend
import std/random

randomize()

proc search(board: var Board, depth: int): tuple[move:Move, score:int, nodes:int] =
  var legalmoves: seq[Move]
  for move in pseudoMoves(board):
    let hist = makeMove(board, move)
    if not inCheck(board):
      legalmoves.add(move)
    unmakeMove(board, move, hist)
  result.move = sample(legalmoves)

middleend.search = search
middleend.run("random")

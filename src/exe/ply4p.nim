import ../chess
import ../engine/middleend
import std/random

const pieceValues: array[0..6, int] = [
  none: 0,
  king: 200,
  queen: 9,
  rook: 5,
  bishop: 3,
  knight: 3,
  pawn: 1,
]

randomize()

var
  nodes: int
  rng = initRand()

proc randAdjust(): int =
  let x = int64(rng.next())
  x shr 62

func colorMod(color: Color): int =
  const cmod: array[0..1, int] = [
    white: 1,
    black: -1,
  ]
  cmod[uint8(color)]

func evaluate(board: var Board): int =
  for s in squares():
    let pc = board[s]
    result += colorMod(pc.color) * pieceValues[uint8(pc.tp)] * 100
    if pc.tp == pawn:
      let rank = coords(s).rank
      if pc.color == white:
        result += 5 * rank
      else:
        result += 5 * (rank - 7)

  when true: # false for faster but worse moves
    result += pseudoMoves(board).len
    board.flip()
    result -= pseudoMoves(board).len
    board.flip()

proc negamax(board: var Board, depth: int): tuple[move:Move, score:int] =
  if depth <= 0:
    result.score = evaluate(board)
    return result

  result.score = low(int)

  for move in pseudoMoves(board):
    let hist = makeMove(board, move)
    if not inCheck(board):
      nodes += 1
      board.flip()
      let score = - negamax(board, depth-1).score + randAdjust()
      if score > result.score:
        result.move = move
        result.score = score
      board.flip()
    unmakeMove(board, move, hist)

  if result.score == low(int):
    if inCheck(board):
      result.score = -10000
    else:
      result.score = 0

  if result.score < -100:
    result.score += 1
  elif result.score > 100:
    result.score -= 1

proc search(board: var Board, depth: int): tuple[move:Move, score:int, nodes:int] =
  nodes = 0
  (result.move, result.score) = negamax(board, 4)
  result.nodes = nodes

middleend.search = search
middleend.run("4ply+")

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

proc quiesce(board: var Board, alphap, beta, depth: int): int =
  let stand_pat = evaluate(board)

  if depth <= 0:
    return stand_pat

  var alpha = alphap

  if stand_pat >= beta:
    return beta
  elif alpha < stand_pat:
    alpha = stand_pat

  for move in pseudoMoves(board):
    if board[move.dst].occupied:
      let hist = makeMove(board, move)

      if not inCheck(board):
        nodes += 1
        board.flip()
        let score = - quiesce(board, -beta, -alpha, depth-1)
        board.flip()

        if score >= beta:
          unmakeMove(board, move, hist)
          return beta
        if score > alpha:
          alpha = score

      unmakeMove(board, move, hist)

  alpha

const
  minus_inf = low(int) shr 1
  plus_inf = high(int) shr 1

proc alphaBeta(board: var Board, alphap, beta, depth: int): int =
  if depth <= 0:
    return quiesce(board, alphap, beta, 6)

  var alpha = alphap
  var bestscore = minus_inf

  var moves = pseudoMoves(board)
  moves.shuffle()

  for move in moves:
    let hist = makeMove(board, move)
    if not inCheck(board):
      nodes += 1
      board.flip()
      let score = -alphaBeta(board, -beta, -alpha, depth-1)
      board.flip()

      if score >= beta:
        unmakeMove(board, move, hist)
        return beta
      if score > bestscore:
        bestscore = score
        if score > alpha:
          alpha = score
    unmakeMove(board, move, hist)

  if bestscore == minus_inf:
    if inCheck(board):
      # Checkmate
      bestscore = -10000
    else:
      # Stalemate
      bestscore = 0

  if bestscore < -100:
    bestscore += 1
  elif bestscore > 100:
    bestscore -= 1

  bestscore


proc alphaBetaRoot(board: var Board, depth: int): tuple[move:Move, score:int] =
  result.score = minus_inf

  for move in pseudoMoves(board):
    let hist = makeMove(board, move)

    if not inCheck(board):
      nodes += 1
      board.flip()
      let score = -alphaBeta(board, minus_inf, plus_inf, depth-1) + randAdjust()
      board.flip()

      if score > result.score:
        result.move = move
        result.score = score

    unmakeMove(board, move, hist)

proc search(board: var Board, depth: int): tuple[move:Move, score:int, nodes:int] =
  nodes = 0
  (result.move, result.score) = alphaBetaRoot(board, 4)
  result.nodes = nodes

middleend.search = search
middleend.run("ab")

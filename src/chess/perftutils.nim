import ./[boarddef, movedef, movegen]

func perftrec(board: var Board, moves: int): int =
  if moves <= 0:
    return 1

  forAllLegalMoves(board):
    result += perftrec(board, moves-1)

func perft*(board: var Board, moves: int): int =
  discard withPlayerAsWhite(board):
    result = perftrec(board, moves)

func perftdiv*(board: var Board, moves: int): seq[tuple[move:Move, count:int]] =
  assert moves > 0
  let flip = withPlayerAsWhite(board):
    for move in pseudoMoves(board):
      withMakeMove(board, move):
        result.add((move, perft(board, moves-1)))

  if flip:
    for i in 0..<result.len:
      result[i].move = result[i].move.flip()


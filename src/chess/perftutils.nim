import ./[boarddef, movedef, movegen]

func perftrec(board: var Board, moves: int): int =
  if moves <= 0:
    return 1

  for move in pseudoMoves(board):
    let hist = makeMove(board, move)

    if not inCheck(board):
      board.flip()
      result += perftrec(board, moves-1)
      board.flip()

    unmakeMove(board, move, hist)


func perft*(board: var Board, moves: int): int =
  let flip = board.player == black

  if flip:
    board.flip

  result = perftrec(board, moves)

  if flip:
    board.flip

func perftdiv*(board: var Board, moves: int): seq[tuple[move:Move, count:int]] =
  assert moves > 0
  let flip = board.player == black

  if flip:
    board.flip

  for move in pseudoMoves(board):
    let hist = makeMove(board, move)

    if not inCheck(board):
      let m = if flip: move.flip() else: move
      result.add((m, perft(board, moves-1)))

    unmakeMove(board, move, hist)

  if flip:
    board.flip

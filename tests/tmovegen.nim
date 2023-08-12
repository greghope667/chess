import chess

proc testMoveUndo() =
  let chessboard = startposFen.fromFen()
  let movelist = pseudoMoves(chessboard)
  assert movelist.len == 20

  for move in movelist:
    var scratch = chessboard
    let undo = makeMove(scratch, move)

    scratch.flip()
    let responses = pseudoMoves(scratch)
    doassert responses.len == 20
    scratch.flip()

    unmakeMove(scratch, move, undo)
    doassert scratch == chessboard

testMoveUndo()

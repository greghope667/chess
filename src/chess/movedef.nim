import boarddef

type
  MoveType* = enum
    normal=0, doublePawn, enPassent, castle, promoteQueen, promoteRook, promoteKnight, promoteBishop

  Move* = object
    piece*: Piece
    src*: Square
    dst*: Square
    special*: MoveType

  BoardPrevState* = object
    # Data needed to 'undo' a move
    capture: SquareContents
    prevCastling: CastlingRights
    prevPawnmove: Square

func flip*(move: Move): Move =
  let bits = cast[uint32](move)
  #[
    70      flip dst square
      70    flip src square
        08  flip piece color
  ]#
  const flips = 0x707008u32
  cast[Move](flips xor bits)

func castlingRightsLost(s: Square): CastlingRights =
  case s:
  of sq"a1":
    {white_queenside}
  of sq"e1":
    {white_queenside, white_kingside}
  of sq"h1":
    {white_kingside}
  of sq"a8":
    {black_queenside}
  of sq"e8":
    {black_kingside, black_queenside}
  of sq"h8":
    {black_kingside}
  else:
    {}

func makeMoveCastle(board: var Board, dst: Square) =
  # Moves the rook after a castle (+ asserts)
  case dst:
  of sq"c1":
    assert board[sq"a1"] == piece(white, rook).onSquare
    assert board[sq"b1"] == emptySquare
    assert board[sq"c1"] == piece(white, king).onSquare
    assert board[sq"d1"] == emptySquare
    assert board[sq"e1"] == emptySquare
    board[sq"a1"] = emptySquare
    board[sq"d1"] = piece(white, rook).onSquare

  of sq"g1":
    assert board[sq"e1"] == emptySquare
    assert board[sq"f1"] == emptySquare
    assert board[sq"g1"] == piece(white, king).onSquare
    assert board[sq"h1"] == piece(white, rook).onSquare
    board[sq"f1"] = piece(white, rook).onSquare
    board[sq"h1"] = emptySquare

  of sq"c8":
    assert board[sq"a8"] == piece(black, rook).onSquare
    assert board[sq"b8"] == emptySquare
    assert board[sq"c8"] == piece(black, king).onSquare
    assert board[sq"d8"] == emptySquare
    assert board[sq"e8"] == emptySquare
    board[sq"a8"] = emptySquare
    board[sq"d8"] = piece(black, rook).onSquare

  of sq"g8":
    assert board[sq"e8"] == emptySquare
    assert board[sq"f8"] == emptySquare
    assert board[sq"g8"] == piece(black, king).onSquare
    assert board[sq"h8"] == piece(black, rook).onSquare
    board[sq"f8"] = piece(black, rook).onSquare
    board[sq"h8"] = emptySquare

  else:
    assert false

func makeMove*(board: var Board, move: Move): BoardPrevState =
  # Check start square matches
  assert move.piece.onSquare == board[move.src]
  # No double-moves
  assert move.piece.color == board.player

  let capture = board[move.dst]
  if capture != emptySquare:
    # No team-kills
    assert (move.piece.color != capture.color)
    result.capture = capture

  board[move.src] = emptySquare
  board[move.dst] = move.piece

  board.player = flip(board.player)
  board.halfMoves += 1
  board.fullMoves += int16(move.piece.color == black)

  result.prevCastling = board.castling
  board.castling.excl(castlingRightsLost(move.src))
  board.castling.excl(castlingRightsLost(move.dst))

  result.prevPawnmove = board.pawnmove
  board.pawnmove = sq"a1"

  if move.piece.tp == king:
    if move.piece.color == black:
      board.blackkingpos = move.dst
    else:
      board.whitekingpos = move.dst

  case move.special:
  of normal:
    discard

  of doublePawn:
    assert move.piece.tp == pawn
    board.pawnmove = move.dst

  of enPassent:
    assert move.piece.tp == pawn
    result.capture = board[result.prevPawnmove]
    board[result.prevPawnmove] = emptySquare

  of castle:
    assert move.piece.tp == king
    makeMoveCastle(board, move.dst)

  of promoteBishop:
    board[move.dst] = piece(move.piece.color, bishop)
  of promoteKnight:
    board[move.dst] = piece(move.piece.color, knight)
  of promoteRook:
    board[move.dst] = piece(move.piece.color, rook)
  of promoteQueen:
    board[move.dst] = piece(move.piece.color, queen)

func unmakeMoveCastle(board: var Board, dst: Square) =
  # Un-Moves the rook after a castle (+ asserts)
  case dst:
  of sq"c1":
    assert board[sq"d1"] == piece(white, rook).onSquare
    assert board[sq"a1"] == emptySquare
    board[sq"d1"] = emptySquare
    board[sq"a1"] = piece(white, rook).onSquare

  of sq"g1":
    assert board[sq"f1"] == piece(white, rook).onSquare
    assert board[sq"h1"] == emptySquare
    board[sq"f1"] = emptySquare
    board[sq"h1"] = piece(white, rook).onSquare

  of sq"c8":
    assert board[sq"d8"] == piece(black, rook).onSquare
    assert board[sq"a8"] == emptySquare
    board[sq"d8"] = emptySquare
    board[sq"a8"] = piece(black, rook).onSquare

  of sq"g8":
    assert board[sq"f8"] == piece(black, rook).onSquare
    assert board[sq"h8"] == emptySquare
    board[sq"f8"] = emptySquare
    board[sq"h8"] = piece(black, rook).onSquare

  else:
    assert false

func unmakeMove*(board: var Board, move: Move, prev: BoardPrevState) =
  # Check start square empty
  assert board[move.src] == emptySquare
  # No double-moves
  assert move.piece.color == flip(board.player)

  board[move.src] = move.piece
  board[move.dst] = prev.capture
  board.fullMoves -= int16(move.piece.color == black)
  board.halfMoves -= 1
  board.player = flip(board.player)

  # Check castling rights history retained
  assert prev.prevCastling >= board.castling
  board.castling = prev.prevCastling

  board.pawnmove = prev.prevPawnmove

  if move.piece.tp == king:
    if move.piece.color == black:
      board.blackkingpos = move.src
    else:
      board.whitekingpos = move.src

  case move.special:
  of normal:
    discard

  of doublePawn:
    assert move.piece.tp == pawn

  of enPassent:
    assert move.piece.tp == pawn
    board[move.dst] = emptySquare
    board[prev.prevPawnmove] = prev.capture

  of castle:
    assert move.piece.tp == king
    unmakeMoveCastle(board, move.dst)

  of promoteBishop:
    discard
  of promoteKnight:
    discard
  of promoteRook:
    discard
  of promoteQueen:
    discard

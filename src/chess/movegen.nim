import ./[boarddef, movedef]
import std/tables

#[
  Generator for all chess moves (assuming a legal chess position).
  pseudo-legal includes moves which end in check illegally

  ONLY GENERATES MOVES FOR WHITE - use board.flip() first if you
  want moves for black.
]#

type
  MoveOutcome = enum
    blocked, empty, capture

  MoveList = seq[Move]

  MoveDir = object
    slide: bool
    dir: array[9,Distance]

func classifyMove(board: Board, dest: Square): MoveOutcome =
  if not dest.inBounds():
    blocked
  elif board[dest] == emptySquare:
    empty
  elif board[dest].color == black:
    capture
  else:
    blocked


func d(x, y: int): Distance = distance(x,y)

const
  z = d(0,0)

  allDirs = [
    d(-1,-1), d(0,-1), d(1,-1),
    d(-1, 0),          d(1, 0),
    d(-1, 1), d(0, 1), d(1, 1),
    z
  ]

  knightDirs = [
      d(-1,-2), d(1,-2),
    d(-2,-1),     d(2,-1),
    d(-2, 1),     d(2, 1),
      d(-1, 2), d(1,2),
    z
  ]

  diagDirs = [
    d(-1,-1), d(1,-1),
    d(-1, 1), d(1, 1),
    z,z,z,z,z
  ]

  orthDirs = [
        d(0,-1),
    d(-1,0), d(1,0),
        d(0, 1),
    z,z,z,z,z
  ]

  pawnAttackDirs = [
    d(-1,1), d(1,1)
  ]

  noDirs = [z,z,z,z,z,z,z,z,z]

  pieceMoveDir = {
    bishop: MoveDir(slide:true, dir: diagDirs),
    knight: MoveDir(slide:false, dir: knightDirs),
    rook: MoveDir(slide:true, dir: orthDirs),
    queen: MoveDir(slide:true, dir: allDirs),
    king: MoveDir(slide:false, dir: allDirs),
    pawn: MoveDir(slide:false, dir: noDirs),
  }.toTable

func pieceMovesSq(list: var MoveList, board: Board, src: Square) =
  let piece = board[src]
  assert (piece.occupied)
  assert (piece.color == white)

  var mv = Move(piece:piece.piece, src:src, special:normal)

  let moveDir = pieceMoveDir[piece.tp]
  for i in 0..8:
    let dir = moveDir.dir[i]

    if dir == z:
      return

    mv.dst = src
    while true:
      mv.dst = mv.dst + dir
      case classifyMove(board, mv.dst):
      of blocked:
        break
      of capture:
        list.add(mv)
        break
      of empty:
        list.add(mv)
        if not moveDir.slide:
          break

func pieceMoves(list: var MoveList, board: Board) =
  for i in squares():
    let pc = board[i]
    # Check we have a white piece
    if (cast[uint8](pc) and 0b11000u8) == 0b10000:
      pieceMovesSq(list, board, i)

func isAttacked(board: Board, target: Square): bool =
  const
    bp = piece(black, pawn).onSquare
    bn = piece(black, knight).onSquare
    bb = piece(black, bishop).onSquare
    br = piece(black, rook).onSquare
    bq = piece(black, queen).onSquare
    bk = piece(black, king).onSquare

  for i in 0..<4:
    let dir = diagDirs[i]
    var curr = target
    while true:
      curr = curr + dir
      if not curr.inBounds:
        break

      let pc = board[curr]
      if pc == bb or pc == bq:
        return true

      if pc != emptySquare:
        break

  for i in 0..<4:
    let dir = orthDirs[i]
    var curr = target
    while true:
      curr = curr + dir
      if not curr.inBounds:
        break

      let pc = board[curr]
      if pc == br or pc == bq:
        return true

      if pc != emptySquare:
        break

  for i in 0..<8:
    let tk = target + allDirs[i]
    let tn = target + knightDirs[i]
    if tk.inBounds and (board[tk] == bk):
      return true

    if tn.inBounds and (board[tn] == bn):
      return true

  for dir in pawnAttackDirs:
    let tp = target + dir
    if tp.inBounds and (board[tp] == bp):
      return true

  return false

func castleMoves(list: var MoveList, board: Board) =
  if white_kingside in board.castling:
    if ((board[sq"f1"] == emptySquare) and
        (board[sq"g1"] == emptySquare) and
        (not isAttacked(board, sq"e1")) and
        (not isAttacked(board, sq"f1"))):
        const mv = Move(
          piece: piece(white, king),
          src: sq"e1",
          dst: sq"g1",
          special: castle,
        )
        list.add(mv)

  if white_queenside in board.castling:
    if ((board[sq"d1"] == emptySquare) and
        (board[sq"c1"] == emptySquare) and
        (board[sq"b1"] == emptySquare) and
        (not isAttacked(board, sq"e1")) and
        (not isAttacked(board, sq"d1"))):
        const mv = Move(
          piece: piece(white, king),
          src: sq"e1",
          dst: sq"c1",
          special: castle,
        )
        list.add(mv)

func pawnStandardMoves(list: var MoveList, board: Board) =
  var mv = static(Move(piece:piece(white, pawn), special:normal))
  for rank in 1..5:
    for file in 0..7:
      mv.src = square(file, rank)
      if board[mv.src] == piece(white, pawn).onSquare:
        for dir in pawnAttackDirs:
          mv.dst = mv.src + dir
          if not mv.dst.inBounds:
            continue

          let target = board[mv.dst]
          if (cast[uint8](target) and 0b11000u8) == 0b11000u8:
            # Occupied by black
            list.add(mv)

        # Move forward 1
        mv.dst = mv.src + distance(0, 1)
        if board[mv.dst] == emptySquare:
          list.add(mv)
          if rank == 1:
            # Double move
            mv.dst = mv.src + distance(0, 2)
            if board[mv.dst] == emptySquare:
              mv.special = doublePawn
              list.add(mv)
              mv.special = normal

func pawnPromoteMoves(list: var MoveList, board: Board) =
  const rank = 6
  var mv = static(Move(piece:piece(white, pawn)))

  func promote(list: var MoveList) =
    mv.special = promoteKnight
    list.add(mv)
    mv.special = promoteBishop
    list.add(mv)
    mv.special = promoteRook
    list.add(mv)
    mv.special = promoteQueen
    list.add(mv)

  for file in 0..7:
    mv.src = square(file, rank)
    if board[mv.src] == piece(white, pawn).onSquare:
      for dir in pawnAttackDirs:
        mv.dst = mv.src + dir
        if not mv.dst.inBounds:
          continue

        let target = board[mv.dst]
        if (cast[uint8](target) and 0b11000u8) == 0b11000u8:
          # Occupied by black
          promote(list)

      # Move forward 1
      mv.dst = mv.src + distance(0, 1)
      if board[mv.dst] == emptySquare:
        promote(list)

func enPassentMoves(list: var MoveList, board: Board) =
  let target = board.pawnmove
  if target.coords().rank == 4:
    var mv = static(Move(piece:piece(white, pawn), special:enPassent))

    assert board[target] == piece(black, pawn).onSquare
    mv.dst = target + distance(0, 1)

    mv.src = target + distance(-1, 0)
    if mv.src.inBounds and (board[mv.src] == piece(white, pawn).onSquare):
      list.add(mv)

    mv.src = target + distance( 1, 0)
    if mv.src.inBounds and (board[mv.src] == piece(white, pawn).onSquare):
      list.add(mv)

func pseudoMoves*(board: Board): MoveList =
  assert board.player == white
  result = newSeqOfCap[Move](64)
  pieceMoves(result, board)
  pawnStandardMoves(result, board)
  pawnPromoteMoves(result, board)
  enPassentMoves(result, board)
  castleMoves(result, board)

func inCheck*(board: Board): bool = isAttacked(board, board.whitekingpos)

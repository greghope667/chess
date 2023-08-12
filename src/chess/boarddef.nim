import strutils

type
  Color* = enum
    white=0, black=1

  PieceType* = enum
    none=0, king=1, queen=2, rook=3, bishop=4, knight=5, pawn=6

  Piece* = object
    tp* {.bitsize:3.}: PieceType
    color* {.bitsize:1.}: Color

  SquareContents* = object
    tp* {.bitsize:3.}: PieceType
    color* {.bitsize:1.}: Color
    occupied* {.bitsize:1.}: bool

func piece*(color: Color, tp: PieceType): auto = Piece(color:color, tp:tp)
func piece*(sq: SquareContents): auto = Piece(color:sq.color, tp:sq.tp)
func onSquare*(p: Piece): auto =
  SquareContents(color:p.color, tp:p.tp, occupied:true)

func flip*(sq: SquareContents): SquareContents =
  var bits = cast[uint8](sq)
  bits = bits xor ((bits and 0x10) shr 1)
  cast[SquareContents](bits)
func flip*(c: Color): Color =
  cast[Color](cast[uint8](c) xor 1)

const emptySquare* = SquareContents()

#[
  Board layout

  Currently using '0x88' representation (https://www.chessprogramming.org/0x88)
  square = 0b0rrr0ccc (r = row/rank, c=col/file)
]#

type
  CastlingTypes* = enum
    white_queenside, white_kingside, black_queenside, black_kingside
  CastlingRights* = set[CastlingTypes]

  Board* = object
    rank1: uint64
    halfmoves*: int32
    fullmoves*: int32

    rank2: uint64
    castling*: CastlingRights
    pawnmove*: Square
    player*: Color
    whitekingpos*:Square
    blackkingpos*:Square

    rank3: uint64
    pad3: uint8

    rank4: uint64
    pad4: uint8

    rank5: uint64
    pad5: uint8

    rank6: uint64
    pad6: uint8

    rank7: uint64
    pad7: uint8

    rank8: uint64
    pad8: uint8

  BitBoard* = set[0 .. 63]
  Square* = distinct uint8
  Distance* = distinct uint8

func square*(file, rank: Natural): Square = Square((rank shl 4) or file)
func coords*(square: Square): tuple[file, rank: Natural] =
  let s = uint8(square) and 0x77u8
  result.file = Natural(s and 0x7)
  result.rank = Natural(s shr 4)
func distance*(file, rank: int): Distance =
  let f8 = cast[uint8](file)
  let r8 = cast[uint8](rank)
  Distance(((r8) shl 4) + (f8))
func `+`*(s: Square, d: Distance): Square = Square(uint8(s) + uint8(d))
func `-`*(s: Square, d: Distance): Square = Square(uint8(s) - uint8(d))
func inBounds*(square: Square): bool = (uint8(square) and 0x88u8) == 0

func flip*(sq: Square): Square = Square(uint8(sq) xor 0x70u8)
func `==`*(l: Square, r:Square): bool =
  assert inBounds(l) and inBounds(r)
  uint8(l) == uint8(r)
func `==`*(l, r: Distance): bool = uint8(l) == uint8(r)


template sq*(squareName: static[string]): Square =
  const file = int(toLowerAscii(squareName[0])) - int('a')
  const rank = int(squareName[1]) - int('1')
  const s = square(file, rank)
  s

template sq*(squareName: string): Square =
  assert len(squareName) == 2
  let file = int(toLowerAscii(squareName[0])) - int('a')
  let rank = int(squareName[1]) - int('1')
  square(file, rank)


#[
  Convert between 'Square' notation and index [0..63]
  square = 0b0rrr0ccc
  index  = 0b00rrrccc
]#
func toIdx*(square: Square): uint8 {.inline.} =
  assert inBounds(square)
  let s = uint8(square)
  (s + (s and 7)) shr 1
func fromIdx*(idx: uint8): Square {.inline.} =
  assert idx < 64
  Square(idx + (idx and 0xf8))


iterator squares*(): Square =
  for i in 0u8..63:
    yield fromIdx(i)

static:
  for i in 0u8..63:
    assert i == i.fromIdx().toIdx()

  for s in squares():
    assert uint8(s) == uint8(s.toIdx().fromIdx())

func `[]`*(board: Board, s: Square): SquareContents =
  let cells = cast[ptr array[128, SquareContents]](unsafeAddr board)
  cells[][uint8(s)]

func `[]=`*(board: var Board, s:Square, piece: Piece) =
  let cells = cast[ptr array[128, SquareContents]](unsafeAddr board)
  cells[][uint8(s)] = piece.onSquare

func `[]=`*(board: var Board, s:Square, contents: SquareContents) =
  let cells = cast[ptr array[128, SquareContents]](unsafeAddr board)
  cells[][uint8(s)] = contents

func flip(rank: uint64): uint64 =
  let occupancy = rank and 0x1010101010101010u64
  rank xor (occupancy shr 1)

func flip(cr: CastlingRights): CastlingRights =
  let bits = cast[uint8](cr)
  let swapped = ((bits and 0b0011) shl 2) or ((bits and 0b1100) shr 2)
  cast[CastlingRights](swapped)

func flip*(board: var Board) =
  func flipswap[T](a, b: var T) =
    let tmpa = a
    let tmpb = b
    a = flip(tmpb)
    b = flip(tmpa)

  flipswap(board.rank1, board.rank8)
  flipswap(board.rank2, board.rank7)
  flipswap(board.rank3, board.rank6)
  flipswap(board.rank4, board.rank5)

  board.castling = flip(board.castling)
  board.player = flip(board.player)
  board.pawnmove = flip(board.pawnmove)

  flipswap(board.whitekingpos, board.blackkingpos)





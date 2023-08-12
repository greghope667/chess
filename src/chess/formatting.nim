import ./[boarddef, movedef]
import std/strutils

# Pieces
func uci*(piece: Piece): char =
  case piece.tp:
  of pawn: 'p'
  of knight: 'n'
  of bishop: 'b'
  of rook: 'r'
  of queen: 'q'
  of king: 'k'
  of none: ' '

func ascii*(piece: Piece): char =
  let c = uci(piece)
  if piece.color == white:
    toUpperAscii(c)
  else:
    c

func add*(s: var string, piece: Piece) = add(s, uci(piece))
func `$`*(piece: Piece): string = $ uci(piece)

# Board
func ascii*(board: Board): string =
  for rank in countdown(7,0):
    for file in countup(0,7):
      let s = square(file, rank)
      result.add(ascii(board[s].piece))
      result.add(' ')
    result.add('\n')

func uci*(square: Square): string =
  let (file, rank) = coords(square)
  result.add(char(file + int('a')))
  result.add(char(rank + int('1')))

func add*(s: var string, square: Square) = add(s, uci(square))
func `$`*(x: Square): string = uci(x)

# Moves
func uci*(x: Move): string =
  result.add(x.src)
  result.add(x.dst)
  if x.special in {promoteKnight, promoteBishop, promoteRook, promoteQueen}:
    result.add case x.special:
      of promoteKnight: 'n'
      of promoteBishop: 'b'
      of promoteRook: 'r'
      of promoteQueen: 'q'
      else: raiseAssert("Logic error")

func add*(s: var string, move: Move) = add(s, uci(move))
func `$`*(x: Move): string = uci(x)

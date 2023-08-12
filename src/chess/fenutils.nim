import boarddef
import std/strformat
import std/strutils

#[ FEN handling
  e.g.
  8/5k2/3p4/1p1Pp2p/pP2Pp1P/P4P1K/8/8 b - - 99 50
  fields:
    1 - Pieces, a8 .. h1
    2 - Player
    3 - Castling rights
    4 - En-Passent square
    5 - Halfmoves since pawn move
    6 - Fullmoves
]#

type FenError* = object of ValueError
template fenError(s: string) =
  raise newException(FenError, "FEN decoding error: " & s)

func pieceFromFen(fen: char): Piece =
  case fen:
  of 'k':piece(black, king)
  of 'q':piece(black, queen)
  of 'r':piece(black, rook)
  of 'b':piece(black, bishop)
  of 'n':piece(black, knight)
  of 'p':piece(black, pawn)

  of 'K':piece(white, king)
  of 'Q':piece(white, queen)
  of 'R':piece(white, rook)
  of 'B':piece(white, bishop)
  of 'N':piece(white, knight)
  of 'P':piece(white, pawn)
  else: fenError(fmt"invalid piece `{fen}`")

func placementFromFen(board: var Board, placement: string) =
  var rank = 8

  for line in placement.split('/'):

    var file = 0
    rank -= 1

    for c in line:
      if (isDigit(c)):
        file += int(c) - int('0')
        if file > 8:
          fenError(fmt"row `{line}` too long (cols={file})")
      else:
        let pc = pieceFromFen(c)
        let sq = square(file, rank)
        board[sq] = pc
        if pc.tp == king:
          case pc.color:
          of white:
            board.whitekingpos = sq
          of black:
            board.blackkingpos = sq
        file += 1

    if file != 8:
      fenError(fmt"row `{line}` wrong length (cols={file})")

  if rank != 0:
    fenError(fmt"fen `{placement}` wrong length (rows={8-rank})")


func playerFromFen(player: string): Color =
  if player == "b":
    black
  elif player == "w":
    white
  else:
    fenError(fmt"invalid player `{player}`")


func enpassentSquareFromFen(target: string): Square =
  if target == "-":
    sq"a1"
  elif len(target) != 2:
    fenError(fmt"invalid square `{target}`")
  else:
    let s = sq(target)
    if not inBounds(s):
      fenError(fmt"invalid square `{target}`")
    let (file, rank) = coords(s)
    if rank == 5:
      square(file, 4)
    elif rank == 2:
      square(file, 3)
    else:
      fenError(fmt"bad en-passent rank: `{target}`")


func castlingRightsFromFen(castlingRights: string): CastlingRights =
  for c in castlingRights:
    case c:
    of 'k': result.incl(black_kingside)
    of 'q': result.incl(black_queenside)
    of 'K': result.incl(white_kingside)
    of 'Q': result.incl(white_queenside)
    of '-': discard
    else:
      fenError(fmt"bad castling-rights: `{castlingRights}`")

func validateFromFen(board: Board) =
  # Some validation, but only a bit (I'm lazy)
  if board.pawnmove != sq"a1" and board[board.pawnmove] != piece(flip(board.player), pawn).onSquare:
    fenError(fmt"en-passent target square does not contain pawn")

  if board[board.whitekingpos] != piece(white, king).onSquare:
    fenError(fmt"missing white king")

  if board[board.blackkingpos] != piece(black, king).onSquare:
    fenError(fmt"missing black king")


func fromFen*(fen: string): Board =
  let components = splitWhitespace(fen,6)
  if len(components) > 0:
    result.placementFromFen(components[0])
  if len(components) > 1:
    result.player = playerFromFen(components[1])
  if len(components) > 2:
    result.castling = castlingRightsFromFen(components[2])
  if len(components) > 3:
    result.pawnmove = enpassentSquareFromFen(components[3])

  validateFromFen(result)


const startposFen* = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

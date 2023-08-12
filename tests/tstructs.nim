import chess

#[
  For high performance, we want very specific binary
  representations of objects/structures.
]#

assert (sizeof(Piece) == 1)
assert (sizeof(SquareContents) == 1)

const sq = onSquare(piece(white, rook))

assert (cast[uint8](sq) == 0b10011)
assert (cast[uint8](flip(sq)) == 0b11011)


assert (sizeof(Board) == 128)

let cr = CastlingRights { white_kingside, black_queenside }
assert (cast[uint8](cr) == 0b0110)

assert (sizeof(Move) == 4)

let mv = Move(
  piece:piece(black, bishop),
  src:sq"a3", dst:sq"d6"
)
let mvflipped = Move(
  piece:piece(white, bishop),
  src:sq"a6", dst:sq"d3"
)
assert (flip(mv) == mvflipped)

let target = piece(black, none).onSquare
assert (cast[uint8](target) == 0b11000)

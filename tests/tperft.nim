import chess
import chess/perftutils

proc testPerfResult(fen: string, depth, score: int) =
  var chessboard = fromFen(fen)
  let calcScore = perft(chessboard, depth)

  if calcScore != score:
    echo fen, " @ ", depth, ": ", calcScore, " != ", score
    assert calcScore == score


testPerfResult(startposFen, 0, 1)
testPerfResult(startposFen, 1, 20)
testPerfResult(startposFen, 2, 400)
testPerfResult(startposFen, 3, 8902)
testPerfResult(startposFen, 4, 197281)
testPerfResult("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - ", 4, 4085603)
testPerfResult("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - ", 4, 43238)

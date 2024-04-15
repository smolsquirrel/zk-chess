pragma circom 2.0.0;
include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/pedersen.circom";
include "circomlib/circuits/bitify.circom";
include "utils.circom";

/* 
0 = Empty
1 = Pawn
2 = Knight
3 = Bishop
4 = Rook
5 = King
6 = Queen
7 = Unknown
*/

template Color() {
    signal input in;
    signal output out;

    component nb = Num2Bits(4);
    nb.in <== in;

    out <== nb.out[0];
}

template Piece() {
    signal input in;
    signal output out;
    component n2b = Num2Bits(4);
    n2b.in <== in;
    component b2n = Bits2Num(3);
    for (var i=0;i<3;i++) {
      b2n.in[i] <== n2b.out[i+1];
    }
    out <== b2n.out;
}

template CoordToIndex() {
    signal input x;
    signal input y;
    signal output out;

    signal inter;
    // 8 * (8 - y) + x
    inter <== 63 + x;
    out <== inter - 8*y;
}
// outputs unknown for a color c;
// ex: in: c=0; out: unknown of color 1;
template Unknown() {
    signal input in;
    signal output out;

    component b2n = Bits2Num(4);
    b2n.in[0] <== 1-in;
    b2n.in[1] <== 1;
    b2n.in[2] <== 1;
    b2n.in[3] <== 1;
    out <== b2n.out;
}

template MoveRook() {
    signal input board[64];
    // signal input commBoard;
    signal input c;
    signal input sx;
    signal input sy;
    signal input tx;
    signal input ty;
    signal input capture;
    signal input newBoard[64];
    // signal input commNewBoard;

    assert(sx >= 1 && sx <= 8);
    assert(tx >= 1 && tx <= 8);
    assert(sy >= 1 && sy <= 8);
    assert(ty >= 1 && ty <= 8);
    assert(c == 0 | c == 1); 
    assert(capture == 0 | capture == 1); 

    // check starting board commit
    // *****

    // ******************************
    // check starting piece rook
    // ******************************
    // get index
    component cti1 = CoordToIndex();
    cti1.x <== sx;
    cti1.y <== sy;

    // get piece
    component ar1 = ArrayRead(64);
    for (var i=0; i<64; i++) {
        ar1.in[i] <== board[i];
    }
    ar1.index <== cti1.out;

    // check is rook
    component p1 = Piece();
    p1.in <== ar1.out;
    p1.out === 5;

    // check color
    component c1 = Color();
    c1.in <== ar1.out;
    c1.out === c;

    // ******************************
    // check target square empty or opponent piece
    // ******************************
    component cti2 = CoordToIndex();
    cti2.x <== tx;
    cti2.y <== ty;

    // get piece
    component ar2 = ArrayRead(64);
    for (var i=0; i<64; i++) {
        ar2.in[i] <== board[i];
    }
    ar2.index <== cti2.out;

    // check color
    component c2 = Color();
    c2.in <== ar2.out;

    // check target square has different color from the piece being moved
    component eq = IsEqual();
    eq.in[0] <== c;
    eq.in[1] <== c2.out;
    eq.out === 0;

    // check is opponent piece or empty (not unknown)
    component p2 = Piece();
    p2.in <== ar2.out;

    component is_unknown = IsEqual();
    is_unknown.in[0] <== 7;
    is_unknown.in[1] <== p2.out;
    is_unknown.out === 0;

    // check valid capture flag
    component is_empty = IsEqual();
    is_empty.in[0] <== p2.out;
    is_empty.in[1] <== 0;
    
    component is_capture = IsEqual();
    is_capture.in[0] <== is_empty.out;
    is_capture.in[1] <== (1-capture);
    is_capture.out === 1;

    // ******************************
    // check direction is valid
    // ******************************
    // did x coord change
    component lr_v = IsEqual();
    lr_v.in[0] <== sx;
    lr_v.in[1] <== tx;

    // did y coord change
    component ud_v = IsEqual();
    ud_v.in[0] <== sy;
    ud_v.in[1] <== ty;

    // for rook, only one of x or y can change
    lr_v.out + ud_v.out === 1;

    // ******************************
    // get direction; down 0, up 1, left 0, right 1
    // get distance
    // ******************************
    component left_right = nLessThan(3);
    left_right.in[0] <== sx;
    left_right.in[1] <== tx;

    // horizontal distance
    signal hd;
    signal h1a;
    signal h1b;
    signal h2a;
    signal h2b;
    // lr*(tx-sx) + (1-lr)*(sx-tx)
    h1a <== tx-sx;
    h1b <== left_right.out * h1a;
    h2a <== sx-tx;
    h2b <== (1-left_right.out) * h2a;
    hd <== h1b + h2b;

    component up_down = nLessThan(3);
    up_down.in[0] <== sy;
    up_down.in[1] <== ty;

    // vertical distance
    signal vd;
    signal v1a;
    signal v1b;
    signal v2a;
    signal v2b;
    // ud*(ty-sy) + (1-ud)*(sy-ty)
    v1a <== ty-sy;
    v1b <== up_down.out * v1a;
    v2a <== sy-ty;
    v2b <== (1-up_down.out) * v2a;
    vd <== v1b + v2b;

    // actual distance
    signal d;
    signal d1;
    signal d2;
    d1 <== (1-lr_v.out) * hd;
    d2 <== (1-ud_v.out) * vd;
    d <== d1 + d2;

    // check no obstruction
    component obstruction[6];
    for (var i=0;i<6;i++) {
        obstruction[i] = IsObstruction();
        obstruction[i].board <== board;
        obstruction[i].sx <== sx;
        obstruction[i].sy <== sy;
        obstruction[i].i <== i+1;
        obstruction[i].d <== d;
        obstruction[i].lr <== left_right.out;
        obstruction[i].lr_v <== lr_v.out;
        obstruction[i].ud <== up_down.out;
        obstruction[i].ud_v <== ud_v.out; 
    }

    // ******************************
    // check new board 
    // ******************************
    // check new start square is unknown
    component newStart = ArrayRead(64);
    for (var i=0; i<64; i++) {
        newStart.in[i] <== newBoard[i];
    }
    newStart.index <== cti1.out;

    component new_start_unknown = IsEqual();
    new_start_unknown.in[0] <== Unknown()(c);
    new_start_unknown.in[1] <== newStart.out;
    new_start_unknown.out === 1;

    // check new start square is moved piece
    component newTarget = ArrayRead(64);
    for (var i=0; i<64; i++) {
        newTarget.in[i] <== newBoard[i];
    }
    newTarget.index <== cti2.out;

    component new_target_piece = IsEqual();
    new_target_piece.in[0] <== ar1.out;
    new_target_piece.in[1] <== newTarget.out;
    new_target_piece.out === 1;

    // check new and old boards agree
    component consistent[64];
    for (var i=0;i<64;i++) {
        consistent[i] = IsConsistent();
        consistent[i].index <== i;
        consistent[i].start_index <== cti1.out;
        consistent[i].target_index <== cti2.out;
        consistent[i].old_square <== board[i];
        consistent[i].new_square <== newBoard[i];
    }

    // check new board commit
}

template IsObstruction() {
  signal input board[64];
  signal input sx;
  signal input sy;
  signal input i;
  signal input d;
  signal input lr;
  signal input lr_v;
  signal input ud;
  signal input ud_v;

  component lt = nLessThan(3);
  lt.in[0] <== i;
  lt.in[1] <== d;

  signal x, x0, x1, x2, x3, x4;
  signal y, y0, y1, y2, y3, y4;

  // (lr_v*sx) + (lr*(sx+i) + (1-lr)*(sx-i))
  x0 <== lr * (sx+i);
  x1 <== (1-lr) * (sx-i);
  x2 <== x0 + x1;
  x3 <== lr_v*sx;
  x4 <== (1-lr_v)*x2;
  x <== x3+x4; 

  // (ud_v*sx) + (ud*(sy+i) + (1-ud)*(sy-i))
  y0 <== ud * (sy+i);
  y1 <== (1-ud) * (sy-i);
  y2 <== y0 + y1;
  y3 <== ud_v*sy;
  y4 <== (1-ud_v)*y2;
  y <== y3+y4; 

  component cti = CoordToIndex();
  cti.x <== x;
  cti.y <== y;

  signal piece;
  piece <== ArrayRead(64)(board, cti.out);

  component eq = IsEqual();
  eq.in[0] <== Piece()(piece);
  eq.in[1] <== 0;
  (1-eq.out) * (lt.out) === 0;
}

// check if a square is consistent from old board to new board
template IsConsistent() {
    signal input index;
    signal input start_index;
    signal input target_index;
    signal input old_square;
    signal input new_square;

    // ignore; is start square
    component isStart = IsEqual();
    isStart.in[0] <== start_index;
    isStart.in[1] <== index;

    // ignore; is target square
    component isTarget = IsEqual();
    isTarget.in[0] <== target_index;
    isTarget.in[1] <== index;

    // is same square
    component isSame = IsEqual();
    isSame.in[0] <== old_square;
    isSame.in[1] <== new_square;

    signal ignore;
    ignore <== isStart.out + isTarget.out;

    (1-isSame.out) * (1-ignore) === 0;
}

// component main {public [board, commBoard, c, commNewBoard]} = MoveRook();
component main {public [c, capture]} = MoveRook();


extends Node2D

var g = Global

enum {
	EMPTY = 0, BLACK, WHITE, WALL,		# セル値
	DID_PUT = 0, CAN_PUT, 				# 着手位置、着手可能箇所
	HUMAN = 0, AI,
	#	パターンタイプ
	PTYPE_LINE1 = 0,	#	1・6行目、1・6列目
	PTYPE_LINE2,
	PTYPE_LINE3,
	PTYPE_DIAG6,		#	中央対角線上
	PTYPE_DIAG5,		#	
	PTYPE_DIAG4,		#	
	PTYPE_DIAG3,		#	
	N_PTYPE,
}
const TRANSPARENT = -1
#const EMPTY = -1
#const BLACK = 1
#const WHITE = 2
const N_CELL_HORZ : int = 6
const N_CELL_VERT : int = 6
const CELL_SIZE = N_CELL_HORZ * N_CELL_VERT
const ARY_WIDTH : int = N_CELL_HORZ + 1
const ARY_HEIGHT : int = N_CELL_VERT + 2
const ARY_SIZE = ARY_WIDTH * ARY_HEIGHT + 1
const DIR_UL = -ARY_WIDTH - 1
const DIR_U = -ARY_WIDTH
const DIR_UR = -ARY_WIDTH + 1
const DIR_L = -1
const DIR_R = 1
const DIR_DL = ARY_WIDTH - 1
const DIR_D = ARY_WIDTH
const DIR_DR = ARY_WIDTH + 1
const xaxis = "abcdef"

#/*
#	Bitboard:
#
#	＼ ａ ｂ ｃ ｄ ｅ ｆ →X
#	１ 20 10 08 04 02 01	<< 40
#	２ 20 10 08 04 02 01	<< 32
#	３ 20 10 08 04 02 01	<< 24
#	４ 20 10 08 04 02 01	<< 16
#	５ 20 10 08 04 02 01	<< 8
#	６ 20 10 08 04 02 01	
#	↓Y
#*/

const BB_MASK = 0x3f3f3f3f3f3f

const C3_BIT = (0x08<<(8*3))
const C4_BIT = (0x08<<(8*2))
const D3_BIT = (0x04<<(8*3))
const D4_BIT = (0x04<<(8*2))
const E4_BIT = (0x02<<(8*2))

const BB_DIR_UL = 9
const BB_DIR_U = 8
const BB_DIR_UR = 7
const BB_DIR_L = 1
const BB_DIR_R = (-1)
const BB_DIR_DL = (-7)
const BB_DIR_D = (-8)
const BB_DIR_DR = (-9)
const g_pat_type = [
	PTYPE_LINE1, PTYPE_LINE2, PTYPE_LINE3, PTYPE_LINE3, PTYPE_LINE2, PTYPE_LINE1, 
	PTYPE_LINE1, PTYPE_LINE2, PTYPE_LINE3, PTYPE_LINE3, PTYPE_LINE2, PTYPE_LINE1, 
	PTYPE_DIAG3, PTYPE_DIAG4, PTYPE_DIAG5, PTYPE_DIAG6, PTYPE_DIAG5, PTYPE_DIAG4, PTYPE_DIAG3, 
	PTYPE_DIAG3, PTYPE_DIAG4, PTYPE_DIAG5, PTYPE_DIAG6, PTYPE_DIAG5, PTYPE_DIAG4, PTYPE_DIAG3, 
]

var BOARD_ORG_X
var BOARD_ORG_Y
var BOARD_ORG
var CELL_WD
var CELL_HT
var BOARD_WIDTH
var BOARD_HEIGHT

var AI_color = WHITE
var man_color = BLACK
#var black_player = AI
#var white_player = HUMAN
var next_color = BLACK
var next_pass = false		# 手番がパス
var game_over = false		# 終局状態
var AI_thinking = false
var nNode = 0				# 探索末端ノード数
var bd_array = PoolByteArray()		# 盤面配列
var bd_stable = PoolByteArray()		# 準確定石
var bd_canPutBlack = PoolByteArray()	# 着手可能
var bd_canPutWhite = PoolByteArray()	# 着手可能
var nColors = [0, 0, 0]
var empty_list = []		# 空欄リスト
var put_stack = []		# PoolByteArray()
var rng = RandomNumberGenerator.new()
var thread = null
var AI_putIX = 0	# -1 for pass, >0 for put IX
#var putIX = 0
var n_legal_move = 0	# 着手可能箇所数
var waiting = 0			# 
var putPos = 0			# 直前着手位置
var pressedPos = Vector2(0, 0)

var bb_black
var bb_white


func _ready():
	#print(g_pat2_val)
	#print("C3_BIT = ", C3_BIT, ", xyToBit(2, 2) = ", xyToBit(2, 2))
	#print("bitToX(C3_BIT) = ", bitToX(C3_BIT))
	#print("bitToY(C4_BIT) = ", bitToY(C4_BIT))
	#
	BOARD_ORG_X = $Board/TileMap.global_position.x
	BOARD_ORG_Y = $Board/TileMap.global_position.y
	BOARD_ORG = Vector2(BOARD_ORG_X, BOARD_ORG_Y)
	#print("BOARD_ORG = ", BOARD_ORG)
	CELL_WD = $Board/TileMap.cell_size.x
	CELL_HT = $Board/TileMap.cell_size.y
	BOARD_WIDTH = CELL_WD * N_CELL_HORZ
	BOARD_HEIGHT = CELL_HT * N_CELL_VERT
	#
	bd_stable.resize(ARY_SIZE)
	bd_canPutBlack.resize(ARY_SIZE)
	bd_canPutWhite.resize(ARY_SIZE)
	#
	#update_humanAIColor()	# 人間・AI 石色表示
	update_black_white_player()		# 黒番・白番プレイヤー表示
	init_bb()
	init_bd_array()
	#putBlack(4, 3)
	#putIX = xyToArrayIX(4, 3)
	#next_color = WHITE
	update_TileMap()
	update_cursor()
	update_nextTurn()
	waiting = 6
	#
	print(bb_get_pat_indexes(bb_black, bb_white))
	print("ev = ", bb_eval(bb_black, bb_white))
func update_black_white_player():
	$BlackBG/Human.set_visible(g.black_player == HUMAN)
	$BlackBG/AI.set_visible(g.black_player == AI)
	$WhiteBG/Human.set_visible(g.white_player == HUMAN)
	$WhiteBG/AI.set_visible(g.white_player == AI)
#func update_humanAIColor():
#	$HumanBG/Black.set_visible(AI_color == WHITE)
#	$HumanBG/White.set_visible(AI_color != WHITE)
#	$AIBG/Black.set_visible(AI_color != WHITE)
#	$AIBG/White.set_visible(AI_color == WHITE)
#
func xyToBit(x, y):		# 0 <= x, y < 6
	if x < 0 || x >= N_CELL_HORZ || y < 0 || y >= N_CELL_VERT:
		return 0
	return 1<<int(N_CELL_HORZ-1-x + 8*(N_CELL_VERT-1-y))
func bitToX(pos):
	if( pos != 0 ):
		while( (pos & 255) == 0 ):
			pos >>= 8;
		var mask = 1;
		#for(int x = N_HORZ; --x >= 0; mask<<=1) {
		for x in range(N_CELL_HORZ):
			if( (pos & mask) != 0 ): return N_CELL_HORZ-1-x;
			mask <<= 1
	#assert(0);
	return -1;
func bitToY(pos):
	#for(int y = N_HORZ; --y >= 0; b>>=8) {
	for y in range(N_CELL_VERT):
		if( (pos & 255) != 0 ): return N_CELL_VERT-1-y;
		pos >>= 8
	#assert(0);
	return -1;
	
func init_bb():
	bb_black = C4_BIT | D3_BIT
	bb_white = C3_BIT | D4_BIT
func bb_get_pos_color(black:int, white:int, pos):
	if (black & pos) != 0: return BLACK
	if (white & pos) != 0: return WHITE
	return EMPTY
func bb_get_color(black:int, white:int, x, y):
	#var bit = xyToBit(x, y)
	return bb_get_pos_color(black, white, xyToBit(x, y))
func bb_can_put_black_dir(black:int, white:int, pos, dir) -> bool:
	if dir > 0:
		pos <<= dir
		if( (white & pos) == 0 ): return false;		#	白でない
		while true:
			pos <<= dir
			if( (white & pos) == 0 ): break		#	白が続く間ループ
	else:
		dir = -dir;
		pos >>= dir
		if( (white & pos) == 0 ): return false;		#	白でない
		while true:
			pos >>= dir
			if( (white & pos) == 0 ): break		#	白が続く間ループ
	return (black & pos) != 0
func bb_can_put_black(black:int, white:int, pos) -> bool:
	#if bb_can_put_black_dir(black, white, pos, BB_DIR_UL): return true
	#return false
	if (black & pos) != 0 || (white & pos) != 0: return false
	return (bb_can_put_black_dir(black, white, pos, BB_DIR_UL) ||
			bb_can_put_black_dir(black, white, pos, BB_DIR_U) ||
			bb_can_put_black_dir(black, white, pos, BB_DIR_UR) ||
			bb_can_put_black_dir(black, white, pos, BB_DIR_L) ||
			bb_can_put_black_dir(black, white, pos, BB_DIR_R) ||
			bb_can_put_black_dir(black, white, pos, BB_DIR_DL) ||
			bb_can_put_black_dir(black, white, pos, BB_DIR_D) ||
			bb_can_put_black_dir(black, white, pos, BB_DIR_DR))
func count_n_legal_move_black(black:int, white:int):
	var cnt = 0
	var spc : int = ~(black | white) & BB_MASK
	while spc != 0:
		var b = -spc & spc
		if bb_can_put_black(black, white, b): cnt += 1
		spc ^= b
	return cnt
func bb_get_revbits_dir(black:int, white:int, pos, dir) -> int:
	var b = 0
	if( dir > 0 ):
		pos <<= dir
		if( (white & pos) == 0 ): return 0;		#	白でない
		while true:
			b |= pos;
			pos <<= dir
			if( (white & pos) == 0 ): break			#	白が続く間ループ
	else:
		dir = -dir;
		pos >>= dir
		if( (white & pos) == 0 ): return 0;		#	白でない
		while true:
			b |= pos;
			pos >>= dir
			if( (white & pos) == 0 ): break			#	白が続く間ループ
	if( (black & pos) != 0 ): return b;
	return 0
func bb_get_revbits(black:int, white:int, pos) -> int:
	return (bb_get_revbits_dir(black, white, pos, BB_DIR_UL) |
			bb_get_revbits_dir(black, white, pos, BB_DIR_U) |
			bb_get_revbits_dir(black, white, pos, BB_DIR_UR) |
			bb_get_revbits_dir(black, white, pos, BB_DIR_L) |
			bb_get_revbits_dir(black, white, pos, BB_DIR_R) |
			bb_get_revbits_dir(black, white, pos, BB_DIR_DL) |
			bb_get_revbits_dir(black, white, pos, BB_DIR_D) |
			bb_get_revbits_dir(black, white, pos, BB_DIR_DR))
func bb_put_black(pos):
	var rev = bb_get_revbits(bb_black, bb_white, pos)
	bb_black |= (pos | rev)
	bb_white ^= rev
func bb_put_white(pos):
	var rev = bb_get_revbits(bb_white, bb_black, pos)
	bb_white |= (pos | rev)
	bb_black ^= rev
#
func xyToArrayIX(x, y):		# 0 <= x, y < 6
	return (y+1)*ARY_WIDTH + (x+1)
func aixToX(ix : int):
	return ix % ARY_WIDTH - 1
func aixToY(ix : int):
	return ix / ARY_WIDTH - 1
func init_bd_array():		#	盤面初期化
	bd_array.resize(ARY_SIZE)
	for i in range(ARY_SIZE):
		bd_array[i] = WALL
	#print("ARY_SIZE = ", ARY_SIZE)
	#print("bd_array.size() = ", bd_array.size())
	for y in range(N_CELL_VERT):
		for x in range(N_CELL_HORZ):
			bd_array[xyToArrayIX(x, y)] = EMPTY
	bd_array[xyToArrayIX(2, 3)] = BLACK
	bd_array[xyToArrayIX(3, 2)] = BLACK
	bd_array[xyToArrayIX(2, 2)] = WHITE
	bd_array[xyToArrayIX(3, 3)] = WHITE
	next_color = BLACK
	putPos = 0
	game_over = false
func update_TileMap():
	nColors = [0, 0, 0]		# 空白、黒石、白石数
	for y in range(N_CELL_VERT):
		for x in range(N_CELL_HORZ):
			#var col = bd_array[xyToArrayIX(x, y)]
			var col = bb_get_color(bb_black, bb_white, x, y)
			$Board/TileMap.set_cell(x, y, col-1)
			nColors[col] += 1
	var hix = 1 if AI_color == WHITE else 2
	var aix = 1 if AI_color == BLACK else 2
	$BlackBG/Num.text = "%d" % nColors[hix]
	$WhiteBG/Num.text = "%d" % nColors[aix]
func update_cursor():
	#print("next_color = ", next_color)
	n_legal_move = 0
	next_pass = false
	for y in range(N_CELL_VERT):
		for x in range(N_CELL_HORZ):
			var id = TRANSPARENT
			#if xyToArrayIX(x, y) == putIX:
			#	id = DID_PUT
			#elif( next_color == BLACK && canPutBlack(x, y) ||
			#		next_color == WHITE && canPutWhite(x, y) ):
			if xyToBit(x, y) == putPos:
				id = DID_PUT
			elif( next_color == BLACK && bb_can_put_black(bb_black, bb_white, xyToBit(x, y)) ||
					next_color == WHITE && bb_can_put_black(bb_white, bb_black, xyToBit(x, y)) ):
				id = CAN_PUT
				n_legal_move += 1
			$Board/CursorTileMap.set_cell(x, y, id)
func result_diff(nwin, nloss):
	var diff = nwin - nloss
	if nwin + nloss < CELL_SIZE:
		diff += CELL_SIZE - (nwin + nloss)
	return diff
func update_nextTurn():
	if n_legal_move == 0:
		# 次の手番が着手不可能な場合
		if( next_color == WHITE && count_n_legal_move_black(bb_black, bb_white) != 0 ||		# 黒着手可能
		next_color == BLACK && count_n_legal_move_black(bb_white, bb_black) != 0 ):			# 白着手可能
			next_pass = true
			$MessLabel.text = "パスです。画面をタップしてください。"
		else:
			game_over = true
			next_color = EMPTY
			$BlackBG/Underline.set_visible(false)
			$WhiteBG/Underline.set_visible(false)
			#$MessLabel.text = "Game Over"
			if nColors[BLACK] > nColors[WHITE]:
				$MessLabel.text = "Black won %d" % result_diff(nColors[BLACK], nColors[WHITE])
			elif nColors[BLACK] < nColors[WHITE]:
				$MessLabel.text = "White won %d" % result_diff(nColors[WHITE], nColors[BLACK])
			else:
				$MessLabel.text = "draw"
	else:
		$BlackBG/Underline.set_visible(next_color != AI_color)
		$WhiteBG/Underline.set_visible(next_color == AI_color)
		# $MessLabel.text = "AI 思考中・・・" if next_color == AI_color else "人間の手番です。"
		$MessLabel.text = "黒の手番です。" if next_color == BLACK else "白の手番です。"
#
func thinkAI_random():
	if game_over:
		return
	var lst = Array()
	for y in range(N_CELL_VERT):
		for x in range(N_CELL_HORZ):
			#if( next_color == WHITE && canPutWhite(x, y) ||
			#		next_color == BLACK && canPutBlack(x, y) ):
			#	lst.push_back(xyToArrayIX(x, y))
			if( next_color == BLACK && bb_can_put_black(bb_black, bb_white, xyToBit(x, y)) ||
				next_color == WHITE && bb_can_put_black(bb_white, bb_black, xyToBit(x, y)) ):
					lst.push_back(xyToBit(x, y))
	if lst.empty():
		return 0
	rng.randomize()
	var r = rng.randi_range(0, lst.size() - 1)
	return lst[r]
#
func result(black, white):
	if g.rule == g.NORMAL:
		return popcount(black) - popcount(white)
	else:
		return -(popcount(black) - popcount(white))
func nega_alpha(black, white, alpha, beta, depth, passed) -> float:
	if !depth: return bb_eval(black, white)
	var put : bool = false
	var spc : int = ~(black | white) & BB_MASK
	if spc == 0:
		#return popcount(black) - popcount(white)
		return result(black, white)
	while spc != 0:
		var b = -spc & spc;		#	最右ビットを取り出す
		var rev = bb_get_revbits(black, white, b)
		if rev != 0:
			alpha = max(alpha, -nega_alpha(white^rev, black|rev|b, -beta, -alpha, depth-1, false))
			if alpha >= beta:  return alpha		# ベータカット
			put = true
		spc ^= b
	if put: return alpha
	if passed:		# 双方パスの場合
		#return bb_eval(black, white)		# 双方パスの場合
		#return popcount(black) - popcount(white)
		return result(black, white)
	else: return -nega_alpha(white, black, -beta, -alpha, depth, true)
func thinkAI_nega_alpha_black(black, white) -> Array:	# [打つ位置, 評価値] を返す
	var alpha = -9999
	var beta = 9999
	var bestpos = 0
	var spc : int = ~(black | white) & BB_MASK
	while spc != 0:
		var b = -spc & spc;		#	最右ビットを取り出す
		var rev = bb_get_revbits(black, white, b)
		if rev != 0:
			#var g_depth = 4
			var ev = -nega_alpha(white^rev, black|rev|b, -beta, -alpha, g.depth, false)
			if ev > alpha:
				alpha = ev
				bestpos = b
		spc ^= b
	return [bestpos, alpha]
func thinkAI_nega_alpha() -> Array:	# [打つ位置, 評価値] を返す
	if next_color == BLACK:
		return thinkAI_nega_alpha_black(bb_black, bb_white)
	else:
		return thinkAI_nega_alpha_black(bb_white, bb_black)
#
func canPutWhiteSub(ix, dir):
	ix += dir
	if bd_array[ix] != BLACK:
		return false
	while bd_array[ix] == BLACK:
		ix += dir
	return bd_array[ix] == WHITE
func canPutBlackSub(ix, dir):
	ix += dir
	if bd_array[ix] != WHITE:
		return false
	while bd_array[ix] == WHITE:
		ix += dir
	return bd_array[ix] == BLACK
func canPutWhite(x, y):
	return canPutWhiteIX(xyToArrayIX(x, y))
func canPutWhiteIX(ix):
	if (bd_array[ix] != EMPTY):
		return false;
	return (canPutWhiteSub(ix, -ARY_WIDTH-1) ||
			canPutWhiteSub(ix, -ARY_WIDTH) ||
			canPutWhiteSub(ix, -ARY_WIDTH+1) ||
			canPutWhiteSub(ix, -1) ||
			canPutWhiteSub(ix, +1) ||
			canPutWhiteSub(ix, ARY_WIDTH-1) ||
			canPutWhiteSub(ix, ARY_WIDTH) ||
			canPutWhiteSub(ix, ARY_WIDTH+1))
func canPutBlack(x, y):
	return canPutBlackIX(xyToArrayIX(x, y))
func canPutBlackIX(ix):
	if (bd_array[ix] != EMPTY):
		return false;
	return (canPutBlackSub(ix, -ARY_WIDTH-1) ||
			canPutBlackSub(ix, -ARY_WIDTH) ||
			canPutBlackSub(ix, -ARY_WIDTH+1) ||
			canPutBlackSub(ix, -1) ||
			canPutBlackSub(ix, +1) ||
			canPutBlackSub(ix, ARY_WIDTH-1) ||
			canPutBlackSub(ix, ARY_WIDTH) ||
			canPutBlackSub(ix, ARY_WIDTH+1))
func canPutBlackSomewhere():
	for y in range(N_CELL_VERT):
		for x in range(N_CELL_HORZ):
			if canPutBlack(x, y):
				return true;
	return false;
func canPutWhiteSomewhere():
	for y in range(N_CELL_VERT):
		for x in range(N_CELL_HORZ):
			if canPutWhite(x, y):
				return true;
	return false;
#
func putWhiteSub(ix, dir):
	ix += dir
	if bd_array[ix] != BLACK:
		return 0
	var n = 0
	while bd_array[ix] == BLACK:
		n += 1
		ix += dir
	if bd_array[ix] != WHITE:
		return 0
	for i in range(n):
		ix -= dir
		bd_array[ix] = WHITE
		put_stack.push_back(ix)
	return n
func putBlackSub(ix, dir):
	ix += dir
	if bd_array[ix] != WHITE:
		return 0
	var n = 0
	while bd_array[ix] == WHITE:
		n += 1
		ix += dir
	if bd_array[ix] != BLACK:
		return 0
	for i in range(n):
		ix -= dir
		bd_array[ix] = BLACK
		put_stack.push_back(ix)
	return n
func putWhite(x, y):	# 返した石数を返す
	return putWhiteIX(xyToArrayIX(x, y))
func putWhiteIX(ix):	# 返した石数を返す
	#var ix = xyToArrayIX(x, y)
	var n = putWhiteSub(ix, -ARY_WIDTH-1)
	n += putWhiteSub(ix, -ARY_WIDTH)
	n += putWhiteSub(ix, -ARY_WIDTH+1)
	n += putWhiteSub(ix, -1)
	n += putWhiteSub(ix, 1)
	n += putWhiteSub(ix, ARY_WIDTH-1)
	n += putWhiteSub(ix, ARY_WIDTH)
	n += putWhiteSub(ix, ARY_WIDTH+1)
	if n != 0:
		bd_array[ix] = WHITE
		put_stack.push_back(n)
		put_stack.push_back(ix)
	return n
func putBlack(x, y):	# 返した石数を返す
	return putBlackIX(xyToArrayIX(x, y))
func putBlackIX(ix):	# 返した石数を返す
	#var ix = xyToArrayIX(x, y)
	var n = putBlackSub(ix, -ARY_WIDTH-1)
	n += putBlackSub(ix, -ARY_WIDTH)
	n += putBlackSub(ix, -ARY_WIDTH+1)
	n += putBlackSub(ix, -1)
	n += putBlackSub(ix, 1)
	n += putBlackSub(ix, ARY_WIDTH-1)
	n += putBlackSub(ix, ARY_WIDTH)
	n += putBlackSub(ix, ARY_WIDTH+1)
	if n != 0:
		bd_array[ix] = BLACK
		put_stack.push_back(n)
		put_stack.push_back(ix)
	return n
func un_putWhite():
	var ix = put_stack.pop_back()
	bd_array[ix] = EMPTY
	var n = put_stack.pop_back()
	for i in range(n):
		var k = put_stack.pop_back()
		bd_array[k] = BLACK
func un_putBlack():
	var ix = put_stack.pop_back()
	bd_array[ix] = EMPTY
	var n = put_stack.pop_back()
	for i in range(n):
		var k = put_stack.pop_back()
		bd_array[k] = WHITE
#
func get_pat_index(ix, dir, n):		# ix 位置から dir 方向の長さ n のパターンインデックスを計算
	var v = 0
	for i in range(n):
		v = v * 3 + bd_array[ix]
		ix += dir
	return v
func get_pat_indexes():		# 盤面の直線パターンインデックスを計算し、結果を配列で返す
	var lst = []
	# 水平方向スキャン
	for y in range(N_CELL_VERT):
		lst.push_back(get_pat_index(xyToArrayIX(0, y), DIR_R, N_CELL_HORZ))
	# 垂直方向スキャン
	for x in range(N_CELL_HORZ):
		lst.push_back(get_pat_index(xyToArrayIX(x, 0), DIR_D, N_CELL_VERT))
	# ／方向スキャン
	for y in range(2, N_CELL_VERT):
		lst.push_back(get_pat_index(xyToArrayIX(0, y), DIR_UR, y+1))
	for x in range(1, N_CELL_HORZ-2):
		lst.push_back(get_pat_index(xyToArrayIX(x, N_CELL_VERT-1), DIR_UR, N_CELL_VERT-x))
	# ＼方向スキャン
	for y in range(2, N_CELL_VERT):
		lst.push_back(get_pat_index(xyToArrayIX(0, N_CELL_VERT-1-y), DIR_DR, y+1))
	for x in range(1, N_CELL_HORZ-2):
		lst.push_back(get_pat_index(xyToArrayIX(x, 0), DIR_DR, N_CELL_VERT-x))
	return lst
func bb_get_pat_index(black, white, pos, dir, n):		# pos 位置から dir 方向の長さ n のパターンインデックスを計算
	var v = 0
	for i in range(n):
		v = v * 3 + bb_get_pos_color(black, white, pos)
		if dir > 0: pos <<= dir
		else: pos >>= -dir
	return v
func bb_get_pat_indexes(black, white):		# 盤面の直線パターンインデックスを計算し、結果を配列で返す
	var lst = []
	# 水平方向スキャン
	for y in range(N_CELL_VERT):
		lst.push_back(bb_get_pat_index(black, white, xyToBit(0, y), BB_DIR_R, N_CELL_HORZ))
	# 垂直方向スキャン
	for x in range(N_CELL_HORZ):
		lst.push_back(bb_get_pat_index(black, white, xyToBit(x, 0), BB_DIR_D, N_CELL_VERT))
	# ／方向スキャン
	for y in range(2, N_CELL_VERT):
		lst.push_back(bb_get_pat_index(black, white, xyToBit(0, y), BB_DIR_UR, y+1))
	for x in range(1, N_CELL_HORZ-2):
		lst.push_back(bb_get_pat_index(black, white, xyToBit(x, N_CELL_VERT-1), BB_DIR_UR, N_CELL_VERT-x))
	# ＼方向スキャン
	for y in range(2, N_CELL_VERT):
		lst.push_back(bb_get_pat_index(black, white, xyToBit(0, N_CELL_VERT-1-y), BB_DIR_DR, y+1))
	for x in range(1, N_CELL_HORZ-2):
		lst.push_back(bb_get_pat_index(black, white, xyToBit(x, 0), BB_DIR_DR, N_CELL_VERT-x))
	return lst
#
func _process(delta):
	if waiting > 0:
		waiting -= 1
	elif( !game_over && !AI_thinking &&
	(next_color == BLACK && g.black_player == g.AI) || (next_color == WHITE && g.white_player == g.AI) ):
		AI_thinking = true
		#putIX = thinkAI_random()
		#putWhiteIX(putIX)
		#putPos = thinkAI_random()
		var pair = thinkAI_nega_alpha()
		print("eval = ", pair[1])
		putPos = pair[0]
		if putPos != 0:		# パスでない場合
			var x = bitToX(putPos)
			var y = bitToY(putPos)
			if next_color == BLACK:
				bb_put_black(xyToBit(x, y))
			else:
				bb_put_white(xyToBit(x, y))
		next_color = (BLACK + WHITE) - next_color
		update_TileMap()
		update_cursor()
		update_nextTurn()
		#print("ev = ", bb_eval(bb_black, bb_white))
		AI_thinking = false
	pass
func _input(event):
	if event is InputEventMouseButton:
		#print(event.position)
		#print($Board/TileMap.world_to_map(event.position - BOARD_ORG))
		var pos = $Board/TileMap.world_to_map(event.position - BOARD_ORG)
		print("mouse button")
		if event.is_pressed():
			print("pressed")
			pressedPos = pos
		else:
			print("released")
			if next_pass:
				next_pass = false
				next_color = (BLACK + WHITE) - next_color
				#update_cursor()
			else:
				if pos != pressedPos: return
				var bit = xyToBit(pos.x, pos.y)
				if bit == 0: return;
				if next_color == BLACK:
					#if !canPutBlack(pos.x, pos.y): return
					#putBlack(pos.x, pos.y)
					if !bb_can_put_black(bb_black, bb_white, bit): return
					bb_put_black(bit)
					next_color = WHITE
				else:	#if next_color == WHITE:
					#if !canPutWhite(pos.x, pos.y): return
					#putWhite(pos.x, pos.y)
					if !bb_can_put_black(bb_white, bb_black, bit): return
					bb_put_white(bit)
					next_color = BLACK
				#putIX = xyToArrayIX(pos.x, pos.y)
				putPos = bit
				update_TileMap()
			update_cursor()
			update_nextTurn()
			waiting = 6
	pass
#
func popcount(bits: int):
	bits = (bits & 0x555555555555) + ((bits >> 1) & 0x555555555555);    #  2bitごとに計算
	bits = (bits & 0x333333333333) + ((bits >> 2) & 0x333333333333);    #  4bitごとに計算
	bits = (bits & 0x0f0f0f0f0f0f) + ((bits >> 4) & 0x0f0f0f0f0f0f);    #  8bitごとに計算
	bits = (bits & 0x00ff00ff00ff) + ((bits >> 8) & 0x00ff00ff00ff);    #  16bitごとに計算
	bits = (bits & 0xffff0000ffff) + ((bits >> 16) & 0xffff0000ffff);    #  32bitごとに計算
	bits = (bits & 0x0000ffffffff) + ((bits >> 32) & 0x0000ffffffff);    #  64bitごとに計算
	return bits;
func bb_eval(black : int, white : int) -> float:
	if (black|white) == BB_MASK:
		#return popcount(black) - popcount(white)
		return result(black, white)
	var ev = 0.0
	var lst = bb_get_pat_indexes(black, white)
	var npb = min(8, count_n_legal_move_black(black, white))	# 黒着手可能箇所数
	var npw = min(8, count_n_legal_move_black(white, black))	# 白着手可能箇所数
	if g.rule == g.NORMAL:
		for i in range(lst.size()):
			ev += g_pat2_val[g_pat_type[i]][lst[i]]					# 直線パターン
		ev += g_npbw_val[npw][npb]
	else:
		for i in range(lst.size()):
			ev += g_pat2_val_LW[g_pat_type[i]][lst[i]]					# 直線パターン
		ev += g_npbw_val_LW[npw][npb]
	return ev
#
const g_pat2_val = [
  [
  0.174211, 1.004155, -0.434724, -0.450714, 2.097835, -2.786080, 0.312219, 1.022675, -2.472394,
  0.247282, 1.366444, -1.391407, -0.673728, 3.132664, -4.595717, 2.205845, -0.507327, -5.282271,
  0.200204, 0.979784, -1.058279, -1.079581, 4.719854, -0.943058, 0.430058, 3.925760, -3.273362,
  0.035880, 1.155495, -1.478638, -1.664119, 0.329001, -4.091293, 0.271401, 2.522321, -3.313809,
  -0.269955, -0.036650, -2.147141, 0.592874, 4.922705, -5.590819, 3.347943, -1.095140, -5.749197,
  -0.187057, 2.835954, -2.172224, -5.471924, -1.254037, 0.000000, 3.372494, -3.157926, -6.509679,
  -0.180919, 1.415482, -1.231127, -0.425115, 2.486904, -2.539516, 1.526303, 3.465686, -1.099349,
  -0.235055, 1.585908, -1.951148, -1.901465, 5.277649, 1.748530, 4.743948, 0.000000, -1.006025,
  0.077895, 1.590227, 0.287852, -1.785296, 4.550603, -0.714432, -0.894827, 3.625598, -5.719807,
  0.368844, 0.760002, -0.610057, -0.610899, 1.462657, -2.323103, -0.397319, 0.895212, -3.225108,
  -2.045342, -1.821765, -2.612898, -1.971951, 1.602274, -5.908325, 2.131400, -6.218303, -6.174680,
  -0.220292, 0.736146, -1.682537, -1.221351, 4.845768, -0.845201, 0.061923, 4.301295, -3.688509,
  -0.090566, 1.144385, -0.957571, -1.999874, 0.390591, -4.810439, -0.010547, 3.846723, -2.820558,
  0.156117, 0.321440, 0.138515, 1.407251, 6.227160, -4.194752, 3.821886, -5.188829, -5.350949,
  -1.640879, 2.049411, -3.160298, -7.727024, -4.527427, 0.000000, 2.742259, -7.925094, -6.583301,
  -0.533985, -1.457201, -2.224649, -1.474385, 3.968405, -4.763155, -1.237339, 2.723648, -3.398365,
  -4.976477, -6.441483, -5.625118, -7.231124, -2.030390, -1.548702, 0.000000, 0.000000, 0.000000,
  -2.033772, 1.826400, -3.574135, -7.395598, -5.129783, -4.672342, 3.595911, -8.059308, -7.425107,
  -0.679007, 1.460205, -0.101530, 0.334148, 1.642692, -1.756674, -0.301830, 1.366336, -2.278460,
  0.407306, 1.261712, -1.109233, -0.401506, 4.049991, -1.931982, 2.715223, 1.097256, -3.340501,
  1.260253, 1.884458, 2.249555, -1.606031, 4.848197, 4.372606, 2.213941, 4.784054, -1.807724,
  2.677102, 3.764373, 2.353864, 1.755147, 4.569382, 0.111162, 2.771636, 4.828774, 0.327801,
  3.300658, 4.779134, 2.648908, 3.594238, 7.223591, 7.493711, 7.271345, 3.802378, 3.858200,
  4.475123, 5.474979, 5.466510, 0.000000, 0.000000, 0.000000, 6.789766, 0.157194, 0.844958,
  0.545574, 1.358325, -1.346575, -0.192636, 3.068996, -1.519463, 2.449806, 3.270873, -0.277676,
  3.713093, 4.552230, 2.977350, 3.388180, 6.880582, 7.485080, 6.527809, 0.000000, 4.458679,
  -1.322967, 0.040584, 0.399625, 3.364705, 6.146172, 5.916582, -1.751687, 6.356713, -7.279572,
  0.873947, 2.258762, 0.250074, 0.884610, 2.708618, -1.750921, 0.654859, 1.957264, -1.946972,
  1.241631, 1.326880, -0.064848, 1.083460, 4.206316, -3.774471, 4.550276, -0.395463, -4.276649,
  1.015465, 1.847051, 0.929380, -2.203206, 3.871415, 0.233830, 1.056916, 3.083098, -2.958373,
  1.316914, 1.486378, -0.555416, -2.181442, 0.543607, -3.931652, 1.017655, 2.420972, -2.406624,
  0.028919, -0.021081, -1.113253, -0.039534, 4.117675, -3.335678, 4.838787, -3.541935, -4.395473,
  1.357236, 3.069184, -0.088278, -6.519910, -2.850607, 0.000000, 4.421082, -5.666830, -5.320880,
  1.043056, 1.625117, -0.127721, 0.633619, 2.656219, -1.641578, 1.112860, 2.874044, 0.032800,
  2.804982, 2.500425, 2.109554, 1.954849, 4.412929, 5.474056, 5.467252, 0.000000, 2.769106,
  1.167989, 2.410408, 0.594536, 1.848765, 4.272672, 4.466031, -0.225134, 3.989623, -5.907101,
  1.883047, 2.287761, 1.810728, 1.285681, 2.268007, -0.716891, 1.979029, 2.229004, -0.578346,
  0.361621, -0.137909, -0.410020, -0.009195, 3.590110, -1.203601, 3.786999, -1.764721, -2.532840,
  2.891865, 2.292758, 1.842735, 4.271775, 5.761854, 4.593356, 2.835894, 5.068748, -1.593109,
  3.395012, 3.820261, 2.303820, 1.357021, 3.862955, 0.604681, 4.147471, 5.243086, 1.293209,
  4.623604, 4.346673, 4.689774, 6.327649, 6.363194, 6.129128, 7.410925, 3.279932, 2.859491,
  5.015495, 4.536134, 4.916416, -2.456902, 2.134927, 0.000000, 6.054672, -0.847748, -0.622747,
  4.580543, 3.516587, 3.979068, 4.635698, 5.569865, 3.788734, 4.830363, 5.664022, 3.501362,
  -0.985924, -3.304776, -2.774328, -4.540722, 2.147820, 0.711707, 0.000000, 0.000000, 0.000000,
  4.670615, 4.055883, 4.819028, -5.106126, -1.641988, -1.311494, 6.026605, -5.189201, -3.968673,
  1.307045, 2.162537, 1.372014, 0.473851, 2.417097, -0.997236, 0.779021, 1.230177, -0.576714,
  2.537404, 2.030080, 2.375936, 3.617284, 5.140973, 2.617226, 4.743464, 0.141691, -0.254182,
  3.370608, 2.703839, 2.756347, 2.794564, 5.967738, 4.787074, 3.360411, 5.110384, -0.410452,
  -0.358828, 0.111615, -2.046533, -5.837071, -1.793374, -2.520301, 0.343021, -0.093737, -2.897638,
  -1.300864, -3.725821, -3.208077, -5.250559, 3.295048, 1.990799, 3.525326, 0.000000, -0.123698,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  3.506005, 2.910512, 3.563110, 3.891269, 5.464530, 4.254266, 4.311503, 4.989066, 3.607547,
  -3.091373, -5.122781, -5.180301, -7.703516, -1.153261, -0.615862, -0.077151, 0.000000, -2.267978,
  4.120152, 3.658838, 3.790661, -8.390688, -4.894481, -3.651198, 5.868529, -7.420706, -7.789643,
  -1.053779, 0.137963, -1.998255, -0.102508, 1.674171, -2.890476, -0.372063, 2.447978, -3.368552,
  -1.120746, -0.804140, -2.340833, -1.599705, 2.761922, -3.691155, 3.370116, -1.138243, -4.301701,
  -1.576019, 0.329968, -1.929218, -2.178973, 4.153289, -1.601302, -1.424477, 2.996051, -4.480377,
  -1.640785, -0.146880, -2.043465, -2.369732, -0.215668, -4.049365, -0.441927, 2.214312, -3.347094,
  -2.080535, -1.052771, -3.943994, 0.310965, 5.055155, -2.231963, 3.065129, -3.161105, -3.544031,
  -2.413464, 2.190994, -2.080643, -5.315986, -2.890624, 0.000000, 2.732723, -5.743946, -5.110127,
  -0.443004, 0.908987, -1.433979, -0.864001, 2.714692, -1.097575, 1.817574, 2.824510, 0.411890,
  -2.337472, 0.400599, -1.757700, -3.285079, 5.375516, 5.212262, 5.622091, 0.000000, 2.515966,
  -0.027721, 1.189591, 1.142902, -3.992269, 4.890928, 4.069311, -0.318794, 4.626909, -5.437679,
  -2.065012, -2.096375, -2.818803, -2.688835, -0.795738, -2.534839, -1.911605, -0.642230, -2.978342,
  -4.611820, -3.429551, -3.378381, -5.082664, 0.264441, -3.329802, 0.331100, -3.192039, -4.549645,
  -2.693629, -0.870176, -1.662641, -4.353918, 4.014477, 4.348068, -1.759991, 4.620761, -5.201533,
  -4.625616, -3.362675, -4.779492, -5.698589, -1.199849, -4.024864, -2.387012, 2.178053, -2.811183,
  -5.285977, -3.055575, -2.675532, -4.536254, 6.010776, 5.690895, 7.371008, 1.691788, 2.551659,
  1.234164, 5.991702, 5.298053, -0.838319, 0.725201, 0.000000, 6.804691, -0.896090, -0.497886,
  -0.931040, -0.123733, -1.721277, -1.308041, 4.527459, 4.169660, 4.093068, 4.372428, 2.556588,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -1.110296, 3.928992, 4.401147, -5.190631, -1.150357, 0.000000, 6.254236, -3.718511, -5.520037,
  -2.601046, -1.352951, -2.720989, -2.687656, -0.283380, -3.655821, -2.969907, -0.836416, -4.081197,
  -3.312454, -1.851184, -3.806723, -2.148637, 0.886633, -3.598565, 0.613165, -2.827411, -4.736752,
  -1.058113, -0.241350, -0.165623, -3.335587, 2.905844, 2.310062, -0.041818, 3.390351, -3.867304,
  -4.982837, -4.143980, -4.591833, -5.435023, -2.812028, -4.952089, -3.606021, -0.308932, -4.922591,
  -5.761308, -4.438492, -3.741422, -5.894681, 2.915149, 3.033889, 4.063496, 0.051509, -0.070018,
  -1.567413, 2.355257, 2.495704, 0.000000, 0.000000, 0.000000, 4.178664, -1.981369, -3.168368,
  -2.990264, -3.232160, -4.718518, -4.200051, -1.923169, -4.645211, -1.713614, -0.109383, -4.063800,
  -6.302905, -5.469205, -4.396873, -6.111653, -0.886443, -0.680318, 0.797336, 0.000000, -3.380672,
  -5.657598, -5.545508, -4.744263, -7.182754, -4.377032, -4.989238, -7.345121, -7.552760, -7.981350,
  ],
  [
  0.000000, 0.000000, 0.000000, -0.157664, 0.422475, -0.131838, 0.211444, 0.072119, -0.175878,
  0.153815, -0.629753, 0.533839, 1.200818, -0.292340, -0.553493, 0.615632, 0.911627, -1.283338,
  -0.227759, -0.476381, -0.156833, 0.557693, 1.247366, 0.616752, -0.493803, 1.135708, -0.586849,
  0.203840, 0.651288, 1.122081, 0.085325, -0.301418, -0.394624, 0.370421, 1.081016, -0.777257,
  0.706784, -0.197173, 0.799310, 0.438467, -0.369928, -0.003445, 1.325076, 0.460799, -0.933741,
  0.426930, 0.482744, 1.032959, -1.087477, -0.275128, -0.598741, -0.183248, -0.482133, -0.855729,
  -0.405785, -0.924055, -0.401690, -0.200638, 0.274463, -1.217280, 0.040780, 0.682240, -0.664303,
  0.805028, -0.125216, 0.192839, 0.007950, 0.596841, 0.342883, 1.061070, 0.872768, 0.079350,
  -1.419323, -0.892625, 0.753093, -0.926819, 0.160597, 0.428698, -0.520361, 0.839992, -0.553117,
  -0.058183, -0.473917, 0.079405, 0.368957, 0.614482, 0.336317, 0.002934, 0.387665, -0.927657,
  -0.245814, -1.046867, -0.184879, -0.061027, -0.672316, -0.786585, 0.502437, -0.457811, -1.670553,
  -0.240401, -0.162890, 0.746291, 1.111048, 0.868226, 0.613204, -0.423394, -0.022384, -0.723524,
  0.602333, 0.121157, 0.687920, -0.061663, -0.056147, -0.073024, 0.085795, 0.805757, -1.029740,
  1.013698, -0.754483, -0.048232, -0.020742, 0.295875, -0.089567, 0.978332, 0.090121, -1.135533,
  0.140425, 0.088486, 0.414504, -0.541682, -0.581548, -0.838128, -0.290122, -0.715784, -1.073277,
  0.050607, -0.524838, 0.102428, 0.466941, -0.000762, -0.570359, 0.092451, 0.121005, -0.687680,
  -0.974179, -1.445900, -0.826425, -1.136603, -0.086295, -1.232393, -0.711729, -0.490588, -0.862320,
  -0.237462, -0.840098, -0.619670, -2.494047, -0.648555, -0.933824, -0.934644, -0.776005, -1.565665,
  -0.176476, -0.250758, 0.313051, -0.177254, 0.275488, 0.000660, -0.363934, 0.367672, -0.374622,
  0.194037, -1.533099, 0.213691, -0.148362, 0.274408, 0.394311, 0.297914, -0.126839, -1.278025,
  -0.442422, -0.234164, 0.592480, -0.082391, 1.017298, 1.206468, -0.003459, 0.575345, 0.300656,
  1.108390, 0.102256, 0.995554, 0.476583, 0.049089, -0.460006, -0.037599, 0.685615, 0.016931,
  1.260267, -0.046955, 0.713952, -0.292764, 0.856142, 1.217168, 1.438870, 1.022479, 0.380114,
  0.763851, 0.676531, 0.940594, -0.135999, 0.185159, 0.428156, 0.447805, 0.114525, 0.244264,
  -0.740258, -0.785950, 0.222199, -0.328479, 0.235635, -0.045802, -0.486754, 0.113312, -0.067168,
  -0.380049, -0.623301, -0.727715, -0.347876, -0.064440, 0.263009, 0.885207, 0.821826, 0.603883,
  -0.729725, -0.254867, 0.671207, -0.522984, -0.078612, 0.663941, -0.591940, 1.027855, 0.299880,
  0.000000, 0.000000, 0.029241, -0.022527, -0.350191, -0.207289, -0.323654, -0.067091, -1.338070,
  -0.103753, -0.302347, 0.476901, -0.599709, -0.375005, -0.648966, -0.175414, -0.697336, -1.872594,
  -1.087753, -1.342623, -0.529549, -0.654380, 0.804104, -0.091920, -0.992851, 0.698907, 0.128755,
  -0.317206, -0.976502, 0.270468, -1.270805, -0.989723, -1.091773, -0.391753, -0.107218, -0.928467,
  -0.383652, -1.328002, 0.028597, -1.207729, -1.004251, -1.486792, -0.272277, -1.004362, -0.993533,
  -0.481147, -0.142557, 0.349881, -1.586351, -0.901781, -0.587216, -1.016522, -1.042596, -1.241677,
  -1.105700, -1.303670, -0.553243, -0.913627, 0.236553, -0.347495, -0.523633, 0.506867, -0.274987,
  0.436531, -0.489975, -0.067476, 0.518069, 0.916514, 0.711146, 0.869718, 1.378241, 0.155174,
  -0.327466, -0.643518, -0.469814, -0.836800, -0.111302, 0.763673, -0.764629, 1.261152, -1.041511,
  -0.152983, -0.232258, 0.538760, 0.686864, 0.938769, 0.235709, 0.498677, 0.616603, -0.462854,
  0.308396, -0.552189, -0.058426, -0.066773, 0.446804, -0.705892, 0.668841, -0.635720, -1.315539,
  0.694209, 0.031919, 1.107200, -0.078665, 0.601632, 1.013519, 0.054133, 0.334269, 0.130288,
  0.355427, -0.547572, 0.148701, -0.051889, -0.412831, -0.090253, 0.099286, 0.504384, -0.983655,
  -0.058778, -0.452369, 0.395387, -0.105519, -1.061576, -0.071780, 0.504788, -0.054350, -0.370756,
  0.658321, 0.586976, 0.673176, -0.036074, -0.005294, 0.900847, -0.158115, -0.015221, -0.126123,
  0.906449, 0.721512, 1.887686, 1.424952, 0.901292, 0.669671, 1.188575, 0.157093, 0.506767,
  0.348455, -0.888423, -0.360895, -0.507093, -0.265105, 0.249941, 0.230968, 0.101647, 0.456338,
  1.029352, -0.108162, 0.469762, -0.893773, -0.499307, 0.332883, -0.258759, -0.552571, -0.435043,
  0.455627, -0.254645, 0.510028, 0.446836, 0.856478, 0.407946, -0.029943, 0.420347, 0.360278,
  1.431621, -0.188071, 0.951918, 0.521067, 0.652243, 0.429030, 0.849657, 0.380928, 0.014264,
  0.494844, 0.227464, 1.488608, -0.104357, 0.778153, 0.632071, 0.801088, 0.135565, 0.306492,
  0.777531, 0.246229, 0.785685, -0.186481, -0.084067, 0.019359, -0.184018, -0.042093, -0.482346,
  0.065841, -0.954345, 0.069084, -0.134166, 0.396178, 0.584197, 1.444891, 0.751212, 0.622088,
  1.282569, 0.362624, 1.252124, -0.489274, 0.268311, 0.906548, 0.498391, 0.413935, 0.170234,
  1.392448, -0.003117, 1.189314, 0.686087, 0.156707, -0.121196, 0.338251, 0.597637, 0.755364,
  -0.114948, -0.710344, -0.506574, -0.909850, -0.496970, -0.082214, 0.504323, 0.365733, -0.478500,
  1.530515, 0.367961, 0.760262, -1.451605, -0.215813, 0.061096, 0.476802, 0.323905, 0.226911,
  0.000000, -0.021840, -0.012581, 0.106972, 0.578196, 0.107483, -0.007596, 0.832620, -0.698299,
  1.219866, 0.333583, 1.112571, 0.246260, 0.301491, 0.524547, 1.007945, 0.609839, -0.612507,
  0.051446, -0.611920, 0.639014, 0.291770, 0.817546, 1.291454, -0.343545, 1.346497, 0.459838,
  1.210505, 0.348800, 1.424963, -0.172134, -0.084890, -0.291305, 0.131217, 1.138536, -0.149288,
  0.828400, 0.029292, 0.979364, 0.460758, -0.076411, 0.069788, 0.428668, -0.249575, -0.523525,
  0.344884, 0.082154, 0.535531, -1.072209, -0.114690, -0.586945, -0.307144, -0.899881, -0.453524,
  0.089910, -0.488582, 1.012437, 0.138936, 0.719731, -0.273518, 0.587647, 1.424859, -0.196238,
  -0.017429, -0.265022, 0.989218, 0.898475, 0.866257, 1.088920, 1.453289, 1.487589, 0.904564,
  0.005782, 0.060565, 0.957810, -0.497805, 0.950024, 1.080736, 0.840100, 1.553713, 0.719358,
  -0.174754, -0.175037, 0.215690, -0.318503, -0.518298, -0.340324, -0.100946, -0.530937, -0.340078,
  -0.314723, -1.233727, -0.447910, -0.649224, -0.888825, -0.354369, 0.151215, 0.054471, -0.316462,
  -0.536546, -0.223966, 0.061481, -0.136155, 0.020944, 0.812059, -0.338512, 0.004726, -0.487905,
  -0.570050, 0.230951, 0.463228, -0.488555, -0.540601, 0.176589, -0.801421, 0.250518, -0.441487,
  -0.631761, -1.114076, -0.757239, -0.763293, 0.265063, 0.463657, 0.807903, 0.539381, 0.787936,
  0.712848, 1.217445, 0.775495, -0.518492, 0.423027, 1.263875, 0.057925, 0.647641, 0.725057,
  0.243147, -0.061884, 0.818245, 0.822831, 1.169825, 0.851670, 1.045044, 0.642426, 1.027378,
  -0.777303, -0.458640, -0.402121, -0.324360, 0.498096, 0.925685, 0.579631, 0.804814, 0.940663,
  0.691818, 0.310939, 0.863715, -0.946282, -0.160639, 0.127440, 0.546414, 0.250177, -0.324669,
  -0.344251, -1.553399, -0.123922, -0.873232, -0.361142, -0.380649, -0.684548, 0.662902, -0.902147,
  -0.827077, -1.169872, -0.439319, -0.788771, 0.072276, 0.241926, -0.454840, -0.905213, -1.105176,
  -0.436923, 0.158783, 0.900557, -0.240263, 0.184011, 0.422237, 0.294093, 0.460669, -0.129599,
  -0.670398, -1.607247, -0.549770, -1.509702, -1.426716, -0.379616, -0.704186, -0.327287, -1.346894,
  -1.735343, -2.001310, -0.519923, -0.687693, -0.008453, 1.029830, 0.654913, 0.808268, 0.532565,
  -0.213102, -0.024841, -0.089166, -1.366562, -0.001219, 0.701854, 0.688250, 1.219093, 0.408747,
  -0.067015, -1.309932, 0.514446, -0.258926, 0.024300, -0.313977, 0.186860, 0.330487, 0.162478,
  -1.018633, -1.771158, -0.967666, -0.748242, -0.812293, 0.509738, -0.211934, 0.483099, 0.170980,
  -0.370257, -0.505574, 0.659356, -1.252503, -0.622854, 0.537795, -0.140349, 0.462386, 0.606045,
  ],
  [
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.069851, 0.296897, -0.318710, -0.207830, 0.790127, -0.532078, 0.088716, -0.692427, -2.046079,
  -0.170504, 0.501845, 0.195888, -1.485283, -0.264404, -0.483610, -0.105963, -1.073395, -1.442995,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.300169, -0.176884, 0.068892, 0.045180, 1.751797, 1.277242, 1.613185, 0.135164, -0.124196,
  -0.344138, -0.379111, -0.336971, -0.012296, 1.057810, 0.387503, 0.065251, 0.887459, -0.514356,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.087958, -0.423403, -0.068265, -0.430287, -0.205050, -0.299401, 0.379323, -0.504144, -1.172819,
  0.238225, 0.460194, 0.625216, -1.658648, -0.532246, -0.648890, -0.044525, -0.607062, -1.524234,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -1.551352, -2.793740, -1.424365, -1.327873, -0.318173, -0.278154, -0.222466, -0.920853, -1.158808,
  0.213118, 0.240726, 0.003560, -1.952960, -1.301049, -0.296548, -0.248191, -0.759528, -1.473568,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.491519, -0.160816, 0.415367, 0.191807, 1.403487, 1.341332, 1.666858, 1.053922, 0.983018,
  1.395129, 1.524020, 2.083073, -0.521790, 0.536595, 0.713912, 1.200521, 0.562817, 0.647945,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.430245, -0.634258, 0.660767, -0.002782, 1.131914, 1.260839, 1.416663, 0.886307, 1.002208,
  -0.119879, -0.757442, 0.656627, -0.025687, 1.183960, 1.507662, 0.422665, 0.573362, 0.203700,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.716520, 0.093980, 0.111531, -0.176866, -0.521685, -1.686491, -0.246159, -1.503829, -1.715599,
  -0.478266, 0.696692, -0.312955, -2.031721, -0.724797, -1.827422, -0.881752, -1.404961, -2.452370,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  1.044503, 0.072200, 0.454002, 0.132268, 1.916224, 1.326766, 1.613182, 0.750535, 0.552787,
  -0.137251, 0.138543, 0.257215, 0.234075, 1.230266, 0.836351, 0.144652, 0.458198, -1.018229,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.853888, -0.024856, 1.403666, 0.291132, 0.302517, 0.152544, 2.113238, 0.074619, -0.091013,
  1.482743, 1.405131, 2.550575, -0.664098, 0.058095, -0.119996, 1.516365, 0.080522, -0.124718,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.164864, -1.000285, -0.158672, -0.529673, 0.233014, -0.326253, 0.552504, -0.177192, -0.275140,
  0.801971, 1.231782, 1.859702, -0.662318, -0.097897, -0.380880, 0.983977, 0.076153, -0.002627,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.664748, -1.048825, -0.386520, -1.125021, 0.234491, 0.409329, 0.268511, -0.620043, 0.323205,
  0.281401, 0.599379, 1.622629, -1.634583, 0.623513, 0.702152, 0.124702, 0.007191, 0.165042,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.775112, -1.436747, -1.235681, -0.976700, 0.155956, 0.019963, 0.386027, 0.072100, -0.360027,
  0.583282, 0.892285, 1.455077, -1.377046, -0.079461, 0.548903, 1.017934, -0.750411, 0.404755,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.126057, -0.207121, -0.420500, 0.181462, 1.238239, -0.094700, 0.216830, -1.558697, -1.324469,
  -0.697373, 0.603405, -0.133605, -1.414183, -0.550544, -1.276991, -0.236093, -1.796899, -1.306517,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.428261, -0.085749, 0.145626, 0.617267, 2.167065, 1.482810, 2.221529, 1.260333, 1.136107,
  -0.325231, 0.078393, 0.588795, 0.186731, 1.962323, 1.677224, 0.503316, 1.801379, 0.226819,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -1.074999, -2.234206, -0.396303, -0.763778, 0.367379, -0.578583, 1.725691, 0.493027, 0.219633,
  1.330545, 1.176867, 1.850999, 0.182152, 0.335489, 0.365568, 1.234636, -0.122289, 0.953047,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.531599, -2.136596, -0.737296, -0.461795, -0.220358, -0.159035, 0.496119, 0.316332, 0.206264,
  1.050729, 0.368101, 1.293854, -0.924417, -0.551917, 0.297666, 1.660720, -0.102906, 0.144913,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -1.476152, -1.963773, -1.247951, -1.209791, -0.216471, 0.057538, 1.383268, 0.300714, 0.408795,
  0.374873, 0.740392, 1.157882, -1.249851, 0.279470, 0.009696, 0.319900, 0.159023, 0.649517,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -2.015670, -2.704762, -1.613728, -1.410831, 0.261257, 0.646574, 0.514749, 0.000705, -0.061533,
  -0.660543, -1.011892, 0.476631, -1.325577, 0.058914, 0.356300, -0.376582, -0.188389, 0.247688,
  ],
  [
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  1.170359, 1.312245, -0.887258, 2.062059, 2.607032, -3.771716, 0.867400, 0.833440, -3.395563,
  0.265714, 1.376171, -0.527945, -1.708810, 1.591592, -2.364141, 1.022816, 0.817334, -4.251198,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.084930, 0.944957, -0.935699, 0.586664, 3.535075, -1.745254, 2.154717, 1.749294, -1.504980,
  -0.822755, 0.947765, -1.623918, 0.559294, 3.393061, -0.895644, -1.110105, 2.725816, -2.482468,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  1.013535, 1.458532, -0.307514, 0.830574, 2.194649, -3.448124, 0.307749, -0.597915, -3.600632,
  -0.027991, 0.820964, -0.760999, -2.227147, -0.238831, -2.573942, 0.624947, -1.076805, -3.631234,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -2.002460, -2.164825, -3.531526, -2.321746, 0.293002, -2.597555, -0.277287, -0.664832, -2.675931,
  0.128360, 1.301945, -1.062912, -2.604664, -0.408344, -2.503186, 0.272967, -0.879501, -3.337409,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  1.302408, 1.825042, 0.425281, 0.650568, 3.658166, 1.177720, 2.303586, 2.686262, 0.127136,
  1.592030, 2.624473, 2.642755, -0.256096, 2.702986, 0.693773, 1.868657, 1.417507, 0.262625,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.283542, 0.958341, 0.331958, 1.017997, 4.081471, 1.347432, 2.085645, 1.990207, 0.569115,
  -0.701289, 0.281455, -0.980132, 0.581805, 3.838826, 1.191580, -1.160056, 2.752997, -1.567649,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  1.575937, 0.915166, -0.092255, 0.504190, 2.020704, -1.437529, 2.146924, 0.554461, -3.012943,
  1.286655, 0.805851, -0.398891, -2.088101, 1.500031, -1.580668, 1.819811, 0.998632, -3.153707,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  1.319677, 0.782455, 0.624938, 1.126002, 3.417397, 0.459690, 2.675681, 2.015093, 0.640322,
  1.226284, 0.706727, 0.264864, 0.963331, 3.650682, 0.738590, 0.623813, 2.453956, -1.712189,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  2.648222, 2.475549, 1.697597, 1.735771, 3.439940, 0.198083, 3.705640, 2.721621, -0.371273,
  3.200555, 4.365078, 3.243478, -0.071244, 3.933076, 0.593685, 3.477477, 2.398958, 0.879514,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  1.473360, 1.187982, 0.110054, 0.170346, 3.458457, 0.364433, 2.930790, 2.531665, 0.378867,
  3.400076, 3.369000, 2.702449, -0.479966, 3.597491, 0.116794, 3.685404, 2.091761, 0.145570,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.920936, 0.541249, -0.347186, -0.771104, 2.696742, -0.171790, 2.527735, 1.740698, -0.495852,
  1.670977, 1.929640, 2.495788, -0.865023, 2.646862, 0.097685, 2.629220, 1.655816, -0.607545,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.465677, 0.518420, -0.781164, -1.803941, 2.827532, -0.290591, 2.191847, 1.607508, -0.588341,
  3.247867, 2.714699, 2.345238, -1.678126, 2.566888, -0.085238, 2.850469, 1.001552, -0.655209,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.787153, -0.198503, -1.782749, -0.900276, 1.912211, -3.663873, 0.848474, -0.836680, -3.669287,
  -1.427844, 0.050626, -1.385942, -2.964514, -0.162616, -2.411914, 0.683265, -1.005256, -4.301865,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -1.607642, -0.665827, -1.239416, -0.780872, 2.824541, -1.087571, 2.113150, 1.872320, -1.425271,
  -1.271072, 0.421148, -1.324322, -1.139011, 3.222929, -0.145552, -1.222022, 2.056318, -2.657646,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -3.730394, -2.009490, -3.094993, -2.535586, 0.762510, -1.689013, 0.819715, -0.239975, -2.658519,
  -1.199086, 0.629059, -0.923631, -2.336624, 0.627240, -1.423159, 1.048893, 0.167676, -3.114150,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -2.552638, -1.976895, -2.856326, -2.372527, 0.860903, -1.052405, 0.750250, -0.044407, -2.921534,
  -0.904000, 0.258227, -0.604627, -2.290100, 0.502605, -1.370851, 1.496794, -0.572584, -2.725464,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -3.698174, -3.074261, -3.590239, -3.648775, 0.190391, -2.667068, 0.472871, -0.197249, -3.801832,
  -1.331095, 0.073236, -1.900405, -3.344213, -0.023255, -2.469306, 1.413047, -0.615235, -3.564428,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -3.804932, -3.153208, -4.886281, -3.794624, 0.626509, -2.963768, -0.369956, -0.601596, -2.917205,
  -2.665226, -1.223268, -2.583733, -3.141997, 0.171332, -3.019183, -2.012588, -0.417437, -3.444846,
  ],
  [
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.322412, -0.114441, -0.754071, 0.635538, 0.514712, -1.276353, 0.279788, -0.690468, -1.674916,
  -0.403422, 0.118673, 0.020245, -0.456925, 1.862041, 0.148091, -1.024320, 1.220130, -1.287300,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.904266, 0.236230, -0.262002, -0.166691, 0.001754, -1.075722, -0.204453, -1.460553, -1.541869,
  -0.116036, 0.226804, -0.145979, -2.868179, -1.205893, -0.995476, -0.489594, -1.430060, -1.604203,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.477425, 0.491062, 0.248182, -0.029979, 1.243206, 0.960888, 1.735620, 0.911087, 1.712243,
  -1.244773, -0.136928, 0.305164, -0.304834, 1.181769, 1.778996, -0.409703, 1.453578, 0.757957,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.148942, 0.132203, -0.183246, -0.091946, -0.391491, -0.554999, 0.192970, -1.143528, -0.628482,
  0.234586, 0.768399, 0.435362, 0.347424, 1.313054, 0.951991, -0.211155, 0.569745, -0.329930,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.226767, -0.506185, 0.024321, -0.462363, -0.180780, 0.486532, 1.114954, -0.274717, 0.296583,
  0.963519, 0.682963, 1.281218, -1.446822, -0.709414, 0.208288, 1.318180, -0.748691, 0.531300,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.419639, -0.934288, -1.261758, -1.530372, -0.944926, 0.088905, 0.735931, -0.230308, 0.543084,
  1.287667, -0.051017, 1.135663, -2.014402, -0.211148, 0.409605, 0.707313, 0.004532, 0.584725,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.626525, -0.423117, -0.818531, 0.209069, 0.428149, -0.122804, 0.303867, -0.465171, 0.226822,
  0.538836, 0.992636, 0.567254, -0.212037, 1.312605, 1.306286, -0.127148, 0.624914, 0.444182,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -1.246228, -0.452293, -0.220809, -1.731128, 0.177730, 0.184666, 1.098436, 0.380791, 1.336743,
  0.527720, 0.669508, 1.848365, -1.416219, 0.348866, 0.768792, 1.025920, -0.034351, 1.189346,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -1.192303, -0.710980, -0.161052, -0.645939, 0.427233, 0.683372, 0.948827, 0.288673, 1.094643,
  -0.080678, -0.299640, 0.819360, -0.720629, 0.903035, 1.132859, 0.413822, 0.735986, 1.463139,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  ],
  [
  -0.094624, -0.237374, 0.902516, -0.247744, -0.023026, -0.991061, -0.119212, 0.633617, 0.072513,
  -0.828542, 0.278403, -0.295344, -0.345104, -0.100237, -0.754226, 0.705072, -1.083427, -0.737333,
  0.641829, 1.009685, 0.236055, -0.313846, 1.197516, 0.569432, 0.501570, 0.636796, 0.474036,
  -0.299258, 0.168002, 0.350942, -0.411941, 0.211972, -0.677076, 0.835551, 0.659742, -0.264849,
  0.087007, 0.129165, 0.095837, -0.678505, -0.114645, -0.607500, 0.853229, -0.186546, 0.216813,
  0.712269, 0.516987, 0.453687, -0.689686, 0.134167, 0.184923, 1.617561, 0.316148, 0.731100,
  -0.122740, -0.285900, 0.189010, -0.733664, 0.011817, 0.232534, 1.181898, 0.814762, 0.830618,
  -0.654115, -0.344705, -0.446467, -0.756257, 0.051582, 0.766165, 1.214694, 0.372284, 0.511739,
  0.662686, 0.020829, 0.999775, -0.948804, 0.826342, 0.169677, 0.222525, 0.484423, 0.751082,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  ],
  [
  -0.471319, 0.547172, -0.219795, -0.538246, -0.858765, -0.362154, 1.156526, 1.958217, 1.272405,
  0.592874, 0.783457, 0.496689, -0.977851, -0.803329, -0.627239, 1.554782, 1.998671, 1.787222,
  -0.663774, 0.243926, 0.560601, -0.726477, 0.062054, -0.479198, 1.269231, 1.706798, 2.792346,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  ],
]
const g_pat2_val_LW = [
  [
  -0.237380, -1.908849, 0.713275, -0.539604, -1.931011, 1.121391, -0.757837, -1.303923, 1.702383,
  0.032772, -1.460790, 0.948621, 0.301276, -1.825012, 1.875487, -1.175247, -1.825182, 1.711844,
  -0.139516, -0.946403, 1.604260, 0.613259, -1.761000, 2.495702, -0.662531, -1.862577, 1.857296,
  -0.866117, -1.068956, 0.620200, -0.264800, -1.661534, 1.751021, -0.508337, -0.950227, 1.434171,
  -0.469228, -0.773633, 0.648394, 0.364107, -3.114330, 2.696573, -0.498602, -0.157291, 2.590692,
  0.444303, -1.517466, 1.625798, -0.607347, -1.271092, 0.000000, -1.560429, -0.779279, 1.563778,
  -0.207514, -0.995188, 1.273041, 0.787517, -1.949854, 1.477048, 0.597419, -1.764688, 1.681607,
  -0.163527, -1.282229, 2.040700, 1.111509, -2.186667, 2.220046, 0.573522, 0.000000, 2.414684,
  0.423858, -1.212263, 1.930214, 0.836392, -2.290749, 1.938924, -0.521697, -2.951292, 2.603506,
  0.133657, -0.066614, 1.765141, 0.245853, -1.142525, 1.694245, -0.629462, -0.419537, 1.605104,
  -0.527498, 0.211655, 0.659126, -0.157279, -2.365156, 1.912904, -1.515188, 2.205861, 2.085209,
  0.654671, -0.415723, 1.905598, 0.951580, -1.618988, 2.719648, -0.478665, -1.362205, 1.976666,
  -0.023672, 0.054812, 1.665095, 0.408663, -0.885896, 1.955910, -0.034792, -1.459422, 2.231260,
  0.051158, -0.033947, 2.075084, 0.040304, -3.718700, 3.475977, -0.243580, 2.948605, 3.108572,
  1.427654, -0.336071, 3.643000, 1.742846, 1.645506, 0.000000, -0.684918, 3.036996, 2.732235,
  0.276222, 0.587208, 2.100002, 1.229832, -1.368976, 3.189981, 0.758534, -1.636769, 2.505371,
  -0.762420, 0.949020, -0.062099, 1.924273, -0.087350, -0.511315, 0.000000, 0.000000, 0.000000,
  0.990631, -0.641777, 2.569355, 1.298482, 0.730540, 0.786994, -1.274168, 2.160510, 2.762107,
  -0.680190, -1.626536, 0.184090, -0.477823, -1.122817, 1.044097, -0.007899, -1.266398, 1.248734,
  -0.350026, -1.471076, 0.167741, 0.524573, -1.461335, 1.675515, -0.993110, -1.283522, 1.169168,
  0.510224, -0.596379, 0.025404, 0.508976, -1.559764, -1.740015, 0.318559, -1.825568, 1.910017,
  -0.965742, -2.220340, -0.627681, -1.239862, -2.072742, 0.642914, -1.375309, -1.727317, -0.055946,
  -0.952296, -2.466827, -0.483429, 0.089946, -2.162809, -2.443454, -1.574771, -1.143374, -0.734231,
  -0.065322, -0.892224, -1.411429, 0.000000, 0.000000, 0.000000, -1.821989, 0.321062, 0.715613,
  -0.211611, -0.706980, 0.356200, -0.509345, -1.795521, 0.882168, 0.132009, -1.894863, -0.261908,
  -1.460857, -3.211491, -1.288496, -0.503686, -3.276112, -3.312974, -1.760178, 0.000000, -1.438461,
  -0.268466, -1.053473, -0.324512, -1.520250, -2.511502, -2.919395, 0.498078, -3.012264, 2.990706,
  -1.883403, -1.722983, -0.071357, -0.373835, -1.680171, 0.794317, -1.322469, -1.473885, 0.690570,
  -0.846029, -0.556806, -0.029184, -0.631271, -2.597472, 1.186662, -2.363886, -0.059589, 1.259386,
  -1.002017, -0.820791, -0.211993, 0.633117, -2.384799, 2.247874, -1.072197, -2.104857, 1.955362,
  -1.387133, -1.288584, 0.494931, -0.106045, -1.361753, 0.520437, -1.446613, -1.071648, 1.269832,
  -1.117149, -0.639553, 0.724832, -0.002056, -2.787128, 2.399672, -2.176686, 1.991506, 2.049461,
  -1.354032, -2.007908, 0.969073, 0.738101, -0.132725, 0.000000, -2.996698, 1.243968, 1.854573,
  -1.128256, -1.204248, 0.114896, -0.758649, -1.170748, 0.144749, -0.190983, -0.762673, 0.321157,
  -1.790538, -1.536318, -0.924769, -0.136177, -2.107436, -1.273725, -0.796447, 0.000000, -0.051144,
  -0.809248, -0.353785, -1.190465, -1.073356, -1.896240, -2.233145, -0.922188, -1.468684, 2.565237,
  -1.843541, -1.686448, -0.989653, -1.197612, -2.157218, 0.149918, -1.983569, -1.235744, -0.040640,
  -1.116516, -1.322483, -0.513335, -0.973344, -2.955299, 1.306124, -2.314561, -0.106588, 0.685157,
  -1.384174, -0.927042, -0.683859, -1.667677, -2.391985, -1.473639, -1.617128, -2.223509, 1.376278,
  -2.338604, -2.773517, -2.071277, -1.866279, -2.633467, -1.578741, -1.994312, -2.104571, -0.952286,
  -3.287066, -2.484025, -2.670627, -3.577180, -4.164772, -3.030896, -2.835326, -1.947831, -1.417138,
  -2.816859, -1.697975, -2.004947, -0.642666, -1.651299, 0.000000, -2.700826, -0.439727, 0.158840,
  -1.629252, -2.045293, -1.278911, -1.862988, -2.571874, -1.053882, -1.601723, -2.583946, -0.610936,
  -1.528739, -0.199237, -0.297024, 1.553816, -1.903849, -1.159619, 0.000000, 0.000000, 0.000000,
  -2.590079, -2.093039, -2.507725, 1.123612, 0.007183, -0.017754, -2.141165, 1.373242, 1.847993,
  -1.571030, -0.881489, -0.746530, -0.790132, -1.666494, 0.135900, -1.375284, -0.954444, 0.729250,
  -1.117132, -1.111965, 0.278167, -0.903246, -2.176489, 0.714606, -2.111849, 0.304246, 0.713665,
  -1.348166, -0.878569, -0.592032, -2.198468, -3.072855, -2.333798, -1.836248, -2.623822, 1.073470,
  -1.201474, 0.236542, -0.163176, 2.065942, 0.121619, 2.103029, -1.236720, 0.359320, 1.592612,
  0.175168, 1.887600, 1.748892, 3.302825, -2.056077, -1.281165, -0.803452, 0.000000, -0.038403,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -1.809663, -2.189290, -0.881427, -1.850825, -2.410058, -0.535388, -2.003513, -2.848112, -0.999434,
  -0.177916, 1.369686, 1.336141, 2.769223, -0.502058, -0.197422, 0.531393, 0.000000, 1.404777,
  -2.676496, -1.699122, -2.313977, 2.310817, 0.989429, 1.247560, -2.461453, 2.756685, 3.053700,
  0.760888, -0.100038, 1.144525, 1.374293, -1.158208, 1.202815, -0.207646, -0.368532, 1.465207,
  1.239076, 0.048818, 0.993189, 1.445459, -2.032222, 2.314533, -0.713530, -0.083157, 1.962841,
  1.132586, -0.187408, 0.604881, 1.810501, -1.025345, 1.143872, 0.722011, -1.192731, 2.096094,
  1.423155, 0.497215, 0.743617, 1.191028, -0.237789, 1.385649, 0.372085, -0.154095, 1.392293,
  0.931892, 1.618116, 1.133437, 2.041858, -2.701758, 2.014137, -0.309193, 1.255853, 1.717736,
  1.734370, -0.360833, 1.501134, 0.710910, -0.430489, 0.000000, -1.312206, 1.639485, 1.777509,
  1.505923, 0.180106, 1.287584, 2.296447, -0.910117, 1.020017, 0.425336, -0.507444, 1.115922,
  2.262633, 0.504955, 1.441243, 3.152532, -2.295512, -1.809767, -1.623835, 0.000000, 0.106099,
  1.556236, -0.914311, -0.351850, 2.546490, -2.420285, -2.012493, 0.123292, -2.330875, 2.649708,
  1.607814, 0.505128, 1.357678, 1.338577, -0.328332, 1.704061, 0.989408, 0.099619, 1.669051,
  1.194504, 0.997298, 1.212051, 2.170451, -1.243191, 2.740132, 0.277724, 1.937349, 2.494371,
  1.187153, 0.344471, 0.493568, 2.745950, -0.784929, -0.431148, 0.740846, -0.272949, 1.626141,
  2.097980, 1.556173, 1.775640, 2.783581, 1.142442, 2.596506, 1.703935, 0.943266, 1.970464,
  2.641589, 2.112945, 1.761304, 3.717424, -3.078069, -3.065953, -2.579485, -1.427044, -1.069899,
  2.728575, -2.194959, -1.699429, -0.763144, -0.810607, 0.000000, -2.998432, -0.133928, 0.287902,
  1.716322, 1.816810, 1.710192, 2.214819, -1.659803, -0.525380, -1.237793, -1.740641, -0.427485,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  1.692082, -2.098755, -2.319657, 0.868217, 0.081248, 0.000000, -2.631446, 1.789269, 2.293622,
  1.457942, 1.072470, 1.692199, 2.348897, 0.179456, 1.489903, 0.689390, 0.900042, 1.730395,
  1.797903, 1.152954, 1.523106, 2.270624, -0.895211, 2.022889, 0.392095, 1.719936, 2.141443,
  1.917713, 0.306333, 1.530368, 2.520116, -0.557341, -0.121362, 0.339020, -0.810102, 2.712148,
  1.575717, 1.328690, 2.108880, 1.805941, 0.160352, 2.477585, 1.105741, 0.526775, 2.091913,
  2.242311, 2.289788, 2.160494, 3.485412, -1.355171, -1.108886, -0.458152, -0.049779, 0.256360,
  2.796966, 0.098791, 0.056559, 0.000000, 0.000000, 0.000000, -1.280714, 1.504489, 1.871901,
  2.392677, 2.024693, 2.416410, 2.446506, 1.227611, 2.082773, 1.936784, 0.904063, 2.487909,
  2.254191, 1.619990, 1.644085, 3.082095, 0.139612, 0.295247, 0.737928, 0.000000, 2.002338,
  2.390138, 2.163743, 2.363545, 2.547821, 1.864724, 1.917156, 2.780997, 3.584802, 3.325874,
  ],
  [
  0.000000, 0.000000, 0.000000, -0.046846, -0.975293, 0.502683, -0.166336, -0.394249, 0.006736,
  0.097268, -0.121649, -0.030957, 0.256038, 0.091867, 1.081944, -0.394211, -0.274008, 1.116017,
  -0.508182, -0.583819, -0.281348, 0.294811, -0.709545, 0.272016, -0.489443, -1.670950, -0.298224,
  -0.162485, 0.165555, 0.247765, -0.022726, 0.246783, 0.221023, 0.022269, -0.335267, 0.279519,
  0.775014, 0.305304, 0.595279, -0.265164, -0.004334, 0.567544, 0.149164, 0.711308, 0.717646,
  -0.080730, 0.220388, 0.112006, 0.702954, 0.234731, 0.379848, -0.371224, -0.339135, 0.135253,
  -0.104695, -0.764935, 0.089951, -0.026045, 0.064250, 0.096287, -0.103156, 0.056485, 0.065274,
  0.388090, 0.052590, -0.095782, 0.361043, -0.264712, 0.379819, -0.305305, 0.420697, 0.309431,
  -0.571995, 0.042207, -0.368206, -0.430244, -0.729345, -0.390964, -0.130226, -1.241826, 0.442666,
  -0.000794, 0.047425, 0.727572, -0.479286, -0.255171, 0.052492, -0.181463, -0.148568, 0.174437,
  -0.256367, -0.382291, -0.193728, -0.274071, -0.019249, 0.104584, -0.887248, -0.212525, 0.243861,
  -0.483998, 0.304523, 0.426399, -0.105290, -0.117413, 0.321967, 0.235426, -1.227703, 0.266345,
  0.262238, -0.056292, -0.027409, -0.224475, -0.593838, -0.744516, 0.129268, -0.330132, 0.236822,
  -0.515715, -0.917045, 0.295537, -0.500456, -0.936892, 0.265474, -0.092694, -0.140834, 0.172328,
  0.167136, 0.114842, 0.598361, 0.299958, -0.013638, 0.004017, -0.111003, 0.686797, 0.339863,
  0.313360, 0.204770, 0.371262, 0.345558, -0.056353, 0.412390, 0.500152, -0.411444, -0.071330,
  0.237337, -0.010574, -0.006699, 0.489043, -0.131167, -0.457062, 0.089144, -0.455500, 0.236545,
  -0.013085, -0.097467, 0.251322, -0.099927, -0.111797, 0.020583, -0.181403, 0.012801, 0.534612,
  -0.219831, -0.567366, -0.055300, -0.052562, 0.460209, 0.802905, -0.329926, -0.440664, -0.025103,
  0.183031, -0.294316, 0.239266, 0.056411, 0.387163, 0.745930, -0.265495, -0.204363, 0.664380,
  -0.047977, 0.323400, 0.683372, 0.286954, 0.169987, 0.212379, 0.088717, -0.135666, 0.909568,
  -0.073207, 0.069554, 0.626043, -0.487257, 0.000174, 0.464833, 0.016386, -0.065383, 0.534676,
  0.110238, 0.066685, 0.512750, 0.009195, -0.273157, -0.293042, 0.123913, 0.147322, -0.070065,
  0.486561, 0.247728, -0.196168, -0.139390, 0.259887, 0.360058, -0.170549, 0.135136, 0.419929,
  -0.741189, 0.033905, -0.049795, 0.172694, 0.042243, 0.350885, 0.166127, -0.035846, 0.151856,
  -0.259297, -0.358982, 0.072858, -0.269127, -0.579604, -0.532166, -0.385858, -0.268332, -0.453157,
  0.265953, 0.949490, 0.667673, -0.506324, -0.310455, 0.140111, 0.952118, -0.399837, 0.647991,
  0.000000, 0.071411, -0.086191, -0.148049, -0.068223, 0.444556, -0.232997, -0.538511, -0.154644,
  0.295197, -0.400852, 0.244709, -0.032989, 0.110429, 0.623926, -0.040306, 0.159525, 0.934060,
  -0.531237, 0.189282, -0.624540, 0.113188, -0.444947, -0.096506, -0.435698, -0.968622, 0.375454,
  0.308413, 0.097189, 0.237381, -1.053140, 0.061271, -0.240747, 0.319891, -0.264809, 0.067108,
  -0.224147, -0.307482, -0.012868, -0.493206, -0.605751, 0.282912, -0.424478, -0.103303, 0.367337,
  -0.123667, -0.149783, 0.100880, -0.252760, -0.178893, -0.311005, -1.024257, 0.130825, -0.075293,
  -0.239285, -0.185961, -0.170339, -0.046151, 0.419905, 0.792157, 0.139186, 0.470110, 0.027570,
  0.455231, 0.194044, 0.124617, 0.011771, 0.529414, -0.225146, 0.077522, -0.084590, -0.009369,
  0.330506, 0.718417, 0.843943, -0.329506, -0.006136, -0.230816, 0.775232, -0.674330, 0.376114,
  -0.232905, -0.326264, 0.290598, -0.228914, -0.274682, 0.128880, 0.476856, -0.408336, 0.115943,
  -0.272097, 0.162238, -0.311019, -0.136066, 0.106880, 0.866297, 0.077933, 0.181517, 0.215851,
  0.036822, -0.039867, 0.093418, 0.315420, -0.428211, 0.000677, 0.303669, -0.603129, 0.392162,
  0.473920, -0.191589, 0.196343, -0.343273, -0.011048, -0.403560, 0.102220, -0.079029, 0.189755,
  -0.156766, -0.345040, -0.239127, -1.263784, -0.863125, -0.589564, -0.774098, -0.608869, -0.769723,
  0.012736, -0.196379, 0.248575, -0.044394, 0.004539, -0.210995, -0.820636, 0.130168, 0.067330,
  -0.392848, -0.426169, -0.217461, -0.060643, 0.038489, -0.024503, 0.516868, -0.435133, -0.123856,
  -0.007647, -0.009111, -0.090832, 0.034785, -0.165945, 0.267746, 0.093098, 0.482739, 0.278737,
  -0.355736, -0.578481, -0.379113, -0.416100, 0.895025, 0.564747, -0.237700, 0.891074, 0.652756,
  -0.776723, -1.383275, -0.324797, -0.586173, -0.412576, -0.120767, -0.491228, -0.194268, -0.131815,
  -0.091948, -0.462011, -0.077757, -0.420534, 0.168138, 0.070512, -0.441474, -0.157949, -0.146982,
  -0.531057, -0.026771, 0.316803, -0.341376, -0.159113, -0.014349, -0.122693, -0.027312, 0.512474,
  0.504195, 0.301364, 0.212397, -0.121544, 0.161074, 0.302209, 0.088480, -0.330031, 0.344919,
  0.432533, -0.061192, -0.191340, 0.387698, -0.276092, -0.137616, 0.081735, -0.475960, -0.173779,
  -0.118417, -0.044035, -0.161118, -0.126047, 0.323368, 0.015046, 0.025076, 0.516209, 0.045929,
  -1.240967, -0.955316, -0.760603, -1.006965, -0.257131, -0.405114, 0.014334, -0.622345, -0.371715,
  -0.685341, -0.049557, 0.336749, 0.163490, 0.174915, 0.465245, 0.183973, 0.249052, -0.084713,
  -1.072588, -0.862713, -0.646781, -0.181548, 0.534903, 0.539408, -0.708700, 0.888740, 0.815301,
  0.000000, -0.019127, -0.130024, 0.709491, 0.035485, 0.734205, -0.621953, -0.346611, -0.021184,
  0.153744, 0.029011, -0.249785, 0.159529, 0.330476, 1.277745, 0.537710, 0.254792, 1.003355,
  -0.637423, -0.378692, -0.529458, 0.012958, -0.273802, 0.214822, 0.260605, -1.040998, -0.447910,
  -0.073784, 0.438355, 0.432836, -0.132168, 0.123697, -0.213485, 0.438036, -0.089762, -0.323967,
  0.038052, -0.144118, -0.695863, -0.073165, -0.266327, -0.053008, 0.104154, 0.466163, 0.126479,
  0.043365, 0.284031, -0.398947, 0.680203, 0.425623, 0.246586, -0.024531, -0.193198, -0.166426,
  0.088485, -0.304804, -0.291489, 0.300568, -0.183944, -0.018226, 0.065557, 0.111636, 0.153981,
  0.265782, -0.011954, -0.111724, 0.415453, 0.007033, -0.404952, -0.135674, 0.085577, -0.161529,
  0.375529, 0.213118, -0.008986, -0.357115, 0.268924, -0.082363, 1.005755, -0.130412, 0.282239,
  0.548848, 0.523419, 0.550702, 0.093860, 0.495855, 0.097495, 0.716494, 0.326343, 0.244679,
  0.948938, -0.087285, -0.448640, -0.317387, -0.219409, 0.215844, 0.502869, 0.308483, 0.040575,
  0.476928, 0.451884, 0.132674, -0.117509, -0.284496, -0.129325, 0.253067, -0.787516, 0.112021,
  1.767664, 0.723460, 1.037998, -0.222949, 0.652508, 0.106494, 1.147822, 0.173572, 0.205208,
  0.419772, -0.116147, 0.074318, -0.019803, -0.905118, -1.164331, -0.483222, -0.365110, -0.858151,
  0.071399, -0.127828, -0.045300, -0.387944, 0.103711, -0.354166, -0.757375, -0.311870, -0.468985,
  0.962800, -0.271307, 0.294447, 0.424797, -0.237421, 0.266564, 0.347876, -0.305166, -0.365497,
  0.374106, -0.049462, -0.066670, 0.786218, -0.009292, -0.489236, 0.011405, 0.081808, -0.065685,
  -0.080270, -0.406992, -0.467711, -0.239528, 0.529172, 0.589115, -0.241253, 0.485518, 0.119966,
  0.140567, 0.042657, 0.007108, 0.298160, 0.227323, -0.219250, 0.176025, -0.407384, 0.087344,
  0.608031, 0.199088, 0.022721, 0.280154, -0.305427, 0.448524, 0.010010, 0.210936, 0.195922,
  0.301606, 0.219923, 0.011104, 0.065415, 0.105024, -0.484287, -0.084921, -0.274307, -0.272428,
  1.141925, 0.531236, 0.446233, 0.353378, -0.128652, 0.365081, 0.485146, -0.128516, 0.169411,
  0.284053, -0.068438, -0.070003, 0.179321, -0.391435, -0.652552, -0.455966, -0.250957, -0.094694,
  -0.203957, 0.224230, -0.148864, 0.295932, 0.378407, -0.159145, -0.585364, 0.256580, 0.221239,
  0.509461, -0.275494, 0.061099, 0.342098, 0.122555, -0.204129, 1.169196, 0.053836, 0.066038,
  0.350918, -0.098270, -0.642848, 0.560503, 0.198958, -0.436708, 0.491904, 0.195601, -0.293140,
  0.359078, 0.705069, 0.310718, 0.183930, 0.157236, 0.047666, 0.903630, 0.501536, 0.577054,
  ],
  [
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.171121, -0.083913, 0.745825, 0.357954, 0.068421, 0.301954, -0.249090, 0.369662, 0.347404,
  0.323658, -0.084298, 0.378690, -0.059632, -0.236937, 0.033966, -0.395153, -0.518477, 0.041631,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.276773, -0.209752, 0.318143, 0.281805, -0.146539, 0.640753, 0.037211, 0.002867, 0.290121,
  -0.046578, -0.465616, 0.310882, 0.281322, 0.045792, 0.185429, -0.195596, -0.230999, 0.056778,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.635369, -0.518414, 0.271126, 0.002306, 0.225624, 0.302515, -0.012601, 0.333586, 0.111944,
  0.718696, -0.310146, 0.456987, -0.024911, 0.358752, 0.185239, -0.160163, 0.428967, 0.131614,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.122300, -0.383306, -0.342169, 0.221684, 0.097211, -0.150395, -0.386253, -0.604937, -0.077112,
  0.429522, 0.527581, 0.829884, -0.000639, -0.122335, -0.387714, -0.263681, 0.138837, 0.034775,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.383429, -0.591317, 0.020392, 0.258538, 0.226906, -0.051698, -0.025703, 0.089223, 0.361891,
  0.074330, 0.127838, 0.295340, -0.091729, -0.090480, 0.079487, -0.139132, 0.050604, 0.488817,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.736985, -0.588455, -0.003220, -0.011020, -0.250824, -0.103733, 0.173623, 0.043674, -0.326082,
  -0.190818, 0.187377, 0.088094, -0.102626, -0.148773, -0.490382, 0.354452, -0.234948, 0.440804,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.359361, -0.081062, 0.143562, -0.622481, -0.376765, -0.495565, -0.964325, -0.288073, -0.750703,
  -0.111350, 0.017421, -0.049998, -0.489086, -0.668736, -0.297096, -0.695675, -0.329782, -0.477460,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.246564, 0.065036, 0.529833, 0.451855, 0.566792, 0.520933, 0.085367, 0.307282, 0.218218,
  -0.511631, 0.551687, 0.122230, 0.242112, 0.477306, 0.366849, -0.144025, -0.483242, -0.070940,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.232729, -0.467260, 0.314645, -0.541114, -0.420438, -0.610163, -0.325250, 0.186280, -0.226226,
  0.303995, 0.336644, 0.795834, -0.266795, -0.384187, -0.661815, 0.186941, -0.223555, 0.073008,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.203044, -0.576734, -0.072413, -0.077272, -0.114446, -0.181912, 0.070379, 0.214486, 0.088472,
  -0.401687, 0.177076, 0.548107, -0.216048, 0.087985, 0.009236, -0.505493, 0.722270, 0.234767,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.268249, -0.330709, -0.113989, 0.219037, 0.175874, 0.080588, -0.082814, 0.361420, 0.186859,
  0.375221, 0.136180, 0.597722, -0.196312, 0.496896, -0.035547, -0.003004, 0.487897, 0.986857,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.699533, -0.308713, -0.506919, 0.116030, 0.066477, -0.196754, 0.276098, 0.256562, 0.462994,
  -0.485758, -0.294281, 0.431834, 0.123175, -0.014192, 0.315700, -0.195797, 0.493700, 0.540107,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.042207, -0.346327, -0.409249, -0.170759, -0.059802, 0.211672, -0.039529, -0.130635, -0.741267,
  0.479318, 0.299404, 0.268650, -0.352515, -0.063193, -0.465324, -0.596606, -0.463427, 0.008313,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.403542, 0.076331, 0.048684, 0.936128, 0.202629, 0.650303, 0.583111, 0.764081, -0.067022,
  0.485876, 0.027753, 0.301071, 0.641433, 0.683343, 0.383710, 0.170854, 0.471906, 0.029615,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.368742, -0.485134, 0.166688, 0.080973, -0.431760, -0.225038, 0.074850, -0.096514, -0.607061,
  0.804331, 0.170738, 0.320439, -0.130289, -0.412146, -0.580472, 0.010343, -0.120370, 0.021777,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.366464, -0.907218, -0.536109, 0.234227, 0.239916, 0.169387, 0.185640, 0.325154, 0.160702,
  0.115898, 0.462277, -0.236963, -0.030473, -0.091069, -0.449070, -0.277716, 0.132183, -0.048819,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.242653, -0.663219, -0.436990, 0.242565, -0.294287, 0.109910, 0.116707, 0.072241, 0.130386,
  0.075064, 0.200491, 0.148867, -0.290935, 0.273600, 0.215385, -0.350807, 0.453290, 0.530796,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.130670, -1.006512, -0.417028, 0.525992, -0.155984, -0.200163, 0.372083, 0.274401, -0.252911,
  -0.257666, 0.297624, -0.004424, 0.055614, 0.187886, 0.293946, 0.438436, 0.638957, 0.354623,
  ],
  [
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.620139, -0.321857, 1.424359, -0.097601, -1.101315, 1.675615, -0.489764, -1.230069, 1.288492,
  -0.142089, -0.859453, 0.735168, -0.354506, -1.091004, 0.422832, -1.759670, -1.501931, 0.865020,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.269224, -0.492028, 0.810178, 0.706722, -0.986490, 1.593816, -0.149326, -0.567222, 1.514039,
  -1.011831, -0.594789, 0.374233, 0.067587, -1.089709, 1.375162, -0.549117, -1.239391, 1.056324,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.602330, -0.144752, 0.557105, -0.300205, -1.202056, 1.567431, 0.442106, -0.082788, 1.596609,
  1.393676, 0.391491, 1.431904, -0.217127, -0.522520, 1.313981, -0.938910, -0.079668, 1.562945,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.048829, -0.076343, 0.486651, 0.177864, -0.519465, 0.579681, -0.096665, -0.513663, 1.512057,
  -0.002688, -0.114270, 0.899812, 0.187465, -0.935652, 0.789379, -0.298697, 0.028183, 1.542342,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.469200, -1.342400, -0.249870, 0.227248, -1.392809, 0.369186, 0.166734, -0.817817, 0.317195,
  0.095572, -0.308662, 0.080587, 0.216412, -1.247065, -0.262165, -0.366099, -0.608456, 0.727024,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -1.102633, -2.222105, -0.805713, -0.555155, -1.230816, 0.025484, -0.827073, -0.652030, 0.946362,
  -0.308588, 0.220919, 0.441803, -0.650896, -1.090024, 0.647971, 0.423547, -1.274456, 1.880019,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.321651, -0.362763, -0.161194, -0.430233, -1.637791, 0.534148, -1.199330, -1.676723, 0.560481,
  -0.454688, -0.576876, -0.001836, -0.640205, -1.665365, 0.106176, -1.706033, -1.857872, 0.536106,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.557387, -0.428279, 0.040882, 0.363067, -1.261646, 0.497510, -0.817269, -0.845886, 0.536424,
  -1.015906, -0.871328, 0.014014, 0.225482, -1.948470, 0.471354, -0.257973, -1.728502, 1.044769,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -1.393182, -1.833509, -0.938556, -1.714859, -2.711658, -0.426656, -1.568276, -2.149713, -0.188769,
  -0.419152, -1.614030, -0.372562, -0.911784, -2.467824, -0.148980, -1.530804, -1.673193, 0.075836,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -1.222610, -1.839280, -0.887081, -0.458253, -2.256524, -0.350155, -1.427933, -1.948183, -0.098481,
  -1.032648, -1.943510, -0.522426, -0.833421, -2.095295, -0.134365, -1.661556, -2.182880, 0.218893,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -1.396069, -1.872015, -0.204171, -0.023115, -2.335639, -0.175620, -0.586329, -1.767701, 0.638016,
  -0.707944, -1.610292, -0.297894, 0.210519, -1.850375, -0.062842, -1.014754, -1.330216, 0.650120,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -1.610673, -1.654695, -1.018201, -0.107168, -1.990659, 0.436061, -0.635668, -1.651607, 0.372937,
  -1.357393, -1.831624, -1.086245, -0.176841, -1.736085, -0.156511, -1.293975, -1.272721, 0.840589,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.678525, 0.092069, 0.860186, 0.917978, -0.749606, 1.960496, -0.175500, -0.594889, 1.311277,
  1.116620, 0.251803, 1.136757, 0.555488, -0.799459, 1.369660, -0.757524, -0.645384, 1.031039,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.642664, 0.593354, 1.128864, 1.226436, -0.445460, 1.663804, 0.407980, -0.247039, 2.051177,
  0.128276, -0.303676, 0.804972, 1.286171, -0.581591, 1.468232, 0.728261, -0.958013, 1.627997,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  1.663071, 0.667822, 1.707601, 1.120321, -0.479673, 1.478738, -0.055104, -0.295632, 1.805897,
  1.476086, 0.821971, 1.530089, 0.997297, -0.196590, 1.646097, 0.286098, -0.474233, 1.989017,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.500466, 0.490883, 1.412938, 1.097168, -0.295991, 1.400056, 0.238967, 0.087800, 1.954230,
  1.541656, 0.903957, 1.619527, 0.585627, -0.256388, 1.433995, 0.625143, 0.231321, 2.214228,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.665464, 0.378560, 1.864548, 1.385579, -0.256055, 1.580767, 0.811023, 0.078554, 2.235138,
  1.881328, 0.935629, 1.757905, 1.540053, 0.057423, 1.822996, 0.541569, 0.672280, 2.305851,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.821721, 0.891591, 1.149289, 1.794335, -0.132274, 2.225363, 1.070766, 0.763341, 2.294879,
  1.273832, 0.733016, 1.427125, 1.422129, 0.762422, 2.262023, 1.272853, 0.743698, 2.358903,
  ],
  [
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.130290, -0.451457, 0.259603, 0.403409, -0.998982, 0.707496, -0.295103, -0.328413, -0.359505,
  0.041465, 0.013307, 0.444608, 0.863053, -0.118101, 0.627554, -0.126519, -0.685048, 1.222604,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.326641, -0.753310, 0.381148, -0.250714, -0.882448, 0.444607, 0.199317, -0.294256, 0.357412,
  0.329052, -0.000454, 0.763017, -0.180485, -0.892272, 0.533906, -0.056543, -0.233672, 0.702597,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.328597, -0.285332, -0.333013, 0.595156, -0.291146, 0.791235, 0.233491, -0.160397, 0.080036,
  -0.124262, 0.070731, 0.787216, -0.194759, -0.487147, 0.033836, 0.693197, -0.735402, 1.049201,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.457950, -0.729522, 0.135570, -0.769918, -0.690852, 0.408954, -0.738462, -0.347110, 0.082882,
  -0.384645, -0.064884, 0.194547, 0.281612, -0.268017, 0.060208, -0.513091, -0.682969, 0.488599,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.050920, -0.929787, -0.107951, -0.977034, -1.251626, -0.362209, -0.072761, -0.542182, 0.466353,
  -0.200654, -0.690238, 0.107077, -0.711209, -1.125352, -0.368331, -0.592605, -0.523559, 0.486040,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.510323, -0.626977, -0.208104, -0.445456, -0.933921, -0.091969, -0.320204, -0.527143, 0.449301,
  -0.361950, -1.034482, -0.409265, -0.347924, -0.107286, 0.210079, -0.897021, -0.057855, 0.540743,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.299895, -0.317665, -0.004573, 1.158047, -0.084387, 0.807822, 0.510771, -0.187280, 0.313523,
  0.429478, 0.565030, 0.673901, 1.080717, 0.145390, 0.615919, 0.458827, -0.473407, 0.950704,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.259718, 0.320851, 0.615604, 0.644713, -0.191988, 0.346901, 0.160305, -0.412367, 0.753393,
  0.477885, 0.497690, 0.822006, 0.166744, -0.043223, 0.401215, 0.312791, 0.157591, 1.049962,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.162463, -0.374226, 0.512174, 0.198531, -0.125141, 0.746678, 0.515175, 0.603566, 0.603714,
  0.625168, 0.402927, 0.404140, -0.064522, 0.330304, 0.707718, 0.681797, 0.242130, 0.857849,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  ],
  [
  -0.103441, 0.424786, -0.089214, -0.192233, -0.159279, 0.409254, 0.039416, -0.294806, 0.018476,
  0.185988, -0.141444, 0.151481, -0.137509, -0.301328, 0.684678, 0.234480, -0.179458, -0.026358,
  -0.103012, 0.374524, 0.378717, 0.089439, -0.302185, 0.449959, 0.318112, -0.236223, 0.693674,
  -0.221817, 0.227104, -0.290862, -0.172363, -0.342717, -0.104921, 0.434728, -0.035090, -0.191198,
  -0.139190, 0.337945, 0.136633, -0.343176, -1.003777, -0.192747, -0.243409, 0.381278, 0.143563,
  -0.555512, -0.391528, -0.299003, 0.228204, 0.093128, -0.055856, -0.708563, 0.786719, 0.787873,
  0.350194, -0.027281, 0.439670, 0.114937, 0.173920, 0.578910, 0.660809, -0.210387, 0.240861,
  0.436200, 0.312491, 0.274750, 0.597232, -0.664274, -0.213400, 0.028792, -0.206027, 0.466067,
  0.688406, -0.116828, 0.595632, 0.081372, -0.339683, -0.011457, 0.403861, 0.212393, 0.611990,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  ],
  [
  0.144350, -0.266480, 0.494876, -0.239100, -0.497291, 0.398177, 0.835690, -0.160645, 0.888819,
  -0.217761, -0.340352, 0.053480, -0.349460, -0.952740, -0.121524, -0.029072, -0.138000, 0.090022,
  0.934296, 0.442379, 1.312877, 0.633294, 0.418303, 0.590931, 0.847807, 0.137651, 1.020562,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  ],
]
const g_npbw_val = [
  [  -1.100957, -1.580669, 0.421011, 3.402425, 6.805137, 8.287308, 8.932731, 9.724490, 9.594696, ],
  [  -0.238193, -2.835734, -0.652330, 2.883754, 4.680688, 7.387002, 8.750883, 9.638002, 9.996876, ],
  [  -2.491301, -6.621022, -3.467678, 0.603922, 3.389340, 5.600759, 7.708919, 8.463098, 8.859036, ],
  [  -6.768501, -8.533801, -4.783741, -0.683168, 1.784597, 4.413062, 5.856626, 6.518043, 7.769190, ],
  [  -9.143374, -9.387193, -5.272302, -1.986885, 0.183539, 2.590005, 4.185691, 5.814040, 5.757242, ],
  [  -10.777906, -8.803990, -6.178785, -2.730830, -0.685045, 1.467368, 2.663987, 3.697831, 4.212288, ],
  [  -11.269992, -8.877430, -5.405372, -3.452391, -1.488815, 0.129756, 1.907144, 2.339594, 2.555117, ],
  [  -10.606501, -8.697511, -5.784572, -3.995143, -2.403796, -0.735672, 0.330543, 0.741030, 0.752994, ],
  [  -9.482450, -7.586755, -5.775105, -4.188809, -2.518537, -1.580775, -0.143632, 0.291352, 0.056181, ],
]
const g_npbw_val_LW = [
  [  -0.450832, -1.142715, -0.516857, 0.807805, 2.587910, 3.606273, 5.129072, 6.448098, 7.659422, ],
  [  -0.048758, -1.998129, -0.678591, 1.287366, 2.885141, 4.443682, 5.692499, 7.031418, 8.282873, ],
  [  -0.517561, -3.361090, -1.543622, 0.428864, 2.049947, 3.793984, 5.235349, 6.600048, 7.872921, ],
  [  -1.563358, -4.781179, -2.288292, -0.653598, 1.052518, 2.986168, 4.182808, 5.539856, 6.720244, ],
  [  -4.027743, -5.649034, -3.501543, -1.506926, 0.247270, 1.736327, 2.877520, 4.683075, 5.419307, ],
  [  -5.653105, -5.904676, -4.170840, -2.278795, -0.693391, 0.935232, 2.186242, 3.365615, 4.390664, ],
  [  -7.086067, -6.852486, -4.773910, -3.003481, -1.317032, -0.230687, 1.084612, 2.067456, 2.803095, ],
  [  -7.917411, -7.617793, -5.508787, -3.845581, -2.443603, -0.669198, 0.205894, 1.141953, 0.889629, ],
  [  -8.424613, -7.933195, -5.337000, -4.535517, -3.013534, -1.635979, -0.732566, 0.055053, 0.137251, ],
]

func _on_BackButton_pressed():
	get_tree().change_scene("res://TopScene.tscn")
	pass # Replace with function body.

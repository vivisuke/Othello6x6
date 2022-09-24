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
var black_side = AI
var white_side = HUMAN
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
	update_humanAIColor()	# 人間・AI 石色表示
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
func update_humanAIColor():
	$HumanBG/Black.set_visible(AI_color == WHITE)
	$HumanBG/White.set_visible(AI_color != WHITE)
	$AIBG/Black.set_visible(AI_color != WHITE)
	$AIBG/White.set_visible(AI_color == WHITE)
#
func xyToBit(x, y):		# 0 <= x, y < 6
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
	$HumanBG/Num.text = "%d" % nColors[hix]
	$AIBG/Num.text = "%d" % nColors[aix]
func update_cursor():
	#print("next_color = ", next_color)
	n_legal_move = 0
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
func update_nextTurn():
	if n_legal_move == 0:
		#next_color = (BLACK + WHITE) - next_color
		#update_cursor()
		if( next_color == WHITE && count_n_legal_move_black(bb_black, bb_white) != 0 ||
		next_color == BLACK && count_n_legal_move_black(bb_white, bb_black) != 0 ):
			next_pass = true
			$MessLabel.text = "パスです。画面をタップしてください。"
		else:
			game_over = true
			next_color = EMPTY
			$HumanBG/Underline.set_visible(false)
			$AIBG/Underline.set_visible(false)
			#$MessLabel.text = "Game Over"
			if nColors[BLACK] > nColors[WHITE]:
				$MessLabel.text = "Black won %d" % (nColors[BLACK] - nColors[WHITE])
			elif nColors[BLACK] < nColors[WHITE]:
				$MessLabel.text = "White won %d" % (nColors[WHITE] - nColors[BLACK])
			else:
				$MessLabel.text = "draw"
	else:
		$HumanBG/Underline.set_visible(next_color != AI_color)
		$AIBG/Underline.set_visible(next_color == AI_color)
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
func nega_alpha(black, white, alpha, beta, depth, passed) -> float:
	if !depth: return bb_eval(black, white)
	var put : bool = false
	var spc : int = ~(black | white) & BB_MASK
	if spc == 0:
		return popcount(black) - popcount(white)
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
		return popcount(black) - popcount(white)
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
	elif !game_over && !AI_thinking && next_color == AI_color:
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
			bb_put_white(xyToBit(x, y))
		next_color = BLACK
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
				if next_color == BLACK:
					#if !canPutBlack(pos.x, pos.y): return
					#putBlack(pos.x, pos.y)
					if !bb_can_put_black(bb_black, bb_white, xyToBit(pos.x, pos.y)): return
					bb_put_black(xyToBit(pos.x, pos.y))
					next_color = WHITE
				else:	#if next_color == WHITE:
					#if !canPutWhite(pos.x, pos.y): return
					#putWhite(pos.x, pos.y)
					if !bb_can_put_black(bb_white, bb_black, xyToBit(pos.x, pos.y)): return
					bb_put_white(xyToBit(pos.x, pos.y))
					next_color = BLACK
				#putIX = xyToArrayIX(pos.x, pos.y)
				putPos = xyToBit(pos.x, pos.y)
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
		return popcount(black) - popcount(white)
	var ev = 0.0
	var lst = bb_get_pat_indexes(black, white)
	for i in range(lst.size()):
		ev += g_pat2_val[g_pat_type[i]][lst[i]]					# 直線パターン
	var npb = min(8, count_n_legal_move_black(black, white))	# 黒着手可能箇所数
	var npw = min(8, count_n_legal_move_black(white, black))	# 白着手可能箇所数
	ev += g_npbw_val[npw][npb]
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

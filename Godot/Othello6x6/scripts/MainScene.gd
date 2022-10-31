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
var cp_hist = []			# 着手履歴、要素：[BLACK or WHITE, 打った位置]


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
	cp_hist = []	# 着手履歴初期化
	init_bb()		# 盤面データ初期化
	init_bd_array()		#	盤面TileMap初期化
	update_TileMap()
	update_cursor()
	update_nextTurn()
	waiting = 6
	$TitleBar/Rule.text = "Normal" if g.rule == g.NORMAL else "LessWin"
	#$RestartButton.disabled = true
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
	
func init_bb():		# 盤面データ初期化
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
func init_bd_array():		#	盤面TileMap初期化
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
	$RestartButton.disabled = true
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
	var diff = abs(nwin - nloss)
	if nwin + nloss < CELL_SIZE:
		diff += CELL_SIZE - (nwin + nloss)
	return diff
func update_UndoButton():
	$UndoButton.disabled = (next_color == BLACK && g.black_player == AI ||
							next_color == WHITE && g.white_player == AI)
func update_nextTurn():
	if n_legal_move == 0:
		# 次の手番が着手不可能な場合
		if( next_color == WHITE && count_n_legal_move_black(bb_black, bb_white) != 0 ||		# 黒着手可能
		next_color == BLACK && count_n_legal_move_black(bb_white, bb_black) != 0 ):			# 白着手可能
			next_pass = true
			$MessLabel.text = "パスです。画面をタップしてください。"
		else:
			game_over = true
			$RestartButton.disabled = false
			next_color = EMPTY
			$BlackBG/Underline.set_visible(false)
			$WhiteBG/Underline.set_visible(false)
			#$MessLabel.text = "Game Over"
			if nColors[BLACK] == nColors[WHITE]:
				$MessLabel.text = "draw"
			elif( (g.rule == g.NORMAL && nColors[BLACK] > nColors[WHITE]) ||
			(g.rule != g.NORMAL && nColors[BLACK] < nColors[WHITE]) ):
				$MessLabel.text = "Black won %d" % result_diff(nColors[BLACK], nColors[WHITE])
			else:
				$MessLabel.text = "White won %d" % result_diff(nColors[WHITE], nColors[BLACK])
			#elif nColors[BLACK] < nColors[WHITE]:
			#	$MessLabel.text = "White won %d" % result_diff(nColors[WHITE], nColors[BLACK])
			#else:
			#	$MessLabel.text = "draw"
	else:
		$BlackBG/Underline.set_visible(next_color != AI_color)
		$WhiteBG/Underline.set_visible(next_color == AI_color)
		# $MessLabel.text = "AI 思考中・・・" if next_color == AI_color else "人間の手番です。"
		$MessLabel.text = "黒の手番です。" if next_color == BLACK else "白の手番です。"
	update_UndoButton()
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
# pos 位置から dir 方向の長さ n のパターンインデックスを計算
func bb_get_pat_index(black, white, pos, dir, n):
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
func bb_get_pat8_indexes(black, white):		# コーナー８箇所パターンインデックスを計算し、結果を配列で返す
	var lst = []
	var ix = bb_get_pat_index(black, white, xyToBit(0, 0), BB_DIR_R, 3)
	ix = ix * 3*3*3 + bb_get_pat_index(black, white, xyToBit(0, 1), BB_DIR_R, 3)
	lst.push_back(ix * 3*3 + bb_get_pat_index(black, white, xyToBit(0, 2), BB_DIR_R, 2))
	ix = bb_get_pat_index(black, white, xyToBit(0, N_CELL_VERT-1), BB_DIR_R, 3)
	ix = ix * 3*3*3 + bb_get_pat_index(black, white, xyToBit(0, N_CELL_VERT-2), BB_DIR_R, 3)
	lst.push_back(ix * 3*3 + bb_get_pat_index(black, white, xyToBit(0, N_CELL_VERT-3), BB_DIR_R, 2))
	ix = bb_get_pat_index(black, white, xyToBit(N_CELL_HORZ-1, 0), BB_DIR_L, 3)
	ix = ix * 3*3*3 + bb_get_pat_index(black, white, xyToBit(N_CELL_HORZ-1, 1), BB_DIR_L, 3)
	lst.push_back(ix * 3*3 + bb_get_pat_index(black, white, xyToBit(N_CELL_HORZ-1, 2), BB_DIR_L, 2))
	ix = bb_get_pat_index(black, white, xyToBit(N_CELL_HORZ-1, N_CELL_VERT-1), BB_DIR_L, 3)
	ix = ix * 3*3*3 + bb_get_pat_index(black, white, xyToBit(N_CELL_HORZ-1, N_CELL_VERT-2), BB_DIR_L, 3)
	lst.push_back(ix * 3*3 + bb_get_pat_index(black, white, xyToBit(N_CELL_HORZ-1, N_CELL_VERT-3), BB_DIR_L, 2))
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
				cp_hist.push_back([BLACK, xyToBit(x, y)])
			else:
				bb_put_white(xyToBit(x, y))
				cp_hist.push_back([WHITE, xyToBit(x, y)])
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
					cp_hist.push_back([BLACK, bit])
					next_color = WHITE
				else:	#if next_color == WHITE:
					#if !canPutWhite(pos.x, pos.y): return
					#putWhite(pos.x, pos.y)
					if !bb_can_put_black(bb_white, bb_black, bit): return
					bb_put_white(bit)
					cp_hist.push_back([WHITE, bit])
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
	var lst8 = bb_get_pat8_indexes(black, white)
	var npb = min(8, count_n_legal_move_black(black, white))	# 黒着手可能箇所数
	var npw = min(8, count_n_legal_move_black(white, black))	# 白着手可能箇所数
	if g.rule == g.NORMAL:
		for i in range(lst.size()):
			ev += g_pat2_val[g_pat_type[i]][lst[i]]		# 直線パターン
		for i in range(lst8.size()):
			ev += g_pat8_val[lst8[i]]					# コーナー８パターン
		ev += g_npbw_val[npw][npb]
	else:
		for i in range(lst.size()):
			ev += g_pat2_val_LW[g_pat_type[i]][lst[i]]	# 直線パターン
		for i in range(lst8.size()):
			ev += g_pat8_val_LW[lst8[i]]					# コーナー８パターン
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
const g_pat8_val = [
  -0.098600, 3.422341, -3.227710, 1.011260, 2.098554, -1.765597, 0.443354, 2.608128, -0.589558,
  3.422341, 3.825492, 0.245750, 2.794768, 2.826441, 1.875781, 2.875208, 1.817934, 2.167161,
  -3.227710, 0.245750, -3.837905, -2.694815, -0.423224, -1.688610, -2.926029, -1.150900, -1.509011,
  0.408858, 2.747321, -0.173174, 0.801020, 1.772629, 0.940405, 2.127654, 1.706654, 2.812445,
  2.747321, 2.390398, 1.222332, 2.773159, 2.544954, 1.838954, 2.949630, 2.523321, 2.494782,
  -0.173174, 1.222332, -0.031816, -0.527762, -0.257806, 0.638488, 0.009942, 1.140594, 1.510853,
  -0.014656, 0.298789, -2.500225, -2.310915, -1.942953, -1.704259, -0.126155, -0.801691, -0.493775,
  0.298789, 0.328062, -0.527923, -0.988359, -1.681700, -1.132179, 0.686508, -0.060497, 0.434139,
  -2.500225, -0.527923, -2.485054, -1.721118, -2.179437, -2.052233, -2.685593, -1.185427, -2.193997,
  0.000000, -0.513645, 0.000000, -0.164243, -1.006632, -0.986844, 0.000000, -0.438889, -0.616221,
  0.000000, 1.094887, 0.000000, 2.038622, 0.420750, 1.001185, 0.000000, 0.942796, 2.082158,
  0.000000, -3.378731, -1.562130, -2.961890, -3.602565, -2.560067, 0.000000, -2.481797, -1.832355,
  0.000000, 0.533046, 0.000000, 0.078073, 0.209679, -0.756122, 0.000000, 1.207256, 0.928646,
  1.057977, 0.084108, 0.957136, 0.359441, 0.858290, -0.177475, 1.227129, 1.313781, 1.496769,
  0.000000, -2.357794, -0.755572, -1.027623, -1.434168, -2.178235, 0.000000, -0.337946, -0.493200,
  0.000000, -2.161789, 0.147396, -0.388800, -2.161673, -1.411912, 0.000000, -1.224850, -1.525509,
  0.000000, -0.018677, 3.065871, 0.458771, 0.861492, 0.239996, 0.000000, 0.544932, 0.530632,
  0.000000, -2.077887, 1.110264, -0.351937, -0.277380, -0.849561, 0.000000, -0.523929, -1.715290,
  0.000000, 0.000000, 1.004315, 0.000000, -0.456156, -0.881040, 0.302063, 1.749301, 1.161858,
  0.000000, 0.925395, 2.826664, 0.000000, 0.969174, 1.286832, 3.100475, 2.189573, 3.085332,
  0.000000, 0.000000, -1.502258, 0.000000, -2.362801, -2.141513, -2.529664, -1.515357, -0.352233,
  0.000000, 0.803506, 2.814722, 0.000000, 0.746585, 0.361408, 0.400065, 1.354049, 1.173624,
  0.000000, -1.465594, 2.201317, 0.000000, 0.965101, 1.390463, 0.152451, 0.378566, -0.058405,
  0.000000, -2.753025, -0.714024, 0.000000, -1.075520, -0.342179, -0.572914, -1.138438, -1.738087,
  0.000000, 0.000000, 0.552314, 0.000000, -2.138686, -2.066695, -0.163474, 0.223144, 0.184521,
  0.000000, 0.409099, 2.242696, 0.000000, -1.322513, -1.159729, 1.569573, 0.970488, 0.723107,
  -0.696510, -1.023471, 0.553152, -2.405476, -1.439548, -1.834907, -0.838699, -1.028526, -1.593917,
  1.011260, 2.794768, -2.694815, -0.019313, 1.728346, -0.876637, -0.092828, 1.487156, -1.009072,
  2.098554, 2.826441, -0.423224, 1.728346, 1.822851, 0.255477, 1.791245, 0.707869, 0.014195,
  -1.765597, 1.875781, -1.688610, -0.876637, 0.255477, -0.343871, -0.810821, 0.168821, -0.131051,
  0.801020, 2.773159, -0.527762, -0.206862, 2.093386, 1.122992, 1.529215, 1.883146, 2.318854,
  1.772629, 2.544954, -0.257806, 2.093386, 1.483366, 1.280950, 0.891297, 1.968459, 0.990138,
  0.940405, 1.838954, 0.638488, 1.122992, 1.280950, 1.023422, 0.612625, 0.858945, 1.182061,
  -2.310915, -0.988359, -1.721118, -0.096674, -0.623584, -1.591284, -1.162626, -0.755075, -0.068087,
  -1.942953, -1.681700, -2.179437, -0.623584, -1.376857, -1.004549, -1.747793, -0.877695, -0.904581,
  -1.704259, -1.132179, -2.052233, -1.591284, -1.004549, -0.655690, -1.426333, -0.206788, -0.090068,
  0.000000, -0.233354, 0.000000, 0.045346, -0.464708, -0.461157, 0.000000, -0.821603, -1.115647,
  0.000000, 0.187238, 1.232760, 0.567519, -0.707923, 0.310341, 0.000000, -0.629640, 0.546791,
  0.000000, -1.099323, -0.178083, -1.001424, -0.643745, -0.124695, 0.000000, -0.813542, 0.098050,
  0.000000, 1.175427, 0.000000, -0.251567, 1.099119, 1.592562, 0.000000, 1.210428, 1.292756,
  0.123071, 0.639923, 0.380093, -0.582593, 0.869144, 0.738928, -0.015102, 2.328809, 0.528185,
  0.000000, -1.185174, 0.350717, -0.018525, 0.123967, 0.121133, 0.000000, 0.312237, 0.097266,
  0.000000, -2.395684, -1.336986, 0.180724, -0.972448, -0.986180, 0.000000, -1.137307, -1.117232,
  0.000000, -2.135677, 0.691680, 0.482820, -0.606343, -0.386700, 0.000000, -0.415075, -1.938558,
  0.000000, -1.664926, 0.747185, 0.872421, -0.090586, -0.589020, 0.000000, -0.764777, -1.345771,
  0.000000, 0.000000, 1.140758, 0.000000, -0.303060, -0.573056, -0.660035, 1.970730, 0.360817,
  0.000000, 0.810488, 0.762597, 0.000000, -1.392154, -0.647567, 1.387456, 1.452161, 1.619544,
  0.000000, 0.000000, 0.311659, 0.000000, -1.229510, -0.433078, -0.949861, -0.088264, 1.331993,
  0.000000, 0.813705, 1.669053, 0.000000, 0.143300, 0.141093, -0.193303, 1.668046, 0.730514,
  0.000000, 0.179572, 1.707079, -1.689467, -1.021654, -1.235363, -0.366597, 0.244269, -1.111927,
  0.000000, -0.989632, 0.563098, -0.760468, -0.743013, -1.351145, -0.668017, -0.471572, -1.477666,
  0.000000, 0.000000, -0.306636, 0.000000, -0.397778, -1.270085, -0.150649, -0.288798, -0.003438,
  -1.163941, -1.512392, -0.545871, -0.123242, -1.871295, -2.783385, -1.252234, -1.290269, -1.833955,
  -1.361709, -1.601254, -0.207222, -2.454507, -1.765395, -2.962968, 0.290976, -0.702238, -1.414981,
  0.443354, 2.875208, -2.926029, -0.092828, 1.791245, -0.810821, 0.142686, 1.648836, -0.688985,
  2.608128, 1.817934, -1.150900, 1.487156, 0.707869, 0.168821, 1.648836, 0.420409, 0.164542,
  -0.589558, 2.167161, -1.509011, -1.009072, 0.014195, -0.131051, -0.688985, 0.164542, -0.463582,
  2.127654, 2.949630, 0.009942, 1.529215, 0.891297, 0.612625, 0.391095, 1.721095, 0.478869,
  1.706654, 2.523321, 1.140594, 1.883146, 1.968459, 0.858945, 1.721095, 0.466175, 1.577577,
  2.812445, 2.494782, 1.510853, 2.318854, 0.990138, 1.182061, 0.478869, 1.577577, 2.093906,
  -0.126155, 0.686508, -2.685593, -1.162626, -1.747793, -1.426333, -0.043640, -1.154865, -1.323246,
  -0.801691, -0.060497, -1.185427, -0.755075, -0.877695, -0.206788, -1.154865, -1.337524, -0.508351,
  -0.493775, 0.434139, -2.193997, -0.068087, -0.904581, -0.090068, -1.323246, -0.508351, -0.293542,
  0.000000, 0.315241, 0.000000, 0.486552, -1.058446, -1.183532, 0.000000, -0.341664, -0.159123,
  0.000000, 1.155114, 0.000000, -0.180612, -0.984528, -0.484593, 0.000000, -0.630645, 1.151788,
  0.000000, -0.711741, -0.549264, -1.278114, -1.623215, -0.326338, 0.000000, -0.268738, 0.547182,
  0.000000, 0.892466, 0.000000, 0.144427, -0.026621, 0.230520, 0.000000, -0.104263, 0.148768,
  0.971355, 0.459513, 1.341286, 0.023120, -0.155604, 0.429429, 0.143719, 0.674668, 0.547039,
  0.798973, 0.560752, 1.519247, 0.641043, 0.670892, -0.442051, 0.090762, 1.674899, 0.276010,
  0.000000, -1.821165, -1.394349, -0.198125, -1.699217, -1.750049, 0.000000, -1.208909, -1.840568,
  0.000000, -0.778589, 1.818257, 0.405635, 0.183917, -0.658316, -0.082629, -0.263630, -0.890693,
  0.000000, -0.618942, 0.805232, 1.566276, 0.624729, -0.778091, 0.108178, -0.309158, -0.367083,
  0.000000, 0.000000, 0.853499, 0.000000, -0.026244, 0.255915, 0.460172, 1.549801, 1.292573,
  0.000000, 1.248334, 1.428696, 0.000000, 0.294049, -0.248130, 0.753114, 1.022393, 1.250021,
  0.000000, -1.537010, 0.055034, 0.000000, -1.546976, 0.040314, -1.289132, -0.103977, 1.450409,
  0.000000, 1.146371, 2.231706, 0.000000, 0.336498, -0.108523, -0.235151, 0.806866, 0.528169,
  0.000000, -0.985275, 1.550769, 0.000000, -0.393104, -1.281399, -0.738334, 0.140780, -1.605399,
  0.000000, -1.542316, 1.333788, 0.000000, 0.809168, -0.494282, -0.490332, 0.029985, -1.416552,
  0.000000, 0.000000, -0.333002, 0.000000, -1.328723, -2.704075, -0.287783, -2.415695, -2.276143,
  0.000000, -0.958601, 1.343916, 0.000000, -1.740218, -2.801769, 0.117232, -2.255506, -2.077948,
  0.692687, -0.534858, 0.737093, -1.125525, -1.249110, -2.727118, -0.418257, -1.336106, -1.479390,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.513645, 1.094887, -3.378731, -0.233354, 0.187238, -1.099323, 0.315241, 1.155114, -0.711741,
  0.000000, 0.000000, -1.562130, 0.000000, 1.232760, -0.178083, 0.000000, 0.000000, -0.549264,
  0.000000, 1.057977, 0.000000, 0.000000, 0.123071, 0.000000, 0.000000, 0.971355, 0.798973,
  0.533046, 0.084108, -2.357794, 1.175427, 0.639923, -1.185174, 0.892466, 0.459513, 0.560752,
  0.000000, 0.957136, -0.755572, 0.000000, 0.380093, 0.350717, 0.000000, 1.341286, 1.519247,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -2.161789, -0.018677, -2.077887, -2.395684, -2.135677, -1.664926, -1.821165, -0.778589, -0.618942,
  0.147396, 3.065871, 1.110264, -1.336986, 0.691680, 0.747185, -1.394349, 1.818257, 0.805232,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -1.132669, -1.557774, -0.789355, -0.801017, -1.956708, 0.000000, -0.629860, -0.412412,
  0.000000, -1.557774, -0.418748, 0.000000, -1.410514, -1.326227, 0.000000, -1.451479, -1.550120,
  0.000000, -2.562365, 0.000000, 0.000000, -2.557444, -2.217021, 0.000000, -1.393952, -1.647325,
  -2.562365, -2.989223, -3.794139, -2.209498, -3.054285, -4.731211, -2.020348, -1.534618, -3.427940,
  0.000000, -3.794139, -1.810500, 0.000000, -2.493285, -4.333196, 0.000000, -0.590194, -2.162896,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -0.432291, 1.211715, -0.582476, 0.523708, -0.599000, 0.000000, -0.475993, -1.391241,
  0.000000, 1.211715, 4.859937, -0.562876, 4.379444, 2.249390, 0.000000, 0.282166, -0.255258,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -1.395906, 0.678743, 0.000000, 2.130647, 2.056920, 0.890969, 1.602777, 1.713935,
  0.000000, 0.000000, 1.765432, 0.000000, 1.201541, 1.786522, 0.000000, 0.176508, 1.927477,
  0.000000, -1.292747, 0.591060, 0.000000, 2.598124, 2.675634, 0.000000, -0.042750, -1.586853,
  0.000000, -4.020979, -0.178668, 0.000000, 1.848058, 2.160229, -0.307199, -0.682232, -2.879989,
  0.000000, -3.734612, 1.763524, 0.000000, 3.583494, 1.826620, 0.000000, -0.633024, -2.141624,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.262001, -1.816620, 0.878476, -0.668550, -0.184670, -1.026934, 0.063097, 1.099926, 0.480221,
  1.860868, 3.196260, 4.099146, 0.246692, 3.218480, 1.539381, 1.248482, 3.948771, 2.139925,
  -0.164243, 2.038622, -2.961890, 0.045346, 0.567519, -1.001424, 0.486552, -0.180612, -1.278114,
  -1.006632, 0.420750, -3.602565, -0.464708, -0.707923, -0.643745, -1.058446, -0.984528, -1.623215,
  -0.986844, 1.001185, -2.560067, -0.461157, 0.310341, -0.124695, -1.183532, -0.484593, -0.326338,
  0.078073, 0.359441, -1.027623, -0.251567, -0.582593, -0.018525, 0.144427, 0.023120, 0.641043,
  0.209679, 0.858290, -1.434168, 1.099119, 0.869144, 0.123967, -0.026621, -0.155604, 0.670892,
  -0.756122, -0.177475, -2.178235, 1.592562, 0.738928, 0.121133, 0.230520, 0.429429, -0.442051,
  -0.388800, 0.458771, -0.351937, 0.180724, 0.482820, 0.872421, -0.198125, 0.405635, 1.566276,
  -2.161673, 0.861492, -0.277380, -0.972448, -0.606343, -0.090586, -1.699217, 0.183917, 0.624729,
  -1.411912, 0.239996, -0.849561, -0.986180, -0.386700, -0.589020, -1.750049, -0.658316, -0.778091,
  0.000000, -0.789355, 0.000000, 0.008911, -1.152792, -1.368804, 0.000000, -1.212657, -1.205986,
  0.000000, -0.801017, -1.410514, -1.152792, -2.567961, -1.821551, 0.000000, -2.767542, -1.304052,
  0.000000, -1.956708, -1.326227, -1.368804, -1.821551, -1.212405, 0.000000, -1.603663, -1.615794,
  0.000000, -2.209498, 0.000000, -0.047584, -3.097049, -1.407198, 0.000000, -3.182622, -1.789547,
  -2.557444, -3.054285, -2.493285, -3.097049, -3.675264, -5.269513, -3.285156, -2.921478, -3.811143,
  -2.217021, -4.731211, -4.333196, -1.407198, -5.269513, -5.866199, -0.841151, -4.272905, -4.795708,
  0.000000, -0.582476, -0.562876, 0.140130, 1.509895, 1.222191, 0.000000, 0.033459, -0.435938,
  0.000000, 0.523708, 4.379444, 1.509895, 5.998461, 3.646970, 0.606740, 2.498495, 2.637120,
  0.000000, -0.599000, 2.249390, 1.222191, 3.646970, 1.709000, 0.344587, 0.570251, 1.308097,
  0.000000, 0.000000, 0.584816, 0.000000, 1.370214, 1.404603, 0.067118, 0.337568, 1.324803,
  0.000000, -0.885034, -1.293695, 0.000000, 0.908199, 2.195619, -0.283913, 0.220337, 0.557865,
  0.000000, -0.203506, -0.892010, 0.000000, 1.397605, 2.747916, -0.793832, 0.901829, 1.428121,
  0.000000, -1.483759, -0.111734, 0.000000, 2.909658, 2.977035, -0.109921, -0.966320, -0.053627,
  0.000000, -3.519316, -1.761470, 3.320570, 6.491739, 5.253070, -2.595651, -1.072147, -1.805096,
  0.000000, -6.080194, -2.650684, 4.165843, 4.054376, 3.069342, -1.955049, -3.964789, -5.718202,
  0.000000, 0.000000, 1.251774, 0.000000, 0.127637, 0.624885, 0.166017, 1.345177, 2.560684,
  0.834997, 2.344148, 3.659095, 0.855398, 5.223919, 3.787189, 0.962874, 6.580198, 3.415985,
  1.153448, 0.982183, 1.861393, 1.079181, 1.952722, 2.679939, 1.688181, 4.254628, 2.482642,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.438889, 0.942796, -2.481797, -0.821603, -0.629640, -0.813542, -0.341664, -0.630645, -0.268738,
  -0.616221, 2.082158, -1.832355, -1.115647, 0.546791, 0.098050, -0.159123, 1.151788, 0.547182,
  0.000000, 1.227129, 0.000000, 0.000000, -0.015102, 0.000000, 0.000000, 0.143719, 0.090762,
  1.207256, 1.313781, -0.337946, 1.210428, 2.328809, 0.312237, -0.104263, 0.674668, 1.674899,
  0.928646, 1.496769, -0.493200, 1.292756, 0.528185, 0.097266, 0.148768, 0.547039, 0.276010,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.082629, 0.108178,
  -1.224850, 0.544932, -0.523929, -1.137307, -0.415075, -0.764777, -1.208909, -0.263630, -0.309158,
  -1.525509, 0.530632, -1.715290, -1.117232, -1.938558, -1.345771, -1.840568, -0.890693, -0.367083,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -0.629860, -1.451479, -1.212657, -2.767542, -1.603663, 0.000000, -0.885020, -0.559910,
  0.000000, -0.412412, -1.550120, -1.205986, -1.304052, -1.615794, 0.000000, -0.559910, 0.091161,
  0.000000, -2.020348, 0.000000, 0.000000, -3.285156, -0.841151, 0.000000, -1.696219, -0.252936,
  -1.393952, -1.534618, -0.590194, -3.182622, -2.921478, -4.272905, -1.696219, -1.587976, -1.677039,
  -1.647325, -3.427940, -2.162896, -1.789547, -3.811143, -4.795708, -0.252936, -1.677039, -3.837114,
  0.000000, 0.000000, 0.000000, 0.000000, 0.606740, 0.344587, 0.000000, 0.001937, -0.274620,
  0.000000, -0.475993, 0.282166, 0.033459, 2.498495, 0.570251, 0.001937, 1.971862, 1.789953,
  0.000000, -1.391241, -0.255258, -0.435938, 2.637120, 1.308097, -0.274620, 1.789953, 0.825560,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -1.887183, -2.647685, 0.000000, -0.274335, 0.920473, -0.714630, -1.565144, -1.248773,
  0.000000, -2.057313, -2.374308, 0.000000, 1.273779, 2.696955, -1.046324, -0.338359, -0.434853,
  0.000000, -0.767998, -0.134803, 0.000000, 2.025462, 1.764278, 0.000000, -0.428548, -0.129943,
  0.000000, -3.200802, -1.178261, 0.000000, 5.254165, 3.582602, -0.870989, -1.515324, -2.943017,
  0.000000, -4.490258, -1.729076, 0.000000, 3.696121, 2.327931, -0.346248, -2.916957, -5.401360,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.102848, -0.913289,
  -0.331236, -0.516269, 0.032708, -0.311083, 1.279703, 1.470962, -1.074660, 3.657800, 1.635256,
  -1.143519, -1.251291, -1.484124, -0.501565, 1.517624, 1.554148, -0.735251, 2.652297, 1.052076,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.925395, 0.000000, 0.000000, 0.810488, 0.000000, 0.000000, 1.248334, -1.537010,
  1.004315, 2.826664, -1.502258, 1.140758, 0.762597, 0.311659, 0.853499, 1.428696, 0.055034,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.803506, -1.465594, -2.753025, 0.813705, 0.179572, -0.989632, 1.146371, -0.985275, -1.542316,
  2.814722, 2.201317, -0.714024, 1.669053, 1.707079, 0.563098, 2.231706, 1.550769, 1.333788,
  0.000000, 0.000000, -0.696510, 0.000000, -1.163941, -1.361709, 0.000000, 0.000000, 0.692687,
  0.000000, 0.409099, -1.023471, 0.000000, -1.512392, -1.601254, 0.000000, -0.958601, -0.534858,
  0.552314, 2.242696, 0.553152, -0.306636, -0.545871, -0.207222, -0.333002, 1.343916, 0.737093,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -1.395906, 0.000000, 0.000000, -0.885034, -0.203506, 0.000000, -1.887183, -2.057313,
  0.000000, 0.678743, 1.765432, 0.584816, -1.293695, -0.892010, 0.000000, -2.647685, -2.374308,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -1.292747, -4.020979, -3.734612, -1.483759, -3.519316, -6.080194, -0.767998, -3.200802, -4.490258,
  0.591060, -0.178668, 1.763524, -0.111734, -1.761470, -2.650684, -0.134803, -1.178261, -1.729076,
  0.000000, 0.262001, 1.860868, 0.000000, 0.834997, 1.153448, 0.000000, -0.331236, -1.143519,
  0.000000, -1.816620, 3.196260, 0.000000, 2.344148, 0.982183, 0.000000, -0.516269, -1.251291,
  0.000000, 0.878476, 4.099146, 1.251774, 3.659095, 1.861393, 0.000000, 0.032708, -1.484124,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.218117, 1.281684, 0.000000, 0.288090, 0.215158, 0.000000, 1.576751, 2.173122,
  0.000000, 1.281684, 1.051010, 0.000000, -1.315626, -0.807810, 1.252079, 0.900554, 1.302861,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -4.285180, -1.193799, 0.000000, 0.042680, 0.406522, 0.058622, -1.207101, -3.296034,
  0.000000, -1.193799, 0.287429, 0.000000, 1.897221, 0.364645, 0.556106, 0.711219, -0.695559,
  0.000000, 0.000000, 3.417882, 0.000000, 1.354178, -0.115569, 0.000000, 2.313698, 1.392267,
  0.000000, 0.765612, 3.439167, 0.000000, 0.266547, -0.817812, 0.000000, 3.412379, 0.702382,
  3.417882, 3.439167, 3.329802, 0.462062, 1.517732, 0.995949, 2.356152, 4.255843, 1.952498,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.456156, 0.969174, -2.362801, -0.303060, -1.392154, -1.229510, -0.026244, 0.294049, -1.546976,
  -0.881040, 1.286832, -2.141513, -0.573056, -0.647567, -0.433078, 0.255915, -0.248130, 0.040314,
  0.000000, 0.000000, 0.000000, 0.000000, -1.689467, -0.760468, 0.000000, 0.000000, 0.000000,
  0.746585, 0.965101, -1.075520, 0.143300, -1.021654, -0.743013, 0.336498, -0.393104, 0.809168,
  0.361408, 1.390463, -0.342179, 0.141093, -1.235363, -1.351145, -0.108523, -1.281399, -0.494282,
  0.000000, 0.000000, -2.405476, 0.000000, -0.123242, -2.454507, 0.000000, 0.000000, -1.125525,
  -2.138686, -1.322513, -1.439548, -0.397778, -1.871295, -1.765395, -1.328723, -1.740218, -1.249110,
  -2.066695, -1.159729, -1.834907, -1.270085, -2.783385, -2.962968, -2.704075, -2.801769, -2.727118,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 2.130647, 1.201541, 1.370214, 0.908199, 1.397605, 0.000000, -0.274335, 1.273779,
  0.000000, 2.056920, 1.786522, 1.404603, 2.195619, 2.747916, 0.000000, 0.920473, 2.696955,
  0.000000, 0.000000, 0.000000, 0.000000, 3.320570, 4.165843, 0.000000, 0.000000, 0.000000,
  2.598124, 1.848058, 3.583494, 2.909658, 6.491739, 4.054376, 2.025462, 5.254165, 3.696121,
  2.675634, 2.160229, 1.826620, 2.977035, 5.253070, 3.069342, 1.764278, 3.582602, 2.327931,
  0.000000, -0.668550, 0.246692, 0.000000, 0.855398, 1.079181, 0.000000, -0.311083, -0.501565,
  0.000000, -0.184670, 3.218480, 0.127637, 5.223919, 1.952722, 0.000000, 1.279703, 1.517624,
  0.000000, -1.026934, 1.539381, 0.624885, 3.787189, 2.679939, 0.000000, 1.470962, 1.554148,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.288090, -1.315626, 0.000000, -1.980743, -2.051424, 1.309807, 0.100800, -0.264252,
  0.000000, 0.215158, -0.807810, 0.000000, -2.051424, -0.527198, -0.133130, -0.319394, 0.411328,
  0.000000, 0.000000, 0.000000, 0.000000, 0.024465, 0.885468, 0.000000, 0.487610, 0.284965,
  0.000000, 0.042680, 1.897221, 0.024465, 2.556537, 1.802882, 0.847262, 3.139166, 1.232618,
  0.000000, 0.406522, 0.364645, 0.885468, 1.802882, -0.064682, 1.347784, 3.690213, 0.759533,
  0.000000, 0.000000, 0.462062, 0.000000, 0.128440, 0.394367, 0.000000, 0.080699, -0.338516,
  1.354178, 0.266547, 1.517732, 0.128440, 1.842650, 0.703940, 0.155984, 3.314077, 1.274403,
  -0.115569, -0.817812, 0.995949, 0.394367, 0.703940, -0.590480, 0.812148, 2.531374, 0.467707,
  0.302063, 3.100475, -2.529664, -0.660035, 1.387456, -0.949861, 0.460172, 0.753114, -1.289132,
  1.749301, 2.189573, -1.515357, 1.970730, 1.452161, -0.088264, 1.549801, 1.022393, -0.103977,
  1.161858, 3.085332, -0.352233, 0.360817, 1.619544, 1.331993, 1.292573, 1.250021, 1.450409,
  0.400065, 0.152451, -0.572914, -0.193303, -0.366597, -0.668017, -0.235151, -0.738334, -0.490332,
  1.354049, 0.378566, -1.138438, 1.668046, 0.244269, -0.471572, 0.806866, 0.140780, 0.029985,
  1.173624, -0.058405, -1.738087, 0.730514, -1.111927, -1.477666, 0.528169, -1.605399, -1.416552,
  -0.163474, 1.569573, -0.838699, -0.150649, -1.252234, 0.290976, -0.287783, 0.117232, -0.418257,
  0.223144, 0.970488, -1.028526, -0.288798, -1.290269, -0.702238, -2.415695, -2.255506, -1.336106,
  0.184521, 0.723107, -1.593917, -0.003438, -1.833955, -1.414981, -2.276143, -2.077948, -1.479390,
  0.000000, 0.890969, 0.000000, 0.067118, -0.283913, -0.793832, 0.000000, -0.714630, -1.046324,
  0.000000, 1.602777, 0.176508, 0.337568, 0.220337, 0.901829, 0.000000, -1.565144, -0.338359,
  0.000000, 1.713935, 1.927477, 1.324803, 0.557865, 1.428121, 0.000000, -1.248773, -0.434853,
  0.000000, -0.307199, 0.000000, -0.109921, -2.595651, -1.955049, 0.000000, -0.870989, -0.346248,
  -0.042750, -0.682232, -0.633024, -0.966320, -1.072147, -3.964789, -0.428548, -1.515324, -2.916957,
  -1.586853, -2.879989, -2.141624, -0.053627, -1.805096, -5.718202, -0.129943, -2.943017, -5.401360,
  0.000000, 0.063097, 1.248482, 0.166017, 0.962874, 1.688181, 0.000000, -1.074660, -0.735251,
  0.000000, 1.099926, 3.948771, 1.345177, 6.580198, 4.254628, -0.102848, 3.657800, 2.652297,
  0.000000, 0.480221, 2.139925, 2.560684, 3.415985, 2.482642, -0.913289, 1.635256, 1.052076,
  0.000000, 0.000000, 1.252079, 0.000000, 1.309807, -0.133130, 0.093172, 1.243527, 1.341623,
  0.000000, 1.576751, 0.900554, 0.000000, 0.100800, -0.319394, 1.243527, 0.856317, 1.244508,
  0.000000, 2.173122, 1.302861, 0.000000, -0.264252, 0.411328, 1.341623, 1.244508, 1.934946,
  0.000000, 0.058622, 0.556106, 0.000000, 0.847262, 1.347784, 0.003343, -0.051676, 0.223905,
  0.000000, -1.207101, 0.711219, 0.487610, 3.139166, 3.690213, -0.051676, -0.017276, -1.474495,
  0.000000, -3.296034, -0.695559, 0.284965, 1.232618, 0.759533, 0.223905, -1.474495, -3.448520,
  0.000000, 0.000000, 2.356152, 0.000000, 0.155984, 0.812148, 0.086815, 1.318336, 1.412782,
  2.313698, 3.412379, 4.255843, 0.080699, 3.314077, 2.531374, 1.318336, 4.050592, 2.892035,
  1.392267, 0.702382, 1.952498, -0.338516, 1.274403, 0.467707, 1.412782, 2.892035, 1.545145,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.055290, 1.464322, -0.001039, -0.462050, -1.035462, 0.712234, 0.938553, 0.031702, 1.620224,
  1.464322, 2.153503, 1.262764, 0.547289, -0.245738, 2.602395, 1.451856, 0.623308, 1.699662,
  -0.001039, 1.262764, -0.494689, -1.711054, -1.202406, 0.804985, -1.078961, -0.245716, 0.562169,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.147431, 0.438479, 0.293635, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.330742, 0.975041, 2.781986, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.949168, -1.785603, -0.156449, 0.000000, 0.000000, 0.000000,
  0.000000, -0.789281, 0.614975, -0.495692, -0.052220, -1.034972, 0.000000, 0.444792, 0.902929,
  0.000000, 0.142921, 1.576282, 0.396861, 0.720858, 0.202623, 0.000000, 0.873423, 0.812447,
  0.000000, -1.567749, 0.584654, -1.257923, -1.136098, -1.642959, 0.000000, -0.227154, -0.883631,
  0.000000, 0.000000, 0.000000, -0.206401, 0.219174, -0.015102, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.002898, 0.110046, 0.061931, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.320581, 0.099178, -0.097418, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.236726, 0.241198, 0.000000, -0.177421, 0.069927, -0.054120, 1.105258, 0.584440,
  0.396252, 1.000678, 1.831078, 0.000000, 0.728413, 0.248641, -0.046101, 1.668794, 0.713286,
  -2.363608, -1.812695, -0.909448, -0.092044, 0.080047, -0.565490, -1.086803, -0.376289, -1.107906,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.844153, 0.655680, 0.000000, 0.500434, 0.017491, 0.000000, 0.368910, 0.341169,
  -1.301476, -0.467278, -0.501542, 0.313084, 0.958411, 0.880868, -0.157878, 0.891505, -0.403317,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.462050, 0.547289, -1.711054, -0.243035, -0.966078, -0.255614, -0.345021, -0.459654, 0.600097,
  -1.035462, -0.245738, -1.202406, -0.966078, -1.075284, 0.333028, -1.958391, -1.404395, -0.103527,
  0.712234, 2.602395, 0.804985, -0.255614, 0.333028, 1.894201, 0.744987, 0.657304, 1.681675,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.168967, -0.476309, 0.576048, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.027849, -0.099674, 0.872677, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.041272, 0.022194, 1.899601, 0.000000, 0.000000, 0.000000,
  0.000000, -1.190557, -0.192359, -0.232484, -1.984237, -2.111308, 0.000000, -1.465061, -2.350323,
  0.000000, -4.686894, -1.030348, -3.331307, -3.832668, -3.955678, 0.000000, -3.848697, -3.785319,
  0.000000, 0.159241, 1.971875, 0.581640, 1.300655, -0.465836, 0.000000, 0.263482, 0.052666,
  0.000000, 0.000000, 0.000000, -0.005670, 0.817288, 0.876773, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.164764, 3.732357, 1.651820, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.637023, 4.089785, 2.318525, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -0.122680, -0.447660, 0.000000, -0.557061, -1.333445, -0.244483, -0.860790, -2.400967,
  -4.034906, -4.173986, -2.067764, -0.723652, -2.153393, -3.323413, -2.941113, -3.542858, -4.184363,
  0.001036, 0.006135, 1.638982, 0.065501, -0.016423, -0.464866, 0.420926, 0.180612, -0.952928,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -2.293420, 1.011721, -0.666596, 0.000000, 1.365701, 0.192570, -1.284652, 2.848638, -0.750730,
  1.770143, 2.263449, 2.916594, 0.937872, 3.530901, 3.547339, 1.892253, 4.607834, 3.611816,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.938553, 1.451856, -1.078961, -0.345021, -1.958391, 0.744987, 0.668462, -0.509954, 0.076630,
  0.031702, 0.623308, -0.245716, -0.459654, -1.404395, 0.657304, -0.509954, -1.560913, -0.212367,
  1.620224, 1.699662, 0.562169, 0.600097, -0.103527, 1.681675, 0.076630, -0.212367, 1.597555,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 1.725898, 0.144850, 0.353269,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.144850, -1.896355, -1.039986,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.353269, -1.039986, 1.209824,
  0.000000, 0.000000, 0.000000, -0.025214, 0.804759, 1.118802, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.016280, -0.872710, 0.853025, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.067394, -0.367451, 1.282020, 0.000000, 0.000000, 0.000000,
  0.000000, 0.256878, 0.187592, 0.060946, -0.258941, -0.771567, 0.000000, -0.263601, -0.196904,
  0.000000, -0.873899, 0.559861, -1.067844, -0.543329, -2.165768, -0.900176, -0.478152, -1.170512,
  0.000000, 0.673726, 1.495030, 0.589424, 1.945300, 0.702797, 0.563789, 1.098895, 0.411299,
  0.000000, 0.000000, 0.000000, 0.257023, 1.017611, 0.431371, 0.000000, 0.125200, 0.108315,
  0.000000, 0.000000, 0.000000, 0.002920, 3.007723, 0.627457, 0.000000, 2.344822, 0.798654,
  0.000000, 0.000000, 0.000000, 1.890790, 2.841360, 2.509404, 0.000000, 2.029913, 1.734583,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.192844, -0.585988, 0.000000, -0.042804, -2.206206, 0.207749, -0.682430, -0.914122,
  -0.739179, -1.397168, -0.256076, 0.000000, -0.213259, -1.498355, -0.676538, -1.017417, -2.189386,
  0.180387, 0.519189, 1.202917, 0.020470, 0.817135, -0.143912, 0.033964, 1.188976, 0.078279,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.172590, 1.294611, 0.945734,
  0.000000, 0.620615, 0.309300, 0.000000, 0.454362, 0.464759, 0.408139, 2.395970, 0.917880,
  1.942318, 3.236793, 3.202256, 2.112052, 3.457039, 4.010445, 1.979100, 4.072384, 2.445867,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.789281, 0.142921, -1.567749, -1.190557, -4.686894, 0.159241, 0.256878, -0.873899, 0.673726,
  0.614975, 1.576282, 0.584654, -0.192359, -1.030348, 1.971875, 0.187592, 0.559861, 1.495030,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.126497, 1.320532, 3.062808, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.505328, 1.332459, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.914394, 0.694764, 0.000000, 0.000000, 0.000000,
  0.000000, -1.421708, 1.118816, 0.819301, 1.392991, -0.113603, 0.000000, 0.202973, -0.643848,
  0.000000, 1.118816, 2.695821, 1.419686, 4.213148, 1.137570, 0.000000, 1.514898, 0.726604,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 1.171309, 2.240279, 0.788522, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 1.620091, 3.164711, 0.949862, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.772143, 0.001017, 1.213586, 0.020287, 0.085897, 0.331701, -0.032823, -0.336368, -1.417258,
  1.842082, 3.236329, 2.722244, 0.000000, 1.451493, 0.024154, 0.307709, 3.189491, 0.727395,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.319047, -0.769909, -0.185968, 0.322201, 0.387266, 0.200092, -0.106026, -0.424992, -1.709780,
  1.029278, 1.516758, 2.164140, 0.975303, 1.440551, 0.722866, -0.331492, 1.473315, -0.735735,
  0.147431, 0.330742, -0.949168, -0.168967, 0.027849, -0.041272, -0.025214, -0.016280, -0.067394,
  0.438479, 0.975041, -1.785603, -0.476309, -0.099674, 0.022194, 0.804759, -0.872710, -0.367451,
  0.293635, 2.781986, -0.156449, 0.576048, 0.872677, 1.899601, 1.118802, 0.853025, 1.282020,
  -0.495692, 0.396861, -1.257923, -0.232484, -3.331307, 0.581640, 0.060946, -1.067844, 0.589424,
  -0.052220, 0.720858, -1.136098, -1.984237, -3.832668, 1.300655, -0.258941, -0.543329, 1.945300,
  -1.034972, 0.202623, -1.642959, -2.111308, -3.955678, -0.465836, -0.771567, -2.165768, 0.702797,
  -0.206401, 0.002898, -0.320581, -0.005670, -0.164764, 0.637023, 0.257023, 0.002920, 1.890790,
  0.219174, 0.110046, 0.099178, 0.817288, 3.732357, 4.089785, 1.017611, 3.007723, 2.841360,
  -0.015102, 0.061931, -0.097418, 0.876773, 1.651820, 2.318525, 0.431371, 0.627457, 2.509404,
  0.000000, 0.126497, 0.000000, 0.010406, 0.499922, 0.560047, 0.000000, 0.181904, 0.060185,
  0.000000, 1.320532, 0.505328, 0.499922, -1.141270, 1.296428, 0.000000, -0.888625, 2.015571,
  0.000000, 3.062808, 1.332459, 0.560047, 1.296428, 3.019534, 0.000000, 1.451977, 2.662881,
  0.000000, 0.819301, 1.419686, 0.055054, 2.283025, 2.579266, 0.000000, 2.056576, 2.311103,
  0.914394, 1.392991, 4.213148, 2.283025, 4.188274, 2.345490, 1.840880, 4.092578, 3.028320,
  0.694764, -0.113603, 1.137570, 2.579266, 2.345490, 0.805949, 2.009155, 2.300407, 1.481403,
  0.000000, 1.171309, 1.620091, 0.038353, 0.924401, 1.543317, 0.000000, -0.302189, -0.268055,
  0.000000, 2.240279, 3.164711, 0.924401, -1.916066, -2.430641, -0.012034, -1.573802, -2.400015,
  0.000000, 0.788522, 0.949862, 1.543317, -2.430641, -3.215677, 0.035455, -2.161929, -2.967281,
  0.000000, 0.000000, 0.255715, 0.000000, 0.000000, 0.112935, -0.046658, 0.195820, -0.007163,
  0.000000, -0.479460, -0.606853, 0.000000, -1.087862, -0.198085, 0.580778, -1.219644, 1.337246,
  0.000000, -0.157130, 0.598691, 0.000000, 0.093499, 1.778686, 0.447530, 0.436282, 2.273714,
  0.000000, 0.452622, 1.602667, 0.000000, -0.765629, -0.797955, 0.062159, 0.336099, -0.082731,
  0.443200, 2.766941, 3.509154, -0.122343, 2.380447, 0.747396, 0.880950, 3.533778, 1.407925,
  1.115661, 2.121142, 0.950292, 0.267569, 0.827725, 0.681162, 1.618183, 2.407319, 0.918877,
  0.000000, 0.000000, 1.291245, 0.000000, 0.000000, -0.198497, 0.072940, -0.324196, -2.162109,
  0.852950, 2.566624, 2.829099, 0.036885, -2.094117, -2.628983, -0.000247, -1.382291, -2.303486,
  0.380230, 0.377859, 0.530419, 0.285603, -4.306049, -3.875200, 0.468127, -2.852086, -3.649911,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.900176, 0.563789,
  0.444792, 0.873423, -0.227154, -1.465061, -3.848697, 0.263482, -0.263601, -0.478152, 1.098895,
  0.902929, 0.812447, -0.883631, -2.350323, -3.785319, 0.052666, -0.196904, -1.170512, 0.411299,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.125200, 2.344822, 2.029913,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.108315, 0.798654, 1.734583,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.181904, -0.888625, 1.451977, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.060185, 2.015571, 2.662881, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 1.840880, 2.009155, 0.000000, 1.161557, 0.791226,
  0.000000, 0.202973, 1.514898, 2.056576, 4.092578, 2.300407, 1.161557, 4.440617, 3.254545,
  0.000000, -0.643848, 0.726604, 2.311103, 3.028320, 1.481403, 0.791226, 3.254545, 1.520840,
  0.000000, 0.000000, 0.000000, 0.000000, -0.012034, 0.035455, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.302189, -1.573802, -2.161929, 0.000000, -0.244199, -1.477075,
  0.000000, 0.000000, 0.000000, -0.268055, -2.400015, -2.967281, 0.000000, -1.477075, -2.038682,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.441320, 0.337007,
  0.463820, 2.207600, 2.648118, 0.036775, 1.429152, 0.607661, 0.092339, 3.400693, 2.146917,
  0.563978, 1.248366, 1.103188, -0.045065, 0.966385, 0.521949, 0.352662, 3.288552, 1.369791,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.247491, 0.028450, -0.020857, -0.081038, 0.004642, -0.684880, 0.006844, -1.237992, -1.865979,
  0.007297, -1.352515, -1.555443, 0.433223, -1.851904, -3.575254, -0.597878, -2.203925, -2.880131,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.396252, -2.363608, 0.000000, -4.034906, 0.001036, 0.000000, -0.739179, 0.180387,
  0.236726, 1.000678, -1.812695, -0.122680, -4.173986, 0.006135, 0.192844, -1.397168, 0.519189,
  0.241198, 1.831078, -0.909448, -0.447660, -2.067764, 1.638982, -0.585988, -0.256076, 1.202917,
  0.000000, 0.000000, -1.301476, 0.000000, -2.293420, 1.770143, 0.000000, 0.000000, 1.942318,
  0.000000, 0.844153, -0.467278, 0.000000, 1.011721, 2.263449, 0.000000, 0.620615, 3.236793,
  0.000000, 0.655680, -0.501542, 0.000000, -0.666596, 2.916594, 0.000000, 0.309300, 3.202256,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, -0.479460, -0.157130, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.255715, -0.606853, 0.598691, 0.000000, 0.000000, 0.000000,
  0.000000, 0.772143, 1.842082, 0.000000, 0.443200, 1.115661, 0.000000, 0.463820, 0.563978,
  0.000000, 0.001017, 3.236329, 0.452622, 2.766941, 2.121142, 0.000000, 2.207600, 1.248366,
  0.000000, 1.213586, 2.722244, 1.602667, 3.509154, 0.950292, 0.000000, 2.648118, 1.103188,
  0.000000, 0.319047, 1.029278, 0.000000, 0.852950, 0.380230, 0.000000, -0.247491, 0.007297,
  0.000000, -0.769909, 1.516758, 0.000000, 2.566624, 0.377859, 0.000000, 0.028450, -1.352515,
  0.000000, -0.185968, 2.164140, 1.291245, 2.829099, 0.530419, 0.000000, -0.020857, -1.555443,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.548407, 0.458884, 0.000000, -0.262928, -1.220680, 0.000000, -0.045633, -0.686717,
  0.548407, -0.182456, 1.439303, 0.000000, 0.301801, -0.356709, -0.104785, 0.955013, -0.244230,
  0.458884, 1.439303, 2.383267, 0.019199, 0.494148, 0.140328, -0.788111, 1.817061, -0.016724,
  0.000000, 0.000000, 0.464373, 0.000000, 0.024494, -1.380860, 0.000000, -0.136803, -0.427671,
  0.000000, -0.551375, 1.022357, 0.000000, 0.309936, -0.441617, 0.000000, -0.580689, -0.904763,
  0.464373, 1.022357, 1.934810, 0.270211, 2.455342, 0.445938, 0.599001, 0.831031, -0.403659,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, -0.092044, 0.000000, -0.723652, 0.065501, 0.000000, 0.000000, 0.020470,
  -0.177421, 0.728413, 0.080047, -0.557061, -2.153393, -0.016423, -0.042804, -0.213259, 0.817135,
  0.069927, 0.248641, -0.565490, -1.333445, -3.323413, -0.464866, -2.206206, -1.498355, -0.143912,
  0.000000, 0.000000, 0.313084, 0.000000, 0.000000, 0.937872, 0.000000, 0.000000, 2.112052,
  0.000000, 0.500434, 0.958411, 0.000000, 1.365701, 3.530901, 0.000000, 0.454362, 3.457039,
  0.000000, 0.017491, 0.880868, 0.000000, 0.192570, 3.547339, 0.000000, 0.464759, 4.010445,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, -1.087862, 0.093499, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.112935, -0.198085, 1.778686, 0.000000, 0.000000, 0.000000,
  0.000000, 0.020287, 0.000000, 0.000000, -0.122343, 0.267569, 0.000000, 0.036775, -0.045065,
  0.000000, 0.085897, 1.451493, -0.765629, 2.380447, 0.827725, 0.000000, 1.429152, 0.966385,
  0.000000, 0.331701, 0.024154, -0.797955, 0.747396, 0.681162, 0.000000, 0.607661, 0.521949,
  0.000000, 0.322201, 0.975303, 0.000000, 0.036885, 0.285603, 0.000000, -0.081038, 0.433223,
  0.000000, 0.387266, 1.440551, 0.000000, -2.094117, -4.306049, 0.000000, 0.004642, -1.851904,
  0.000000, 0.200092, 0.722866, -0.198497, -2.628983, -3.875200, 0.000000, -0.684880, -3.575254,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.019199, 0.000000, 0.000000, -0.426965, 0.000000, 0.107957, -0.287056,
  -0.262928, 0.301801, 0.494148, 0.000000, -0.062323, -0.030523, -0.296025, 0.235847, 0.136706,
  -1.220680, -0.356709, 0.140328, -0.426965, -0.030523, -0.036654, -0.973248, -0.392943, 0.246903,
  0.000000, 0.000000, 0.270211, 0.000000, 0.000000, -0.802819, 0.000000, 0.000000, -1.351530,
  0.024494, 0.309936, 2.455342, 0.000000, -0.019382, -1.453754, 0.000000, -0.789127, -2.963976,
  -1.380860, -0.441617, 0.445938, -0.802819, -1.453754, -3.060374, -1.350940, -1.680495, -4.125339,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.054120, -0.046101, -1.086803, -0.244483, -2.941113, 0.420926, 0.207749, -0.676538, 0.033964,
  1.105258, 1.668794, -0.376289, -0.860790, -3.542858, 0.180612, -0.682430, -1.017417, 1.188976,
  0.584440, 0.713286, -1.107906, -2.400967, -4.184363, -0.952928, -0.914122, -2.189386, 0.078279,
  0.000000, 0.000000, -0.157878, 0.000000, -1.284652, 1.892253, 0.172590, 0.408139, 1.979100,
  0.000000, 0.368910, 0.891505, 0.000000, 2.848638, 4.607834, 1.294611, 2.395970, 4.072384,
  0.000000, 0.341169, -0.403317, 0.000000, -0.750730, 3.611816, 0.945734, 0.917880, 2.445867,
  0.000000, 0.000000, 0.000000, -0.046658, 0.580778, 0.447530, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.195820, -1.219644, 0.436282, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.007163, 1.337246, 2.273714, 0.000000, 0.000000, 0.000000,
  0.000000, -0.032823, 0.307709, 0.062159, 0.880950, 1.618183, 0.000000, 0.092339, 0.352662,
  0.000000, -0.336368, 3.189491, 0.336099, 3.533778, 2.407319, 0.441320, 3.400693, 3.288552,
  0.000000, -1.417258, 0.727395, -0.082731, 1.407925, 0.918877, 0.337007, 2.146917, 1.369791,
  0.000000, -0.106026, -0.331492, 0.072940, -0.000247, 0.468127, 0.000000, 0.006844, -0.597878,
  0.000000, -0.424992, 1.473315, -0.324196, -1.382291, -2.852086, 0.000000, -1.237992, -2.203925,
  0.000000, -1.709780, -0.735735, -2.162109, -2.303486, -3.649911, 0.000000, -1.865979, -2.880131,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -0.104785, -0.788111, 0.000000, -0.296025, -0.973248, -0.035440, 0.010427, -0.709026,
  -0.045633, 0.955013, 1.817061, 0.107957, 0.235847, -0.392943, 0.010427, 0.750299, 2.240521,
  -0.686717, -0.244230, -0.016724, -0.287056, 0.136706, 0.246903, -0.709026, 2.240521, 1.188859,
  0.000000, 0.000000, 0.599001, 0.000000, 0.000000, -1.350940, 0.000000, -0.270569, -1.933159,
  -0.136803, -0.580689, 0.831031, 0.000000, -0.789127, -1.680495, -0.270569, -0.254794, -2.206401,
  -0.427671, -0.904763, -0.403659, -1.351530, -2.963976, -4.125339, -1.933159, -2.206401, -2.803830,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.001618, 1.380162, -1.738453, -1.123743, -2.415737, -0.188038, 0.421987, -0.744547, 1.867357,
  1.380162, 0.321344, -0.741395, 1.015471, -0.151705, 0.869115, 1.002794, -0.799969, 1.173432,
  -1.738453, -0.741395, -2.917864, -0.679481, -2.314520, -0.325926, -0.742844, -2.463277, 0.010746,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.904057, 0.213082, 0.971259, 1.138090, 1.749340, 0.265643, 0.579422, 0.361908, 0.716915,
  0.000000, -0.785426, -0.797221, 0.000000, -0.661798, -1.119697, 0.000000, 0.002197, -0.850640,
  0.000000, -0.508266, -0.143207, 0.077258, -1.396357, -0.535454, 0.000000, 0.620708, 0.077459,
  0.822689, 0.010264, 1.163158, 1.035187, 0.071338, 0.285704, 0.136531, -0.120061, 0.013080,
  -0.969978, -1.681131, -1.396768, -0.619017, -1.380551, -1.934802, -0.031018, -1.299835, -1.903979,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.165629, -0.438086, -0.150376,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.200032, 0.378121, 2.026988,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.829246, -3.036713, -0.368900,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.078618, -0.013840, -0.031743,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.513704, -0.055222, -0.072812,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.022824, -1.135951, -1.914839,
  0.000000, -0.688668, 0.584535, 0.000000, -0.234600, 0.362204, 0.306466, 1.199572, 1.550587,
  0.000000, -1.133983, 2.165090, 0.000000, 0.348030, 1.213312, 2.537290, 0.413515, 0.748076,
  0.000000, -1.537557, -0.466409, 0.000000, -0.738577, -1.439798, 0.042222, -0.020480, -0.992170,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -1.379812, -1.869218, -0.125327, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -1.869218, -1.059217, -0.690756, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.125327, -0.690756, 0.378044, 0.000000, 0.000000, 0.000000,
  -1.123743, 1.015471, -0.679481, 0.124469, 0.059275, 2.147671, -0.711386, -1.039370, 1.567788,
  -2.415737, -0.151705, -2.314520, 0.059275, -1.745635, -0.433491, -1.072934, -1.940816, -0.364088,
  -0.188038, 0.869115, -0.325926, 2.147671, -0.433491, 0.810881, 0.877581, -1.331370, 1.181465,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.114155, -1.280530, -1.374054, 0.000000, 0.000000, 0.000000,
  -2.644657, -3.472531, -3.375570, -2.824871, -3.356412, -3.430428, -1.489793, -3.278855, -2.780571,
  0.000000, -0.147719, -0.072859, -0.151918, 0.076734, -0.217466, 0.000000, -0.018078, 0.109794,
  0.000000, 0.533406, -0.114661, -0.001890, 1.991928, 1.303603, 0.000000, 1.591700, 0.053046,
  -0.870587, -0.085810, -1.699088, 0.257531, 0.884599, 0.344377, 0.045982, 0.302344, -0.428500,
  0.926945, 0.937256, 0.638296, 0.545118, 2.757307, 2.422734, 0.000000, 0.963818, 0.245225,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.001530, -1.467293, -0.858397,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.048725, -1.866968, -0.564669,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.166666, -1.775878, 0.196098,
  0.000000, 0.000000, 0.000000, 0.000000, -0.470832, -1.294350, 0.060069, -0.967278, -1.273521,
  0.000000, 0.000000, 0.000000, 0.000000, -2.576157, -2.720976, -1.789706, -3.294387, -3.722444,
  0.000000, 0.000000, 0.000000, 0.000000, -0.926970, -1.297431, 0.147323, -1.153012, -0.956577,
  0.000000, -0.018530, -0.266998, 0.000000, 0.710833, 0.937289, 0.437729, 1.101867, 1.180165,
  0.000000, -0.568398, -0.790503, -0.381275, 1.013731, 0.035309, -0.021450, 1.818648, -1.174493,
  0.000000, 0.597192, 1.591909, 1.151953, 3.038342, 1.499944, 2.372649, 3.367498, 3.025873,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.421987, 1.002794, -0.742844, -0.711386, -1.072934, 0.877581, -0.039240, -0.754464, 1.819452,
  -0.744547, -0.799969, -2.463277, -1.039370, -1.940816, -1.331370, -0.754464, -3.395693, -1.661435,
  1.867357, 1.173432, 0.010746, 1.567788, -0.364088, 1.181465, 1.819452, -1.661435, 1.156722,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -1.758824, -1.848800, -2.135505, -1.739651, -2.485976, -2.447545, 0.013818, -2.631043, -1.647305,
  1.360455, 0.896623, -0.369801, 0.806187, 1.666553, -1.764872, 0.101224, 0.077474, 0.071433,
  0.000000, 0.107447, 0.009032, 0.020512, 1.025119, 1.504599, 0.000000, 1.164848, -0.079552,
  -0.420151, -0.333531, -0.125288, 0.140926, 1.640699, 1.186319, 0.127541, 1.178708, 0.018329,
  2.935225, 2.266171, 3.722813, 2.473113, 2.897238, 2.945012, 0.997452, 3.394907, 2.277744,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.189116, -1.422114, -0.058009,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.030687, -2.792095, -0.775562,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.007833, -2.085820, 0.441772,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.084054, -1.630836, -1.099953,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.652397, -2.936397, -3.728671,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.645645, -0.028514, -2.151309,
  0.000000, -0.297428, 2.150083, 0.000000, 0.724755, 1.704629, 0.043203, 1.049140, 1.320564,
  0.000000, -0.997468, 0.622583, 0.000000, 1.490597, 0.646188, 1.324897, 1.954052, -1.187017,
  0.000000, 1.151796, 4.044014, 0.000000, 3.809704, 3.995768, 2.845391, 3.778584, 3.307770,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.904057, 0.000000, 0.000000, -2.644657, 0.000000, 0.000000, -1.758824, 1.360455,
  0.000000, 0.213082, -0.785426, 0.000000, -3.472531, -0.147719, 0.000000, -1.848800, 0.896623,
  0.000000, 0.971259, -0.797221, 0.000000, -3.375570, -0.072859, 0.000000, -2.135505, -0.369801,
  0.000000, 0.822689, -0.969978, 0.000000, -0.870587, 0.926945, 0.000000, -0.420151, 2.935225,
  -0.508266, 0.010264, -1.681131, 0.533406, -0.085810, 0.937256, 0.107447, -0.333531, 2.266171,
  -0.143207, 1.163158, -1.396768, -0.114661, -1.699088, 0.638296, 0.009032, -0.125288, 3.722813,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -0.626734, 0.000000, 0.000000, 1.963554, -0.049742, 0.000000, 0.592085, -0.012613,
  -0.626734, -1.046561, -0.492535, -0.151012, 1.290710, -0.221937, 0.171387, 0.468613, -0.201137,
  0.000000, -0.492535, 1.684690, 0.000000, 2.735959, 1.517097, 0.000000, 1.318062, 1.119833,
  0.000000, -1.676521, -0.350437, 0.000000, 1.365985, 0.029355, 0.000000, 0.302654, 0.423261,
  -1.676521, -3.493957, -2.339775, 1.131230, 1.359384, 0.009476, 0.072376, -0.562522, -0.286470,
  -0.350437, -2.339775, -0.694281, -0.001924, -0.097496, -1.264289, 0.005497, -0.379702, -1.072768,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.056529, -0.385429, -0.123751,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.609283, -0.106339,
  0.000000, -1.105340, -1.529876, 0.000000, 0.201992, -1.049391, 0.000000, -0.513046, -1.352678,
  0.000000, -1.996616, -0.439426, 0.000000, 0.859632, 0.087430, -0.325580, -0.236782, -2.096348,
  0.000000, -1.073272, 1.553163, 0.000000, 0.628380, 0.260516, 0.000000, -0.021902, 0.584248,
  0.000000, -1.447231, -0.922244, 0.000000, -0.960493, -0.716272, 0.000000, -1.875402, -1.469148,
  0.000000, -3.051755, -1.441017, 0.000000, 0.702953, -0.100647, -0.921213, -1.980288, -3.182573,
  0.000000, -2.718716, 0.044991, 0.000000, -0.239449, -1.403267, -0.277363, -1.843987, -2.680461,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 1.138090, 0.000000, -0.114155, -2.824871, -0.151918, 0.000000, -1.739651, 0.806187,
  0.000000, 1.749340, -0.661798, -1.280530, -3.356412, 0.076734, 0.000000, -2.485976, 1.666553,
  0.000000, 0.265643, -1.119697, -1.374054, -3.430428, -0.217466, 0.000000, -2.447545, -1.764872,
  0.077258, 1.035187, -0.619017, -0.001890, 0.257531, 0.545118, 0.020512, 0.140926, 2.473113,
  -1.396357, 0.071338, -1.380551, 1.991928, 0.884599, 2.757307, 1.025119, 1.640699, 2.897238,
  -0.535454, 0.285704, -1.934802, 1.303603, 0.344377, 2.422734, 1.504599, 1.186319, 2.945012,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -0.151012, 0.000000, 0.000000, 3.166643, 0.967197, 0.000000, 0.939039, 0.049007,
  1.963554, 1.290710, 2.735959, 3.166643, 3.069361, 1.842780, 0.937418, 4.396392, 3.141486,
  -0.049742, -0.221937, 1.517097, 0.967197, 1.842780, -0.002361, 0.000000, 0.490865, 0.515616,
  0.000000, 1.131230, -0.001924, 0.049160, -0.350234, 0.293047, 0.000000, 0.353687, 0.222006,
  1.365985, 1.359384, -0.097496, -0.350234, -3.653608, -3.590255, 0.025946, -0.934404, -0.662478,
  0.029355, 0.009476, -1.264289, 0.293047, -3.590255, -1.407328, 0.064613, -1.155588, -0.851184,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.011687, -0.659817, -0.471330,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.240575, -1.725096, 0.038438,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.098083, 0.011906, 1.818591,
  0.000000, -0.436696, -0.346387, 0.000000, -0.392344, 0.000970, -0.045188, -0.081404, -0.538446,
  0.000000, 0.245078, 0.451764, 0.000000, 1.533766, 0.572990, 1.316020, 1.851628, 0.947486,
  0.000000, -0.532478, 0.536884, 0.000000, 1.521586, 0.040109, 0.457084, 1.513759, 0.541107,
  0.000000, -0.566726, -0.463407, 0.000000, -0.489056, -0.006194, -0.019112, -1.590549, -0.431922,
  0.000000, -0.031540, 0.820468, 0.524529, -2.272220, -2.623660, 0.789392, -2.184320, -2.396518,
  0.000000, -1.380759, 0.474699, -0.368632, -3.506105, -3.446689, 0.406489, -3.483313, -3.726117,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.579422, 0.000000, 0.000000, -1.489793, 0.000000, 0.000000, 0.013818, 0.101224,
  0.000000, 0.361908, 0.002197, 0.000000, -3.278855, -0.018078, 0.000000, -2.631043, 0.077474,
  0.000000, 0.716915, -0.850640, 0.000000, -2.780571, 0.109794, 0.000000, -1.647305, 0.071433,
  0.000000, 0.136531, -0.031018, 0.000000, 0.045982, 0.000000, 0.000000, 0.127541, 0.997452,
  0.620708, -0.120061, -1.299835, 1.591700, 0.302344, 0.963818, 1.164848, 1.178708, 3.394907,
  0.077459, 0.013080, -1.903979, 0.053046, -0.428500, 0.245225, -0.079552, 0.018329, 2.277744,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.171387, 0.000000, 0.000000, 0.937418, 0.000000, 0.000000, 0.360652, 0.000000,
  0.592085, 0.468613, 1.318062, 0.939039, 4.396392, 0.490865, 0.360652, 2.849699, 1.078251,
  -0.012613, -0.201137, 1.119833, 0.049007, 3.141486, 0.515616, 0.000000, 1.078251, 0.129787,
  0.000000, 0.072376, 0.005497, 0.000000, 0.025946, 0.064613, 0.000000, -0.160270, -0.014041,
  0.302654, -0.562522, -0.379702, 0.353687, -0.934404, -1.155588, -0.160270, -0.053654, 0.091627,
  0.423261, -0.286470, -1.072768, 0.222006, -0.662478, -0.851184, -0.014041, 0.091627, -0.176857,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.048474, -1.055442, 0.515174,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.058882, 2.252558,
  0.000000, -0.035813, -0.246389, 0.000000, -0.438805, 0.201660, 0.000000, -0.563831, -0.152396,
  0.000000, -1.126572, -0.079292, 0.000000, 1.813593, 0.177815, 0.752600, 3.336167, 1.839143,
  0.000000, -0.584237, 0.022934, 0.000000, 0.625564, 0.156485, 0.000000, 2.904475, 1.445237,
  0.000000, -0.086323, -0.121078, 0.000000, -0.015092, 0.033946, 0.000000, -0.678764, -0.492295,
  0.000000, -0.203563, -0.151964, 0.000000, -0.250653, -0.198467, 0.768434, -2.324074, -1.716178,
  0.000000, -2.161113, -0.582001, 0.000000, -1.206067, -2.716375, 1.643602, -2.829237, -2.827418,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.688668, -1.133983, -1.537557, -0.018530, -0.568398, 0.597192, -0.297428, -0.997468, 1.151796,
  0.584535, 2.165090, -0.466409, -0.266998, -0.790503, 1.591909, 2.150083, 0.622583, 4.044014,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -1.105340, -1.996616, -1.073272, -0.436696, 0.245078, -0.532478, -0.035813, -1.126572, -0.584237,
  -1.529876, -0.439426, 1.553163, -0.346387, 0.451764, 0.536884, -0.246389, -0.079292, 0.022934,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -1.447231, -3.051755, -2.718716, -0.566726, -0.031540, -1.380759, -0.086323, -0.203563, -2.161113,
  -0.922244, -1.441017, 0.044991, -0.463407, 0.820468, 0.474699, -0.121078, -0.151964, -0.582001,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -2.362739, -0.865086,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.192418, -2.766175, -1.171327,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -1.728033, -1.717567, -3.305908,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -1.742863, -1.509797, -2.011198,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.979308, -0.605536,
  0.000000, -2.048664, -1.826469, 0.000000, -0.055778, -0.812747, -0.780863, -2.076228, -4.183270,
  0.000000, -1.826469, 0.928128, 0.000000, 1.018870, -0.423617, -0.731600, -0.428754, -0.267169,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.470832, -2.576157, -0.926970, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -1.294350, -2.720976, -1.297431, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, -0.381275, 1.151953, 0.000000, 0.000000, 0.000000,
  -0.234600, 0.348030, -0.738577, 0.710833, 1.013731, 3.038342, 0.724755, 1.490597, 3.809704,
  0.362204, 1.213312, -1.439798, 0.937289, 0.035309, 1.499944, 1.704629, 0.646188, 3.995768,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.201992, 0.859632, 0.628380, -0.392344, 1.533766, 1.521586, -0.438805, 1.813593, 0.625564,
  -1.049391, 0.087430, 0.260516, 0.000970, 0.572990, 0.040109, 0.201660, 0.177815, 0.156485,
  0.000000, 0.000000, 0.000000, 0.000000, 0.524529, -0.368632, 0.000000, 0.000000, 0.000000,
  -0.960493, 0.702953, -0.239449, -0.489056, -2.272220, -3.506105, -0.015092, -0.250653, -1.206067,
  -0.716272, -0.100647, -1.403267, -0.006194, -2.623660, -3.446689, 0.033946, -0.198467, -2.716375,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.040810, -2.173801, -0.976519,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.009378, -0.287421, 1.414083,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.044426, -0.214728,
  0.000000, 0.000000, 0.000000, 0.000000, 0.141656, -0.222833, -0.675118, 1.211470, 0.948140,
  0.000000, 0.000000, 0.000000, 0.000000, -0.222833, -0.030615, -0.128347, 0.985143, -0.039671,
  0.000000, 0.000000, 0.000000, 0.000000, -0.329929, -1.240470, 0.000000, -1.648360, -1.628161,
  0.000000, -0.055778, 1.018870, -0.329929, -1.806193, -2.718916, -1.875762, -2.040498, -2.944790,
  0.000000, -0.812747, -0.423617, -1.240470, -2.718916, -3.893013, -1.166031, -2.832485, -5.038836,
  -0.165629, 0.200032, -0.829246, -0.001530, -0.048725, -0.166666, -0.189116, -0.030687, 0.007833,
  -0.438086, 0.378121, -3.036713, -1.467293, -1.866968, -1.775878, -1.422114, -2.792095, -2.085820,
  -0.150376, 2.026988, -0.368900, -0.858397, -0.564669, 0.196098, -0.058009, -0.775562, 0.441772,
  0.078618, 0.513704, -0.022824, 0.060069, -1.789706, 0.147323, -0.084054, -0.652397, 0.645645,
  -0.013840, -0.055222, -1.135951, -0.967278, -3.294387, -1.153012, -1.630836, -2.936397, -0.028514,
  -0.031743, -0.072812, -1.914839, -1.273521, -3.722444, -0.956577, -1.099953, -3.728671, -2.151309,
  0.306466, 2.537290, 0.042222, 0.437729, -0.021450, 2.372649, 0.043203, 1.324897, 2.845391,
  1.199572, 0.413515, -0.020480, 1.101867, 1.818648, 3.367498, 1.049140, 1.954052, 3.778584,
  1.550587, 0.748076, -0.992170, 1.180165, -1.174493, 3.025873, 1.320564, -1.187017, 3.307770,
  0.000000, 0.056529, 0.000000, -0.011687, 0.240575, -0.098083, 0.000000, 0.048474, 0.000000,
  0.000000, -0.385429, -0.609283, -0.659817, -1.725096, 0.011906, 0.000000, -1.055442, -0.058882,
  0.000000, -0.123751, -0.106339, -0.471330, 0.038438, 1.818591, 0.000000, 0.515174, 2.252558,
  0.000000, -0.325580, 0.000000, -0.045188, 1.316020, 0.457084, 0.000000, 0.752600, 0.000000,
  -0.513046, -0.236782, -0.021902, -0.081404, 1.851628, 1.513759, -0.563831, 3.336167, 2.904475,
  -1.352678, -2.096348, 0.584248, -0.538446, 0.947486, 0.541107, -0.152396, 1.839143, 1.445237,
  0.000000, -0.921213, -0.277363, -0.019112, 0.789392, 0.406489, 0.000000, 0.768434, 1.643602,
  -1.875402, -1.980288, -1.843987, -1.590549, -2.184320, -3.483313, -0.678764, -2.324074, -2.829237,
  -1.469148, -3.182573, -2.680461, -0.431922, -2.396518, -3.726117, -0.492295, -1.716178, -2.827418,
  0.000000, 0.000000, -0.192418, 0.000000, 0.040810, 0.009378, 0.036480, -1.081265, -0.854013,
  0.000000, -2.362739, -2.766175, 0.000000, -2.173801, -0.287421, -1.081265, -2.542809, -0.889505,
  0.000000, -0.865086, -1.171327, 0.000000, -0.976519, 1.414083, -0.854013, -0.889505, 2.506231,
  0.000000, -1.728033, -1.742863, 0.000000, -0.675118, -0.128347, -0.066299, -0.496356, -0.928279,
  0.000000, -1.717567, -1.509797, -0.044426, 1.211470, 0.985143, -0.496356, 1.174564, 1.447081,
  0.000000, -3.305908, -2.011198, -0.214728, 0.948140, -0.039671, -0.928279, 1.447081, 0.630694,
  0.000000, -0.780863, -0.731600, 0.000000, -1.875762, -1.166031, -0.252398, -1.988047, -1.427450,
  -0.979308, -2.076228, -0.428754, -1.648360, -2.040498, -2.832485, -1.988047, -1.743557, -3.352107,
  -0.605536, -4.183270, -0.267169, -1.628161, -2.944790, -5.038836, -1.427450, -3.352107, -4.767233,
]
const g_pat8_val_LW = [
  -0.014319, 0.298531, -0.501339, 0.056303, 0.602251, -0.313402, 0.295922, 0.030343, -0.493858,
  0.298531, 0.672721, 0.007084, 0.295355, 0.807675, 0.099664, 0.340001, 0.360868, -0.316438,
  -0.501339, 0.007084, -0.449340, -0.552357, 0.159194, -0.205413, -0.098543, -0.027438, -0.714662,
  0.111960, 0.256511, 0.039584, -0.073592, 0.141657, 0.136440, 0.270211, -0.189022, 0.271714,
  0.256511, -0.125933, 0.331456, -0.239051, 0.116035, 0.224971, 0.267400, 0.506133, 0.735403,
  0.039584, 0.331456, 0.403184, -0.046275, 0.628039, 0.502504, -0.104119, 0.524951, 0.131250,
  -0.099563, -0.091287, -0.244823, -0.283175, -0.471705, 0.302005, -0.046457, -0.220574, 0.440222,
  -0.091287, -0.339659, -0.625822, -0.133512, 0.110194, -0.441110, 0.065346, -0.519961, -1.072754,
  -0.244823, -0.625822, -0.623883, -0.507770, -0.911783, -0.367871, -0.071274, -0.167895, -0.011898,
  0.000000, -0.091178, 0.000000, 0.000100, -0.230672, 0.221577, 0.000000, -0.502171, -0.294698,
  0.000000, 0.184566, 0.000000, 0.136700, 0.095210, -0.179180, 0.000000, 0.229228, -0.300668,
  0.000000, -0.507459, -0.071305, -0.115969, -0.159281, 0.175101, 0.000000, -0.340196, -0.648916,
  0.000000, -0.087293, 0.000000, -0.016091, 0.154034, 0.300229, 0.000000, 0.249499, -0.074970,
  -0.242469, -1.144563, 0.282444, -0.522783, -0.701370, -0.093992, 0.061376, -0.147628, -0.589818,
  0.000000, -0.117334, 0.277978, -0.040510, 0.243132, -0.283945, 0.000000, 0.264226, -0.285871,
  0.000000, -0.226367, -0.111776, -0.001805, 0.406366, -0.294115, 0.000000, 0.109345, -0.683202,
  0.000000, -0.249742, 0.125590, -0.004518, 0.236510, -0.112995, 0.000000, 0.049080, -0.219044,
  0.000000, -0.390090, 0.758059, 0.026310, 0.092568, -0.450374, 0.000000, 0.027419, -0.349324,
  0.000000, 0.000000, -0.043072, 0.000000, 0.292471, 0.489941, -0.056203, 0.121998, 0.507849,
  0.000000, 0.064436, 0.703513, 0.000000, 0.739036, 0.291674, -0.093274, -0.099790, 0.206288,
  0.000000, 0.000000, -0.101219, 0.000000, 0.022469, 0.339972, -0.131780, -0.165872, 0.159341,
  0.000000, 0.074763, 0.114919, 0.000000, 0.481837, -0.187183, -0.007354, 0.167564, -0.591590,
  0.000000, -0.476320, 0.701963, 0.000000, 0.184904, -0.086031, 0.150935, 0.070518, -0.430841,
  0.000000, -0.147248, 0.337073, 0.000000, 0.350412, -0.072357, 0.025354, -0.023469, -0.276047,
  0.000000, 0.000000, -0.143526, 0.000000, 0.141458, -0.457223, 0.020701, 0.237834, 0.134476,
  0.000000, -0.280490, 0.345740, 0.000000, 0.199881, -0.033338, 0.038285, 0.029509, -0.565717,
  -0.074706, -0.428918, 0.989394, 0.093680, 0.444095, -0.310999, 0.218698, 0.527045, -0.025114,
  0.056303, 0.295355, -0.552357, -0.051340, -0.110185, -0.005879, 0.109742, -0.169331, -0.307545,
  0.602251, 0.807675, 0.159194, -0.110185, -0.303910, 0.350219, 0.336029, -0.012578, 0.264739,
  -0.313402, 0.099664, -0.205413, -0.005879, 0.350219, 0.160442, -0.244733, -0.052292, -0.178293,
  -0.073592, -0.239051, -0.046275, -0.084423, -0.375498, 0.392652, 0.096981, -0.277006, 0.426058,
  0.141657, 0.116035, 0.628039, -0.375498, 0.419961, 0.285583, -0.106305, -0.149782, 0.257293,
  0.136440, 0.224971, 0.502504, 0.392652, 0.285583, 0.590382, 0.053129, -0.119594, -0.191077,
  -0.283175, -0.133512, -0.507770, 0.023324, -0.101864, 0.350233, -0.115508, 0.014211, 0.431290,
  -0.471705, 0.110194, -0.911783, -0.101864, 0.086907, -0.127308, -0.312683, -0.156877, -0.596415,
  0.302005, -0.441110, -0.367871, 0.350233, -0.127308, 0.262976, 0.853218, -0.147588, 0.323200,
  0.000000, -0.090526, 0.000000, -0.057168, -0.337569, 0.059751, 0.000000, -0.243957, -0.091151,
  0.000000, -0.327860, 0.283546, -0.067396, -0.228077, 0.053918, 0.000000, -0.715378, -0.574127,
  0.000000, -0.070861, 0.222018, 0.127641, -0.006061, 0.115507, 0.000000, -0.093399, 0.014609,
  0.000000, -0.374466, 0.000000, -0.190504, -0.666249, -0.143034, 0.000000, 0.017382, -0.208197,
  -1.181307, -2.488780, 0.071771, -0.834363, -1.792004, -1.753066, -0.440286, -0.952156, -1.649003,
  0.000000, -0.392899, 0.752037, 0.175965, 0.124846, -0.024808, 0.000000, -0.225381, -0.096750,
  0.000000, -0.002236, -0.147653, -0.033436, 0.449962, 0.229695, 0.000000, 0.020580, -0.128202,
  0.000000, 0.103024, 0.209413, 0.083826, 0.166393, -0.043610, 0.000000, 0.236130, 0.025229,
  0.000000, -0.075065, 0.536227, 0.067688, 1.230329, 0.931977, 0.000000, 0.313698, 0.113789,
  0.000000, 0.000000, -0.063562, 0.000000, 0.122773, 0.099270, -0.090532, -0.119879, 0.173616,
  0.000000, -0.309638, -0.005570, 0.000000, 0.106895, 0.203492, -0.219858, -0.278594, -0.136022,
  0.000000, 0.000000, -0.070231, 0.000000, 0.107293, 0.196837, -0.044139, 0.015543, -0.171406,
  0.000000, -0.135002, -0.028892, 0.000000, 0.051588, -0.414313, -0.102169, -0.228927, -0.720038,
  0.000000, -1.080099, 0.140539, 0.059504, 0.461519, -0.128485, -0.346601, -0.658179, -1.512165,
  0.000000, -0.134147, 0.065400, 0.257279, 0.250145, -0.152027, -0.059082, 0.112740, -0.045195,
  0.000000, 0.000000, 0.106871, 0.000000, -0.062644, -0.045960, -0.031347, 0.045856, 0.056832,
  -0.204174, 0.318566, 0.255678, 0.007140, 0.291287, 0.138592, -0.124363, 0.863534, -0.019319,
  0.606924, 0.484676, 0.202309, 0.225143, 1.391193, 0.548084, 1.260979, 1.377957, 1.329506,
  0.295922, 0.340001, -0.098543, 0.109742, 0.336029, -0.244733, 0.119701, -0.134269, -0.329528,
  0.030343, 0.360868, -0.027438, -0.169331, -0.012578, -0.052292, -0.134269, 0.113621, -0.269227,
  -0.493858, -0.316438, -0.714662, -0.307545, 0.264739, -0.178293, -0.329528, -0.269227, 0.215477,
  0.270211, 0.267400, -0.104119, 0.096981, -0.106305, 0.053129, 0.010811, -0.146973, 0.126142,
  -0.189022, 0.506133, 0.524951, -0.277006, -0.149782, -0.119594, -0.146973, 0.185850, 0.217151,
  0.271714, 0.735403, 0.131250, 0.426058, 0.257293, -0.191077, 0.126142, 0.217151, 0.036267,
  -0.046457, 0.065346, -0.071274, -0.115508, -0.312683, 0.853218, 0.070867, -0.305425, 0.616980,
  -0.220574, -0.519961, -0.167895, 0.014211, -0.156877, -0.147588, -0.305425, -0.242356, -0.634691,
  0.440222, -1.072754, -0.011898, 0.431290, -0.596415, 0.323200, 0.616980, -0.634691, -0.741381,
  0.000000, 0.174879, 0.000000, 0.097773, -0.327912, -0.027939, 0.000000, -0.585125, -0.166762,
  0.000000, -0.063790, 0.000000, -0.018662, -0.152036, 0.057233, 0.000000, -0.402576, -0.097193,
  0.000000, -0.137061, 0.492105, 0.233900, -0.127748, 0.115589, 0.000000, -0.339583, 0.037802,
  0.000000, 0.129324, 0.000000, 0.000000, -0.229303, -0.026552, 0.000000, 0.067416, -0.022757,
  -0.248103, -0.097239, -0.145509, -0.580194, -1.006166, -1.021589, -0.213027, -0.420666, -0.297841,
  -0.272158, -0.329679, -0.316715, 0.432216, 0.332112, -0.114867, -0.017393, 0.209408, -0.250213,
  0.000000, -0.294079, 0.086760, 0.104300, 0.783509, 0.113256, 0.000000, 0.468602, -0.061616,
  0.000000, 0.024331, 0.102062, -0.019623, 0.495413, 0.322435, -0.191689, 0.321665, 0.009249,
  0.000000, -0.687699, 0.848918, 0.342131, 0.827316, 0.620952, 0.131941, 0.587399, -0.156578,
  0.000000, 0.000000, 0.034926, 0.000000, 0.226091, 0.298994, -0.074070, -0.033688, 0.635942,
  0.000000, -0.502058, 0.018743, 0.000000, -0.174109, 0.073883, -0.022453, -0.067769, -0.379760,
  0.000000, -0.057519, -0.180815, 0.000000, 0.293467, 0.370045, -0.089757, -0.567784, 0.259891,
  0.000000, 0.248340, 0.169101, 0.000000, 0.037252, -0.183221, -0.014898, 0.004163, -0.461301,
  0.000000, -0.118303, 0.089957, 0.000000, -0.313559, 0.118591, -0.265484, -0.679340, -0.956130,
  0.000000, -0.239776, -0.142353, 0.000000, 0.359360, 0.123050, -0.017873, 0.161640, -0.152107,
  0.000000, 0.000000, 0.136422, 0.000000, 0.117729, -0.279192, 0.081280, 0.592075, 0.399258,
  0.000000, -0.231676, 0.546530, 0.000000, -0.094915, -0.110687, 0.006044, 0.235437, 0.488347,
  0.758381, 0.033546, 2.156947, 0.895548, 1.442076, 0.821311, 1.267711, 1.672306, 1.370693,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.091178, 0.184566, -0.507459, -0.090526, -0.327860, -0.070861, 0.174879, -0.063790, -0.137061,
  0.000000, 0.000000, -0.071305, 0.000000, 0.283546, 0.222018, 0.000000, 0.000000, 0.492105,
  0.000000, -0.242469, 0.000000, 0.000000, -1.181307, 0.000000, 0.000000, -0.248103, -0.272158,
  -0.087293, -1.144563, -0.117334, -0.374466, -2.488780, -0.392899, 0.129324, -0.097239, -0.329679,
  0.000000, 0.282444, 0.277978, 0.000000, 0.071771, 0.752037, 0.000000, -0.145509, -0.316715,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.226367, -0.249742, -0.390090, -0.002236, 0.103024, -0.075065, -0.294079, 0.024331, -0.687699,
  -0.111776, 0.125590, 0.758059, -0.147653, 0.209413, 0.536227, 0.086760, 0.102062, 0.848918,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -0.136823, 0.111356, 0.087224, 0.374900, 0.276515, 0.000000, 0.034508, -0.017178,
  0.000000, 0.111356, 0.090054, 0.000000, 0.332166, 0.048450, 0.000000, 0.048434, 0.107605,
  0.000000, 0.163348, 0.000000, 0.000000, 0.989165, 0.084415, 0.000000, 0.621099, 0.417847,
  0.163348, -0.665728, 0.343289, 0.296425, 0.371916, 0.487280, 0.129020, -0.045399, 0.258039,
  0.000000, 0.343289, 0.274282, 0.000000, 1.321625, 0.643236, 0.000000, 0.274382, 0.703565,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.065229, 0.140405, 0.123843, 0.198518, 0.178758, 0.000000, -0.002908, -0.310985,
  0.000000, 0.140405, 0.596431, -0.067414, 0.718880, 0.730161, 0.000000, 0.028982, 0.002950,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -0.160803, 0.011567, 0.000000, -0.218131, 0.297548, -0.011236, -0.206132, 0.005746,
  0.000000, 0.000000, 0.093486, 0.000000, 0.035045, 0.189539, 0.000000, 0.018009, 0.396330,
  0.000000, 0.015309, 0.062592, 0.000000, 0.168668, -0.056003, 0.000000, -0.366183, -0.348418,
  0.000000, -0.719742, 0.426770, 0.000000, -0.065169, -0.022671, 0.022463, -0.386274, -0.304587,
  0.000000, -0.055097, 0.418686, 0.000000, 0.451269, -0.004517, 0.000000, 0.064925, 0.039522,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.349047, -0.260437, -0.211634, 0.103729, 0.270663, 0.194474, -0.059934, -0.544071, -0.420644,
  0.137767, -0.007969, 1.142718, 0.081816, 0.694765, 0.643562, -0.185444, 0.506501, 0.626027,
  0.000100, 0.136700, -0.115969, -0.057168, -0.067396, 0.127641, 0.097773, -0.018662, 0.233900,
  -0.230672, 0.095210, -0.159281, -0.337569, -0.228077, -0.006061, -0.327912, -0.152036, -0.127748,
  0.221577, -0.179180, 0.175101, 0.059751, 0.053918, 0.115507, -0.027939, 0.057233, 0.115589,
  -0.016091, -0.522783, -0.040510, -0.190504, -0.834363, 0.175965, 0.000000, -0.580194, 0.432216,
  0.154034, -0.701370, 0.243132, -0.666249, -1.792004, 0.124846, -0.229303, -1.006166, 0.332112,
  0.300229, -0.093992, -0.283945, -0.143034, -1.753066, -0.024808, -0.026552, -1.021589, -0.114867,
  -0.001805, -0.004518, 0.026310, -0.033436, 0.083826, 0.067688, 0.104300, -0.019623, 0.342131,
  0.406366, 0.236510, 0.092568, 0.449962, 0.166393, 1.230329, 0.783509, 0.495413, 0.827316,
  -0.294115, -0.112995, -0.450374, 0.229695, -0.043610, 0.931977, 0.113256, 0.322435, 0.620952,
  0.000000, 0.087224, 0.000000, 0.000000, 0.109971, 0.196670, 0.000000, 0.122695, 0.087226,
  0.000000, 0.374900, 0.332166, 0.109971, 0.724319, 0.382344, 0.000000, -0.190595, 0.315551,
  0.000000, 0.276515, 0.048450, 0.196670, 0.382344, 0.215286, 0.000000, 0.243087, 0.518853,
  0.000000, 0.296425, 0.000000, 0.000000, 0.632929, 0.027202, 0.000000, 0.707088, 0.392318,
  0.989165, 0.371916, 1.321625, 0.632929, 1.523303, 1.005456, 0.371039, 1.795035, 1.012145,
  0.084415, 0.487280, 0.643236, 0.027202, 1.005456, 0.459867, 0.045448, 0.960751, 0.815738,
  0.000000, 0.123843, -0.067414, -0.004195, 0.107659, 0.039069, 0.000000, 0.138384, 0.106649,
  0.000000, 0.198518, 0.718880, 0.107659, -0.080522, -0.547799, -0.003857, -0.313807, -0.385449,
  0.000000, 0.178758, 0.730161, 0.039069, -0.547799, -0.044975, -0.085260, 0.049715, -0.090864,
  0.000000, 0.000000, 0.041761, 0.000000, -0.036523, 0.149482, -0.025553, -0.013645, 0.129782,
  0.000000, -0.081872, -0.146648, 0.000000, -0.617512, 0.349088, -0.091719, -0.781088, 0.595889,
  0.000000, 0.096554, 0.503440, 0.000000, 0.115698, -0.001364, 0.081785, 0.016789, 0.966995,
  0.000000, -0.101412, 0.199400, 0.000000, -0.022219, 0.100715, -0.016238, -0.230138, -0.383880,
  0.000000, -0.572051, 0.439380, 0.003596, -0.493896, -0.265771, 0.201540, 0.197624, 0.197155,
  0.000000, -0.224941, 0.363500, 0.247952, 0.377893, -0.050886, 0.087614, 0.828634, 1.129353,
  0.000000, 0.000000, 0.039467, 0.000000, -0.021554, -0.025650, 0.022519, -0.092570, 0.006895,
  0.136905, 0.110557, 0.109215, -0.038115, -0.816115, -0.796361, 0.378385, -0.911713, -0.286320,
  0.084909, 0.660286, 0.687992, -0.194203, -0.844007, -1.181675, 0.117450, -0.941971, -0.166767,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.502171, 0.229228, -0.340196, -0.243957, -0.715378, -0.093399, -0.585125, -0.402576, -0.339583,
  -0.294698, -0.300668, -0.648916, -0.091151, -0.574127, 0.014609, -0.166762, -0.097193, 0.037802,
  0.000000, 0.061376, 0.000000, 0.000000, -0.440286, 0.000000, 0.000000, -0.213027, -0.017393,
  0.249499, -0.147628, 0.264226, 0.017382, -0.952156, -0.225381, 0.067416, -0.420666, 0.209408,
  -0.074970, -0.589818, -0.285871, -0.208197, -1.649003, -0.096750, -0.022757, -0.297841, -0.250213,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.191689, 0.131941,
  0.109345, 0.049080, 0.027419, 0.020580, 0.236130, 0.313698, 0.468602, 0.321665, 0.587399,
  -0.683202, -0.219044, -0.349324, -0.128202, 0.025229, 0.113789, -0.061616, 0.009249, -0.156578,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.034508, 0.048434, 0.122695, -0.190595, 0.243087, 0.000000, 0.054502, 0.257244,
  0.000000, -0.017178, 0.107605, 0.087226, 0.315551, 0.518853, 0.000000, 0.257244, 0.175835,
  0.000000, 0.129020, 0.000000, 0.000000, 0.371039, 0.045448, 0.000000, 0.652344, 0.000764,
  0.621099, -0.045399, 0.274382, 0.707088, 1.795035, 0.960751, 0.652344, 0.721008, 0.806750,
  0.417847, 0.258039, 0.703565, 0.392318, 1.012145, 0.815738, 0.000764, 0.806750, 0.441740,
  0.000000, 0.000000, 0.000000, 0.000000, -0.003857, -0.085260, 0.000000, 0.246997, 0.060266,
  0.000000, -0.002908, 0.028982, 0.138384, -0.313807, 0.049715, 0.246997, -0.026253, -0.013442,
  0.000000, -0.310985, 0.002950, 0.106649, -0.385449, -0.090864, 0.060266, -0.013442, 0.276896,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -0.209659, -0.127851, 0.000000, -0.046312, 0.004793, 0.029589, -0.178336, 0.266786,
  0.000000, -0.112337, 0.066956, 0.000000, 0.151663, 0.146931, 0.026268, -0.076919, 0.625097,
  0.000000, -0.054519, -0.209854, 0.000000, -0.029881, 0.117276, 0.000000, 0.102453, -0.071222,
  0.000000, -0.595517, -0.043203, 0.000000, 0.168927, 0.274175, -0.069354, 0.575798, 0.725333,
  0.000000, -0.284357, 0.134736, 0.000000, 0.565011, 0.001888, 0.000000, 0.296033, 0.851291,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.299750, 0.020459,
  0.016910, -0.095839, 0.037319, -0.018625, -0.116477, 0.010841, 0.063897, -0.285125, -0.073728,
  0.158778, -0.347583, 0.195831, 0.034067, -0.703177, -0.455438, 0.192030, -0.412519, 0.329669,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.064436, 0.000000, 0.000000, -0.309638, 0.000000, 0.000000, -0.502058, -0.057519,
  -0.043072, 0.703513, -0.101219, -0.063562, -0.005570, -0.070231, 0.034926, 0.018743, -0.180815,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.074763, -0.476320, -0.147248, -0.135002, -1.080099, -0.134147, 0.248340, -0.118303, -0.239776,
  0.114919, 0.701963, 0.337073, -0.028892, 0.140539, 0.065400, 0.169101, 0.089957, -0.142353,
  0.000000, 0.000000, -0.074706, 0.000000, -0.204174, 0.606924, 0.000000, 0.000000, 0.758381,
  0.000000, -0.280490, -0.428918, 0.000000, 0.318566, 0.484676, 0.000000, -0.231676, 0.033546,
  -0.143526, 0.345740, 0.989394, 0.106871, 0.255678, 0.202309, 0.136422, 0.546530, 2.156947,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -0.160803, 0.000000, 0.000000, -0.081872, 0.096554, 0.000000, -0.209659, -0.112337,
  0.000000, 0.011567, 0.093486, 0.041761, -0.146648, 0.503440, 0.000000, -0.127851, 0.066956,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.015309, -0.719742, -0.055097, -0.101412, -0.572051, -0.224941, -0.054519, -0.595517, -0.284357,
  0.062592, 0.426770, 0.418686, 0.199400, 0.439380, 0.363500, -0.209854, -0.043203, 0.134736,
  0.000000, -0.349047, 0.137767, 0.000000, 0.136905, 0.084909, 0.000000, 0.016910, 0.158778,
  0.000000, -0.260437, -0.007969, 0.000000, 0.110557, 0.660286, 0.000000, -0.095839, -0.347583,
  0.000000, -0.211634, 1.142718, 0.039467, 0.109215, 0.687992, 0.000000, 0.037319, 0.195831,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -0.058597, -0.060972, 0.000000, -0.054680, -0.014195, 0.000000, -0.277703, -0.347921,
  0.000000, -0.060972, -0.106925, 0.000000, -0.308397, -0.004916, -0.249870, -0.427837, -0.966097,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -0.162833, -0.069188, 0.000000, -0.125605, -0.097596, -0.148120, -0.761742, -0.688063,
  0.000000, -0.069188, -0.013364, 0.000000, 0.173707, -0.021823, -0.056968, -0.255143, -0.275397,
  0.000000, 0.000000, -0.366739, 0.000000, -0.392587, -0.773427, 0.000000, -0.287200, -1.111526,
  0.000000, -0.071249, -0.328831, 0.000000, -0.412921, -0.072129, 0.000000, -0.450363, -1.147527,
  -0.366739, -0.328831, 0.719062, -0.200321, -0.246880, 0.007209, -0.290067, -0.694364, -0.878549,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.292471, 0.739036, 0.022469, 0.122773, 0.106895, 0.107293, 0.226091, -0.174109, 0.293467,
  0.489941, 0.291674, 0.339972, 0.099270, 0.203492, 0.196837, 0.298994, 0.073883, 0.370045,
  0.000000, 0.000000, 0.000000, 0.000000, 0.059504, 0.257279, 0.000000, 0.000000, 0.000000,
  0.481837, 0.184904, 0.350412, 0.051588, 0.461519, 0.250145, 0.037252, -0.313559, 0.359360,
  -0.187183, -0.086031, -0.072357, -0.414313, -0.128485, -0.152027, -0.183221, 0.118591, 0.123050,
  0.000000, 0.000000, 0.093680, 0.000000, 0.007140, 0.225143, 0.000000, 0.000000, 0.895548,
  0.141458, 0.199881, 0.444095, -0.062644, 0.291287, 1.391193, 0.117729, -0.094915, 1.442076,
  -0.457223, -0.033338, -0.310999, -0.045960, 0.138592, 0.548084, -0.279192, -0.110687, 0.821311,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -0.218131, 0.035045, -0.036523, -0.617512, 0.115698, 0.000000, -0.046312, 0.151663,
  0.000000, 0.297548, 0.189539, 0.149482, 0.349088, -0.001364, 0.000000, 0.004793, 0.146931,
  0.000000, 0.000000, 0.000000, 0.000000, 0.003596, 0.247952, 0.000000, 0.000000, 0.000000,
  0.168668, -0.065169, 0.451269, -0.022219, -0.493896, 0.377893, -0.029881, 0.168927, 0.565011,
  -0.056003, -0.022671, -0.004517, 0.100715, -0.265771, -0.050886, 0.117276, 0.274175, 0.001888,
  0.000000, 0.103729, 0.081816, 0.000000, -0.038115, -0.194203, 0.000000, -0.018625, 0.034067,
  0.000000, 0.270663, 0.694765, -0.021554, -0.816115, -0.844007, 0.000000, -0.116477, -0.703177,
  0.000000, 0.194474, 0.643562, -0.025650, -0.796361, -1.181675, 0.000000, 0.010841, -0.455438,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -0.054680, -0.308397, 0.000000, -0.200186, 0.014116, 0.071731, -0.269186, -0.449537,
  0.000000, -0.014195, -0.004916, 0.000000, 0.014116, -0.081493, -0.234292, -0.331484, 0.444137,
  0.000000, 0.000000, 0.000000, 0.000000, -0.225309, -0.156262, 0.000000, 0.059396, 0.022854,
  0.000000, -0.125605, 0.173707, -0.225309, -0.337961, -0.304998, 0.010148, -0.140788, 0.143618,
  0.000000, -0.097596, -0.021823, -0.156262, -0.304998, 0.076583, -0.115752, 0.090446, 0.107192,
  0.000000, 0.000000, -0.200321, 0.000000, 0.000000, -0.797088, 0.000000, 0.005188, -0.360731,
  -0.392587, -0.412921, -0.246880, 0.000000, -0.383692, -1.533196, -0.115230, -1.005653, -1.792456,
  -0.773427, -0.072129, 0.007209, -0.797088, -1.533196, -2.004356, -0.955502, -1.268526, -2.017211,
  -0.056203, -0.093274, -0.131780, -0.090532, -0.219858, -0.044139, -0.074070, -0.022453, -0.089757,
  0.121998, -0.099790, -0.165872, -0.119879, -0.278594, 0.015543, -0.033688, -0.067769, -0.567784,
  0.507849, 0.206288, 0.159341, 0.173616, -0.136022, -0.171406, 0.635942, -0.379760, 0.259891,
  -0.007354, 0.150935, 0.025354, -0.102169, -0.346601, -0.059082, -0.014898, -0.265484, -0.017873,
  0.167564, 0.070518, -0.023469, -0.228927, -0.658179, 0.112740, 0.004163, -0.679340, 0.161640,
  -0.591590, -0.430841, -0.276047, -0.720038, -1.512165, -0.045195, -0.461301, -0.956130, -0.152107,
  0.020701, 0.038285, 0.218698, -0.031347, -0.124363, 1.260979, 0.081280, 0.006044, 1.267711,
  0.237834, 0.029509, 0.527045, 0.045856, 0.863534, 1.377957, 0.592075, 0.235437, 1.672306,
  0.134476, -0.565717, -0.025114, 0.056832, -0.019319, 1.329506, 0.399258, 0.488347, 1.370693,
  0.000000, -0.011236, 0.000000, -0.025553, -0.091719, 0.081785, 0.000000, 0.029589, 0.026268,
  0.000000, -0.206132, 0.018009, -0.013645, -0.781088, 0.016789, 0.000000, -0.178336, -0.076919,
  0.000000, 0.005746, 0.396330, 0.129782, 0.595889, 0.966995, 0.000000, 0.266786, 0.625097,
  0.000000, 0.022463, 0.000000, -0.016238, 0.201540, 0.087614, 0.000000, -0.069354, 0.000000,
  -0.366183, -0.386274, 0.064925, -0.230138, 0.197624, 0.828634, 0.102453, 0.575798, 0.296033,
  -0.348418, -0.304587, 0.039522, -0.383880, 0.197155, 1.129353, -0.071222, 0.725333, 0.851291,
  0.000000, -0.059934, -0.185444, 0.022519, 0.378385, 0.117450, 0.000000, 0.063897, 0.192030,
  0.000000, -0.544071, 0.506501, -0.092570, -0.911713, -0.941971, -0.299750, -0.285125, -0.412519,
  0.000000, -0.420644, 0.626027, 0.006895, -0.286320, -0.166767, 0.020459, -0.073728, 0.329669,
  0.000000, 0.000000, -0.249870, 0.000000, 0.071731, -0.234292, -0.069943, 0.002198, -0.019755,
  0.000000, -0.277703, -0.427837, 0.000000, -0.269186, -0.331484, 0.002198, -0.306142, -0.693326,
  0.000000, -0.347921, -0.966097, 0.000000, -0.449537, 0.444137, -0.019755, -0.693326, 0.231705,
  0.000000, -0.148120, -0.056968, 0.000000, 0.010148, -0.115752, -0.050296, -0.004125, -0.203754,
  0.000000, -0.761742, -0.255143, 0.059396, -0.140788, 0.090446, -0.004125, -0.212316, 0.130934,
  0.000000, -0.688063, -0.275397, 0.022854, 0.143618, 0.107192, -0.203754, 0.130934, 0.340451,
  0.000000, 0.000000, -0.290067, 0.000000, -0.115230, -0.955502, -0.033837, -0.065394, -0.734839,
  -0.287200, -0.450363, -0.694364, 0.005188, -1.005653, -1.268526, -0.065394, -0.313590, -1.761017,
  -1.111526, -1.147527, -0.878549, -0.360731, -1.792456, -2.017211, -0.734839, -1.761017, -1.958693,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.017496, -0.224228, -0.089522, -0.053203, -0.336852, -0.254947, -0.112779, -0.158441, -0.210938,
  -0.224228, -0.223616, -0.038929, -0.153761, 0.015165, -0.203142, -0.081543, -0.556057, 0.002834,
  -0.089522, -0.038929, -0.068597, 0.130262, 0.499111, -0.370733, -0.237152, -0.072430, -0.717634,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.035880, -0.549766, -0.338382, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.259088, -0.372682, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.002284, -0.316028, -0.943493, 0.000000, 0.000000, 0.000000,
  0.000000, -0.396600, -0.139546, 0.004231, 0.166410, -0.332725, 0.000000, -0.445410, -0.172575,
  0.000000, -0.872262, 0.033786, 0.055519, -0.120508, -0.235248, 0.000000, -0.343423, -0.285729,
  0.000000, -0.381905, -0.099808, 0.071481, 0.508104, -0.367853, 0.000000, -0.012351, -0.404830,
  0.000000, 0.000000, 0.000000, -0.028348, -0.082391, -0.369623, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.088827, 0.342288, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.194732, -0.146321, -0.301225, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.141309, -0.203255, 0.000000, 0.039121, -0.088911, 0.171079, -0.041945, -0.416829,
  0.037012, -0.169311, -0.250797, 0.000000, 0.005197, 0.038897, -0.153253, 0.059824, -0.211406,
  0.316129, 0.115144, -0.505145, 0.029196, 0.007497, -0.058494, 0.024697, 0.022148, -0.420507,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -0.021450, -0.023847, 0.000000, 0.055105, 0.011927, 0.000000, -0.017245, -0.221434,
  -0.101301, 0.131270, 0.405185, -0.080699, 0.152598, -0.049567, -0.033866, -0.005781, -0.003072,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.053203, -0.153761, 0.130262, -0.118720, -0.493155, 0.036307, 0.018525, -0.134485, 0.331318,
  -0.336852, 0.015165, 0.499111, -0.493155, -0.626510, 0.025848, -0.497636, -0.349178, 0.138989,
  -0.254947, -0.203142, -0.370733, 0.036307, 0.025848, -0.243057, -0.143879, -0.193889, -0.850746,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, -0.098239, 0.136617, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.019358, -0.661706, 0.012842, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.031609, -0.151733, 0.029892, 0.000000, 0.000000, 0.000000,
  0.000000, 0.035485, 0.112199, 0.018033, 0.178184, 0.387821, 0.000000, -0.012703, 0.075202,
  0.000000, 0.081162, 0.415693, 0.191500, 1.598157, 1.505949, 0.000000, 0.685355, 0.329262,
  0.000000, -0.106719, 0.052967, 0.045304, 0.298966, 0.221175, 0.000000, -0.139475, -0.100464,
  0.000000, 0.000000, 0.000000, 0.000000, 0.008105, 0.070600, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.075656, -0.285045, -0.461966, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.071698, -0.370339, -1.006657, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.055658, -0.195023, 0.000000, -0.006354, -0.080226, -0.000931, -0.053363, -0.104871,
  0.430238, 0.664811, 0.674651, -0.030859, -0.001047, 0.076392, 0.063435, 0.303152, 0.659502,
  0.287426, 0.024459, 0.151235, 0.007816, -0.012730, -0.010173, 0.262487, 0.283393, -0.261831,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.022062, -0.133752, -0.264071, 0.000000, -0.015975, -0.029096, 0.005207, -0.120091, -0.665609,
  -0.165781, -0.375249, -0.966894, 0.038990, -0.213227, -0.354608, 0.070791, -0.320025, -0.888436,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.112779, -0.081543, -0.237152, 0.018525, -0.497636, -0.143879, 0.046337, -0.378001, -0.122373,
  -0.158441, -0.556057, -0.072430, -0.134485, -0.349178, -0.193889, -0.378001, -0.282712, -0.367735,
  -0.210938, 0.002834, -0.717634, 0.331318, 0.138989, -0.850746, -0.122373, -0.367735, -0.552352,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.015989, -0.161682, 0.395431,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.161682, -0.057304, -0.270882,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.395431, -0.270882, 1.004635,
  0.000000, 0.000000, 0.000000, 0.019811, -0.263375, -0.074925, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.053401, -0.385646, -0.208847, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.016071, -0.241465, 0.405342, 0.000000, 0.000000, 0.000000,
  0.000000, -0.226623, -0.100256, 0.041221, 0.152008, 0.037196, 0.000000, -0.047090, -0.081586,
  0.000000, 0.055262, 0.040652, -0.136650, 0.313482, 0.385318, -0.084334, 0.340895, 0.044282,
  0.000000, -0.636040, -0.422847, 0.210760, 0.096725, 0.116745, 0.052203, -0.100052, -0.059995,
  0.000000, 0.000000, 0.000000, -0.109154, 0.048196, 0.005379, 0.000000, -0.261179, -0.114720,
  0.000000, 0.000000, 0.000000, -0.001476, -0.592527, -0.174992, 0.000000, -0.109377, -0.385959,
  0.000000, 0.000000, 0.000000, -0.526348, -1.076060, -1.005354, 0.000000, -0.630346, -0.880099,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.050365, -0.014179, 0.000000, 0.007957, -0.111426, 0.091187, 0.051651, -0.312115,
  0.008905, 0.189807, 0.004725, 0.000000, 0.012924, -0.101462, -0.022410, 0.107358, 0.021695,
  -0.117997, 0.357959, -0.798486, -0.043858, 0.116278, -0.017796, 0.226921, 0.086398, -0.498754,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.011478, 0.008648, 0.209322,
  0.000000, -0.031699, 0.013621, 0.000000, -0.040957, -0.023221, -0.038960, -0.104429, -0.209647,
  -0.072531, -0.795827, -0.709879, 0.178975, -0.359018, -0.733639, 0.005112, -0.607942, -0.930992,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.396600, -0.872262, -0.381905, 0.035485, 0.081162, -0.106719, -0.226623, 0.055262, -0.636040,
  -0.139546, 0.033786, -0.099808, 0.112199, 0.415693, 0.052967, -0.100256, 0.040652, -0.422847,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.011553, -0.708828, -0.551791, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.007319, -0.188729, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, -0.806551, -0.098914, 0.000000, 0.000000, 0.000000,
  0.000000, -0.308997, -0.212994, -0.265399, -1.366993, -1.137821, 0.000000, -0.310954, -0.261853,
  0.000000, -0.212994, -0.225204, -0.046754, -0.924025, -0.931273, 0.000000, -0.100566, -0.375323,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.182677, -0.289202, -0.280205, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.370377, -0.763789, -1.110158, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.074190, 0.191108, -0.552932, 0.000000, -0.151631, -0.024082, -0.177523, -0.158831, -0.560975,
  -0.000359, -0.010234, -0.768866, 0.000000, 0.103783, -0.015322, 0.014597, -0.530343, -0.547662,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.216310, -0.045244, -0.523190, -0.010901, -0.028104, -0.058768, 0.013189, 0.064721, -0.176414,
  -0.243410, -0.121586, -0.927550, 0.057337, -0.040592, -0.075427, -0.102570, -0.132190, -0.068605,
  0.035880, 0.000000, -0.002284, 0.000000, -0.019358, 0.031609, 0.019811, -0.053401, 0.016071,
  -0.549766, 0.259088, -0.316028, -0.098239, -0.661706, -0.151733, -0.263375, -0.385646, -0.241465,
  -0.338382, -0.372682, -0.943493, 0.136617, 0.012842, 0.029892, -0.074925, -0.208847, 0.405342,
  0.004231, 0.055519, 0.071481, 0.018033, 0.191500, 0.045304, 0.041221, -0.136650, 0.210760,
  0.166410, -0.120508, 0.508104, 0.178184, 1.598157, 0.298966, 0.152008, 0.313482, 0.096725,
  -0.332725, -0.235248, -0.367853, 0.387821, 1.505949, 0.221175, 0.037196, 0.385318, 0.116745,
  -0.028348, 0.000000, -0.194732, 0.000000, -0.075656, -0.071698, -0.109154, -0.001476, -0.526348,
  -0.082391, 0.088827, -0.146321, 0.008105, -0.285045, -0.370339, 0.048196, -0.592527, -1.076060,
  -0.369623, 0.342288, -0.301225, 0.070600, -0.461966, -1.006657, 0.005379, -0.174992, -1.005354,
  0.000000, 0.011553, 0.000000, 0.000000, -0.072949, 0.007133, 0.000000, -0.033343, 0.000000,
  0.000000, -0.708828, 0.007319, -0.072949, -0.404146, -0.626598, 0.000000, -0.261085, -0.438397,
  0.000000, -0.551791, -0.188729, 0.007133, -0.626598, -0.386880, 0.000000, -0.300622, -0.541547,
  0.000000, -0.265399, -0.046754, -0.038474, -1.235634, -1.077871, 0.000000, -0.588251, -0.423201,
  -0.806551, -1.366993, -0.924025, -1.235634, -1.680998, -1.003255, -0.573117, -1.143463, -1.358046,
  -0.098914, -1.137821, -0.931273, -1.077871, -1.003255, -0.685921, -0.100249, -0.681596, -0.994546,
  0.000000, -0.182677, -0.370377, 0.000000, -0.297955, -0.804985, 0.000000, -0.159934, -0.601307,
  0.000000, -0.289202, -0.763789, -0.297955, 0.049691, 0.030900, -0.039545, -0.133837, -0.452859,
  0.000000, -0.280205, -1.110158, -0.804985, 0.030900, -0.187039, 0.000000, -0.201375, -0.067973,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.012430, 0.024627, -0.016153, -0.029347,
  0.000000, -0.055625, -0.578099, 0.000000, -0.057333, -0.096429, -0.009494, -0.182965, -0.273169,
  0.000000, 0.040980, -0.064343, 0.000000, 0.000000, -0.143614, 0.010781, 0.026022, -0.644148,
  0.000000, 0.037140, -0.345191, 0.000000, -0.026103, 0.133090, -0.015090, 0.085359, -0.260603,
  -0.221879, -0.182717, -0.509469, -0.030939, -0.064014, 0.518088, -0.228742, -0.335318, -0.246949,
  0.141829, 0.473668, -0.629371, 0.018012, -0.060188, 0.119695, 0.054055, -0.494524, -0.317050,
  0.000000, 0.000000, -0.412937, 0.000000, 0.000000, 0.015038, 0.000000, -0.045388, 0.153852,
  -0.549688, -0.428288, -1.436563, -0.009203, -0.031968, 0.241299, -0.273300, 0.257860, 0.030669,
  -0.367678, -0.664814, -1.225381, 0.005023, 0.297879, 0.474665, -0.242227, -0.099582, 0.076715,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.084334, 0.052203,
  -0.445410, -0.343423, -0.012351, -0.012703, 0.685355, -0.139475, -0.047090, 0.340895, -0.100052,
  -0.172575, -0.285729, -0.404830, 0.075202, 0.329262, -0.100464, -0.081586, 0.044282, -0.059995,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.261179, -0.109377, -0.630346,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.114720, -0.385959, -0.880099,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.033343, -0.261085, -0.300622, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, -0.438397, -0.541547, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, -0.573117, -0.100249, 0.000000, -0.458488, -0.002921,
  0.000000, -0.310954, -0.100566, -0.588251, -1.143463, -0.681596, -0.458488, -0.448328, -0.442105,
  0.000000, -0.261853, -0.375323, -0.423201, -1.358046, -0.994546, -0.002921, -0.442105, -0.301363,
  0.000000, 0.000000, 0.000000, 0.000000, -0.039545, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.159934, -0.133837, -0.201375, 0.000000, 0.008505, -0.229008,
  0.000000, 0.000000, 0.000000, -0.601307, -0.452859, -0.067973, 0.000000, -0.229008, -0.014874,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.031306, -0.124475,
  -0.049096, 0.091695, -0.414937, 0.000000, 0.111783, -0.009421, -0.011982, -0.240762, -0.393073,
  0.155953, 0.432231, -0.962840, 0.000000, -0.309725, 0.005115, 0.010248, -0.220967, -0.603657,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.032714, -0.016690, -0.043130, 0.022846, -0.024898, 0.002940, -0.091738, -0.072009, -0.155059,
  0.035936, 0.026822, -0.200222, 0.027774, -0.017354, -0.113499, -0.272261, 0.327146, 0.022580,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.037012, 0.316129, 0.000000, 0.430238, 0.287426, 0.000000, 0.008905, -0.117997,
  0.141309, -0.169311, 0.115144, 0.055658, 0.664811, 0.024459, 0.050365, 0.189807, 0.357959,
  -0.203255, -0.250797, -0.505145, -0.195023, 0.674651, 0.151235, -0.014179, 0.004725, -0.798486,
  0.000000, 0.000000, -0.101301, 0.000000, 0.022062, -0.165781, 0.000000, 0.000000, -0.072531,
  0.000000, -0.021450, 0.131270, 0.000000, -0.133752, -0.375249, 0.000000, -0.031699, -0.795827,
  0.000000, -0.023847, 0.405185, 0.000000, -0.264071, -0.966894, 0.000000, 0.013621, -0.709879,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, -0.055625, 0.040980, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, -0.578099, -0.064343, 0.000000, 0.000000, 0.000000,
  0.000000, 0.074190, -0.000359, 0.000000, -0.221879, 0.141829, 0.000000, -0.049096, 0.155953,
  0.000000, 0.191108, -0.010234, 0.037140, -0.182717, 0.473668, 0.000000, 0.091695, 0.432231,
  0.000000, -0.552932, -0.768866, -0.345191, -0.509469, -0.629371, 0.000000, -0.414937, -0.962840,
  0.000000, -0.216310, -0.243410, 0.000000, -0.549688, -0.367678, 0.000000, 0.032714, 0.035936,
  0.000000, -0.045244, -0.121586, 0.000000, -0.428288, -0.664814, 0.000000, -0.016690, 0.026822,
  0.000000, -0.523190, -0.927550, -0.412937, -1.436563, -1.225381, 0.000000, -0.043130, -0.200222,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.005040, 0.037990, 0.000000, -0.039421, 0.019273, 0.000000, -0.027326, 0.249330,
  0.005040, 0.095029, -0.013998, 0.000000, -0.035788, 0.067402, 0.003653, 0.305944, 0.223547,
  0.037990, -0.013998, -0.456299, -0.005923, 0.007145, 0.005159, -0.049932, -0.164541, -0.397783,
  0.000000, 0.000000, -0.313048, 0.000000, 0.000000, 0.051925, 0.000000, 0.034027, 0.232790,
  0.000000, -0.019329, -0.422895, 0.000000, 0.178999, 0.064834, 0.000000, -0.133946, 0.317913,
  -0.313048, -0.422895, -1.065908, -0.079052, -0.073429, -0.369866, -0.068655, -0.042795, -0.091397,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.029196, 0.000000, -0.030859, 0.007816, 0.000000, 0.000000, -0.043858,
  0.039121, 0.005197, 0.007497, -0.006354, -0.001047, -0.012730, 0.007957, 0.012924, 0.116278,
  -0.088911, 0.038897, -0.058494, -0.080226, 0.076392, -0.010173, -0.111426, -0.101462, -0.017796,
  0.000000, 0.000000, -0.080699, 0.000000, 0.000000, 0.038990, 0.000000, 0.000000, 0.178975,
  0.000000, 0.055105, 0.152598, 0.000000, -0.015975, -0.213227, 0.000000, -0.040957, -0.359018,
  0.000000, 0.011927, -0.049567, 0.000000, -0.029096, -0.354608, 0.000000, -0.023221, -0.733639,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, -0.057333, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.012430, -0.096429, -0.143614, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, -0.030939, 0.018012, 0.000000, 0.000000, 0.000000,
  0.000000, -0.151631, 0.103783, -0.026103, -0.064014, -0.060188, 0.000000, 0.111783, -0.309725,
  0.000000, -0.024082, -0.015322, 0.133090, 0.518088, 0.119695, 0.000000, -0.009421, 0.005115,
  0.000000, -0.010901, 0.057337, 0.000000, -0.009203, 0.005023, 0.000000, 0.022846, 0.027774,
  0.000000, -0.028104, -0.040592, 0.000000, -0.031968, 0.297879, 0.000000, -0.024898, -0.017354,
  0.000000, -0.058768, -0.075427, 0.015038, 0.241299, 0.474665, 0.000000, 0.002940, -0.113499,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, -0.005923, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.025549,
  -0.039421, -0.035788, 0.007145, 0.000000, 0.008856, 0.046143, 0.020574, 0.017153, -0.003173,
  0.019273, 0.067402, 0.005159, 0.000000, 0.046143, 0.000000, -0.037202, 0.028986, -0.013202,
  0.000000, 0.000000, -0.079052, 0.000000, 0.000000, 0.052800, 0.000000, 0.000000, 0.076017,
  0.000000, 0.178999, -0.073429, 0.000000, 0.013406, 0.046073, 0.000000, -0.054131, 0.314890,
  0.051925, 0.064834, -0.369866, 0.052800, 0.046073, 0.249454, -0.120945, -0.018372, 0.486061,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.171079, -0.153253, 0.024697, -0.000931, 0.063435, 0.262487, 0.091187, -0.022410, 0.226921,
  -0.041945, 0.059824, 0.022148, -0.053363, 0.303152, 0.283393, 0.051651, 0.107358, 0.086398,
  -0.416829, -0.211406, -0.420507, -0.104871, 0.659502, -0.261831, -0.312115, 0.021695, -0.498754,
  0.000000, 0.000000, -0.033866, 0.000000, 0.005207, 0.070791, -0.011478, -0.038960, 0.005112,
  0.000000, -0.017245, -0.005781, 0.000000, -0.120091, -0.320025, 0.008648, -0.104429, -0.607942,
  0.000000, -0.221434, -0.003072, 0.000000, -0.665609, -0.888436, 0.209322, -0.209647, -0.930992,
  0.000000, 0.000000, 0.000000, 0.024627, -0.009494, 0.010781, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.016153, -0.182965, 0.026022, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.029347, -0.273169, -0.644148, 0.000000, 0.000000, 0.000000,
  0.000000, -0.177523, 0.014597, -0.015090, -0.228742, 0.054055, 0.000000, -0.011982, 0.010248,
  0.000000, -0.158831, -0.530343, 0.085359, -0.335318, -0.494524, 0.031306, -0.240762, -0.220967,
  0.000000, -0.560975, -0.547662, -0.260603, -0.246949, -0.317050, -0.124475, -0.393073, -0.603657,
  0.000000, 0.013189, -0.102570, 0.000000, -0.273300, -0.242227, 0.000000, -0.091738, -0.272261,
  0.000000, 0.064721, -0.132190, -0.045388, 0.257860, -0.099582, 0.000000, -0.072009, 0.327146,
  0.000000, -0.176414, -0.068605, 0.153852, 0.030669, 0.076715, 0.000000, -0.155059, 0.022580,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.003653, -0.049932, 0.000000, 0.020574, -0.037202, 0.000000, 0.009704, -0.020683,
  -0.027326, 0.305944, -0.164541, 0.000000, 0.017153, 0.028986, 0.009704, 0.007557, -0.002239,
  0.249330, 0.223547, -0.397783, 0.025549, -0.003173, -0.013202, -0.020683, -0.002239, -0.309221,
  0.000000, 0.000000, -0.068655, 0.000000, 0.000000, -0.120945, 0.000000, 0.057779, 0.179955,
  0.034027, -0.133946, -0.042795, 0.000000, -0.054131, -0.018372, 0.057779, 0.034602, 0.001995,
  0.232790, 0.317913, -0.091397, 0.076017, 0.314890, 0.486061, 0.179955, 0.001995, 0.299897,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.057198, -0.099238, 0.321776, -0.094633, -0.219283, 0.303578, 0.055901, -0.003104, 0.296873,
  -0.099238, -0.342473, -0.248545, 0.053108, 0.412484, 0.041751, 0.096158, 0.475895, -0.561178,
  0.321776, -0.248545, 0.279848, -0.213835, -0.328005, -0.451844, -0.065186, 0.114557, 0.219421,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.020985, 0.001305, 0.066558, 0.111341, 0.406855, 0.049782, 0.012081, -0.005699, -0.162774,
  0.000000, 0.063855, 0.316085, 0.000000, 0.148296, -0.056688, 0.000000, 0.021456, -0.108802,
  0.000000, 0.105318, -0.097130, 0.007522, 0.305455, -0.193029, 0.000000, 0.255010, -0.037835,
  -0.157851, 0.864494, -0.006246, 0.176205, 0.736034, 0.173651, 0.000652, 0.046652, -0.041596,
  0.055925, -0.016433, 0.219032, -0.064738, 0.444190, -0.142298, 0.000000, -0.114422, 0.117011,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.031027, 0.211850, 0.568785,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.010497, 0.426497, 0.645334,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.047022, 0.273952, -0.251699,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.076633, 0.009843,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.502585, 0.126744, -0.516145,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.230989, 0.744164,
  0.000000, 0.141083, 0.581944, 0.000000, -0.025159, -0.092395, 0.026404, 0.353069, 0.285292,
  0.000000, 0.199930, 0.141076, 0.000000, 0.569073, 0.369418, 0.200446, 1.261755, -0.119487,
  0.000000, 0.140366, 1.006994, 0.000000, 0.316261, 0.052819, 0.107654, 0.331038, 0.250359,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.056408, -0.126296, 0.093494, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, -0.126296, -0.673189, 0.030250, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.093494, 0.030250, 0.340211, 0.000000, 0.000000, 0.000000,
  -0.094633, 0.053108, -0.213835, 0.141437, -0.047968, 0.518164, -0.020036, 0.208871, 0.248878,
  -0.219283, 0.412484, -0.328005, -0.047968, 0.861985, 0.025999, 0.232943, 0.566795, -0.053754,
  0.303578, 0.041751, -0.451844, 0.518164, 0.025999, -0.109160, 0.014946, -0.056337, 0.432706,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.049696, 0.171992, 0.036661, 0.000000, 0.000000, 0.000000,
  0.328872, 0.516830, 0.140786, 0.132213, 0.393720, 0.078828, -0.039863, 0.370927, 0.079525,
  0.000000, -0.000577, 0.186073, 0.011917, 0.191694, 0.011030, 0.000000, 0.009271, 0.092261,
  0.000000, 0.004805, 0.011506, -0.035456, 0.113414, 0.232669, 0.000000, 0.083100, 0.066654,
  -0.072554, 0.614628, -0.415137, -0.166641, 0.339303, -0.266055, 0.014666, 0.009450, -0.002833,
  0.037564, 0.110531, -0.330836, 0.036239, -0.206129, -0.055134, 0.000000, -0.032443, -0.010958,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.017252, -0.183024, 0.375758,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.007723, -0.216636, 0.769381,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.284289, 0.560819,
  0.000000, 0.000000, 0.000000, 0.000000, 0.025230, 0.102701, 0.007687, 0.092379, -0.080143,
  0.000000, 0.000000, 0.000000, 0.000000, 0.542831, 0.372643, 0.665187, 0.397464, 0.922876,
  0.000000, 0.000000, 0.000000, 0.000000, 0.009677, 0.107090, 0.027870, 0.164766, 0.452846,
  0.000000, 0.055875, 0.256798, 0.000000, 0.008212, 0.123300, -0.001070, 0.156264, 0.102857,
  0.000000, 0.333823, 0.546754, 0.178207, 0.666585, 0.325625, 0.213313, 0.650776, 0.017660,
  0.000000, 0.062620, 0.278741, 0.283295, 0.104401, 0.233419, -0.140575, -0.286793, -0.320716,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.055901, 0.096158, -0.065186, -0.020036, 0.232943, 0.014946, 0.040880, 0.092024, 0.271345,
  -0.003104, 0.475895, 0.114557, 0.208871, 0.566795, -0.056337, 0.092024, 0.215240, 0.446364,
  0.296873, -0.561178, 0.219421, 0.248878, -0.053754, 0.432706, 0.271345, 0.446364, 0.616954,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.343472, 0.844971, 0.296103, 0.164405, 1.112286, 0.067570, 0.007422, 0.420692, -0.016865,
  0.141825, 0.409179, 0.214721, 0.293276, 0.478323, 0.059734, 0.000000, -0.054880, 0.085821,
  0.000000, 0.083746, 0.005852, 0.011150, 0.345528, 0.041200, 0.000000, 0.255363, 0.038692,
  0.060687, -0.133384, -0.210279, 0.002769, 0.109020, -0.149128, 0.002961, 0.081226, 0.005337,
  -0.644620, -0.993175, -0.843661, -0.184221, -0.835680, -0.474990, -0.211073, 0.154125, -0.122680,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.001351, -0.171003, 0.374803,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.224088, 0.321923,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.003597, 0.459192, 0.776002,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.234558, -0.039963,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.253665, 0.379202, 0.410385,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.010476, 0.568011, 0.490738,
  0.000000, 0.002127, 0.215559, 0.000000, 0.037996, -0.035539, 0.084523, -0.352822, 0.002021,
  0.000000, -0.009656, 0.413056, 0.000000, 0.261007, 0.170766, -0.303499, -0.240902, 0.098614,
  0.000000, -0.538050, -0.047440, 0.000000, -0.264096, -0.176289, -0.395010, -1.378168, -1.138430,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, -0.020985, 0.000000, 0.000000, 0.328872, 0.000000, 0.000000, 0.343472, 0.141825,
  0.000000, 0.001305, 0.063855, 0.000000, 0.516830, -0.000577, 0.000000, 0.844971, 0.409179,
  0.000000, 0.066558, 0.316085, 0.000000, 0.140786, 0.186073, 0.000000, 0.296103, 0.214721,
  0.000000, -0.157851, 0.055925, 0.000000, -0.072554, 0.037564, 0.000000, 0.060687, -0.644620,
  0.105318, 0.864494, -0.016433, 0.004805, 0.614628, 0.110531, 0.083746, -0.133384, -0.993175,
  -0.097130, -0.006246, 0.219032, 0.011506, -0.415137, -0.330836, 0.005852, -0.210279, -0.843661,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.088523, 0.000000, 0.000000, -0.085063, 0.036582, 0.000000, 0.151573, -0.013118,
  0.088523, 1.185321, 0.194386, 0.126929, 0.180341, 0.128730, 0.077953, 0.844313, 0.058142,
  0.000000, 0.194386, 0.009220, 0.000000, 0.124992, 0.032804, 0.000000, 0.113367, 0.098511,
  0.000000, -0.036535, -0.023438, 0.000000, -0.018757, -0.138079, 0.000000, 0.005133, 0.057577,
  -0.036535, 0.046246, -0.014380, 0.139518, 0.549216, 0.258473, -0.020776, 0.052792, 0.028687,
  -0.023438, -0.014380, -0.177570, -0.033227, -0.086423, -0.146958, 0.000000, -0.005518, 0.025847,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.002393, 0.610628, 0.853689,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.075968, 0.194455,
  0.000000, 0.393515, 0.100229, 0.000000, 0.162339, 0.033819, 0.000000, 1.003755, 0.559902,
  0.000000, 0.707671, 0.546896, 0.000000, 0.134863, 0.066524, 0.406668, 1.309458, 1.443997,
  0.000000, 0.095586, 0.202236, 0.000000, 0.062396, 0.026785, 0.000000, 0.258391, 0.743894,
  0.000000, -0.049763, 0.060869, 0.000000, 0.032131, 0.193246, 0.000000, -0.402307, 0.200022,
  0.000000, 0.191994, 0.742584, 0.000000, 0.854200, 0.616365, 0.459608, -0.117513, 0.118946,
  0.000000, 0.178689, 0.094384, 0.000000, -0.273054, -0.125933, 0.000868, 0.263794, 0.330796,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.111341, 0.000000, 0.049696, 0.132213, 0.011917, 0.000000, 0.164405, 0.293276,
  0.000000, 0.406855, 0.148296, 0.171992, 0.393720, 0.191694, 0.000000, 1.112286, 0.478323,
  0.000000, 0.049782, -0.056688, 0.036661, 0.078828, 0.011030, 0.000000, 0.067570, 0.059734,
  0.007522, 0.176205, -0.064738, -0.035456, -0.166641, 0.036239, 0.011150, 0.002769, -0.184221,
  0.305455, 0.736034, 0.444190, 0.113414, 0.339303, -0.206129, 0.345528, 0.109020, -0.835680,
  -0.193029, 0.173651, -0.142298, 0.232669, -0.266055, -0.055134, 0.041200, -0.149128, -0.474990,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.126929, 0.000000, 0.000000, -0.066551, -0.092407, 0.000000, -0.024156, 0.000000,
  -0.085063, 0.180341, 0.124992, -0.066551, 0.063524, -0.064855, 0.072943, -0.338847, -0.084693,
  0.036582, 0.128730, 0.032804, -0.092407, -0.064855, 0.017074, 0.000000, -0.095405, -0.025731,
  0.000000, 0.139518, -0.033227, 0.000000, -0.152464, -0.063421, 0.000000, 0.011444, -0.018852,
  -0.018757, 0.549216, -0.086423, -0.152464, 0.345424, -0.167334, -0.005888, -0.042298, 0.023761,
  -0.138079, 0.258473, -0.146958, -0.063421, -0.167334, 0.018399, 0.000000, 0.127561, 0.075114,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.008085, 0.073812,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.010912, 0.174345, 0.483004,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.197545, 0.035041,
  0.000000, 0.139354, 0.224930, 0.000000, 0.196276, 0.003444, 0.000000, 0.339828, 0.142046,
  0.000000, 0.043352, 0.439324, 0.000000, 0.065513, 0.319653, -0.042349, -0.043509, 0.041711,
  0.000000, -0.012959, 0.051137, 0.000000, 0.075595, -0.041386, -0.027212, -0.201416, -0.138321,
  0.000000, 0.037537, 0.121361, 0.000000, 0.030798, 0.021658, -0.001214, -0.032395, 0.434315,
  0.000000, 0.750435, 0.394522, -0.078629, 0.385245, 0.389707, 0.043619, 0.193273, 0.185537,
  0.000000, 0.619859, 0.338341, -0.036851, 0.355705, 0.538336, -0.124984, -0.124849, 0.781263,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.012081, 0.000000, 0.000000, -0.039863, 0.000000, 0.000000, 0.007422, 0.000000,
  0.000000, -0.005699, 0.021456, 0.000000, 0.370927, 0.009271, 0.000000, 0.420692, -0.054880,
  0.000000, -0.162774, -0.108802, 0.000000, 0.079525, 0.092261, 0.000000, -0.016865, 0.085821,
  0.000000, 0.000652, 0.000000, 0.000000, 0.014666, 0.000000, 0.000000, 0.002961, -0.211073,
  0.255010, 0.046652, -0.114422, 0.083100, 0.009450, -0.032443, 0.255363, 0.081226, 0.154125,
  -0.037835, -0.041596, 0.117011, 0.066654, -0.002833, -0.010958, 0.038692, 0.005337, -0.122680,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.077953, 0.000000, 0.000000, 0.072943, 0.000000, 0.000000, 0.011564, 0.000000,
  0.151573, 0.844313, 0.113367, -0.024156, -0.338847, -0.095405, 0.011564, -0.059782, 0.004834,
  -0.013118, 0.058142, 0.098511, 0.000000, -0.084693, -0.025731, 0.000000, 0.004834, 0.022102,
  0.000000, -0.020776, 0.000000, 0.000000, -0.005888, 0.000000, 0.000000, -0.000607, 0.000000,
  0.005133, 0.052792, -0.005518, 0.011444, -0.042298, 0.127561, -0.000607, 0.024604, 0.026652,
  0.057577, 0.028687, 0.025847, -0.018852, 0.023761, 0.075114, 0.000000, 0.026652, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.030715, 0.077178,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.086949,
  0.000000, 0.012714, -0.005147, 0.000000, 0.034365, -0.012173, 0.000000, -0.017347, -0.070813,
  0.000000, 0.035960, 0.065081, 0.000000, -0.011165, 0.011107, 0.010054, -0.120087, 0.183454,
  0.000000, 0.005677, 0.014298, 0.000000, 0.072873, -0.010899, 0.000000, -0.019026, 0.184999,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.044011, 0.030105,
  0.000000, 0.002453, -0.081375, 0.000000, 0.018664, 0.037486, -0.095917, 0.220033, 0.157140,
  0.000000, 0.100269, 0.240793, 0.000000, 0.044446, 0.130728, 0.104163, -0.003836, 0.461640,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.141083, 0.199930, 0.140366, 0.055875, 0.333823, 0.062620, 0.002127, -0.009656, -0.538050,
  0.581944, 0.141076, 1.006994, 0.256798, 0.546754, 0.278741, 0.215559, 0.413056, -0.047440,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.393515, 0.707671, 0.095586, 0.139354, 0.043352, -0.012959, 0.012714, 0.035960, 0.005677,
  0.100229, 0.546896, 0.202236, 0.224930, 0.439324, 0.051137, -0.005147, 0.065081, 0.014298,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  -0.049763, 0.191994, 0.178689, 0.037537, 0.750435, 0.619859, 0.000000, 0.002453, 0.100269,
  0.060869, 0.742584, 0.094384, 0.121361, 0.394522, 0.338341, 0.000000, -0.081375, 0.240793,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.353784, 0.051882,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -0.000498, 0.589863, 0.607915,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.193803, 0.412361, 0.686931,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.210135, 0.391830, 0.207603,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.266480, 0.957741,
  0.000000, 0.085940, 0.143069, 0.000000, 0.225124, 0.036788, 0.087108, -0.082817, 0.472977,
  0.000000, 0.143069, 0.251409, 0.000000, 0.297059, 0.188921, 0.638910, 1.150891, 1.445578,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.025230, 0.542831, 0.009677, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.102701, 0.372643, 0.107090, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.178207, 0.283295, 0.000000, 0.000000, 0.000000,
  -0.025159, 0.569073, 0.316261, 0.008212, 0.666585, 0.104401, 0.037996, 0.261007, -0.264096,
  -0.092395, 0.369418, 0.052819, 0.123300, 0.325625, 0.233419, -0.035539, 0.170766, -0.176289,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.162339, 0.134863, 0.062396, 0.196276, 0.065513, 0.075595, 0.034365, -0.011165, 0.072873,
  0.033819, 0.066524, 0.026785, 0.003444, 0.319653, -0.041386, -0.012173, 0.011107, -0.010899,
  0.000000, 0.000000, 0.000000, 0.000000, -0.078629, -0.036851, 0.000000, 0.000000, 0.000000,
  0.032131, 0.854200, -0.273054, 0.030798, 0.385245, 0.355705, 0.000000, 0.018664, 0.044446,
  0.193246, 0.616365, -0.125933, 0.021658, 0.389707, 0.538336, 0.000000, 0.037486, 0.130728,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.364052, 0.298068,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.004351, 0.515036, 0.433192,
  0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.054480, 0.006798,
  0.000000, 0.000000, 0.000000, 0.000000, -0.012946, 0.095584, 0.056464, 0.414108, 0.345573,
  0.000000, 0.000000, 0.000000, 0.000000, 0.095584, -0.011471, 0.043502, 0.000879, 0.055936,
  0.000000, 0.000000, 0.000000, 0.000000, 0.122317, 0.085133, 0.000000, 0.149197, 0.665309,
  0.000000, 0.225124, 0.297059, 0.122317, 0.045371, 0.458387, 0.292284, 0.524994, 1.256600,
  0.000000, 0.036788, 0.188921, 0.085133, 0.458387, 0.229961, 0.279934, 0.560029, 1.100163,
  0.031027, 0.010497, 0.047022, 0.017252, 0.007723, 0.000000, -0.001351, 0.000000, 0.003597,
  0.211850, 0.426497, 0.273952, -0.183024, -0.216636, 0.284289, -0.171003, 0.224088, 0.459192,
  0.568785, 0.645334, -0.251699, 0.375758, 0.769381, 0.560819, 0.374803, 0.321923, 0.776002,
  0.000000, 0.502585, 0.000000, 0.007687, 0.665187, 0.027870, 0.000000, 0.253665, -0.010476,
  0.076633, 0.126744, 0.230989, 0.092379, 0.397464, 0.164766, 0.234558, 0.379202, 0.568011,
  0.009843, -0.516145, 0.744164, -0.080143, 0.922876, 0.452846, -0.039963, 0.410385, 0.490738,
  0.026404, 0.200446, 0.107654, -0.001070, 0.213313, -0.140575, 0.084523, -0.303499, -0.395010,
  0.353069, 1.261755, 0.331038, 0.156264, 0.650776, -0.286793, -0.352822, -0.240902, -1.378168,
  0.285292, -0.119487, 0.250359, 0.102857, 0.017660, -0.320716, 0.002021, 0.098614, -1.138430,
  0.000000, 0.002393, 0.000000, 0.000000, 0.010912, 0.000000, 0.000000, 0.000000, 0.000000,
  0.000000, 0.610628, 0.075968, 0.008085, 0.174345, 0.197545, 0.000000, -0.030715, 0.000000,
  0.000000, 0.853689, 0.194455, 0.073812, 0.483004, 0.035041, 0.000000, 0.077178, 0.086949,
  0.000000, 0.406668, 0.000000, 0.000000, -0.042349, -0.027212, 0.000000, 0.010054, 0.000000,
  1.003755, 1.309458, 0.258391, 0.339828, -0.043509, -0.201416, -0.017347, -0.120087, -0.019026,
  0.559902, 1.443997, 0.743894, 0.142046, 0.041711, -0.138321, -0.070813, 0.183454, 0.184999,
  0.000000, 0.459608, 0.000868, -0.001214, 0.043619, -0.124984, 0.000000, -0.095917, 0.104163,
  -0.402307, -0.117513, 0.263794, -0.032395, 0.193273, -0.124849, -0.044011, 0.220033, -0.003836,
  0.200022, 0.118946, 0.330796, 0.434315, 0.185537, 0.781263, 0.030105, 0.157140, 0.461640,
  0.000000, 0.000000, -0.000498, 0.000000, 0.000000, 0.004351, 0.000000, 0.009905, 0.132656,
  0.000000, 0.353784, 0.589863, 0.000000, 0.364052, 0.515036, 0.009905, -0.010406, 0.446475,
  0.000000, 0.051882, 0.607915, 0.000000, 0.298068, 0.433192, 0.132656, 0.446475, -0.092272,
  0.000000, 0.193803, 0.210135, 0.000000, 0.056464, 0.043502, 0.000000, 0.497762, 0.183611,
  0.000000, 0.412361, 0.391830, 0.054480, 0.414108, 0.000879, 0.497762, 0.143288, 0.031899,
  0.000000, 0.686931, 0.207603, 0.006798, 0.345573, 0.055936, 0.183611, 0.031899, -0.255459,
  0.000000, 0.087108, 0.638910, 0.000000, 0.292284, 0.279934, 0.000000, 0.601197, 0.846803,
  0.266480, -0.082817, 1.150891, 0.149197, 0.524994, 0.560029, 0.601197, 0.219085, 0.543662,
  0.957741, 0.472977, 1.445578, 0.665309, 1.256600, 1.100163, 0.846803, 0.543662, 1.141693,
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


func _on_RestartButton_pressed():
	if !game_over: return
	cp_hist = []	# 着手履歴初期化
	init_bb()		# 盤面データ初期化
	init_bd_array()		#	盤面TileMap初期化
	update_TileMap()
	update_cursor()
	update_nextTurn()
	waiting = 6
	pass # Replace with function body.

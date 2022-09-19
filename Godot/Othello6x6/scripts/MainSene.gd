extends Node2D

enum {
	EMPTY = 0, BLACK, WHITE, WALL,
}
enum {
	DID_PUT = 0, CAN_PUT, 
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

var BOARD_ORG_X
var BOARD_ORG_Y
var BOARD_ORG
var CELL_WD
var CELL_HT
var BOARD_WIDTH
var BOARD_HEIGHT

var AI_color = WHITE
var man_color = BLACK
var next_color = BLACK
var next_pass = false
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
var putIX = 0
var pressedPos = Vector2(0, 0)

var bb_black
var bb_white


func _ready():
	BOARD_ORG_X = $Board/TileMap.global_position.x
	BOARD_ORG_Y = $Board/TileMap.global_position.y
	BOARD_ORG = Vector2(BOARD_ORG_X, BOARD_ORG_Y)
	print("BOARD_ORG = ", BOARD_ORG)
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
	#
	print(get_pat_indexes())
func update_humanAIColor():
	$HumanBG/Black.set_visible(AI_color == WHITE)
	$HumanBG/White.set_visible(AI_color != WHITE)
	$AIBG/Black.set_visible(AI_color != WHITE)
	$AIBG/White.set_visible(AI_color == WHITE)
#
func xyToBit(x, y):		# 0 <= x, y < 6
	return 1<<int(N_CELL_HORZ-1-x + 8*(N_CELL_VERT-1-y))
func init_bb():
	bb_black = C4_BIT | D3_BIT
	bb_white = C3_BIT | D4_BIT
func bb_get_color(black:int, white:int, x, y):
	var bit = xyToBit(x, y)
	if (black & bit) != 0: return BLACK
	if (white & bit) != 0: return WHITE
	return EMPTY
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
	return (bb_get_revbits_dir(black, white, pos, DIR_UL) |
			bb_get_revbits_dir(black, white, pos, DIR_U) |
			bb_get_revbits_dir(black, white, pos, DIR_UR) |
			bb_get_revbits_dir(black, white, pos, DIR_L) |
			bb_get_revbits_dir(black, white, pos, DIR_R) |
			bb_get_revbits_dir(black, white, pos, DIR_DL) |
			bb_get_revbits_dir(black, white, pos, DIR_D) |
			bb_get_revbits_dir(black, white, pos, DIR_DR))
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
	putIX = 0
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
	print("next_color = ", next_color)
	for y in range(N_CELL_VERT):
		for x in range(N_CELL_HORZ):
			var id = TRANSPARENT
			if xyToArrayIX(x, y) == putIX:
				id = DID_PUT
			#elif( next_color == BLACK && canPutBlack(x, y) ||
			#		next_color == WHITE && canPutWhite(x, y) ):
			elif( next_color == BLACK && bb_can_put_black(bb_black, bb_white, xyToBit(x, y)) ||
					next_color == WHITE && bb_can_put_black(bb_white, bb_black, xyToBit(x, y)) ):
				id = CAN_PUT
			$Board/CursorTileMap.set_cell(x, y, id)
func update_nextTurn():
	$HumanBG/Underline.set_visible(next_color != AI_color)
	$AIBG/Underline.set_visible(next_color == AI_color)
#
func thinkAI_random():
	if game_over:
		return
	var lst = Array()
	for y in range(N_CELL_VERT):
		for x in range(N_CELL_HORZ):
			if( next_color == WHITE && canPutWhite(x, y) ||
					next_color == BLACK && canPutBlack(x, y) ):
				lst.push_back(xyToArrayIX(x, y))
	if lst.empty():
		return 0
	rng.randomize()
	var r = rng.randi_range(0, lst.size() - 1)
	return lst[r]
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
#
func _process(delta):
	if !AI_thinking && next_color == AI_color:
		AI_thinking = true
		putIX = thinkAI_random()
		#putWhiteIX(putIX)
		var x = aixToX(putIX)
		var y = aixToY(putIX)
		bb_put_white(xyToBit(x, y))
		next_color = BLACK
		update_TileMap()
		update_cursor()
		update_nextTurn()
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
			if pos == pressedPos:
				if next_color == BLACK:
					#if !canPutBlack(pos.x, pos.y): return
					#putBlack(pos.x, pos.y)
					bb_put_black(xyToBit(pos.x, pos.y))
					next_color = WHITE
				else:	#if next_color == WHITE:
					#if !canPutWhite(pos.x, pos.y): return
					#putWhite(pos.x, pos.y)
					bb_put_white(xyToBit(pos.x, pos.y))
					next_color = BLACK
			putIX = xyToArrayIX(pos.x, pos.y)
			update_TileMap()
			update_cursor()
			update_nextTurn()
	pass

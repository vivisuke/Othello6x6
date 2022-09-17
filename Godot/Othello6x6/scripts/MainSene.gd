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
const N_CELL_HORZ = 6
const N_CELL_VERT = 6
const ARY_WIDTH : int = N_CELL_HORZ + 1
const ARY_HEIGHT : int = N_CELL_VERT + 2
const ARY_SIZE = ARY_WIDTH * ARY_HEIGHT + 1
const xaxis = "abcdef"

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
	##update_humanAIColor()	# 人間・AI 石色表示
	init_bd_array()
	putBlack(4, 3)
	putIX = xyToArrayIX(4, 3)
	next_color = WHITE
	update_TileMap()
	update_cursor()

func xyToArrayIX(x, y):		# 0 <= x, y < 8
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
			var col = bd_array[xyToArrayIX(x, y)]
			$Board/TileMap.set_cell(x, y, col-1)
			nColors[col] += 1
	var hix = 1 if AI_color == WHITE else 2
	var aix = 1 if AI_color == BLACK else 2
	##$HumanBG/num.text = "%d" % nColors[hix]
	##$AIBG/num.text = "%d" % nColors[aix]
func update_cursor():
	for y in range(N_CELL_VERT):
		for x in range(N_CELL_HORZ):
			var id = TRANSPARENT
			if xyToArrayIX(x, y) == putIX:
				id = DID_PUT
			elif( next_color == BLACK && canPutBlack(x, y) ||
					next_color == WHITE && canPutWhite(x, y) ):
				id = CAN_PUT
			$Board/CursorTileMap.set_cell(x, y, id)
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

func _input(event):
	if event is InputEventMouseButton:
		print(event.position)
		print($Board/TileMap.world_to_map(event.position - BOARD_ORG))
		print("mouse button")
		if event.is_pressed():
			print("pressed")
		else:
			print("released")
		#elif event.is_action_released()
	pass

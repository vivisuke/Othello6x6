extends Node2D

enum {
	EMPTY = 0, BLACK, WHITE, WALL,
}
enum {
	CAN_PUT = 0, DID_PUT,
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
	CELL_WD = $Board/TileMap.cell_size.x
	CELL_HT = $Board/TileMap.cell_size.y
	BOARD_WIDTH = CELL_WD * N_CELL_HORZ
	BOARD_HEIGHT = CELL_HT * N_CELL_VERT
	#
	bd_stable.resize(ARY_SIZE)
	bd_canPutBlack.resize(ARY_SIZE)
	bd_canPutWhite.resize(ARY_SIZE)
	#
	$Board/TileMap.set_cell(2, 2, WHITE-1)
	$Board/TileMap.set_cell(3, 3, WHITE-1)
	$Board/TileMap.set_cell(2, 3, BLACK-1)
	$Board/TileMap.set_cell(3, 2, BLACK-1)
	pass # Replace with function body.

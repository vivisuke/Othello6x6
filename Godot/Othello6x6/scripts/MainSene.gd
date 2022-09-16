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

func _ready():
	$Board/TileMap.set_cell(2, 2, WHITE-1)
	$Board/TileMap.set_cell(3, 3, WHITE-1)
	$Board/TileMap.set_cell(2, 3, BLACK-1)
	$Board/TileMap.set_cell(3, 2, BLACK-1)
	pass # Replace with function body.

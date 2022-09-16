extends Node2D

const EMPTY = -1
const BLACK = 1
const WHITE = 2

func _ready():
	$Board/TileMap.set_cell(2, 2, WHITE)
	$Board/TileMap.set_cell(3, 3, WHITE)
	$Board/TileMap.set_cell(2, 3, BLACK)
	$Board/TileMap.set_cell(3, 2, BLACK)
	pass # Replace with function body.

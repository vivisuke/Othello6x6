extends Node2D

enum {
	HUMAN = 0, AI,
}

var black_player = HUMAN
var white_player = AI
var depth = 4				# 固定探索深さ

func _ready():
	pass # Replace with function body.

extends Node2D

enum {
	HUMAN = 0, AI,
	NORMAL = 0, LESS_WIN,
}

var rule = NORMAL
var black_player = HUMAN
var white_player = AI
var depth = 4				# 固定探索深さ

func _ready():
	pass # Replace with function body.

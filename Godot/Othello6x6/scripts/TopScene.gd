extends Node2D

#var g
var g = Global
#onready var g = get_node("/root/Global")

func _ready():
	#var g = get_node("/root/Global")
	$Black/Human.pressed = g.black_player == g.HUMAN
	$Black/AI.pressed = g.black_player == g.AI
	pass # Replace with function body.

func _on_GameStart_pressed():
	print("_on_GameStart_pressed()")
	get_tree().change_scene("res://MainScene.tscn")

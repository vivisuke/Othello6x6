extends Node2D

#var g
var g = Global
#onready var g = get_node("/root/Global")

func _ready():
	#var g = get_node("/root/Global")
	update_black_white_player()

func update_black_white_player():
	$Rule/Normal.pressed = g.rule == g.NORMAL
	$Rule/LessWin.pressed = g.rule == g.LESS_WIN
	$Black/Human.pressed = g.black_player == g.HUMAN
	$Black/AI.pressed = g.black_player == g.AI
	$White/Human.pressed = g.white_player == g.HUMAN
	$White/AI.pressed = g.white_player == g.AI

func _on_GameStart_pressed():
	print("_on_GameStart_pressed()")
	get_tree().change_scene("res://MainScene.tscn")


func _on_Black_Human_toggled(button_pressed):
	g.black_player = g.HUMAN if button_pressed else g.AI
	update_black_white_player()


func _on_Black_AI_toggled(button_pressed):
	g.black_player = g.AI if button_pressed else g.HUMAN
	update_black_white_player()


func _on_White_Human_toggled(button_pressed):
	g.white_player = g.HUMAN if button_pressed else g.AI
	update_black_white_player()


func _on_White_AI_toggled(button_pressed):
	g.white_player = g.AI if button_pressed else g.HUMAN
	update_black_white_player()


func _on_Normal_toggled(button_pressed):
	g.rule = g.NORMAL if button_pressed else g.LESS_WIN
	update_black_white_player()


func _on_LessWin_toggled(button_pressed):
	g.rule = g.LESS_WIN if button_pressed else g.NORMAL
	update_black_white_player()

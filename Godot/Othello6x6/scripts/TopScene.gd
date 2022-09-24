extends Node2D


func _ready():
	pass # Replace with function body.

func _on_GameStart_pressed():
	print("_on_GameStart_pressed()")
	get_tree().change_scene("res://MainScene.tscn")

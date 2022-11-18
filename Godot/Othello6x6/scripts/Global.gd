extends Node2D

enum {
	HUMAN = 0, AI,          # プレイヤータイプ
	NORMAL = 0, LESS_WIN,   # ゲームルール
}

var rule = NORMAL           # ゲームルール
var black_player = HUMAN    # 黒番プレイヤー
var white_player = AI       # 白番プレイヤー
var depth = 4               # 固定探索深さ

func _ready():
	pass # Replace with function body.

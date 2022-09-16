extends ColorRect


func _ready():
	pass # Replace with function body.

func _draw():
	draw_rect(Rect2(0, 0, 500, 500), Color.black)
	draw_rect(Rect2(25, 25, 75*6, 75*6), Color.darkgreen)
	for x in range(1, 6):
		draw_line(Vector2(25+x*75, 25), Vector2(25+x*75, 25+75*6), Color.black, 1)
		draw_line(Vector2(25, 25+x*75), Vector2(25+75*6, 25+x*75), Color.black, 1)
	pass

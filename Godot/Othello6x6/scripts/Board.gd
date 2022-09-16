extends ColorRect

const R = 6

func _ready():
	for x in range(6):
		var l = Label.new()
		l.text = "abcdef"[x]
		l.set_position(Vector2(23+(x+0.5)*75, 8))
		add_child(l)
	for y in range(6):
		var l = Label.new()
		l.text = "123456"[y]
		l.set_position(Vector2(8, 23+(y+0.5)*75))
		add_child(l)
	pass # Replace with function body.

func _draw():
	draw_rect(Rect2(0, 0, 500, 500), Color.black)
	draw_rect(Rect2(25, 25, 75*6, 75*6), Color.darkgreen)
	for x in range(1, 6):
		draw_line(Vector2(25+x*75, 25), Vector2(25+x*75, 25+75*6), Color.black, 1)
		draw_line(Vector2(25, 25+x*75), Vector2(25+75*6, 25+x*75), Color.black, 1)
	draw_circle(Vector2(25+2*75, 25+2*75), R, Color.black)
	draw_circle(Vector2(25+4*75, 25+2*75), R, Color.black)
	draw_circle(Vector2(25+2*75, 25+4*75), R, Color.black)
	draw_circle(Vector2(25+4*75, 25+4*75), R, Color.black)
	#for x in range(6):
	#	draw_string(font, Vector2(), "abcdef"[x], Color.white)
	pass

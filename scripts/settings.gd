extends Node

func _ready():
	get_node("v_box_container/button").connect("pressed", self, "_on_pressed")
	get_node("v_box_container/info").connect("pressed", self, "_on_info_pressed")


func _on_pressed():
	OS.set_window_size(Vector2(get_node("v_box_container/width").text, get_node("v_box_container/height").text))
	OS.window_fullscreen = get_node("v_box_container/fullscreen").pressed

func _on_info_pressed():
	$"../info_pop".popup_centered_minsize()

extends Control

var send_to_server = false

func _ready():
	# Called every time the node is added to the scene.
	gamestate.connect("connection_failed", self, "_on_connection_failed")
	gamestate.connect("connection_succeeded", self, "_on_connection_success")
	gamestate.connect("player_list_changed", self, "refresh_lobby")
	gamestate.connect("game_ended", self, "_on_game_ended")
	gamestate.connect("game_error", self, "_on_game_error")


#func _physics_process(delta):
#	if $players.visible:
#		if get_tree().is_network_server():
#			if all_players_ready():
#				$players/start.disabled = false
#			else:
#				$players/start.disabled = true


func _on_host_pressed():
	if get_node("connect/v_box_container/h_box_container2/name").text == "":
		get_node("connect/v_box_container/h_box_container5/error_label").text = "Invalid name!"
		return

	get_node("connect").hide()
	get_node("players").show()
	get_node("connect/v_box_container/h_box_container5/error_label").text = ""

	var player_name = get_node("connect/v_box_container/h_box_container2/name").text
	gamestate.host_game(player_name)
	refresh_lobby()


func _on_join_pressed():
	if get_node("connect/v_box_container/h_box_container2/name").text == "":
		get_node("connect/v_box_container/h_box_container5/error_label").text = "Invalid name!"
		return

	var ip = get_node("connect/v_box_container/h_box_container4/ip").text
	if ip == "":
		ip = "127.0.0.1"
	elif not ip.is_valid_ip_address():
		get_node("connect/v_box_container/h_box_container5/error_label").text = "Invalid IPv4 address!"
		return

	get_node("connect/v_box_container/h_box_container5/error_label").text=""
	get_node("connect/v_box_container/h_box_container2/host").disabled = true
	get_node("connect/v_box_container/h_box_container4/join").disabled = true

	var player_name = get_node("connect/v_box_container/h_box_container2/name").text
	gamestate.join_game(ip, player_name)
	refresh_lobby()


func _on_connection_success():
	get_node("connect").hide()
	get_node("players").show()


func _on_connection_failed():
	get_node("connect/v_box_container/h_box_container2/host").disabled = false
	get_node("connect/v_box_container/h_box_container4/join").disabled = false
	get_node("connect/v_box_container/h_box_container5/error_label").set_text("Connection failed.")
	get_tree().set_network_peer(null) # End networking
	send_to_server = false


func _on_game_ended():
	show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_node("connect").show()
	get_node("players").hide()
	get_node("connect/v_box_container/h_box_container2/host").disabled = false
	$game_stats.visible = true


func _on_game_error(errtxt):
	get_node("error").dialog_text = errtxt
	get_node("error").popup_centered_minsize()


func refresh_lobby():
	var players = gamestate.get_player_list()
	players.sort()
	get_node("players/list").clear()
	get_node("players/list").add_item(gamestate.get_player_name() + " (You)")
	for p in players:
		get_node("players/list").add_item(p)

	if players.size() == 0 and not get_tree().is_network_server():
		send_to_server = true
		get_node("players/start").disabled = false
	elif players.size() > 0 and not send_to_server:
		get_node("players/start").disabled = not get_tree().is_network_server()


func _on_start_pressed():
	if send_to_server:
		rpc_id(1, "start_game", gamestate.get_player_name())
	else:
		gamestate.begin_game()


func _on_round_time_text_changed(new_text):
	gamestate.set_time(int($settings/v_box_container/round_time.text))


#func all_players_ready():
#	return true

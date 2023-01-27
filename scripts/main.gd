extends Spatial

var round_time
onready var timer = $game_timer
onready var env = Environment
var light = true

func _ready():
	timer.set_wait_time(gamestate.game_time())
	round_time = gamestate.game_time()
	timer.start()


func _process(_delta):
	if timer.get_time_left() <= round_time/2:
		pass
#		cycle_light() #TODO: fix this after networking


func _on_game_timer_timeout():
	gamestate.end_game()


func cycle_light():
	if light:
		$directional_light.light_energy = 0
		env.set_bg_energy(0.01)
		env.set_ambient_light_energy(0)
	else:
		$directional_light.light_energy = 1
		env.set_bg_energy(1)
		env.set_ambient_light_energy(0)

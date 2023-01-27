extends Particles

func _physics_process(_delta):
	if !emitting:
		queue_free()

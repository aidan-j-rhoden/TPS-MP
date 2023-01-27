extends CPUParticles

func _process(_delta):
	if !emitting:
		queue_free()

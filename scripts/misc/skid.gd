extends Spatial

func _ready():
	$self_destruct.start()


func _on_self_destruct_timeout():
	queue_free()

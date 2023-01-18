extends Spatial

onready var animation_tree = $animation_tree
var shine = "parameters/shine/add_amount"
onready var blade_cast = $mesh_instance/blade_cast

onready var main_scn = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
var shooter# = null

onready var sword_copy = load("res://scenes/weapons/Sting.tscn")

export var ray_length = 2
export var knockback_multiplier = 15
export var fire_delay = 0.1
export var DAMAGE = 50
export var bullets = 1
export var spread = 5
export var fov = 60
export var title = "sword"
var timer_fire = 0
var can_fire = true

# States
enum {
	PICKED,
	DROPPED
}

onready var state = DROPPED setget set_state, get_state
signal state_changed

var drop_timeout = 0
var drop_timeout_start = false
var is_pickable = true

onready var scn_wound = preload("res://scenes/impact/wound.tscn")
onready var scn_blood_fx = preload("res://scenes/impact/blood_fx.tscn")

func _ready():
	connect("state_changed", self, "_on_state_changed")
	get_node("area").connect("body_entered", self, "_on_body_entered")
	blade_cast.add_exception($mesh_instance/blade)
	blade_cast.add_exception($area)


func _physics_process(delta):
	check_collision(delta)
	if timer_fire < fire_delay:
		timer_fire += 1.0 * delta
	if timer_fire > fire_delay:
		can_fire = true
	else:
		can_fire = false

	if state == DROPPED:
		rotation.y += 1.0 * delta
		if rotation.y >= TAU:
			rotation.y = 0

	if drop_timeout_start:
		drop_timeout += 1.0 * delta

	if drop_timeout >= 1:
		is_pickable = true
		drop_timeout_start = false
		drop_timeout = 0

#	if shooter != null:
#		var nearest = get_nearest_player()
#		if 0 < nearest and nearest <= 100:
#			nearest = 101 - nearest
#			set_shine(nearest/100)
#		else:
#			set_shine(0)


func get_nearest_player():
	var distance = 0
	for player in gamestate.players: #get_node("/root/main/players").get_children():
		if distance < self.translation.distance_to(get_node("/root/main/players/" + str(player)).translation):
			distance = self.translation.distance_to(get_node("/root/main/players/" + str(player)).translation)
	return distance

# Fire
remotesync func fire():
	if can_fire:
		timer_fire = 0
	$animation_player.play("swing")
	shooter.get_node("shape/cube/animation_player").play()


remotesync func create_impact(scn, scn_fx, result, from):
	if scn is EncodedObjectAsID or scn_fx is EncodedObjectAsID:
		return
	var impact = scn.instance()
	result.collider.add_child(impact)
	impact.global_transform.origin = result.position
	impact.global_transform = utils.look_at_with_z(impact.global_transform, result.normal, from)
	randomize()
	impact.rotation = Vector3(impact.rotation.x, impact.rotation.y, rand_range(-180, 180))

	var impact_fx = scn_fx.instance()
	get_tree().root.add_child(impact_fx)
	impact_fx.global_transform.origin = result.position
	impact_fx.emitting = true
	impact_fx.global_transform = utils.look_at_with_x(impact_fx.global_transform, result.normal, from)


func set_state(value):
	state = value
	emit_signal("state_changed", value)


func get_state():
	return state


func _on_state_changed(value):
	match value:
		PICKED:
			get_node("area").monitoring = false
			get_node("area/collision_shape").disabled = true
		DROPPED:
			rpc_unreliable("update_trans", translation)
			get_node("area").monitoring = true
			get_node("area/collision_shape").disabled = false
			animation_tree[shine] = 0


remote func update_trans(trans):
	translation = trans


# Pick up weapon
remotesync func _on_body_entered(body):
	shooter = body
	rpc("pick")


remotesync func pick():
	if shooter != null:
		if shooter is Player and !shooter.is_dead and is_pickable:
			if shooter.equipped_weapon == null:
				is_pickable = false
				var weapon_container = shooter.get_node("shape/cube/root/skeleton/bone_attachment/weapon")
				# get_parent().remove_child(self)
				var weapon_copy = sword_copy.instance()
				weapon_container.add_child(weapon_copy)
				weapon_copy.transform = Transform.IDENTITY
				weapon_copy.translation = Vector3(0, 0.5, 0)
				weapon_copy.shooter = shooter
				weapon_copy.set_state(PICKED)
				weapon_copy.get_node("mesh_instance/blade").add_collision_exception_with(shooter)
				weapon_copy.set_rotation(Vector3(89.5, 0, 0))
				weapon_copy.set_scale(Vector3(1.666, 1.666, 1.666))
				shooter.weapon_equipped = true
#				weapon_copy.get_node("audio/ammo").play() # TODO add sword pick sound here
				queue_free()


# Drop weapon
remotesync func drop():
	get_parent().remove_child(self)
	main_scn.get_node("weapons").add_child(self)
	self.global_transform.origin = shooter.global_transform.origin + shooter.shape_orientation.basis.z * 1.5 + shooter.shape_orientation.basis.x * 1.8
	set_rotation(Vector3(0, 0, 0))
	set_scale(Vector3(1, 1, 1))
	shooter.equipped_weapon = null
	shooter.weapon_equipped = false
	shooter = null
	drop_timeout_start = true
	set_state(DROPPED)


func random_spread(spread_value):
	randomize()
	return Vector3(rand_range(-spread_value, spread_value), rand_range(-spread_value, spread_value), rand_range(-spread_value, spread_value))


func set_shine(value):
	animation_tree[shine] = value


func check_collision(delta):
	var body = blade_cast.get_collider()
	var space_state = get_world().direct_space_state
	body = space_state.intersect_ray(blade_cast.translation, blade_cast.get_collision_point(), [self, shooter, $mesh_instance/blade])
#	print(body)
	if body is KinematicBody and not body.is_in_vehicle and body != shooter:
		if body.health <= DAMAGE * delta and not body.is_dead:
			shooter.kill_count += 2
			body.rpc("killed_you", gamestate.get_player_name())
		body.rpc("hurt", DAMAGE * delta)
#		var position = result.position - result.collider.global_transform.origin
#		var impulse = (result.position - global_transform.origin).normalized()
#		result.collider.apply_impulse(position, impulse * knockback_multiplier)
		body.rpc("create_impact", scn_wound, scn_blood_fx, body, shooter.camera.global_transform.basis.z)
		rpc("create_impact", scn_wound, scn_blood_fx, body, shooter.camera.global_transform.basis.z)
	if body is KinematicBody and body.get_parent() is VehicleBody:
		body.rpc("create_impact", scn_wound, scn_blood_fx, body, shooter.camera.global_transform.basis.z)
		rpc("create_impact", scn_wound, scn_blood_fx, body, shooter.camera.global_transform.basis.z)
		if body.health <= DAMAGE * delta and not body.is_dead:
			shooter.kill_count += 2
			body.rpc("killed_you", gamestate.get_player_name())
		body.rpc("hurt", DAMAGE * delta)
	if body is Gibs:
#		var position = body.position - body.collider.global_transform.origin
#		var impulse = (body.position - global_transform.origin).normalized()
#		body.apply_impulse(position, impulse * 8)
		rpc("create_impact", scn_wound, scn_blood_fx, body, shooter.camera.global_transform.basis.z)

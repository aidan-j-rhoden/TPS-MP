extends Spatial

export var knockback_multiplier = 15
export var fire_delay = 0.1
export var bullets = 1

export var DAMAGE = 60
export var fov = 60
export var title = "heavy"

var can_fire = true
var firing_timer = -0.5
var exploded = false
var vel = Vector3(0, 0, 0)

# Ammo
export var MAX_FUEL = 100
onready var fuel = 0 setget set_fuel

onready var scn_impact = preload("res://scenes/impact/impact.tscn")
onready var scn_wound = preload("res://scenes/impact/wound.tscn")
onready var scn_impact_fx = preload("res://scenes/impact/impact_fx.tscn")
onready var scn_blood_fx = preload("res://scenes/impact/blood_fx.tscn")

onready var animation_player = $animation_player

# Shooter
var shooter

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

onready var main_scn = get_tree().root.get_child(get_tree().root.get_child_count() - 1)

func _ready():
	set_fuel(MAX_FUEL)

	assert(connect("state_changed", self, "_on_state_changed") == 0, "Could not connect state changed signal")


func _physics_process(delta):
	if fuel <= 0: 
		can_fire = false

	if state == DROPPED:
		if not exploded:
			rotation.y += 1.0 * delta
			if rotation.y >= TAU:
				rotation.y = 0

	if drop_timeout_start:
		drop_timeout += 1.0 * delta

	if drop_timeout >= 1:
		is_pickable = true
		drop_timeout_start = false
		drop_timeout = 0

	if not exploded:
		if not Input.is_action_pressed("lmb"): #Fix this
			animation_player.play("idle")
			firing_timer -= delta / 10
		firing_timer = clamp(firing_timer, -0.5, 2)
		$animation_tree["parameters/Blend2/blend_amount"] = firing_timer
		if firing_timer > 1:
			drop()
			exploded = true
			animation_player.play("explode")
			$body.visible = false


# Fire
func fire():
	var delta = get_process_delta_time()
	firing_timer += delta / 10
	for body in $flame_hitbox.get_overlapping_bodies():
		if body is Player:
			if body != shooter:
				body.hurt(DAMAGE * delta)
	if can_fire:
		set_fuel(fuel - delta)
		get_node("audio/fire").play()
		if not animation_player.is_playing() and animation_player.current_animation != "fire":
			animation_player.play("fire")

#		for i in bullets: # Raycast
#			var from = shooter.camera.global_transform.origin
#			var to = from + (shooter.camera.global_transform.basis.z * -ray_length + random_spread(spread))
#			var space_state = get_world().direct_space_state
#			var result = space_state.intersect_ray(from, to, [self, shooter])
#			if not result.empty():
#				print(result.collider)
#				if result.collider is Player and not result.collider.is_in_vehicle:
#					shooter.get_node("audio/hit").play()
##					result.collider.rpc("hit", DAMAGE, (result.position - global_transform.origin).normalized() * knockback_multiplier) #Should this line even be here?
#					if result.collider.health <= DAMAGE and not result.collider.is_dead:
#						shooter.kill_count += 2
#						result.collider.rpc("killed_you", gamestate.get_player_name())
#					result.collider.rpc("hurt", DAMAGE)
##					var position = result.position - result.collider.global_transform.origin
##					var impulse = (result.position - global_transform.origin).normalized()
##					result.collider.apply_impulse(position, impulse * knockback_multiplier)
#					result.collider.rpc("create_impact", scn_wound, scn_blood_fx, result, shooter.camera.global_transform.basis.z)
#					rpc("create_impact", scn_wound, scn_blood_fx, result, shooter.camera.global_transform.basis.z)
#				if result.collider is KinematicBody and result.collider.get_parent() is VehicleBody:
#					result.collider.rpc("create_impact", scn_wound, scn_blood_fx, result, shooter.camera.global_transform.basis.z)
#					rpc("create_impact", scn_wound, scn_blood_fx, result, shooter.camera.global_transform.basis.z)
#					if result.collider.health <= DAMAGE and not result.collider.is_dead:
#						shooter.kill_count += 2
#						result.collider.rpc("killed_you", gamestate.get_player_name())
#					result.collider.rpc("hurt", DAMAGE)
#				if result.collider is RigidBody and not result.collider is Gibs:
#					var position = result.position - result.collider.global_transform.origin
#					var impulse = (result.position - global_transform.origin).normalized()
#					result.collider.apply_impulse(position, impulse * 10)
#					rpc("create_impact", scn_impact, scn_impact_fx, result, shooter.camera.global_transform.basis.z)
#				if result.collider is StaticBody and not result.collider is Gibs:
#					rpc("create_impact", scn_impact, scn_impact_fx, result, shooter.camera.global_transform.basis.z)
#				if result.collider is Gibs:
#					var position = result.position - result.collider.global_transform.origin
#					var impulse = (result.position - global_transform.origin).normalized()
#					result.collider.apply_impulse(position, impulse * 8)
#					rpc("create_impact", scn_wound, scn_blood_fx, result, shooter.camera.global_transform.basis.z)


#remotesync func create_impact(scn, scn_fx, result, from):
#	if scn is EncodedObjectAsID or scn_fx is EncodedObjectAsID:
#		return
#	var impact = scn.instance()
#	result.collider.add_child(impact)
#	impact.global_transform.origin = result.position
#	impact.global_transform = utils.look_at_with_z(impact.global_transform, result.normal, from)
#	randomize()
#	impact.rotation = Vector3(impact.rotation.x, impact.rotation.y, rand_range(-180, 180))
#
#	var impact_fx = scn_fx.instance()
#	get_tree().root.add_child(impact_fx)
#	impact_fx.global_transform.origin = result.position
#	impact_fx.emitting = true
#	impact_fx.global_transform = utils.look_at_with_x(impact_fx.global_transform, result.normal, from)


func set_fuel(value):
	fuel = value
	get_node("hud/fuel").value = value


func set_state(value):
	state = value
	emit_signal("state_changed", value)


func get_state():
	return state


func _on_state_changed(value):
	match value:
		PICKED:
			animation_player.play("idle")
			get_node("area").monitoring = false
#			get_node("area/collision_shape").disabled = true
		DROPPED:
			rpc_unreliable("update_trans", translation)
			get_node("animation_player").seek(0, true)
			get_node("animation_player").stop()
			get_node("area").monitoring = true
#			get_node("area/collision_shape").disabled = false


remote func update_trans(trans):
	translation = trans


remotesync func pick():
	if shooter != null:
		if shooter is Player and !shooter.is_dead and is_pickable:
			if shooter.equipped_weapon == null:
				is_pickable = false
				var weapon_container = shooter.get_node("shape/cube/root/skeleton/bone_attachment/weapon")
#				get_parent().remove_child(self)
#				weapon_container.add_child(self)
				transform = Transform.IDENTITY
				set_state(PICKED)
				shooter.weapon_equipped = true
				if shooter.is_network_master():
					get_node("hud").visible = true
#					get_node("audio/ammo").play() #TODO
				var weapon_copy = self.duplicate(7)
				weapon_container.add_child(weapon_copy)
				weapon_copy.transform = Transform.IDENTITY
				weapon_copy.shooter = shooter
				weapon_copy.rotation_degrees = Vector3(180, 0, 0)
				weapon_copy.scale = Vector3(1.666, 1.666, 1.666)
				weapon_copy.set_state(PICKED)
				shooter.weapon_equipped = true
				weapon_copy.set_fuel(fuel)
				if shooter.is_network_master():
					weapon_copy.get_node("hud").visible = true
#					weapon_copy.get_node("audio/ammo").play()
				queue_free()


# Drop weapon
remotesync func drop():
	get_parent().remove_child(self)
	main_scn.get_node("weapons").add_child(self)
	self.global_transform.origin = shooter.global_transform.origin + shooter.shape_orientation.basis.z * 1.5 + shooter.shape_orientation.basis.x * 1.8
	if shooter.is_network_master():
		get_node("hud").visible = false
	shooter.equipped_weapon = null
	shooter.weapon_equipped = false
	shooter = null
	drop_timeout_start = true
	set_state(DROPPED)


func _on_area_body_entered(body):
	if not exploded:
		shooter = body
		rpc("pick")


func _on_explode_hitbox_body_entered(body):
	if body is Player:
		body.die()

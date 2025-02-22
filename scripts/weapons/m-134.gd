extends Spatial

export var ray_length = 1250
export var knockback_multiplier = 25
export var fire_delay = 0.01
export var bullets = 1
export var spread = 5
export var DAMAGE = 30
export var fov = 60
export var title = "heavy"
var timer_fire = 0
var can_fire = true

# Ammo
export var MAX_AMMO = 2000
onready var ammo = 0 setget set_ammo
onready var ammo_supply = 0 setget set_ammo_supply
signal ammo_changed
var is_reloading = false

onready var scn_impact = preload("res://scenes/impact/impact.tscn")
onready var scn_wound = preload("res://scenes/impact/wound.tscn")
onready var scn_impact_fx = preload("res://scenes/impact/impact_fx.tscn")
onready var scn_blood_fx = preload("res://scenes/impact/blood_fx.tscn")

# Muzzle flash
onready var flash = get_node("flash")
var flash_timer = 0

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
	if get_tree().is_network_server():
		spawn_position()
	set_ammo(MAX_AMMO)
	set_ammo_supply(MAX_AMMO)

	connect("ammo_changed", self, "_on_ammo_changed")
	connect("state_changed", self, "_on_state_changed")
	get_node("area").connect("body_entered", self, "_on_body_entered")


func _physics_process(delta):
	if flash.visible == true:
		flash_timer += 1.0 * delta
		if flash_timer >= 0.05:
			flash.visible = false
			flash.get_node("light").visible = false
			flash_timer = 0

	if timer_fire < fire_delay:
		timer_fire += 1.0 * delta
	if timer_fire > fire_delay:
		can_fire = true
	else:
		can_fire = false

	if ammo <= 0 or is_reloading: 
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


# Fire
remotesync func fire():
	if can_fire:
		timer_fire = 0

		set_ammo(ammo - 1)
		get_node("audio/fire").play()
#		get_node("animation_player").stop()
		get_node("animation_player").play("Minigun_Rig|Rotation")

		# Muzzle flash
		flash.rotation.z = rand_range(-180, 180)
		flash.visible = true
		flash.get_node("light").visible = true

		for i in bullets: # Raycast
			var from = shooter.camera.global_transform.origin
			var to = from + (shooter.camera.global_transform.basis.z * -ray_length + random_spread(spread))
			var space_state = get_world().direct_space_state
			var result = space_state.intersect_ray(from, to, [self, shooter])
			if not result.empty():
				print(result.collider)
				if result.collider is Player and not result.collider.is_in_vehicle:
					shooter.get_node("audio/hit").play()
#					result.collider.rpc("hit", DAMAGE, (result.position - global_transform.origin).normalized() * knockback_multiplier) #Should this line even be here?
					if result.collider.health <= DAMAGE and not result.collider.is_dead:
						shooter.kill_count += 2
						result.collider.rpc("killed_you", gamestate.get_player_name())
					result.collider.rpc("hurt", DAMAGE)
#					var position = result.position - result.collider.global_transform.origin
#					var impulse = (result.position - global_transform.origin).normalized()
#					result.collider.apply_impulse(position, impulse * knockback_multiplier)
					result.collider.rpc("create_impact", scn_wound, scn_blood_fx, result, shooter.camera.global_transform.basis.z)
					rpc("create_impact", scn_wound, scn_blood_fx, result, shooter.camera.global_transform.basis.z)
				if result.collider is KinematicBody and result.collider.get_parent() is VehicleBody:
					result.collider.rpc("create_impact", scn_wound, scn_blood_fx, result, shooter.camera.global_transform.basis.z)
					rpc("create_impact", scn_wound, scn_blood_fx, result, shooter.camera.global_transform.basis.z)
					if result.collider.health <= DAMAGE and not result.collider.is_dead:
						shooter.kill_count += 2
						result.collider.rpc("killed_you", gamestate.get_player_name())
					result.collider.rpc("hurt", DAMAGE)
				if result.collider is RigidBody and not result.collider is Gibs:
					var position = result.position - result.collider.global_transform.origin
					var impulse = (result.position - global_transform.origin).normalized()
					result.collider.apply_impulse(position, impulse * 10)
					rpc("create_impact", scn_impact, scn_impact_fx, result, shooter.camera.global_transform.basis.z)
				if result.collider is StaticBody and not result.collider is Gibs:
					rpc("create_impact", scn_impact, scn_impact_fx, result, shooter.camera.global_transform.basis.z)
				if result.collider is Gibs:
					var position = result.position - result.collider.global_transform.origin
					var impulse = (result.position - global_transform.origin).normalized()
					result.collider.apply_impulse(position, impulse * 8)
					rpc("create_impact", scn_wound, scn_blood_fx, result, shooter.camera.global_transform.basis.z)


# Reloading
remotesync func reload():
	if ammo < MAX_AMMO and ammo_supply > 0 and is_reloading != true:
		is_reloading = true
		get_node("animation_player").play("reload")
		get_node("audio/reload").play()
		var ammo_required = MAX_AMMO - ammo
		if ammo_supply >= ammo_required:
			set_ammo_supply(ammo_supply - ammo_required)
			set_ammo(ammo + ammo_required)
		else:
			set_ammo(ammo + ammo_supply)
			set_ammo_supply(0)
		yield(get_node("animation_player"), "animation_finished")
		is_reloading = false


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


func set_ammo(value):
	ammo = value
	emit_signal("ammo_changed", ammo, ammo_supply)


func set_ammo_supply(value):
	ammo_supply = value
	emit_signal("ammo_changed", ammo, ammo_supply)


func _on_ammo_changed(ammo_value, ammo_supply_value):
	get_node("hud/ammo").text = "AMMO: " + str(ammo_value) + "/" + str(ammo_supply_value)


func set_state(value):
	state = value
	emit_signal("state_changed", value)


func get_state():
	return state


func _on_state_changed(value):
	match value:
		PICKED:
			get_node("animation_player").play("idle")
			get_node("area").monitoring = false
			get_node("area/collision_shape").disabled = true
		DROPPED:
			rpc_unreliable("update_trans", translation)
			get_node("animation_player").seek(0, true)
			get_node("animation_player").stop()
			get_node("area").monitoring = true
			get_node("area/collision_shape").disabled = false


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
				var current_ammo = ammo
				var current_ammo_supply = ammo_supply
				is_pickable = false
				var weapon_container = shooter.get_node("shape/cube/root/skeleton/bone_attachment/weapon")
				# get_parent().remove_child(self)
				var weapon_copy = self.duplicate(7)
				weapon_container.add_child(weapon_copy)
				weapon_copy.transform = Transform.IDENTITY
				weapon_copy.shooter = shooter
				weapon_copy.set_state(PICKED)
				shooter.weapon_equipped = true
				weapon_copy.set_ammo(current_ammo)
				weapon_copy.set_rotation(Vector3(0, 179.5, 0))
				weapon_copy.set_translation(Vector3(-0.05, -0.72, -0.18))
				weapon_copy.set_scale(Vector3(1.6, 1.6, 1.6))
				weapon_copy.set_ammo_supply(current_ammo_supply)
				if shooter.is_network_master():
					weapon_copy.get_node("hud/ammo").visible = true
					weapon_copy.get_node("audio/ammo").play()
				queue_free()


# Drop weapon
remotesync func drop():
	is_reloading = false
	var current_ammo = ammo
	var current_ammo_supply = ammo_supply
	get_parent().remove_child(self)
	main_scn.add_child(self)
	self.global_transform.origin = shooter.global_transform.origin + shooter.shape_orientation.basis.z * 1.5 + shooter.shape_orientation.basis.x * 1.8
	self.set_rotation(Vector3(0, 0, 0))
	set_ammo(current_ammo)
	set_ammo_supply(current_ammo_supply)
	if shooter.is_network_master():
		get_node("hud/ammo").visible = false
	shooter.equipped_weapon = null
	shooter.weapon_equipped = false
	shooter = null
	drop_timeout_start = true
	set_state(DROPPED)


func random_spread(spread_value):
	randomize()
	return Vector3(rand_range(-spread_value, spread_value), rand_range(-spread_value, spread_value), rand_range(-spread_value, spread_value))


func spawn_position():
	randomize()
#	self.global_transform.origin = (Vector3(rand_range(-399, 399), 0.8, rand_range(-399, 399)))
	print(self.global_transform)
	var raycast = $ray_up
	if raycast.is_colliding():
		var collision = raycast.get_collider()
		print(collision)
	

extends Area2D

@export var Bullet : PackedScene

func _ready():
	# Connect this area's "area_entered" signal to itself.
	# This function will run whenever another Area2D enters this one.
	area_entered.connect(_on_area_entered)

func _on_area_entered(area):
	# We only want to react if the thing that hit us was a bullet.
	# We check this by seeing if the entering area has the 'speed' property
	# we defined in bullet.gd. This is a simple way of identifying our bullet.
	if area.collision_layer == 2:
		shoot()
		area.queue_free()

func shoot():
	# This function is the same as the other tower's shooting logic.
	var bullet_instance = Bullet.instantiate()
	get_parent().add_child(bullet_instance)
	bullet_instance.global_transform = $Muzzle.global_transform

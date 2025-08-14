extends Area2D

@export var Bullet : PackedScene

func _ready():
	$ShootTimer.timeout.connect(on_shoot_timer_timeout)
	
	pass;
	
func on_shoot_timer_timeout():
	
	var bullet_instance = Bullet.instantiate()
	get_parent().add_child(bullet_instance)
	bullet_instance.global_transform = $Muzzle.global_transform
	
	pass;

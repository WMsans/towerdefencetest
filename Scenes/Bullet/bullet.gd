extends Area2D
@export var speed = 600

func _process(delta):
	# Move the bullet forward (along its local x-axis)
	position += transform.x * speed * delta
	

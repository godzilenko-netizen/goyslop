extends SceneTree

func _init():
    var proj_scene = load("res://scenes/projectile.tscn")
    var dummy_scene = load("res://scenes/dummy.tscn")
    var p = proj_scene.instantiate()
    var d = dummy_scene.instantiate()
    var root = Node3D.new()
    root.add_child(p)
    root.add_child(d)
    
    p.global_position = Vector3(0, 0, 0)
    d.global_position = Vector3(0, 0, 0)
    
    print("Proj mask: ", p.collision_mask)
    print("Dummy layer: ", d.collision_layer)
    quit()

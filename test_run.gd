extends SceneTree

func _init():
    var s = load("res://scenes/main.tscn").instantiate()
    root.add_child(s)
    
    for i in range(60):
        await process_frame
        
    print("Test passed.")
    quit()

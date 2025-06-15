extends Node3D

@onready var hoody_mesh := $Armature/Skeleton3D/Hoody
@onready var body_mesh := $Armature/Skeleton3D/Body
@onready var sneakers_mesh := $Armature/Skeleton3D/Sneakers
@onready var pants_mesh := $Armature/Skeleton3D/Pants

func set_hoody_color(hoody_color: Color) -> void:
    hoody_mesh.get_active_material(0).albedo_color = hoody_color
    
# Sets the obstacle xray color of the player
func set_player_xray_color(color: Color) -> void:
    hoody_mesh.get_active_material(0).next_pass.albedo_color = color 
    body_mesh.get_active_material(0).next_pass.albedo_color = color 
    sneakers_mesh.get_active_material(0).next_pass.albedo_color = color 
    pants_mesh.get_active_material(0).next_pass.albedo_color = color 
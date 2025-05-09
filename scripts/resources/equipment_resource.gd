# scripts/resources/equipment_resource.gd
extends Resource
class_name EquipmentResource

@export var item_id: String = "helmet_basic"
@export var item_name: String = "Basic Helmet"
@export var item_type: String = "head"  # head, body, weapon, etc.
@export var protection: float = 10.0
@export var durability: float = 100.0
@export var model_path: String = "res://assets/models/equipment/head/helmet_basic.tscn"

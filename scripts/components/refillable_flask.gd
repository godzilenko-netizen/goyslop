class_name RefillableFlask
extends RefCounted

signal changed(
	flask_id: StringName,
	charges: int,
	max_charges: int,
	liquid_ratio: float,
	recharge_ratio: float
)

var data: FlaskData
var charges: int = 0
var _recharge_elapsed: float = 0.0


func _init(flask_data: FlaskData = null) -> void:
	if flask_data:
		configure(flask_data)


func configure(flask_data: FlaskData) -> void:
	data = flask_data
	charges = data.max_charges
	_recharge_elapsed = 0.0
	_emit_changed()


func consume() -> bool:
	if not data or charges <= 0:
		return false
	charges -= 1
	if charges >= data.max_charges:
		_recharge_elapsed = 0.0
	_emit_changed()
	return true


func tick(delta: float) -> void:
	if not data or charges >= data.max_charges or delta <= 0.0:
		return
	_recharge_elapsed += delta
	while _recharge_elapsed >= data.recharge_seconds and charges < data.max_charges:
		_recharge_elapsed -= data.recharge_seconds
		charges += 1
	if charges >= data.max_charges:
		_recharge_elapsed = 0.0
	_emit_changed()


func refill(amount: int = 1) -> int:
	if not data or amount <= 0:
		return 0
	var previous := charges
	charges = mini(data.max_charges, charges + amount)
	if charges >= data.max_charges:
		_recharge_elapsed = 0.0
	_emit_changed()
	return charges - previous


func get_recharge_ratio() -> float:
	if not data or charges >= data.max_charges:
		return 0.0
	return clampf(_recharge_elapsed / data.recharge_seconds, 0.0, 1.0)


func get_liquid_ratio() -> float:
	if not data or data.max_charges <= 0:
		return 0.0
	var partial_charge := get_recharge_ratio() if charges < data.max_charges else 0.0
	return clampf((charges + partial_charge) / float(data.max_charges), 0.0, 1.0)


func emit_current_state() -> void:
	_emit_changed()


func _emit_changed() -> void:
	if not data:
		return
	changed.emit(
		data.flask_id,
		charges,
		data.max_charges,
		get_liquid_ratio(),
		get_recharge_ratio()
	)

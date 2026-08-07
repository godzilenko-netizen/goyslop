extends RefCounted
class_name GothicUI

const INK := Color("090706")
const INK_SOFT := Color("130f0c")
const LEATHER := Color("21130f")
const LEATHER_LIGHT := Color("321b13")
const IRON := Color("302a27")
const BRASS_DARK := Color("6f491b")
const BRASS := Color("a36f28")
const BRASS_LIGHT := Color("d0a04b")
const BONE := Color("d4c0a0")
const BONE_MUTED := Color("94856f")
const BLOOD := Color("8f111c")
const MANA := Color("174998")
const EMBER := Color("ba4322")


static func panel_style(
	background: Color = INK_SOFT,
	border: Color = BRASS_DARK,
	border_width: int = 2,
	corner_radius: int = 0,
	shadow_size: int = 0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.set_corner_radius_all(corner_radius)
	if shadow_size > 0:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.88)
		style.shadow_size = shadow_size
		style.shadow_offset = Vector2(0.0, 4.0)
	return style


static func slot_style(accent := false, transparent := false) -> StyleBoxFlat:
	var background := Color(0.025, 0.018, 0.014, 0.82)
	if transparent:
		background.a = 0.48
	var border := BRASS if accent else Color(0.25, 0.20, 0.16, 1.0)
	var style := panel_style(background, border, 2, 1)
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	return style


static func tooltip_style(border: Color = BRASS) -> StyleBoxFlat:
	var style := panel_style(Color(0.025, 0.018, 0.014, 0.98), border, 2, 0, 10)
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	return style


static func divider_style(color: Color = BRASS_DARK) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	return style

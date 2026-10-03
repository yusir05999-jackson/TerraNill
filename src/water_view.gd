class_name WaterView
extends Node2D
## 《绿脉》水文原型可视化和交互层（依赖 WaterSim）
##
## 用法：新建场景 → 根节点搜索添加 "WaterView" → F6 运行当前场景。
## 建议窗口 768×768（项目设置 → 显示 → 窗口 → 视口宽度/高度）。
## 操作：左键注水 | 右键挖渠（降低地形）| Shift+左键抬升地形

const CELL := 6  # 每格 6px，128×6 = 768，对应建议窗口大小
const SIZE := WaterSim.SIZE

var sim := WaterSim.new()
var terrain_tex: ImageTexture
var steps_per_frame := 3  # 每帧推进的模拟步数，越大水流越快


func _ready() -> void:
	sim.generate_terrain()
	sim.rain_disc(SIZE / 2, 24, 3, 2.0)  # 初始水源：北部山口一场暴雨
	_rebuild_terrain_texture()
	print("操作：左键 注水 | 右键 挖渠 | Shift+左键 抬升地形")


func _process(_delta: float) -> void:
	for i in steps_per_frame:
		sim.step()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var g := Vector2i(event.position / CELL)
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.shift_pressed:
					sim.raise_disc(g.x, g.y, 2, 0.5)
					_rebuild_terrain_texture()
				else:
					sim.rain_disc(g.x, g.y, 3, 1.5)
			MOUSE_BUTTON_RIGHT:
				sim.dig_disc(g.x, g.y, 2, 0.5)
				_rebuild_terrain_texture()


func _rebuild_terrain_texture() -> void:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			img.set_pixel(x, y, _height_color(sim.terrain[y * SIZE + x]))
	terrain_tex = ImageTexture.create_from_image(img)


func _height_color(h: float) -> Color:
	var t := clampf(h / 8.0, 0.0, 1.0)
	var c_low := Color(0.36, 0.42, 0.22)   # 谷底偏绿
	var c_mid := Color(0.55, 0.47, 0.30)   # 旱地土黄
	var c_high := Color(0.42, 0.33, 0.24)  # 高地褐
	if t < 0.5:
		return c_low.lerp(c_mid, t * 2.0)
	return c_mid.lerp(c_high, (t - 0.5) * 2.0)


func _draw() -> void:
	draw_texture_rect(terrain_tex, Rect2(Vector2.ZERO, Vector2(SIZE, SIZE) * CELL), false)
	# 只画有水的地方。透明度对深度开平方：薄水膜也清晰可见
	for y in SIZE:
		for x in SIZE:
			var d: float = sim.depth[y * SIZE + x]
			if d > 0.01:
				var a := clampf(0.15 + sqrt(d) * 0.5, 0.15, 0.95)
				draw_rect(Rect2(Vector2(x, y) * CELL, Vector2(CELL, CELL)),
					Color(0.15, 0.45, 0.85, a))
	draw_string(ThemeDB.fallback_font, Vector2(10, 22),
		"左键:注水  右键:挖渠  Shift+左键:抬升",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

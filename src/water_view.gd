class_name WaterView
extends Node2D
## 《绿脉》水文原型可视化和交互层（依赖 WaterSim）
##
## 用法：新建场景 → 根节点搜索添加 "WaterView" → F6 运行当前场景。
## 建议窗口 1024×1024（项目设置 → 显示 → 窗口 → 视口宽度/高度）。
## 操作：按住左键下雨 | 右键挖渠 | Shift+左键抬升地形
##
## 注意：若在编辑器"游戏"标签页中嵌入运行，需先点工具栏的"输入"按钮
## 才会把鼠标键盘转发给游戏；建议在编辑器设置 → 运行中关闭嵌入。

const CELL := 8  # 每格 8px，128×8 = 1024，对应建议窗口大小
const SIZE := WaterSim.SIZE
const SPRING := Vector2i(SIZE / 2, 14)  # 北部涌泉：保证始终有一条河在成形

var sim := WaterSim.new()
var terrain_tex: ImageTexture
var steps_per_frame := 3      # 每帧推进的模拟步数，越大水流越快
var _raining := false         # 左键是否按住（持续下雨）
var _rain_pos := Vector2i.ZERO


func _ready() -> void:
	sim.generate_terrain()
	sim.rain_disc(SPRING.x, SPRING.y + 8, 4, 2.5)  # 开局一场暴雨
	_rebuild_terrain_texture()
	print("操作：按住左键下雨 | 右键挖渠 | Shift+左键抬升地形")


func _process(_delta: float) -> void:
	sim.add_water(SPRING.x, SPRING.y, 0.08)  # 涌泉持续供水 → 常驻河流
	if _raining and not Input.is_key_pressed(KEY_SHIFT):
		sim.rain_disc(_rain_pos.x, _rain_pos.y, 3, 0.35)
	for i in steps_per_frame:
		sim.step()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var g := Vector2i(event.position / CELL)
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed and event.shift_pressed:
					sim.raise_disc(g.x, g.y, 2, 0.5)
					_rebuild_terrain_texture()
				else:
					_raining = event.pressed
					_rain_pos = g
					if event.pressed:
						sim.rain_disc(g.x, g.y, 4, 2.0)  # 点击瞬间一场暴雨，立刻可见
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					sim.dig_disc(g.x, g.y, 2, 0.5)
					_rebuild_terrain_texture()


func _rebuild_terrain_texture() -> void:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			img.set_pixel(x, y, _height_color(sim.terrain[y * SIZE + x]))
	terrain_tex = ImageTexture.create_from_image(img)


func _height_color(h: float) -> Color:
	var t := clampf(h / 10.0, 0.0, 1.0)
	var c_low := Color(0.36, 0.42, 0.22)   # 谷底偏绿
	var c_mid := Color(0.55, 0.47, 0.30)   # 旱地土黄
	var c_high := Color(0.42, 0.33, 0.24)  # 高地褐
	if t < 0.5:
		return c_low.lerp(c_mid, t * 2.0)
	return c_mid.lerp(c_high, (t - 0.5) * 2.0)


func _draw() -> void:
	draw_texture_rect(terrain_tex, Rect2(Vector2.ZERO, Vector2(SIZE, SIZE) * CELL), false)
	# 只画有水的地方。透明度下限给足：最薄的水膜也明显发蓝
	for y in SIZE:
		for x in SIZE:
			var d: float = sim.depth[y * SIZE + x]
			if d > 0.01:
				var a := clampf(0.35 + sqrt(d) * 0.45, 0.35, 0.95)
				draw_rect(Rect2(Vector2(x, y) * CELL, Vector2(CELL, CELL)),
					Color(0.10, 0.45, 0.90, a))
	# 涌泉标记
	var spring_px := Vector2(SPRING) * CELL + Vector2(CELL, CELL) * 0.5
	draw_circle(spring_px, CELL * 0.9, Color(0.92, 0.96, 1.0, 0.9))
	draw_string(ThemeDB.fallback_font, spring_px + Vector2(10, -6), "泉",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(10, 24),
		"按住左键:下雨  右键:挖渠  Shift+左键:抬升  |  白点=涌泉，河从此出发",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

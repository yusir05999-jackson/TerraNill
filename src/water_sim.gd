class_name WaterSim
extends RefCounted
## 元胞自动机水文模拟（《绿脉》第 1 周原型核心）
##
## 算法要点（对应企划书第五节）：
##   总水位 = 地形高度 + 水深。每格按与 4 邻格的总水位差计算流出量，
##   先算完全部流向（基于同一时刻的水深快照），再统一更新 —— 避免棋盘格伪影。
##   单步总流出量超过本格现有水量时等比缩减，保证质量守恒。
##
## 快速开始（Godot 4.x）：
##   1. 把 src/ 下两个脚本放入项目
##   2. 新建场景，根节点搜索并添加 "WaterView"，按 F6 运行当前场景
##   3. 建议窗口 768×768：项目设置 → 显示 → 窗口 → 视口宽度/高度
##   操作：左键注水 | 右键挖渠（降低地形）| Shift+左键抬升地形

const SIZE := 128            # 网格边长（企划书定的 128×128）
const FLOW_RATE := 0.35      # 流速系数（0~0.5 之间稳定，越大流得越快）
const MAX_DEPTH := 3.0       # 单格水深上限，防止数值爆炸

const DX := [1, -1, 0, 0]
const DY := [0, 0, 1, -1]

var terrain: PackedFloat32Array = PackedFloat32Array()  # 地形高度（静态，挖渠时改变）
var depth: PackedFloat32Array = PackedFloat32Array()    # 当前水深


func _init() -> void:
	terrain.resize(SIZE * SIZE)
	depth.resize(SIZE * SIZE)


# ---------- 地形 ----------

## 生成演示地形：北低南高的单向大坡 + 值噪声起伏 + 预挖几个水潭。
## 单向坡让水有固定流向（才能冲出河道），水潭保证"低洼聚积"的观感。
func generate_terrain() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_VALUE
	noise.frequency = 0.04
	noise.seed = randi()
	for y in SIZE:
		for x in SIZE:
			var slope := (float(y) / SIZE) * 8.0                    # 从北到南抬升 8
			var bump := (noise.get_noise_2d(x, y) + 1.0) * 1.25     # 噪声起伏 0~2.5
			terrain[y * SIZE + x] = slope + bump
	# 在中下游挖几个洼地，水汇到此形成湖泊
	for k in 3:
		var cx := randi_range(16, SIZE - 16)
		var cy := randi_range(SIZE / 2, SIZE - 16)
		dig_disc(cx, cy, randi_range(4, 7), 1.5)


func dig_disc(cx: int, cy: int, radius: int, amount: float) -> void:
	_for_each_in_disc(cx, cy, radius, func(i: int) -> void:
		terrain[i] = maxf(0.0, terrain[i] - amount))


func raise_disc(cx: int, cy: int, radius: int, amount: float) -> void:
	_for_each_in_disc(cx, cy, radius, func(i: int) -> void:
		terrain[i] += amount)


# ---------- 水 ----------

func add_water(cx: int, cy: int, amount: float) -> void:
	if not _in_bounds(cx, cy):
		return
	var i := cy * SIZE + cx
	depth[i] = clampf(depth[i] + amount, 0.0, MAX_DEPTH)


func rain_disc(cx: int, cy: int, radius: int, amount: float) -> void:
	_for_each_in_disc(cx, cy, radius, func(i: int) -> void:
		depth[i] = clampf(depth[i] + amount, 0.0, MAX_DEPTH))


## 推进一个模拟步。这是本周里程碑的核心，别改动更新顺序。
func step() -> void:
	# delta 记录每个格子本步的净流入/流出，全部算完后一次性施加
	var delta := PackedFloat32Array()
	delta.resize(SIZE * SIZE)

	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			var d := depth[i]
			if d <= 0.0:
				continue

			var level := terrain[i] + d
			var outs := [0.0, 0.0, 0.0, 0.0]
			var total := 0.0

			# —— 第一步：只计算流向和流出量，不改任何数据 ——
			for k in 4:
				var nx: int = x + DX[k]
				var ny: int = y + DY[k]
				if nx < 0 or nx >= SIZE or ny < 0 or ny >= SIZE:
					continue
				var ni := ny * SIZE + nx
				var diff := level - (terrain[ni] + depth[ni])
				if diff > 0.0:
					var f: float = diff * FLOW_RATE
					outs[k] = f
					total += f

			if total <= 0.0:
				continue

			# 水不够分就等比缩减，质量守恒：水不会凭空多出来
			if total > d:
				var scale := d / total
				for k in 4:
					outs[k] *= scale

			# —— 第二步：把流出量写入 delta（正负相抵），尚未改动 depth ——
			for k in 4:
				var f2: float = outs[k]
				if f2 <= 0.0:
					continue
				delta[i] -= f2
				delta[(y + DY[k]) * SIZE + (x + DX[k])] += f2

	# —— 第三步：统一更新 ——
	for i in SIZE * SIZE:
		depth[i] = clampf(depth[i] + delta[i], 0.0, MAX_DEPTH)


# ---------- 工具 ----------

func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < SIZE and y >= 0 and y < SIZE


func _for_each_in_disc(cx: int, cy: int, radius: int, fn: Callable) -> void:
	for y in range(maxi(0, cy - radius), mini(SIZE, cy + radius + 1)):
		for x in range(maxi(0, cx - radius), mini(SIZE, cx + radius + 1)):
			if Vector2i(x, y).distance_to(Vector2i(cx, cy)) <= radius:
				fn.call(y * SIZE + x)

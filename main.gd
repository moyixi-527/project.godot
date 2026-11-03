extends Node2D

# 核心变量
var player: CharacterBody2D
var player_speed = 300.0
var player_hp = 100.0
var max_hp = 100.0
var attack_damage = 10.0
var attack_speed = 0.5 # 每秒攻击次数
var attack_timer = 0.0

var enemies = []
var enemy_spawn_timer = 0.0
var game_over = false

# UI相关
var upgrade_panel: Control
var hp_label: Label
var is_upgrading = false
var joystick_center = Vector2.ZERO
var joystick_pos = Vector2.ZERO
var is_touching = false

# 为了不用拖拽节点，我们完全用代码生成所有东西
func _ready():
	# 设置背景色
	RenderingServer.set_default_clear_color(Color(0.1, 0.15, 0.2))
	
	# 动态创建玩家（一个蓝色方块，用 Polygon2D 代替复杂的节点）
	player = CharacterBody2D.new()
	player.position = get_viewport_rect().size / 2
	var poly = Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-20,-20), Vector2(20,-20), Vector2(20,20), Vector2(-20,20)])
	poly.color = Color(0.2, 0.6, 1.0)
	player.add_child(poly)
	add_child(player)
	
	# 动态创建UI
	var ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	hp_label = Label.new()
	hp_label.position = Vector2(20, 20)
	hp_label.text = "HP: 100 / 100"
	ui_layer.add_child(hp_label)
	
	upgrade_panel = Control.new()
	upgrade_panel.set_anchors_preset(Control.PRESET_CENTER)
	upgrade_panel.visible = false
	ui_layer.add_child(upgrade_panel)
	
	create_upgrade_ui()

func create_upgrade_ui():
	var label = Label.new()
	label.text = "升级！请选择一项强化："
	label.position = Vector2(-150, -100)
	upgrade_panel.add_child(label)
	
	var btn1 = Button.new()
	btn1.text = "攻击力 +50%"
	btn1.position = Vector2(-100, -30)
	btn1.size = Vector2(200, 50)
	btn1.pressed.connect(func(): apply_upgrade("damage"))
	upgrade_panel.add_child(btn1)
	
	var btn2 = Button.new()
	btn2.text = "攻速 +20%"
	btn2.position = Vector2(-100, 30)
	btn2.size = Vector2(200, 50)
	btn2.pressed.connect(func(): apply_upgrade("speed"))
	upgrade_panel.add_child(btn2)
	
	var btn3 = Button.new()
	btn3.text = "恢复生命值"
	btn3.position = Vector2(-100, 90)
	btn3.size = Vector2(200, 50)
	btn3.pressed.connect(func(): apply_upgrade("heal"))
	upgrade_panel.add_child(btn3)

func apply_upgrade(type):
	if type == "damage":
		attack_damage *= 1.5
	elif type == "speed":
		attack_speed *= 1.2
	elif type == "heal":
		player_hp = min(max_hp, player_hp + 30)
	
	is_upgrading = false
	upgrade_panel.visible = false
	update_ui()

func _process(delta):
	if game_over or is_upgrading:
		return
		
	# 处理移动（简易摇杆）
	if is_touching:
		var dir = joystick_pos - joystick_center
		if dir.length() > 10:
			player.position += dir.normalized() * player_speed * delta
			
	# 自动攻击
	attack_timer -= delta
	if attack_timer <= 0 and enemies.size() > 0:
		attack_timer = 1.0 / attack_speed
		shoot_at_nearest_enemy()
		
	# 刷怪
	enemy_spawn_timer -= delta
	if enemy_spawn_timer <= 0:
		spawn_enemy()
		enemy_spawn_timer = 2.0 # 每2秒刷一只
		
	# 更新敌人
	for e in enemies:
		if is_instance_valid(e):
			var dir = (player.position - e.position).normalized()
			e.position += dir * 100.0 * delta
			
			# 碰撞检测
			if e.position.distance_to(player.position) < 30:
				player_hp -= 10 * delta * 10 # 每秒扣10点
				update_ui()
				if player_hp <= 0:
					game_over = true
					hp_label.text = "GAME OVER! 点击屏幕重开"
					break

func shoot_at_nearest_enemy():
	var nearest = null
	var min_dist = 9999
	for e in enemies:
		if is_instance_valid(e):
			var d = player.position.distance_to(e.position)
			if d < min_dist:
				min_dist = d
				nearest = e
				
	if nearest:
		# 生成子弹
		var bullet = Polygon2D.new()
		bullet.polygon = PackedVector2Array([Vector2(-5,-5), Vector2(5,-5), Vector2(5,5), Vector2(-5,5)])
		bullet.color = Color(1.0, 0.8, 0.2)
		bullet.position = player.position
		add_child(bullet)
		
		# 子弹移动逻辑
		var tween = create_tween()
		tween.tween_property(bullet, "position", nearest.position, 0.2)
		tween.finished.connect(func():
			if is_instance_valid(nearest) and is_instance_valid(bullet):
				enemies.erase(nearest)
				nearest.queue_free()
				bullet.queue_free()
				# 简易升级逻辑：每次击杀有概率触发
				if randf() < 0.3: 
					trigger_upgrade()
		)

func trigger_upgrade():
	is_upgrading = true
	upgrade_panel.visible = true

func spawn_enemy():
	var e = CharacterBody2D.new()
	var poly = Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-15,-15), Vector2(15,-15), Vector2(15,15), Vector2(-15,15)])
	poly.color = Color(1.0, 0.3, 0.3)
	e.add_child(poly)
	
	# 随机在屏幕边缘生成
	var screen_size = get_viewport_rect().size
	var side = randi() % 4
	if side == 0: e.position = Vector2(randf() * screen_size.x, -20)
	elif side == 1: e.position = Vector2(randf() * screen_size.x, screen_size.y + 20)
	elif side == 2: e.position = Vector2(-20, randf() * screen_size.y)
	else: e.position = Vector2(screen_size.x + 20, randf() * screen_size.y)
	
	add_child(e)
	enemies.append(e)

func update_ui():
	hp_label.text = "HP: " + str(int(player_hp)) + " / " + str(int(max_hp))

# 触摸输入映射
func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			is_touching = true
			joystick_center = event.position
			joystick_pos = event.position
			if game_over:
				get_tree().reload_current_scene()
		else:
			is_touching = false
	if event is InputEventScreenDrag:
		joystick_pos = event.position

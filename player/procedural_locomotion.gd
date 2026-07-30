class_name ProceduralLocomotion
extends Node
## ProceduralLocomotion — v3
##
## Resumo do que mudou em relação à v2 (e por quê), pedido por pedido:
##
## 1) PARÂMETROS DINÂMICOS COM A VELOCIDADE
##    Antes só step_duration e step_height eram escalados pela velocidade
##    real dentro do preset ativo. Agora step_trigger_distance e
##    max_stretch também escalam (_effective_trigger_distance /
##    _effective_max_stretch), usando a mesma ideia: razão entre a
##    velocidade atual e o reference_speed do preset, limitada por
##    dynamic_scale_min/dynamic_scale_max. Resultado: dentro do mesmo
##    preset (ex: WALK acelerando de 0 até walk_speed), a passada cresce
##    suavemente com a velocidade em vez de saltar direto pro valor fixo
##    do preset. "Ao correr os passos ficam mais longes" é basicamente
##    isso: quanto mais rápido, maior o trigger_distance efetivo — e como
##    o home anda mais rápido também nesse meio tempo, o pé viaja mais
##    longe até o passo disparar.
##
## 2) PÉS NUNCA MAIS FICAM COLADOS
##    Três coisas novas, funcionando juntas:
##    a) turn_in_place: se você girar no lugar (parado ou quase) mais que
##       plant_rotation_threshold_deg desde que o pé foi plantado, dispara
##       um passo pra realinhar, mesmo sem distância suficiente. Isso é
##       o caso que você descreveu (parado girando a câmera).
##    b) min_foot_separation: se a distância entre os dois pés plantados
##       cair abaixo disso, o pé mais desalinhado dispara uma correção —
##       rede de segurança pra qualquer outra causa dos pés se cruzarem.
##    c) idle_settle: depois de idle_settle_delay parado (abaixo de
##       idle_speed_threshold), o limiar de disparo despenca pra
##       idle_trigger_distance. Ou seja, parado o suficiente, qualquer
##       resíduo de deslocamento é corrigido e os pés voltam exatamente
##       pro home — os "valores originais" que você pediu.
##
## 3) PULO
##    Antes, no ar, os pés travavam na última posição de mundo, e como o
##    corpo continuava se movendo, a perna esticava/puxava pra trás.
##    Agora, no ar, o pé PERSEGUE o home (suavizado por air_follow_speed)
##    em vez de ficar parado — com um leve "tuck" pra cima subindo e
##    "reach" pra baixo caindo, baseado na velocidade vertical. Ao
##    aterrissar, dispara um passo de pouso curto e seco
##    (landing_step_duration/height) direto pro chão real, ou só encaixa
##    se já estiver perto o bastante (landing_snap_distance). Esse passo
##    de pouso é a ÚNICA situação em que os dois pés têm permissão de se
##    mover ao mesmo tempo — é intencional: é assim que um pouso
##    normalmente parece (evento discreto, não parte do ciclo de andar).
##
## 4) NUNCA DOIS PASSOS DE UMA VEZ (fora do pouso)
##    O bug: "forced" (perna esticando) disparava sem checar se o outro
##    pé já estava no ar, então uma aceleração brusca fazia os dois
##    quererem sair juntos. Agora existe step_overlap (por preset, em
##    locomotion_presets.gd): o próximo pé só pode começar quando o outro
##    NÃO está no ar, OU já passou de step_overlap (0 a 1) da própria
##    passada. Com overlap=1.0 (padrão do WALK) o comportamento é
##    idêntico ao de antes (estrito — por isso o walk continua com a
##    mesma cara). Com overlap menor (RUN) o próximo pé pode antecipar um
##    pouco, o que também evita a perna ficar esticada esperando o outro
##    pé fechar o passo inteiro.

@export_node_path("CharacterBody3D") var player
@export_node_path("Marker3D") var left_foot_home
@export_node_path("Marker3D") var right_foot_home
@export_node_path("Marker3D") var left_foot_target
@export_node_path("Marker3D") var right_foot_target

@export var state: LocomotionPresets.State = LocomotionPresets.State.WALK:
	set(value):
		var changed := value != state
		state = value
		_apply_preset()
		if changed and debug_print_preset:
			_print_preset()

@export var step_duration: float = 0.26
@export var step_height: float = 0.20
@export var step_trigger_distance: float = 0.32
@export var max_stretch: float = 0.52
## 0..1. Quanto do passo do OUTRO pé precisa estar completo antes deste
## poder começar a se mover. 1.0 = só começa quando o outro estiver
## totalmente plantado (nunca sobrepõe). Valores menores permitem um
## pouco de antecipação — útil em velocidades altas. Vem do preset ativo,
## ver locomotion_presets.gd.
@export var step_overlap: float = 0.7
@export var ease_strength: float = -1.6
@export var reference_speed: float = 2.0

## Se o pé ficar absurdamente longe (teleporte, queda, spawn), reposiciona.
@export var snap_distance: float = 1.5

@export_group("Ground")
## Camadas de colisão consideradas "chão" pelo raycast de pouso.
@export_flags_3d_physics var ground_mask: int = 1
## Quanto acima/abaixo do FootHome o raycast procura chão.
@export var ground_probe_up: float = 0.6
@export var ground_probe_down: float = 1.2
## Offset do tornozelo em relação ao contato do pé com o chão.
@export var foot_ground_offset: float = 0.0

@export_group("Dynamic")
## Limites da razão (velocidade / reference_speed) usada pra escalar
## step_trigger_distance e max_stretch continuamente. 0.5 = no mínimo
## metade do valor do preset (parado/lento); 1.6 = no máximo 60% a mais
## (bem acima da velocidade de referência do preset).
@export var dynamic_scale_min: float = 0.5
@export var dynamic_scale_max: float = 1.6

@export_group("Idle & Turn")
## Abaixo disso, o personagem é considerado "parado" pra fins de idle e giro.
@export var idle_speed_threshold: float = 0.05
## Quanto tempo parado antes do limiar de passo apertar pra idle_trigger_distance.
@export var idle_settle_delay: float = 0.25
## Limiar de correção quando já está parado há idle_settle_delay — bem
## menor que step_trigger_distance, garante que o pé volta pro home exato.
@export var idle_trigger_distance: float = 0.05
## Girar no lugar só conta como "turn in place" abaixo dessa velocidade
## (girar enquanto anda já é coberto pelo trigger de distância normal).
@export var turn_in_place_speed: float = 0.3
## Graus de rotação do corpo (desde que o pé foi plantado) que forçam um
## replante, mesmo sem distância suficiente. É isso que resolve o pé
## grudado quando você fica parado girando a câmera.
@export var plant_rotation_threshold_deg: float = 30.0
## Distância horizontal mínima entre os dois pés plantados. Abaixo disso,
## o pé mais fora do lugar dispara uma correção. Rede de segurança contra
## pés colados/cruzados. IMPORTANTE: deixe isso MENOR que a distância
## normal entre os pés parados no seu rig, senão vai corrigir à toa o
## tempo todo — ajuste olhando o stance padrão do seu personagem.
@export var min_foot_separation: float = 0.10

@export_group("Air")
## Velocidade de suavização com que o pé "solto" persegue o home no ar.
## Maior = gruda mais rápido no corpo (menos "puxado pra trás").
@export var air_follow_speed: float = 10.0
## Quanto (m) o pé sobe ao subir e desce ao cair, proporcional à
## velocidade vertical — dá uma pequena antecipação de pouso.
@export var air_tuck_amount: float = 0.10
## Velocidade vertical (m/s) usada como referência pra normalizar o tuck/reach.
@export var air_tuck_reference_speed: float = 6.0
## Duração do passo de aterrissagem — mais curto e seco que um passo normal.
@export var landing_step_duration: float = 0.12
## Altura extra do passo de aterrissagem (efeito de impacto).
@export var landing_step_height: float = 0.22
## Se o pé já estiver mais perto do chão que isso ao aterrissar, só
## encaixa direto (sem animação) em vez de dar um passo de pouso.
@export var landing_snap_distance: float = 0.05

@export_group("Debug")
## Imprime o preset ativo sempre que o estado muda.
@export var debug_print_preset: bool = true
## Imprime cada passo disparado (spam alto — use só pra calibrar).
@export var debug_print_steps: bool = false

var _player: CharacterBody3D
var _left_home: Node3D
var _right_home: Node3D
var _left_target: Node3D
var _right_target: Node3D

var _last_printed_state: int = -1
var _was_on_floor: bool = true
var _idle_elapsed: float = 0.0

class FootStep:
	var name: String = ""
	var stepping: bool = false
	var t: float = 0.0
	var duration: float = 0.26
	var height: float = 0.2
	var start_pos: Vector3 = Vector3.ZERO
	var end_pos: Vector3 = Vector3.ZERO
	## Posição do pé em ESPAÇO DE MUNDO enquanto ele está plantado no chão.
	var planted_pos: Vector3 = Vector3.ZERO
	## Rotação Y do corpo no momento em que este pé foi plantado. Usado
	## pra detectar giro no lugar (ver plant_rotation_threshold_deg).
	var plant_yaw: float = 0.0


var _left := FootStep.new()
var _right := FootStep.new()


func _ready() -> void:
	_player = get_node(player)
	_left_home = get_node(left_foot_home)
	_right_home = get_node(right_foot_home)
	_left_target = get_node(left_foot_target)
	_right_target = get_node(right_foot_target)

	_left.name = "L"
	_right.name = "R"

	# Os targets NÃO podem herdar o transform do corpo: eles vivem em mundo.
	_left_target.top_level = true
	_right_target.top_level = true

	_plant(_left, _left_target, _ground_point(_left_home.global_position))
	_plant(_right, _right_target, _ground_point(_right_home.global_position))

	_apply_preset()
	if debug_print_preset:
		_print_preset()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	if debug_print_preset and state != _last_printed_state:
		_print_preset()

	var on_floor := _is_on_floor()

	if not on_floor:
		_was_on_floor = false
		_update_airborne_foot(_left, _left_home, _left_target, delta)
		_update_airborne_foot(_right, _right_home, _right_target, delta)
		return

	if not _was_on_floor:
		_handle_landing()
	_was_on_floor = true

	var speed: float = _horizontal_speed()

	if speed < idle_speed_threshold:
		_idle_elapsed += delta
	else:
		_idle_elapsed = 0.0

	_update_foot(_left, _left_home, _left_target, delta, speed, _right)
	_update_foot(_right, _right_home, _right_target, delta, speed, _left)


func _effective_velocity() -> Vector3:
	var v: Vector3 = _player.velocity
	# Remoto: move_and_slide() não roda, velocity fica 0. Use a replicada.
	if v.length_squared() < 0.0001 and "network_velocity" in _player:
		v = _player.network_velocity
	return v


func _horizontal_speed() -> float:
	var v := _effective_velocity()
	v.y = 0.0
	return v.length()


func _vertical_velocity() -> float:
	return _effective_velocity().y


func _is_on_floor() -> bool:
	if "network_on_floor" in _player:
		return _player.network_on_floor
	return _player.is_on_floor()


func _apply_preset() -> void:
	var p: Dictionary = LocomotionPresets.get_preset(state)
	step_duration = p["step_duration"]
	step_height = p["step_height"]
	step_trigger_distance = p["step_trigger_distance"]
	max_stretch = p.get("max_stretch", step_trigger_distance * 1.6)
	step_overlap = p.get("step_overlap", 0.7)
	ease_strength = p["ease_strength"]
	reference_speed = p.get("reference_speed", 2.0)


func _print_preset() -> void:
	_last_printed_state = state
	print("[ProceduralLocomotion] %s -> preset=%s dur=%.2f height=%.2f trigger=%.2f stretch=%.2f overlap=%.2f ease=%.2f ref_speed=%.1f" % [
		_player.name if is_instance_valid(_player) else "?",
		LocomotionPresets.get_state_name(state),
		step_duration, step_height, step_trigger_distance, max_stretch,
		step_overlap, ease_strength, reference_speed,
	])


## Projeta um ponto no chão real abaixo dele. Isso é o que tira o pé
## flutuando: o FootHome está na altura do rig, não na altura do terreno.
func _ground_point(p: Vector3) -> Vector3:
	var space := _player.get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(
		p + Vector3.UP * ground_probe_up,
		p + Vector3.DOWN * ground_probe_down
	)
	params.collision_mask = ground_mask
	params.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return p
	return (hit["position"] as Vector3) + Vector3.UP * foot_ground_offset


## Marca o pé como plantado NESSA posição de mundo, e memoriza o yaw do
## corpo nesse instante (usado depois pra detectar giro no lugar).
func _plant(foot: FootStep, target: Node3D, pos: Vector3) -> void:
	foot.stepping = false
	foot.planted_pos = pos
	if is_instance_valid(_player):
		foot.plant_yaw = _player.global_rotation.y
	target.global_position = pos


## Razão velocidade/reference_speed, limitada — usada pra escalar
## trigger_distance e max_stretch continuamente com a velocidade real.
func _speed_ratio(speed: float) -> float:
	return clampf(speed / maxf(reference_speed, 0.01), dynamic_scale_min, dynamic_scale_max)


func _effective_trigger_distance(speed: float) -> float:
	return step_trigger_distance * _speed_ratio(speed)


func _effective_max_stretch(speed: float) -> float:
	return max_stretch * _speed_ratio(speed)


## Duração efetiva do passo: mais rápido você anda, mais curta a passada.
func _effective_duration(speed: float) -> float:
	if speed < 0.05:
		return step_duration
	var scale: float = reference_speed / speed
	return clampf(step_duration * scale, 0.08, step_duration * 1.6)


## Altura efetiva: base + até 50% de bônus conforme a velocidade.
func _effective_height(speed: float) -> float:
	var ratio: float = clampf(speed / maxf(reference_speed, 0.01), 0.0, 1.5)
	return step_height * (0.75 + 0.5 * ratio)


func _yaw_delta(plant_yaw: float) -> float:
	return absf(wrapf(_player.global_rotation.y - plant_yaw, -PI, PI))


## No ar: o pé para de "esperar" o gatilho normal de passo e passa a
## perseguir o home (suavizado), com um leve tuck/reach pela velocidade
## vertical. É isso que tira o "pé preso, perna puxada pra trás" ao pular.
func _update_airborne_foot(foot: FootStep, home: Node3D, target: Node3D, delta: float) -> void:
	if foot.stepping:
		# Saiu do chão no meio de um passo: continua da posição visual
		# atual em vez de "popar" de volta pro início da passada.
		foot.planted_pos = target.global_position
		foot.stepping = false

	var ratio: float = clampf(_vertical_velocity() / maxf(air_tuck_reference_speed, 0.01), -1.0, 1.0)
	var follow_pos: Vector3 = home.global_position
	follow_pos.y += air_tuck_amount * ratio

	var t: float = 1.0 - exp(-air_follow_speed * delta)
	foot.planted_pos = foot.planted_pos.lerp(follow_pos, t)
	target.global_position = foot.planted_pos


## Chamado uma vez, no frame exato em que os pés voltam a tocar o chão.
## Os dois pés podem se mover juntos aqui — é a única exceção à regra de
## "nunca dois passos ao mesmo tempo": pouso é um evento discreto, não
## parte do ciclo normal de caminhada.
func _handle_landing() -> void:
	_land_foot(_left, _left_home, _left_target)
	_land_foot(_right, _right_home, _right_target)


func _land_foot(foot: FootStep, home: Node3D, target: Node3D) -> void:
	var ground: Vector3 = _ground_point(home.global_position)
	var to_ground: Vector3 = ground - foot.planted_pos
	if to_ground.length() <= landing_snap_distance:
		_plant(foot, target, ground)
		return

	foot.stepping = true
	foot.t = 0.0
	foot.duration = landing_step_duration
	foot.height = landing_step_height
	foot.start_pos = foot.planted_pos
	foot.end_pos = ground
	if debug_print_steps:
		print("[ProceduralLocomotion] %s LANDING (d=%.2f)" % [foot.name, to_ground.length()])


func _update_foot(foot: FootStep, home: Node3D, target: Node3D, delta: float, speed: float, other: FootStep) -> void:
	if foot.stepping:
		foot.t += delta / maxf(foot.duration, 0.01)
		var f: float = clampf(foot.t, 0.0, 1.0)
		var eased_f: float = ease(f, ease_strength)
		# O home continua andando durante a passada: mira sempre no home
		# atual (já projetado no chão), senão o pé pousa atrás do corpo.
		foot.end_pos = _ground_point(home.global_position)
		var pos: Vector3 = foot.start_pos.lerp(foot.end_pos, eased_f)
		pos.y += sin(f * PI) * foot.height
		target.global_position = pos
		if f >= 1.0:
			_plant(foot, target, foot.end_pos)
		return

	# --- Pé plantado: TRAVA em mundo (não acompanha o corpo) ---
	target.global_position = foot.planted_pos

	var home_ground: Vector3 = _ground_point(home.global_position)

	var drift: Vector3 = home_ground - foot.planted_pos
	drift.y = 0.0
	var d: float = drift.length()

	# Quanto a perna já está esticada, medida do quadril até o pé.
	var stretch_vec: Vector3 = _player.global_position - foot.planted_pos
	stretch_vec.y = 0.0
	var stretch: float = stretch_vec.length()

	if d > snap_distance:
		_plant(foot, target, home_ground)
		if debug_print_steps:
			print("[ProceduralLocomotion] %s SNAP (d=%.2f)" % [foot.name, d])
		return

	var eff_trigger: float = _effective_trigger_distance(speed)
	var eff_stretch: float = _effective_max_stretch(speed)

	# Parado o suficiente: aperta o limiar pra bem menor que o normal — o
	# pé sempre volta pro home exato em vez de ficar "quase lá".
	if _idle_elapsed > idle_settle_delay:
		eff_trigger = minf(eff_trigger, idle_trigger_distance)

	# Girou no lugar (parado/quase parado) além do limite: força
	# replante, mesmo com pouca distância. Resolve o pé grudado ao girar
	# a câmera parado.
	var turned: bool = speed < turn_in_place_speed and _yaw_delta(foot.plant_yaw) > deg_to_rad(plant_rotation_threshold_deg)

	# Rede de segurança: os dois pés plantados ficaram perto demais um do
	# outro (qualquer que seja a causa) — corrige.
	var gap: Vector3 = other.planted_pos - foot.planted_pos
	gap.y = 0.0
	var too_close: bool = gap.length() < min_foot_separation

	# Só pode começar um passo se o outro NÃO estiver no ar, ou já tiver
	# passado de step_overlap da própria passada. É isso que impede os
	# dois pés de saírem juntos numa aceleração brusca.
	var other_ready: bool = (not other.stepping) or (other.t >= step_overlap)

	var forced: bool = stretch > eff_stretch and other_ready
	var normal: bool = (d > eff_trigger or turned or too_close) and other_ready

	if forced or normal:
		foot.stepping = true
		foot.t = 0.0
		foot.duration = _effective_duration(speed)
		foot.height = _effective_height(speed)
		foot.start_pos = foot.planted_pos
		foot.end_pos = home_ground
		if debug_print_steps:
			var reason := "FORCED" if forced else ("TURN" if turned else ("GAP" if too_close else "normal"))
			print("[ProceduralLocomotion] %s STEP %s | speed=%.2f d=%.2f stretch=%.2f dur=%.2f h=%.2f trig=%.2f str=%.2f" % [
				foot.name, reason, speed, d, stretch, foot.duration, foot.height, eff_trigger, eff_stretch,
			])

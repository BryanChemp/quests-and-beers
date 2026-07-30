class_name LocomotionPresets
extends RefCounted
## Tabela estática de parâmetros de passo por estado.
##
## - "step_duration" é a duração de REFERÊNCIA (na velocidade base do
##   estado). ProceduralLocomotion encurta ela conforme a velocidade
##   real, então o pé nunca fica com passada em aberto quando você
##   acelera.
## - "max_stretch" evita a perna esticada: assim que o quadril se afasta
##   mais do que isso do pé plantado, o passo dispara na marra. Tanto
##   "max_stretch" quanto "step_trigger_distance" agora também escalam
##   continuamente com a velocidade real dentro do preset (ver
##   dynamic_scale_min/max em ProceduralLocomotion) — os valores aqui são
##   o ponto de calibração em reference_speed, não um teto fixo.
## - "step_overlap" (NOVO): 0..1, quanto do passo do outro pé precisa
##   estar completo antes deste poder começar. 1.0 = nunca sobrepõe
##   (comportamento estrito, igual ao original). Presets de corrida usam
##   um valor menor pra permitir uma pequena antecipação — isso é o que
##   impede os dois pés de saírem ao mesmo tempo numa aceleração brusca,
##   sem deixar a perna esperando esticada o passo inteiro do outro pé.
## - "step_height" foi levantado de propósito em todos os estados: o
##   feedback foi "muito colado no chão".
enum State {
	WALK,
	RUN,
	WALK_STRAFE,
	RUN_STRAFE,
	CROUCH_WALK,
	CROUCH_RUN,
}
## Nome legível pra debug/print.
const STATE_NAMES := {
	State.WALK: "WALK",
	State.RUN: "RUN",
	State.WALK_STRAFE: "WALK_STRAFE",
	State.RUN_STRAFE: "RUN_STRAFE",
	State.CROUCH_WALK: "CROUCH_WALK",
	State.CROUCH_RUN: "CROUCH_RUN",
}
const PRESETS := {
	# ~2.0 m/s — perfeito, mantido estrito (overlap=1.0 = comportamento antigo).
	State.WALK: {
		"step_duration": 0.26,
		"step_height": 0.20,
		"step_trigger_distance": 0.32,
		"max_stretch": 0.52,
		"step_overlap": 1.0,
		"ease_strength": -1.6,
		"prediction_time": 0.10,
		"max_speed_for_prediction": 2.5,
		"reference_speed": 2.0,
	},
	# ~5.5 m/s — aqui estava o pior caso de "estica, flutua e sai os 2 juntos".
	State.RUN: {
		"step_duration": 0.18,
		"step_height": 0.38,
		"step_trigger_distance": 0.55,
		"max_stretch": 0.85,
		"step_overlap": 0.55,
		"ease_strength": -2.0,
		"prediction_time": 0.12,
		"max_speed_for_prediction": 6.0,
		"reference_speed": 5.5,
	},
	State.WALK_STRAFE: {
		"step_duration": 0.24,
		"step_height": 0.15,
		"step_trigger_distance": 0.26,
		"max_stretch": 0.44,
		"step_overlap": 1.0,
		"ease_strength": -1.3,
		"prediction_time": 0.06,
		"max_speed_for_prediction": 2.2,
		"reference_speed": 1.8,
	},
	State.RUN_STRAFE: {
		"step_duration": 0.18,
		"step_height": 0.26,
		"step_trigger_distance": 0.40,
		"max_stretch": 0.65,
		"step_overlap": 0.6,
		"ease_strength": -1.7,
		"prediction_time": 0.10,
		"max_speed_for_prediction": 4.5,
		"reference_speed": 4.0,
	},
	State.CROUCH_WALK: {
		"step_duration": 0.30,
		"step_height": 0.12,
		"step_trigger_distance": 0.22,
		"max_stretch": 0.34,
		"step_overlap": 1.0,
		"ease_strength": -1.4,
		"prediction_time": 0.08,
		"max_speed_for_prediction": 1.2,
		"reference_speed": 1.2,
	},
	State.CROUCH_RUN: {
		"step_duration": 0.24,
		"step_height": 0.18,
		"step_trigger_distance": 0.34,
		"max_stretch": 0.50,
		"step_overlap": 0.7,
		"ease_strength": -1.8,
		"prediction_time": 0.10,
		"max_speed_for_prediction": 2.6,
		"reference_speed": 2.6,
	},
}
static func get_preset(state: State) -> Dictionary:
	return PRESETS.get(state, PRESETS[State.WALK])
static func get_state_name(state: State) -> String:
	return STATE_NAMES.get(state, "UNKNOWN(%d)" % state)

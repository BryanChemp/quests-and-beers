class_name LocomotionPresets
extends RefCounted
## Tabela estática de parâmetros de passo por estado.
##
## MUDANÇA IMPORTANTE em relação à v1:
## - "step_duration" agora é a duração de REFERÊNCIA (na velocidade base do
##   estado). ProceduralLocomotion encurta ela conforme a velocidade real,
##   então o pé nunca fica com passada em aberto quando você acelera.
## - "max_stretch" é o que realmente evita a perna esticada: assim que o
##   quadril se afasta mais do que isso do pé plantado, o passo dispara na
##   marra, mesmo que o outro pé ainda esteja no ar.
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
	# ~2.0 m/s
	State.WALK: {
		"step_duration": 0.26,
		"step_height": 0.20,          # era 0.12 — passo visível ao andar
		"step_trigger_distance": 0.32,
		"max_stretch": 0.52,          # perna nunca estica além disso
		"ease_strength": -1.6,
		"prediction_time": 0.10,
		"max_speed_for_prediction": 2.5,
		"reference_speed": 2.0,
	},
	# ~5.5 m/s — aqui estava o pior caso de "estica e flutua"
	State.RUN: {
		"step_duration": 0.18,
		"step_height": 0.38,          # corrida levanta MUITO o joelho
		"step_trigger_distance": 0.55, # menor que 0.70: passada mais frequente
		"max_stretch": 0.85,
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

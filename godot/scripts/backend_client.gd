extends Node
## Read-only client. One HTTP request at a time; retry polls, never write state.

signal state_updated(state: Dictionary)
signal events_received(events: Array, historical: bool)
signal connection_changed(online: bool, message: String)
signal session_reset

const Protocol = preload("res://scripts/protocol.gd")
var protocol = Protocol.new()
var backend_url: String = "http://127.0.0.1:8000"
var http: HTTPRequest
var timer: Timer
var phase: String = ""
var running: bool = false

func _ready() -> void:
	http = HTTPRequest.new()
	http.timeout = 4.0
	add_child(http)
	http.request_completed.connect(_completed)
	timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = 0.5
	add_child(timer)
	timer.timeout.connect(_poll)

func connect_to(url: String) -> void:
	stop()
	backend_url = url.strip_edges().trim_suffix("/")
	protocol.reset()
	session_reset.emit()
	if not (backend_url.begins_with("http://") or backend_url.begins_with("https://")):
		connection_changed.emit(false, "Use an http:// or https:// backend URL.")
		return
	running = true
	_poll()

func stop() -> void:
	running = false
	if timer:
		timer.stop()
	if http:
		http.cancel_request()
	phase = ""

func _poll() -> void:
	if running:
		_request("state", "/state")

func _request(next_phase: String, path: String) -> void:
	phase = next_phase
	var error := http.request(backend_url + path, ["Cache-Control: no-cache"])
	if error != OK:
		_failed("Cannot start request. Retrying...")

func _completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not running:
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_failed("Backend unavailable. Retrying...")
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if phase == "state":
		if not Protocol.valid_state(data):
			_failed("Invalid world state. Retrying...")
			return
		if protocol.observe_state(data):
			session_reset.emit()
		state_updated.emit(data.duplicate(true))
		_request("events", "/events?after=%d" % protocol.cursor)
	elif phase == "events":
		if not Protocol.valid_events(data):
			_failed("Invalid event data. Retrying...")
			return
		var historical: bool = not protocol.initialized
		var fresh: Array = protocol.accept_events(data)
		events_received.emit(fresh, historical)
		connection_changed.emit(true, "Connected / live")
		phase = ""
		timer.start()

func _failed(message: String) -> void:
	phase = ""
	connection_changed.emit(false, message)
	if running:
		timer.start(1.0)

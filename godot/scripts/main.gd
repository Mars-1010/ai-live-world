extends Node2D

const BackendClient = preload("res://scripts/backend_client.gd")
const WorldView = preload("res://scripts/world_view.gd")
var client: Node
var view: Node2D
var address: LineEdit

func _ready() -> void:
	view = WorldView.new()
	add_child(view)
	client = BackendClient.new()
	add_child(client)
	client.state_updated.connect(view.update_state)
	client.events_received.connect(view.receive_events)
	client.connection_changed.connect(view.update_connection)
	client.session_reset.connect(view.reset_session)
	var url := OS.get_environment("AI_LIVE_WORLD_API_URL")
	if url.is_empty():
		url = "http://127.0.0.1:8000"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--backend-url="):
			url = argument.trim_prefix("--backend-url=")
	address = LineEdit.new()
	address.position = Vector2(32, 654)
	address.size = Vector2(565, 34)
	address.text = url
	address.placeholder_text = "http://127.0.0.1:8000"
	address.tooltip_text = "FastAPI base URL. Press Enter to reconnect and reload history."
	address.add_theme_font_size_override("font_size", 16)
	address.text_submitted.connect(func(_value): _reconnect())
	add_child(address)
	var button := Button.new()
	button.position = Vector2(608, 654)
	button.size = Vector2(152, 34)
	button.text = "Connect / resync"
	button.pressed.connect(_reconnect)
	add_child(button)
	client.connect_to(url)

func _reconnect() -> void:
	client.connect_to(address.text)

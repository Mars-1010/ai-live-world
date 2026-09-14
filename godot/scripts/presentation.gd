extends RefCounted
## Presentation choices only. Event IDs select copy deterministically, not randomly.

const REACTIONS = ["neutral", "happy", "shocked", "annoyed", "panicked", "defeated"]
const GIFT_STYLES = {
	"food_drop": {
		"copy": ["续命成功", "饭来！", "还能再炫"],
		"color": Color("f7d544"), "ink": Color("1c2030"), "duration": 1.6, "tier": 1,
	},
	"rain": {
		"copy": ["谁把天捅漏了", "这班没法上", "猫都淋无语了"],
		"color": Color("90d8ff"), "ink": Color("101629"), "duration": 2.1, "tier": 2,
	},
	"meteor_strike": {
		"copy": ["天塌了", "猫生完了", "陨石已送达"],
		"color": Color("ff603b"), "ink": Color("fff5c9"), "duration": 2.8, "tier": 3,
	},
}
const LABELS = {
	"title": "这猫今天又咋了",
	"subtitle": "弹幕一动，猫生震动。",
	"warning": "有东西下来了！",
	"aftermath": "电没了，猫也蔫了",
	"waiting": "猫呢？正在连线…",
}
const ACTION_COPY = {
	"idle": "先装作没事", "walk": "巡视我的江山", "eat": "干饭勿扰",
	"sleep": "已读，已睡", "work": "打工猫已上线", "explore": "我去看看咋回事",
}
const REACTION_COPY = {"panicked_left": "啊！", "panicked_right": "救！", "shocked": "？！"}

static func phrase(effect: String, event_id: int) -> String:
	var choices: Array = GIFT_STYLES.get(effect, {}).get("copy", [""])
	return choices[posmod(event_id - 1, choices.size())]

static func duration(effect: String) -> float:
	return GIFT_STYLES.get(effect, {}).get("duration", 0.0)

static func reaction(state: Dictionary, effect: String, elapsed: float) -> String:
	if effect == "meteor_strike":
		return "shocked" if elapsed < 0.6 else "panicked"
	if effect == "food_drop":
		return "happy"
	if effect == "rain":
		return "shocked" if elapsed < 0.4 else "annoyed"
	var cat: Dictionary = state.get("cat", {})
	var world: Dictionary = state.get("world", {})
	if not world.get("power", true) or cat.get("hp", 100) <= 20 or cat.get("mood", 70) <= 15:
		return "defeated"
	if world.get("weather", "clear") == "rain" or cat.get("action") == "work":
		return "annoyed"
	if cat.get("action") == "eat":
		return "happy"
	if cat.get("action") == "sleep":
		return "defeated"
	return "neutral"

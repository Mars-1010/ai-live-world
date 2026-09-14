import { Simulator } from "./client.mjs";

const element = (id) => document.getElementById(id);
const actions = { walk: "散步", eat: "吃饭", sleep: "睡觉", work: "工作", explore: "探索", idle: "休息" };
const effects = {
  food_drop: ["补给已送达", "饥饿 −20，心情 +5，猫咪开始吃饭。"],
  rain: ["下雨了", "世界天气已变为下雨。"],
  meteor_strike: ["陨石来袭！", "生命 −30，心情 −20，电力中断，陨石灾害已激活。"],
  action_suggestion: ["动作建议", ""],
  ignored_comment: ["弹幕已记录", "未匹配预设动作，世界状态不变。"],
};
let online = false;
let sending = false;
let eventCount = 0;
let toastTimer;

function connection(connected) {
  online = connected;
  element("connection").dataset.online = String(connected);
  element("connection").textContent = connected ? "实时连接" : "连接中断 · 自动重试";
  element("controls").disabled = !online || sending;
}

function showError(message = "") {
  element("error").textContent = message;
  element("error").hidden = !message;
}

const simulator = new Simulator({
  onState(state) {
    for (const stat of ["hp", "hunger", "mood"]) {
      element(stat).value = state.cat[stat];
      element(`${stat}-value`).textContent = state.cat[stat];
    }
    element("money").textContent = state.cat.money;
    element("weather").textContent = state.world.weather === "rain" ? "下雨" : "晴朗";
    element("power").textContent = state.world.power ? "正常供电" : "停电";
    element("action").textContent = `${actions[state.cat.action]} / ${state.cat.action}`;
    element("event-id").textContent = `#${state.meta.last_event_id}`;
    element("scene").dataset.weather = state.world.weather;
    element("scene").dataset.power = String(state.world.power);
    element("scene-caption").textContent = `猫咪正在${actions[state.cat.action]}`;
  },
  onEvents(events) {
    const feed = element("feed");
    const nearBottom = feed.scrollHeight - feed.scrollTop - feed.clientHeight < 60;
    for (const event of events) {
      const item = document.createElement("li");
      item.dataset.eventId = event.id;
      const number = document.createElement("span");
      number.className = "event-number";
      number.textContent = `#${event.id}`;
      const content = document.createElement("div");
      const title = document.createElement("div");
      title.className = "event-title";
      title.textContent = effects[event.effect]?.[0] ?? event.effect;
      const detail = document.createElement("p");
      detail.className = "event-detail";
      // Viewer text is always textContent, never interpreted as HTML.
      detail.textContent = event.type === "comment"
        ? `“${event.payload.text}”${event.effect === "ignored_comment" ? " · 仅记录" : ""}`
        : effects[event.effect]?.[1] ?? event.effect;
      content.append(title, detail);
      item.append(number, content);
      feed.append(item);
    }
    eventCount += events.length;
    element("feed-count").textContent = `${eventCount} 条事件`;
    element("empty-feed").hidden = eventCount > 0;
    if (nearBottom) feed.scrollTop = feed.scrollHeight;
  },
  onGift(event) {
    clearTimeout(toastTimer);
    const toast = element("toast");
    toast.dataset.effect = event.effect;
    toast.textContent = `#${event.id} · ${effects[event.effect]?.[0] ?? event.effect}`;
    toast.hidden = false;
    toastTimer = setTimeout(() => { toast.hidden = true; }, 2600);
  },
  onReset() {
    element("feed").replaceChildren();
    eventCount = 0;
    element("feed-count").textContent = "0 条事件";
    element("empty-feed").hidden = false;
    element("toast").hidden = true;
  },
});

async function sync() {
  try {
    await simulator.refresh();
    connection(true);
  } catch {
    connection(false);
  }
}

async function send(type, payload) {
  if (sending) return;
  sending = true;
  element("controls").disabled = true;
  showError();
  try {
    await simulator.send(type, payload);
    if (type === "comment") element("comment").value = "";
    // A failed feed refresh must not report an accepted event as failed.
    await sync();
  } catch (error) {
    showError(error.message === "HTTP 422"
      ? "内容不符合要求，请检查后重试。"
      : "未能确认发送结果。请先查看事件记录再决定是否重试，以免重复发送。" );
  } finally {
    sending = false;
    element("controls").disabled = !online;
  }
}

for (const button of document.querySelectorAll("[data-comment]")) {
  button.addEventListener("click", () => send("comment", { text: button.dataset.comment }));
}
for (const button of document.querySelectorAll("[data-gift]")) {
  button.addEventListener("click", () => send("gift", { tier: button.dataset.gift }));
}
element("comment-form").addEventListener("submit", (event) => {
  event.preventDefault();
  const text = element("comment").value.trim();
  if (!text) return showError("请输入一条弹幕。");
  send("comment", { text });
});

async function poll() {
  await sync();
  setTimeout(poll, 1000);
}
poll();

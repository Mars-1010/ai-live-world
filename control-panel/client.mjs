// Shared by the browser and Node's dependency-free test runner.
export async function request(path, body) {
  const abort = new AbortController();
  const timeout = setTimeout(() => abort.abort(), 5000);
  try {
    const response = await fetch(path, {
      method: body === undefined ? "GET" : "POST",
      headers: body === undefined ? {} : { "Content-Type": "application/json" },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: abort.signal,
      cache: "no-store",
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return await response.json();
  } finally {
    clearTimeout(timeout);
  }
}

export class Simulator {
  constructor({ transport = request, onState, onEvents, onGift, onReset }) {
    Object.assign(this, { transport, onState, onEvents, onGift, onReset });
    this.cursor = 0;
    this.stateId = 0;
    this.initialized = false;
    this.announced = new Set();
    this.pending = Promise.resolve();
  }

  enqueue(operation) {
    const next = this.pending.then(operation);
    // A failed request must not block all future polling or submissions.
    this.pending = next.catch(() => {});
    return next;
  }

  showState(state) {
    if (state.meta.last_event_id < this.stateId) {
      this.cursor = 0;
      this.announced.clear();
      this.initialized = false;
      this.onReset();
    }
    this.stateId = state.meta.last_event_id;
    this.onState(state);
  }

  showGift(event) {
    if (event.type === "gift" && !this.announced.has(event.id)) {
      this.announced.add(event.id);
      this.onGift(event);
    }
  }

  refresh() {
    return this.enqueue(async () => {
      this.showState(await this.transport("/state"));
      const events = await this.transport(`/events?after=${this.cursor}`);
      const fresh = [];
      for (const event of [...events].sort((a, b) => a.id - b.id)) {
        if (event.id <= this.cursor) continue;
        this.cursor = event.id;
        fresh.push(event);
        if (this.initialized) this.showGift(event);
      }
      this.onEvents(fresh);
      this.initialized = true;
      // An external event may arrive between the state and feed requests.
      if (this.cursor > this.stateId) {
        this.showState(await this.transport("/state"));
      }
    });
  }

  send(type, payload) {
    return this.enqueue(async () => {
      const result = await this.transport(`/event/${type}`, payload);
      this.showState(result.state);
      this.showGift(result.event);
      // Only polling advances the feed cursor, so another viewer's earlier
      // events are not skipped when this POST returns a later event ID.
      return result;
    });
  }
}

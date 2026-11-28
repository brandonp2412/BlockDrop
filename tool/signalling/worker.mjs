export default {
  fetch(request, env) {
    const url = new URL(request.url);
    const room = /^\/signal\/([a-f0-9]{32})$/.exec(url.pathname);
    const role = url.searchParams.get("role");
    const origin = request.headers.get("Origin") ?? "";
    if (origin !== "https://brandonp2412.github.io" &&
        !/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) {
      return new Response("Origin not allowed", { status: 403 });
    }
    if (!room || !["host", "guest"].includes(role)) {
      return new Response("Invalid room or role", { status: 404 });
    }
    if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
      return new Response("WebSocket required", { status: 426 });
    }
    return env.ROOMS.get(env.ROOMS.idFromName(room[1])).fetch(request);
  },
};

// The room holds the two signalling sockets only. Gameplay flows over WebRTC.
export class SignalRoom {
  constructor(state) {
    this.state = state;
  }

  socket(role) {
    return this.state.getWebSockets(role).find(socket => socket.readyState === 1);
  }

  fetch(request) {
    const role = new URL(request.url).searchParams.get("role");
    const [client, server] = Object.values(new WebSocketPair());
    const host = this.socket("host");
    const roomTaken = role === "guest" && host?.deserializeAttachment()?.claimed;
    const error = this.socket(role) || roomTaken ? "Room is full." :
      role === "guest" && !host ? "The host is offline." : null;
    this.state.acceptWebSocket(server, [error ? "rejected" : role]);
    if (error) {
      server.send(JSON.stringify({ op: "error", message: error }));
      server.close(1000);
    } else {
      server.send(JSON.stringify({ op: "ready" }));
      if (role === "guest") {
        host.serializeAttachment({ claimed: true });
        host.send(JSON.stringify({ op: "join" }));
      }
    }
    return new Response(null, { status: 101, webSocket: client });
  }

  webSocketMessage(socket, payload) {
    if (typeof payload !== "string" || payload.length > 20000) return;
    let message;
    try {
      message = JSON.parse(payload);
    } catch {
      return;
    }
    const [role] = this.state.getTags(socket);
    if (role !== "host" && role !== "guest") return;
    const op = role === "host" ? "offer" : "answer";
    if (message?.op !== op || typeof message.sdp !== "string") return;
    this.socket(role === "host" ? "guest" : "host")?.send(
      JSON.stringify({ op, sdp: message.sdp }),
    );
  }

  webSocketClose(socket) {
    const [role] = this.state.getTags(socket);
    if (role === "host" || role === "guest") {
      this.socket(role === "host" ? "guest" : "host")?.send('{"op":"left"}');
    }
    socket.close();
  }
}

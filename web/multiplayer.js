"use strict";

(() => {
  const invitePattern = /^#room=([a-f0-9]{32})$/;
  window.blockDropInvite = invitePattern.exec(location.hash)?.[1] ?? null;
  if (window.blockDropInvite) {
    history.replaceState(history.state, "", location.pathname + location.search);
  }
  window.addEventListener("hashchange", event => {
    if (!invitePattern.test(location.hash)) return;
    event.stopImmediatePropagation();
    location.reload();
  });
})();

window.blockDropOnline = (endpoint, turnEndpoint, room, host, event) => {
  const url = new URL(endpoint);
  url.pathname = url.pathname.replace(/\/$/, "") + "/signal/" + room;
  url.searchParams.set("role", host ? "host" : "guest");
  const signalling = new WebSocket(url);
  let peer;
  let channel;
  let stopped = false;
  let connected = false;
  const timeout = () => setTimeout(() => fail("The online connection timed out."), 20000);
  let timer = timeout();

  function close(gracefully = true) {
    if (stopped) return;
    stopped = true;
    clearTimeout(timer);
    signalling.close();
    if (gracefully && channel?.readyState === "open") {
      // Let SCTP deliver a queued quit or rejection before closing ICE.
      const finish = () => {
        clearTimeout(deadline);
        peer.close();
      };
      const deadline = setTimeout(finish, 1000);
      channel.addEventListener("close", finish, { once: true });
      channel.close();
    } else {
      peer?.close();
    }
  }

  function fail(message) {
    if (stopped) return;
    close(false);
    event("closed", message);
  }

  async function createPeer() {
    if (peer) throw Error();
    const iceServers = [
      { urls: "stun:stun.l.google.com:19302" },
      { urls: "stun:stun.cloudflare.com:3478" },
    ];
    if (turnEndpoint) {
      try {
        const response = await fetch(turnEndpoint, {
          cache: "no-store",
          signal: AbortSignal.timeout(3000),
        });
        if (response.ok) iceServers.push(...(await response.json()).iceServers);
      } catch {
        // Direct ICE remains available if the credential broker is unavailable.
      }
    }
    if (stopped) return;
    peer = new RTCPeerConnection({ iceServers });
    peer.onconnectionstatechange = () => {
      if (peer.connectionState === "failed") fail("Could not connect to the other player.");
    };
    return peer;
  }

  function attach(dataChannel) {
    channel = dataChannel;
    channel.onopen = () => {
      connected = true;
      clearTimeout(timer);
      signalling.close();
      event("open", "");
    };
    channel.onmessage = ({ data }) => {
      if (typeof data !== "string" || data.length > 16384) {
        fail("Invalid multiplayer message.");
        return;
      }
      event("message", data);
    };
    channel.onclose = () => fail("");
    channel.onerror = () => fail("The online connection failed.");
  }

  async function sendDescription(connection, op, description) {
    await connection.setLocalDescription(description);
    // A complete SDP avoids needing a separate signalling path for ICE candidates.
    if (connection.iceGatheringState !== "complete") {
      await new Promise(resolve => {
        const finish = () => {
          clearTimeout(deadline);
          connection.removeEventListener("icegatheringstatechange", check);
          resolve();
        };
        const check = () => {
          if (connection.iceGatheringState === "complete") finish();
        };
        const deadline = setTimeout(finish, 3500);
        connection.addEventListener("icegatheringstatechange", check);
        check();
      });
    }
    if (!stopped && signalling.readyState === WebSocket.OPEN) {
      signalling.send(JSON.stringify({ op, sdp: connection.localDescription.sdp }));
    }
  }

  let pending = Promise.resolve();
  signalling.onmessage = ({ data }) => {
    pending = pending.then(async () => {
      if (stopped || connected) return;
      const { op, sdp, message } = JSON.parse(data);
      if (op === "error") fail(message);
      if (op === "ready") {
        if (host) clearTimeout(timer);
        event("ready", "");
      }
      if (host && op === "join") {
        timer = timeout();
        event("negotiating", "");
        const connection = await createPeer();
        if (!connection) return;
        attach(connection.createDataChannel("blockdrop"));
        await sendDescription(connection, "offer", await connection.createOffer());
      }
      if (!host && op === "offer") {
        const connection = await createPeer();
        if (!connection) return;
        connection.ondatachannel = ({ channel }) => attach(channel);
        await connection.setRemoteDescription({ type: "offer", sdp });
        await sendDescription(connection, "answer", await connection.createAnswer());
      }
      if (host && op === "answer") await peer.setRemoteDescription({ type: "answer", sdp });
      if (op === "left" && !connected) {
        // Either side can open and close signalling just before its peer opens.
        if (!peer?.remoteDescription) fail("The other player left the invitation.");
      }
    }).catch(() => fail("Could not negotiate the online connection."));
  };
  signalling.onclose = () => {
    if (!connected) fail("Could not reach the matchmaking service.");
  };

  return {
    send(message) {
      if (channel?.readyState === "open") channel.send(message);
    },
    close,
  };
};

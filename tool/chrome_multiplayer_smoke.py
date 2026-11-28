"""Play an online match in two isolated Chrome contexts against a running build."""

import argparse
import json
from pathlib import Path

from playwright.sync_api import sync_playwright


OBSERVE_NETWORK = """
window.multiplayerProof = { incoming: [], signalling: [], peers: [], endpoint: null };
const proof = window.multiplayerProof;
const NativeWebSocket = window.WebSocket;
window.WebSocket = class extends NativeWebSocket {
  constructor(...args) {
    super(...args);
    const endpoint = new URL(args[0]);
    if (endpoint.pathname.startsWith("/signal/")) {
      proof.endpoint = endpoint.origin;
      this.addEventListener("message", ({ data }) => proof.signalling.push(JSON.parse(data).op));
      this.addEventListener("close", () => proof.signalling.push("closed"));
    }
  }
};
function observe(channel) {
  channel.addEventListener("message", ({ data }) => {
    const { type, score, cells, mode } = JSON.parse(data);
    proof.incoming.push({ type, score, cells, mode });
    if (proof.incoming.length > 500) proof.incoming.shift();
  });
}
const NativePeer = window.RTCPeerConnection;
window.RTCPeerConnection = class extends NativePeer {
  constructor(...args) {
    super(...args);
    proof.peers.push(this);
    this.addEventListener("datachannel", ({ channel }) => observe(channel));
  }
  createDataChannel(...args) {
    const channel = super.createDataChannel(...args);
    observe(channel);
    return channel;
  }
};
"""


def enable_semantics(page):
    page.locator("flt-semantics-placeholder").evaluate("(element) => element.click()")


def exact(page, label):
    return page.get_by_text(label, exact=True)


def wait_for_locked_piece(page):
    return page.wait_for_function(
        """window.multiplayerProof.incoming.findLast(message =>
          message.type === 'board_snapshot' && message.cells.length === 200 &&
          message.cells.slice(-40).some(cell => cell > 0))""",
    ).json_value()


def wait_for_signal_close(page):
    page.wait_for_function("window.multiplayerProof.signalling.includes('closed')")


def run(browser, url, artifacts):
    def player():
        context = browser.new_context(
            viewport={"width": 1280, "height": 900},
            permissions=["clipboard-read", "clipboard-write"],
            locale="en-US",
        )
        context.add_init_script(OBSERVE_NETWORK)
        context.add_init_script(
            "localStorage.setItem('flutter.show_opponent_board', 'true');"
        )
        return context.new_page()

    host, guest = player(), player()
    for page in (host, guest):
        page.set_default_timeout(15000)
    errors = []
    for page in (host, guest):
        page.on("pageerror", lambda error: errors.append(str(error)))
    host.goto(url)
    enable_semantics(host)
    host.keyboard.press("Escape")
    host.get_by_role("textbox").fill("Play online")
    exact(host, "Play online").click()
    exact(host, "Host online game").click()
    exact(host, "Copy invitation").click(timeout=25000)
    invite = host.evaluate("navigator.clipboard.readText()")
    assert invite.startswith(url + "#room=")

    guest.goto(invite)
    enable_semantics(guest)
    exact(host, "Accept").click(timeout=25000)
    exact(guest, "Waiting for host to start…").wait_for()
    for page, operation in ((host, "answer"), (guest, "offer")):
        wait_for_signal_close(page)
        assert operation in page.evaluate("window.multiplayerProof.signalling")
        assert page.evaluate("window.multiplayerProof.peers[0].connectionState") == "connected"

    exact(host, "Fair").click()
    exact(guest, "Fair mode").wait_for()
    exact(host, "Start Game").click()
    exact(host, "YOU").wait_for()
    exact(guest, "YOU").wait_for()
    guest.wait_for_function(
        """window.multiplayerProof.incoming.some(
          message => message.type === 'game_start' && message.mode === 'shared_pieces')"""
    )
    for page in (host, guest):
        page.wait_for_function(
            "window.multiplayerProof.incoming.some(message => message.type === 'board_snapshot')"
        )

    host.keyboard.press("Space")
    host_board = wait_for_locked_piece(guest)
    exact(guest, str(host_board["score"])).first.wait_for()
    guest.keyboard.press("ArrowRight")
    guest.keyboard.press("ArrowRight")
    guest.keyboard.press("Space")
    guest_board = wait_for_locked_piece(host)
    assert host_board["cells"][-40:] != guest_board["cells"][-40:]
    exact(host, str(guest_board["score"])).first.wait_for()
    if artifacts:
        host.screenshot(path=artifacts / "host-playing.png")
        guest.screenshot(path=artifacts / "guest-playing.png")

    for _ in range(28):
        if exact(guest, "Play Again").is_visible():
            break
        guest.keyboard.press("Space", delay=50)
        guest.wait_for_timeout(275)
    exact(guest, "Game Over").wait_for()
    exact(host, "You Win!").wait_for()
    host.wait_for_function(
        "window.multiplayerProof.incoming.some(message => message.type === 'game_over')"
    )
    for page in (host, guest):
        assert exact(page, "Play Again").count() == 1
        assert not exact(page, "Game Over!").is_visible()
    if artifacts:
        host.screenshot(path=artifacts / "host-result.png")
        guest.screenshot(path=artifacts / "guest-result.png")
    exact(host, "Play Again").click()
    exact(guest, "Play Again").click()
    exact(host, "Host online game").wait_for()
    exact(guest, "Host online game").wait_for()

    expired_guest = player()
    expired_guest.goto(invite)
    enable_semantics(expired_guest)
    exact(expired_guest, "The host is offline.").last.wait_for()
    exact(host, "Host online game").click()
    exact(host, "Copy invitation").click()
    second_invite = host.evaluate("navigator.clipboard.readText()")
    declined_guest = player()
    declined_guest.goto(second_invite)
    enable_semantics(declined_guest)
    exact(host, "Decline").click()
    exact(declined_guest, "Join rejected: declined").last.wait_for()
    exact(host, "Host online game").wait_for()
    assert not errors, errors
    return {
        "chrome": browser.version,
        "signalling": host.evaluate("window.multiplayerProof.endpoint"),
        "host_locked_cells_seen_by_guest": sum(cell > 0 for cell in host_board["cells"][-40:]),
        "guest_locked_cells_seen_by_host": sum(cell > 0 for cell in guest_board["cells"][-40:]),
        "passed": [
            "invite link and two-player lobby",
            "shared pieces and start",
            "signalling closed before gameplay",
            "bidirectional board snapshots and displayed scores",
            "one match result per player after invite guest tops out",
            "one-use invite is rejected after the match",
            "host decline reaches the guest and frees the lobby",
        ],
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url")
    parser.add_argument("--chrome", help="Path to a Google Chrome executable")
    parser.add_argument("--artifacts", type=Path)
    args = parser.parse_args()
    if args.artifacts:
        args.artifacts.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as playwright:
        options = {"executable_path": args.chrome} if args.chrome else {"channel": "chrome"}
        browser = playwright.chromium.launch(headless=True, **options)
        try:
            result = run(browser, args.url, args.artifacts)
            report = json.dumps(result, indent=2)
            print(report)
            if args.artifacts:
                (args.artifacts / "report.json").write_text(report + "\n")
        finally:
            browser.close()

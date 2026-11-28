from html import escape

PROFILES = {
    "phone": (450, 800, 2),
    "tablet": (820, 1180, 1),
    "desktop": (1440, 900, 1),
}

SECTIONS = {
    "Light theme": {
        f"light-{style}": style.title()
        for style in ("classic", "modern", "bubbles", "retro")
    },
    "Dark theme": {
        f"dark-{style}": style.title()
        for style in ("classic", "modern", "bubbles", "neon", "retro")
    },
    "Pure Black (AMOLED)": {
        f"black-{style}": style.title()
        for style in ("classic", "modern", "bubbles", "neon", "retro")
    },
    "Gameplay": {
        "on-screen-controls": "On-screen controls",
        "full-screen-board": "Full-screen board",
        "practice-level-picker": "Practice level picker",
        "practice-game": "Practice game",
        "game-over": "Game over",
        "quit-confirmation": "Quit confirmation",
    },
    "Multiplayer": {
        "multiplayer-countdown": "Match countdown",
        "multiplayer-match": "Match with opponent board",
    },
    "Settings and help": {
        "settings": "Settings and pause menu",
        "appearance-settings": "Appearance settings",
        "style-picker": "Style picker",
        "gameplay-settings": "Gameplay settings",
        "starting-speed": "Starting speed",
        "sound-settings": "Sound settings",
        "controller-settings": "Controller bindings",
        "settings-no-results": "Settings search with no results",
        "instructions": "Instructions",
        "about": "About Block Drop",
        "whats-new": "What’s new",
    },
}


def scenes(profile):
    return {
        group: {
            name: title for name, title in entries.items()
            if name != "full-screen-board" or profile != "desktop"
        }
        for group, entries in SECTIONS.items()
    }


def write_index(output, profiles):
    (output / "index.html").write_text("""<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Block Drop screenshot catalogue</title>
<style>
  :root { color-scheme: light dark; font-family: system-ui, sans-serif }
  body { max-width: 1280px; margin: auto; padding: 1rem }
  nav { display: flex; flex-wrap: wrap; gap: .8rem 1.2rem }
  .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 245px), 1fr)); gap: 1rem }
  .desktop { grid-template-columns: repeat(auto-fit, minmax(min(100%, 380px), 1fr)) }
  figure { margin: 0 }
  img { display: block; width: 100%; height: auto; border-radius: .5rem }
  figcaption { padding: .4rem 0 }
</style>
<h1>Block Drop screenshot catalogue</h1>
<p>Flutter web captures at phone, tablet, and desktop sizes. Select an image to open the full-size PNG.</p>
<nav aria-label="Layouts">
""" + "\n".join(f'<a href="#{profile}">{profile.title()}</a>' for profile in profiles)
        + "\n</nav>\n"
        + "\n".join(profile_html(profile) for profile in profiles), encoding="utf-8")


def profile_html(profile):
    width, height, scale = PROFILES[profile]
    sections = [f'<section id="{profile}"><h2>{profile.title()}</h2>']
    for group, entries in scenes(profile).items():
        sections.append(f'<h3>{escape(group)}</h3><div class="grid {profile}">')
        for name, title in entries.items():
            path = f"{profile}/{name}.png"
            sections.append(
                f'<figure><a href="{path}"><img src="{path}" loading="lazy" '
                f'width="{round(width * scale)}" height="{round(height * scale)}" '
                f'alt="{escape(title)}"></a><figcaption>{escape(title)}</figcaption></figure>'
            )
        sections.append("</div>")
    sections.append("</section>")
    return "\n".join(sections)


def write_readme(output, profiles):
    lines = [
        "# Block Drop screenshot catalogue",
        "",
        "Open [index.html](index.html) locally for the full gallery, or browse the PNGs below.",
        "",
        "The appearance comparisons use the same saved board, held piece, and upcoming piece.",
        "Neon forces a dark theme. The desktop capture uses the wide layout.",
        "The multiplayer scenes use sample opponents and scores.",
        "",
    ]
    for profile in profiles:
        lines.extend([f"## {profile.title()}", ""])
        for group, entries in scenes(profile).items():
            links = " · ".join(f"[{title}]({profile}/{name}.png)" for name, title in entries.items())
            lines.extend([f"- **{group}** — {links}"])
        lines.append("")
    (output / "README.md").write_text("\n".join(lines), encoding="utf-8")

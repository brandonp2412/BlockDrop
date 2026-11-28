from html import escape
from shutil import copyfile

PROFILES = {
    "phoneScreenshots": (450, 800, 2.4),
    "sevenInchScreenshots": (1440, 810, 4 / 3),
    "tenInchScreenshots": (1280, 800, 2),
    "desktop": (1600, 881, 1),
}

PROFILE_LABELS = {
    "phoneScreenshots": "Phone",
    "sevenInchScreenshots": "7-inch tablet",
    "tenInchScreenshots": "10-inch tablet",
    "desktop": "Desktop",
}

THEMES = {"dark": "Dark", "light": "Light", "amoled": "Black (AMOLED)"}

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
            if name != "full-screen-board" or profile == "phoneScreenshots"
        }
        for group, entries in SECTIONS.items()
    }


def build_gallery(captures, destination, profiles):
    destination.mkdir(parents=True, exist_ok=True)
    sections = []
    for profile in profiles:
        width, height, scale = PROFILES[profile]
        label = PROFILE_LABELS[profile]
        panels = []
        for theme in THEMES:
            groups = scenes(profile)
            theme_group = {"dark": "Dark theme", "light": "Light theme", "amoled": "Pure Black (AMOLED)"}[theme]
            selected = {theme_group: groups[theme_group]}
            if theme == "dark":
                selected.update({
                    group: entries for group, entries in groups.items()
                    if group not in ("Dark theme", "Light theme", "Pure Black (AMOLED)")
                })
            relative = profile if theme == "dark" else f"{theme}/{profile}"
            directory = destination / relative
            directory.mkdir(parents=True, exist_ok=True)
            hidden = "" if theme == "dark" else " hidden"
            panel = [f'<div data-panel="{theme}"{hidden}><h2>{label}</h2>']
            for group, entries in selected.items():
                panel.append(f'<h3>{escape(group)}</h3><div class="screens {profile}">')
                for name, title in entries.items():
                    filename = f"{name}.png"
                    copyfile(captures / profile / filename, directory / filename)
                    path = f"{relative}/{filename}"
                    title = escape(title)
                    panel.append(
                        f'<a href="{path}"><img loading="lazy" src="{path}" '
                        f'width="{round(width * scale)}" height="{round(height * scale)}" '
                        f'alt="{title}"><span>{title}</span></a>'
                    )
                panel.append("</div>")
            panel.append("</div>")
            panels.extend(panel)
        sections.append(f'<section id="{profile}">{"".join(panels)}</section>')
    links = " ".join(f'<a href="#{profile}">{PROFILE_LABELS[profile]}</a>' for profile in profiles)
    buttons = " ".join(
        f'<button type="button" data-choice="{theme}" aria-pressed="{str(theme == "dark").lower()}">{label}</button>'
        for theme, label in THEMES.items()
    )
    (destination / "index.html").write_text(
        """<!doctype html>
<html lang="en" data-theme="dark">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Block Drop screenshots</title>
<style>
  :root { color-scheme: dark; --bg: #121212; --fg: #eee; --card: #222; --link: #abc7ff }
  :root[data-theme=light] { color-scheme: light; --bg: #faf8ff; --fg: #1c1b20; --card: #e9edf7; --link: #2257a0 }
  :root[data-theme=amoled] { --bg: #000; --card: #111 }
  body { font: 16px system-ui, sans-serif; margin: 24px; background: var(--bg); color: var(--fg) }
  nav { position: sticky; top: 0; z-index: 1; background: var(--bg); display: grid; gap: 12px; padding: 12px 0 }
  nav div { display: flex; flex-wrap: wrap; gap: 12px }
  a { color: var(--link) }
  button { font: inherit; color: var(--fg); background: var(--card); border: 1px solid transparent; border-radius: 999px; padding: 7px 14px; cursor: pointer }
  button[aria-pressed=true] { border-color: var(--link); color: var(--link) }
  section { scroll-margin-top: calc(var(--nav-height, 120px) + 12px) }
  .screens { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 360px), 1fr)); gap: 16px }
  .phoneScreenshots { grid-template-columns: repeat(auto-fill, minmax(min(100%, 200px), 1fr)) }
  .screens a { display: grid; gap: 8px; background: var(--card); border-radius: 12px; padding: 12px; text-decoration: none }
  img { display: block; width: 100%; height: auto; border-radius: 5px }
</style>
<h1>Block Drop screenshots</h1>
<p>Choose a theme and device. Open any image at full resolution. Dark also includes gameplay, multiplayer, and settings scenes.</p>
"""
        + f'<nav><div role="group" aria-label="Screenshot theme">{buttons}</div><div>{links}</div></nav>'
        + "\n".join(sections)
        + """
<script>
  const nav = document.querySelector('nav');
  const panels = document.querySelectorAll('[data-panel]');
  const buttons = document.querySelectorAll('[data-choice]');
  const sections = Array.from(document.querySelectorAll('section')).reverse();
  new ResizeObserver(() => document.documentElement.style.setProperty('--nav-height', nav.offsetHeight + 'px')).observe(nav);
  for (const button of buttons) {
    button.addEventListener('click', () => {
      const section = sections.find(item => item.getBoundingClientRect().top <= nav.getBoundingClientRect().bottom + 24);
      const theme = button.dataset.choice;
      document.documentElement.dataset.theme = theme;
      for (const panel of panels) panel.hidden = panel.dataset.panel !== theme;
      for (const choice of buttons) choice.setAttribute('aria-pressed', String(choice === button));
      if (section) section.scrollIntoView();
    });
  }
</script>
</html>
""",
        encoding="utf-8",
    )

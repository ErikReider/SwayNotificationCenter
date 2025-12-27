# Ultra-Customizable MPRIS Widget for SwayNC

## 📋 Table of Contents

- [Overview](#overview)
- [Configuration Options](#configuration-options)
- [Practical Examples](#practical-examples)
- [Modified Files](#modified-files)

---

## Overview

This enhancement to SwayNotificationCenter adds **8 new JSON options** to fully customize the MPRIS widget, allowing layouts ranging from ultra-compact (only 3 buttons) to complete with all controls.

## Configuration Options

### 🎨 Element Visibility

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `show-album-art` | string | `"always"` | Controls album art display<br>• `"always"` - Always visible<br>• `"when-available"` - Only if artwork exists<br>• `"never"` - Always hidden |
| `show-title` | boolean | `true` | Shows track title or player name |
| `show-subtitle` | boolean | `true` | Shows "Artist - Album" |
| `show-background` | boolean | `true` | Displays blurred album art background |

### 🎛️ Controls

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `show-shuffle` | boolean | `true` | Shuffle button |
| `show-repeat` | boolean | `true` | Repeat button (None/Playlist/Track) |
| `show-favorite` | boolean | `true` | Favorite button _(not yet implemented in original code)_ |

### 🧩 Layout

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `compact-mode` | boolean | `false` | Optimized layout for small height _(placeholder for future optimizations)_ |
| `button-size` | integer | `-1` | Button size in pixels<br>• `-1` - Default theme size |

---

## Practical Examples

### 🎯 Ultra-Compact Mode (only play/pause/next/prev)

```json
{
  "widget-config": {
    "mpris": {
      "show-album-art": "never",
      "show-title": false,
      "show-subtitle": false,
      "show-background": false,
      "show-shuffle": false,
      "show-repeat": false,
      "compact-mode": true
    }
  }
}
```

**Result:** Only 3 horizontal buttons (⏮️ ⏯️ ⏭️) + player title

---

### 🎧 Minimalist Mode (cover + basic controls)

```json
{
  "widget-config": {
    "mpris": {
      "show-album-art": "when-available",
      "show-title": true,
      "show-subtitle": false,
      "show-background": true,
      "show-shuffle": false,
      "show-repeat": false
    }
  }
}
```

**Result:** Album cover + title + 3 main buttons

---

### 🎹 Complete Mode (all controls)

```json
{
  "widget-config": {
    "mpris": {
      "show-album-art": "always",
      "show-title": true,
      "show-subtitle": true,
      "show-background": true,
      "show-shuffle": true,
      "show-repeat": true,
      "button-size": 36
    }
  }
}
```

**Result:** Complete interface with all elements

---

### 🚫 Filter specific players

```json
{
  "widget-config": {
    "mpris": {
      "blacklist": ["firefox", "chromium", "spotify"],
      "show-shuffle": false,
      "show-repeat": false
    }
  }
}
```

**Result:** Ignores browsers and Spotify, without shuffle/repeat buttons

---

## Modified Files

### 1. `src/controlCenter/widgets/mpris/mpris.vala`

- **Struct `Config`** expanded with 8 new fields
- **Parsing** of new JSON options in constructor

### 2. `src/controlCenter/widgets/mpris/mpris_player.vala`

- **`update_title()`** - Respects `show_title`
- **`update_sub_title()`** - Respects `show_subtitle`
- **`update_album_art()`** - Respects `show_background`
- **`update_button_shuffle()`** - Early return if `!show_shuffle`
- **`update_button_repeat()`** - Early return if `!show_repeat`

### 3. `src/configSchema.json`

- Added 8 new properties to `mpris` widget schema

### 4. `data/ui/mpris_player.blp`

- Reverted to original behavior (code-controlled)

---

## Building

```bash
cd ~/git-clones/SwayNotificationCenter
meson setup build --prefix=/usr --wipe
meson compile -C build
sudo meson install -C build
killall swaync && swaync &
```

---

## User Configuration

Edit `~/.config/swaync/config.json` (create if it doesn't exist):

```json
{
  "$schema": "/etc/xdg/swaync/configSchema.json",
  "widgets": ["mpris", "notifications"],
  "widget-config": {
    "mpris": {
      "show-album-art": "never",
      "show-title": false,
      "show-subtitle": false,
      "show-shuffle": false,
      "show-repeat": false
    }
  }
}
```

Then reload the config:

```bash
swaync-client --reload-config
```

---

## Feature Status

| Feature | Status |
|---------------|--------|
| ✅ `show-album-art` | **Funcional** |
| ✅ `show-title` | **Funcional** |
| ✅ `show-subtitle` | **Funcional** |
| ✅ `show-background` | **Funcional** |
| ✅ `show-shuffle` | **Funcional** |
| ✅ `show-repeat` | **Funcional** |
| ⚠️ `show-favorite` | **Placeholder** (botão não existe no código original) |
| ⚠️ `compact-mode` | **Placeholder** (requer modificações no layout do .blp) |
| ⚠️ `button-size` | **Placeholder** (requer aplicação dinâmica de pixel-size) |

---

## Próximos Passos (Opcional)

1. **Implementar `button-size`**: Aplicar `set_pixel_size()` nos botões dinamicamente
2. **Implementar `compact-mode`**: Criar layout alternativo no `.blp` com orientação horizontal
3. **Adicionar `show-favorite`**: Criar botão de favorito/coração se o player suportar

---

## Créditos

- **SwayNotificationCenter Original**: [ErikReider/SwayNotificationCenter](https://github.com/ErikReider/SwayNotificationCenter)
- **Modificações**: Customização MPRIS ultra-personalizável via JSON

---

## Licença

Mesma licença do projeto original (GPL-3.0).

# 🎵 Quick Guide: Testing MPRIS Configurations

## Current Status

✅ **SwayNC compiled and installed** with new MPRIS options
✅ **Config loading**: `/home/bitter/.config/swaync/config.json`
✅ **MPRIS working**: Chromium player detected

## Current Configuration

You have `"show-album-art": "never"` on line 140 of your config.

## How to Test the New Options

### Method 1: Interactive Script (Recommended)

```bash
cd ~/git-clones/SwayNotificationCenter
./test-mpris-configs.sh
```

The script offers 4 presets:

- **Ultra-Compact**: Only control buttons
- **Minimal**: Cover + title + controls
- **Complete**: All elements
- **No-Art**: No images but with shuffle/repeat

### Method 2: Manual Editing

Edit `~/.config/swaync/config.json` and add options to the `mpris` section:

```json
"mpris": {
  "show-album-art": "when-available",
  "show-title": true,
  "show-subtitle": true,
  "show-background": true,
  "show-shuffle": false,
  "show-repeat": false,
  "show-favorite": false,
  "compact-mode": false,
  "button-size": -1,
  "autohide": false,
  "loop-carousel": true
}
```

Then reload:

```bash
swaync-client --reload-config
```

### Method 3: Quick Commands

**Ultra-Compact (only 3 buttons):**

```bash
cat > /tmp/mpris_patch.json << 'EOF'
{
  "show-album-art": "never",
  "show-title": false,
  "show-subtitle": false,
  "show-shuffle": false,
  "show-repeat": false
}
EOF

jq '.["widget-config"]["mpris"] = input' \
   ~/.config/swaync/config.json /tmp/mpris_patch.json > /tmp/config_new.json
mv /tmp/config_new.json ~/.config/swaync/config.json
swaync-client --reload-config
```

**Modo Completo:**

```bash
jq '.["widget-config"]["mpris"] = {
  "show-album-art": "always",
  "show-title": true,
  "show-subtitle": true,
  "show-background": true,
  "show-shuffle": true,
  "show-repeat": true
}' ~/.config/swaync/config.json > /tmp/config_new.json
mv /tmp/config_new.json ~/.config/swaync/config.json
swaync-client --reload-config
```

## Testing with Players

Play music in any MPRIS player:

```bash
# Spotify
spotify &

# VLC
vlc ~/Música/exemplo.mp3 &

# Chromium/Chrome (YouTube Music)
chromium --app=https://music.youtube.com &

# Firefox
firefox https://soundcloud.com &
```

Then open the Control Center:

```bash
swaync-client -t -sw
```

## Available Options

| Option | Values | Description |
|-------|---------|-----------|
| `show-album-art` | `"always"`, `"when-available"`, `"never"` | Controls album art |
| `show-title` | `true`, `false` | Track title |
| `show-subtitle` | `true`, `false` | Artist - Album |
| `show-background` | `true`, `false` | Blurred background |
| `show-shuffle` | `true`, `false` | Shuffle button |
| `show-repeat` | `true`, `false` | Repeat button |
| `show-favorite` | `true`, `false` | Favorite button (placeholder) |
| `compact-mode` | `true`, `false` | Compact layout (placeholder) |
| `button-size` | `-1` or pixels | Button size |
| `autohide` | `true`, `false` | Hide when no media |
| `loop-carousel` | `true`, `false` | Loop carousel |

## Configuration Examples

### For Desktop (space available)

```json
"mpris": {
  "show-album-art": "always",
  "show-title": true,
  "show-subtitle": true,
  "show-background": true,
  "show-shuffle": true,
  "show-repeat": true
}
```

### For Laptop (space saving)

```json
"mpris": {
  "show-album-art": "when-available",
  "show-title": true,
  "show-subtitle": false,
  "show-shuffle": false,
  "show-repeat": false
}
```

### Extreme Minimalist Mode

```json
"mpris": {
  "show-album-art": "never",
  "show-title": false,
  "show-subtitle": false,
  "show-background": false,
  "show-shuffle": false,
  "show-repeat": false
}
```

## Troubleshooting

**Config not being applied?**

```bash
# Check if SwayNC is running
ps aux | grep swaync

# Restart completely
killall swaync
swaync &
```

**JSON error?**

```bash
# Validate syntax
jq . ~/.config/swaync/config.json

# Check schema
jsonschema -i ~/.config/swaync/config.json /etc/xdg/swaync/configSchema.json
```

**Detailed logs:**

```bash
# Stop SwayNC
killall swaync

# Start with debug
G_MESSAGES_DEBUG=all swaync
```

## Resultado Esperado

Com `show-shuffle: false` e `show-repeat: false`, você deve ver:

- Apenas os botões: **⏮️ Anterior** | **⏯️ Play/Pause** | **⏭️ Próximo**
- Sem botões de shuffle (🔀) e repeat (🔁)

Se `show-album-art: "never"`:

- Nenhuma imagem/ícone será exibido

## Próximos Passos

Para personalizar ainda mais, consulte:

- `MPRIS-CUSTOMIZATION.md` - Documentação completa
- `mpris-config-example.json` - Template com todas as opções
- `/etc/xdg/swaync/configSchema.json` - Schema completo

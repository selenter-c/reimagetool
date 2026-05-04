# Re;Image Tool

A complete rewrite of the classic Image Tool for Garry's Mod. Place images from the internet as physical entities with full control over size, color, lighting, collision and more.

## Features
- Real entities with physics, collision and network sync
- Two placement modes: simple click and advanced size-drawing
- Double‑sided rendering, dynamic lighting, and color/alpha tint
- Adjustable render distance per image
- Automatic image caching and built‑in browser for local materials
- Smart URL correction (fixes typos in imgur, discord, gyazo etc.)
- 9 placement presets (center, edges, corners)
- Full undo, cleanup, CPPI and sandbox limit support

## Installation
1. Subscribe on the Steam Workshop or clone this repository to `garrysmod/addons/`.
2. Make sure the addon is enabled in your game or server.

## Usage
- Open the tool menu (`Q`) → **Asterion Tools** → **Re;Image Tool**.
- Paste an image URL (imgur, discord, gyazo or any direct .png/.jpg link).
- Adjust settings in the control panel.
- **Left click** to place normally.
- **Right click** to place and weld to an existing entity.
- **Hold E + Left click** to draw exact image dimensions on a surface.
- Press **R** to cycle through placement anchor points.

## Server configuration
All ConVars are replicated, change them in your server config:
| ConVar | Default | Description |
|--------|---------|-------------|
| `reimagetool_max_width` | 2048 | Maximum image width (pixels) |
| `reimagetool_max_height` | 2048 | Maximum image height (pixels) |
| `reimagetool_max_scale` | 10 | Maximum scale multiplier |
| `reimagetool_max_filesize` | 10 | Maximum downloaded file size (MB) |
| `sbox_maximages` | 5 | Images per player limit |

## Hooks for developers
- `PlayerSpawnImage(Player ply, table trace)` – return `false` to block placement.
- `OnCanSpawnImageInPlayer(Player ply, Entity target, table trace)` – return `false` to prevent placing on a player.

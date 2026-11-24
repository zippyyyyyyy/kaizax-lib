# Kaizax UI

![Kaizax UI screenshot placeholder](docs/screenshot.png)

A native Roblox interface library for dense tool panels: dark instrumentation chrome, one accent color, hairline borders, mono numeric readouts, and components that stay in sync with a live theme.

Everything renders with `ScreenGui`, `Frame`, `TextLabel`, `TextButton`, `TextBox`, `ScrollingFrame`, `UIListLayout`, `UICorner`, `UIStroke`, `UIPadding`, `UIScale`, and `TweenService`. There is no web runtime and no image assets to ship.

```
Window
├─ top bar: brand, search, minimize, close
├─ sidebar: tabs, version, toggle-key hint
└─ page: title, description, subtab bar, scrolling cards
```

## Highlights

- **Native and themeable.** Palette roles are stored as attributes, so one `SetTheme` call repaints every open window and notification host.
- **Complete control set.** Buttons, toggles, checkboxes, sliders, dropdowns, multi-dropdowns, text inputs, keybinds, color pickers, labels, paragraphs, dividers, spacers, statuses, search, and notifications.
- **Typed surface.** Strict Luau modules, exported option and instance types, and guarded callbacks.
- **Lifecycle safe.** Every connection, tween, popup, and GUI object is owned by a cleanup bag.
- **Reduced motion aware.** All motion goes through one animation helper and respects `GuiService.ReducedMotionEnabled`.
- **Window behavior.** Drag, resize, minimize, close, toggle key, viewport scaling, and popup placement that flips near screen edges.
- **Auto re-execute.** Queues the bundled script on teleport when the executor supports `queue_on_teleport`; requires an executor with that API.
- **Four presets.** Default (mint), Midnight (blue), Ember (amber), Graphite (neutral).

## Requirements

- Roblox Player or Studio with current Luau.
- Optional: [Rojo](https://rojo.space/) for syncing `src/` into a place.
- Optional: Wally for package management.

## Install

### Rojo

The repository ships `default.project.json`, which maps `src/` to the `Kaizax` folder:

```bash
rojo serve
```

Connect from the Rojo Studio plugin, then require the folder:

```lua
local Kaizax = require(game.ReplicatedStorage.Kaizax)
```

Place the synced folder where your project expects it, or edit the project tree.

### Manual

Copy `src/` into `ReplicatedStorage` and rename the folder to `Kaizax`. Keep the `Components` folder nested inside it. `init.luau` is the module entry point.

### Wally

```toml
[dependencies]
Kaizax = "zippyyyyyyy/kaizax-lib@0.1.0"
```

The package is not published to the public registry yet. Until then, use the Rojo or manual path.

## Quick start

```lua
local Kaizax = require(game.ReplicatedStorage.Kaizax)

local window = Kaizax:CreateWindow({
	Title = "Operations",
	Subtitle = "interface lab",
	Size = Vector2.new(1040, 720),
	ToggleKey = Enum.KeyCode.RightShift,
})

local tab = window:CreateTab({
	Name = "Overview",
	Description = "Session state and quick actions.",
})

local section = tab:CreateSection({ Name = "Session" })

section:CreateLabel({ Text = "Connected as build-bot" })

section:CreateToggle({
	Text = "Compact rows",
	Default = true,
	Callback = function(enabled)
		print("compact", enabled)
	end,
})

section:CreateSlider({
	Text = "Field of view",
	Min = 40,
	Max = 120,
	Default = 70,
	Suffix = "°",
	Live = true,
	Callback = function(value)
		print("fov", value)
	end,
})

section:CreateButton({
	Text = "Run check",
	Variant = "Primary",
	Callback = function()
		window:Notify({
			Title = "Check complete",
			Message = "All controls responded.",
			Kind = "success",
		})
	end,
})
```

A full demo lives in [`examples/Demo.luau`](examples/Demo.luau). It exercises every control, theme switching, notifications, status readouts, minimize, close, and destroy.

## One-line loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/zippyyyyyyy/kaizax-lib/main/build/kaizax-demo.luau"))()
```

The bundled demo includes the example harness. Auto re-execute requires an executor with `queue_on_teleport`.

## Components

| Factory | Returns | Notes |
| --- | --- | --- |
| `CreateButton` | Button | Primary, Secondary, Ghost, Danger variants |
| `CreateToggle` | Toggle | Animated switch |
| `CreateCheckbox` | Checkbox | Compact check mark |
| `CreateSlider` | Slider | Step rounding, suffix or custom formatter, live drag |
| `CreateDropdown` | Dropdown | Popup list |
| `CreateMultiDropdown` | MultiDropdown | Multi-select popup list |
| `CreateTextInput` | TextInput | Character limit, submit signal |
| `CreateKeybind` | Keybind | Hold or toggle mode, global capture |
| `CreateColorPicker` | ColorPicker | HSV field, hue strip, alpha, hex field |
| `CreateLabel` | TextLabel | Single-line label |
| `CreateParagraph` | TextLabel | Wrapped body copy |
| `CreateDivider` | Frame | Hairline rule |
| `CreateSpacer` | Frame | Explicit vertical gap |
| `CreateStatus` | Status | Dot, value, optional pulse |

Every factory accepts either a string shorthand or an options table:

```lua
section:CreateButton("Run check")
section:CreateButton({ Text = "Run check", Variant = "Primary", Callback = fn })
```

## Theming

```lua
Kaizax:SetTheme("Midnight")
Kaizax:SetTheme({
	Name = "Custom",
	Palette = {
		Accent = "#00FAB4",
		Background = "#0A0B0F",
		Surface = "#13151B",
	},
	Motion = { Fast = 0.1, Normal = 0.18 },
})
```

Preset names: `Default`, `Midnight`, `Ember`, `Graphite`. See [docs/Themes.md](docs/Themes.md) for the full palette table and token reference.

## Documentation

- [API reference](docs/API.md)
- [Theme and token reference](docs/Themes.md)
- [Demo](examples/Demo.luau)

## Project layout

```
src/
├─ init.luau          public library entry point
├─ Window.luau        shell, tabs, drag/resize, popups
├─ Tab.luau           page header, subtabs, search
├─ SubTab.luau        column layout and sections
├─ Section.luau       card shell and control factories
├─ Notification.luau  toast host
├─ Theme.luau         presets, resolve, color parsing
├─ Util.luau          instance helpers, paint roles, cleanup bags
├─ Animation.luau     reduced-motion-aware tweens
├─ Signal.luau        lightweight event object
├─ Types.luau         shared public types
└─ Components/        Base, Button, Toggle, Checkbox, Slider,
                      Dropdown, MultiDropdown, TextInput, Keybind,
                      ColorPicker, Search
examples/Demo.luau    full component demo
test/harness.luau     bootstrap used by the bundled demo
tools/bundle.mjs      single-file bundler
```

## Development

Validate syntax with the Luau compiler:

```bash
luau-compile --binary src/init.luau
```

Build the single-file demo:

```bash
node tools/bundle.mjs --out build/kaizax-demo.luau \
  --demo examples/Demo.luau --harness test/harness.luau
```

The repository has been syntax-checked with `luau-compile`; a Studio smoke test is still recommended before release because layout and input behavior depend on the live runtime.

## Attribution and license

The visual language is inspired by the original Dear ImGui example interface that this library was rebuilt from. The Roblox implementation is original Luau code: no C++, no ImGui runtime, no DLLs, and no assets from the reference archive are redistributed. Only presentation and interaction patterns were carried over.

MIT. See [LICENSE](LICENSE).

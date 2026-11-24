# API reference

All modules use strict Luau. Option tables accept partial values; defaults are listed with each control.

## Library

```lua
local Kaizax = require(game.ReplicatedStorage.Kaizax)
```

### `Kaizax:CreateWindow(options?)`

Creates a `ScreenGui` and the window shell. The first window becomes active.

| Option | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | `string?` | `"Kaizax"` | Rendered uppercase in the top bar |
| `Subtitle` | `string?` | `nil` | Mono subtitle under the title |
| `Theme` | `string \| ThemeOverrides?` | active theme | Applies globally before the window is built |
| `Size` | `Vector2?` | `900 × 620` | Logical pixels before viewport scaling |
| `Position` | `Vector2?` | centered | Logical offset |
| `ToggleKey` | `Enum.KeyCode \| false?` | `RightShift` | `false` disables the hotkey |
| `DisplayOrder` | `number?` | `100` | `ScreenGui.DisplayOrder` |
| `Parent` | `Instance?` | `PlayerGui` | Falls back to `CoreGui` |
| `OnClose` | `(() -> ())?` | `nil` | Called when the close button hides the window |

### Library methods

| Method | Returns | Notes |
| --- | --- | --- |
| `Notify(options)` | `()` | Creates the toast host on first use |
| `Toast(title, message?, kind?)` | `()` | Shortcut for `Notify` |
| `SetTheme(input)` | `Theme` | Repaints every open window and the toast host |
| `GetTheme()` | `Theme` | Active theme table |
| `GetThemes()` | `{ string }` | Preset names |
| `Destroy()` | `()` | Destroys all windows and the toast host |

### Public fields

`Kaizax.Version`, `Kaizax.Types`, `Kaizax.Theme`, `Kaizax.Themes`, `Kaizax.Util`, `Kaizax.Signal`.

## Window

### Methods

| Method | Returns | Notes |
| --- | --- | --- |
| `CreateTab(options)` | `Tab` | Accepts a string shorthand |
| `SelectTab(target)` | `()` | Tab object, index, or name |
| `GetTabs()` | `{ Tab }` | Creation order |
| `GetActiveTab()` | `Tab?` | |
| `SetOpen(open)` | `()` | Hides or restores the shell |
| `IsOpen()` | `boolean` | |
| `Toggle()` | `()` | Open/closed switch |
| `SetMinimized(minimized)` | `()` | Collapses to the top bar |
| `SetTitle(title)` | `()` | Uppercase top-bar title |
| `SetTheme(input)` | `Theme` | Applies globally |
| `Notify(options)` | `()` | Routes to the library host |
| `OnClosed(handler)` | `Connection` | Fires when the close button is pressed |
| `Destroy()` | `()` | Disconnects listeners, closes popups, removes the `ScreenGui` |

`Window.Instance` is the `ScreenGui`. `Window.Closed` is a `Signal`.

### Tab

```lua
window:CreateTab({
	Name = "Components",
	Description = "Every control with live values.",
	SubTabs = {
		{ Name = "Inputs", Columns = 2 },
		{ Name = "Feedback", Columns = 2 },
	},
})
```

A tab with no `SubTabs` receives one implicit `General` subtab. When two or more subtabs exist, the subtab bar appears in the page header.

| Method | Returns | Notes |
| --- | --- | --- |
| `CreateSection(options)` | `Section` | Accepts a string shorthand |
| `CreateSubTab(name, columns?)` | `SubTab` | Adds a subtab after creation |
| `SelectSubTab(target)` | `()` | SubTab object, index, or name |
| `GetSubTabs()` | `{ SubTab }` | |
| `SetVisible(visible)` | `()` | |
| `Destroy()` | `()` | |

Section options: `Name` (required), `Description` (optional).

Subtabs use one or two equal columns. `Columns = 2` splits sections into two `0.5, -6` columns with a 12px gutter.

## Section

```lua
local section = tab:CreateSection({ Name = "Numeric and text" })
```

Every factory accepts a string shorthand or an options table:

```lua
section:CreateButton("Run check")
section:CreateButton({ Text = "Run check", Variant = "Primary", Callback = fn })
```

### Layout methods

| Method | Returns | Notes |
| --- | --- | --- |
| `CreateLabel(options)` | `TextLabel` | 18px single line |
| `CreateParagraph(options)` | `TextLabel` | Wraps and grows vertically |
| `CreateDivider()` | `Frame` | 1px `Stroke` rule |
| `CreateSpacer(height?)` | `Frame` | Default 4px |
| `CreateStatus(options)` | `Status` | See below |
| `SetVisible(visible)` | `()` | |
| `Destroy()` | `()` | Destroys every control in the card |

Label options: `Text`, `ColorRole?`, `Size?`. Paragraph accepts the same fields.

### Common control methods

Button, Toggle, Checkbox, Slider, Dropdown, MultiDropdown, TextInput, Keybind, and ColorPicker expose:

| Method | Notes |
| --- | --- |
| `SetVisible(visible)` | |
| `SetDisabled(disabled)` | Disables input and lowers emphasis |
| `Destroy()` | |
| `Instance` | Root `GuiObject` |

Controls with a value also expose `GetValue`/`SetValue`, `Changed` (Signal), and `OnChanged(handler)` (Connection). `SetValue(value, silent?)` skips the callback when `silent` is true.

## Controls

### Button

Options: `Text`, `Variant` (`"Primary" | "Secondary" | "Ghost" | "Danger"`), `Height`, `Disabled`, `Callback`.

Extra methods: `SetText`, `GetText`, `GetDisabled`, `OnClicked(handler)`. Signal: `Clicked`.

### Toggle

Options: `Text`, `Default`, `Disabled`, `Callback`. Value is `boolean`.

Extra: `Toggle(silent?)`. Calls `SetValue(not value)`.

### Checkbox

Options: `Text`, `Default`, `Disabled`, `Callback`. Value is `boolean`.

Extra: `Toggle(silent?)`.

### Slider

Options:

| Option | Type | Default |
| --- | --- | --- |
| `Text` | `string?` | `"Slider"` |
| `Min` | `number?` | `0` |
| `Max` | `number?` | `100` |
| `Default` | `number?` | `Min` |
| `Step` | `number?` | `1` |
| `Suffix` | `string?` | `""` |
| `Format` | `((number) -> string)?` | numeric formatting |
| `Live` | `boolean?` | `false` | Fires while dragging instead of on release |
| `Disabled` | `boolean?` | `false` |
| `Callback` | `((number) -> ())?` | |

Extra methods: `GetValue`, `SetValue`, `SetRange(min, max)`, `GetRange()`. Signals: `Changed`, `Released`.

### Dropdown

Options: `Text`, `Options` (required), `Default`, `Placeholder`, `Disabled`, `Callback`. Value is `string?`.

Extra methods: `GetValue`, `SetValue`, `SetOptions`, `GetOptions`.

### MultiDropdown

Options: `Text`, `Options` (required), `Default` (list), `Placeholder`, `Disabled`, `Callback`. Value is `{ string }`.

Extra methods: `GetValue`, `SetValue`, `Clear`, `SetOptions`, `GetOptions`.

### TextInput

Options: `Text`, `Placeholder`, `Default`, `CharacterLimit` (default 64), `ClearOnFocus`, `Disabled`, `Callback`.

Extra methods: `GetText`, `SetText`. Signals: `Changed`, `Submitted` (Enter).

### Keybind

Options: `Text`, `Default` (`Enum.KeyCode?`), `Mode` (`"Hold" | "Toggle"`, default `"Toggle"`), `ShowMode`, `Disabled`, `Callback(key, mode)`.

Click the key chip, then press a key. `Escape` cancels capture; `Backspace` or `Delete` clears the binding.

Extra methods: `GetKey`, `SetKey`, `GetMode`, `SetMode`.

### ColorPicker

Options: `Text`, `Default` (`Color3?`), `Alpha` (0–1), `ShowAlpha`, `Live`, `Disabled`, `Callback(color, alpha)`.

Extra methods: `GetColor`, `GetAlpha`, `SetValue(color, alpha?, silent?)`. Signals: `Changed`, `Released`. Hex field accepts `#RGB` and `#RRGGBB`.

### Status

Options: `Text`, `Value`, `Kind` (`"neutral" | "info" | "success" | "warning" | "danger"`), `Pulse`.

Methods: `SetStatus(value, kind?, pulse?)`, `SetVisible`, `Destroy`.

## Notifications

```lua
Kaizax:Notify({
	Title = "Preset saved",
	Message = "Interface settings stored for this session.",
	Kind = "success",
	Duration = 4,
})
```

| Option | Type | Default |
| --- | --- | --- |
| `Title` | `string` | required |
| `Message` | `string?` | `nil` |
| `Kind` | `"info" \| "success" \| "warning" \| "error"` | `"info"` |
| `Duration` | `number?` | `4` seconds; `0` stays until dismissed |
| `Dismissable` | `boolean?` | `true` |

Toasts stack top-right, animate in, show a lifetime bar, and pause while hovered. The host survives window close and is destroyed by `Kaizax:Destroy()`.

## Signals

`Signal` is a small synchronous event object:

```lua
local connection = control.Changed:Connect(function(value)
	print(value)
end)

connection:Disconnect()
```

Methods: `Connect`, `Once`, `Fire`, `DisconnectAll`, `ListenerCount`. Handlers run under `pcall`; a failing handler logs a warning and does not block the others.

## Lifecycle notes

- Control callbacks that throw are isolated with `Util.safeCall`.
- All window and control connections live in cleanup bags. `Destroy()` disconnects them.
- Open popups close when their owner is hidden or the window is minimized.
- Motion passes through `Animation.duration`, which returns 0 when `GuiService.ReducedMotionEnabled` is true.

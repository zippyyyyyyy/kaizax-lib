# Themes and tokens

A theme is one table with five token groups: `Palette`, `Fonts`, `Radius`, `Spacing`, `Window`, and `Motion`, plus a `Name`.

```lua
local theme = Kaizax:GetTheme()
print(theme.Palette.Accent)
print(theme.Window.Sidebar)
```

## Applying a theme

```lua
-- Built-in preset by name.
Kaizax:SetTheme("Midnight")

-- Partial override. Missing values come from the Default theme.
Kaizax:SetTheme({
	Name = "Custom",
	Palette = {
		Accent = "#00FAB4",
		Background = "#0A0B0F",
		Surface = "#13151B",
		Text = "#F2F3F7",
	},
})
```

`SetTheme` validates hex strings, repaints every open window, and forwards the new palette to the notification host. Existing controls keep their role bindings; no rebuild is needed.

Important: a table override merges with the **Default** theme, not with the currently active preset. To base a custom theme on a preset, start from `Kaizax.Theme.get("Midnight")` and pass the full table.

```lua
local base = Kaizax.Theme.get("Midnight")
base.Name = "Midnight Warm"
base.Palette.Accent = "#FFB454"
Kaizax:SetTheme(base)
```

Preset name lookup is case-insensitive. Unknown names raise an error.

## Palette roles

| Role | Use |
| --- | --- |
| `Background` | Window body |
| `Surface` | Cards, top bar, sidebar |
| `SurfaceRaised` | Popups, active tab, switch fill |
| `Hover` | Hover state for flat rows |
| `Stroke` | Hairline borders and dividers |
| `StrokeStrong` | Hover borders, scrollbar thumb |
| `Accent` | Selection, primary action, active slider |
| `OnAccent` | Text and glyphs drawn on `Accent` |
| `Text` | Titles and primary values |
| `TextMuted` | Labels and body copy |
| `TextFaint` | Placeholder text, disabled controls, secondary hints |
| `Danger` | Destructive actions and error status |
| `Warning` | Warning status |
| `Success` | Success status |
| `Info` | Informational status |

Use `Kaizax.Util.paint(instance, "BackgroundColor3", "Surface", theme)` to bind a property to a role. Bindings are stored as attributes named `KaizaxColor_<Role>`, which is how live theme changes reach every control.

## Built-in presets

### Default — mint instrumentation

| Token | Hex |
| --- | --- |
| `Background` | `#0A0B0F` |
| `Surface` | `#13151B` |
| `SurfaceRaised` | `#1A1D25` |
| `Hover` | `#232731` |
| `Stroke` | `#2A2E38` |
| `StrokeStrong` | `#3B414E` |
| `Accent` | `#00FAB4` |
| `OnAccent` | `#04120D` |
| `Text` | `#F2F3F7` |
| `TextMuted` | `#A2A7B8` |
| `TextFaint` | `#7D8397` |
| `Danger` | `#FF5D73` |
| `Warning` | `#FFC24B` |
| `Success` | `#3DDC97` |
| `Info` | `#5AA9FF` |

### Midnight — cool blue

| Token | Hex |
| --- | --- |
| `Background` | `#0A0D14` |
| `Surface` | `#0E121B` |
| `SurfaceRaised` | `#131926` |
| `Hover` | `#182031` |
| `Stroke` | `#212B3D` |
| `StrokeStrong` | `#2E3A50` |
| `Accent` | `#5AA9FF` |
| `OnAccent` | `#070E18` |
| `Text` | `#EEF3FF` |
| `TextMuted` | `#98A6C2` |
| `TextFaint` | `#7D8AA3` |
| `Danger` | `#FF657F` |
| `Warning` | `#FFC857` |
| `Success` | `#4ADEA8` |
| `Info` | `#8BC5FF` |

### Ember — warm amber

| Token | Hex |
| --- | --- |
| `Background` | `#120F0D` |
| `Surface` | `#171310` |
| `SurfaceRaised` | `#1E1915` |
| `Hover` | `#271F19` |
| `Stroke` | `#332920` |
| `StrokeStrong` | `#46382B` |
| `Accent` | `#FF9F45` |
| `OnAccent` | `#160C03` |
| `Text` | `#FFF1E6` |
| `TextMuted` | `#B8A493` |
| `TextFaint` | `#978370` |
| `Danger` | `#FF6464` |
| `Warning` | `#FFD166` |
| `Success` | `#65D9A5` |
| `Info` | `#78B7FF` |

### Graphite — neutral monochrome

| Token | Hex |
| --- | --- |
| `Background` | `#0E0F11` |
| `Surface` | `#131519` |
| `SurfaceRaised` | `#191C21` |
| `Hover` | `#20242A` |
| `Stroke` | `#2A2E35` |
| `StrokeStrong` | `#3A404A` |
| `Accent` | `#E7EBF2` |
| `OnAccent` | `#0A0B0D` |
| `Text` | `#F4F6FA` |
| `TextMuted` | `#A0A7B4` |
| `TextFaint` | `#7D8594` |
| `Danger` | `#FF6B7D` |
| `Warning` | `#F2C14E` |
| `Success` | `#5ADBA4` |
| `Info` | `#7FB7FF` |

## Other tokens

### Fonts

| Token | Default |
| --- | --- |
| `Regular` | `Enum.Font.Gotham` |
| `Medium` | `Enum.Font.GothamMedium` |
| `Bold` | `Enum.Font.GothamBold` |
| `Mono` | `Enum.Font.Code` |

Mono is reserved for numeric readouts, version text, and the toggle-key hint. Titles use `Bold`; labels and section headings use `Medium`; body copy uses `Regular`.

### Radius

| Token | Default |
| --- | --- |
| `Window` | 12 |
| `Card` | 10 |
| `Element` | 6 |
| `Pill` | 999 |

### Spacing

| Token | Default |
| --- | --- |
| `XS` | 4 |
| `S` | 8 |
| `M` | 12 |
| `L` | 16 |
| `XL` | 24 |
| `XXL` | 32 |

Layouts use a 4px rhythm. Section padding is 16px, card gaps are 8px, and control rows are 36px tall.

### Window metrics

| Token | Default |
| --- | --- |
| `Width` | 960 |
| `Height` | 680 |
| `MinWidth` | 720 |
| `MinHeight` | 520 |
| `Sidebar` | 224 |
| `TopBar` | 52 |
| `PageHeader` | 92 |
| `Padding` | 24 |
| `RowHeight` | 40 |

Window metrics are read when a window is built. Changing them later affects new windows.

### Motion

| Token | Default |
| --- | --- |
| `Fast` | 0.14 |
| `Normal` | 0.22 |
| `Slow` | 0.36 |
| `Notification` | 0.42 |

All tween durations pass through `Animation.duration`. When `GuiService.ReducedMotionEnabled` is true, animations apply their final state immediately.

## Design rules

- One accent per theme. Do not introduce a second highlight hue.
- Borders stay at 1px and use `Stroke`; reserve `StrokeStrong` for interaction.
- No glows, gradients, or drop shadows beyond the single window shadow.
- Numeric values use `Mono`; prose and labels do not.
- Empty space is part of the hierarchy. Prefer spacing over extra dividers.
- Disabled controls stay readable: use `TextFaint` for text and lower background contrast, never hide content.

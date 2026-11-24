--!strict

local Types = require(script.Parent.Types)

local Theme = {}

local DEFAULT: Types.Theme = {
	Name = "Default",
	Palette = {
		Background = Color3.fromHex("#0A0B0F"),
		Surface = Color3.fromHex("#13151B"),
		SurfaceRaised = Color3.fromHex("#1A1D25"),
		Hover = Color3.fromHex("#232731"),
		Stroke = Color3.fromHex("#2A2E38"),
		StrokeStrong = Color3.fromHex("#3B414E"),
		Accent = Color3.fromHex("#00FAB4"),
		OnAccent = Color3.fromHex("#04120D"),
		Text = Color3.fromHex("#F2F3F7"),
		TextMuted = Color3.fromHex("#A2A7B8"),
		TextFaint = Color3.fromHex("#7D8397"),
		Danger = Color3.fromHex("#FF5D73"),
		Warning = Color3.fromHex("#FFC24B"),
		Success = Color3.fromHex("#3DDC97"),
		Info = Color3.fromHex("#5AA9FF"),
	},
	Fonts = {
		Regular = Enum.Font.Gotham,
		Medium = Enum.Font.GothamMedium,
		Bold = Enum.Font.GothamBold,
		Mono = Enum.Font.Code,
	},
	Radius = {
		Window = 10,
		Card = 8,
		Element = 5,
		Pill = 999,
	},
	Spacing = {
		XS = 4,
		S = 8,
		M = 12,
		L = 16,
		XL = 22,
		XXL = 30,
	},
	Window = {
		Width = 900,
		Height = 620,
		MinWidth = 680,
		MinHeight = 480,
		Sidebar = 200,
		TopBar = 48,
		PageHeader = 76,
		Padding = 20,
		RowHeight = 36,
	},
	Motion = {
		Fast = 0.12,
		Normal = 0.2,
		Slow = 0.34,
		Notification = 0.4,
	},
}

local PRESETS: { [string]: Types.ThemeOverrides } = {
	Default = {
		Name = "Default",
	},
	Midnight = {
		Name = "Midnight",
		Palette = {
			Background = "#0A0D14",
			Surface = "#0E121B",
			SurfaceRaised = "#131926",
			Hover = "#182031",
			Stroke = "#212B3D",
			StrokeStrong = "#2E3A50",
			Accent = "#5AA9FF",
			OnAccent = "#070E18",
			Text = "#EEF3FF",
			TextMuted = "#98A6C2",
			TextFaint = "#7D8AA3",
			Danger = "#FF657F",
			Warning = "#FFC857",
			Success = "#4ADEA8",
			Info = "#8BC5FF",
		},
	},
	Ember = {
		Name = "Ember",
		Palette = {
			Background = "#120F0D",
			Surface = "#171310",
			SurfaceRaised = "#1E1915",
			Hover = "#271F19",
			Stroke = "#332920",
			StrokeStrong = "#46382B",
			Accent = "#FF9F45",
			OnAccent = "#160C03",
			Text = "#FFF1E6",
			TextMuted = "#B8A493",
			TextFaint = "#978370",
			Danger = "#FF6464",
			Warning = "#FFD166",
			Success = "#65D9A5",
			Info = "#78B7FF",
		},
	},
	Graphite = {
		Name = "Graphite",
		Palette = {
			Background = "#0E0F11",
			Surface = "#131519",
			SurfaceRaised = "#191C21",
			Hover = "#20242A",
			Stroke = "#2A2E35",
			StrokeStrong = "#3A404A",
			Accent = "#E7EBF2",
			OnAccent = "#0A0B0D",
			Text = "#F4F6FA",
			TextMuted = "#A0A7B4",
			TextFaint = "#7D8594",
			Danger = "#FF6B7D",
			Warning = "#F2C14E",
			Success = "#5ADBA4",
			Info = "#7FB7FF",
		},
	},
}

Theme.Presets = { "Default", "Midnight", "Ember", "Graphite" }

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, item in value do
		copy[key] = deepCopy(item)
	end
	return copy
end

local function merge(base: any, patch: any): any
	local result = deepCopy(base)

	for key, value in patch do
		if typeof(value) == "table" and typeof(result[key]) == "table" then
			result[key] = merge(result[key], value)
		else
			result[key] = deepCopy(value)
		end
	end

	return result
end

local function presetFor(name: string): Types.ThemeOverrides?
	local lowered = string.lower(name)
	for presetName, preset in PRESETS do
		if string.lower(presetName) == lowered then
			return preset
		end
	end
	return nil
end

local function color(value: Types.ColorInput): Color3
	if typeof(value) == "string" then
		local ok, parsed = pcall(Color3.fromHex, value)
		if not ok then
			error(`Kaizax theme: "{value}" is not a valid hex color`, 4)
		end
		return parsed
	end
	return value
end

local function normalize(theme: Types.Theme): Types.Theme
	local palette = theme.Palette :: any
	for key, value in palette do
		palette[key] = color(value)
	end
	return theme
end

--- Resolves a preset name or a partial theme into a complete theme table.
function Theme.resolve(input: Types.ThemeInput?): Types.Theme
	local resolved = deepCopy(DEFAULT) :: any

	if typeof(input) == "string" then
		local preset = presetFor(input)
		if not preset then
			error(`Kaizax theme: unknown preset "{input}"`, 2)
		end
		resolved = merge(resolved, preset)
	elseif typeof(input) == "table" then
		resolved = merge(resolved, input)
	end

	return normalize(resolved :: Types.Theme)
end

--- Returns a fresh copy of a built-in theme.
function Theme.get(name: string): Types.Theme
	return Theme.resolve(name)
end

--- Returns the default theme, unmodified.
function Theme.default(): Types.Theme
	return deepCopy(DEFAULT) :: Types.Theme
end

--- Parses a hex color or returns the Color3 untouched.
function Theme.color(value: Types.ColorInput): Color3
	return color(value)
end

return Theme

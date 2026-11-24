--!strict

-- Shared public types for Kaizax. Kept free of requires so every module can
-- depend on it without creating a cycle.

export type ColorInput = Color3 | string

export type Palette = {
	Background: Color3,
	Surface: Color3,
	SurfaceRaised: Color3,
	Hover: Color3,
	Stroke: Color3,
	StrokeStrong: Color3,
	Accent: Color3,
	OnAccent: Color3,
	Text: Color3,
	TextMuted: Color3,
	TextFaint: Color3,
	Danger: Color3,
	Warning: Color3,
	Success: Color3,
	Info: Color3,
}

export type Fonts = {
	Regular: Enum.Font,
	Medium: Enum.Font,
	Bold: Enum.Font,
	Mono: Enum.Font,
}

export type Radius = {
	Window: number,
	Card: number,
	Element: number,
	Pill: number,
}

export type Spacing = {
	XS: number,
	S: number,
	M: number,
	L: number,
	XL: number,
	XXL: number,
}

export type WindowMetrics = {
	Width: number,
	Height: number,
	MinWidth: number,
	MinHeight: number,
	Sidebar: number,
	TopBar: number,
	PageHeader: number,
	Padding: number,
	RowHeight: number,
}

export type Motion = {
	Fast: number,
	Normal: number,
	Slow: number,
	Notification: number,
}

export type Theme = {
	Name: string,
	Palette: Palette,
	Fonts: Fonts,
	Radius: Radius,
	Spacing: Spacing,
	Window: WindowMetrics,
	Motion: Motion,
}

export type ThemeOverrides = {
	Name: string?,
	Palette: { [string]: ColorInput }?,
	Fonts: { [string]: Enum.Font }?,
	Radius: { [string]: number }?,
	Spacing: { [string]: number }?,
	Window: { [string]: number }?,
	Motion: { [string]: number }?,
}

export type ThemeInput = string | ThemeOverrides

export type NotificationKind = "info" | "success" | "warning" | "error"

export type NotificationOptions = {
	Title: string,
	Message: string?,
	Kind: NotificationKind?,
	Duration: number?,
	Dismissable: boolean?,
}

export type ButtonVariant = "Primary" | "Secondary" | "Ghost" | "Danger"
export type StatusKind = "neutral" | "info" | "success" | "warning" | "danger"
export type KeybindMode = "Hold" | "Toggle"

export type UIContext = {
	GetTheme: () -> Theme,
	Color: (role: string) -> Color3,
	Paint: (instance: Instance, property: string, role: string) -> (),
	Register: (row: GuiObject, searchText: string?) -> (),
	OpenPopup: (owner: any, anchor: GuiObject, width: number, height: number, onClose: (() -> ())?) -> (Frame, () -> ()),
	ClosePopup: (owner: any) -> (),
	GetScale: () -> number,
	Window: any,
	Notify: (NotificationOptions) -> (),
}

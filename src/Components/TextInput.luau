--!strict

local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Parent.Util)
local Animation = require(script.Parent.Parent.Animation)
local Signal = require(script.Parent.Parent.Signal)
local Base = require(script.Parent.Base)

local TextInput = {}
TextInput.__index = TextInput

export type Options = {
	Text: string?,
	Placeholder: string?,
	Default: string?,
	CharacterLimit: number?,
	ClearOnFocus: boolean?,
	Disabled: boolean?,
	Callback: ((text: string) -> ())?,
}

export type TextInput = {
	Instance: Frame,
	Changed: Signal.Signal,
	Submitted: Signal.Signal,
	GetText: (self: TextInput) -> string,
	SetText: (self: TextInput, text: string, silent: boolean?) -> (),
	SetDisabled: (self: TextInput, disabled: boolean) -> (),
	SetVisible: (self: TextInput, visible: boolean) -> (),
	OnChanged: (self: TextInput, handler: (text: string) -> ()) -> Signal.Connection,
	OnSubmitted: (self: TextInput, handler: (text: string) -> ()) -> Signal.Connection,
	Destroy: (self: TextInput) -> (),
}

function TextInput.new(
	ctx: Types.UIContext,
	parent: Instance,
	options: Options
): TextInput
	local theme = ctx.GetTheme()
	local bag = Util.bag()
	local text = options.Default or ""
	local committed = text
	local limit = options.CharacterLimit or 64
	local disabled = options.Disabled == true
	local focused = false
	local hovered = false
	local labelText = options.Text or "Text input"
	local placeholder = options.Placeholder or "Type here..."
	local callback = options.Callback
	local changed = Signal.new()
	local submitted = Signal.new()

	local container = Util.frame({
		Name = "TextInput",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 60),
	}, parent)

	local label = Base.text(ctx, container, labelText, {
		Font = theme.Fonts.Medium,
		Size = 13,
		ColorRole = "TextMuted",
	})
	label.Position = UDim2.fromOffset(0, 0)
	label.Size = UDim2.new(1, 0, 0, 18)

	local field = Util.textBox({
		Name = "Field",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = theme.Palette.SurfaceRaised,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		MultiLine = false,
		PlaceholderText = placeholder,
		PlaceholderColor3 = theme.Palette.TextFaint,
		Text = text,
		TextColor3 = theme.Palette.Text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Font = theme.Fonts.Regular,
		TextEditable = not disabled,
		Active = not disabled,
	}, container)

	Util.corner(field, theme.Radius.Element)
	Util.padding(field, 10, 0)
	local stroke = Util.stroke(field, 1)

	ctx.Paint(field, "BackgroundColor3", "SurfaceRaised")
	ctx.Paint(field, "TextColor3", "Text")
	ctx.Paint(field, "PlaceholderColor3", "TextFaint")
	ctx.Paint(stroke, "Color", "Stroke")

	local clearButton = Util.textButton({
		Name = "Clear",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Visible = text ~= "",
	}, field)

	local clearLineOne = Util.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = theme.Palette.TextMuted,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = 45,
		Size = UDim2.fromOffset(8, 1),
	}, clearButton)
	ctx.Paint(clearLineOne, "BackgroundColor3", "TextMuted")

	local clearLineTwo = Util.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = theme.Palette.TextMuted,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = -45,
		Size = UDim2.fromOffset(8, 1),
	}, clearButton)
	ctx.Paint(clearLineTwo, "BackgroundColor3", "TextMuted")

	local function applyColors(animate: boolean)
		local current = ctx.GetTheme()
		local active = focused or hovered

		if disabled then
			ctx.Paint(field, "BackgroundColor3", "Surface")
			ctx.Paint(field, "TextColor3", "TextFaint")
			ctx.Paint(stroke, "Color", "Stroke")
			ctx.Paint(label, "TextColor3", "TextFaint")
			field.BackgroundTransparency = 0.25
			stroke.Transparency = 0.5
			return
		end

		ctx.Paint(field, "BackgroundColor3", if focused then "SurfaceRaised" else if hovered then "Hover" else "SurfaceRaised")
		ctx.Paint(field, "TextColor3", "Text")
		ctx.Paint(stroke, "Color", if focused then "Accent" else if hovered then "StrokeStrong" else "Stroke")
		ctx.Paint(label, "TextColor3", "TextMuted")
		field.BackgroundTransparency = 0
		stroke.Transparency = 0

		Animation.play(field, current.Motion.Fast, {
			BackgroundColor3 = ctx.Color(if focused then "SurfaceRaised" else if hovered then "Hover" else "SurfaceRaised"),
			BackgroundTransparency = 0,
		}, { easing = "Quad" })
		Animation.play(stroke, current.Motion.Fast, {
			Color = ctx.Color(if focused then "Accent" else if hovered then "StrokeStrong" else "Stroke"),
			Transparency = 0,
		}, { easing = "Quad" })
	end

	local function commit()
		if committed ~= text then
			committed = text
			submitted:Fire(text)
			Util.safeCall(callback, text)
		end
	end

	local function updateClear()
		clearButton.Visible = text ~= "" and not disabled
	end

	applyColors(false)
	updateClear()

	bag:Add(field:GetPropertyChangedSignal("Text"):Connect(function()
		local nextText = field.Text
		if limit > 0 and #nextText > limit then
			nextText = string.sub(nextText, 1, limit)
			field.Text = nextText
		end
		text = nextText
		updateClear()
		changed:Fire(text)
	end))

	bag:Add(field.Focused:Connect(function()
		focused = true
		if options.ClearOnFocus and field.Text ~= "" then
			field.Text = ""
			text = ""
			updateClear()
		end
		applyColors(true)
	end))

	bag:Add(field.FocusLost:Connect(function()
		focused = false
		text = field.Text
		applyColors(true)
		commit()
	end))

	bag:Add(field.MouseEnter:Connect(function()
		if disabled then
			return
		end
		hovered = true
		applyColors(true)
	end))

	bag:Add(field.MouseLeave:Connect(function()
		if disabled then
			return
		end
		hovered = false
		applyColors(true)
	end))

	bag:Add(clearButton.Activated:Connect(function()
		if disabled then
			return
		end
		field.Text = ""
		text = ""
		updateClear()
		field:CaptureFocus()
		applyColors(true)
	end))

	local self = setmetatable({} :: any, TextInput) :: TextInput
	self.Instance = container
	self.Changed = changed
	self.Submitted = submitted

	function self:GetText(): string
		return text
	end

	function self:SetText(nextText: string, silent: boolean?)
		if limit > 0 and #nextText > limit then
			nextText = string.sub(nextText, 1, limit)
		end
		text = nextText
		committed = nextText
		field.Text = nextText
		updateClear()
		if not silent then
			changed:Fire(text)
			submitted:Fire(text)
			Util.safeCall(callback, text)
		end
	end

	function self:SetDisabled(nextDisabled: boolean)
		if disabled == nextDisabled then
			return
		end
		disabled = nextDisabled
		field.TextEditable = not disabled
		field.Active = not disabled
		clearButton.Visible = text ~= "" and not disabled
		applyColors(true)
	end

	function self:SetVisible(visible: boolean)
		container.Visible = visible
	end

	function self:OnChanged(handler: (text: string) -> ()): Signal.Connection
		return changed:Connect(handler)
	end

	function self:OnSubmitted(handler: (text: string) -> ()): Signal.Connection
		return submitted:Connect(handler)
	end

	function self:Destroy()
		bag:Clear()
		changed:DisconnectAll()
		submitted:DisconnectAll()
		container:Destroy()
	end

	container:SetAttribute("KaizaxComponent", "TextInput")
	ctx.Register(container, labelText)

	return self
end

return TextInput

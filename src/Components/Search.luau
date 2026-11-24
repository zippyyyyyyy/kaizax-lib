--!strict

local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Parent.Util)
local Animation = require(script.Parent.Parent.Animation)
local Signal = require(script.Parent.Parent.Signal)

local Search = {}
Search.__index = Search

export type Options = {
	Placeholder: string?,
	Width: number?,
	Height: number?,
	Callback: ((text: string) -> ())?,
}

export type Search = {
	Instance: Frame,
	Changed: Signal.Signal,
	GetText: (self: Search) -> string,
	SetText: (self: Search, text: string, silent: boolean?) -> (),
	Clear: (self: Search, silent: boolean?) -> (),
	Focus: (self: Search) -> (),
	OnChanged: (self: Search, handler: (text: string) -> ()) -> Signal.Connection,
	Destroy: (self: Search) -> (),
}

function Search.new(
	ctx: Types.UIContext,
	parent: Instance,
	options: Options
): Search
	local theme = ctx.GetTheme()
	local bag = Util.bag()
	local text = ""
	local focused = false
	local hovered = false
	local callback = options.Callback
	local placeholder = options.Placeholder or "Search controls"
	local changed = Signal.new()

	local frame = Util.frame({
		Name = "Search",
		BackgroundColor3 = theme.Palette.Surface,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(options.Width or 216, options.Height or 32),
	}, parent)

	Util.corner(frame, theme.Radius.Element)
	local stroke = Util.stroke(frame, 1)
	ctx.Paint(frame, "BackgroundColor3", "Surface")
	ctx.Paint(stroke, "Color", "Stroke")

	local icon = Util.frame({
		Name = "Icon",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(9, 0),
		Size = UDim2.fromOffset(14, 32),
	}, frame)

	local ring = Util.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 11),
		Size = UDim2.fromOffset(8, 8),
	}, icon)
	Util.corner(ring, 999)
	local ringStroke = Util.stroke(ring, 1.4)
	ctx.Paint(ringStroke, "Color", "TextFaint")

	local handle = Util.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = theme.Palette.TextFaint,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(11, 16),
		Rotation = 45,
		Size = UDim2.fromOffset(5, 1.4),
	}, icon)
	Util.corner(handle, 1)
	ctx.Paint(handle, "BackgroundColor3", "TextFaint")

	local field = Util.textBox({
		Name = "Field",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = theme.Fonts.Regular,
		MultiLine = false,
		PlaceholderColor3 = theme.Palette.TextFaint,
		PlaceholderText = placeholder,
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -52, 1, 0),
		Text = "",
		TextColor3 = theme.Palette.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, frame)

	ctx.Paint(field, "TextColor3", "Text")
	ctx.Paint(field, "PlaceholderColor3", "TextFaint")

	local clearButton = Util.textButton({
		Name = "Clear",
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -4, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		Text = "",
		AutoButtonColor = false,
		Visible = false,
	}, frame)

	local barOne = Util.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = theme.Palette.TextMuted,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = 45,
		Size = UDim2.fromOffset(7, 1),
	}, clearButton)
	ctx.Paint(barOne, "BackgroundColor3", "TextMuted")

	local barTwo = Util.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = theme.Palette.TextMuted,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = -45,
		Size = UDim2.fromOffset(7, 1),
	}, clearButton)
	ctx.Paint(barTwo, "BackgroundColor3", "TextMuted")

	local function paintIcon(role: string)
		ctx.Paint(ringStroke, "Color", role)
		ctx.Paint(handle, "BackgroundColor3", role)
		ringStroke.Color = ctx.Color(role)
		handle.BackgroundColor3 = ctx.Color(role)
	end

	local function apply(animate: boolean)
		local current = ctx.GetTheme()
		local targetFrame = if focused then "SurfaceRaised" elseif hovered then "Hover" else "Surface"
		local targetStroke = if focused then "Accent" elseif hovered then "StrokeStrong" else "Stroke"
		local iconRole = if focused then "Accent" elseif hovered then "TextMuted" else "TextFaint"

		ctx.Paint(frame, "BackgroundColor3", targetFrame)
		ctx.Paint(stroke, "Color", targetStroke)
		paintIcon(iconRole)

		if animate then
			Animation.play(frame, current.Motion.Fast, {
				BackgroundColor3 = ctx.Color(targetFrame),
			}, { easing = "Quad" })
			Animation.play(stroke, current.Motion.Fast, {
				Color = ctx.Color(targetStroke),
			}, { easing = "Quad" })
		else
			frame.BackgroundColor3 = ctx.Color(targetFrame)
			stroke.Color = ctx.Color(targetStroke)
		end
	end

	local function syncClear()
		clearButton.Visible = text ~= ""
		field.Size = UDim2.new(1, if text ~= "" then -52 else -34, 1, 0)
	end

	local function emit(textValue: string, silent: boolean?)
		changed:Fire(textValue)
		if not silent then
			Util.safeCall(callback, textValue)
		end
	end

	apply(false)
	syncClear()

	bag:Add(field:GetPropertyChangedSignal("Text"):Connect(function()
		text = field.Text
		syncClear()
		emit(text, false)
	end))

	bag:Add(field.Focused:Connect(function()
		focused = true
		apply(true)
	end))

	bag:Add(field.FocusLost:Connect(function()
		focused = false
		hovered = false
		apply(true)
	end))

	bag:Add(field.MouseEnter:Connect(function()
		hovered = true
		if not focused then
			apply(true)
		end
	end))

	bag:Add(field.MouseLeave:Connect(function()
		hovered = false
		if not focused then
			apply(true)
		end
	end))

	bag:Add(clearButton.Activated:Connect(function()
		field.Text = ""
		text = ""
		syncClear()
		emit("", false)
		field:CaptureFocus()
	end))

	local self = setmetatable({} :: any, Search) :: Search
	self.Instance = frame
	self.Changed = changed

	function self:GetText(): string
		return text
	end

	function self:SetText(nextText: string, silent: boolean?)
		text = nextText
		field.Text = nextText
		syncClear()
		if not silent then
			emit(nextText, false)
		end
	end

	function self:Clear(silent: boolean?)
		if text == "" then
			return
		end
		text = ""
		field.Text = ""
		syncClear()
		if not silent then
			emit("", false)
		end
	end

	function self:Focus()
		field:CaptureFocus()
	end

	function self:OnChanged(handler: (nextText: string) -> ()): Signal.Connection
		return changed:Connect(handler)
	end

	function self:Destroy()
		bag:Clear()
		changed:DisconnectAll()
		frame:Destroy()
	end

	ctx.Register(frame, nil)
	return self
end

return Search

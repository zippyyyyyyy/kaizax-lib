--!strict

local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Parent.Util)
local Animation = require(script.Parent.Parent.Animation)
local Signal = require(script.Parent.Parent.Signal)
local Base = require(script.Parent.Base)

local UserInputService = game:GetService("UserInputService")

local Slider = {}
Slider.__index = Slider

export type Options = {
	Text: string?,
	Min: number?,
	Max: number?,
	Default: number?,
	Step: number?,
	Suffix: string?,
	Format: ((value: number) -> string)?,
	Live: boolean?,
	Disabled: boolean?,
	Callback: ((value: number) -> ())?,
}

export type Slider = {
	Instance: Frame,
	Changed: Signal.Signal,
	Released: Signal.Signal,
	GetValue: (self: Slider) -> number,
	SetValue: (self: Slider, value: number) -> (),
	SetRange: (self: Slider, minimum: number, maximum: number) -> (),
	GetRange: (self: Slider) -> (number, number),
	SetDisabled: (self: Slider, disabled: boolean) -> (),
	SetVisible: (self: Slider, visible: boolean) -> (),
	OnChanged: (self: Slider, handler: (value: number) -> ()) -> Signal.Connection,
	OnReleased: (self: Slider, handler: (value: number) -> ()) -> Signal.Connection,
	Destroy: (self: Slider) -> (),
}

function Slider.new(
	ctx: Types.UIContext,
	parent: Instance,
	options: Options
): Slider
	local theme = ctx.GetTheme()
	local bag = Util.bag()

	local minimum = options.Min or 0
	local maximum = options.Max or 100
	if maximum <= minimum then
		error("Kaizax slider: Max must be greater than Min", 2)
	end

	local step = options.Step or 1
	if step <= 0 then
		error("Kaizax slider: Step must be greater than zero", 2)
	end

	local suffix = options.Suffix or ""
	local callback = options.Callback
	local live = options.Live == true
	local disabled = options.Disabled == true
	local labelText = options.Text or "Slider"
	local dragging = false
	local hovered = false
	local value = Util.round(math.clamp(options.Default or minimum, minimum, maximum), step)
	local changed = Signal.new()
	local released = Signal.new()

	local row = Util.frame({
		Name = "Slider",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
	}, parent)

	local label = Base.text(ctx, row, labelText, {
		Font = theme.Fonts.Medium,
		Size = 13,
		ColorRole = "TextMuted",
	})
	label.Position = UDim2.fromOffset(0, 2)
	label.Size = UDim2.new(1, -84, 0, 18)

	local valueLabel = Base.text(ctx, row, "", {
		Font = theme.Fonts.Mono,
		Size = 12.5,
		ColorRole = "TextMuted",
		XAlign = Enum.TextXAlignment.Right,
	})
	valueLabel.AnchorPoint = Vector2.new(1, 0)
	valueLabel.Position = UDim2.new(1, 0, 0, 2)
	valueLabel.Size = UDim2.fromOffset(84, 18)

	local trackHit = Util.textButton({
		Name = "TrackHit",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -18),
		Text = "",
		AutoButtonColor = false,
		Active = not disabled,
	}, row)

	local track = Util.frame({
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 5, 0.5, 0),
		Size = UDim2.new(1, -10, 0, 4),
		BorderSizePixel = 0,
	}, trackHit)

	Util.corner(track, 999)

	local fill = Util.frame({
		Name = "Fill",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(0, 1),
		BorderSizePixel = 0,
	}, track)

	Util.corner(fill, 999)

	local knob = Util.frame({
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, track)

	Util.corner(knob, 999)

	local knobCore = Util.frame({
		Name = "Core",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4),
		BorderSizePixel = 0,
	}, knob)

	Util.corner(knobCore, 999)

	local knobScale = Util.create("UIScale", {
		Scale = 1,
	}, knob) :: UIScale

	local function fraction(): number
		return (value - minimum) / (maximum - minimum)
	end

	local function display(): string
		if options.Format then
			local ok, text = pcall(options.Format, value)
			if ok and typeof(text) == "string" then
				return text
			end
		end
		return Util.formatNumber(value, step, suffix)
	end

	local function applyColors(animate: boolean)
		local current = ctx.GetTheme()
		local active = dragging or hovered

		if disabled then
			ctx.Paint(track, "BackgroundColor3", "Stroke")
			ctx.Paint(fill, "BackgroundColor3", "TextFaint")
			ctx.Paint(knob, "BackgroundColor3", "TextFaint")
			ctx.Paint(knobCore, "BackgroundColor3", "Surface")
			ctx.Paint(valueLabel, "TextColor3", "TextFaint")
			track.BackgroundTransparency = 0.5
			fill.BackgroundTransparency = 0.6
			knob.BackgroundTransparency = 0.4
			return
		end

		ctx.Paint(track, "BackgroundColor3", if active then "StrokeStrong" else "Stroke")
		ctx.Paint(fill, "BackgroundColor3", "Accent")
		ctx.Paint(knob, "BackgroundColor3", "Accent")
		ctx.Paint(knobCore, "BackgroundColor3", "OnAccent")
		ctx.Paint(valueLabel, "TextColor3", if active then "Accent" else "TextMuted")
		track.BackgroundTransparency = 0
		fill.BackgroundTransparency = 0
		knob.BackgroundTransparency = 0

		local targetScale = if active then 1.12 else 1
		if animate then
			Animation.play(knobScale, current.Motion.Fast, { Scale = targetScale }, { easing = "Quad" })
			Animation.play(track, current.Motion.Fast, {
				BackgroundColor3 = ctx.Color(if active then "StrokeStrong" else "Stroke"),
			}, { easing = "Quad" })
		else
			knobScale.Scale = targetScale
		end
	end

	local function updateVisuals(animate: boolean)
		local position = fraction()
		local target = UDim2.fromScale(position, 0.5)
		fill.Size = UDim2.fromScale(position, 1)
		knob.Position = target
		valueLabel.Text = display()
		applyColors(animate)
	end

	local function setValue(nextValue: number, fromUser: boolean, final: boolean)
		local clamped = Util.round(math.clamp(nextValue, minimum, maximum), step)
		if clamped == value then
			if final and fromUser then
				released:Fire(value)
				Util.safeCall(callback, value)
			end
			return
		end

		value = clamped
		updateVisuals(false)
		changed:Fire(value)

		if fromUser and live and not final then
			Util.safeCall(callback, value)
		end

		if final then
			released:Fire(value)
			Util.safeCall(callback, value)
		end
	end

	local function updateFromInput(positionX: number, final: boolean)
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local relative = (positionX - track.AbsolutePosition.X) / width
		local nextValue = minimum + math.clamp(relative, 0, 1) * (maximum - minimum)
		setValue(nextValue, true, final)
	end

	updateVisuals(false)

	bag:Add(trackHit.InputBegan:Connect(function(input)
		if disabled then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		dragging = true
		updateFromInput(input.Position.X, false)
	end))

	bag:Add(UserInputService.InputChanged:Connect(function(input)
		if not dragging or disabled then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			updateFromInput(input.Position.X, false)
		end
	end))

	bag:Add(UserInputService.InputEnded:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
			updateFromInput(input.Position.X, true)
			applyColors(true)
		end
	end))

	bag:Add(trackHit.MouseEnter:Connect(function()
		if disabled then
			return
		end
		hovered = true
		applyColors(true)
	end))

	bag:Add(trackHit.MouseLeave:Connect(function()
		if disabled then
			return
		end
		hovered = false
		applyColors(true)
	end))

	local self = setmetatable({} :: any, Slider) :: Slider
	self.Instance = row
	self.Changed = changed
	self.Released = released

	function self:GetValue(): number
		return value
	end

	function self:SetValue(nextValue: number)
		setValue(nextValue, false, false)
	end

	function self:SetRange(nextMinimum: number, nextMaximum: number)
		if nextMaximum <= nextMinimum then
			error("Kaizax slider: Max must be greater than Min", 2)
		end
		minimum = nextMinimum
		maximum = nextMaximum
		value = Util.round(math.clamp(value, minimum, maximum), step)
		updateVisuals(false)
	end

	function self:GetRange(): (number, number)
		return minimum, maximum
	end

	function self:SetDisabled(nextDisabled: boolean)
		if disabled == nextDisabled then
			return
		end
		disabled = nextDisabled
		trackHit.Active = not disabled
		if disabled then
			dragging = false
		end
		applyColors(true)
	end

	function self:SetVisible(visible: boolean)
		row.Visible = visible
	end

	function self:OnChanged(handler: (value: number) -> ()): Signal.Connection
		return changed:Connect(handler)
	end

	function self:OnReleased(handler: (value: number) -> ()): Signal.Connection
		return released:Connect(handler)
	end

	function self:Destroy()
		bag:Clear()
		changed:DisconnectAll()
		released:DisconnectAll()
		row:Destroy()
	end

	row:SetAttribute("KaizaxComponent", "Slider")
	ctx.Register(row, labelText)

	return self
end

return Slider

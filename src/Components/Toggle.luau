--!strict

local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Parent.Util)
local Animation = require(script.Parent.Parent.Animation)
local Signal = require(script.Parent.Parent.Signal)
local Base = require(script.Parent.Base)

local Toggle = {}
Toggle.__index = Toggle

export type Options = {
	Text: string?,
	Default: boolean?,
	Disabled: boolean?,
	Callback: ((value: boolean) -> ())?,
}

export type Toggle = {
	Instance: Frame,
	Changed: Signal.Signal,
	GetValue: (self: Toggle) -> boolean,
	SetValue: (self: Toggle, value: boolean, silent: boolean?) -> (),
	Toggle: (self: Toggle, silent: boolean?) -> (),
	SetDisabled: (self: Toggle, disabled: boolean) -> (),
	SetVisible: (self: Toggle, visible: boolean) -> (),
	OnChanged: (self: Toggle, handler: (value: boolean) -> ()) -> Signal.Connection,
	Destroy: (self: Toggle) -> (),
}

function Toggle.new(
	ctx: Types.UIContext,
	parent: Instance,
	options: Options
): Toggle
	local theme = ctx.GetTheme()
	local bag = Util.bag()
	local value = options.Default == true
	local disabled = options.Disabled == true
	local hovered = false
	local callback = options.Callback
	local labelText = options.Text or "Toggle"

	local changed = Signal.new()
	local row, _, rowLabel = Base.row(ctx, parent, labelText)
	if rowLabel then
		rowLabel.Size = UDim2.new(1, -52, 1, 0)
	end

	local switch = Util.textButton({
		Name = "Switch",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(38, 20),
		BackgroundColor3 = theme.Palette.SurfaceRaised,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		Active = not disabled,
	}, row)

	Util.corner(switch, 999)
	local stroke = Util.stroke(switch, 1)

	local knob = Util.frame({
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = theme.Palette.TextFaint,
		BorderSizePixel = 0,
	}, switch)

	Util.corner(knob, 999)

	local function targets(): (Color3, number, string, Color3, string, number)
		local current = ctx.GetTheme()

		if disabled then
			return current.Palette.SurfaceRaised, 0.4, "SurfaceRaised", current.Palette.TextFaint, "TextFaint", 0.7
		end

		if value then
			local fill = if hovered then current.Palette.Accent:Lerp(Color3.new(1, 1, 1), 0.06) else current.Palette.Accent
			return fill, 0, "Accent", current.Palette.OnAccent, "OnAccent", 1
		end

		local fill = if hovered then current.Palette.Hover else current.Palette.SurfaceRaised
		local knobColor = if hovered then current.Palette.TextMuted else current.Palette.TextFaint
		return fill, 0, if hovered then "Hover" else "SurfaceRaised", knobColor, if hovered then "TextMuted" else "TextFaint", 0
	end

	local function apply(animate: boolean)
		local fill, fillTransparency, fillRole, knobColor, knobRole, strokeTransparency = targets()
		local current = ctx.GetTheme()

		ctx.Paint(switch, "BackgroundColor3", fillRole)
		ctx.Paint(knob, "BackgroundColor3", knobRole)
		ctx.Paint(stroke, "Color", if value then "Accent" else "Stroke")

		local knobPosition = UDim2.new(0, if value then 20 else 2, 0.5, 0)
		local properties = {
			BackgroundColor3 = fill,
			BackgroundTransparency = fillTransparency,
		}

		if animate then
			Animation.play(switch, current.Motion.Normal, properties, {
				easing = "Quad",
			})
			Animation.play(knob, current.Motion.Normal, {
				BackgroundColor3 = knobColor,
				Position = knobPosition,
			}, {
				easing = "Quad",
				direction = "Out",
			})
			stroke.Transparency = strokeTransparency
		else
			switch.BackgroundColor3 = fill
			switch.BackgroundTransparency = fillTransparency
			knob.BackgroundColor3 = knobColor
			knob.Position = knobPosition
			stroke.Transparency = strokeTransparency
		end
	end

	local function setValue(nextValue: boolean, silent: boolean?)
		if value == nextValue or disabled then
			return
		end
		value = nextValue
		apply(true)
		changed:Fire(value)
		if not silent then
			Util.safeCall(callback, value)
		end
	end

	apply(false)

	bag:Add(switch.Activated:Connect(function()
		setValue(not value, false)
	end))

	bag:Add(switch.MouseEnter:Connect(function()
		if disabled then
			return
		end
		hovered = true
		apply(true)
	end))

	bag:Add(switch.MouseLeave:Connect(function()
		if disabled then
			return
		end
		hovered = false
		apply(true)
	end))

	local self = setmetatable({} :: any, Toggle) :: Toggle
	self.Instance = row
	self.Changed = changed

	function self:GetValue(): boolean
		return value
	end

	function self:SetValue(nextValue: boolean, silent: boolean?)
		setValue(nextValue, silent)
	end

	function self:Toggle(silent: boolean?)
		setValue(not value, silent)
	end

	function self:SetDisabled(nextDisabled: boolean)
		if disabled == nextDisabled then
			return
		end
		disabled = nextDisabled
		switch.Active = not disabled
		apply(true)
	end

	function self:SetVisible(visible: boolean)
		row.Visible = visible
	end

	function self:OnChanged(handler: (value: boolean) -> ()): Signal.Connection
		return changed:Connect(handler)
	end

	function self:Destroy()
		bag:Clear()
		changed:DisconnectAll()
		row:Destroy()
	end

	row:SetAttribute("KaizaxComponent", "Toggle")
	ctx.Register(row, labelText)

	return self
end

return Toggle

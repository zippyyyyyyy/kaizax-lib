--!strict

local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Parent.Util)
local Animation = require(script.Parent.Parent.Animation)
local Signal = require(script.Parent.Parent.Signal)
local Base = require(script.Parent.Base)

local Checkbox = {}
Checkbox.__index = Checkbox

export type Options = {
	Text: string?,
	Default: boolean?,
	Disabled: boolean?,
	Callback: ((value: boolean) -> ())?,
}

export type Checkbox = {
	Instance: Frame,
	Changed: Signal.Signal,
	GetValue: (self: Checkbox) -> boolean,
	SetValue: (self: Checkbox, value: boolean, silent: boolean?) -> (),
	Toggle: (self: Checkbox, silent: boolean?) -> (),
	SetDisabled: (self: Checkbox, disabled: boolean) -> (),
	SetVisible: (self: Checkbox, visible: boolean) -> (),
	OnChanged: (self: Checkbox, handler: (value: boolean) -> ()) -> Signal.Connection,
	Destroy: (self: Checkbox) -> (),
}

function Checkbox.new(
	ctx: Types.UIContext,
	parent: Instance,
	options: Options
): Checkbox
	local theme = ctx.GetTheme()
	local bag = Util.bag()
	local value = options.Default == true
	local disabled = options.Disabled == true
	local hovered = false
	local callback = options.Callback
	local labelText = options.Text or "Checkbox"

	local row = Base.row(ctx, parent, labelText)
	local changed = Signal.new()

	local box = Util.textButton({
		Name = "Checkbox",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(20, 20),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		Active = not disabled,
	}, row)

	Util.corner(box, theme.Radius.Element - 6)
	local stroke = Util.stroke(box, 1)

	local check = Util.frame({
		Name = "Check",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, box)

	local short = Util.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(7, 11),
		Size = UDim2.fromOffset(2, 7),
		Rotation = 45,
		BorderSizePixel = 0,
	}, check)
	Util.corner(short, 1)

	local long = Util.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(11, 10),
		Size = UDim2.fromOffset(2, 10),
		Rotation = -48,
		BorderSizePixel = 0,
	}, check)
	Util.corner(long, 1)

	local checkScale = Util.create("UIScale", {
		Scale = if value then 1 else 0,
	}, check) :: UIScale

	local function targets(): (Color3, string, Color3, number, number)
		local current = ctx.GetTheme()

		if disabled then
			return current.Palette.SurfaceRaised, "SurfaceRaised", current.Palette.TextFaint, 0.5, 0.7
		end

		if value then
			return current.Palette.Accent, "Accent", current.Palette.OnAccent, 0, 1
		end

		if hovered then
			return current.Palette.Hover, "Hover", current.Palette.Text, 0, 0.55
		end

		return current.Palette.SurfaceRaised, "SurfaceRaised", current.Palette.TextFaint, 0, 0.4
	end

	local function apply(animate: boolean)
		local fill, fillRole, mark, strokeTransparency, strokeOpacity = targets()
		local current = ctx.GetTheme()

		ctx.Paint(box, "BackgroundColor3", fillRole)
		ctx.Paint(stroke, "Color", if value then "Accent" else if hovered then "StrokeStrong" else "Stroke")
		ctx.Paint(short, "BackgroundColor3", if value then "OnAccent" else "TextFaint")
		ctx.Paint(long, "BackgroundColor3", if value then "OnAccent" else "TextFaint")

		local targetScale = if value then 1 else 0

		if animate then
			Animation.play(box, current.Motion.Fast, {
				BackgroundColor3 = fill,
			}, {
				easing = "Quad",
			})
			Animation.play(checkScale, current.Motion.Fast, {
				Scale = targetScale,
			}, {
				easing = "Quad",
				direction = "Out",
			})
			stroke.Transparency = strokeTransparency
			Animation.play(stroke, current.Motion.Fast, {
				Transparency = strokeTransparency,
			}, {
				easing = "Quad",
			})
		else
			box.BackgroundColor3 = fill
			checkScale.Scale = targetScale
			stroke.Transparency = strokeTransparency
		end

		short.BackgroundColor3 = if value then ctx.Color("OnAccent") else ctx.Color("TextFaint")
		long.BackgroundColor3 = short.BackgroundColor3
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

	bag:Add(box.Activated:Connect(function()
		setValue(not value, false)
	end))

	bag:Add(box.MouseEnter:Connect(function()
		if disabled then
			return
		end
		hovered = true
		apply(true)
	end))

	bag:Add(box.MouseLeave:Connect(function()
		if disabled then
			return
		end
		hovered = false
		apply(true)
	end))

	local self = setmetatable({} :: any, Checkbox) :: Checkbox
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
		box.Active = not disabled
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

	row:SetAttribute("KaizaxComponent", "Checkbox")
	ctx.Register(row, labelText)

	return self
end

return Checkbox

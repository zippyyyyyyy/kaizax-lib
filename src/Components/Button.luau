--!strict

local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Parent.Util)
local Animation = require(script.Parent.Parent.Animation)
local Signal = require(script.Parent.Parent.Signal)
local Base = require(script.Parent.Base)

local Button = {}
Button.__index = Button

export type Options = {
	Text: string?,
	Variant: Types.ButtonVariant?,
	Height: number?,
	Disabled: boolean?,
	Callback: (() -> ())?,
}

export type Button = {
	Instance: TextButton,
	Clicked: Signal.Signal,
	SetText: (self: Button, text: string) -> (),
	GetText: (self: Button) -> string,
	SetDisabled: (self: Button, disabled: boolean) -> (),
	GetDisabled: (self: Button) -> boolean,
	SetVisible: (self: Button, visible: boolean) -> (),
	Sweep: (self: Button, enabled: boolean) -> (),
	Flash: (self: Button) -> (),
	OnClicked: (self: Button, handler: () -> ()) -> Signal.Connection,
	Destroy: (self: Button) -> (),
}

local registry: { [Instance]: Button } = {}

function Button.new(
	ctx: Types.UIContext,
	parent: Instance,
	options: Options
): Button
	local theme = ctx.GetTheme()
	local bag = Util.bag()
	local variant = options.Variant or "Secondary"
	local text = options.Text or "Button"
	local disabled = options.Disabled == true
	local callback = options.Callback

	local instance = Util.textButton({
		Name = "Button",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, options.Height or 32),
		Text = "",
		Active = not disabled,
	}, parent)
	instance:SetAttribute("KaizaxButtonVariant", variant)

	local surface = Util.frame({
		Name = "Surface",
		BackgroundColor3 = theme.Palette.SurfaceRaised,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, instance)
	Util.corner(surface, theme.Radius.Element)
	if variant == "Primary" then
		Util.gradient(surface, "PrimaryShade", 0, theme)
	end

	local label = Base.text(ctx, instance, text, {
		Font = theme.Fonts.Medium,
		Size = 13,
		ColorRole = "Text",
		XAlign = Enum.TextXAlignment.Center,
	})
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Position = UDim2.fromOffset(10, 0)
	label.ZIndex = 3

	local sweep = Util.frame({
		Name = "Sweep",
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 2,
	}, surface)
	ctx.Paint(sweep, "BackgroundColor3", "Text")
	local sweepGradient = Util.create("UIGradient", {
		Offset = Vector2.new(-1, 0),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, sweep) :: UIGradient
	local sweepTween: Tween? = nil
	local sweepToken = 0

	local stroke = Util.stroke(surface, 1)
	stroke.Transparency = 1
	local clicked = Signal.new()

	local function stopSweep()
		sweepToken += 1
		Animation.cancel(sweepTween)
		sweepTween = nil
		sweep.Visible = false
		sweepGradient.Offset = Vector2.new(-1, 0)
	end

	bag:Add(instance:GetPropertyChangedSignal("Visible"):Connect(function()
		if not instance.Visible then
			stopSweep()
		end
	end))

	local function startSweep(loop: boolean)
		stopSweep()
		if not Animation.enabled() or Animation.reducedMotion() then
			return
		end

		local token = sweepToken
		sweep.Visible = true
		sweepGradient.Offset = Vector2.new(-1, 0)
		sweepTween = Animation.play(sweepGradient, if loop then 0.7 else 0.45, {
			Offset = Vector2.new(1, 0),
		}, {
			easing = "Quad",
			repeatCount = if loop then -1 else 0,
			tag = "KaizaxSweep",
		})

		if not loop then
			task.delay(0.47, function()
				if token == sweepToken then
					sweep.Visible = false
				end
			end)
		end
	end

	local function style(): (Color3, number, string, string, Color3?, number?, string?)
		local current = ctx.GetTheme()

		if disabled then
			return current.Palette.SurfaceRaised, 0.45, "SurfaceRaised", "TextFaint", nil, nil, "SurfaceRaised"
		end

		if variant == "Primary" then
			return current.Palette.Accent, 0, "Accent", "OnAccent", nil, nil, "Accent"
		elseif variant == "Danger" then
			return current.Palette.Danger, 0.9, "Danger", "Danger", current.Palette.Danger, 0.65, "Danger"
		elseif variant == "Ghost" then
			return current.Palette.Surface, 0.35, "Surface", "TextMuted", current.Palette.Stroke, 0.35, "Stroke"
		end

		return current.Palette.SurfaceRaised, 0, "SurfaceRaised", "Text", current.Palette.Stroke, 0, "Stroke"
	end

	local function applyStyle(animate: boolean)
		local background, transparency, backgroundRole, textRole, strokeColor, strokeTransparency, strokeRole =
			style()

		local strokeRoleName = strokeRole or "Stroke"
		if animate then
			Util.paint(surface, "BackgroundColor3", backgroundRole)
			Util.paint(label, "TextColor3", textRole)
			if strokeColor then
				Util.paint(stroke, "Color", strokeRoleName)
			end
		else
			ctx.Paint(surface, "BackgroundColor3", backgroundRole)
			ctx.Paint(label, "TextColor3", textRole)
			if strokeColor then
				ctx.Paint(stroke, "Color", strokeRoleName)
			end
		end

		stroke.Transparency = if strokeColor then (strokeTransparency or 0) else 1

		if animate then
			local motion = Animation.MOTION.Hover
			Animation.play(surface, motion.Duration, {
				BackgroundColor3 = background,
				BackgroundTransparency = transparency,
			}, {
				easing = motion.Easing,
				direction = motion.Direction,
			})

			if not disabled then
				Animation.play(label, Animation.MOTION.Label.Duration, {
					TextColor3 = ctx.Color(textRole),
				}, {
					easing = Animation.MOTION.Label.Easing,
					direction = Animation.MOTION.Label.Direction,
				})
			end
		else
			surface.BackgroundColor3 = background
			surface.BackgroundTransparency = transparency
			label.TextColor3 = ctx.Color(textRole)
		end
	end

	applyStyle(false)

	local pressed = false
	local function setPressed(value: boolean)
		if disabled or pressed == value then
			return
		end
		pressed = value

		local current = ctx.GetTheme()
		local background, _, backgroundRole = style()
		Util.paint(surface, "BackgroundColor3", backgroundRole)
		local target = if value then background:Lerp(current.Palette.Background, 0.18) else background
		local motion = Animation.MOTION.Press

		Animation.play(surface, motion.Duration, {
			BackgroundColor3 = target,
		}, { easing = motion.Easing, direction = motion.Direction })
		Animation.play(label, motion.Duration, {
			Position = UDim2.fromOffset(10, if value then 1 else 0),
		}, { easing = motion.Easing, direction = motion.Direction })
	end

	bag:Add(instance.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			setPressed(true)
		end
	end))

	local function releasePress()
		setPressed(false)
	end

	bag:Add(instance.InputEnded:Connect(releasePress))
	bag:Add(instance.MouseLeave:Connect(releasePress))

	bag:Add(instance.MouseEnter:Connect(function()
		if disabled then
			return
		end

		local current = ctx.GetTheme()
		local motion = Animation.MOTION.Hover
		local hoverColor: Color3
		local hoverTransparency: number
		local hoverRole: string

		if variant == "Primary" then
			hoverColor = current.Palette.Accent:Lerp(current.Palette.Text, 0.08)
			hoverTransparency = 0
			hoverRole = "Accent"
		elseif variant == "Danger" then
			hoverColor = current.Palette.Danger
			hoverTransparency = 0.82
			hoverRole = "Danger"
		else
			hoverColor = current.Palette.Hover
			hoverTransparency = 0
			hoverRole = "Hover"
		end

		Util.paint(surface, "BackgroundColor3", hoverRole)
		Animation.play(surface, motion.Duration, {
			BackgroundColor3 = hoverColor,
			BackgroundTransparency = hoverTransparency,
		}, {
			easing = motion.Easing,
			direction = motion.Direction,
		})

		if variant == "Ghost" then
			Util.paint(label, "TextColor3", "Text")
			Animation.play(label, Animation.MOTION.Label.Duration, {
				TextColor3 = current.Palette.Text,
			}, {
				easing = Animation.MOTION.Label.Easing,
				direction = Animation.MOTION.Label.Direction,
			})
		end

		if stroke.Transparency < 1 then
			Util.paint(stroke, "Color", "StrokeStrong")
			Animation.play(stroke, motion.Duration, {
				Color = current.Palette.StrokeStrong,
			}, {
				easing = motion.Easing,
				direction = motion.Direction,
			})
		end
	end))

	bag:Add(instance.MouseLeave:Connect(function()
		if disabled then
			return
		end
		applyStyle(true)
	end))

	bag:Add(instance.Activated:Connect(function()
		if disabled then
			return
		end
		clicked:Fire()
		Util.safeCall(callback)
	end))

	local self = setmetatable({} :: any, Button) :: Button
	self.Instance = instance
	self.Clicked = clicked
	registry[instance] = self

	function self:SetText(newText: string)
		text = newText
		label.Text = newText
	end

	function self:GetText(): string
		return text
	end

	function self:SetDisabled(value: boolean)
		if disabled == value then
			return
		end
		disabled = value
		instance.Active = not value
		if value then
			stopSweep()
			setPressed(false)
		end
		applyStyle(true)
	end

	function self:GetDisabled(): boolean
		return disabled
	end

	function self:SetVisible(visible: boolean)
		instance.Visible = visible
	end

	function self:Sweep(enabled: boolean)
		if enabled then
			startSweep(true)
		else
			stopSweep()
		end
	end

	function self:Flash()
		startSweep(false)
	end

	function self:OnClicked(handler: () -> ()): Signal.Connection
		return clicked:Connect(handler)
	end

	function self:Destroy()
		stopSweep()
		registry[instance] = nil
		bag:Clear()
		clicked:DisconnectAll()
		instance:Destroy()
	end

	instance:SetAttribute("KaizaxComponent", "Button")
	ctx.Register(instance, text)

	return self
end

function Button.Get(instance: Instance): Button?
	return registry[instance]
end

return Button

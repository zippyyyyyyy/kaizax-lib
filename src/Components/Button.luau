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
	OnClicked: (self: Button, handler: () -> ()) -> Signal.Connection,
	Destroy: (self: Button) -> (),
}

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
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, options.Height or 32),
		Text = "",
		Active = not disabled,
	}, parent)

	Util.corner(instance, theme.Radius.Element)

	local label = Base.text(ctx, instance, text, {
		Font = theme.Fonts.Medium,
		Size = 13,
		ColorRole = "Text",
		XAlign = Enum.TextXAlignment.Center,
	})
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Position = UDim2.fromOffset(10, 0)

	local stroke = Util.stroke(instance, 1)
	stroke.Transparency = 1
	local clicked = Signal.new()

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
		local current = ctx.GetTheme()

		ctx.Paint(instance, "BackgroundColor3", backgroundRole)
		ctx.Paint(label, "TextColor3", textRole)

		if strokeColor then
			ctx.Paint(stroke, "Color", strokeRole or "Stroke")
			stroke.Transparency = strokeTransparency or 0
		else
			stroke.Transparency = 1
		end

		if animate then
			Animation.play(instance, current.Motion.Fast, {
				BackgroundColor3 = background,
				BackgroundTransparency = transparency,
			}, {
				easing = "Quad",
			})

			if not disabled then
				Animation.play(label, current.Motion.Fast, {
					TextColor3 = ctx.Color(textRole),
				}, {
					easing = "Quad",
				})
			end
		else
			instance.BackgroundColor3 = background
			instance.BackgroundTransparency = transparency
			label.TextColor3 = ctx.Color(textRole)
		end
	end

	applyStyle(false)
	Base.pressable(instance, bag)

	bag:Add(instance.MouseEnter:Connect(function()
		if disabled then
			return
		end

		local current = ctx.GetTheme()
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

		ctx.Paint(instance, "BackgroundColor3", hoverRole)
		Animation.play(instance, current.Motion.Fast, {
			BackgroundColor3 = hoverColor,
			BackgroundTransparency = hoverTransparency,
		}, {
			easing = "Quad",
		})

		if variant == "Ghost" then
			ctx.Paint(label, "TextColor3", "Text")
			Animation.play(label, current.Motion.Fast, {
				TextColor3 = current.Palette.Text,
			}, {
				easing = "Quad",
			})
		end

		if stroke.Transparency < 1 then
			ctx.Paint(stroke, "Color", "StrokeStrong")
			Animation.play(stroke, current.Motion.Fast, {
				Color = current.Palette.StrokeStrong,
			}, {
				easing = "Quad",
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
		applyStyle(true)
	end

	function self:GetDisabled(): boolean
		return disabled
	end

	function self:SetVisible(visible: boolean)
		instance.Visible = visible
	end

	function self:OnClicked(handler: () -> ()): Signal.Connection
		return clicked:Connect(handler)
	end

	function self:Destroy()
		bag:Clear()
		clicked:DisconnectAll()
		instance:Destroy()
	end

	instance:SetAttribute("KaizaxComponent", "Button")
	ctx.Register(instance, text)

	return self
end

return Button

--!strict

local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Parent.Util)
local Animation = require(script.Parent.Parent.Animation)

local Base = {}

export type TextOptions = {
	Font: Enum.Font?,
	Size: number?,
	ColorRole: string?,
	XAlign: Enum.TextXAlignment?,
	YAlign: Enum.TextYAlignment?,
	Wrapped: boolean?,
	Truncate: boolean?,
}

--- Creates a styled, theme-bound text label.
function Base.text(
	ctx: Types.UIContext,
	parent: Instance,
	text: string,
	options: TextOptions?
): TextLabel
	local theme = ctx.GetTheme()
	local opts = options or {}

	local label = Util.label({
		BackgroundTransparency = 1,
		Text = text,
		Font = opts.Font or theme.Fonts.Regular,
		TextSize = opts.Size or 13,
		TextColor3 = theme.Palette.TextMuted,
		TextXAlignment = opts.XAlign or Enum.TextXAlignment.Left,
		TextYAlignment = opts.YAlign or Enum.TextYAlignment.Center,
		TextWrapped = opts.Wrapped or false,
		TextTruncate = if opts.Wrapped then Enum.TextTruncate.None elseif opts.Truncate == false then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
		RichText = false,
		Size = UDim2.fromScale(1, 1),
	}, parent)

	ctx.Paint(label, "TextColor3", opts.ColorRole or "TextMuted")
	return label
end

--- Standard control row with a label and an optional right-hand slot.
function Base.row(
	ctx: Types.UIContext,
	parent: Instance,
	text: string?,
	height: number?
): (Frame, Frame, TextLabel?)
	local theme = ctx.GetTheme()
	local rowHeight = height or theme.Window.RowHeight

	local row = Util.frame({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, rowHeight),
	}, parent)

	local label: TextLabel? = nil
	if text and text ~= "" then
		label = Base.text(ctx, row, text, {
			Font = theme.Fonts.Medium,
			Size = 13,
			ColorRole = "TextMuted",
		})
		label.Size = UDim2.new(1, -200, 1, 0)
	end

	local slot = Util.frame({
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(0, rowHeight),
		AutomaticSize = Enum.AutomaticSize.X,
	}, row)

	Util.create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, slot)

	return row, slot, label
end

--- Hover/press color behavior with theme bindings kept in sync.
function Base.hover(
	ctx: Types.UIContext,
	object: GuiObject,
	bag: Util.Bag,
	baseRole: string?,
	hoverRole: string?,
	baseTransparency: number?,
	hoverTransparency: number?
)
	local theme = ctx.GetTheme()
	local hover = hoverRole or "Hover"
	local normalTransparency = baseTransparency or 0
	local activeTransparency = hoverTransparency or normalTransparency

	if baseRole then
		ctx.Paint(object, "BackgroundColor3", baseRole)
	else
		object.BackgroundTransparency = normalTransparency
	end

	bag:Add(object.MouseEnter:Connect(function()
		if baseRole then
			ctx.Paint(object, "BackgroundColor3", hover)
		end
		Animation.play(object, theme.Motion.Fast, {
			BackgroundColor3 = ctx.Color(hover),
			BackgroundTransparency = activeTransparency,
		}, {
			easing = "Quad",
		})
	end))

	bag:Add(object.MouseLeave:Connect(function()
		if baseRole then
			ctx.Paint(object, "BackgroundColor3", baseRole)
		end
		Animation.play(object, theme.Motion.Fast, {
			BackgroundColor3 = if baseRole then ctx.Color(baseRole) else ctx.Color(hover),
			BackgroundTransparency = normalTransparency,
		}, {
			easing = "Quad",
		})
	end))
end

--- Adds a press-scale to a button without affecting layout.
function Base.pressable(object: GuiObject, bag: Util.Bag)
	local scale = Util.create("UIScale", {
		Scale = 1,
	}, object) :: UIScale

	bag:Add(object.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			Animation.play(scale, 0.08, { Scale = 0.97 }, { easing = "Quad" })
		end
	end))

	local function release()
		Animation.play(scale, 0.14, { Scale = 1 }, { easing = "Quad", direction = "Out" })
	end

	bag:Add(object.InputEnded:Connect(release))
	bag:Add(object.MouseLeave:Connect(release))
	return scale
end

function Base.spacer(parent: Instance, height: number): Frame
	return Util.frame({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
	}, parent)
end

--- Small chevron made from primitives so it stays crisp at any scale.
function Base.chevron(ctx: Types.UIContext, parent: Instance, colorRole: string?): Frame
	local holder = Util.frame({
		Name = "Chevron",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(12, 12),
	}, parent)

	local left = Util.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(3.9, 4.9),
		Rotation = 45,
		Size = UDim2.fromOffset(6, 1.5),
	}, holder)
	Util.corner(left, 1)
	ctx.Paint(left, "BackgroundColor3", colorRole or "TextFaint")

	local right = Util.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8.1, 4.9),
		Rotation = -45,
		Size = UDim2.fromOffset(6, 1.5),
	}, holder)
	Util.corner(right, 1)
	ctx.Paint(right, "BackgroundColor3", colorRole or "TextFaint")

	return holder
end

return Base

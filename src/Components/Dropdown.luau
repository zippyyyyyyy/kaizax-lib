--!strict

local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Parent.Util)
local Animation = require(script.Parent.Parent.Animation)
local Signal = require(script.Parent.Parent.Signal)
local Base = require(script.Parent.Base)

local Dropdown = {}
Dropdown.__index = Dropdown

export type Options = {
	Text: string?,
	Options: { string },
	Default: string?,
	Placeholder: string?,
	Disabled: boolean?,
	Callback: ((value: string) -> ())?,
}

export type Dropdown = {
	Instance: Frame,
	Changed: Signal.Signal,
	GetValue: (self: Dropdown) -> string?,
	SetValue: (self: Dropdown, value: string?, silent: boolean?) -> (),
	SetOptions: (self: Dropdown, options: { string }) -> (),
	GetOptions: (self: Dropdown) -> { string },
	SetDisabled: (self: Dropdown, disabled: boolean) -> (),
	SetVisible: (self: Dropdown, visible: boolean) -> (),
	OnChanged: (self: Dropdown, handler: (value: string) -> ()) -> Signal.Connection,
	Destroy: (self: Dropdown) -> (),
}

function Dropdown.new(
	ctx: Types.UIContext,
	parent: Instance,
	options: Options
): Dropdown
	local theme = ctx.GetTheme()
	local bag = Util.bag()
	local popupBag = Util.bag()
	local items: { string } = table.clone(options.Options or {})
	local value: string? = options.Default
	local disabled = options.Disabled == true
	local labelText = options.Text or "Dropdown"
	local placeholder = options.Placeholder or "Select"
	local callback = options.Callback
	local owner = {}
	local popupOpen = false
	local closeActive: (() -> ())? = nil
	local changed = Signal.new()

	if value ~= nil and not table.find(items, value) then
		value = nil
	end

	local row = Base.row(ctx, parent, labelText)

	local button = Util.textButton({
		Name = "Dropdown",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(138, 26),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		Active = not disabled and #items > 0,
	}, row)

	Util.corner(button, theme.Radius.Element)
	local stroke = Util.stroke(button, 1)

	local valueLabel = Base.text(ctx, button, placeholder, {
		Font = theme.Fonts.Mono,
		Size = 12,
		ColorRole = "TextFaint",
		XAlign = Enum.TextXAlignment.Left,
	})
	valueLabel.Position = UDim2.fromOffset(10, 0)
	valueLabel.Size = UDim2.new(1, -30, 1, 0)

	local chevron = Base.chevron(ctx, button, "TextFaint")
	chevron.AnchorPoint = Vector2.new(1, 0.5)
	chevron.Position = UDim2.new(1, -8, 0.5, 0)

	local function paintChevron(role: string)
		for _, bar in chevron:GetChildren() do
			if bar:IsA("Frame") then
				ctx.Paint(bar, "BackgroundColor3", role)
				bar.BackgroundColor3 = ctx.Color(role)
			end
		end
	end

	local function updateDisplay()
		if value then
			valueLabel.Text = value
			ctx.Paint(valueLabel, "TextColor3", "Text")
			paintChevron("TextMuted")
		else
			valueLabel.Text = placeholder
			ctx.Paint(valueLabel, "TextColor3", "TextFaint")
			paintChevron("TextFaint")
		end

		valueLabel.TextColor3 = ctx.Color(if value then "Text" else "TextFaint")
	end

	local function applyDisabled()
		button.Active = not disabled and #items > 0
		ctx.Paint(button, "BackgroundColor3", if disabled then "Surface" else "SurfaceRaised")
		button.BackgroundColor3 = ctx.Color(if disabled then "Surface" else "SurfaceRaised")
		button.BackgroundTransparency = if disabled then 0.35 else 0
		ctx.Paint(stroke, "Color", "Stroke")
		stroke.Transparency = if disabled then 0.6 else 0
		ctx.Paint(valueLabel, "TextColor3", if disabled then "TextFaint" else if value then "Text" else "TextFaint")
		valueLabel.TextColor3 = ctx.Color(if disabled then "TextFaint" else if value then "Text" else "TextFaint")
		chevron.Visible = not disabled
		if disabled then
			paintChevron("TextFaint")
		end
	end

	local function close()
		if closeActive then
			local callbackClose = closeActive
			closeActive = nil
			callbackClose()
		end
	end

	local function open()
		if disabled or popupOpen or #items == 0 then
			return
		end

		close()
		popupBag:Clear()

		local height = math.min(#items * 30 + 12, 252)
		local popupFrame, closeFn = ctx.OpenPopup(owner, button, 202, height, function()
			popupOpen = false
			closeActive = nil
			popupBag:Clear()
			Animation.play(chevron, ctx.GetTheme().Motion.Fast, {
				Rotation = 0,
			}, { easing = "Quad" })
		end)

		popupOpen = true
		closeActive = closeFn

		Animation.play(chevron, ctx.GetTheme().Motion.Fast, {
			Rotation = 180,
		}, { easing = "Quad", direction = "Out" })

		local scroller = Util.scrollingFrame({
			Name = "Options",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = ctx.Color("StrokeStrong"),
			ScrollingDirection = Enum.ScrollingDirection.Y,
		}, popupFrame)

		Util.padding(scroller, 5, 5)
		Util.list(scroller, 2)

		for index, item in items do
			local selected = value == item

			local optionRow = Util.textButton({
				Name = `Option_{index}`,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = index,
				Size = UDim2.new(1, 0, 0, 30),
				Text = "",
				AutoButtonColor = false,
			}, scroller)

			Util.corner(optionRow, 4)

			local optionLabel = Base.text(ctx, optionRow, item, {
				Font = theme.Fonts.Regular,
				Size = 12.5,
				ColorRole = if selected then "Accent" else "TextMuted",
				XAlign = Enum.TextXAlignment.Left,
			})
			optionLabel.Position = UDim2.fromOffset(10, 0)
			optionLabel.Size = UDim2.new(1, -30, 1, 0)

			if selected then
				local dot = Util.frame({
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(5, 5),
					BorderSizePixel = 0,
				}, optionRow)
				Util.corner(dot, 999)
				ctx.Paint(dot, "BackgroundColor3", "Accent")
			end

			Base.hover(ctx, optionRow, popupBag, if selected then "Accent" else nil, "Hover", if selected then 0.9 else 1, 0)

			popupBag:Add(optionRow.MouseEnter:Connect(function()
				optionLabel.TextColor3 = ctx.Color("Text")
			end))
			popupBag:Add(optionRow.MouseLeave:Connect(function()
				optionLabel.TextColor3 = ctx.Color(if selected then "Accent" else "TextMuted")
			end))

			popupBag:Add(optionRow.Activated:Connect(function()
				value = item
				updateDisplay()
				close()
				changed:Fire(item)
				Util.safeCall(callback, item)
			end))
		end
	end

	do
		local baseRole = "SurfaceRaised"
		button.BackgroundColor3 = ctx.Color(baseRole)
		ctx.Paint(button, "BackgroundColor3", baseRole)
		ctx.Paint(stroke, "Color", "Stroke")

		bag:Add(button.MouseEnter:Connect(function()
			if disabled then
				return
			end
			local current = ctx.GetTheme()
			ctx.Paint(button, "BackgroundColor3", "Hover")
			ctx.Paint(stroke, "Color", "StrokeStrong")
			Animation.play(button, current.Motion.Fast, {
				BackgroundColor3 = ctx.Color("Hover"),
			}, { easing = "Quad" })
			Animation.play(stroke, current.Motion.Fast, {
				Color = ctx.Color("StrokeStrong"),
			}, { easing = "Quad" })
			paintChevron("Text")
		end))

		bag:Add(button.MouseLeave:Connect(function()
			if disabled then
				return
			end
			local current = ctx.GetTheme()
			ctx.Paint(button, "BackgroundColor3", "SurfaceRaised")
			ctx.Paint(stroke, "Color", "Stroke")
			Animation.play(button, current.Motion.Fast, {
				BackgroundColor3 = ctx.Color("SurfaceRaised"),
			}, { easing = "Quad" })
			Animation.play(stroke, current.Motion.Fast, {
				Color = ctx.Color("Stroke"),
			}, { easing = "Quad" })
			paintChevron(if value then "TextMuted" else "TextFaint")
		end))
	end

	bag:Add(button.Activated:Connect(function()
		if popupOpen then
			close()
		else
			open()
		end
	end))

	updateDisplay()
	applyDisabled()

	local self = setmetatable({} :: any, Dropdown) :: Dropdown
	self.Instance = row
	self.Changed = changed

	function self:GetValue(): string?
		return value
	end

	function self:SetValue(nextValue: string?, silent: boolean?)
		if nextValue ~= nil and not table.find(items, nextValue) then
			error(`Kaizax dropdown: "{nextValue}" is not one of the options`, 2)
		end
		if value == nextValue then
			return
		end
		value = nextValue
		updateDisplay()
		changed:Fire(value)
		if not silent then
			Util.safeCall(callback, value)
		end
	end

	function self:SetOptions(nextOptions: { string })
		items = table.clone(nextOptions)

		if value and not table.find(items, value) then
			value = nil
		end

		close()
		updateDisplay()
		applyDisabled()
	end

	function self:GetOptions(): { string }
		return table.clone(items)
	end

	function self:SetDisabled(nextDisabled: boolean)
		if disabled == nextDisabled then
			return
		end
		disabled = nextDisabled
		close()
		applyDisabled()
	end

	function self:SetVisible(visible: boolean)
		row.Visible = visible
	end

	function self:OnChanged(handler: (value: string) -> ()): Signal.Connection
		return changed:Connect(handler)
	end

	function self:Destroy()
		close()
		bag:Clear()
		popupBag:Clear()
		changed:DisconnectAll()
		row:Destroy()
	end

	row:SetAttribute("KaizaxComponent", "Dropdown")
	ctx.Register(row, labelText)

	return self
end

return Dropdown

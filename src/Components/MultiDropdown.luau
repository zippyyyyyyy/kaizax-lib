--!strict

local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Parent.Util)
local Animation = require(script.Parent.Parent.Animation)
local Signal = require(script.Parent.Parent.Signal)
local Base = require(script.Parent.Base)

local MultiDropdown = {}
MultiDropdown.__index = MultiDropdown

export type Options = {
	Text: string?,
	Options: { string },
	Default: { string }?,
	Placeholder: string?,
	Disabled: boolean?,
	Callback: ((values: { string }) -> ())?,
}

export type MultiDropdown = {
	Instance: Frame,
	Changed: Signal.Signal,
	GetValue: (self: MultiDropdown) -> { string },
	SetValue: (self: MultiDropdown, values: { string }, silent: boolean?) -> (),
	Clear: (self: MultiDropdown, silent: boolean?) -> (),
	SetOptions: (self: MultiDropdown, options: { string }) -> (),
	GetOptions: (self: MultiDropdown) -> { string },
	SetDisabled: (self: MultiDropdown, disabled: boolean) -> (),
	SetVisible: (self: MultiDropdown, visible: boolean) -> (),
	OnChanged: (self: MultiDropdown, handler: (values: { string }) -> ()) -> Signal.Connection,
	Destroy: (self: MultiDropdown) -> (),
}

function MultiDropdown.new(
	ctx: Types.UIContext,
	parent: Instance,
	options: Options
): MultiDropdown
	local theme = ctx.GetTheme()
	local bag = Util.bag()
	local popupBag = Util.bag()
	local items: { string } = table.clone(options.Options or {})
	local selected: { [string]: boolean } = {}
	local disabled = options.Disabled == true
	local labelText = options.Text or "Select"
	local placeholder = options.Placeholder or "None selected"
	local callback = options.Callback
	local owner = {}
	local popupOpen = false
	local closeActive: (() -> ())? = nil
	local changed = Signal.new()

	for _, item in options.Default or {} do
		if table.find(items, item) then
			selected[item] = true
		end
	end

	local function getValues(): { string }
		local values = {}
		for _, item in items do
			if selected[item] then
				table.insert(values, item)
			end
		end
		return values
	end

	local row = Base.row(ctx, parent, labelText)

	local button = Util.textButton({
		Name = "MultiDropdown",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(184, 32),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		Active = not disabled and #items > 0,
	}, row)

	Util.corner(button, theme.Radius.Element)
	local stroke = Util.stroke(button, 1)

	local valueLabel = Base.text(ctx, button, placeholder, {
		Font = theme.Fonts.Mono,
		Size = 12.5,
		ColorRole = "TextFaint",
		XAlign = Enum.TextXAlignment.Left,
	})
	valueLabel.Position = UDim2.fromOffset(10, 0)
	valueLabel.Size = UDim2.new(1, -32, 1, 0)

	local chevron = Base.chevron(ctx, button, "TextFaint")
	chevron.AnchorPoint = Vector2.new(1, 0.5)
	chevron.Position = UDim2.new(1, -10, 0.5, 0)

	local function paintChevron(role: string)
		for _, bar in chevron:GetChildren() do
			if bar:IsA("Frame") then
				ctx.Paint(bar, "BackgroundColor3", role)
				bar.BackgroundColor3 = ctx.Color(role)
			end
		end
	end

	local function updateDisplay()
		local values = getValues()
		if #values == 0 then
			valueLabel.Text = placeholder
			ctx.Paint(valueLabel, "TextColor3", "TextFaint")
			paintChevron("TextFaint")
		elseif #values == 1 then
			valueLabel.Text = values[1]
			ctx.Paint(valueLabel, "TextColor3", "Text")
			paintChevron("TextMuted")
		elseif #values == 2 then
			valueLabel.Text = `{values[1]}, {values[2]}`
			ctx.Paint(valueLabel, "TextColor3", "Text")
			paintChevron("TextMuted")
		else
			valueLabel.Text = `{values[1]}, {values[2]} +{#values - 2}`
			ctx.Paint(valueLabel, "TextColor3", "Text")
			paintChevron("TextMuted")
		end

		valueLabel.TextColor3 = ctx.Color(if #values == 0 then "TextFaint" else "Text")
	end

	local function applyDisabled()
		button.Active = not disabled and #items > 0
		ctx.Paint(button, "BackgroundColor3", if disabled then "Surface" else "SurfaceRaised")
		button.BackgroundColor3 = ctx.Color(if disabled then "Surface" else "SurfaceRaised")
		button.BackgroundTransparency = if disabled then 0.35 else 0
		ctx.Paint(stroke, "Color", "Stroke")
		stroke.Transparency = if disabled then 0.6 else 0
		ctx.Paint(valueLabel, "TextColor3", if disabled then "TextFaint" else "Text")
		valueLabel.TextColor3 = ctx.Color(if disabled then "TextFaint" else "Text")
		chevron.Visible = not disabled
		if disabled then
			paintChevron("TextFaint")
		end
	end

	local function emit(notifyCallback: boolean)
		local values = getValues()
		changed:Fire(values)
		if notifyCallback then
			Util.safeCall(callback, table.clone(values))
		end
	end

	local function close()
		if closeActive then
			local callbackClose = closeActive
			closeActive = nil
			callbackClose()
		end
	end

	local function makeFooterButton(footer: Frame, text: string, primary: boolean, order: number): TextButton
		local footerButton = Util.textButton({
			Name = text,
			BackgroundColor3 = ctx.Color(if primary then "Accent" else "SurfaceRaised"),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(58, 26),
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = order,
		}, footer)

		Util.corner(footerButton, 4)
		ctx.Paint(footerButton, "BackgroundColor3", if primary then "Accent" else "SurfaceRaised")

		local label = Base.text(ctx, footerButton, text, {
			Font = theme.Fonts.Medium,
			Size = 11,
			ColorRole = if primary then "OnAccent" else "TextMuted",
			XAlign = Enum.TextXAlignment.Center,
		})
		label.Size = UDim2.fromScale(1, 1)

		return footerButton
	end

	local function open()
		if disabled or popupOpen or #items == 0 then
			return
		end

		close()
		popupBag:Clear()

		local height = math.min(#items * 30 + 52, 300)
		local popupFrame, closeFn = ctx.OpenPopup(owner, button, 224, height, function()
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
			Size = UDim2.new(1, 0, 1, -40),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = ctx.Color("StrokeStrong"),
			ScrollingDirection = Enum.ScrollingDirection.Y,
		}, popupFrame)

		Util.padding(scroller, 5, 5)
		Util.list(scroller, 2)

		local boxes: { [string]: { box: Frame, stroke: UIStroke, check: UIScale, label: TextLabel } } = {}

		local function paintOption(item: string)
			local entry = boxes[item]
			if not entry then
				return
			end

			local isSelected = selected[item] == true
			ctx.Paint(entry.box, "BackgroundColor3", if isSelected then "Accent" else "SurfaceRaised")
			ctx.Paint(entry.stroke, "Color", if isSelected then "Accent" else "Stroke")
			ctx.Paint(entry.label, "TextColor3", if isSelected then "Text" else "TextMuted")
			Animation.play(entry.box, ctx.GetTheme().Motion.Fast, {
				BackgroundColor3 = ctx.Color(if isSelected then "Accent" else "SurfaceRaised"),
			}, { easing = "Quad" })
			entry.stroke.Transparency = if isSelected then 1 else 0.4
			Animation.play(entry.check, ctx.GetTheme().Motion.Fast, {
				Scale = if isSelected then 1 else 0,
			}, { easing = "Quad", direction = "Out" })
		end

		for index, item in items do
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

			local box = Util.frame({
				Name = "Checkbox",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 1, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				BackgroundColor3 = ctx.Color("SurfaceRaised"),
				BorderSizePixel = 0,
			}, optionRow)

			Util.corner(box, 3)
			local boxStroke = Util.stroke(box, 1)

			local checkContainer = Util.frame({
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
			}, box)

			local checkScale = Util.create("UIScale", {
				Scale = if selected[item] then 1 else 0,
			}, checkContainer) :: UIScale

			local barOne = Util.frame({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = ctx.Color("OnAccent"),
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(4, 8),
				Rotation = 45,
				Size = UDim2.fromOffset(2, 5),
			}, checkContainer)
			Util.corner(barOne, 1)
			ctx.Paint(barOne, "BackgroundColor3", "OnAccent")

			local barTwo = Util.frame({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = ctx.Color("OnAccent"),
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(8, 7),
				Rotation = -48,
				Size = UDim2.fromOffset(2, 8),
			}, checkContainer)
			Util.corner(barTwo, 1)
			ctx.Paint(barTwo, "BackgroundColor3", "OnAccent")

			local optionLabel = Base.text(ctx, optionRow, item, {
				Font = theme.Fonts.Regular,
				Size = 12.5,
				ColorRole = if selected[item] then "Text" else "TextMuted",
				XAlign = Enum.TextXAlignment.Left,
			})
			optionLabel.Position = UDim2.fromOffset(26, 0)
			optionLabel.Size = UDim2.new(1, -36, 1, 0)

			boxes[item] = {
				box = box,
				stroke = boxStroke,
				check = checkScale,
				label = optionLabel,
			}

			Base.hover(ctx, optionRow, popupBag, nil, "Hover", 1, 0)

			popupBag:Add(optionRow.Activated:Connect(function()
				if selected[item] then
					selected[item] = nil
				else
					selected[item] = true
				end
				paintOption(item)
				updateDisplay()
				emit(true)
			end))
		end

		local divider = Util.frame({
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = ctx.Color("Stroke"),
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 1, -34),
			Size = UDim2.new(1, -12, 0, 1),
		}, popupFrame)
		ctx.Paint(divider, "BackgroundColor3", "Stroke")

		local footer = Util.frame({
			Name = "Footer",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.new(1, -12, 0, 34),
		}, popupFrame)

		Util.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, footer)

		local clearButton = makeFooterButton(footer, "Clear", false, 1)
		local doneButton = makeFooterButton(footer, "Done", true, 2)

		Base.hover(ctx, clearButton, popupBag, "SurfaceRaised", "Hover", 0, 0)
		Base.hover(ctx, doneButton, popupBag, "Accent", "Accent", 0, 0)

		popupBag:Add(clearButton.Activated:Connect(function()
			table.clear(selected)
			for item in boxes do
				paintOption(item)
			end
			updateDisplay()
			emit(true)
		end))

		popupBag:Add(doneButton.Activated:Connect(close))
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
			paintChevron(if #getValues() > 0 then "TextMuted" else "TextFaint")
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

	local self = setmetatable({} :: any, MultiDropdown) :: MultiDropdown
	self.Instance = row
	self.Changed = changed

	function self:GetValue(): { string }
		return getValues()
	end

	function self:SetValue(values: { string }, silent: boolean?)
		table.clear(selected)
		for _, item in values do
			if table.find(items, item) then
				selected[item] = true
			end
		end
		updateDisplay()
		if not silent then
			emit(true)
		end
	end

	function self:Clear(silent: boolean?)
		if next(selected) == nil then
			return
		end
		table.clear(selected)
		updateDisplay()
		if not silent then
			emit(true)
		end
	end

	function self:SetOptions(nextOptions: { string })
		items = table.clone(nextOptions)

		for item in selected do
			if not table.find(items, item) then
				selected[item] = nil
			end
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

	function self:OnChanged(handler: (values: { string }) -> ()): Signal.Connection
		return changed:Connect(handler)
	end

	function self:Destroy()
		close()
		bag:Clear()
		popupBag:Clear()
		changed:DisconnectAll()
		row:Destroy()
	end

	row:SetAttribute("KaizaxComponent", "MultiDropdown")
	ctx.Register(row, labelText)

	return self
end

return MultiDropdown

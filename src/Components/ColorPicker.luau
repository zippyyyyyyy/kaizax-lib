--!strict

local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Parent.Util)
local Animation = require(script.Parent.Parent.Animation)
local Signal = require(script.Parent.Parent.Signal)
local Base = require(script.Parent.Base)

local UserInputService = game:GetService("UserInputService")

local ColorPicker = {}
ColorPicker.__index = ColorPicker

export type Options = {
	Text: string?,
	Default: Color3?,
	Alpha: number?,
	ShowAlpha: boolean?,
	Live: boolean?,
	Disabled: boolean?,
	Callback: ((color: Color3, alpha: number) -> ())?,
}

export type ColorPicker = {
	Instance: Frame,
	Changed: Signal.Signal,
	Released: Signal.Signal,
	GetColor: (self: ColorPicker) -> Color3,
	GetAlpha: (self: ColorPicker) -> number,
	SetValue: (self: ColorPicker, color: Color3, alpha: number?, silent: boolean?) -> (),
	SetDisabled: (self: ColorPicker, disabled: boolean) -> (),
	SetVisible: (self: ColorPicker, visible: boolean) -> (),
	OnChanged: (self: ColorPicker, handler: (color: Color3, alpha: number) -> ()) -> Signal.Connection,
	OnReleased: (self: ColorPicker, handler: (color: Color3, alpha: number) -> ()) -> Signal.Connection,
	Destroy: (self: ColorPicker) -> (),
}

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

local function parseHex(value: string): Color3?
	local cleaned = string.gsub(value, "%s", "")
	cleaned = string.gsub(cleaned, "#", "")
	if #cleaned == 3 then
		cleaned = string.sub(cleaned, 1, 1) .. string.sub(cleaned, 1, 1)
			.. string.sub(cleaned, 2, 2) .. string.sub(cleaned, 2, 2)
			.. string.sub(cleaned, 3, 3) .. string.sub(cleaned, 3, 3)
	end
	if #cleaned ~= 6 or string.find(cleaned, "[^%x]") then
		return nil
	end
	local ok, color = pcall(Color3.fromHex, "#" .. cleaned)
	return if ok then color else nil
end

function ColorPicker.new(
	ctx: Types.UIContext,
	parent: Instance,
	options: Options
): ColorPicker
	local theme = ctx.GetTheme()
	local bag = Util.bag()
	local popupBag = Util.bag()
	local labelText = options.Text or "Color"
	local showAlpha = options.ShowAlpha ~= false
	local live = options.Live ~= false
	local disabled = options.Disabled == true
	local callback = options.Callback
	local initialColor = options.Default or Color3.fromHex("#00FAB4")
	local color = initialColor
	local alpha = clamp01(options.Alpha or 1)
	local hue, saturation, value = color:ToHSV()
	local owner = {}
	local popupOpen = false
	local closeActive: (() -> ())? = nil
	local changed = Signal.new()
	local released = Signal.new()

	local row, _, rowLabel = Base.row(ctx, parent, labelText)
	if rowLabel then
		rowLabel.Size = UDim2.new(1, -132, 1, 0)
	end

	local hexLabel = Base.text(ctx, row, Util.hex(color), {
		Font = theme.Fonts.Mono,
		Size = 10,
		ColorRole = "TextMuted",
		XAlign = Enum.TextXAlignment.Right,
	})
	hexLabel.AnchorPoint = Vector2.new(1, 0.5)
	hexLabel.Position = UDim2.new(1, -40, 0.5, 0)
	hexLabel.Size = UDim2.fromOffset(72, 20)

	local swatch = Util.textButton({
		Name = "Swatch",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(32, 24),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = not disabled,
		ClipsDescendants = true,
	}, row)

	Util.corner(swatch, 6)
	local swatchStroke = Util.stroke(swatch, 1)
	ctx.Paint(swatchStroke, "Color", "StrokeStrong")

	local swatchCell = 6
	for y = 0, 3 do
		for x = 0, 4 do
			local tile = Util.frame({
				BackgroundColor3 = theme.Palette.Surface,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(x * swatchCell, y * swatchCell),
				Size = UDim2.fromOffset(swatchCell, swatchCell),
			}, swatch)
			ctx.Paint(tile, "BackgroundColor3", if (x + y) % 2 == 0 then "Surface" else "Hover")
		end
	end

	local swatchColor = Util.frame({
		Name = "Color",
		BackgroundColor3 = color,
		BackgroundTransparency = 1 - alpha,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, swatch)
	Util.corner(swatchColor, 5)

	local function refreshRow()
		hexLabel.Text = Util.hex(color)
		swatchColor.BackgroundColor3 = color
		swatchColor.BackgroundTransparency = 1 - alpha
	end

	local function notify(fromUser: boolean, releasedNow: boolean)
		changed:Fire(color, alpha)
		if fromUser and (live or releasedNow) then
			Util.safeCall(callback, color, alpha)
		end
		if releasedNow then
			released:Fire(color, alpha)
		end
	end

	refreshRow()

	local function close()
		if closeActive then
			local callbackClose = closeActive
			closeActive = nil
			callbackClose()
		end
	end

	local function makeChecker(parentFrame: Instance, width: number, height: number, cell: number): Frame
		local holder = Util.frame({
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(width, height),
			ClipsDescendants = true,
		}, parentFrame)

		local columns = math.ceil(width / cell)
		local rows = math.ceil(height / cell)
		for y = 0, rows - 1 do
			for x = 0, columns - 1 do
				local tile = Util.frame({
					BackgroundColor3 = theme.Palette.Surface,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(x * cell, y * cell),
					Size = UDim2.fromOffset(cell, cell),
				}, holder)
				ctx.Paint(tile, "BackgroundColor3", if (x + y) % 2 == 0 then "SurfaceRaised" else "Hover")
			end
		end

		return holder
	end

	local function open()
		if disabled or popupOpen then
			return
		end

		close()
		popupBag:Clear()

		local contentHeight = if showAlpha then 290 else 272
		local popupFrame, closeFn = ctx.OpenPopup(owner, swatch, 232, contentHeight + 24, function()
			popupOpen = false
			closeActive = nil
			popupBag:Clear()
		end)

		popupOpen = true
		closeActive = closeFn
		local activeDrag: string? = nil

		local content = Util.frame({
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(208, contentHeight),
		}, popupFrame)

		local header = Base.text(ctx, content, "Color", {
			Font = theme.Fonts.Medium,
			Size = 12,
			ColorRole = "Text",
		})
		header.Position = UDim2.fromOffset(0, 0)
		header.Size = UDim2.new(1, 0, 0, 16)

		local readout = Base.text(ctx, content, "", {
			Font = theme.Fonts.Mono,
			Size = 10,
			ColorRole = "TextMuted",
			XAlign = Enum.TextXAlignment.Right,
		})
		readout.Position = UDim2.fromOffset(0, 0)
		readout.Size = UDim2.new(1, 0, 0, 16)

		local svY = 24
		local svSize = Vector2.new(208, 112)
		local svContainer = Util.frame({
			Name = "SaturationValue",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, svY),
			Size = UDim2.fromOffset(svSize.X, svSize.Y),
		}, content)

		local svSquare = Util.frame({
			BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ClipsDescendants = true,
		}, svContainer)
		Util.corner(svSquare, 6)

		local whiteOverlay = Util.frame({
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, svSquare)

		Util.create("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, whiteOverlay)

		local darkOverlay = Util.frame({
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, svSquare)

		Util.create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(0, 0, 0)),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0),
			}),
		}, darkOverlay)

		local svHit = Util.textButton({
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			AutoButtonColor = false,
			ZIndex = 4,
		}, svContainer)

		local svRing = Util.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(16, 16),
			ZIndex = 5,
		}, svContainer)
		Util.corner(svRing, 999)
		Util.create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(0, 0, 0),
			Thickness = 1,
			Transparency = 0.35,
		}, svRing)

		local svInner = Util.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(12, 12),
		}, svRing)
		Util.create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(1, 1, 1),
			Thickness = 2,
		}, svInner)
		Util.corner(svInner, 999)

		local hueY = svY + svSize.Y + 10
		local stripWidth = 208
		local hueContainer = Util.frame({
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, hueY),
			Size = UDim2.fromOffset(stripWidth, 16),
		}, content)

		local hueStrip = Util.frame({
			BackgroundColor3 = Color3.new(1, 0, 0),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 2),
			Size = UDim2.fromOffset(stripWidth, 12),
			ClipsDescendants = true,
		}, hueContainer)
		Util.corner(hueStrip, 999)

		Util.create("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
			}),
		}, hueStrip)

		local hueHit = Util.textButton({
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			AutoButtonColor = false,
			ZIndex = 4,
		}, hueContainer)

		local hueMarker = Util.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Position = UDim2.new(hue, 0, 0.5, 0),
			Size = UDim2.fromOffset(3, 16),
			ZIndex = 5,
		}, hueContainer)
		Util.corner(hueMarker, 2)
		Util.create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(0, 0, 0),
			Thickness = 1,
			Transparency = 0.4,
		}, hueMarker)

		local alphaY = hueY + 24
		local alphaContainer: Frame? = nil
		local alphaMarker: Frame? = nil
		local alphaFill: Frame? = nil
		local alphaHit: TextButton? = nil

		if showAlpha then
			alphaContainer = Util.frame({
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, alphaY),
				Size = UDim2.fromOffset(stripWidth, 16),
			}, content)

			local alphaChecker = makeChecker(alphaContainer, stripWidth, 10, 8)
			alphaChecker.Position = UDim2.fromOffset(0, 3)
			alphaChecker.ClipsDescendants = true
			Util.corner(alphaChecker, 999)

			alphaFill = Util.frame({
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, 3),
				Size = UDim2.fromOffset(stripWidth, 10),
				ClipsDescendants = true,
			}, alphaContainer)
			Util.corner(alphaFill, 999)

			Util.create("UIGradient", {
				Color = ColorSequence.new(color),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(1, 0),
				}),
			}, alphaFill)

			alphaHit = Util.textButton({
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				Text = "",
				AutoButtonColor = false,
				ZIndex = 4,
			}, alphaContainer)

			alphaMarker = Util.frame({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Position = UDim2.new(alpha, 0, 0.5, 0),
				Size = UDim2.fromOffset(3, 16),
				ZIndex = 5,
			}, alphaContainer)
			Util.corner(alphaMarker, 2)
			Util.create("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(0, 0, 0),
				Thickness = 1,
				Transparency = 0.4,
			}, alphaMarker)
		end

		local hexY = alphaY + (if showAlpha then 26 else 8)
		local hexBox = Util.textBox({
			Name = "Hex",
			BackgroundColor3 = ctx.Color("SurfaceRaised"),
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Font = theme.Fonts.Mono,
			PlaceholderText = "#00FAB4",
			PlaceholderColor3 = ctx.Color("TextFaint"),
			Position = UDim2.fromOffset(0, hexY),
			Size = UDim2.fromOffset(104, 28),
			Text = Util.hex(color),
			TextColor3 = ctx.Color("Text"),
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, content)
		Util.corner(hexBox, 4)
		Util.padding(hexBox, 9, 0)
		local hexStroke = Util.stroke(hexBox, 1)
		ctx.Paint(hexBox, "BackgroundColor3", "SurfaceRaised")
		ctx.Paint(hexBox, "TextColor3", "Text")
		ctx.Paint(hexBox, "PlaceholderColor3", "TextFaint")
		ctx.Paint(hexStroke, "Color", "Stroke")

		local alphaReadout = Base.text(ctx, content, "", {
			Font = theme.Fonts.Mono,
			Size = 10,
			ColorRole = "TextMuted",
			XAlign = Enum.TextXAlignment.Right,
		})
		alphaReadout.Position = UDim2.fromOffset(112, hexY)
		alphaReadout.Size = UDim2.fromOffset(96, 28)

		local previewY = hexY + 38
		local previewContainer = Util.frame({
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, previewY),
			Size = UDim2.fromOffset(208, 20),
		}, content)
		Util.corner(previewContainer, 4)

		local previewChecker = makeChecker(previewContainer, 208, 20, 5)
		previewChecker.Size = UDim2.fromScale(1, 1)
		Util.corner(previewChecker, 4)

		local previewFill = Util.frame({
			BackgroundColor3 = color,
			BackgroundTransparency = 1 - alpha,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, previewContainer)
		Util.corner(previewFill, 4)

		local previewStroke = Util.stroke(previewContainer, 1)
		ctx.Paint(previewStroke, "Color", "Stroke")

		local footer = Util.frame({
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, previewY + 30),
			Size = UDim2.fromOffset(208, 26),
		}, content)

		Util.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, footer)

		local function footerButton(text: string, primary: boolean, order: number): TextButton
			local button = Util.textButton({
				BackgroundColor3 = ctx.Color(if primary then "Accent" else "SurfaceRaised"),
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(62, 26),
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = order,
			}, footer)
			Util.corner(button, 4)
			ctx.Paint(button, "BackgroundColor3", if primary then "Accent" else "SurfaceRaised")
			local label = Base.text(ctx, button, text, {
				Font = theme.Fonts.Medium,
				Size = 11,
				ColorRole = if primary then "OnAccent" else "TextMuted",
				XAlign = Enum.TextXAlignment.Center,
			})
			label.Size = UDim2.fromScale(1, 1)
			return button
		end

		local resetButton = footerButton("Reset", false, 1)
		local doneButton = footerButton("Done", true, 2)

		local function refreshPicker()
			local h, s, v = color:ToHSV()
			hue = h
			saturation = s
			value = v
			svSquare.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
			svRing.Position = UDim2.fromScale(saturation, 1 - value)
			hueMarker.Position = UDim2.new(hue, 0, 0.5, 0)
			hexBox.Text = Util.hex(color)
			readout.Text = `{string.upper(Util.hex(color))}  ·  {math.round(alpha * 100)}%`
			alphaReadout.Text = `ALPHA {string.format("%.0f", alpha * 100)}%`
			previewFill.BackgroundColor3 = color
			previewFill.BackgroundTransparency = 1 - alpha
			if alphaFill then
				alphaFill.BackgroundColor3 = color
				local gradient = alphaFill:FindFirstChildOfClass("UIGradient")
				if gradient then
					gradient.Color = ColorSequence.new(color)
				end
			end
			if alphaMarker then
				alphaMarker.Position = UDim2.new(alpha, 0, 0.5, 0)
			end
			refreshRow()
		end

		refreshPicker()

		local function updateFromPointer(position: Vector2, final: boolean)
			if not activeDrag then
				return
			end

			if activeDrag == "sv" then
				local size = svContainer.AbsoluteSize
				local origin = svContainer.AbsolutePosition
				if size.X > 0 and size.Y > 0 then
					saturation = clamp01((position.X - origin.X) / size.X)
					value = 1 - clamp01((position.Y - origin.Y) / size.Y)
				end
			elseif activeDrag == "hue" then
				local size = hueContainer.AbsoluteSize
				local origin = hueContainer.AbsolutePosition
				if size.X > 0 then
					hue = clamp01((position.X - origin.X) / size.X)
				end
			elseif activeDrag == "alpha" and alphaContainer then
				local size = alphaContainer.AbsoluteSize
				local origin = alphaContainer.AbsolutePosition
				if size.X > 0 then
					alpha = clamp01((position.X - origin.X) / size.X)
				end
			end

			color = Color3.fromHSV(hue, saturation, value)
			refreshPicker()
			notify(true, final)
		end

		local function beginDrag(kind: string, input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			activeDrag = kind
			updateFromPointer(input.Position, false)
		end

		popupBag:Add(svHit.InputBegan:Connect(function(input)
			beginDrag("sv", input)
		end))
		popupBag:Add(hueHit.InputBegan:Connect(function(input)
			beginDrag("hue", input)
		end))
		if alphaHit then
			popupBag:Add(alphaHit.InputBegan:Connect(function(input)
				beginDrag("alpha", input)
			end))
		end

		popupBag:Add(UserInputService.InputChanged:Connect(function(input)
			if not activeDrag then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				updateFromPointer(input.Position, false)
			end
		end))

		popupBag:Add(UserInputService.InputEnded:Connect(function(input)
			if not activeDrag then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				activeDrag = nil
				notify(false, true)
			end
		end))

		popupBag:Add(hexBox.Focused:Connect(function()
			ctx.Paint(hexStroke, "Color", "Accent")
			hexStroke.Color = ctx.Color("Accent")
		end))

		popupBag:Add(hexBox.FocusLost:Connect(function()
			ctx.Paint(hexStroke, "Color", "Stroke")
			hexStroke.Color = ctx.Color("Stroke")
			local parsed = parseHex(hexBox.Text)
			if parsed then
				color = parsed
				hue, saturation, value = color:ToHSV()
				refreshPicker()
				notify(true, true)
			else
				hexBox.Text = Util.hex(color)
			end
		end))

		popupBag:Add(resetButton.Activated:Connect(function()
			color = initialColor
			alpha = clamp01(options.Alpha or 1)
			hue, saturation, value = color:ToHSV()
			refreshPicker()
			notify(true, true)
		end))

		popupBag:Add(doneButton.Activated:Connect(close))
	end

	bag:Add(swatch.Activated:Connect(function()
		if disabled then
			return
		end
		if popupOpen then
			close()
		else
			open()
		end
	end))

	bag:Add(swatch.MouseEnter:Connect(function()
		if disabled then
			return
		end
		ctx.Paint(swatchStroke, "Color", "Accent")
		swatchStroke.Color = ctx.Color("Accent")
	end))

	bag:Add(swatch.MouseLeave:Connect(function()
		if disabled then
			return
		end
		ctx.Paint(swatchStroke, "Color", "StrokeStrong")
		swatchStroke.Color = ctx.Color("StrokeStrong")
	end))

	local self = setmetatable({} :: any, ColorPicker) :: ColorPicker
	self.Instance = row
	self.Changed = changed
	self.Released = released

	function self:GetColor(): Color3
		return color
	end

	function self:GetAlpha(): number
		return alpha
	end

	function self:SetValue(nextColor: Color3, nextAlpha: number?, silent: boolean?)
		color = nextColor
		if nextAlpha ~= nil then
			alpha = clamp01(nextAlpha)
		end
		hue, saturation, value = color:ToHSV()
		refreshRow()
		if popupOpen then
			close()
		end
		changed:Fire(color, alpha)
		released:Fire(color, alpha)
		if not silent then
			Util.safeCall(callback, color, alpha)
		end
	end

	function self:SetDisabled(nextDisabled: boolean)
		if disabled == nextDisabled then
			return
		end
		disabled = nextDisabled
		swatch.Active = not disabled
		hexLabel.Visible = not disabled
		if disabled then
			close()
			swatchColor.BackgroundTransparency = 0.6
			ctx.Paint(swatchStroke, "Color", "Stroke")
			swatchStroke.Color = ctx.Color("Stroke")
			hexLabel.TextColor3 = ctx.Color("TextFaint")
		else
			refreshRow()
			ctx.Paint(swatchStroke, "Color", "StrokeStrong")
			swatchStroke.Color = ctx.Color("StrokeStrong")
			ctx.Paint(hexLabel, "TextColor3", "TextMuted")
			hexLabel.TextColor3 = ctx.Color("TextMuted")
		end
	end

	function self:SetVisible(visible: boolean)
		row.Visible = visible
	end

	function self:OnChanged(handler: (color: Color3, alpha: number) -> ()): Signal.Connection
		return changed:Connect(handler)
	end

	function self:OnReleased(handler: (color: Color3, alpha: number) -> ()): Signal.Connection
		return released:Connect(handler)
	end

	function self:Destroy()
		close()
		bag:Clear()
		popupBag:Clear()
		changed:DisconnectAll()
		released:DisconnectAll()
		row:Destroy()
	end

	row:SetAttribute("KaizaxComponent", "ColorPicker")
	ctx.Register(row, labelText)

	return self
end

return ColorPicker

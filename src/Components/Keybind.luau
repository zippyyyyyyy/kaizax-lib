--!strict

local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Parent.Util)
local Animation = require(script.Parent.Parent.Animation)
local Signal = require(script.Parent.Parent.Signal)
local Base = require(script.Parent.Base)

local UserInputService = game:GetService("UserInputService")

local Keybind = {}
Keybind.__index = Keybind

export type Options = {
	Text: string?,
	Default: Enum.KeyCode?,
	Mode: Types.KeybindMode?,
	ShowMode: boolean?,
	Disabled: boolean?,
	Callback: ((key: Enum.KeyCode?, mode: Types.KeybindMode) -> ())?,
}

export type Keybind = {
	Instance: Frame,
	Changed: Signal.Signal,
	GetKey: (self: Keybind) -> Enum.KeyCode?,
	SetKey: (self: Keybind, key: Enum.KeyCode?, silent: boolean?) -> (),
	GetMode: (self: Keybind) -> Types.KeybindMode,
	SetMode: (self: Keybind, mode: Types.KeybindMode, silent: boolean?) -> (),
	SetDisabled: (self: Keybind, disabled: boolean) -> (),
	SetVisible: (self: Keybind, visible: boolean) -> (),
	OnChanged: (self: Keybind, handler: (key: Enum.KeyCode?, mode: Types.KeybindMode) -> ()) -> Signal.Connection,
	Destroy: (self: Keybind) -> (),
}

local KEY_NAMES: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.LeftShift] = "Shift",
	[Enum.KeyCode.RightShift] = "R-Shift",
	[Enum.KeyCode.LeftControl] = "Ctrl",
	[Enum.KeyCode.RightControl] = "R-Ctrl",
	[Enum.KeyCode.LeftAlt] = "Alt",
	[Enum.KeyCode.RightAlt] = "R-Alt",
	[Enum.KeyCode.Return] = "Enter",
	[Enum.KeyCode.Backspace] = "Backspace",
	[Enum.KeyCode.CapsLock] = "Caps",
	[Enum.KeyCode.Up] = "Up",
	[Enum.KeyCode.Down] = "Down",
	[Enum.KeyCode.Left] = "Left",
	[Enum.KeyCode.Right] = "Right",
	[Enum.KeyCode.ButtonA] = "A",
	[Enum.KeyCode.ButtonB] = "B",
	[Enum.KeyCode.ButtonX] = "X",
	[Enum.KeyCode.ButtonY] = "Y",
	[Enum.KeyCode.ButtonL1] = "LB",
	[Enum.KeyCode.ButtonR1] = "RB",
	[Enum.KeyCode.ButtonL2] = "LT",
	[Enum.KeyCode.ButtonR2] = "RT",
	[Enum.KeyCode.ButtonStart] = "Start",
	[Enum.KeyCode.ButtonSelect] = "Select",
}

local function keyLabel(key: Enum.KeyCode?): string
	if not key then
		return "None"
	end
	return KEY_NAMES[key] or key.Name
end

local activeStop: (() -> ())? = nil

function Keybind.new(
	ctx: Types.UIContext,
	parent: Instance,
	options: Options
): Keybind
	local theme = ctx.GetTheme()
	local bag = Util.bag()
	local key: Enum.KeyCode? = options.Default
	local mode: Types.KeybindMode = options.Mode or "Toggle"
	local showMode = options.ShowMode == true
	local disabled = options.Disabled == true
	local listening = false
	local labelText = options.Text or "Keybind"
	local callback = options.Callback
	local listenConnection: RBXScriptConnection? = nil
	local changed = Signal.new()

	local row, _, rowLabel = Base.row(ctx, parent, labelText)
	if rowLabel then
		rowLabel.Size = UDim2.new(1, if showMode then -204 else -128, 1, 0)
	end

	local bindButton = Util.textButton({
		Name = "Bind",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(120, 32),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		Active = not disabled,
	}, row)

	Util.corner(bindButton, theme.Radius.Element)
	local bindStroke = Util.stroke(bindButton, 1)

	local bindLabel = Base.text(ctx, bindButton, keyLabel(key), {
		Font = theme.Fonts.Mono,
		Size = 12,
		ColorRole = if key then "Text" else "TextFaint",
		XAlign = Enum.TextXAlignment.Center,
	})
	bindLabel.Size = UDim2.fromScale(1, 1)

	local modeButton: TextButton? = nil
	local modeLabel: TextLabel? = nil

	if showMode then
		modeButton = Util.textButton({
			Name = "Mode",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -128, 0.5, 0),
			Size = UDim2.fromOffset(60, 32),
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Text = "",
			Active = not disabled,
		}, row)

		Util.corner(modeButton, theme.Radius.Element)
		Util.stroke(modeButton, 1)
		modeLabel = Base.text(ctx, modeButton, string.upper(mode), {
			Font = theme.Fonts.Medium,
			Size = 10,
			ColorRole = "TextMuted",
			XAlign = Enum.TextXAlignment.Center,
		})
		modeLabel.Size = UDim2.fromScale(1, 1)
		ctx.Paint(modeButton, "BackgroundColor3", "Surface")
		ctx.Paint(modeLabel, "TextColor3", "TextMuted")

		local modeStroke = modeButton:FindFirstChildOfClass("UIStroke")
		if modeStroke then
			ctx.Paint(modeStroke, "Color", "Stroke")
		end
	end

	local function apply(animate: boolean)
		local current = ctx.GetTheme()

		if disabled then
			ctx.Paint(bindButton, "BackgroundColor3", "Surface")
			bindButton.BackgroundColor3 = ctx.Color("Surface")
			bindButton.BackgroundTransparency = 0.35
			ctx.Paint(bindStroke, "Color", "Stroke")
			bindStroke.Transparency = 0.6
			ctx.Paint(bindLabel, "TextColor3", "TextFaint")
			bindLabel.TextColor3 = ctx.Color("TextFaint")
			if modeButton and modeLabel then
				ctx.Paint(modeButton, "BackgroundColor3", "Surface")
				modeButton.BackgroundColor3 = ctx.Color("Surface")
				modeButton.BackgroundTransparency = 0.35
				ctx.Paint(modeLabel, "TextColor3", "TextFaint")
				modeLabel.TextColor3 = ctx.Color("TextFaint")
			end
			return
		end

		local fillRole = if listening then "Accent" else "SurfaceRaised"
		local textRole = if listening then "OnAccent" else if key then "Text" else "TextFaint"
		local strokeRole = if listening then "Accent" else "Stroke"

		ctx.Paint(bindButton, "BackgroundColor3", fillRole)
		ctx.Paint(bindLabel, "TextColor3", textRole)
		ctx.Paint(bindStroke, "Color", strokeRole)
		bindButton.BackgroundTransparency = 0
		bindStroke.Transparency = if listening then 0.2 else 0
		bindLabel.Text = if listening then "Listening..." else keyLabel(key)

		if animate then
			Animation.play(bindButton, current.Motion.Fast, {
				BackgroundTransparency = 0,
				BackgroundColor3 = if listening then current.Palette.Accent else current.Palette.SurfaceRaised,
			}, { easing = "Quad" })
			Animation.play(bindStroke, current.Motion.Fast, {
				Transparency = if listening then 0.2 else 0,
				Color = ctx.Color(strokeRole),
			}, { easing = "Quad" })
		else
			bindButton.BackgroundColor3 = if listening then current.Palette.Accent else current.Palette.SurfaceRaised
		end

		bindButton.Active = not disabled
		bindLabel.TextColor3 = ctx.Color(textRole)

		if modeButton and modeLabel then
			modeButton.Active = not disabled
			ctx.Paint(modeButton, "BackgroundColor3", "Surface")
			ctx.Paint(modeLabel, "TextColor3", "TextMuted")
			modeLabel.Text = string.upper(mode)
			modeButton.BackgroundColor3 = ctx.Color("Surface")
			modeButton.BackgroundTransparency = 0
			modeLabel.TextColor3 = ctx.Color("TextMuted")
		end
	end

	local function stopListening()
		if listenConnection then
			listenConnection:Disconnect()
			listenConnection = nil
		end
		listening = false
		if activeStop == stopListening then
			activeStop = nil
		end
		apply(true)
	end

	local function emit(fromUser: boolean)
		changed:Fire(key, mode)
		if fromUser then
			Util.safeCall(callback, key, mode)
		end
	end

	local function setKey(nextKey: Enum.KeyCode?, fromUser: boolean)
		key = nextKey
		apply(true)
		emit(fromUser)
	end

	local function startListening()
		if disabled or listening then
			return
		end

		if activeStop and activeStop ~= stopListening then
			activeStop()
		end

		listening = true
		activeStop = stopListening
		apply(true)

		listenConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if not listening then
				return
			end
			if gameProcessed then
				return
			end

			if input.KeyCode == Enum.KeyCode.Escape then
				stopListening()
				return
			end

			if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
				stopListening()
				setKey(nil, true)
				return
			end

			local kind = input.UserInputType
			if kind == Enum.UserInputType.Keyboard
				or kind == Enum.UserInputType.Gamepad1
				or kind == Enum.UserInputType.Gamepad2
				or kind == Enum.UserInputType.Gamepad3
				or kind == Enum.UserInputType.Gamepad4
			then
				stopListening()
				setKey(input.KeyCode, true)
			end
		end)
	end

	apply(false)

	bag:Add(bindButton.Activated:Connect(function()
		if disabled then
			return
		end
		if listening then
			stopListening()
		else
			startListening()
		end
	end))

	bag:Add(bindButton.MouseEnter:Connect(function()
		if disabled or listening then
			return
		end
		local current = ctx.GetTheme()
		ctx.Paint(bindButton, "BackgroundColor3", "Hover")
		ctx.Paint(bindStroke, "Color", "StrokeStrong")
		Animation.play(bindButton, current.Motion.Fast, {
			BackgroundColor3 = ctx.Color("Hover"),
		}, { easing = "Quad" })
		Animation.play(bindStroke, current.Motion.Fast, {
			Color = ctx.Color("StrokeStrong"),
		}, { easing = "Quad" })
	end))

	bag:Add(bindButton.MouseLeave:Connect(function()
		if disabled or listening then
			return
		end
		apply(true)
	end))

	if modeButton then
		bag:Add(modeButton.Activated:Connect(function()
			if disabled then
				return
			end
			mode = if mode == "Hold" then "Toggle" else "Hold"
			apply(true)
			emit(true)
		end))

		bag:Add(modeButton.MouseEnter:Connect(function()
			if disabled then
				return
			end
			local current = ctx.GetTheme()
			ctx.Paint(modeButton, "BackgroundColor3", "Hover")
			Animation.play(modeButton, current.Motion.Fast, {
				BackgroundColor3 = ctx.Color("Hover"),
			}, { easing = "Quad" })
		end))

		bag:Add(modeButton.MouseLeave:Connect(function()
			if disabled then
				return
			end
			ctx.Paint(modeButton, "BackgroundColor3", "Surface")
			Animation.play(modeButton, ctx.GetTheme().Motion.Fast, {
				BackgroundColor3 = ctx.Color("Surface"),
			}, { easing = "Quad" })
		end))
	end

	local self = setmetatable({} :: any, Keybind) :: Keybind
	self.Instance = row
	self.Changed = changed

	function self:GetKey(): Enum.KeyCode?
		return key
	end

	function self:SetKey(nextKey: Enum.KeyCode?, silent: boolean?)
		key = nextKey
		apply(true)
		if not silent then
			emit(false)
		end
	end

	function self:GetMode(): Types.KeybindMode
		return mode
	end

	function self:SetMode(nextMode: Types.KeybindMode, silent: boolean?)
		mode = nextMode
		apply(true)
		if not silent then
			emit(false)
		end
	end

	function self:SetDisabled(nextDisabled: boolean)
		if disabled == nextDisabled then
			return
		end
		disabled = nextDisabled
		bindButton.Active = not disabled
		if modeButton then
			modeButton.Active = not disabled
		end
		if disabled then
			stopListening()
		end
		apply(true)
	end

	function self:SetVisible(visible: boolean)
		row.Visible = visible
	end

	function self:OnChanged(handler: (key: Enum.KeyCode?, mode: Types.KeybindMode) -> ()): Signal.Connection
		return changed:Connect(handler)
	end

	function self:Destroy()
		stopListening()
		bag:Clear()
		changed:DisconnectAll()
		row:Destroy()
	end

	row:SetAttribute("KaizaxComponent", "Keybind")
	ctx.Register(row, labelText)

	return self
end

return Keybind

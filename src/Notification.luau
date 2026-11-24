--!strict

local Types = require(script.Parent.Types)
local Util = require(script.Parent.Util)
local Animation = require(script.Parent.Animation)

local Notification = {}

export type Options = Types.NotificationOptions

export type Manager = {
	Push: (self: Manager, options: Options) -> (),
	SetTheme: (self: Manager, theme: Types.Theme) -> (),
	Destroy: (self: Manager) -> (),
}

local KIND_ROLE: { [string]: string } = {
	info = "Info",
	success = "Success",
	warning = "Warning",
	error = "Danger",
}

local TOAST_WIDTH = 300
local TOAST_HEIGHT = 84
local TOAST_GAP = 8
local MAX_TOASTS = 4

function Notification.new(
	getTheme: () -> Types.Theme,
	parent: Instance
): Manager
	local toasts: { any } = {}
	local gui = Util.create("ScreenGui", {
		Name = "KaizaxNotifications",
		DisplayOrder = 1000,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, parent) :: ScreenGui

	local host = Util.frame({
		Name = "Stack",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(TOAST_WIDTH, 400),
	}, gui)

	local manager = {} :: Manager

	local function layout(animate: boolean)
		local theme = getTheme()

		for index, toast in toasts do
			local target = UDim2.new(1, if toast.state == "enter" then TOAST_WIDTH + 24 else 0, 0, (index - 1) * (TOAST_HEIGHT + TOAST_GAP))
			if toast.state == "enter" then
				continue
			end
			if animate then
				Animation.play(toast.frame, theme.Motion.Fast, {
					Position = target,
				}, { easing = "Quad" })
			else
				toast.frame.Position = target
			end
		end
	end

	local function remove(toast: any)
		if toast.removed then
			return
		end
		toast.removed = true

		local index = table.find(toasts, toast)
		if index then
			table.remove(toasts, index)
		end

		layout(true)

		local theme = getTheme()
		local exitTarget = UDim2.new(1, TOAST_WIDTH + 40, 0, toast.frame.Position.Y.Offset)
		local tween = Animation.play(toast.frame, theme.Motion.Fast, {
			Position = exitTarget,
		}, { easing = "Quad", direction = "In" })

		if tween then
			tween.Completed:Once(function()
				toast.frame:Destroy()
			end)
		else
			toast.frame:Destroy()
		end
	end

	local function push(options: Options)
		local theme = getTheme()
		local kind = options.Kind or "info"
		local role = KIND_ROLE[kind] or "Info"
		local duration = options.Duration
		if duration == nil then
			duration = 4
		end

		if #toasts >= MAX_TOASTS then
			remove(toasts[#toasts])
		end

		local frame = Util.frame({
			Name = `Notification_{kind}`,
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = theme.Palette.SurfaceRaised,
			BorderSizePixel = 0,
			Position = UDim2.new(1, TOAST_WIDTH + 24, 0, 0),
			Size = UDim2.fromOffset(TOAST_WIDTH, TOAST_HEIGHT),
		}, host)
		Util.corner(frame, theme.Radius.Card)
		local stroke = Util.stroke(frame, 1)
		Util.paint(frame, "BackgroundColor3", "SurfaceRaised", theme)
		Util.paint(stroke, "Color", "Stroke", theme)

		local accent = Util.frame({
			Name = "Accent",
			BackgroundColor3 = theme.Palette[role],
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 10),
			Size = UDim2.new(0, 2, 1, -20),
		}, frame)
		Util.corner(accent, 1)
		Util.paint(accent, "BackgroundColor3", role, theme)

		local dot = Util.frame({
			Name = "Dot",
			BackgroundColor3 = theme.Palette[role],
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(14, 14),
			Size = UDim2.fromOffset(6, 6),
		}, frame)
		Util.corner(dot, 999)
		Util.paint(dot, "BackgroundColor3", role, theme)

		local message = options.Message or ""

		local title = Util.label({
			BackgroundTransparency = 1,
			Font = theme.Fonts.Bold,
			Size = UDim2.new(1, -62, 0, 20),
			Text = options.Title,
			TextColor3 = theme.Palette.Text,
			TextSize = 12.5,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, frame)
		title.Position = UDim2.fromOffset(27, if message == "" then 20 else 8)
		Util.paint(title, "TextColor3", "Text", theme)

		local messageLabel = Util.label({
			BackgroundTransparency = 1,
			Font = theme.Fonts.Regular,
			Position = UDim2.fromOffset(15, 30),
			Size = UDim2.new(1, -30, 0, 34),
			Text = message,
			TextColor3 = theme.Palette.TextMuted,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Visible = message ~= "",
		}, frame)
		Util.paint(messageLabel, "TextColor3", "TextMuted", theme)

		local dismissable = options.Dismissable ~= false
		if dismissable then
			local closeButton = Util.textButton({
				Name = "Dismiss",
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.new(1, -7, 0, 7),
				Size = UDim2.fromOffset(20, 20),
				Text = "",
				AutoButtonColor = false,
			}, frame)

			local barOne = Util.frame({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = theme.Palette.TextFaint,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Rotation = 45,
				Size = UDim2.fromOffset(8, 1),
			}, closeButton)
			Util.paint(barOne, "BackgroundColor3", "TextFaint", theme)

			local barTwo = Util.frame({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = theme.Palette.TextFaint,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Rotation = -45,
				Size = UDim2.fromOffset(8, 1),
			}, closeButton)
			Util.paint(barTwo, "BackgroundColor3", "TextFaint", theme)

			closeButton.Activated:Connect(function()
				remove(toast)
			end)
		end

		local progressTrack: Frame? = nil
		local progressFill: Frame? = nil

		if duration > 0 then
			progressTrack = Util.frame({
				Name = "ProgressTrack",
				BackgroundColor3 = theme.Palette.Stroke,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 14, 1, -8),
				Size = UDim2.new(1, -28, 0, 2),
			}, frame)
			Util.corner(progressTrack, 1)
			Util.paint(progressTrack, "BackgroundColor3", "Stroke", theme)

			progressFill = Util.frame({
				Name = "ProgressFill",
				BackgroundColor3 = theme.Palette[role],
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
			}, progressTrack)
			Util.corner(progressFill, 1)
			Util.paint(progressFill, "BackgroundColor3", role, theme)
		end

		local toast = {
			frame = frame,
			state = "enter",
			removed = false,
			hovering = false,
		}

		table.insert(toasts, 1, toast)
		layout(false)

		toast.state = "moving"
		Animation.play(frame, theme.Motion.Normal, {
			Position = UDim2.new(1, 0, 0, 0),
		}, { easing = "Quart", direction = "Out" })

		if duration > 0 and progressFill and progressTrack then
			local progressTween = Animation.play(progressFill, duration, {
				Size = UDim2.new(0, 0, 0, 2),
			}, { easing = "Linear" })

			frame.MouseEnter:Connect(function()
				toast.hovering = true
				if progressTween then
					progressTween:Pause()
				end
			end)

			frame.MouseLeave:Connect(function()
				toast.hovering = false
				if progressTween then
					progressTween:Play()
				end
			end)

			task.spawn(function()
				local remaining = duration
				while remaining > 0 and not toast.removed do
					local step = math.min(0.1, remaining)
					task.wait(step)
					if not toast.hovering then
						remaining -= step
					end
				end
				if not toast.removed then
					remove(toast)
				end
			end)
		end
	end

	function manager:Push(options: Options)
		push(options)
	end

	function manager:SetTheme(theme: Types.Theme)
		Util.applyTheme(gui, theme)
	end

	function manager:Destroy()
		for index = #toasts, 1, -1 do
			local toast = toasts[index]
			toast.removed = true
			toast.frame:Destroy()
		end
		table.clear(toasts)
		gui:Destroy()
	end

	return manager
end

return Notification

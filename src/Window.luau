--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Types = require(script.Parent.Types)
local Util = require(script.Parent.Util)
local Animation = require(script.Parent.Animation)
local Signal = require(script.Parent.Signal)
local Base = require(script.Parent.Components.Base)
local Search = require(script.Parent.Components.Search)
local Tab = require(script.Parent.Tab)

local Window = {}
Window.__index = Window

export type Options = {
	Title: string?,
	Subtitle: string?,
	Theme: Types.ThemeInput?,
	Size: Vector2?,
	Position: Vector2?,
	ToggleKey: (Enum.KeyCode | boolean)?,
	DisplayOrder: number?,
	Parent: Instance?,
	OnClose: (() -> ())?,
}

export type Window = {
	Instance: ScreenGui,
	Closed: Signal.Signal,
	CreateTab: (self: Window, options: any) -> any,
	SelectTab: (self: Window, target: any) -> (),
	GetTabs: (self: Window) -> { any },
	GetActiveTab: (self: Window) -> any,
	Notify: (self: Window, options: Types.NotificationOptions) -> (),
	SetTheme: (self: Window, input: Types.ThemeInput) -> Types.Theme,
	SetOpen: (self: Window, open: boolean) -> (),
	Toggle: (self: Window) -> (),
	IsOpen: (self: Window) -> boolean,
	SetMinimized: (self: Window, minimized: boolean) -> (),
	SetTitle: (self: Window, title: string) -> (),
	OnClosed: (self: Window, handler: () -> ()) -> Signal.Connection,
	_ApplyTheme: (self: Window, theme: Types.Theme) -> (),
	_OpenPopup: (self: Window, owner: any, anchor: GuiObject, width: number, height: number, onClose: (() -> ())?) -> (Frame, () -> ()),
	_ClosePopup: (self: Window, owner: any) -> (),
	Destroy: (self: Window) -> (),
}

local function inside(object: GuiObject, point: Vector2): boolean
	local position = object.AbsolutePosition
	local size = object.AbsoluteSize
	return point.X >= position.X and point.X <= position.X + size.X
		and point.Y >= position.Y and point.Y <= position.Y + size.Y
end

local function resolveParent(explicit: Instance?): Instance
	if explicit then
		return explicit
	end

	local player = Players.LocalPlayer
	if player then
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			return playerGui
		end
	end

	return game:GetService("CoreGui")
end

function Window.new(library: any, options: Options): Window
	local theme = library:_GetTheme()
	local bag = Util.bag()
	local popupBag = Util.bag()
	local tabs: { any } = {}
	local tabButtons: { [any]: { button: TextButton, label: TextLabel, order: number } } = {}
	local activeTab: any = nil
	local activePopup: any = nil
	local minimized = false
	local expandedSize: UDim2? = nil
	local closed = Signal.new()
	local toggleKey: Enum.KeyCode? = nil

	local self = setmetatable({} :: any, Window) :: Window

	if options.ToggleKey == nil then
		toggleKey = Enum.KeyCode.RightShift
	elseif options.ToggleKey ~= false then
		toggleKey = options.ToggleKey :: Enum.KeyCode
	end

	local width = if options.Size then options.Size.X else theme.Window.Width
	local height = if options.Size then options.Size.Y else theme.Window.Height

	local gui = Util.create("ScreenGui", {
		Name = "Kaizax",
		DisplayOrder = options.DisplayOrder or 100,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, resolveParent(options.Parent)) :: ScreenGui

	local shadowLayers: { { frame: Frame, scale: UIScale, grow: number, y: number, transparency: number } } = {}
	local shadowSpecs = {
		{ grow = 24, y = 10, transparency = 0.90, radius = theme.Radius.Window + 12 },
		{ grow = 16, y = 6, transparency = 0.82, radius = theme.Radius.Window + 8 },
		{ grow = 8, y = 2, transparency = 0.72, radius = theme.Radius.Window + 4 },
	}
	for index, spec in shadowSpecs do
		local layer = Util.frame({
			Name = `Shadow_{index}`,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = spec.transparency,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(-spec.grow / 2, -spec.grow / 2 + spec.y),
			Size = UDim2.fromOffset(width + spec.grow, height + spec.grow),
			ZIndex = 0,
		}, gui)
		Util.corner(layer, spec.radius)
		table.insert(shadowLayers, {
			frame = layer,
			scale = Util.create("UIScale", { Scale = 1 }, layer) :: UIScale,
			grow = spec.grow,
			y = spec.y,
			transparency = spec.transparency,
		})
	end

	local window = Util.frame({
		Name = "Window",
		BackgroundColor3 = theme.Palette.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(width, height),
		ZIndex = 1,
	}, gui)
	Util.corner(window, theme.Radius.Window)
	local windowStroke = Util.stroke(window, 1)
	Util.paint(window, "BackgroundColor3", "Background", theme)
	Util.paint(windowStroke, "Color", "Stroke", theme)

	local scale = Util.create("UIScale", { Scale = 1 }, window) :: UIScale

	local topBar = Util.frame({
		Name = "TopBar",
		BackgroundColor3 = theme.Palette.Surface,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, theme.Window.TopBar),
		ZIndex = 2,
	}, window)
	Util.paint(topBar, "BackgroundColor3", "Surface", theme)

	local topDivider = Util.frame({
		Name = "TopDivider",
		BackgroundColor3 = theme.Palette.Stroke,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, theme.Window.TopBar - 1),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 3,
	}, topBar)
	Util.paint(topDivider, "BackgroundColor3", "Stroke", theme)

	local sidebar = Util.frame({
		Name = "Sidebar",
		BackgroundColor3 = theme.Palette.Surface,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, theme.Window.TopBar),
		Size = UDim2.new(0, theme.Window.Sidebar, 1, -theme.Window.TopBar),
		ZIndex = 2,
	}, window)
	Util.paint(sidebar, "BackgroundColor3", "Surface", theme)

	local sidebarDivider = Util.frame({
		Name = "SidebarDivider",
		BackgroundColor3 = theme.Palette.Stroke,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -1, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
	}, sidebar)
	Util.paint(sidebarDivider, "BackgroundColor3", "Stroke", theme)

	local tabScroller = Util.scrollingFrame({
		Name = "Tabs",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 10),
		Size = UDim2.new(1, -16, 1, -64),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = theme.Palette.StrokeStrong,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
	}, sidebar)
	Util.list(tabScroller, 4)

	local tabRail = Util.frame({
		Name = "TabRail",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = tabScroller.Position,
		Size = tabScroller.Size,
		ZIndex = 3,
	}, sidebar)

	local activeIndicator = Util.frame({
		Name = "ActiveIndicator",
		BackgroundColor3 = theme.Palette.Accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 9),
		Size = UDim2.fromOffset(3, 18),
		Visible = false,
		ZIndex = 4,
	}, tabRail)
	Util.corner(activeIndicator, theme.Radius.Pill)
	Util.paint(activeIndicator, "BackgroundColor3", "Accent", theme)

	local sidebarFooter = Util.frame({
		Name = "Footer",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 48),
	}, sidebar)

	local footerLine = Util.frame({
		BackgroundColor3 = theme.Palette.Stroke,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 0, 1),
	}, sidebarFooter)
	Util.paint(footerLine, "BackgroundColor3", "Stroke", theme)

	local versionLabel = Util.label({
		BackgroundTransparency = 1,
		Font = theme.Fonts.Mono,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 14),
		Text = `Kaizax {library.Version}`,
		TextColor3 = theme.Palette.TextFaint,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, sidebarFooter)
	Util.paint(versionLabel, "TextColor3", "TextFaint", theme)

	local toggleHint = Util.label({
		BackgroundTransparency = 1,
		Font = theme.Fonts.Mono,
		Position = UDim2.fromOffset(12, 26),
		Size = UDim2.new(1, -24, 0, 14),
		Text = if toggleKey then `{toggleKey.Name} to toggle` else "",
		TextColor3 = theme.Palette.TextFaint,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Visible = toggleKey ~= nil,
	}, sidebarFooter)
	Util.paint(toggleHint, "TextColor3", "TextFaint", theme)

	local content = Util.frame({
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(theme.Window.Sidebar, theme.Window.TopBar),
		Size = UDim2.new(1, -theme.Window.Sidebar, 1, -theme.Window.TopBar),
		ZIndex = 2,
	}, window)

	local overlay = Util.frame({
		Name = "Overlay",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
	}, gui)

	local dragButton = Util.textButton({
		Name = "DragRegion",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, theme.Window.TopBar),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 2,
	}, topBar)

	local brandDot = Util.frame({
		Name = "BrandDot",
		BackgroundColor3 = theme.Palette.Accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(20, 23),
		Size = UDim2.fromOffset(10, 10),
		ZIndex = 3,
	}, topBar)
	Util.corner(brandDot, theme.Radius.Pill)
	Util.paint(brandDot, "BackgroundColor3", "Accent", theme)

	local titleLabel = Util.label({
		Name = "Title",
		BackgroundTransparency = 1,
		Font = theme.Fonts.Medium,
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(0.5, -56, 1, 0),
		Text = options.Title or "Kaizax",
		TextColor3 = theme.Palette.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 3,
	}, topBar)
	Util.paint(titleLabel, "TextColor3", "Text", theme)

	local search = Search.new({
		GetTheme = library._GetTheme,
		Color = function(role: string)
			return (library:_GetTheme().Palette :: any)[role]
		end,
		Paint = function(instance: Instance, property: string, role: string)
			Util.paint(instance, property, role, library:_GetTheme())
		end,
		Register = function() end,
		GetScale = function()
			return scale.Scale
		end,
	}, topBar, {
		Placeholder = "Search controls",
		Width = 220,
	})

	local searchFrame = search.Instance :: Frame
	searchFrame.AnchorPoint = Vector2.new(1, 0.5)
	searchFrame.Position = UDim2.new(1, -104, 0.5, 0)
	searchFrame.ZIndex = 4
	searchFrame.Visible = false

	local function makeControlButton(name: string, offset: number): TextButton
		local button = Util.textButton({
			Name = name,
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(1, offset, 0.5, 0),
			Size = UDim2.fromOffset(32, 32),
			Text = "",
			AutoButtonColor = false,
			ZIndex = 4,
		}, topBar)
		Util.corner(button, theme.Radius.Element)
		return button
	end

	local minimizeButton = makeControlButton("Minimize", -60)
	local closeButton = makeControlButton("Close", -20)

	local minimizeLine = Util.frame({
		Name = "MinimizeIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = theme.Palette.TextMuted,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 1.5),
	}, minimizeButton)
	Util.corner(minimizeLine, 1)
	Util.paint(minimizeLine, "BackgroundColor3", "TextMuted", theme)

	local restoreOutline = Util.frame({
		Name = "RestoreIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(9, 9),
		Visible = false,
	}, minimizeButton)
	local restoreStroke = Util.stroke(restoreOutline, 1.2)
	Util.paint(restoreStroke, "Color", "TextMuted", theme)

	local closeBars: { Frame } = {}
	for index, rotation in { 45, -45 } do
		local bar = Util.frame({
			Name = `CloseBar{index}`,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = theme.Palette.TextMuted,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = rotation,
			Size = UDim2.fromOffset(10, 1.5),
		}, closeButton)
		Util.corner(bar, 1)
		Util.paint(bar, "BackgroundColor3", "TextMuted", theme)
		table.insert(closeBars, bar)
	end

	for _, button in { minimizeButton, closeButton } do
		bag:Add(button.MouseEnter:Connect(function()
			button.BackgroundTransparency = 1
			button.BackgroundColor3 = library:_GetTheme().Palette.Hover
			Animation.play(button, library:_GetTheme().Motion.Fast, {
				BackgroundTransparency = 0,
			}, { easing = "Quad" })
		end))

		bag:Add(button.MouseLeave:Connect(function()
			Animation.play(button, library:_GetTheme().Motion.Fast, {
				BackgroundTransparency = 1,
			}, { easing = "Quad" })
		end))
	end

	local function updateSearchVisibility()
		searchFrame.Visible = not minimized and window.Size.X.Offset >= 760
	end

	local function indicatorY(order: number): number
		return (order - 1) * 40 + 9 - tabScroller.CanvasPosition.Y
	end

	local indicatorMove: Tween? = nil
	local indicatorPulse: Tween? = nil
	local indicatorGeneration = 0

	local function moveIndicator(target: any, animate: boolean)
		local entry = tabButtons[target]
		if not entry then
			return
		end

		indicatorGeneration += 1
		local generation = indicatorGeneration
		Animation.cancel(indicatorMove)
		Animation.cancel(indicatorPulse)

		local y = indicatorY(entry.order)
		if not animate or not activeIndicator.Visible then
			activeIndicator.Position = UDim2.fromOffset(0, y)
			activeIndicator.Size = UDim2.fromOffset(3, 18)
			activeIndicator.Visible = true
			return
		end

		local smooth = library:_GetTheme().Motion.Slow
		local pulse = Animation.duration(smooth / 2)
		indicatorMove = Animation.play(activeIndicator, smooth, {
			Position = UDim2.fromOffset(0, y),
		}, { easing = "Sine", direction = "InOut" })
		indicatorPulse = Animation.play(activeIndicator, pulse, {
			Size = UDim2.fromOffset(3, 22),
		}, { easing = "Sine", direction = "InOut" })

		task.delay(pulse, function()
			if generation ~= indicatorGeneration then
				return
			end
			indicatorPulse = Animation.play(activeIndicator, pulse, {
				Size = UDim2.fromOffset(3, 18),
			}, { easing = "Sine", direction = "InOut" })
		end)
	end

	bag:Add(tabScroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		moveIndicator(activeTab, false)
	end))

	local function paintTab(target: any, active: boolean, hovered: boolean)
		local entry = tabButtons[target]
		if not entry then
			return
		end

		local current = library:_GetTheme()
		local backgroundRole = if active then "SurfaceRaised" elseif hovered then "Hover" else "Surface"
		local labelRole = if active then "Text" elseif hovered then "Text" else "TextMuted"
		local labelX = if active then 14 else 16

		Util.paint(entry.button, "BackgroundColor3", backgroundRole, current)
		Util.paint(entry.label, "TextColor3", labelRole, current)

		Animation.play(entry.button, current.Motion.Normal, {
			BackgroundColor3 = (current.Palette :: any)[backgroundRole],
		}, { easing = "Sine", direction = "InOut" })
		Animation.play(entry.label, current.Motion.Normal, {
			TextColor3 = (current.Palette :: any)[labelRole],
			Position = UDim2.fromOffset(labelX, 0),
		}, { easing = "Sine", direction = "InOut" })
	end

	local function selectTab(target: any)
		if not target or activeTab == target then
			return
		end

		activeTab = target
		for _, tab in tabs do
			tab:SetVisible(tab == target)
		end
		for item in tabButtons do
			paintTab(item, item == target, false)
		end
		moveIndicator(target, true)

		local query = search:GetText()
		if query ~= "" then
			target:_ApplySearch(query)
		end
	end

	function self:CreateTab(optionsOrName: any): any
		local opts = if typeof(optionsOrName) == "string"
			then { Name = optionsOrName }
			else (optionsOrName or {})

		local tab = Tab.new({
			GetTheme = library._GetTheme,
			Color = function(role: string)
				return (library:_GetTheme().Palette :: any)[role]
			end,
			Paint = function(instance: Instance, property: string, role: string)
				Util.paint(instance, property, role, library:_GetTheme())
			end,
			Register = function() end,
			OpenPopup = function(...)
				return self:_OpenPopup(...)
			end,
			ClosePopup = function(owner: any)
				self:_ClosePopup(owner)
			end,
			GetScale = function()
				return scale.Scale
			end,
			Window = self,
			Notify = function(notificationOptions: Types.NotificationOptions)
				library:Notify(notificationOptions)
			end,
		}, content, {
			Name = opts.Name or "Tab",
			Description = opts.Description,
			SubTabs = opts.SubTabs,
		})

		table.insert(tabs, tab)
		local order = #tabs

		local button = Util.textButton({
			Name = `TabButton_{tab.Name}`,
			BackgroundColor3 = theme.Palette.Surface,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 36),
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = order,
		}, tabScroller)
		Util.corner(button, theme.Radius.Element)
		local tabScale = Base.pressable(button, bag)
		tabScale.Scale = 0.96
		Animation.play(tabScale, theme.Motion.Normal, {
			Scale = 1,
		}, { delay = 0.03 * #tabs, easing = "Quart" })

		local label = Util.label({
			BackgroundTransparency = 1,
			Font = theme.Fonts.Medium,
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.new(1, -28, 1, 0),
			Text = tab.Name,
			TextColor3 = theme.Palette.TextMuted,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, button)

		Util.paint(button, "BackgroundColor3", "Surface", theme)
		Util.paint(label, "TextColor3", "TextMuted", theme)

		tabButtons[tab] = {
			button = button,
			label = label,
			order = order,
		}

		bag:Add(button.MouseEnter:Connect(function()
			if activeTab ~= tab then
				paintTab(tab, false, true)
			end
		end))

		bag:Add(button.MouseLeave:Connect(function()
			paintTab(tab, activeTab == tab, false)
		end))

		bag:Add(button.Activated:Connect(function()
			selectTab(tab)
		end))

		if not activeTab then
			selectTab(tab)
		end

		return tab
	end

	function self:SelectTab(target: any)
		if typeof(target) == "number" then
			selectTab(tabs[target])
		elseif typeof(target) == "string" then
			for _, tab in tabs do
				if tab.Name == target then
					selectTab(tab)
					return
				end
			end
		else
			selectTab(target)
		end
	end

	function self:GetTabs(): { any }
		return tabs
	end

	function self:GetActiveTab(): any
		return activeTab
	end

	function self:Notify(notificationOptions: Types.NotificationOptions)
		library:Notify(notificationOptions)
	end

	function self:SetOpen(open: boolean)
		local wasOpen = gui.Enabled
		gui.Enabled = open

		if not open and wasOpen then
			self:_ClosePopup(nil)
			closed:Fire()
			Util.safeCall(options.OnClose)
		end
	end

	function self:Toggle()
		self:SetOpen(not gui.Enabled)
	end

	function self:IsOpen(): boolean
		return gui.Enabled
	end

	function self:SetMinimized(value: boolean)
		if minimized == value then
			return
		end

		minimized = value
		sidebar.Visible = not value
		content.Visible = not value
		topDivider.Visible = not value

		if value then
			expandedSize = window.Size
			Animation.play(window, library:_GetTheme().Motion.Normal, {
				Size = UDim2.new(window.Size.X.Scale, window.Size.X.Offset, 0, theme.Window.TopBar),
			}, { easing = "Quad" })
			minimizeLine.Visible = false
			restoreOutline.Visible = true
		else
			local targetSize = expandedSize or UDim2.fromOffset(width, height)
			Animation.play(window, library:_GetTheme().Motion.Normal, {
				Size = targetSize,
			}, { easing = "Quad" })
			minimizeLine.Visible = true
			restoreOutline.Visible = false
		end

		updateSearchVisibility()
		task.delay(library:_GetTheme().Motion.Normal, updateSearchVisibility)
	end

	function self:SetTitle(title: string)
		titleLabel.Text = title
	end

	function self:OnClosed(handler: () -> ()): Signal.Connection
		return closed:Connect(handler)
	end

	function self:SetTheme(input: Types.ThemeInput): Types.Theme
		return library:SetTheme(input)
	end

	function self:_ApplyTheme(nextTheme: Types.Theme)
		Util.applyTheme(gui, nextTheme)
		for _, layer in shadowLayers do
			layer.frame.BackgroundTransparency = layer.transparency
		end
		for item in tabButtons do
			paintTab(item, item == activeTab, false)
		end
	end

	local searchBag = Util.bag()
	searchBag:Add(search.OnChanged(function(query)
		if activeTab then
			activeTab:_ApplySearch(query)
		end
	end))

	local mouse = game:GetService("Players").LocalPlayer:GetMouse()
	local dragging = false
	local dragStartPointer = Vector2.new()
	local dragStartPosition = UDim2.new()

	local function moveToAbsolute(position: Vector2)
		local viewport = Util.viewportSize()
		local absoluteSize = window.AbsoluteSize
		local parentPosition = gui.AbsolutePosition
		local currentScale = scale.Scale

		local maxX = math.max(8, viewport.X - absoluteSize.X - 8)
		local maxY = math.max(8, viewport.Y - absoluteSize.Y - 8)
		local targetX = math.clamp(position.X, math.min(8, maxX), maxX)
		local targetY = math.clamp(position.Y, math.min(8, maxY), maxY)

		window.Position = UDim2.fromOffset(
			(targetX - parentPosition.X) / currentScale,
			(targetY - parentPosition.Y) / currentScale
		)
	end

	local function clampWindow()
		moveToAbsolute(window.AbsolutePosition)
	end

	local function beginDrag(pointer: Vector2 | Vector3)
		if dragging then
			return
		end
		dragging = true
		dragStartPointer = Vector2.new(pointer.X, pointer.Y)
		dragStartPosition = window.Position
	end

	local function endDrag()
		dragging = false
	end

	local function updateDrag(pointer: Vector2 | Vector3)
		if not dragging then
			return
		end

		local current = Vector2.new(pointer.X, pointer.Y)
		local delta = (current - dragStartPointer) / math.max(scale.Scale, 0.01)
		local targetAbs = gui.AbsolutePosition
			+ Vector2.new(dragStartPosition.X.Offset, dragStartPosition.Y.Offset) * scale.Scale
			+ delta * scale.Scale
		moveToAbsolute(targetAbs)
	end

	bag:Add(dragButton.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		beginDrag(input.Position)
	end))

	bag:Add(dragButton.MouseButton1Down:Connect(function()
		beginDrag(Vector2.new(mouse.X, mouse.Y))
	end))

	bag:Add(UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		updateDrag(input.Position)
	end))

	bag:Add(mouse.Move:Connect(function()
		updateDrag(Vector2.new(mouse.X, mouse.Y))
	end))

	bag:Add(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			endDrag()
		end
	end))

	bag:Add(mouse.Button1Up:Connect(endDrag))

	local resizing = false
	local resizeStartPointer = Vector2.new()
	local resizeStartSize = UDim2.new()
	local resizeGrip = Util.textButton({
		Name = "ResizeGrip",
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(18, 18),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 6,
	}, window)

	for index, rotation in { 45, 45 } do
		local gripLine = Util.frame({
			AnchorPoint = Vector2.new(1, 1),
			BackgroundColor3 = theme.Palette.TextFaint,
			BorderSizePixel = 0,
			Position = UDim2.new(1, -(if index == 1 then 5 else 10), 1, -(if index == 1 then 10 else 5)),
			Rotation = rotation,
			Size = UDim2.fromOffset(if index == 1 then 9 else 6, 1.5),
			BackgroundTransparency = if index == 1 then 0.2 else 0.45,
		}, resizeGrip)
		Util.corner(gripLine, 1)
		Util.paint(gripLine, "BackgroundColor3", "TextFaint", theme)
	end

	bag:Add(resizeGrip.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		resizing = true
		resizeStartPointer = input.Position
		resizeStartSize = window.Size
	end))

	bag:Add(UserInputService.InputChanged:Connect(function(input)
		if not resizing then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		local viewport = Util.viewportSize()
		local currentScale = scale.Scale
		local delta = (input.Position - resizeStartPointer) / math.max(currentScale, 0.01)
		local maxWidth = math.max(theme.Window.MinWidth, (viewport.X - 16) / currentScale)
		local maxHeight = math.max(theme.Window.MinHeight, (viewport.Y - 16) / currentScale)

		local nextWidth = math.clamp(resizeStartSize.X.Offset + delta.X, theme.Window.MinWidth, maxWidth)
		local nextHeight = math.clamp(resizeStartSize.Y.Offset + delta.Y, theme.Window.MinHeight, maxHeight)

		window.Size = UDim2.fromOffset(nextWidth, nextHeight)
		updateSearchVisibility()
		clampWindow()
	end))

	bag:Add(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			resizing = false
		end
	end))

	bag:Add(minimizeButton.Activated:Connect(function()
		self:SetMinimized(not minimized)
	end))

	bag:Add(closeButton.Activated:Connect(function()
		self:SetOpen(false)
	end))

	local function syncShadow()
		for _, layer in shadowLayers do
			layer.frame.Size = UDim2.new(
				window.Size.X.Scale,
				window.Size.X.Offset + layer.grow,
				window.Size.Y.Scale,
				window.Size.Y.Offset + layer.grow
			)
			layer.frame.Position = UDim2.new(
				window.Position.X.Scale,
				window.Position.X.Offset - layer.grow / 2,
				window.Position.Y.Scale,
				window.Position.Y.Offset - layer.grow / 2 + layer.y
			)
		end
	end

	bag:Add(window:GetPropertyChangedSignal("Size"):Connect(syncShadow))
	bag:Add(window:GetPropertyChangedSignal("Position"):Connect(syncShadow))

	local function applyScale()
		local viewport = Util.viewportSize()
		local nextScale = math.clamp(math.min(
			(viewport.X - 24) / math.max(window.Size.X.Offset, 1),
			(viewport.Y - 24) / math.max(window.Size.Y.Offset, 1),
			1
		), 0.35, 1)

		scale.Scale = nextScale
		for _, layer in shadowLayers do
			layer.scale.Scale = nextScale
		end
		updateSearchVisibility()
		return nextScale
	end

	bag:Add(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		applyScale()
		clampWindow()
		self:_ClosePopup(nil)
	end))

	function self:_OpenPopup(owner: any, anchor: GuiObject, popupWidth: number, popupHeight: number, onClose: (() -> ())?)
		self:_ClosePopup(nil)

		local popupFrame = Util.frame({
			Name = "Popup",
			BackgroundColor3 = library:_GetTheme().Palette.SurfaceRaised,
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(popupWidth, popupHeight),
			ZIndex = 60,
		}, overlay)
		Util.corner(popupFrame, library:_GetTheme().Radius.Card)
		local popupStroke = Util.stroke(popupFrame, 1)
		Util.paint(popupFrame, "BackgroundColor3", "SurfaceRaised", library:_GetTheme())
		Util.paint(popupStroke, "Color", "Stroke", library:_GetTheme())

		local popupScale = Util.create("UIScale", {
			Scale = scale.Scale * 0.97,
		}, popupFrame) :: UIScale
		Animation.play(popupScale, library:_GetTheme().Motion.Fast, {
			Scale = scale.Scale,
		}, { easing = "Quart", direction = "Out" })
		Animation.play(popupFrame, library:_GetTheme().Motion.Fast, {
			BackgroundTransparency = 0,
		}, { easing = "Quad" })

		local viewport = Util.viewportSize()
		local anchorPosition = anchor.AbsolutePosition
		local anchorSize = anchor.AbsoluteSize
		local renderedWidth = popupWidth * scale.Scale
		local renderedHeight = popupHeight * scale.Scale
		local overlayPosition = overlay.AbsolutePosition

		local x = anchorPosition.X + anchorSize.X - renderedWidth
		local y = anchorPosition.Y + anchorSize.Y + 6

		if y + renderedHeight > viewport.Y - 8 then
			y = anchorPosition.Y - renderedHeight - 6
		end

		x = math.clamp(x, 8, math.max(8, viewport.X - renderedWidth - 8))
		y = math.clamp(y, 8, math.max(8, viewport.Y - renderedHeight - 8))

		popupFrame.Position = UDim2.fromOffset(x - overlayPosition.X, y - overlayPosition.Y)

		local closedNow = false

		local function closeThis()
			if closedNow then
				return
			end
			closedNow = true
			popupBag:Clear()
			if activePopup and activePopup.frame == popupFrame then
				activePopup = nil
			end
			popupFrame:Destroy()
			if onClose then
				Util.safeCall(onClose)
			end
		end

		activePopup = {
			owner = owner,
			frame = popupFrame,
			anchor = anchor,
			close = closeThis,
		}

		popupBag:Add(UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			if inside(popupFrame, input.Position) or inside(anchor, input.Position) then
				return
			end
			self:_ClosePopup(nil)
		end))

		popupBag:Add(UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.Escape then
				self:_ClosePopup(nil)
			end
		end))

		return popupFrame, function()
			self:_ClosePopup(owner)
		end
	end

	function self:_ClosePopup(owner: any)
		if not activePopup then
			return
		end
		if owner ~= nil and activePopup.owner ~= owner then
			return
		end

		local closeFn = activePopup.close
		activePopup = nil
		closeFn()
	end

	function self:_GetParent(): Instance
		return gui.Parent or resolveParent(nil)
	end

	function self:Destroy()
		self:_ClosePopup(nil)
		closed:DisconnectAll()
		bag:Clear()
		search:Destroy()
		searchBag:Clear()

		for _, tab in tabs do
			tab:Destroy()
		end
		table.clear(tabs)
		table.clear(tabButtons)

		gui:Destroy()
		library:_RemoveWindow(self)
	end

	-- Keyboard toggling and search focus.
	bag:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		local focusedBox = UserInputService:GetFocusedTextBox()
		if focusedBox then
			if input.KeyCode == Enum.KeyCode.Escape then
				focusedBox:ReleaseFocus()
			end
			return
		end

		if toggleKey and input.KeyCode == toggleKey then
			self:Toggle()
			return
		end

		if input.KeyCode == Enum.KeyCode.F
			and (input:IsKeyDown(Enum.KeyCode.LeftControl) or input:IsKeyDown(Enum.KeyCode.RightControl))
			and gui.Enabled
		then
			if not minimized then
				search:Focus()
			end
		end
	end))

	window.Size = UDim2.fromOffset(width, height)
	topBar.Size = UDim2.new(1, 0, 0, theme.Window.TopBar)
	sidebar.Size = UDim2.new(0, theme.Window.Sidebar, 1, -theme.Window.TopBar)
	content.Position = UDim2.fromOffset(theme.Window.Sidebar, theme.Window.TopBar)
	content.Size = UDim2.new(1, -theme.Window.Sidebar, 1, -theme.Window.TopBar)

	local initialScale = applyScale()
	syncShadow()

	local viewport = Util.viewportSize()
	window.Position = UDim2.fromOffset(
		(viewport.X / scale.Scale - width) / 2,
		(viewport.Y / scale.Scale - height) / 2
	)
	clampWindow()
	updateSearchVisibility()

	if options.Position then
		moveToAbsolute(options.Position)
	end

	local subtitle: TextLabel? = nil
	if options.Subtitle and options.Subtitle ~= "" then
		subtitle = Util.label({
			BackgroundTransparency = 1,
			Font = theme.Fonts.Mono,
			Position = UDim2.new(0, 40, 0, 35),
			Size = UDim2.new(0.5, -56, 0, 16),
			Text = options.Subtitle,
			TextColor3 = theme.Palette.TextMuted,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 3,
		}, topBar)
		Util.paint(subtitle, "TextColor3", "TextMuted", theme)
		titleLabel.Position = UDim2.fromOffset(40, 9)
		titleLabel.Size = UDim2.new(0.5, -56, 0, 22)
	end

	local entranceVeil = Util.frame({
		Name = "EntranceVeil",
		BackgroundColor3 = theme.Palette.Background,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
	}, window)
	Util.paint(entranceVeil, "BackgroundColor3", "Background", theme)

	scale.Scale = initialScale * 0.985
	Animation.play(scale, theme.Motion.Slow, {
		Scale = initialScale,
	}, { easing = "Quart" })
	Animation.play(entranceVeil, theme.Motion.Normal, {
		BackgroundTransparency = 1,
	}, { easing = "Quad" })
	task.delay(Animation.duration(theme.Motion.Normal) + 0.05, function()
		if entranceVeil.Parent then
			entranceVeil:Destroy()
		end
	end)

	brandDot.BackgroundTransparency = 1
	titleLabel.TextTransparency = 1
	if subtitle then
		subtitle.TextTransparency = 1
	end
	Animation.play(brandDot, theme.Motion.Fast, {
		BackgroundTransparency = 0,
	}, { delay = 0.02, easing = "Quad" })
	Animation.play(titleLabel, theme.Motion.Normal, {
		TextTransparency = 0,
	}, { delay = 0.05, easing = "Quad" })
	if subtitle then
		Animation.play(subtitle, theme.Motion.Normal, {
			TextTransparency = 0,
		}, { delay = 0.09, easing = "Quad" })
	end

	self.Instance = gui
	self.Closed = closed
	library:_AddWindow(self)

	return self
end

return Window

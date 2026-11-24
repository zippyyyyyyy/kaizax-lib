--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Types = require(script.Parent.Types)
local Util = require(script.Parent.Util)
local Animation = require(script.Parent.Animation)
local Signal = require(script.Parent.Signal)
local Button = require(script.Parent.Components.Button)
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
	Introduced: Signal.Signal,
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
	local tabButtons: { [any]: { button: TextButton, hover: Frame, label: TextLabel, order: number, finalPosition: UDim2 } } = {}
	local activeTab: any = nil
	local activePopup: any = nil
	local Introduced = Signal.new()
	local minimized = false
	local openRequested = true
	local introGeneration = 0
	local initializing = true
	local basePosition: UDim2? = nil
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
	local footerHeight = theme.Window.Footer
	local cornerRadius = theme.Radius.Window

	local gui = Util.create("ScreenGui", {
		Name = "Kaizax",
		DisplayOrder = options.DisplayOrder or 100,
		Enabled = false,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, resolveParent(options.Parent)) :: ScreenGui

	local windowShadow = Util.frame({
		Name = "WindowShadow",
		BackgroundColor3 = theme.Palette.Background,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromOffset(width, height),
		ZIndex = 0,
	}, gui)
	Util.corner(windowShadow, cornerRadius)
	Util.paint(windowShadow, "BackgroundColor3", "Background", theme)
	local shadowTransparency = windowShadow.BackgroundTransparency

	local window = Util.frame({
		Name = "Window",
		BackgroundColor3 = theme.Palette.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(width, height),
		ZIndex = 1,
	}, gui)
	Util.corner(window, cornerRadius)
	local windowStroke = Util.stroke(window, 1)
	Util.paint(window, "BackgroundColor3", "Background", theme)
	Util.paint(windowStroke, "Color", "Stroke", theme)
	Util.gradient(window, "PanelShade", 90, theme)

	local function syncWindowShadow()
		windowShadow.Position = window.Position + UDim2.fromOffset(0, 6)
		windowShadow.Size = window.Size
	end
	bag:Add(window:GetPropertyChangedSignal("Position"):Connect(syncWindowShadow))
	bag:Add(window:GetPropertyChangedSignal("Size"):Connect(syncWindowShadow))

	local scale = Util.create("UIScale", { Scale = 1 }, window) :: UIScale
	local introScale = Util.create("UIScale", { Scale = 1 }, window) :: UIScale

	local topSurface = Util.frame({
		Name = "TopSurface",
		BackgroundColor3 = theme.Palette.Surface,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, theme.Window.TopBar),
		ZIndex = 2,
	}, window)
	Util.corner(topSurface, cornerRadius)
	Util.paint(topSurface, "BackgroundColor3", "Surface", theme)
	Util.gradient(topSurface, "TopShade", 0, theme)

	local function cornerFiller(
		name: string,
		parent: Instance,
		position: UDim2,
		role: string,
		gradientKind: string?
	): Frame
		local filler = Util.frame({
			Name = name,
			BackgroundColor3 = (theme.Palette :: any)[role],
			BorderSizePixel = 0,
			Position = position,
			Size = UDim2.fromOffset(cornerRadius, cornerRadius),
			ZIndex = 2,
		}, parent)
		Util.paint(filler, "BackgroundColor3", role, theme)
		if gradientKind then
			Util.gradient(filler, gradientKind, 0, theme)
		end
		return filler
	end

	cornerFiller("TopFillLeft", topSurface, UDim2.fromOffset(0, theme.Window.TopBar - cornerRadius), "Surface", "TopStart")
	cornerFiller("TopFillRight", topSurface, UDim2.new(1, -cornerRadius, 1, -cornerRadius), "Surface", "TopEnd")

	local sideSurface = Util.frame({
		Name = "SideSurface",
		BackgroundColor3 = theme.Palette.Surface,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, theme.Window.TopBar),
		Size = UDim2.new(0, theme.Window.Sidebar, 1, -theme.Window.TopBar),
		ZIndex = 2,
	}, window)
	Util.corner(sideSurface, cornerRadius)
	Util.paint(sideSurface, "BackgroundColor3", "Surface", theme)
	Util.gradient(sideSurface, "PanelShade", 90, theme)

	cornerFiller("SideFillTop", sideSurface, UDim2.fromOffset(theme.Window.Sidebar - cornerRadius, 0), "Surface", "PanelStart")
	cornerFiller("SideFillBottom", sideSurface, UDim2.new(1, -cornerRadius, 1, -cornerRadius), "Surface", "PanelEnd")

	local windowCornerFill = cornerFiller(
		"WindowCornerFill",
		window,
		UDim2.new(1, -cornerRadius, 1, -cornerRadius),
		"Background",
		"PanelEnd"
	)
	windowCornerFill.ZIndex = 10

	local topBar = Util.frame({
		Name = "TopBar",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, theme.Window.TopBar),
		ZIndex = 3,
	}, window)

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
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, theme.Window.TopBar),
		Size = UDim2.new(0, theme.Window.Sidebar, 1, -theme.Window.TopBar),
		ZIndex = 3,
	}, window)

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
		Size = UDim2.new(1, -24, 1, -(footerHeight + 16)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = theme.Palette.StrokeStrong,
		ScrollBarImageTransparency = 0.15,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		ZIndex = 4,
	}, sidebar)
	Util.paint(tabScroller, "ScrollBarImageColor3", "StrokeStrong", theme)

	local tabRail = Util.frame({
		Name = "TabRail",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = tabScroller.Position,
		Size = tabScroller.Size,
		ZIndex = 5,
	}, sidebar)

	local activeIndicator = Util.frame({
		Name = "ActiveIndicator",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 36),
		Visible = false,
		ZIndex = 5,
	}, tabRail)

	local indicatorSurface = Util.frame({
		Name = "Surface",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = theme.Palette.SurfaceRaised,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 36),
		ZIndex = 5,
	}, activeIndicator)
	Util.corner(indicatorSurface, theme.Radius.Element)
	Util.gradient(indicatorSurface, "PillShade", 0, theme)
	Util.paint(indicatorSurface, "BackgroundColor3", "SurfaceRaised", theme)

	local indicatorBar = Util.frame({
		Name = "AccentBar",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = theme.Palette.Accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(6, 18),
		Size = UDim2.fromOffset(3, 24),
		ZIndex = 6,
	}, indicatorSurface)
	Util.corner(indicatorBar, theme.Radius.Pill)
	Util.paint(indicatorBar, "BackgroundColor3", "Accent", theme)
	Util.gradient(indicatorBar, "AccentBar", 90, theme)

	local sidebarFooter = Util.frame({
		Name = "Footer",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, footerHeight),
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
		Position = UDim2.fromOffset(28, 10),
		Size = UDim2.new(1, -56, 0, 14),
		Text = `Kaizax {library.Version}`,
		TextColor3 = theme.Palette.TextFaint,
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, sidebarFooter)
	Util.paint(versionLabel, "TextColor3", "TextFaint", theme)

	local toggleHint = Util.label({
		BackgroundTransparency = 1,
		Font = theme.Fonts.Mono,
		Position = UDim2.fromOffset(28, 26),
		Size = UDim2.new(1, -56, 0, 14),
		Text = if toggleKey then `{toggleKey.Name} to toggle` else "",
		TextColor3 = theme.Palette.TextFaint,
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
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
		Position = UDim2.fromOffset(8, 23),
		Size = UDim2.fromOffset(10, 10),
		ZIndex = 3,
	}, topBar)
	Util.corner(brandDot, theme.Radius.Pill)
	Util.paint(brandDot, "BackgroundColor3", "Accent", theme)
	local brandDotScale = Util.create("UIScale", { Scale = 1 }, brandDot) :: UIScale

	local titleLabel = Util.label({
		Name = "Title",
		BackgroundTransparency = 1,
		Font = theme.Fonts.Medium,
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(0.5, -44, 1, 0),
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
		return (order - 1) * 40 - tabScroller.CanvasPosition.Y
	end

	local indicatorGeneration = 0

	local function moveIndicator(target: any, animate: boolean)
		local entry = tabButtons[target]
		if not entry then
			return
		end

		indicatorGeneration += 1
		local generation = indicatorGeneration
		Animation.stopTagged(activeIndicator, "KaizaxIndicator")

		local y = math.floor(indicatorY(entry.order) + 0.5)
		if not animate or not activeIndicator.Visible then
			activeIndicator.Position = UDim2.fromOffset(0, y)
			activeIndicator.Size = UDim2.new(1, 0, 0, 36)
			indicatorSurface.Size = UDim2.new(1, 0, 0, 36)
			indicatorBar.Size = UDim2.fromOffset(3, 24)
			activeIndicator.Visible = true
			return
		end

		local motion = Animation.MOTION.Indicator
		local half = Animation.duration(motion.Duration / 2)
		Animation.play(activeIndicator, motion.Duration, {
			Position = UDim2.fromOffset(0, y),
		}, { easing = motion.Easing, direction = motion.Direction, tag = "KaizaxIndicator" })
		Animation.play(indicatorSurface, half, {
			Size = UDim2.new(1, 0, 0, 40),
		}, { easing = "Quad", direction = "Out", tag = "KaizaxIndicator" })

		task.delay(half, function()
			if generation == indicatorGeneration and activeIndicator.Parent then
				Animation.play(indicatorSurface, half, {
					Size = UDim2.new(1, 0, 0, 36),
				}, { easing = "Quad", direction = "InOut", tag = "KaizaxIndicator" })
			end
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
		local labelRole = if active then "Text" elseif hovered then "Text" else "TextMuted"
		local hoverTransparency = if active then 1 elseif hovered then 0.45 else 1

		Util.paint(entry.hover, "BackgroundColor3", "Hover")
		Util.paint(entry.label, "TextColor3", labelRole)

		Animation.play(entry.hover, Animation.MOTION.Hover.Duration, {
			BackgroundColor3 = current.Palette.Hover,
			BackgroundTransparency = hoverTransparency,
		}, {
			easing = Animation.MOTION.Hover.Easing,
			direction = Animation.MOTION.Hover.Direction,
			tag = "KaizaxTabPaint",
		})
		Animation.play(entry.label, Animation.MOTION.Label.Duration, {
			TextColor3 = (current.Palette :: any)[labelRole],
		}, {
			easing = Animation.MOTION.Label.Easing,
			direction = Animation.MOTION.Label.Direction,
			tag = "KaizaxTabPaint",
		})
	end

	local function selectTab(target: any)
		if not target or activeTab == target then
			return
		end

		if activeTab then
			activeTab:SetVisible(false)
		end
		activeTab = target
		if initializing then
			target:PlayIntro(false)
		else
			target:SetVisible(true)
		end
		for item in tabButtons do
			paintTab(item, item == target, false)
		end
		tabScroller.CanvasPosition = Vector2.new(0, 0)
		for _, subtab in target:GetSubTabs() do
			subtab.Instance.CanvasPosition = Vector2.new(0, 0)
		end
		moveIndicator(target, true)

		local query = search:GetText()
		if query ~= "" then
			target:_ApplySearch(query)
		end
	end

	local function restoreIntroVisuals()
		Animation.stopTagged(window, "KaizaxIntro")
		Animation.stop(windowShadow, "BackgroundTransparency")
		Animation.stop(introScale)
		Animation.stop(brandDotScale)
		introScale.Scale = 1
		brandDotScale.Scale = 1
		windowShadow.BackgroundTransparency = shadowTransparency
		if basePosition then
			window.Position = basePosition
		end
		Animation.fade(window, 1, { Duration = 0, Tag = "KaizaxIntro" })
		for _, entry in tabButtons do
			entry.button.Position = entry.finalPosition
		end
		if activeTab then
			moveIndicator(activeTab, false)
		end
	end

	local function playIntro()
		introGeneration += 1
		local generation = introGeneration
		local finalPosition = basePosition or window.Position
		finalPosition = UDim2.fromOffset(
			math.floor(finalPosition.X.Offset),
			math.floor(finalPosition.Y.Offset)
		)
		basePosition = finalPosition
		gui.Enabled = true
		restoreIntroVisuals()

		if not Animation.introEnabled() then
			window.Position = UDim2.fromOffset(
				math.floor(finalPosition.X.Offset),
				math.floor(finalPosition.Y.Offset)
			)
			introScale.Scale = 1
			if activeTab then
				activeTab:PlayIntro(false)
			end
			Introduced:Fire()
			return
		end

		windowShadow.BackgroundTransparency = 1
		window.Position = UDim2.fromOffset(
			math.floor(finalPosition.X.Offset),
			math.floor(finalPosition.Y.Offset + 16)
		)
		introScale.Scale = 0.96

		Animation.fade(window, 0, { Duration = 0, IncludeDescendants = false, Tag = "KaizaxIntro" })
		Animation.fade(windowStroke, 0, { Duration = 0, Tag = "KaizaxIntro" })
		for _, surface in { topSurface, sideSurface, windowCornerFill } do
			Animation.fade(surface, 0, { Duration = 0, IncludeDescendants = false, Tag = "KaizaxIntro" })
		end
		Animation.fade(topBar, 0, { Duration = 0, Tag = "KaizaxIntro" })
		Animation.fade(sidebar, 0, { Duration = 0, IncludeDescendants = false, Tag = "KaizaxIntro" })
		Animation.fade(content, 0, { Duration = 0, IncludeDescendants = false, Tag = "KaizaxIntro" })
		activeIndicator.Visible = false

		for _, entry in tabButtons do
			entry.button.Position = UDim2.fromOffset(entry.finalPosition.X.Offset - 12, entry.finalPosition.Y.Offset)
			Animation.fade(entry.button, 0, { Duration = 0, Tag = "KaizaxIntro" })
		end

		local enter = Animation.MOTION.Enter
		Animation.play(windowShadow, 0.4, {
			BackgroundTransparency = shadowTransparency,
		}, { easing = "Quad", direction = "Out", tag = "KaizaxIntro" })

		task.delay(0.05, function()
			if generation ~= introGeneration or not gui.Enabled then
				return
			end
			Animation.fade(window, 1, {
				Duration = enter.Duration,
				Easing = enter.Easing,
				Direction = enter.Direction,
				IncludeDescendants = false,
				Tag = "KaizaxIntro",
			})
			Animation.fade(windowStroke, 1, {
				Duration = enter.Duration,
				Easing = enter.Easing,
				Direction = enter.Direction,
				Tag = "KaizaxIntro",
			})
			for _, surface in { topSurface, sideSurface, windowCornerFill } do
				Animation.fade(surface, 1, {
					Duration = enter.Duration,
					Easing = enter.Easing,
					Direction = enter.Direction,
					IncludeDescendants = false,
					Tag = "KaizaxIntro",
				})
			end
			Animation.play(window, enter.Duration, {
				Position = finalPosition,
			}, { easing = enter.Easing, direction = enter.Direction, tag = "KaizaxIntro" })
			Animation.play(introScale, enter.Duration, {
				Scale = 1,
			}, { easing = enter.Easing, direction = enter.Direction, tag = "KaizaxIntro" })
		end)

		task.delay(0.1, function()
			if generation ~= introGeneration or not gui.Enabled then
				return
			end
			Animation.fade(topBar, 1, {
				Duration = 0.34,
				Easing = enter.Easing,
				Direction = enter.Direction,
				Tag = "KaizaxIntro",
			})
			brandDotScale.Scale = 1.18
			Animation.play(brandDotScale, 0.22, {
				Scale = 1,
			}, { easing = "Quad", direction = "Out", tag = "KaizaxIntro" })
		end)

		task.delay(0.16, function()
			if generation ~= introGeneration or not gui.Enabled then
				return
			end
			for _, descendant in content:GetDescendants() do
				if descendant:IsA("TextButton")
					and descendant:GetAttribute("KaizaxButtonVariant") == "Primary"
				then
					local button = Button.Get(descendant)
					if button then
						button:Flash()
					end
				end
			end
		end)

		for _, entry in tabButtons do
			local delay = 0.14 + (entry.order - 1) * Animation.MOTION.Stagger
			Animation.play(entry.button, enter.Duration, {
				Position = entry.finalPosition,
			}, { easing = enter.Easing, direction = enter.Direction, delay = delay, tag = "KaizaxIntro" })
			Animation.fade(entry.button, 1, {
				Duration = 0.3,
				Easing = enter.Easing,
				Direction = enter.Direction,
				Delay = delay,
				Tag = "KaizaxIntro",
			})
		end

		local indicatorDelay = 0.14 + (#tabs * Animation.MOTION.Stagger) + 0.04
		task.delay(indicatorDelay, function()
			if generation ~= introGeneration or not gui.Enabled or not activeTab then
				return
			end
			local entry = tabButtons[activeTab]
			if not entry then
				return
			end
			local pulse = Animation.MOTION.Indicator
			activeIndicator.Visible = true
			activeIndicator.Position = UDim2.fromOffset(0, math.floor(indicatorY(entry.order) + 0.5))
			indicatorSurface.Size = UDim2.new(1, 0, 0, 0)
			indicatorBar.Size = UDim2.fromOffset(3, 0)
			Animation.play(indicatorSurface, pulse.Duration, {
				Size = UDim2.new(1, 0, 0, 36),
			}, { easing = pulse.Easing, direction = pulse.Direction, tag = "KaizaxIntro" })
			Animation.play(indicatorBar, pulse.Duration, {
				Size = UDim2.fromOffset(3, 24),
			}, { easing = pulse.Easing, direction = pulse.Direction, tag = "KaizaxIntro" })
		end)

		task.delay(0.2, function()
			if generation == introGeneration and gui.Enabled and activeTab then
				activeTab:PlayIntro(true)
			end
		end)

		local dots: { GuiObject } = {}
		for _, descendant in content:GetDescendants() do
			if descendant:IsA("GuiObject") and descendant:GetAttribute("KaizaxStatusDot") then
				dots[#dots + 1] = descendant
			end
		end
		for index, dot in dots do
			if index > 3 then
				break
			end
			local dotScale = dot:FindFirstChildOfClass("UIScale")
			if not dotScale then
				dotScale = Util.create("UIScale", { Scale = 1 }, dot) :: UIScale
			end
			dotScale.Scale = 0.4
			Animation.play(dotScale, 0.22, {
				Scale = 1,
			}, {
				easing = "Back",
				direction = "Out",
				delay = 0.48 + (index - 1) * Animation.MOTION.Stagger,
				tag = "KaizaxIntro",
			})
		end

		task.delay(0.54, function()
			if generation == introGeneration and gui.Enabled then
				Introduced:Fire()
			end
		end)

		task.delay(0.92, function()
			if generation == introGeneration and gui.Enabled then
				window.Position = finalPosition
				restoreIntroVisuals()
			end
		end)
	end

	local function playClose()
		introGeneration += 1
		local generation = introGeneration
		Animation.stopTagged(window, "KaizaxIntro")

		if not Animation.enabled() or Animation.reducedMotion() then
			gui.Enabled = false
			restoreIntroVisuals()
			return
		end

		local exit = Animation.MOTION.Exit
		Animation.fade(window, 0, {
			Duration = exit.Duration,
			Easing = exit.Easing,
			Direction = exit.Direction,
			Tag = "KaizaxIntro",
		})
		Animation.play(introScale, exit.Duration, {
			Scale = 0.98,
		}, { easing = exit.Easing, direction = exit.Direction, tag = "KaizaxIntro" })

		task.delay(exit.Duration + 0.02, function()
			if generation == introGeneration and not openRequested then
				gui.Enabled = false
				restoreIntroVisuals()
			end
		end)
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

		local finalPosition = UDim2.fromOffset(0, (order - 1) * 40)
		local button = Util.textButton({
			Name = `TabButton_{tab.Name}`,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = finalPosition,
			Size = UDim2.new(1, 0, 0, 36),
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = order,
			ZIndex = 5,
		}, tabScroller)

		local hover = Util.frame({
			Name = "HoverFill",
			BackgroundColor3 = theme.Palette.Hover,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
		}, button)
		Util.corner(hover, theme.Radius.Element)
		Util.paint(hover, "BackgroundColor3", "Hover", theme)

		local label = Util.label({
			BackgroundTransparency = 1,
			Font = theme.Fonts.Medium,
			Position = UDim2.fromOffset(21, 0),
			Size = UDim2.new(1, -33, 1, 0),
			Text = tab.Name,
			TextColor3 = theme.Palette.TextMuted,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 7,
		}, button)
		Util.paint(label, "TextColor3", "TextMuted", theme)

		tabButtons[tab] = {
			button = button,
			hover = hover,
			label = label,
			order = order,
			finalPosition = finalPosition,
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
		if open == openRequested then
			return
		end
		openRequested = open

		if open then
			if initializing then
				gui.Enabled = true
				return
			end
			playIntro()
			return
		end

		gui.Enabled = true
		self:_ClosePopup(nil)
		closed:Fire()
		Util.safeCall(options.OnClose)
		playClose()
	end

	function self:Toggle()
		self:SetOpen(not openRequested)
	end

	function self:IsOpen(): boolean
		return openRequested
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
		for item in tabButtons do
			paintTab(item, item == activeTab, false)
		end
	end

	local searchBag = Util.bag()
	searchBag:Add(search:OnChanged(function(query)
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
			(math.floor(targetX + 0.5) - parentPosition.X) / currentScale,
			(math.floor(targetY + 0.5) - parentPosition.Y) / currentScale
		)
		basePosition = window.Position
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
		Position = UDim2.new(1, -8, 1, -8),
		Size = UDim2.fromOffset(12, 12),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 20,
	}, window)

	local gripPixels: { Frame } = {}
	for index, offset in { 4, 7, 10 } do
		local pixel = Util.frame({
			Name = `Pixel{index}`,
			BackgroundColor3 = theme.Palette.TextFaint,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(offset, offset - 2),
			Size = UDim2.fromOffset(2, 2),
			ZIndex = 21,
		}, resizeGrip)
		gripPixels[#gripPixels + 1] = pixel
	end

	local function paintGrip(role: string, animate: boolean)
		local current = library:_GetTheme()
		local color = (current.Palette :: any)[role]
		for _, pixel in gripPixels do
			if animate then
				Util.paint(pixel, "BackgroundColor3", role)
				Animation.play(pixel, Animation.MOTION.Hover.Duration, {
					BackgroundColor3 = color,
				}, {
					easing = Animation.MOTION.Hover.Easing,
					direction = Animation.MOTION.Hover.Direction,
				})
			else
				Util.paint(pixel, "BackgroundColor3", role, current)
				pixel.BackgroundColor3 = color
			end
		end
	end

	paintGrip("TextFaint", false)
	bag:Add(resizeGrip.MouseEnter:Connect(function()
		paintGrip("TextMuted", true)
	end))
	bag:Add(resizeGrip.MouseLeave:Connect(function()
		paintGrip("TextFaint", true)
	end))

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

		local nextWidth = math.floor(math.clamp(resizeStartSize.X.Offset + delta.X, theme.Window.MinWidth, maxWidth) + 0.5)
		local nextHeight = math.floor(math.clamp(resizeStartSize.Y.Offset + delta.Y, theme.Window.MinHeight, maxHeight) + 0.5)

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

	local function applyScale()
		local viewport = Util.viewportSize()
		local nextScale = math.clamp(math.min(
			(viewport.X - 24) / math.max(window.Size.X.Offset, 1),
			(viewport.Y - 24) / math.max(window.Size.Y.Offset, 1),
			1
		), 0.35, 1)

		scale.Scale = nextScale
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

	applyScale()

	local viewport = Util.viewportSize()
	moveToAbsolute(Vector2.new(
		(viewport.X - window.AbsoluteSize.X) / 2,
		(viewport.Y - window.AbsoluteSize.Y) / 2
	))
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
			Position = UDim2.fromOffset(28, 31),
			Size = UDim2.new(0.5, -44, 0, 14),
			Text = options.Subtitle,
			TextColor3 = theme.Palette.TextMuted,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 3,
		}, topBar)
		Util.paint(subtitle, "TextColor3", "TextMuted", theme)
		brandDot.Position = UDim2.fromOffset(8, 14)
		titleLabel.Position = UDim2.fromOffset(28, 10)
		titleLabel.Size = UDim2.new(0.5, -44, 0, 18)
	end

	task.defer(function()
		if initializing then
			initializing = false
			playIntro()
		end
	end)

	self.Instance = gui
	self.Closed = closed
	self.Introduced = Introduced
	library:_AddWindow(self)

	return self
end

return Window

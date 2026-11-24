--!strict

local Types = require(script.Parent.Types)
local Util = require(script.Parent.Util)
local Animation = require(script.Parent.Animation)
local Base = require(script.Parent.Components.Base)
local SubTab = require(script.Parent.SubTab)

local Tab = {}
Tab.__index = Tab

local GUTTER = 20

export type Options = {
	Name: string,
	Description: string?,
	SubTabs: { { Name: string, Columns: number? } }?,
}

export type Tab = {
	Instance: Frame,
	Name: string,
	CreateSection: (self: Tab, options: any) -> any,
	CreateSubTab: (self: Tab, name: string, columns: number?) -> any,
	SelectSubTab: (self: Tab, target: any) -> (),
	GetSubTabs: (self: Tab) -> { any },
	SetVisible: (self: Tab, visible: boolean) -> (),
	PlayIntro: (self: Tab, animate: boolean?) -> (),
	StopTransition: (self: Tab) -> (),
	Destroy: (self: Tab) -> (),
}

type ButtonEntry = {
	button: TextButton,
	label: TextLabel,
	underline: Frame,
}

function Tab.new(
	ctx: Types.UIContext,
	parent: Instance,
	options: Options
): Tab
	local theme = ctx.GetTheme()
	local titleText = options.Name
	local description = options.Description or ""
	local subtabs: { any } = {}
	local buttons: { [any]: ButtonEntry } = {}
	local current: any = nil

	local root = Util.frame({
		Name = `Tab_{titleText}`,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, parent)
	root.Visible = false

	local header = Util.frame({
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, theme.Window.PageHeader),
	}, root)

	local title = Base.text(ctx, header, titleText, {
		Font = theme.Fonts.Medium,
		Size = 28,
		ColorRole = "Text",
	})
	title.Position = UDim2.fromOffset(GUTTER, 16)
	title.Size = UDim2.new(0.56, -GUTTER, 0, 34)

	local subtitle = Base.text(ctx, header, description, {
		Font = theme.Fonts.Medium,
		Size = 14,
		ColorRole = "TextMuted",
		Truncate = false,
	})
	subtitle.Position = UDim2.fromOffset(GUTTER, 57)
	subtitle.Size = UDim2.new(0.56, -GUTTER, 0, 24)
	subtitle.Visible = description ~= ""

	local bar = Util.frame({
		Name = "SubTabBar",
		AnchorPoint = Vector2.new(1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = theme.Palette.Surface,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -GUTTER, 0, 24),
		Size = UDim2.fromOffset(0, 36),
		Visible = false,
	}, header)
	Util.corner(bar, theme.Radius.Element)
	local barStroke = Util.stroke(bar, 1)
	ctx.Paint(bar, "BackgroundColor3", "Surface")
	ctx.Paint(barStroke, "Color", "Stroke")
	Util.padding(bar, 4, 4)

	local barLayout = Util.list(bar, 2, Enum.FillDirection.Horizontal)
	barLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local divider = Util.frame({
		Name = "Divider",
		BackgroundColor3 = theme.Palette.Stroke,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, theme.Window.PageHeader),
		Size = UDim2.new(1, 0, 0, 1),
	}, root)
	ctx.Paint(divider, "BackgroundColor3", "Stroke")

	local body = Util.frame({
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, theme.Window.PageHeader + 1),
		Size = UDim2.new(1, 0, 1, -(theme.Window.PageHeader + 1)),
	}, root)

	local empty = Base.text(ctx, body, "No controls match your search.", {
		Font = theme.Fonts.Regular,
		Size = 12,
		ColorRole = "TextFaint",
		Wrapped = true,
		XAlign = Enum.TextXAlignment.Center,
		YAlign = Enum.TextYAlignment.Center,
	})
	empty.Size = UDim2.fromScale(1, 1)
	empty.Visible = false

	local tab = setmetatable({} :: any, Tab) :: Tab
	tab.Instance = root
	tab.Name = titleText

	local function paintButton(subtab: any, active: boolean, hovered: boolean)
		local entry = buttons[subtab]
		if not entry then
			return
		end

		local current = ctx.GetTheme()
		local backgroundRole = if active then "SurfaceRaised" elseif hovered then "Hover" else "Surface"
		local labelRole = if active then "Text" elseif hovered then "Text" else "TextMuted"

		ctx.Paint(entry.button, "BackgroundColor3", backgroundRole)
		ctx.Paint(entry.label, "TextColor3", labelRole)
		entry.underline.Visible = active
		entry.underline.BackgroundTransparency = if active then 0.4 else 1
		Animation.play(entry.underline, current.Motion.Fast, {
			BackgroundTransparency = if active then 0 else 1,
		}, { easing = "Quad" })
		Animation.play(entry.button, current.Motion.Fast, {
			BackgroundColor3 = ctx.Color(backgroundRole),
			BackgroundTransparency = if active or hovered then 0 else 1,
		}, { easing = "Quad" })
		Animation.play(entry.label, current.Motion.Fast, {
			TextColor3 = ctx.Color(labelRole),
		}, { easing = "Quad" })
	end

	local function selectSubTab(target: any)
		if current == target then
			return
		end
		current = target
		for item in buttons do
			paintButton(item, item == target, false)
		end
		for _, subtab in subtabs do
			subtab:_SetActive(subtab == target)
		end
	end

	local function addSubTab(name: string, columns: number?): any
		local subtab = SubTab.new(ctx, body, name, columns or 1, function(chosen)
			selectSubTab(chosen)
		end, true)

		table.insert(subtabs, subtab)

		local button = Util.textButton({
			Name = `SubTabButton_{name}`,
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = theme.Palette.Surface,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = #subtabs,
			Size = UDim2.fromOffset(0, 28),
			Text = "",
			AutoButtonColor = false,
		}, bar)
		Util.corner(button, theme.Radius.Element)

		local label = Base.text(ctx, button, name, {
			Font = theme.Fonts.Medium,
			Size = 13,
			ColorRole = "TextMuted",
			XAlign = Enum.TextXAlignment.Center,
		})
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.new(0, 0, 1, 0)
		Util.padding(button, 12, 0)

		local underline = Util.frame({
			Name = "Underline",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = theme.Palette.Accent,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, -16, 0, 2),
			Visible = false,
		}, button)
		Util.corner(underline, 1)
		ctx.Paint(underline, "BackgroundColor3", "Accent")

		buttons[subtab] = {
			button = button,
			label = label,
			underline = underline,
		}

		button.MouseEnter:Connect(function()
			paintButton(subtab, current == subtab, true)
		end)
		button.MouseLeave:Connect(function()
			paintButton(subtab, current == subtab, false)
		end)
		button.Activated:Connect(function()
			selectSubTab(subtab)
		end)

		return subtab
	end

	local provided = options.SubTabs or {}
	if #provided == 0 then
		addSubTab("General", 1)
	else
		for _, entry in provided do
			addSubTab(entry.Name, entry.Columns)
		end
	end

	if #subtabs > 1 then
		bar.Visible = true
	end

	if subtabs[1] then
		selectSubTab(subtabs[1])
	end

	function tab:CreateSection(value: any): any
		return current:CreateSection(value)
	end

	function tab:CreateSubTab(name: string, columns: number?): any
		for _, subtab in subtabs do
			if subtab:GetName() == name then
				selectSubTab(subtab)
				return subtab
			end
		end

		local subtab = addSubTab(name, columns)
		bar.Visible = true
		selectSubTab(subtab)
		return subtab
	end

	function tab:SelectSubTab(target: any)
		if typeof(target) == "string" then
			for _, subtab in subtabs do
				if subtab:GetName() == target then
					selectSubTab(subtab)
					return
				end
			end
		elseif buttons[target] then
			selectSubTab(target)
		end
	end

	function tab:GetSubTabs(): { any }
		return subtabs
	end

	local finalBodyPosition = UDim2.fromOffset(0, theme.Window.PageHeader + 1)
	local finalTitlePosition = UDim2.fromOffset(GUTTER, 16)
	local finalSubtitlePosition = UDim2.fromOffset(GUTTER, 58)
	local transitionId = 0
	local transitionState = "idle"
	local sectionFinals: { [Instance]: UDim2 } = {}

	local function stopPageMotion()
		transitionId += 1
		Animation.stopTagged(root, "KaizaxPage")
	end

	local function pageSections(): { any }
		local result: { any } = {}
		if current then
			for _, section in current:_GetSections() do
				if section.Instance and section.Instance.Visible and #result < 5 then
					result[#result + 1] = section
				end
			end
		end
		return result
	end

	local function restorePage()
		body.Position = finalBodyPosition
		title.Position = finalTitlePosition
		subtitle.Position = finalSubtitlePosition
		Animation.fade(header, 1, { Duration = 0, Tag = "KaizaxPage" })
		Animation.fade(divider, 1, { Duration = 0, Tag = "KaizaxPage" })
		Animation.fade(empty, 1, { Duration = 0, Tag = "KaizaxPage" })
		for _, section in pageSections() do
			Animation.fade(section.Instance, 1, { Duration = 0, Tag = "KaizaxPage" })
		end
	end

	local function playEnter(animate: boolean?)
		local continueEnter = transitionState == "enter"
		stopPageMotion()
		local generation = transitionId
		transitionState = "enter"
		root.Visible = true

		local sections = pageSections()
		if not animate or not Animation.enabled() or Animation.reducedMotion() then
			restorePage()
			transitionState = "idle"
			return
		end

		local enter = Animation.MOTION.Enter
		if not continueEnter then
			body.Position = UDim2.fromOffset(0, finalBodyPosition.Y.Offset + 12)
			title.Position = UDim2.fromOffset(finalTitlePosition.X.Offset - 6, finalTitlePosition.Y.Offset)
			subtitle.Position = UDim2.fromOffset(finalSubtitlePosition.X.Offset - 6, finalSubtitlePosition.Y.Offset)
			Animation.fade(header, 0, { Duration = 0, Tag = "KaizaxPage" })
			Animation.fade(divider, 0, { Duration = 0, Tag = "KaizaxPage" })
			Animation.fade(empty, 0, { Duration = 0, Tag = "KaizaxPage" })
			for _, section in sections do
				Animation.fade(section.Instance, 0, { Duration = 0, Tag = "KaizaxPage" })
			end
		end

		Animation.fade(header, 1, {
			Duration = enter.Duration,
			Easing = enter.Easing,
			Direction = enter.Direction,
			Tag = "KaizaxPage",
		})
		Animation.fade(divider, 1, {
			Duration = enter.Duration,
			Easing = enter.Easing,
			Direction = enter.Direction,
			Tag = "KaizaxPage",
		})
		Animation.fade(empty, 1, {
			Duration = enter.Duration,
			Easing = enter.Easing,
			Direction = enter.Direction,
			Tag = "KaizaxPage",
		})

		Animation.play(title, enter.Duration, {
			Position = finalTitlePosition,
		}, { easing = enter.Easing, direction = enter.Direction, tag = "KaizaxPage" })
		Animation.play(subtitle, enter.Duration, {
			Position = finalSubtitlePosition,
		}, { easing = enter.Easing, direction = enter.Direction, tag = "KaizaxPage" })
		Animation.play(body, enter.Duration, {
			Position = finalBodyPosition,
		}, { easing = enter.Easing, direction = enter.Direction, tag = "KaizaxPage" })

		for index, section in sections do
			local finalPosition = sectionFinals[section.Instance] or Animation.integer(section.Instance.Position)
			sectionFinals[section.Instance] = finalPosition
			local startPosition = UDim2.new(
				finalPosition.X.Scale,
				finalPosition.X.Offset,
				finalPosition.Y.Scale,
				finalPosition.Y.Offset + 8
			)
			if not continueEnter then
				section.Instance.Position = startPosition
			end
			local delay = (index - 1) * Animation.MOTION.Stagger
			Animation.fade(section.Instance, 1, {
				Duration = enter.Duration,
				Easing = enter.Easing,
				Direction = enter.Direction,
				Delay = delay,
				Tag = "KaizaxPage",
			})
			Animation.play(section.Instance, enter.Duration, {
				Position = finalPosition,
			}, {
				easing = enter.Easing,
				direction = enter.Direction,
				delay = delay,
				tag = "KaizaxPage",
			})
			task.delay(enter.Duration + delay + 0.02, function()
				if generation == transitionId and section.Instance.Parent then
					section.Instance.Position = finalPosition
				end
			end)
		end

		task.delay(enter.Duration + (#sections * Animation.MOTION.Stagger) + 0.03, function()
			if generation == transitionId then
				restorePage()
				transitionState = "idle"
			end
		end)
	end

	local function playExit(animate: boolean?)
		stopPageMotion()
		local generation = transitionId
		if not root.Visible then
			restorePage()
			return
		end

		if not animate or not Animation.enabled() or Animation.reducedMotion() then
			root.Visible = false
			restorePage()
			transitionState = "idle"
			return
		end

		transitionState = "exit"
		local exit = Animation.MOTION.Exit
		local sections = pageSections()

		Animation.fade(header, 0, {
			Duration = exit.Duration,
			Easing = exit.Easing,
			Direction = exit.Direction,
			Tag = "KaizaxPage",
		})
		Animation.fade(divider, 0, {
			Duration = exit.Duration,
			Easing = exit.Easing,
			Direction = exit.Direction,
			Tag = "KaizaxPage",
		})
		Animation.fade(empty, 0, {
			Duration = exit.Duration,
			Easing = exit.Easing,
			Direction = exit.Direction,
			Tag = "KaizaxPage",
		})
		for _, section in sections do
			Animation.fade(section.Instance, 0, {
				Duration = exit.Duration,
				Easing = exit.Easing,
				Direction = exit.Direction,
				Tag = "KaizaxPage",
			})
		end
		Animation.play(body, exit.Duration, {
			Position = UDim2.fromOffset(0, finalBodyPosition.Y.Offset + 8),
		}, { easing = exit.Easing, direction = exit.Direction, tag = "KaizaxPage" })

		task.delay(exit.Duration + 0.02, function()
			if generation == transitionId then
				root.Visible = false
				restorePage()
				transitionState = "idle"
			end
		end)
	end

	function tab:SetVisible(visible: boolean)
		if visible then
			playEnter(true)
		else
			playExit(true)
		end
	end

	function tab:PlayIntro(animate: boolean?)
		playEnter(animate)
	end

	function tab:StopTransition()
		stopPageMotion()
		transitionState = "idle"
	end

	function tab:_ApplySearch(query: string): boolean
		local trimmed = string.gsub(query or "", "^%s*(.-)%s*$", "%1")
		local lowered = string.lower(trimmed)
		local firstMatch: any = nil
		local anyMatch = false

		for _, subtab in subtabs do
			local count = subtab:_ApplySearch(lowered)
			local matches = lowered == "" or count > 0
			local entry = buttons[subtab]

			if entry then
				entry.button.Visible = matches
			end

			if matches then
				anyMatch = true
				if not firstMatch then
					firstMatch = subtab
				end
			end
		end

		if lowered == "" then
			empty.Visible = false
			if current then
				current:_SetActive(true)
			end
			return true
		end

		if not anyMatch then
			empty.Text = `No controls match "{trimmed}".`
			empty.Visible = true
			for _, subtab in subtabs do
				subtab:_SetActive(false)
			end
			return false
		end

		empty.Visible = false
		if not current or current:_GetMatchCount() == 0 then
			selectSubTab(firstMatch)
		else
			current:_SetActive(true)
		end
		return true
	end

	function tab:_GetRoot(): Frame
		return root
	end

	function tab:Destroy()
		for _, subtab in subtabs do
			subtab:Destroy()
		end
		table.clear(subtabs)
		table.clear(buttons)
		root:Destroy()
	end

	return tab
end

return Tab

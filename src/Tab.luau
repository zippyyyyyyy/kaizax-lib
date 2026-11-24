--!strict

local Types = require(script.Parent.Types)
local Util = require(script.Parent.Util)
local Animation = require(script.Parent.Animation)
local Base = require(script.Parent.Components.Base)
local SubTab = require(script.Parent.SubTab)

local Tab = {}
Tab.__index = Tab

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
	title.Position = UDim2.fromOffset(24, 16)
	title.Size = UDim2.new(0.56, -24, 0, 34)

	local subtitle = Base.text(ctx, header, description, {
		Font = theme.Fonts.Regular,
		Size = 13,
		ColorRole = "TextMuted",
	})
	subtitle.Position = UDim2.fromOffset(24, 58)
	subtitle.Size = UDim2.new(0.56, -24, 0, 20)
	subtitle.Visible = description ~= ""

	local bar = Util.frame({
		Name = "SubTabBar",
		AnchorPoint = Vector2.new(1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = theme.Palette.Surface,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -24, 0, 24),
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
		Util.corner(button, 5)

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

	function tab:SetVisible(visible: boolean)
		if root.Visible == visible then
			return
		end
		root.Visible = visible
		if not visible then
			return
		end

		local motion = ctx.GetTheme().Motion.Slow
		local bodyY = theme.Window.PageHeader + 1
		body.Position = UDim2.fromOffset(0, bodyY + 10)
		title.Position = UDim2.fromOffset(20, 16)
		subtitle.Position = UDim2.fromOffset(20, 58)
		title.TextTransparency = 0.45
		subtitle.TextTransparency = 0.45

		Animation.play(body, motion, {
			Position = UDim2.fromOffset(0, bodyY),
		}, { easing = "Sine", direction = "InOut" })
		Animation.play(title, motion, {
			Position = UDim2.fromOffset(24, 16),
			TextTransparency = 0,
		}, { easing = "Sine", direction = "InOut" })
		Animation.play(subtitle, motion, {
			Position = UDim2.fromOffset(24, 58),
			TextTransparency = 0,
		}, { easing = "Sine", direction = "InOut" })
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

--!strict

local Types = require(script.Parent.Types)
local Util = require(script.Parent.Util)
local Animation = require(script.Parent.Animation)
local Section = require(script.Parent.Section)

local SubTab = {}
SubTab.__index = SubTab

export type Options = {
	Name: string,
}

export type SubTab = {
	Instance: ScrollingFrame,
	Name: string?,
	CreateSection: (self: SubTab, options: any) -> any,
	Select: (self: SubTab) -> (),
	GetName: (self: SubTab) -> string?,
	Destroy: (self: SubTab) -> (),
}

function SubTab.new(
	ctx: Types.UIContext,
	parent: Instance,
	name: string?,
	columns: number,
	onSelect: ((subtab: any) -> ())?,
	selectable: boolean?
): SubTab
	local theme = ctx.GetTheme()
	local sections: { any } = {}
	local matchCount = 0
	local active = false
	local nextColumn = 1

	local scroller = Util.scrollingFrame({
		Name = if name then `SubTab_{name}` else "SubTab_General",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -4, 1, -20),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = theme.Palette.StrokeStrong,
		ScrollBarImageTransparency = 0.15,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
	}, parent)
	Util.paint(scroller, "ScrollBarImageColor3", "StrokeStrong", theme)
	scroller.Visible = false

	local holder = Util.frame({
		Name = "Content",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, 20),
		Size = UDim2.new(1, -44, 0, 0),
	}, scroller)

	Util.list(holder, 0)

	local columnHolder = Util.frame({
		Name = "Columns",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
	}, holder)

	Util.create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, columnHolder)

	local function makeColumn(index: number): Frame
		local column = Util.frame({
			Name = `Column_{index}`,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Size = UDim2.new(0.5, -6, 0, 0),
		}, columnHolder)
		Util.list(column, 16)
		return column
	end

	local columnOne = makeColumn(1)
	local columnTwo = makeColumn(2)
	local columnFrames = { columnOne, columnTwo }

	if columns <= 1 then
		columnTwo.Visible = false
		columnOne.Size = UDim2.new(1, 0, 0, 0)
	end

	local spacer = Util.frame({
		Name = "BottomSpace",
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 52),
	}, holder)

	local subtab = setmetatable({} :: any, SubTab) :: SubTab
	subtab.Instance = scroller
	subtab.Name = name

	function subtab:CreateSection(options: any): any
		local opts = if typeof(options) == "string" then { Name = options } else (options or {})
		local columnIndex = 1
		if columns > 1 then
			columnIndex = if opts.Column == 2 then 2 elseif opts.Column == 1 then 1 else nextColumn
			if opts.Column == nil then
				nextColumn = if nextColumn == 1 then 2 else 1
			end
		end

		local section = Section.new(ctx, columnFrames[columnIndex], {
			Name = opts.Name or "Section",
			Description = opts.Description,
		})

		table.insert(sections, section)
		section:_ApplySearch("")
		return section
	end

	function subtab:Select()
		if not selectable then
			return
		end
		if onSelect then
			onSelect(subtab)
		end
	end

	function subtab:GetName(): string?
		return name
	end

	function subtab:_SetActive(value: boolean)
		local wasActive = active
		active = value
		scroller.Visible = value

		if value and not wasActive then
			holder.Position = UDim2.fromOffset(24, 28)
			Animation.play(holder, ctx.GetTheme().Motion.Slow, {
				Position = UDim2.fromOffset(24, 20),
			}, { easing = "Sine", direction = "InOut" })
		elseif not value then
			holder.Position = UDim2.fromOffset(24, 20)
		end
	end

	function subtab:_IsActive(): boolean
		return active
	end

	function subtab:_ApplySearch(query: string, forceVisible: boolean?): number
		local count = 0
		for _, section in sections do
			local matches = if forceVisible then true else section:_ApplySearch(query)
			if matches then
				count += 1
			end
		end
		matchCount = count
		return count
	end

	function subtab:_GetMatchCount(): number
		return matchCount
	end

	function subtab:_GetSections(): { any }
		return sections
	end

	function subtab:Destroy()
		for _, section in sections do
			section:Destroy()
		end
		table.clear(sections)
		scroller:Destroy()
	end

	return subtab
end

return SubTab

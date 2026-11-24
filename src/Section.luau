--!strict

local Types = require(script.Parent.Types)
local Util = require(script.Parent.Util)
local Animation = require(script.Parent.Animation)
local Base = require(script.Parent.Components.Base)
local Button = require(script.Parent.Components.Button)
local Toggle = require(script.Parent.Components.Toggle)
local Checkbox = require(script.Parent.Components.Checkbox)
local Slider = require(script.Parent.Components.Slider)
local Dropdown = require(script.Parent.Components.Dropdown)
local MultiDropdown = require(script.Parent.Components.MultiDropdown)
local TextInput = require(script.Parent.Components.TextInput)
local Keybind = require(script.Parent.Components.Keybind)
local ColorPicker = require(script.Parent.Components.ColorPicker)

local Section = {}
Section.__index = Section

export type SectionOptions = {
	Name: string,
	Description: string?,
}

export type LabelOptions = {
	Text: string,
	ColorRole: string?,
	Size: number?,
}

export type ParagraphOptions = {
	Text: string,
	ColorRole: string?,
	Size: number?,
}

export type StatusOptions = {
	Text: string,
	Value: string?,
	Kind: Types.StatusKind?,
	Pulse: boolean?,
}

export type Status = {
	Instance: Frame,
	SetStatus: (self: Status, value: string, kind: Types.StatusKind?, pulse: boolean?) -> (),
	SetVisible: (self: Status, visible: boolean) -> (),
	Destroy: (self: Status) -> (),
}

type SearchEntry = {
	row: GuiObject,
	text: string?,
	isControl: boolean,
}

local STATUS_ROLES: { [string]: string } = {
	neutral = "TextMuted",
	info = "Info",
	success = "Success",
	warning = "Warning",
	danger = "Danger",
}

local function contains(haystack: string, needle: string): boolean
	return string.find(string.lower(haystack), string.lower(needle), 1, true) ~= nil
end

local function asOptions(value: any, defaultKey: string): any
	if typeof(value) == "string" then
		return { [defaultKey] = value }
	end
	return value or {}
end

function Section.new(
	baseCtx: Types.UIContext,
	parent: Instance,
	options: SectionOptions
): any
	local theme = baseCtx.GetTheme()
	local entries: { SearchEntry } = {}
	local components: { any } = {}
	local query = ""
	local titleText = options.Name
	local descriptionText = options.Description
	local order = 1

	local root = Util.frame({
		Name = `Section_{titleText}`,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme.Palette.Surface,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
	}, parent)

	Util.corner(root, theme.Radius.Card)
	local stroke = Util.stroke(root, 1)
	baseCtx.Paint(root, "BackgroundColor3", "Surface")
	baseCtx.Paint(stroke, "Color", "Stroke")
	Util.padding(root, 24, 20)
	Util.list(root, 8)

	local header = Util.frame({
		Name = "Header",
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 24),
	}, root)

	local title = Base.text(baseCtx, header, titleText, {
		Font = theme.Fonts.Medium,
		Size = 15,
		ColorRole = "Text",
	})
	title.Position = UDim2.fromOffset(0, 0)
	title.Size = UDim2.fromScale(1, 1)

	local headerRule = Util.frame({
		Name = "HeaderRule",
		BackgroundColor3 = theme.Palette.Stroke,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 1),
	}, root)
	baseCtx.Paint(headerRule, "BackgroundColor3", "Stroke")

	local description: TextLabel? = nil
	if descriptionText and descriptionText ~= "" then
		description = Base.text(baseCtx, root, descriptionText, {
			Font = theme.Fonts.Regular,
			Size = 13,
			ColorRole = "TextMuted",
			Wrapped = true,
		})
		description.AutomaticSize = Enum.AutomaticSize.Y
		description.Size = UDim2.new(1, 0, 0, 0)
		description.LineHeight = 1.4
		description.LayoutOrder = 2
		order = 2
	end

	local content = Util.frame({
		Name = "Content",
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, root)

	Util.list(content, 12)

	local function register(row: GuiObject, searchText: string?)
		table.insert(entries, {
			row = row,
			text = searchText,
			isControl = searchText ~= nil,
		})
	end

	local ctx: Types.UIContext = table.clone(baseCtx)
	ctx.Register = register

	local function track(component: any): any
		table.insert(components, component)
		return component
	end

	local function nextOrder(): number
		order += 1
		return order
	end

	local function filterRows()
		local headingMatch = query ~= ""
			and (contains(titleText, query) or (descriptionText ~= nil and contains(descriptionText, query)))

		local anyControl = false
		for _, entry in entries do
			if entry.row.Parent then
				local visible: boolean
				if query == "" then
					visible = true
				elseif headingMatch then
					visible = true
				elseif entry.isControl and entry.text then
					visible = contains(entry.text, query)
				else
					visible = false
				end

				entry.row.Visible = visible
				if visible and entry.isControl then
					anyControl = true
				end
			end
		end

		return query == "" or headingMatch or anyControl
	end

	local section = setmetatable({} :: any, Section) :: any
	section.Instance = root

	function section:_ApplySearch(nextQuery: string): boolean
		local trimmed = string.gsub(nextQuery or "", "^%s*(.-)%s*$", "%1")
		query = string.lower(trimmed)
		local hasMatch = filterRows()
		root.Visible = query == "" or hasMatch
		return hasMatch
	end

	function section:_GetTitle(): string
		return titleText
	end

	function section:SetVisible(visible: boolean)
		root.Visible = visible
	end

	function section:CreateButton(value: any): any
		local opts = asOptions(value, "Text")
		local component = Button.new(ctx, content, opts)
		component.Instance.LayoutOrder = nextOrder()
		return track(component)
	end

	function section:CreateToggle(value: any): any
		local opts = asOptions(value, "Text")
		local component = Toggle.new(ctx, content, opts)
		component.Instance.LayoutOrder = nextOrder()
		return track(component)
	end

	function section:CreateCheckbox(value: any): any
		local opts = asOptions(value, "Text")
		local component = Checkbox.new(ctx, content, opts)
		component.Instance.LayoutOrder = nextOrder()
		return track(component)
	end

	function section:CreateSlider(value: any): any
		local opts = asOptions(value, "Text")
		local component = Slider.new(ctx, content, opts)
		component.Instance.LayoutOrder = nextOrder()
		return track(component)
	end

	function section:CreateDropdown(value: any): any
		local opts = asOptions(value, "Text")
		local component = Dropdown.new(ctx, content, opts)
		component.Instance.LayoutOrder = nextOrder()
		return track(component)
	end

	function section:CreateMultiDropdown(value: any): any
		local opts = asOptions(value, "Text")
		local component = MultiDropdown.new(ctx, content, opts)
		component.Instance.LayoutOrder = nextOrder()
		return track(component)
	end

	function section:CreateTextInput(value: any): any
		local opts = asOptions(value, "Text")
		local component = TextInput.new(ctx, content, opts)
		component.Instance.LayoutOrder = nextOrder()
		return track(component)
	end

	function section:CreateKeybind(value: any): any
		local opts = asOptions(value, "Text")
		local component = Keybind.new(ctx, content, opts)
		component.Instance.LayoutOrder = nextOrder()
		return track(component)
	end

	function section:CreateColorPicker(value: any): any
		local opts = asOptions(value, "Text")
		local component = ColorPicker.new(ctx, content, opts)
		component.Instance.LayoutOrder = nextOrder()
		return track(component)
	end

	function section:CreateLabel(value: any): TextLabel
		local opts: LabelOptions = asOptions(value, "Text")
		local label = Base.text(ctx, content, opts.Text, {
			Font = theme.Fonts.Regular,
			Size = opts.Size or 13,
			ColorRole = opts.ColorRole or "TextMuted",
		})
		label.LayoutOrder = nextOrder()
		label.Size = UDim2.new(1, 0, 0, 18)
		register(label, nil)
		return label
	end

	function section:CreateParagraph(value: any): TextLabel
		local opts: ParagraphOptions = asOptions(value, "Text")
		local paragraph = Base.text(ctx, content, opts.Text, {
			Font = theme.Fonts.Regular,
			Size = opts.Size or 13,
			ColorRole = opts.ColorRole or "TextMuted",
			Wrapped = true,
		})
		paragraph.AutomaticSize = Enum.AutomaticSize.Y
		paragraph.Size = UDim2.new(1, 0, 0, 0)
		paragraph.LineHeight = 1.4
		paragraph.LayoutOrder = nextOrder()
		register(paragraph, nil)
		return paragraph
	end

	function section:CreateDivider(): Frame
		local divider = Util.frame({
			BackgroundColor3 = theme.Palette.Stroke,
			BorderSizePixel = 0,
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, 0, 0, 1),
		}, content)
		ctx.Paint(divider, "BackgroundColor3", "Stroke")
		register(divider, nil)
		return divider
	end

	function section:CreateSpacer(height: number?): Frame
		local spacer = Util.frame({
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, 0, 0, height or 4),
		}, content)
		register(spacer, nil)
		return spacer
	end

	function section:CreateStatus(value: any): Status
		local opts: StatusOptions = asOptions(value, "Text")
		local kind: Types.StatusKind = opts.Kind or "neutral"
		local pulseEnabled = opts.Pulse == true

		local row, _, statusLabel = Base.row(ctx, content, opts.Text, 32)
		row.LayoutOrder = nextOrder()
		row.Name = "Status"
		if statusLabel then
			statusLabel.Size = UDim2.new(1, -110, 1, 0)
		end

		local group = Util.frame({
			AnchorPoint = Vector2.new(1, 0.5),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(0, 20),
		}, row)

		Util.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 7),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, group)

		local dotHolder = Util.frame({
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(10, 10),
		}, group)

		local halo = Util.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(6, 6),
		}, dotHolder)
		Util.corner(halo, 999)

		local dot = Util.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = theme.Palette.TextMuted,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(6, 6),
			ZIndex = 2,
		}, dotHolder)
		Util.corner(dot, 999)

		local haloScale = Util.create("UIScale", {
			Scale = 1,
		}, halo) :: UIScale

		local valueLabel = Base.text(ctx, group, opts.Value or "Ready", {
			Font = theme.Fonts.Mono,
			Size = 12,
			ColorRole = STATUS_ROLES[kind] or "TextMuted",
			XAlign = Enum.TextXAlignment.Right,
		})
		valueLabel.AutomaticSize = Enum.AutomaticSize.X
		valueLabel.Size = UDim2.fromOffset(0, 20)
		valueLabel.TextTruncate = Enum.TextTruncate.None

		local pulseTween: Tween? = nil

		local function stopPulse()
			Animation.cancel(pulseTween)
			pulseTween = nil
			haloScale.Scale = 1
			halo.BackgroundTransparency = 1
		end

		local function applyPulse()
			stopPulse()
			if not pulseEnabled then
				return
			end

			halo.BackgroundTransparency = 0.55
			local role = STATUS_ROLES[kind] or "TextMuted"
			ctx.Paint(halo, "BackgroundColor3", role)
			halo.BackgroundColor3 = ctx.Color(role)

			pulseTween = Animation.play(haloScale, 1.5, {
				Scale = 2.2,
			}, {
				easing = "Sine",
				direction = "Out",
				repeatCount = -1,
				reverses = true,
			})
		end

		local function paintStatus()
			local role = STATUS_ROLES[kind] or "TextMuted"
			ctx.Paint(dot, "BackgroundColor3", role)
			ctx.Paint(valueLabel, "TextColor3", role)
			dot.BackgroundColor3 = ctx.Color(role)
			valueLabel.TextColor3 = ctx.Color(role)
			applyPulse()
		end

		paintStatus()

		local status = {} :: Status
		status.Instance = row

		function status:SetStatus(nextValue: string, nextKind: Types.StatusKind?, nextPulse: boolean?)
			valueLabel.Text = nextValue
			if nextKind then
				kind = nextKind
			end
			if nextPulse ~= nil then
				pulseEnabled = nextPulse
			end
			paintStatus()
		end

		function status:SetVisible(visible: boolean)
			row.Visible = visible
		end

		function status:Destroy()
			stopPulse()
			row:Destroy()
		end

		register(row, opts.Text)
		track(status)
		return status
	end

	function section:Destroy()
		for _, component in components do
			if component.Destroy then
				component:Destroy()
			end
		end
		table.clear(components)
		root:Destroy()
	end

	return section
end

return Section

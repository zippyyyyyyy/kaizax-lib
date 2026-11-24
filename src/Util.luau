--!strict

local Types = require(script.Parent.Types)
local Animation = require(script.Parent.Animation)

local Util = {}

export type Bag = {
	Add: (self: Bag, connection: any) -> any,
	Clear: (self: Bag) -> (),
}

local COLOR_PROPERTIES = {
	"BackgroundColor3",
	"TextColor3",
	"ImageColor3",
	"ScrollBarImageColor3",
	"Color",
	"PlaceholderColor3",
	"TextStrokeColor3",
}

local COLOR_ATTRIBUTE = "KaizaxColor_"

local function addProperties(instance: Instance, properties: { [string]: any }?)
	if not properties then
		return
	end

	local target = instance :: any
	for property, value in properties do
		target[property] = value
	end
end

--- Creates an instance and applies properties before parenting it.
function Util.create(
	className: string,
	properties: { [string]: any }?,
	parent: Instance?
): Instance
	local instance = Instance.new(className)
	addProperties(instance, properties)
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Util.frame(properties: { [string]: any }?, parent: Instance?): Frame
	return Util.create("Frame", properties, parent) :: Frame
end

function Util.label(properties: { [string]: any }?, parent: Instance?): TextLabel
	return Util.create("TextLabel", properties, parent) :: TextLabel
end

function Util.textButton(properties: { [string]: any }?, parent: Instance?): TextButton
	return Util.create("TextButton", properties, parent) :: TextButton
end

function Util.textBox(properties: { [string]: any }?, parent: Instance?): TextBox
	return Util.create("TextBox", properties, parent) :: TextBox
end

function Util.imageLabel(properties: { [string]: any }?, parent: Instance?): ImageLabel
	return Util.create("ImageLabel", properties, parent) :: ImageLabel
end

function Util.scrollingFrame(properties: { [string]: any }?, parent: Instance?): ScrollingFrame
	return Util.create("ScrollingFrame", properties, parent) :: ScrollingFrame
end

function Util.corner(parent: Instance, radius: number): UICorner
	return Util.create("UICorner", {
		CornerRadius = UDim.new(0, radius),
	}, parent) :: UICorner
end

function Util.stroke(parent: Instance, thickness: number?, transparency: number?): UIStroke
	return Util.create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
	}, parent) :: UIStroke
end

function Util.padding(parent: Instance, x: number, y: number): UIPadding
	return Util.create("UIPadding", {
		PaddingLeft = UDim.new(0, x),
		PaddingRight = UDim.new(0, x),
		PaddingTop = UDim.new(0, y),
		PaddingBottom = UDim.new(0, y),
	}, parent) :: UIPadding
end

function Util.list(
	parent: Instance,
	padding: number,
	direction: Enum.FillDirection?,
	alignment: Enum.HorizontalAlignment?
): UIListLayout
	return Util.create("UIListLayout", {
		Padding = UDim.new(0, padding),
		FillDirection = direction or Enum.FillDirection.Vertical,
		HorizontalAlignment = alignment or Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, parent) :: UIListLayout
end

--- Creates a connection bag with bulk cleanup.
function Util.bag(): Bag
	local items: { any } = {}

	local bag = {} :: Bag

	function bag:Add(connection: any): any
		table.insert(items, connection)
		return connection
	end

	function bag:Clear()
		for _, connection in items do
			local kind = typeof(connection)
			if kind == "RBXScriptConnection" then
				connection:Disconnect()
			elseif kind == "table" and (connection :: any).Disconnect then
				(connection :: any):Disconnect()
			elseif kind == "function" then
				(connection :: any)()
			end
		end
		table.clear(items)
	end

	return bag
end

--- Connects a signal and stores the connection in a bag.
function Util.connect(bag: Bag, signal: any, callback: (...any) -> ...any): any
	local connection = signal:Connect(callback)
	bag:Add(connection)
	return connection
end

--- Runs a user callback without letting its error break the interface.
function Util.safeCall(callback: ((...any) -> ...any)?, ...: any)
	if not callback then
		return
	end

	local ok, err = pcall(callback, ...)
	if not ok then
		warn(`[Kaizax] callback failed: {tostring(err)}`)
	end
end

--- Marks a property as theme-driven. The role name resolves against Palette.
function Util.paint(
	instance: Instance,
	property: string,
	role: string,
	theme: Types.Theme?
)
	instance:SetAttribute(COLOR_ATTRIBUTE .. property, role)

	if theme then
		local color = (theme.Palette :: any)[role]
		if color then
			(instance :: any)[property] = color
		end
	end
end

--- Re-applies every color binding under and including root.
function Util.applyTheme(root: Instance, theme: Types.Theme)
	local palette = theme.Palette :: any

	local function apply(instance: Instance)
		for _, property in COLOR_PROPERTIES do
			local role = instance:GetAttribute(COLOR_ATTRIBUTE .. property)
			if typeof(role) == "string" then
				local color = palette[role]
				if color then
					(instance :: any)[property] = color
				end
			end
		end
	end

	apply(root)
	for _, descendant in root:GetDescendants() do
		apply(descendant)
	end
end

--- Tween a color property, respecting reduced-motion preferences.
function Util.tweenColor(
	instance: Instance,
	property: string,
	target: Color3,
	seconds: number,
	easing: string?,
	direction: string?
): Tween?
	return Animation.play(instance, seconds, {
		[property] = target,
	}, {
		easing = easing or "Quad",
		direction = direction or "Out",
	})
end

function Util.round(value: number, step: number): number
	if step <= 0 then
		return value
	end
	return math.round(value / step) * step
end

function Util.clamp(value: number, minimum: number, maximum: number): number
	if maximum < minimum then
		minimum, maximum = maximum, minimum
	end
	return math.clamp(value, minimum, maximum)
end

function Util.decimals(step: number): number
	if step >= 1 then
		return 0
	end
	return math.clamp(math.ceil(-math.log10(step)), 0, 4)
end

function Util.formatNumber(value: number, step: number, suffix: string?): string
	local text = string.format(`%.{Util.decimals(step)}f`, value)
	if suffix and suffix ~= "" then
		text ..= suffix
	end
	return text
end

function Util.hex(color: Color3): string
	return "#" .. string.upper(color:ToHex())
end

function Util.localPosition(object: GuiObject, relativeTo: GuiObject, scale: number): Vector2
	local divisor = if scale <= 0 then 1 else scale
	return (object.AbsolutePosition - relativeTo.AbsolutePosition) / divisor
end

function Util.viewportSize(): Vector2
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1280, 720)
end

function Util.listVisibleCount(layout: GuiObject): number
	local count = 0
	for _, child in layout:GetChildren() do
		if child:IsA("GuiObject") and child.Visible then
			count += 1
		end
	end
	return count
end

function Util.clear(instance: Instance)
	for _, child in instance:GetChildren() do
		child:Destroy()
	end
end

return Util

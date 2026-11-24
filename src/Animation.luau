--!strict

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

-- Master switches. Animation.play applies final values immediately when off.
local Animation = {}

Animation.ANIMATIONS_ENABLED = true
Animation.INTRO_ENABLED = true

local EASING: { [string]: EasingStyle } = {
	Linear = Enum.EasingStyle.Linear,
	Sine = Enum.EasingStyle.Sine,
	Quad = Enum.EasingStyle.Quad,
	Cubic = Enum.EasingStyle.Cubic,
	Quart = Enum.EasingStyle.Quart,
	Quint = Enum.EasingStyle.Quint,
	Exponential = Enum.EasingStyle.Exponential,
	Back = Enum.EasingStyle.Back,
}

local DIRECTION: { [string]: EasingDirection } = {
	In = Enum.EasingDirection.In,
	Out = Enum.EasingDirection.Out,
	InOut = Enum.EasingDirection.InOut,
}

Animation.MOTION = {
	Enter = { Duration = 0.4, Easing = "Quint", Direction = "Out" },
	Exit = { Duration = 0.18, Easing = "Quad", Direction = "In" },
	Hover = { Duration = 0.13, Easing = "Quad", Direction = "Out" },
	Press = { Duration = 0.12, Easing = "Quad", Direction = "Out" },
	Indicator = { Duration = 0.3, Easing = "Exponential", Direction = "Out" },
	Label = { Duration = 0.15, Easing = "Quad", Direction = "Out" },
	Status = { Duration = 0.25, Easing = "Quad", Direction = "Out" },
	Stagger = 0.05,
}

export type PlayOptions = {
	easing: string?,
	direction: string?,
	delay: number?,
	repeatCount: number?,
	reverses: boolean?,
	tag: string?,
}

export type FadeOptions = {
	Duration: number?,
	Easing: string?,
	Direction: string?,
	Delay: number?,
	IncludeDescendants: boolean?,
	Tag: string?,
}

local FADE_PROPERTIES = {
	"BackgroundTransparency",
	"TextTransparency",
	"ImageTransparency",
	"Transparency",
}

local ORIGINAL_ATTRIBUTE = "KaizaxOriginal_"
local tracked: { [Instance]: { [string]: Tween } } = {}
local tags: { [Tween]: string? } = {}

local function reducedMotion(): boolean
	local ok, enabled = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	return ok and enabled == true
end

local function forgetTween(tween: Tween)
	tags[tween] = nil
	for _, properties in tracked do
		for property, active in properties do
			if active == tween then
				properties[property] = nil
			end
		end
	end
end

--- Returns 0 when motion is disabled or the player requested reduced motion.
function Animation.duration(seconds: number): number
	if not Animation.ANIMATIONS_ENABLED or reducedMotion() then
		return 0
	end
	return math.max(0, seconds)
end

function Animation.enabled(): boolean
	return Animation.ANIMATIONS_ENABLED
end

function Animation.introEnabled(): boolean
	return Animation.ANIMATIONS_ENABLED and Animation.INTRO_ENABLED
end

--- Applies tween properties directly, without creating a tween.
function Animation.apply(instance: Instance, properties: { [string]: any })
	local target = instance :: any
	for property, value in properties do
		target[property] = value
	end
end

--- Rounds UDim offsets to integers so finished layouts stay crisp.
function Animation.integer(value: UDim2): UDim2
	return UDim2.new(
		value.X.Scale,
		math.floor(value.X.Offset + 0.5),
		value.Y.Scale,
		math.floor(value.Y.Offset + 0.5)
	)
end

--- Cancels tracked tweens on an instance, or one property of an instance.
function Animation.stop(instance: Instance, property: string?)
	local properties = tracked[instance]
	if not properties then
		return
	end

	if property then
		local tween = properties[property]
		if tween then
			Animation.cancel(tween)
		end
		return
	end

	for _, tween in properties do
		Animation.cancel(tween)
	end
end

--- Cancels tracked tweens with a tag under a root subtree.
function Animation.stopTagged(root: Instance, tag: string)
	for instance, properties in tracked do
		if instance == root or instance:IsDescendantOf(root) then
			for _, tween in properties do
				if tags[tween] == tag then
					Animation.cancel(tween)
				end
			end
		end
	end
end

--- Tweens an instance and returns the tween, or nil when motion is disabled.
--- Active tweens are stored per object and property; a new tween replaces the old.
function Animation.play(
	instance: Instance,
	seconds: number,
	properties: { [string]: any },
	options: PlayOptions?
): Tween?
	local opts = (options or {}) :: PlayOptions
	local duration = Animation.duration(seconds)

	if duration <= 0 then
		for property in properties do
			Animation.stop(instance, property)
		end
		Animation.apply(instance, properties)
		return nil
	end

	for property in properties do
		Animation.stop(instance, property)
	end

	local info = TweenInfo.new(
		duration,
		EASING[opts.easing or "Quad"] or Enum.EasingStyle.Quad,
		DIRECTION[opts.direction or "Out"] or Enum.EasingDirection.Out,
		opts.repeatCount or 0,
		opts.reverses or false,
		opts.delay or 0
	)

	local tween = TweenService:Create(instance, info, properties)
	local own = tracked[instance]
	if not own then
		own = {}
		tracked[instance] = own
	end
	for property in properties do
		own[property] = tween
	end
	tags[tween] = opts.tag

	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and (opts.repeatCount or 0) == 0 then
			Animation.apply(instance, properties)
		end
		forgetTween(tween)
	end)

	tween:Play()
	return tween
end

--- Cancels a tween if it is still running.
function Animation.cancel(tween: Tween?)
	if tween and tween.PlaybackState ~= Enum.PlaybackState.Completed then
		tween:Cancel()
	end
	if tween then
		forgetTween(tween)
	end
end

local function originalTransparency(instance: Instance, property: string): number?
	local key = ORIGINAL_ATTRIBUTE .. property
	local stored = instance:GetAttribute(key)
	if typeof(stored) == "number" then
		return stored
	end

	local ok, value = pcall(function()
		return (instance :: any)[property]
	end)
	if not ok or typeof(value) ~= "number" then
		return nil
	end

	instance:SetAttribute(key, value)
	return value
end

--- Fades a subtree while preserving each object's original transparency.
--- alpha 1 restores originals; alpha 0 hides them.
function Animation.fade(root: Instance, alpha: number, options: FadeOptions?)
	local opts = (options or {}) :: FadeOptions
	local motion = Animation.MOTION.Enter
	local duration = Animation.duration(opts.Duration or motion.Duration)
	local fraction = math.clamp(alpha, 0, 1)
	local targets: { Instance } = { root }
	if opts.IncludeDescendants ~= false then
		for _, descendant in root:GetDescendants() do
			targets[#targets + 1] = descendant
		end
	end

	for _, instance in targets do
		local isStroke = instance:IsA("UIStroke")
		local isGui = instance:IsA("GuiObject")
		if isStroke or isGui then
			for _, property in FADE_PROPERTIES do
				if property == "Transparency" and not isStroke then
					continue
				end
				if property ~= "Transparency" and not isGui then
					continue
				end

				local original = originalTransparency(instance, property)
				if original then
					local target = if fraction >= 1
						then original
						else original + (1 - original) * (1 - fraction)
					Animation.play(instance, duration, {
						[property] = target,
					}, {
						easing = opts.Easing or motion.Easing,
						direction = opts.Direction or motion.Direction,
						delay = opts.Delay or 0,
						tag = opts.Tag,
					})
				end
			end
		end

		if instance:IsA("CanvasGroup") then
			local visible = if fraction >= 1 then 0 else 1 - fraction
			Animation.play(instance, duration, {
				GroupTransparency = visible,
			}, {
				easing = opts.Easing or motion.Easing,
				direction = opts.Direction or motion.Direction,
				delay = opts.Delay or 0,
				tag = opts.Tag,
			})
		end
	end
end

function Animation.reducedMotion(): boolean
	return reducedMotion()
end

return Animation

--!strict

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Animation = {}

local EASING: { [string]: EasingStyle } = {
	Linear = Enum.EasingStyle.Linear,
	Sine = Enum.EasingStyle.Sine,
	Quad = Enum.EasingStyle.Quad,
	Cubic = Enum.EasingStyle.Cubic,
	Quart = Enum.EasingStyle.Quart,
	Quint = Enum.EasingStyle.Quint,
	Back = Enum.EasingStyle.Back,
}

local DIRECTION: { [string]: EasingDirection } = {
	In = Enum.EasingDirection.In,
	Out = Enum.EasingDirection.Out,
	InOut = Enum.EasingDirection.InOut,
}

export type PlayOptions = {
	easing: string?,
	direction: string?,
	delay: number?,
	repeatCount: number?,
	reverses: boolean?,
}

local function reducedMotion(): boolean
	local ok, enabled = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	return ok and enabled == true
end

--- Returns 0 when the player has requested reduced motion.
function Animation.duration(seconds: number): number
	if reducedMotion() then
		return 0
	end
	return math.max(0, seconds)
end

--- Applies tween properties directly, without creating a tween.
function Animation.apply(instance: Instance, properties: { [string]: any })
	local target = instance :: any
	for property, value in properties do
		target[property] = value
	end
end

--- Tweens an instance and returns the tween, or nil when motion is disabled.
function Animation.play(
	instance: Instance,
	seconds: number,
	properties: { [string]: any },
	options: PlayOptions?
): Tween?
	local opts = (options or {}) :: PlayOptions
	local duration = Animation.duration(seconds)
	if duration <= 0 then
		Animation.apply(instance, properties)
		return nil
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
	tween:Play()
	return tween
end

--- Cancels a tween if it is still running.
function Animation.cancel(tween: Tween?)
	if tween and tween.PlaybackState ~= Enum.PlaybackState.Completed then
		tween:Cancel()
	end
end

function Animation.reducedMotion(): boolean
	return reducedMotion()
end

return Animation

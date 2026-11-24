--!strict

-- Kaizax UI Library
-- A Roblox-native interface library for building dense, dark tool panels.
-- Ported from the visual language of the original Dear ImGui interface.

local Players = game:GetService("Players")

local Types = require(script.Types)
local Theme = require(script.Theme)
local Util = require(script.Util)
local Signal = require(script.Signal)
local Window = require(script.Window)
local Notification = require(script.Notification)
local Config = require(script.Config)
local ReExecute = require(script.ReExecute)
local Animation = require(script.Animation)

local Library = {}

Library.Version = "1.0.0"
Library.Types = Types
Library.Theme = Theme
Library.Themes = Theme.Presets
Library.Util = Util
Library.Signal = Signal
Library.ReExecute = ReExecute

local MARKER = "__KaizaxInterfaceLab"

local env: any = _G
pcall(function()
	if typeof(getgenv) == "function" then
		env = getgenv()
	end
end)

local previous = nil
pcall(function()
	previous = (env :: any)[MARKER]
end)
if typeof(previous) == "table" then
	local unload = (previous :: any).Unload
	if typeof(unload) == "function" then
		pcall(unload)
	elseif typeof((previous :: any).Library) == "table" then
		local destroy = (previous :: any).Library.Destroy
		if typeof(destroy) == "function" then
			pcall(destroy, (previous :: any).Library)
		end
	end
end

local runtime = { reloaded = ReExecute.consumeReloaded() }
pcall(function()
	(env :: any)[MARKER] = runtime
end)

local config = Config.load()
local cleanups: { () -> () } = {}
local unloaded = false

local currentTheme: Types.Theme = Theme.resolve(config.Theme)
local windows: { any } = {}
local notificationManager: Notification.Manager? = nil

if config.GlowEnabled == false then
	Animation.GLOW_ENABLED = false
end
if config.GlowPulse == false then
	Animation.GLOW_PULSE = false
end

local function resolveParent(): Instance
	local player = Players.LocalPlayer
	if player then
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			return playerGui
		end
	end
	return game:GetService("CoreGui")
end

--- Returns the active palette without creating a window.
--- @return Types.Theme
function Library._GetTheme(): Types.Theme
	return currentTheme
end

--- Public accessor for the active theme.
function Library:GetTheme(): Types.Theme
	return currentTheme
end

--- Returns the persisted settings snapshot.
function Library:GetConfig(): typeof(config)
	return Config.snapshot()
end

function Library:_GetConfig(): typeof(config)
	return config
end

function Library:_SetConfigValue(key: string, value: any): boolean
	if not Config.set(key, value) then
		return false
	end
	if key == "GlowEnabled" then
		Animation.GLOW_ENABLED = value == true
	elseif key == "GlowPulse" then
		Animation.GLOW_PULSE = value == true
	end
	for _, window in windows do
		if typeof((window :: any)._ApplyRuntimeConfig) == "function" then
			pcall((window :: any)._ApplyRuntimeConfig, window, key, value)
		end
	end
	return true
end

function Library:SetConfigValue(key: string, value: any): boolean
	return Library:_SetConfigValue(key, value)
end

--- Applies a preset name or a partial theme to every open window.
--- @param input Types.ThemeInput
--- @return Types.Theme
function Library:SetTheme(input: Types.ThemeInput): Types.Theme
	local resolved = Theme.resolve(input)
	currentTheme = resolved
	Library:_SetConfigValue("Theme", resolved.Name)

	for _, window in windows do
		window:_ApplyTheme(resolved)
	end

	if notificationManager then
		notificationManager:SetTheme(resolved)
	end

	return resolved
end

--- Returns the theme presets available by name.
function Library:GetThemes(): { string }
	return table.clone(Theme.Presets)
end

--- Creates a top-level window.
--- @param options Window.Options?
--- @return Window.Window
function Library:CreateWindow(options: Window.Options?): Window.Window
	local opts = table.clone(options or {})

	if config.Theme then
		opts.Theme = config.Theme
	end
	if config.Size then
		opts.Size = Vector2.new(config.Size.X, config.Size.Y)
	end
	if config.Position then
		opts.Position = Vector2.new(config.Position.X, config.Position.Y)
	end
	if config.ToggleKey == "Disabled" then
		opts.ToggleKey = false
	elseif typeof(config.ToggleKey) == "string" then
		local savedKey = (Enum.KeyCode :: any)[config.ToggleKey]
		if savedKey then
			opts.ToggleKey = savedKey
		end
	end

	if opts.Theme then
		Library:SetTheme(opts.Theme)
	end

	local window = Window.new(Library, opts)
	if runtime.reloaded then
		runtime.reloaded = false
		task.defer(function()
			Library:Notify({
				Title = "Reloaded in new server",
				Kind = "info",
				Duration = 2.5,
			})
		end)
	end
	return window
end

--- Pushes a notification. The host appears on first use and is independent
--- from window visibility, so alerts still show after a close.
function Library:Notify(options: Types.NotificationOptions)
	if not notificationManager then
		notificationManager = Notification.new(function()
			return currentTheme
		end, resolveParent())
	end

	notificationManager:Push(options)
end

--- Shortcut with a title and optional message.
function Library:Toast(title: string, message: string?, kind: Types.NotificationKind?)
	Library:Notify({
		Title = title,
		Message = message,
		Kind = kind,
	})
end

function Library:_AddWindow(window: any)
	table.insert(windows, window)
end

function Library:_RemoveWindow(window: any)
	local index = table.find(windows, window)
	if index then
		table.remove(windows, index)
	end
end

--- Closes and destroys every window and the notification host.
function Library:Destroy()
	for index = #windows, 1, -1 do
		local window = windows[index]
		windows[index] = nil
		window:Destroy()
	end
	table.clear(windows)

	if notificationManager then
		notificationManager:Destroy()
		notificationManager = nil
	end
end

function Library:Unload()
	if unloaded then
		return
	end
	unloaded = true
	for index = #cleanups, 1, -1 do
		local cleanup = cleanups[index]
		cleanups[index] = nil
		pcall(cleanup)
	end
	Library:Destroy()
	Config.flush()
	pcall(function()
		(env :: any)[MARKER] = nil
	end)
end

runtime.Unload = function()
	Library:Unload()
end
runtime.Library = Library

cleanups[#cleanups + 1] = ReExecute.start(function()
	return Config.snapshot()
end)

return Library

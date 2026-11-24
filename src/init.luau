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

local Library = {}

Library.Version = "1.0.0"
Library.Types = Types
Library.Theme = Theme
Library.Themes = Theme.Presets
Library.Util = Util
Library.Signal = Signal

local currentTheme: Types.Theme = Theme.resolve("Default")
local windows: { any } = {}
local notificationManager: Notification.Manager? = nil

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

--- Applies a preset name or a partial theme to every open window.
--- @param input Types.ThemeInput
--- @return Types.Theme
function Library:SetTheme(input: Types.ThemeInput): Types.Theme
	local resolved = Theme.resolve(input)
	currentTheme = resolved

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
	local opts = options or {}

	if opts.Theme then
		Library:SetTheme(opts.Theme)
	end

	return Window.new(Library, opts)
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

return Library

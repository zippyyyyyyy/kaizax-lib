-- Kaizax demo: exercises every public component and control path.
-- Load this file through the bundled demo, or require it and call:
--   local Demo = require(path.to.Demo)
--   local app = Demo(Kaizax)

return function(Library: any)
	local Players = game:GetService("Players")
	local localPlayer = Players.LocalPlayer
	local userName = if localPlayer then localPlayer.Name else "player"

	local window = Library:CreateWindow({
		Title = "Kaizax",
		Subtitle = "interface lab",
		Size = Vector2.new(960, 680),
		ToggleKey = Enum.KeyCode.RightShift,
	})

	local resets: { () -> () } = {}

	----------------------------------------------------------------
	-- Overview
	----------------------------------------------------------------

	local overview = window:CreateTab({
		Name = "Overview",
		Description = "Session state, quick actions and interface health at a glance.",
	})

	local session = overview:CreateSection({
		Name = "Session",
		Description = "Live state for the current interface session.",
	})

	session:CreateLabel({ Text = `Connected as {userName}` })
	session:CreateParagraph({
		Text = "The panel is drawn entirely with native Roblox GUI objects. Every control is theme-bound, so palette changes update the whole interface without rebuilding it.",
	})

	session:CreateSpacer(2)

	local interfaceStatus = session:CreateStatus({
		Text = "Interface",
		Value = "Stable",
		Kind = "success",
		Pulse = true,
	})

	local themeStatus = session:CreateStatus({
		Text = "Theme",
		Value = Library:GetTheme().Name,
		Kind = "info",
	})

	local cacheStatus = session:CreateStatus({
		Text = "Runtime",
		Value = "Ready",
		Kind = "neutral",
	})

	session:CreateDivider()

	local function report(message: string)
		cacheStatus:SetStatus(message, "info", false)
	end

	local function hex(color: Color3): string
		return `#{color:ToHex()}`
	end

	session:CreateButton({
		Text = "Run health check",
		Variant = "Primary",
		Callback = function()
			interfaceStatus:SetStatus("Stable", "success", true)
			report("Checked just now")
			window:Notify({
				Title = "Health check complete",
				Message = "The interface accepted the latest interaction.",
				Kind = "success",
			})
		end,
	})

	local actions = overview:CreateSection({
		Name = "Quick actions",
		Description = "Sample commands that report into the session status.",
	})

	actions:CreateButton({
		Text = "Copy session label",
		Variant = "Secondary",
		Callback = function()
			if setclipboard then
				setclipboard(`Kaizax session: {userName}`)
				report("Session label copied")
			else
				report("Clipboard unavailable")
			end
		end,
	})

	actions:CreateButton({
		Text = "Reset demo values",
		Variant = "Ghost",
		Callback = function()
			for _, reset in resets do
				reset()
			end
			report(`Reset {#resets} controls`)
		end,
	})

	actions:CreateButton({
		Text = "Clear runtime state",
		Variant = "Danger",
		Callback = function()
			cacheStatus:SetStatus("Cleared", "warning", false)
			window:Notify({
				Title = "Runtime state cleared",
				Message = "Transient status values were reset.",
				Kind = "warning",
				Duration = 3,
			})
		end,
	})

	local streamToggle = actions:CreateToggle({
		Text = "Compact row density",
		Default = false,
		Callback = function(value)
			report(if value then "Compact density on" else "Compact density off")
		end,
	})

	local tooltipsCheckbox = actions:CreateCheckbox({
		Text = "Show inline hints",
		Default = true,
		Callback = function(value)
			report(if value then "Hints enabled" else "Hints disabled")
		end,
	})

	table.insert(resets, function()
		streamToggle:SetValue(false)
		tooltipsCheckbox:SetValue(true)
	end)

	local notes = overview:CreateSection({
		Name = "Notes",
		Description = "How the panel is meant to be driven.",
	})

	notes:CreateLabel({
		Text = "Interaction model",
		ColorRole = "Text",
	})

	notes:CreateParagraph({
		Text = "Drag the top bar to move the window, use the corner grip to resize, and press RightShift to hide or restore the panel. The search field filters the active tab.",
	})

	notes:CreateDivider()

	notes:CreateStatus({
		Text = "Notifications",
		Value = "Top right",
		Kind = "neutral",
	})

	----------------------------------------------------------------
	-- Components
	----------------------------------------------------------------

	local components = window:CreateTab({
		Name = "Components",
		Description = "Every control with live values and state feedback.",
		SubTabs = {
			{ Name = "Inputs", Columns = 2 },
			{ Name = "Feedback", Columns = 2 },
		},
	})

	components:SelectSubTab("Inputs")

	local values = components:CreateSection({
		Name = "Numeric and text",
		Description = "Sample values. Every change reports into the session status.",
	})

	local fovSlider = values:CreateSlider({
		Text = "Field of view",
		Min = 40,
		Max = 120,
		Default = 70,
		Step = 1,
		Suffix = "°",
		Live = true,
		Callback = function(value)
			report(`FOV {math.round(value)}`)
		end,
	})

	values:CreateSlider({
		Text = "Sample ratio",
		Min = 0,
		Max = 1,
		Default = 0.6,
		Step = 0.05,
		Live = true,
		Callback = function(value)
			report(`Sample ratio {string.format("%.2f", value)}`)
		end,
	})

	local profileInput = values:CreateTextInput({
		Text = "Profile label",
		Placeholder = "Enter a profile name",
		Default = "default",
		CharacterLimit = 32,
		Callback = function(text)
			report(if text == "" then "Profile label cleared" else `Profile "{text}"`)
		end,
	})

	local actionBind = values:CreateKeybind({
		Text = "Action bind",
		Default = Enum.KeyCode.F,
		ShowMode = true,
		Callback = function(key, mode)
			report(`{if key then key.Name else "None"} · {mode}`)
		end,
	})

	table.insert(resets, function()
		fovSlider:SetValue(70)
		profileInput:SetText("default")
		actionBind:SetKey(Enum.KeyCode.F, true)
	end)

	local selections = components:CreateSection({
		Name = "Selections",
		Description = "Popups, multi-select, color and binary state.",
	})

	local renderDropdown = selections:CreateDropdown({
		Text = "Render mode",
		Options = { "Balanced", "Quality", "Performance", "Minimal" },
		Default = "Balanced",
		Callback = function(value)
			report(`Render mode: {value}`)
		end,
	})

	local layersDropdown = selections:CreateMultiDropdown({
		Text = "Visible panels",
		Options = { "Session", "Controls", "Alerts", "Diagnostics" },
		Default = { "Session", "Controls" },
		Callback = function(values)
			report(`Panels: {#values}`)
		end,
	})

	local accentPicker = selections:CreateColorPicker({
		Text = "Accent sample",
		Default = Color3.fromHex("#00FAB4"),
		Alpha = 1,
		ShowAlpha = true,
		Callback = function(color, alpha)
			report(`{hex(color)} · {math.round(alpha * 100)}%`)
		end,
	})

	local gridCheckbox = selections:CreateCheckbox({
		Text = "Show alignment grid",
		Default = false,
		Callback = function(value)
			report(if value then "Alignment grid on" else "Alignment grid off")
		end,
	})

	table.insert(resets, function()
		renderDropdown:SetValue("Balanced", true)
		layersDropdown:SetValue({ "Session", "Controls" }, true)
		accentPicker:SetValue(Color3.fromHex("#00FAB4"), 1, true)
		gridCheckbox:SetValue(false, true)
	end)

	components:SelectSubTab("Feedback")

	local buttons = components:CreateSection({
		Name = "Buttons",
		Description = "Four visual variants on the same interaction path.",
	})

	buttons:CreateButton({
		Text = "Primary action",
		Variant = "Primary",
		Callback = function()
			window:Notify({
				Title = "Primary action",
				Message = "This button uses the accent fill.",
				Kind = "info",
			})
		end,
	})

	buttons:CreateButton({
		Text = "Secondary action",
		Variant = "Secondary",
		Callback = function()
			report("Secondary action fired")
		end,
	})

	buttons:CreateButton({
		Text = "Ghost action",
		Variant = "Ghost",
		Callback = function()
			report("Ghost action fired")
		end,
	})

	buttons:CreateButton({
		Text = "Danger action",
		Variant = "Danger",
		Callback = function()
			window:Notify({
				Title = "Danger action",
				Message = "Destructive styling, reversible callback.",
				Kind = "error",
			})
		end,
	})

	local alerts = components:CreateSection({
		Name = "Alerts",
		Description = "Toast stack with kind, lifetime and progress.",
	})

	alerts:CreateButton({
		Text = "Send success alert",
		Variant = "Secondary",
		Callback = function()
			window:Notify({
				Title = "Preset saved",
				Message = "Interface settings stored for this session.",
				Kind = "success",
				Duration = 4,
			})
		end,
	})

	alerts:CreateButton({
		Text = "Send warning alert",
		Variant = "Secondary",
		Callback = function()
			window:Notify({
				Title = "Unsaved changes",
				Message = "Switch tabs before applying another preset.",
				Kind = "warning",
			})
		end,
	})

	alerts:CreateParagraph({
		Text = "Notifications stack independently from the window and pause their lifetime while hovered.",
	})

	local readouts = components:CreateSection({
		Name = "Readouts",
		Description = "Static copy, wrapped paragraphs and live status.",
	})

	readouts:CreateLabel({
		Text = "Static label",
		ColorRole = "Text",
	})

	readouts:CreateParagraph({
		Text = "Paragraphs wrap to the available card width and grow vertically. Use them for descriptions, warnings or supporting notes.",
	})

	readouts:CreateDivider()

	local liveStatus = readouts:CreateStatus({
		Text = "Live value",
		Value = "70°",
		Kind = "success",
	})

	readouts:CreateButton({
		Text = "Sync live value",
		Variant = "Secondary",
		Callback = function()
			local value = math.round(fovSlider:GetValue())
			liveStatus:SetStatus(`{value}°`, "success", true)
		end,
	})

	----------------------------------------------------------------
	-- Settings
	----------------------------------------------------------------

	local settings = window:CreateTab({
		Name = "Settings",
		Description = "Theme selection, motion preferences and maintenance.",
	})

	local themeSection = settings:CreateSection({
		Name = "Theme configuration",
		Description = "Palette, typography and motion tokens.",
	})

	themeSection:CreateParagraph({
		Text = "Presets replace the active palette across every open window and future notification.",
	})

	themeSection:CreateDropdown({
		Text = "Preset",
		Options = Library:GetThemes(),
		Default = Library:GetTheme().Name,
		Callback = function(value)
			local theme = Library:SetTheme(value)
			themeStatus:SetStatus(value, "info", false)
			window:Notify({
				Title = `Theme: {theme.Name}`,
				Message = "Palette applied across the interface.",
				Kind = "info",
				Duration = 2.5,
			})
		end,
	})

	local paletteSection = settings:CreateSection({
		Name = "Interface",
		Description = "Window visibility and shell behavior.",
	})

	paletteSection:CreateLabel({
		Text = "Window controls",
		ColorRole = "Text",
	})

	paletteSection:CreateParagraph({
		Text = "Use the top-right controls to minimize or close. Closing hides the panel until the toggle key is pressed again.",
	})

	paletteSection:CreateDivider()

	paletteSection:CreateButton({
		Text = "Minimize panel",
		Variant = "Ghost",
		Callback = function()
			window:SetMinimized(true)
		end,
	})

	paletteSection:CreateButton({
		Text = "Close panel",
		Variant = "Danger",
		Callback = function()
			window:SetOpen(false)
		end,
	})

	local maintenance = settings:CreateSection({
		Name = "Maintenance",
		Description = "Release the interface and every listener.",
	})

	maintenance:CreateButton({
		Text = "Destroy demo window",
		Variant = "Danger",
		Callback = function()
			window:Notify({
				Title = "Window closing",
				Message = "The demo window is being destroyed.",
				Kind = "warning",
				Duration = 2,
			})
			task.delay(0.35, function()
				window:Destroy()
			end)
		end,
	})

	maintenance:CreateParagraph({
		Text = "Destroying the window disconnects every input listener, closes popups and releases the ScreenGui.",
	})

	return {
		window = window,
		library = Library,
	}
end

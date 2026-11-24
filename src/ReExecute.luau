--!strict

local Players = game:GetService("Players")

local ReExecute = {}

-- Queued loader reads this path from the executor workspace folder.
ReExecute.SCRIPT_SOURCE = "Kaizax/kaizax-demo.luau"
ReExecute.DEBUG = false

local RELOADED_KEY = "__KaizaxReloaded"

local env: any = _G
pcall(function()
	if typeof(getgenv) == "function" then
		env = getgenv()
	end
end)

local QUEUE_NAMES = {
	"queue_on_teleport",
	"syn.queue_on_teleport",
	"fluxus.queue_on_teleport",
	"queue_on_tp",
	"queueonteleport",
	"queueontp",
}

local function nestedValue(root: any, path: string): any
	local value = root
	for part in string.gmatch(path, "[^%.]+") do
		if typeof(value) ~= "table" then
			return nil
		end
		value = value[part]
	end
	return value
end

local function queueFunction(): ((string) -> ())?
	for _, name in QUEUE_NAMES do
		local ok, value = pcall(function()
			return nestedValue(env, name)
		end)
		if ok and typeof(value) == "function" then
			return value :: (string) -> ()
		end
	end
	return nil
end

local function quote(text: string): string
	local escaped = tostring(text):gsub("\\", "\\\\"):gsub('"', '\\"')
	return '"' .. escaped .. '"'
end

function ReExecute.consumeReloaded(): boolean
	local ok, reloaded = pcall(function()
		return env[RELOADED_KEY] == true
	end)
	pcall(function()
		env[RELOADED_KEY] = nil
	end)
	return ok and reloaded == true
end

local function buildLoader(onlySameGame: boolean, gameId: string): string
	local sameGame = if onlySameGame then "true" else "false"
	return table.concat({
		"local f=", quote(ReExecute.SCRIPT_SOURCE), ";",
		"local g=_G;pcall(function() if typeof(getgenv)==\"function\" then g=getgenv() end end);",
		"task.spawn(function()",
		"if not game:IsLoaded() then game.Loaded:Wait() end;",
		"local P=game:GetService(\"Players\");local p=P.LocalPlayer;",
		"while not p do P:GetPropertyChangedSignal(\"LocalPlayer\"):Wait();p=P.LocalPlayer end;",
		"if ", sameGame, " and tostring(game.GameId)~=", quote(gameId), " then return end;",
		"g[", quote(RELOADED_KEY), "]=true;",
		"local okF,it=pcall(function() return typeof(isfile)==\"function\" and isfile(f) or false end);if not okF or not it then return end;",
		"local okR,s=pcall(function() return typeof(readfile)==\"function\" and readfile(f) or nil end);if not okR or typeof(s)~=\"string\" then return end;",
		"local okL,chunk=pcall(function() return typeof(loadstring)==\"function\" and loadstring(s) or nil end);if okL and chunk then pcall(chunk) end;",
		"end)",
	})
end

--- Watches LocalPlayer.OnTeleport and queues one short loader per teleport.
function ReExecute.start(getConfig: () -> any): () -> ()
	local queued = false
	local connection: RBXScriptConnection? = nil

	local function onTeleport(state: Enum.TeleportState)
		if state ~= Enum.TeleportState.Started and state ~= Enum.TeleportState.InProgress then
			return
		end
		if queued then
			return
		end
		queued = true

		local config = getConfig()
		if config.AutoReexecute ~= true then
			if ReExecute.DEBUG then
				print("[Kaizax] re-execute disabled")
			end
			return
		end

		local queue = queueFunction()
		if not queue then
			if ReExecute.DEBUG then
				print("[Kaizax] queue_on_teleport unavailable")
			end
			return
		end

		local loader = buildLoader(config.OnlySameGame == true, tostring(game.GameId))
		local ok, err = pcall(queue, loader)
		if ReExecute.DEBUG then
			if ok then
				print("[Kaizax] queued re-execute once")
			else
				warn(`[Kaizax] queue failed: {tostring(err)}`)
			end
		end
	end

	local function bind(player: Player?)
		if not player or connection then
			return
		end
		connection = player.OnTeleport:Connect(onTeleport)
	end

	bind(Players.LocalPlayer)
	local watch: RBXScriptConnection? = nil
	if not connection then
		watch = Players:GetPropertyChangedSignal("LocalPlayer"):Connect(function()
			bind(Players.LocalPlayer)
			if connection and watch then
				watch:Disconnect()
				watch = nil
			end
		end)
	end

	return function()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if watch then
			watch:Disconnect()
			watch = nil
		end
	end
end

return ReExecute

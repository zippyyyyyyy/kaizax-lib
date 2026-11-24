--!strict

local HttpService = game:GetService("HttpService")

local Config = {}

local FOLDER = "Kaizax"
local FILE = "Kaizax/config.json"
local SAVE_DELAY = 0.5

local env: any = _G
pcall(function()
	if typeof(getgenv) == "function" then
		env = getgenv()
	end
end)

local function fn(name: string): ((...any) -> ())?
	local ok, value = pcall(function()
		return (env :: any)[name]
	end)
	if ok and typeof(value) == "function" then
		return value :: (...any) -> ()
	end
	return nil
end

local function numberPair(value: any): { X: number, Y: number }?
	if typeof(value) ~= "table" then
		return nil
	end
	local x = tonumber(value.X or value.x)
	local y = tonumber(value.Y or value.y)
	if not x or not y then
		return nil
	end
	return { X = x, Y = y }
end

local defaults = {
	Theme = "Default",
	ActiveTab = nil :: string?,
	ToggleKey = "RightShift",
	Position = nil :: { X: number, Y: number }?,
	Size = nil :: { X: number, Y: number }?,
	AutoReexecute = true,
	OnlySameGame = true,
	GlowEnabled = true,
	GlowPulse = true,
}

local data = table.clone(defaults)
local saveTask: thread? = nil

function Config.load(): typeof(data)
	data = table.clone(defaults)

	local isFile = fn("isfile")
	local isFolder = fn("isfolder")
	local read = fn("readfile")
	if not isFile or not isFolder or not read then
		return data
	end

	pcall(function()
		if not isFolder(FOLDER) or not isFile(FILE) then
			return
		end
		local raw = read(FILE)
		if typeof(raw) ~= "string" then
			return
		end
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if not ok or typeof(decoded) ~= "table" then
			return
		end

		if typeof(decoded.Theme) == "string" then
			data.Theme = decoded.Theme
		end
		if typeof(decoded.ActiveTab) == "string" then
			data.ActiveTab = decoded.ActiveTab
		end
		if typeof(decoded.ToggleKey) == "string" then
			data.ToggleKey = decoded.ToggleKey
		end
		data.Position = numberPair(decoded.Position)
		data.Size = numberPair(decoded.Size)
		if typeof(decoded.AutoReexecute) == "boolean" then
			data.AutoReexecute = decoded.AutoReexecute
		end
		if typeof(decoded.OnlySameGame) == "boolean" then
			data.OnlySameGame = decoded.OnlySameGame
		end
		if typeof(decoded.GlowEnabled) == "boolean" then
			data.GlowEnabled = decoded.GlowEnabled
		end
		if typeof(decoded.GlowPulse) == "boolean" then
			data.GlowPulse = decoded.GlowPulse
		end
	end)

	return data
end

function Config.get(key: string): any
	return data[key]
end

function Config.snapshot(): typeof(data)
	return table.clone(data)
end

local function writeNow()
	if saveTask then
		pcall(task.cancel, saveTask)
		saveTask = nil
	end

	local isFolder = fn("isfolder")
	local makeFolder = fn("makefolder")
	local write = fn("writefile")
	if not write then
		return
	end

	pcall(function()
		if isFolder and not isFolder(FOLDER) and makeFolder then
			makeFolder(FOLDER)
		end
		local encoded = HttpService:JSONEncode(data)
		if typeof(encoded) == "string" then
			write(FILE, encoded)
		end
	end)
end

function Config.saveSoon()
	if saveTask then
		pcall(task.cancel, saveTask)
	end
	saveTask = task.delay(SAVE_DELAY, writeNow)
end

function Config.set(key: string, value: any): boolean
	if data[key] == value then
		return false
	end
	if value == nil and data[key] == nil then
		return false
	end
	data[key] = value
	Config.saveSoon()
	return true
end

function Config.cancelSave()
	if saveTask then
		pcall(task.cancel, saveTask)
		saveTask = nil
	end
end

function Config.flush()
	writeNow()
end

return Config

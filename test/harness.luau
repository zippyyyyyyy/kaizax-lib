-- Runtime harness for the bundled demo. Appended after Kaizax and Demo by
-- tools/bundle.mjs, so both locals are in scope.

local app = Demo(Kaizax)

local genv: any = _G
pcall(function()
	if typeof(getgenv) == "function" then
		genv = getgenv()
	end
end)

genv.KaizaxApp = app
genv.KaizaxLibrary = Kaizax

if STATE and STATE.onCleanup then
	STATE.onCleanup(function()
		genv.KaizaxApp = nil
		genv.KaizaxLibrary = nil
		pcall(function()
			Kaizax:Unload()
		end)
	end)
end

print("Kaizax demo ready", app.window.Instance:GetFullName())
return app

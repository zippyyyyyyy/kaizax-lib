-- Runtime harness for the bundled demo. Appended after Kaizax and Demo by
-- tools/bundle.mjs, so both locals are in scope.

local app = Demo(Kaizax)
local genv = getgenv()

genv.KaizaxApp = app
genv.KaizaxLibrary = Kaizax

if STATE and STATE.onCleanup then
	STATE.onCleanup(function()
		genv.KaizaxApp = nil
		genv.KaizaxLibrary = nil
		pcall(function()
			Kaizax:Destroy()
		end)
	end)
end

print("Kaizax demo ready", app.window.Instance:GetFullName())
return app

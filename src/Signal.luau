--!strict

-- Small synchronous signal used for component change notifications. Handlers
-- are isolated with pcall so one bad consumer cannot break the UI or the rest
-- of the listeners.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, handler: (...any) -> ()) -> Connection,
	Once: (self: Signal, handler: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	DisconnectAll: (self: Signal) -> (),
	ListenerCount: (self: Signal) -> number,
}

local Signal = {}

function Signal.new(): Signal
	local listeners: { [Connection]: (...any) -> () } = {}

	local signal = {} :: Signal

	function signal:Connect(handler: (...any) -> ()): Connection
		local connection = {
			Connected = true,
			Disconnect = function() end,
		} :: Connection

		function connection:Disconnect()
			if not self.Connected then
				return
			end
			self.Connected = false
			listeners[self] = nil
		end

		listeners[connection] = handler
		return connection
	end

	function signal:Once(handler: (...any) -> ()): Connection
		local connection
		connection = self:Connect(function(...)
			(connection :: Connection):Disconnect()
			handler(...)
		end)
		return connection
	end

	function signal:Fire(...: any)
		local snapshot = {}
		for connection, handler in listeners do
			if connection.Connected then
				table.insert(snapshot, { connection, handler })
			end
		end

		for _, entry in snapshot do
			local connection = entry[1] :: Connection
			local handler = entry[2] :: (...any) -> ()
			if connection.Connected then
				local ok, err = pcall(handler, ...)
				if not ok then
					warn(`[Kaizax] signal handler failed: {tostring(err)}`)
				end
			end
		end
	end

	function signal:DisconnectAll()
		for connection in listeners do
			connection.Connected = false
		end
		table.clear(listeners)
	end

	function signal:ListenerCount(): number
		local count = 0
		for connection in listeners do
			if connection.Connected then
				count += 1
			end
		end
		return count
	end

	return signal
end

return Signal

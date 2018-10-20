-- Object for managing Cleanup
-- @README https://github.com/devSparkle/Maid

local Maid = {}

-- Maid[key] = (function)				Adds a function to call at cleanup
-- Maid[key] = (Instance)				Adds an Object to be Destroyed at cleanup
-- Maid[key] = (RBXScriptConnection)	Adds a connection to be Disconnected at cleanup
-- Maid[key] = (Maid)					Maids can act as an event connection, allowing a Maid to have other maids to clean up.
-- Maid[key] = nil						Removes a named task. This cleans up the previous Maid[key]


--- Generates a new Maid object
-- @return Maid
function Maid.new()
	return setmetatable({_Tasks = {}}, Maid)
end

--- Gives the Maid a Task to perform at cleanup, incremented by 1
-- @param Variant Task An object to be Destroyed, a Connection to be Disconnected, or function/callable table to be called
-- @returns the index the Task was placed at
function Maid:GiveTask(Task)
	local n = #self._Tasks + 1
	self._Tasks[n] = Task
	return n
end

--- Makes the Maid clean up when the instance is destroyed
-- @param Instance Instance The Instance the Maid will wait for to be Destroyed
-- @returns Disconnectable table to stop Maid from being cleaned up upon Instance Destroy (automatically cleaned up by Maid, btw)
-- @author Corecii

local Disconnect = {Connected = true}
Disconnect.__index = Disconnect
function Disconnect:Disconnect()
	self.Connected = false
	self.Connection:Disconnect()
end

function Maid:LinkToInstance(Object)
	local Reference = Instance.new("ObjectValue")
	Reference.Value = Object
	-- ObjectValues have weak-like Instance references
	-- If the Instance can no longer be accessed then it can be collected despite
	-- the ObjectValue having a reference to it
	local ManualDisconnect = setmetatable({}, Disconnect)
	local Connection
	local function ChangedFunction(Obj, Par)
		if not Reference.Value then
			ManualDisconnect.Connected = false
			return self:DoCleaning()
		elseif Obj == Reference.Value and not Par then
			Obj = nil
			wait()	-- Push further execution of this script to the end of the current execution cycle.
					-- This is needed because when the event first runs it's always still Connected.
			-- The object may have been reparented or the event manually disconnected or disconnected and ran in that time...
			if (not Reference.Value or not Reference.Value.Parent) and ManualDisconnect.Connected then
				if not Connection.Connected then
					ManualDisconnect.Connected = false
					return self:DoCleaning()
				else
					-- Since this event won't fire if the instance is destroyed while in nil, we have to check
					--  often to make sure it's not destroyed. Once it's parented outside of nil we can stop doing
					--  this. We also must check to make sure it wasn't manually disconnected or disconnected and ran.
					while wait(0.2) do
						if not ManualDisconnect.Connected then
							-- Don't run func, we were disconnected manually
							return
						elseif not Connection.Connected then
							-- Otherwise, if we're disconnected it's because instance was destroyed
							ManualDisconnect.Connected = false
							return self:DoCleaning()
						elseif Reference.Value.Parent then
							-- If it's still Connected then it's not destroyed. If it has a parent then
							--  we can quit checking if it's destroyed like this.
							return
						end
					end
				end
			end
		end
	end
	Connection = Object.AncestryChanged:Connect(ChangedFunction)
	ManualDisconnect.Connection = Connection
	Object = nil
	-- If the object is currently in nil then we need to start our destroy checking loop
	-- We need to spawn a new Roblox Lua thread right now before any other code runs.
	--  spawn() starts it on the next cycle or frame, coroutines don't have ROBLOX's coroutine.yield handler
	--  The only option left is BindableEvents, which run as soon as they are called and use ROBLOX's yield
	local QuickRobloxThreadSpawner = Instance.new("BindableEvent")
	QuickRobloxThreadSpawner.Event:Connect(ChangedFunction)
	QuickRobloxThreadSpawner:Fire(Reference.Value, Reference.Value.Parent)
	QuickRobloxThreadSpawner:Destroy()
	self._Tasks[#self._Tasks + 1] = ManualDisconnect -- Give Task to Maid, cleanup this Connection upon cleanup
	return ManualDisconnect
end


--- Cleans up the Tasks assigned to the Maid
-- This Disconnects RBXScriptConnections, Destroys Instances, and calls Functions/callable Tables
function Maid:DoCleaning()
	local Tasks = self._Tasks
	for Name, Task in next, Tasks do
		local Type = typeof(Task)
		local IsTable = Type == "table"
		if Type == "RBXScriptConnection" or IsTable and Task.Disconnect then
			Task:Disconnect()
		elseif Type == "Instance" or IsTable and Task.Destroy then
			Task:Destroy()
		else
			Task()
		end
		Tasks[Name] = nil
	end
end
Maid.Disconnect = Maid.DoCleaning
Maid.Destroy = Maid.DoCleaning

--- Internal __index metamethod
function Maid:__index(i)
	return Maid[i] or self._Tasks[i]
end

--- Internal __newindex metamethod
function Maid:__newindex(i, v)
	local Tasks = self._Tasks
	local Task = Tasks[i]
	if Task or v == nil then -- Clear previous Task
		local Type = typeof(Task)
		local IsTable = Type == "table"
		if Type == "RBXScriptConnection" or IsTable and Task.Disconnect then
			Task:Disconnect()
		elseif Type == "Instance" or IsTable and Task.Destroy then
			Task:Destroy()
		end
	end
	Tasks[i] = v
end

return Maid

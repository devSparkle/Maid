--!nonstrict
--// Initialization

--[=[
	@class Maid
]=]
local Maid = {}
Maid.__index = Maid

--[=[
	@within Maid
	@type MaidTask () -> () | Instance | RBXScriptConnection | Maid | thread
	
	`MaidTask` describes all types of tasks a `Maid` instance can handle.
]=]
type MaidTask = () -> () | Instance | RBXScriptConnection | Maid | thread
type Maid = typeof(setmetatable({_Tasks = {}:: {MaidTask}}, Maid))

--// Functions

--[=[
	Creates a new instance of the Maid class.
	
	:::caution
	The Maid class cannot be used directly. First, you must create a Maid instance with `Maid.new()`
	:::
]=]
function Maid.new(): Maid
	return setmetatable({_Tasks = {}}, Maid)
end

--[=[
	Will ingest any type of [MaidTask] for later cleaning through [Maid:DoCleaning()].
]=]
function Maid:GiveTask(Task: MaidTask)
	table.insert(self._Tasks, Task)
end

--[=[
	Will listen for the provided Instance's destruction, and run [Maid:DoCleaning()] when this takes place.
	
	:::note
	During cleanup, whether invoked by the object's destruction or another method
	call; the maid will destroy any connections used to listen for destruction.
	:::
]=]
function Maid:LinkToInstance(Object: Instance)
	self:GiveTask(Object.Destroying:Connect(function()
		self:DoCleaning()
	end))
end

--[=[
	Will empty the current task table, and iterate over the previously
	given tasks and clean them up, depending on the type of [MaidTask].
	
	- Tasks of type `RBXScriptConnection`, or tables with a `Disconnect` method
	will have `::Disconnect()` called upon them.
	
	- Tasks of type `thread` will be terminated through `coroutine.close(Task)`.
	
	- Tasks of type `Instance`, or tables with a `Destroy` method will have
	`::Destroy()` called upon them.
	
	- **Any other tasks** will be called as a function.
	
	:::tip
	Because the default fallback behaviour is to call a given task like
	a function, tables with a `__call` metamethod can be given as a task.
	:::
	
	:::info
	Only tasks given up to this method's initial invocation will be cleaned,
	even if this method is still running while another task is being given.
	:::
	
	@yields
]=]
function Maid:DoCleaning()
	local Tasks = self._Tasks
	self._Tasks = {}
	
	for _, Task in next, Tasks do
		local TaskType = typeof(Task)
		local IsTable = (TaskType == "table")
		
		if TaskType == "RBXScriptConnection" or (IsTable and Task.Disconnect) then
			Task:Disconnect()
		elseif TaskType == "thread" then
			coroutine.close(Task)
		elseif TaskType == "Instance" or (IsTable and Task.Destroy) then
			Task:Destroy()
		else
			Task()
		end
	end
	
	table.clear(Tasks)
end

Maid.Disconnect = Maid.DoCleaning
Maid.Destroy = Maid.DoCleaning

return table.freeze(Maid)
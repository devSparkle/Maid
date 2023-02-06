--!nonstrict
--// Initialization

local Maid = {}
Maid.__index = Maid

type MaidTask = () -> () | Instance | RBXScriptConnection | Maid
type Maid = typeof(setmetatable({_Tasks = {}:: {MaidTask}}, Maid))

--// Functions

function Maid.new(): Maid
	return setmetatable({_Tasks = {}}, Maid)
end

function Maid:GiveTask(Task: MaidTask)
	table.insert(self._Tasks, Task)
end

function Maid:LinkToInstance(Object: Instance)
	self:GiveTask(Object)
	self:GiveTask(Object.Destroying:Connect(function()
		self:DoCleaning()
	end))
end

function Maid:DoCleaning()
	local Tasks = self._Tasks
	self._Tasks = {}
	
	for _, Task in next, Tasks do
		local TaskType = typeof(Task)
		local IsTable = (TaskType == "table")
		
		if TaskType == "RBXScriptConnection" or (IsTable and Task.Disconnect) then
			Task:Disconnect()
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
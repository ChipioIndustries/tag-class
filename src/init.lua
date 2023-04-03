--!strict
type ClassConstructor = (Instance) -> () | {new: (Instance) -> ()}

local CollectionService = game:GetService("CollectionService")

local t = require(script.Parent.t)
local Maid = require(script.Parent.Maid)
local makeStandalone = require(script.Parent.makeStandalone)

local typeCheck = t.tuple(t.string, t.union(t.callback, t.table), t.optional(t.Instance))

local TagClass = {}
TagClass.__index = TagClass

function TagClass.new(tag: string, classConstructor: ClassConstructor, scope: Instance?)
	assert(typeCheck(tag, classConstructor, scope))

	local self = setmetatable({
		_tag = tag;
		_classConstructor = classConstructor;
		_scope = scope;
		_maid = Maid.new();
		_classCache = {
			--[[
				[Instance] = object;
			]]
		};
	}, TagClass)

	self._standaloneInstanceAdded = makeStandalone(self._instanceAdded, self)
	self._standaloneInstanceRemoved = makeStandalone(self._instanceRemoved, self)

	return self
end

function TagClass:init()
	self:_handleExistingInstances()
	self:_detectNewInstances()
	self:_detectRemovingInstances()
end

function TagClass:_isWithinScope(instance: Instance): boolean
	if self._scope then
		return instance:IsDescendantOf(self._scope)
	end
	return true
end

function TagClass:_handleExistingInstances()
	for _index, instance: Instance in ipairs(CollectionService:GetTagged(self._tag)) do
		self:_instanceAdded(instance)
	end
end

function TagClass:_detectNewInstances()
	local signal = CollectionService:GetInstanceAddedSignal(self._tag)
	local connection = signal:Connect(self._standaloneInstanceAdded)
	self._maid:giveTask(connection)
end

function TagClass:_detectRemovingInstances()
	local signal = CollectionService:GetInstanceRemovedSignal(self._tag)
	local connection = signal:Connect(self._standaloneInstanceRemoved)
	self._maid:giveTask(connection)
end

function TagClass:_instanceAdded(instance: Instance)
	if self:_isWithinScope(instance) then
		local newClass = self:_constructClass(instance)
		self._classCache[instance] = newClass
	end
end

function TagClass:_constructClass(instance: Instance)
	local constructor = self._classConstructor
	if typeof(constructor) == "function" then
		return constructor(instance)
	end
	return constructor.new(instance)
end

function TagClass:_instanceRemoved(instance: Instance)
	self:_destroyInstanceClass(instance)
end

function TagClass:_destroyInstanceClass(instance: Instance)
	local existingClass = self._classCache[instance]
	if existingClass then
		existingClass:destroy()
		self._classCache[instance] = nil
	end
end

function TagClass:destroy()
	self._maid:destroy()
	for instance, _class in pairs(self._classCache) do
		self:_destroyInstanceClass(instance)
	end
end

return TagClass
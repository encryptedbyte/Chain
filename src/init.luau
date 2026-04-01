--!strict
--!optimize 2
--!native
local Types = require(script.Core.Types)

local Chain = {}

local Array = require(script.Engine.Array)
local Dictionary = require(script.Engine.Dictionary)
local DeepCopy = require(script.Util.DeepCopy)

local TYPEOF = typeof
local GETMETATABLE = getmetatable

local TABLE_CREATE = table.create

-- Alias to Chain.Array()
function Chain.new<T>(collection: {T}?) : Types.Array<T>
	return Chain.Array(collection)
end

-- Creates a new Chain Array object
-- This uses the collection as a reference. Chain may change it and changing the original collection may change the Chain.
-- Faster than Chain.ArrayFromCopy(). Useful when you do not care about the original collection.
function Chain.Array<T>(collection: {T}?) : Types.Array<T>
	return Array.new(collection)
end

-- Creates a new Chain Dictionary object
-- This uses the collection as a reference. Chain may change it and changing the original collection may change the Chain.
-- Faster than Chain.DictFromCopy(). Useful when you do not care about the original collection.
function Chain.Dict<K, V>(dictionary: {[K]: V}?) : Types.Dictionary<K, V>
	return Dictionary.new(dictionary)
end

-- Creates a new Chain Array object from a table DEEP COPIED
-- This copy the ENTIRE collection. Safer than Chain.Array() as it does not change the original collection.
-- Slower than Chain.Array(). Useful when you care about not modifying the original collection.
function Chain.ArrayFromCopy<T>(collection: {T}): Types.Array<T>
	return Array.new(DeepCopy(collection))
end

-- Creates a new Chain Dictionary object from a table DEEP COPIED
-- This copy the ENTIRE collection. Safer than Chain.Dictionary() as it does not depends on the original collection.
-- Slower than Chain.Dictionary(). Useful when you care about not modifying the original collection.
function Chain.DictFromCopy<K, V>(collection: {[K]: V}): Types.Dictionary<K, V>
	return Dictionary.new(DeepCopy(collection))
end

-- Creates a numerical Chain object from start to end
function Chain.Range(startAt: number, endAt: number, stepIter: number?): Types.Array<number>
	if TYPEOF(startAt) ~= "number" or TYPEOF(endAt) ~= "number" then
		error("Expected numbers as parameters!", 2)
	end
	
	if TYPEOF(stepIter) ~= "number" and TYPEOF(stepIter) ~= "nil" then
		error("Expected number or nil as the \"step\" parameter!", 2)
	end
	
	local stepBase = stepIter or 1
	local step = (startAt <= endAt) and stepBase or -stepBase

	local size = math.floor((endAt - startAt) / step + 1)
	local collection = TABLE_CREATE(size) :: {number}
	
	local index = 1
	for i = startAt, endAt, step do
		collection[index] = i
		index += 1
	end
	
	return Chain.new(collection)
end

-- Creates a new Chain Array object and fill it with the given value.
-- If the value is a table, it will use shallow copies to fill the array. (table.clone)
function Chain.Fill<T>(value: T, size: number): Types.Array<T>
	local isTable = TYPEOF(value) == "table"
	local collection: {T} = (
		isTable
		and TABLE_CREATE(size) 
		or TABLE_CREATE(size, value)
	)

	if isTable then
		local COPY_TABLE = table.clone
		for i = 1, size do
			collection[i] = COPY_TABLE(value)
		end
	end
	
	return Chain.new(collection)
end

--[[
This merge Chain and/or Table Arrays into a single and new Chain Array.
This method deep copies the tables/chains.

Keep in mind that it triggers the Chain pipeline (if any) to concatenate.
]]--
function Chain.Concat(...: Types.ArrayParams): Types.Array<unknown>
	local args = {...}
	local allocationSize = 0

	local chainObjects = {}

	-- Pre-allocate the table
	for _, item in ipairs(args) do
		if TYPEOF(item) ~= "table" then
			error("Parameters must be only tables.")
		end

		local metatable = GETMETATABLE(item)
		local isChain = metatable and metatable.__chain_array
		if isChain then
			chainObjects[item] = item:_Execute()
		end
		
		allocationSize += isChain and #chainObjects[item] or #item
	end

	-- Fill the table
	local finalTable = TABLE_CREATE(allocationSize) :: {unknown}
	for _, item in ipairs(args) do
		local collection = chainObjects[item] or item
		table.move(collection, 1, #collection, #finalTable + 1, finalTable)
	end

	return Chain.Array(DeepCopy(finalTable))
end

--[[
This merge Chain and/or Table Dictionaries into a single and new Chain Dictionary.
This method deep copies the tables/chains.

Keep in mind that it triggers the Chain pipeline (if any) to merge. Duplicated keys will be overriden by the last one.
]]--
function Chain.Merge(...: Types.DictParams): Types.Dictionary<unknown, unknown>
	local args = {...}

	-- Fill the table
	local finalTable = {} :: {[unknown]: unknown}
	for _, item in ipairs(args) do
		if TYPEOF(item) ~= "table" then
			error("Parameters must be only tables.")
		end

		local metatable = getmetatable(item)
		local isChain = metatable and metatable.__chain_dict

		local collection = isChain and item:_Execute() or item
		for key, value in pairs(collection) do
			finalTable[key] = value
		end
	end

	return Chain.Dict(DeepCopy(finalTable))
end

return Chain
--!optimize 2
--!native
local ServerScriptService = game:GetService("ServerScriptService")
local Core = script.Parent.Parent:WaitForChild("Core")
local Parser = require(Core.Parser)
local Types = require(Core.Types)

-- Localizing globals
local setmetatable = setmetatable
local inf = math.huge

local TABLE_INSERT = table.insert
local TABLE_CLEAR = table.clear

local RandomUp = Random
local RandomDefault = RandomUp.new()

local Chain = {}
Chain.__index = Chain
Chain.__chain_array = true

function Chain.new<T>(collection: {T}?) : Types.Array<T>
	return setmetatable({
		_collection = collection or {},
		_pipeline = {},
	}, Chain)
end

function Chain.Filter<T>(self: Types.Array<T>, query: Types.Comparison<T>)
	local predicate = Parser.GetPredicateOrThrow(query, 3)
	TABLE_INSERT(self._pipeline, {predicate, "filter"})
	return self
end

function Chain.Map<T, U>(self: Types.Array<T>, query: Types.Selection<T, U>)
	local predicate = Parser.GetPredicateOrThrow(query, 3)
	TABLE_INSERT(self._pipeline, {predicate, "map"})
	return self
end

function Chain.GroupBy<T, U>(self: Types.Array<T>, query: Types.Selection<T, U>)
	local predicate = Parser.GetPredicateOrThrow(query, 3)

	local collection = self:_Execute()
	local groups = {}

	for i = 1, #collection do
		local item = collection[i]
		local key = predicate(item)
		local targetGroup = groups[key]

		if not targetGroup then
			groups[key] = {}
			targetGroup = groups[key]
		end

		targetGroup[#targetGroup + 1] = item
	end

	return groups
end

function Chain.Flatten<T, U>(self: Types.Array<T>, query: Types.Selection<T, U>)
	local predicate = Parser.GetPredicateOrThrow(query, 3)
	local result = {}
	local resultLen = 1
	
	for _, item in ipairs(self:_Execute()) do 
		for _, tableItem in ipairs(predicate(item)) do
			result[resultLen] = tableItem
			resultLen += 1
		end
	end

	self._collection = result
	return self
end

function Chain.First<T>(self: Types.Array<T>, query: Types.Comparison<T>?)
	local predicate = Parser.GetPredicate(query)
	local pipeline = self._pipeline

    --[[
    Add it as a task to the pipeline if there is any pending task.
    It does not necessarily mean that this method is lazy. It just
    runs with other Lazy operations to avoid creating a new for loop,
    which can be 96% slower. Technically, it is still eager/terminal.
    ]]--
	if #pipeline > 0 then
		TABLE_INSERT(self._pipeline, {
			predicate or function() return true end, 
			"first"
		})

		return self:_Execute()
	end

	local collection = self._collection
	if not predicate then
		return collection[1]
	end

	for _, item in ipairs(collection) do
		if predicate(item) then
			return item
		end
	end

	return nil
end
 
function Chain.Last<T>(self: Types.Array<T>, query: Types.Comparison<T>?)
	local predicate = Parser.GetPredicate(query)
	local collection = self:_Execute()
	if not predicate then
		return collection[#collection]
	end

	if #collection > 0 then
		for i = #collection, 1, -1 do
			if predicate(collection[i]) then
				return collection[i]
			end
		end
	end

	return nil
end

function Chain.Any<T>(self: Types.Array<T>, query: Types.Comparison<T>)
	return self:First( 
		Parser.GetPredicateOrThrow(query)
	) ~= nil
end

function Chain.All<T>(self: Types.Array<T>, query: Types.Comparison<T>)
	local predicate = Parser.GetPredicateOrThrow(query, 3)

	for _, item in self:_Execute() do
		if not predicate(item) then
			return false
		end
	end

	return true
end

function Chain.Unique<T, U>(self: Types.Array<T>, query: Types.Selection<T, U>?)
	local predicate = Parser.GetPredicate(query) or function(item)
		return item
	end

	TABLE_INSERT(self._pipeline, {predicate, "unique", {}})
	return self
end

function Chain.Shuffle<T>(self: Types.Array<T>, seed: number?)
	if typeof(seed) ~= "nil" and typeof(seed) ~= "number" then
		error("Seed should be nil or a number!", 2)
	end

	local randomLib = seed and RandomUp.new(seed) or RandomDefault
	randomLib:Shuffle(self:_Execute())

	return self
end

function Chain.Reverse<T>(self: Types.Array<T>)
	local collection = self:_Execute()
	local size = #collection
	
	for i = 1, math.floor(size / 2) do
		local switchValue = collection[size-i+1]
		collection[size-i+1] = collection[i]
		collection[i] = switchValue
	end

	return self
end

function Chain.Take<T>(self: Types.Array<T>, amount: number)
	if typeof(amount) ~= "number" or amount < 0 then
		error("Invalid parameter amount. Positive number expected", 2)
	end

	TABLE_INSERT(self._pipeline, {amount, "take", 0})
	return self
end

function Chain.Skip<T>(self: Types.Array<T>, amount: number)
	if typeof(amount) ~= "number" or amount < 0 then
		error("Invalid parameter amount. Positive number expected", 2)
	end
	
	TABLE_INSERT(self._pipeline, {amount, "skip", 0})
	return self
end

function Chain.Contains<T>(self: Types.Array<T>, value: any)
	return table.find(self:_Execute(), value) ~= nil
end

function Chain.Count<T>(self: Types.Array<T>, query: Types.Comparison<T>?)
	local predicate = Parser.GetPredicate(query)
	local collection = self:_Execute()
	if not predicate then
		return #collection 
	end

	local total = 0
	for i = 1, #collection do
		if predicate(collection[i]) then
			total += 1
		end
	end

	return total
end

function Chain.Sum<T>(self: Types.Array<T>, query: Types.Selection<T, number>?)
	local predicate = Parser.GetPredicate(query) or function(x) return x end
	local collection = self:_Execute()
	
	local total = 0
	for i = 1, #collection do
		total += predicate(collection[i])
	end

	return total
end

function Chain.Min<T>(self: Types.Array<T>, query: Types.Selection<T, number>?)
	local predicate = Parser.GetPredicate(query) or function(x) return x end
	local collection = self:_Execute()
	
	local minimum = inf
	local result = nil
	for i = 1, #collection do
		local item = collection[i]
		local value = predicate(item)
		if value < minimum then
			minimum = value
			result = item
		end
	end

	return result
end

function Chain.Max<T>(self: Types.Array<T>, query: Types.Selection<T, number>?)
	local predicate = Parser.GetPredicate(query) or function(item) return item end
	local collection = self:_Execute()

	local maximum = -inf
	local result = nil
	for i = 1, #collection do
		local item = collection[i]
		local value = predicate(item)
		if value > maximum then
			maximum = value
			result = item
		end
	end

	return result
end

function Chain.Reduce<T, U>(self: Types.Array<T>, query: (acc: U, item: T) -> U, accumulator: U)
	local predicate = Parser.GetPredicateOrThrow(query, 3)

	if not accumulator then
		error("Missing accumulator for Reduce method!", 2)
	end

	local collection = self:_Execute()
	local accumulated = accumulator
	for i = 1, #collection do
		accumulated = predicate(accumulated, collection[i])
	end

	return accumulated
end

function Chain.Average<T>(self: Types.Array<T>, query: Types.Selection<T, number>?)
	local predicate = Parser.GetPredicate(query) or function(x) return x end
	
	local collection = self:_Execute()
	local collectionSize = #collection
	if collectionSize == 0 then return 0 end

	local total = 0
	for i = 1, collectionSize do
		total += predicate(collection[i])
	end

	return total / collectionSize
end

function Chain.Sort<T, U>(self: Types.Array<T>, query: Types.Selection<T, U>?)
	local predicate = Parser.GetPredicate(query)
	local collection = self:_Execute()

	if not predicate then
		table.sort(collection, function(x, y)
			return x < y
		end)
	else
		table.sort(collection, function(x, y)
			return predicate(x) < predicate(y)
		end)
	end

	return self
end

function Chain.SortDescending<T, U>(self: Types.Array<T>, query: Types.Selection<T, U>?)
	local predicate = Parser.GetPredicate(query)
	local collection = self:_Execute()

	if not predicate then
		table.sort(collection, function(x, y)
			return x > y
		end)
	else
		table.sort(collection, function(x, y)
			return predicate(x) > predicate(y)
		end)
	end

	return self
end

function Chain.ForEach<T>(self: Types.Array<T>, query: Types.Selection<T, any>)
	local predicate = Parser.GetPredicateOrThrow(query, 3)
	for _, item in ipairs(self:_Execute()) do
		predicate(item)
	end
end

function Chain.IsEmpty<T>(self: Types.Array<T>)
	return #self:_Execute() <= 0
end

function Chain.GetType<T>(self: Types.Array<T>)
	return "Array"
end

--[[
	_OptimizePipeline:
	- Attempts to pre-allocate the final table to improve insertion times.
	- Only pre-allocates if the final array size can be predicted.

	Example 1:
	    Chain.new(arr):Filter(...)
	In this case, the table size cannot be pre-allocated because 'Filter' can change the number of items.

	Example 2:
	    Chain.new(arr):Filter(...):Take(10)
	Here, the maximum size is known (10), so the table can be pre-allocated. 
	This is one of the main reasons this method exists.

	Notes / Caveats:
	- It never pre-allocate more than "collectionSize" of memory.
	- It should NEVER changes the final result. 
		It may reorder or adjust internal tasks to improve performance, 
		but if any optimization would alter the outcome, it should not be applied.
]]--
function Chain._OptimizePipeline(self: any, pipeline: {any}, collectionSize: number)
	local size = #pipeline
	local writeIndex = 1
	local finalSize = collectionSize
	local canPreAllocate = true

	for readIndex = 1, size do
		local current = pipeline[readIndex]
		local name = current[2]

		-- Optimization Logic
		if writeIndex > 1 then
			local prev = pipeline[writeIndex - 1]

			-- Merge consecutive Take/Skip
			if name == prev[2] and (name == "take" or name == "skip") then
				if name == "take" then
					prev[1] = math.min(prev[1], current[1])
				else
					prev[1] += current[1]
				end
				continue -- Skip writing this task, it's merged
			end

			-- Swap Map and Take/Skip (Commutative)
			if prev[2] == "map" and (name == "take" or name == "skip") then
				pipeline[writeIndex - 1] = current
				pipeline[writeIndex] = prev
				writeIndex += 1
				continue
			end
		end

		-- Allocation Calculation
		if canPreAllocate then
			if name == "filter" or name == "unique" then
				canPreAllocate = false
			elseif name == "take" then
				finalSize = math.min(finalSize, current[1])
			elseif name == "skip" then
				finalSize = math.max(0, finalSize - current[1])
			end
		end

		pipeline[writeIndex] = current
		writeIndex += 1
	end

	-- Clean up trailing elements if we merged tasks
	for i = writeIndex, size do
		pipeline[i] = nil
	end

	return (canPreAllocate and finalSize), writeIndex - 1
end

--[[
    This method attempts to "compile" the pipeline by unrolling the operations,
    avoiding the inner loop that interprets each step dynamically.

    Note: this does NOT change the algorithmic complexity (still O(N * M)),
    but significantly reduces constant overhead by eliminating:
    - dynamic dispatch (string/type checks)
    - table lookups per operation
    - inner iteration over the pipeline

    The trade-off is increased code size and duplication, sacrificing
    maintainability for raw performance in hot paths.
]]--
function Chain._Compile<T>(self: Types.Array<T>, pipeline: {}, collection: {T}, result: {T}): boolean
	local rlen = 0
	local pipelineSize = #pipeline
	
	if pipelineSize == 1 then
		local query1 = pipeline[1][2]
		local func1 = pipeline[1][1]
		local arg1 = pipeline[1][3]

		for _, item in ipairs(collection) do
			if query1 == "filter" then
				if not func1(item) then continue end
			elseif query1 == "map" then
				rlen += 1
				result[rlen] = func1(item)
				continue
			elseif query1 == "unique" then
				-- arg is a hash map where 'identifier' is the key
				local identifier = func1(item)
				if arg1[identifier] then continue end
				arg1[identifier] = true
			elseif query1 == "take" then
				-- arg1 is the current count and func1 is the maximum value
				if arg1 + 1 > func1 then break end
				arg1 += 1
			elseif query1 == "skip" then
				-- arg1 is the current count and func1 is the maximum value
				if arg1 + 1 <= func1 then continue end
				arg1 += 1
			elseif query1 == "first" then
				if func1(item) then return item end	
			else
				error("Not implemented response for operation: "..query1, 3)
			end

			rlen += 1
			result[rlen] = item
		end
	elseif pipelineSize == 2 then
		local query1 = pipeline[1][2]
		local func1 = pipeline[1][1]
		local arg1 = pipeline[1][3]

		local query2 = pipeline[2][2]
		local func2 = pipeline[2][1]
		local arg2 = pipeline[2][3]
	
		for _, item in ipairs(collection) do
			local finalItem = item
			
			-- ===== Task 1 =====
			if query1 == "filter" then
				if not func1(item) then continue end
			elseif query1 == "map" then
				finalItem = func1(item)
			elseif query1 == "unique" then
				-- arg is a hash map where 'identifier' is the key
				local identifier = func1(item)
				if arg1[identifier] then continue end
				arg1[identifier] = true
			elseif query1 == "take" then
				-- arg1 is the current count and func1 is the maximum value
				if arg1 + 1 > func1 then break end
				arg1 += 1
			elseif query1 == "skip" then
				-- arg1 is the current count and func1 is the maximum value
				if arg1 + 1 <= func1 then continue end
				arg1 += 1
			else
				error("Not implemented response for operation: "..query1, 3)
			end
			
			-- ===== Task 2 =====
			if query2 == "filter" then
				if not func2(finalItem) then continue end
			elseif query2 == "map" then
				finalItem = func2(finalItem)
			elseif query2 == "unique" then
				-- arg is a hash map where 'identifier' is the key
				local identifier = func2(finalItem)
				if arg2[identifier] then continue end
				arg2[identifier] = true
			elseif query2 == "take" then
				-- arg2 is the current count and func2 is the maximum value
				if arg2 + 1 > func2 then break end
				arg2 += 1
			elseif query2 == "skip" then
				-- arg2 is the current count and func2 is the maximum value
				if arg2 + 1 <= func2 then continue end
				arg2 += 1
			elseif query2 == "first" then
				if func2(finalItem) then return finalItem end	
			else
				error("Not implemented response for operation: "..query2, 3)
			end
			
			rlen += 1
			result[rlen] = finalItem
		end
	elseif pipelineSize == 3 then
		local query1 = pipeline[1][2]
		local func1 = pipeline[1][1]
		local arg1 = pipeline[1][3]

		local query2 = pipeline[2][2]
		local func2 = pipeline[2][1]
		local arg2 = pipeline[2][3]

		local query3 = pipeline[3][2]
		local func3 = pipeline[3][1]
		local arg3 = pipeline[3][3]

		for _, item in ipairs(collection) do
			local finalItem = item

			-- ===== Task 1 =====
			if query1 == "filter" then
				if not func1(item) then continue end
			elseif query1 == "map" then
				finalItem = func1(item)
			elseif query1 == "unique" then
				local identifier = func1(item)
				if arg1[identifier] then continue end
				arg1[identifier] = true
			elseif query1 == "take" then
				-- arg1 is the current count and func1 is the maximum value
				if arg1 + 1 > func1 then break end
				arg1 += 1
			elseif query1 == "skip" then
				-- arg1 is the current count and func1 is the maximum value
				if arg1 + 1 <= func1 then continue end
				arg1 += 1
			else
				error("Not implemented response for operation: "..query1, 3)
			end

			-- ===== Task 2 =====
			if query2 == "filter" then
				if not func2(finalItem) then continue end
			elseif query2 == "map" then
				finalItem = func2(finalItem)
			elseif query2 == "unique" then
				local identifier = func2(finalItem)
				if arg2[identifier] then continue end
				arg2[identifier] = true
			elseif query2 == "take" then
				-- arg2 is the current count and func2 is the maximum value
				if arg2 + 1 > func2 then break end
				arg2 += 1
			elseif query2 == "skip" then
				-- arg2 is the current count and func2 is the maximum value
				if arg2 + 1 <= func2 then continue end
				arg2 += 1
			else
				error("Not implemented response for operation: "..query2, 3)
			end

			-- ===== Task 3 =====
			if query3 == "filter" then
				if not func3(finalItem) then continue end
			elseif query3 == "map" then
				finalItem = func3(finalItem)
			elseif query3 == "unique" then
				local identifier = func3(finalItem)
				if arg3[identifier] then continue end
				arg3[identifier] = true
			elseif query3 == "take" then
				-- arg3 is the current count and func3 is the maximum value
				if arg3 + 1 > func3 then break end
				arg3 += 1
			elseif query3 == "skip" then
				-- arg3 is the current count and func3 is the maximum value
				if arg3 + 1 <= func3 then continue end
				arg3 += 1
			elseif query3 == "first" then
				if func3(finalItem) then return finalItem end
			else
				error("Not implemented response for operation: "..query3, 3)
			end

			rlen += 1
			result[rlen] = finalItem
		end
	end
	
	return rlen > 0
end

--[[
_Execute:
- Applies all pending tasks (_pipeline) to the collection (_collection).
- Supports lazy operations (Filter, Map, Unique, Skip, Take) and terminal operations.
- Optimizes performance via _OptimizePipeline (pre-allocation) and _Compile (pipeline unrolling). First optimize, then compile.
- Clears pipeline after execution.

Examples:
1) Lazy pipeline:
    local result = Chain.new(arr):Filter(cond):Map(func):ToTable()

2) Terminal operation:
    local firstItem = Chain.new(arr):Filter(cond):First()

Notes:
- Designed for speed; readability and maintainability are secondary.
]]--
function Chain._Execute<T>(self: Types.Array<T>): {T} | T?
	local collection = self._collection :: {T}
	local pipeline = self._pipeline :: {}

	local collectionSize = #collection
	local totalTasks = #pipeline

	if totalTasks == 0 or collectionSize == 0 then
		TABLE_CLEAR(pipeline)
		return collection
	end
	
	-- Optimize pipeline before the loop
	local allocationSize, newTotalTasks = self:_OptimizePipeline(pipeline, collectionSize)
	local result: {T} = allocationSize and table.create(allocationSize) or {}
	local resultLen = 1
	totalTasks = (newTotalTasks :: number)
	
	-- Tries to compile the pipeline. Can be significantly faster!
	if self:_Compile(pipeline, collection, result) then
		self._collection = result
		TABLE_CLEAR(pipeline)
		return result
	end

	-- Localize table lookups to registers
	local lastTask = pipeline[totalTasks]
	
	local isFirstTerminal = lastTask[2] == "first"
	local terminalPredicate = isFirstTerminal and lastTask[1]
	
	if terminalPredicate then -- Removes the terminal task from pipeline to reduce loop iterations
		pipeline[totalTasks] = nil 
		totalTasks -= 1 
	end

	local breakLazyLoop = false
	for _, item in ipairs(collection) do
		local finalItem = item
		local pass = true

		-- Apply the pending tasks
		for _, info in pipeline do
			local op = info[2]

			if op == "filter" then
				if not info[1](finalItem) then pass = false break end
			elseif op == "map" then
				finalItem = info[1](finalItem)
			elseif op == "unique" then
				-- info[3] is a hash map where 'identifier' is the key
				local identifier = info[1](finalItem)
				if info[3][identifier] then pass = false break end

				info[3][identifier] = true
			elseif op == "take" then
				-- info[3] is the current count
				info[3] += 1
				if info[3] > info[1] then pass = false breakLazyLoop = true break end
			elseif op == "skip" then
				-- info[3] is the current count
				info[3] += 1
				if info[3] <= info[1] then pass = false break end
			end
		end
		
		if breakLazyLoop then
			break
		end

		if pass then
			if isFirstTerminal and terminalPredicate(finalItem) then
				return finalItem
			end

			result[resultLen] = finalItem
			resultLen += 1
		end
	end

	-- Clear the pipeline pending tasks
	TABLE_CLEAR(pipeline)

	-- Handle terminal operations
	if isFirstTerminal then 
		return nil
	end

	self._collection = result

	return result
end

function Chain.ToTable<T>(self: Types.Array<T>)
	return self:_Execute()
end

return Chain :: {
	new: <T>(collection: {T}?) -> Types.Array<T>,
}
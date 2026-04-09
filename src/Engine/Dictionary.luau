--!optimize 2
--!native
local Parser = require("../Core/Types")
local Types = require("../Core/Types")

local Chain = {}
Chain.__index = Chain
Chain.__chain_dict = true

function Chain.new<K, V>(collection: {[K]: V}?) : Types.Dictionary<K, V>
	local self = setmetatable({}, Chain)
	self._collection = collection or {}
	self._pipeline = {}
	return self
end

function Chain.Filter<K, V>(self: Types.Dictionary<K, V>, query: Types.KeyValueComparison<K, V>)
	local predicate = Parser.GetPredicateOrThrow(query, 3)
	table.insert(self._pipeline, {predicate, "filter"})
	return self
end

function Chain.Map<K, V, U>(self: Types.Dictionary<K, V>, query: Types.KeyValueSelection<K, V, U>)
	local predicate = Parser.GetPredicateOrThrow(query, 3)
	table.insert(self._pipeline, {predicate, "map"})
	return self
end

function Chain.Unique<K, V, U>(self: Types.Dictionary<K, V>, query: Types.KeyValueSelection<K, V, U>?)
	local predicate = Parser.GetPredicate(query) or function(item)
		return item
	end

	table.insert(self._pipeline, {predicate, "unique", {}})
	return self
end

function Chain.Take<K, V>(self: Types.Dictionary<K, V>, amount: number)
	if typeof(amount) ~= "number" or amount < 0 then
		error("Invalid parameter amount. Positive number expected", 2)
	end

	table.insert(self._pipeline, {amount, "take", 0})
	return self
end

function Chain.Skip<K, V>(self: Types.Dictionary<K, V>, amount: number)
	if typeof(amount) ~= "number" or amount < 0 then
		error("Invalid parameter amount. Positive number expected", 2)
	end

	table.insert(self._pipeline, {amount, "skip", 0})
	return self
end

function Chain.Flatten<K, V, U>(self: Types.Dictionary<K, V>, query: Types.KeyValueSelection<K, V, U>)
	local predicate = Parser.GetPredicateOrThrow(query, 3)
	local result = {}
	local resultLen = 1

	for key, value in pairs(self:_Execute()) do
		for i, item in ipairs(predicate(key, value)) do
			result[resultLen] = item
			resultLen += 1
		end
	end

	return require("./Array").new(result)
end

function Chain.ForEach<K, V>(self: Types.Dictionary<K, V>, query: Types.KeyValueSelection<K, V, any>)
	local predicate = Parser.GetPredicateOrThrow(query, 3)
	for key, value in pairs(self:_Execute()) do
		predicate(key, value)
	end
end

function Chain.IsEmpty<K, V>(self: Types.Dictionary<K, V>)
	return next(self:_Execute()) == nil
end

function Chain.First<K, V>(self: Types.Dictionary<K, V>, query: Types.KeyValueComparison<K, V>)
	local predicate = Parser.GetPredicateOrThrow(query)
	local pipeline = self._pipeline

    --[[
    Add it to the pipeline if there is any pending task.
    It does not necessarily mean that this method is lazy. It just
    runs with other Lazy operations to avoid creating a new for loop,
    which can be 96% slower. Technically, it is still eager/terminal.
    ]]--
	if #pipeline > 0 then
		table.insert(pipeline, {predicate, "first"})
		return self:_Execute()
	end

	for key, val in pairs(self._collection) do
		if predicate(key, val) then
			return key, val
		end
	end

	return nil
end

function Chain.Any<K, V>(self: Types.Dictionary<K, V>, query: Types.KeyValueComparison<K, V>)
	return self:First( 
		Parser.GetPredicateOrThrow(query)
	) ~= nil
end

function Chain.All<K, V>(self: Types.Dictionary<K, V>, query: Types.KeyValueComparison<K, V>)
	local predicate = Parser.GetPredicateOrThrow(query, 3)

	for key, value in pairs(self:_Execute()) do
		if not predicate(key, value) then
			return false
		end
	end

	return true
end

function Chain.Contains<K, V>(self: Types.Dictionary<K, V>, key: K)
	return self:_Execute()[key] ~= nil
end

function Chain.GroupBy<K, V, U>(self: Types.Dictionary<K, V>, query: Types.KeyValueSelection<K, V, U>)
	local predicate = Parser.GetPredicateOrThrow(query, 3)

	local collection = self:_Execute()
	local groups = {}

	for key, value in pairs(collection) do
		local groupName = predicate(key, value)
		local group = groups[groupName]

		if not group then
			groups[groupName] = {}
			group = groups[groupName]
		end

		group[key] = value
	end

	return groups
end

function Chain.Count<K, V>(self: Types.Dictionary<K, V>, query: Types.KeyValueComparison<K, V>?)
	local predicate = Parser.GetPredicate(query)
	local collection = self:_Execute()

	if not predicate then
		local collectionSize = 0
		for _, _ in pairs(collection) do 
			collectionSize += 1 
		end

		return collectionSize
	end

	local total = 0
	for key, value in pairs(collection) do
		if predicate(key, value) then
			total += 1
		end
	end

	return total
end

function Chain.Sum<K, V>(self: Types.Dictionary<K, V>, query: Types.KeyValueSelection<K, V, number>)
	local predicate = Parser.GetPredicateOrThrow(query)
	local total = 0
	for key, value in pairs(self:_Execute()) do
		total += predicate(key, value)
	end

	return total
end

function Chain.Min<K, V>(self: Types.Dictionary<K, V>, query: Types.KeyValueSelection<K, V, number>)
	local predicate = Parser.GetPredicateOrThrow(query)

	local minimum = math.huge
	local resultKey, resultValue = nil, nil

	for key, value in pairs(self:_Execute()) do
		local value = predicate(key, value)
		if value < minimum then
			minimum = value
			resultKey, resultValue = key, value
		end
	end

	return resultKey, resultValue
end

function Chain.Max<K, V>(self: Types.Dictionary<K, V>, query: Types.KeyValueSelection<K, V, number>)
	local predicate = Parser.GetPredicateOrThrow(query)
	local collection = self:_Execute()

	local maximum = -math.huge
	local resultKey, resultValue = nil, nil

	for key, value in pairs(self:_Execute()) do
		local value = predicate(key, value)
		if value > maximum then
			maximum = value
			resultKey, resultValue = key, value
		end
	end

	return resultKey, resultValue
end

function Chain.Average<K, V>(self: Types.Dictionary<K, V>, query: Types.KeyValueSelection<K, V, number>)
	local predicate = Parser.GetPredicateOrThrow(query)

	local total = 0
	local collectionSize = 0
	for key, value in pairs(self:_Execute()) do
		total += predicate(key, value)
		collectionSize += 1
	end

	return total / collectionSize
end

function Chain.Reduce<K, V, U>(self: Types.Dictionary<K, V>, accumulator: U, query: (acc: U, key: K, value: V) -> U)
	local predicate = Parser.GetPredicateOrThrow(query, 3)

	if not accumulator then
		error("Missing accumulator for Reduce method!", 2)
	end

	local collection = self:_Execute()
	local accumulated = accumulator
	for key, value in pairs(collection) do
		accumulated = predicate(accumulated, key, value)
	end

	return accumulated
end

function Chain.GetType<K, V>(self: Types.Dictionary<K, V>)
	return "Dictionary"
end

--[[
	_OptimizePipeline:
	- Attempts to reorder or optimize some tasks trying to improve performance before iteration	

	Notes / Caveats:
	- It should NEVER changes the final result. 
		It may reorder or adjust internal tasks to improve performance, 
		but if any optimization would alter the outcome, it should not be applied.
]]--
function Chain._OptimizePipeline2<T>(self: any, pipeline: {any}): number
	local i = 1
	while i <= #pipeline do
		local current = pipeline[i]
		local taskName = current[2]
		local value = current[1] :: number

		-- Attempt to pull 'take' and 'skip' towards the start of the pipeline
		if taskName == "take" or taskName == "skip" then
			local prevIndex = i - 1

			if prevIndex >= 1 then
				local prev = pipeline[prevIndex]
				local prevName = prev[2]

				-- Rule: Swap with 'map' (Commutative optimization)
				if prevName == "map" then
					pipeline[prevIndex], pipeline[i] = pipeline[i], pipeline[prevIndex]
					i = i - 1 -- Step back to try bubbling the task further up
					continue

					-- Rule: Merge consecutive 'take' tasks
				elseif prevName == "take" and taskName == "take" then
					prev[1] = math.min(prev[1], value)
					table.remove(pipeline, i)
					continue

					-- Rule: Merge consecutive 'skip' tasks
				elseif prevName == "skip" and taskName == "skip" then
					prev[1] = prev[1] + value
					table.remove(pipeline, i)
					continue
				end
			end
		end

		i = i + 1
	end

	return #pipeline
end

function Chain._OptimizePipeline<T>(self: any, pipeline: {any}): number
	local size = #pipeline
	local writeIndex = 1

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

		pipeline[writeIndex] = current
		writeIndex += 1
	end

	-- Clean up trailing elements if we merged tasks
	for i = writeIndex, size do
		pipeline[i] = nil
	end

	return writeIndex - 1
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
	local pipelineSize = #pipeline

	if pipelineSize == 1 then
		local query1 = pipeline[1][2]
		local func1 = pipeline[1][1]
		local arg1 = pipeline[1][3]

		for key, value in pairs(collection) do
			if query1 == "filter" then
				if not func1(key, value) then continue end
			elseif query1 == "map" then
				local finalKey, finalValue = func1(key, value)
				result[finalKey] = finalValue
				continue
			elseif query1 == "unique" then
				-- arg is a hash map where 'identifier' is the key
				local identifier = func1(key, value)
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
				if func1(key, value) then return key, value end	
			else
				error("Not implemented response for operation: "..query1, 3)
			end

			result[key] = value
		end
	elseif pipelineSize == 2 then
		local query1 = pipeline[1][2]
		local func1 = pipeline[1][1]
		local arg1 = pipeline[1][3]

		local query2 = pipeline[2][2]
		local func2 = pipeline[2][1]
		local arg2 = pipeline[2][3]

		for key, value in pairs(collection) do
			local finalKey = key
			local finalValue = value

			-- ===== Task 1 =====
			if query1 == "filter" then
				if not func1(key, value) then continue end
			elseif query1 == "map" then
				finalKey, finalValue = func1(key, value)
			elseif query1 == "unique" then
				-- arg is a hash map where 'identifier' is the key
				local identifier = func1(key, value)
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
				if not func2(finalKey, finalValue) then continue end
			elseif query2 == "map" then
				finalKey, finalValue = func2(finalKey, finalValue)
			elseif query2 == "unique" then
				-- arg is a hash map where 'identifier' is the key
				local identifier = func2(finalKey, finalValue)
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
				if func2(finalKey, finalValue) then return finalKey, finalValue end	
			else
				error("Not implemented response for operation: "..query2, 3)
			end

			result[finalKey] = finalValue
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

		for key, value in pairs(collection) do
			local finalKey = key
			local finalValue = value

			-- ===== Task 1 =====
			if query1 == "filter" then
				if not func1(key, value) then continue end
			elseif query1 == "map" then
				finalKey, finalValue = func1(key, value)
			elseif query1 == "unique" then
				local identifier = func1(key, value)
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
				if not func2(finalKey, finalValue) then continue end
			elseif query2 == "map" then
				finalKey, finalValue = func2(finalKey, finalValue)
			elseif query2 == "unique" then
				local identifier = func2(finalKey, finalValue)
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
				if not func3(finalKey, finalValue) then continue end
			elseif query3 == "map" then
				finalKey, finalValue = func3(finalKey, finalValue)
			elseif query3 == "unique" then
				local identifier = func3(finalKey, finalValue)
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
				if func3(finalKey, finalValue) then return finalKey, finalValue end
			else
				error("Not implemented response for operation: "..query3, 3)
			end

			result[finalKey] = finalValue
		end
	end

	return pipelineSize < 4 -- Constant 4 here is because this method can "compile" only 3 tasks
end

function Chain._Execute<K, V>(self: Types.Dictionary<K, V>): {[K]: V}
	local pipeline = self._pipeline :: {}
	local collection = self._collection

	local totalTasks = self:_OptimizePipeline(pipeline)
	if totalTasks == 0 then 
		return collection 
	end

	-- Result table
	local result: {[K]: V} = {}

	-- If compiled, the final time might decrease significantly.
	if self:_Compile(pipeline, collection, result) then
		self._collection = result
		table.clear(pipeline)
		return result
	end

	-- Localize table lookups to registers
	local lastTask = pipeline[totalTasks]
	local isFirstTerminal = lastTask[2] == "first"
	local terminalPredicate = isFirstTerminal and lastTask[1] or nil
	if terminalPredicate then -- Removes the terminal task from pipeline to reduce loop iterations
		table.remove(pipeline, totalTasks) 
		totalTasks -= 1 
	end

	local breakLazyLoop = false
	for key, value in pairs(collection) do
		local finalKey, finalValue = key, value
		local pass = true

		-- Apply the pending tasks
		for _, info in pipeline do
			local op = info[2]

			if op == "filter" then
				if not info[1](finalKey, finalValue) then pass = false break end
			elseif op == "map" then
				finalKey, finalValue = info[1](finalKey, finalValue)
			elseif op == "unique" then
				-- info[3] is a hash map with the value as the key
				local result = info[1](finalKey, finalValue)
				if info[3][result] then pass = false break end

				info[3][result] = true
			elseif op == "take" then
				-- info[3] is the current count
				if info[3] + 1 > info[1] then pass = false breakLazyLoop = true break end
				info[3] += 1
			elseif op == "skip" then
				-- info[3] is the current count
				if info[3] + 1 <= info[1] then pass = false break end
				info[3] += 1
			end
		end

		if breakLazyLoop then
			break
		end

		if pass then
			if isFirstTerminal and terminalPredicate(finalKey, finalValue) then
				return finalKey, finalValue
			end

			result[finalKey] = finalValue
		end
	end

	-- Clear the pipeline pending tasks
	table.clear(pipeline)

	-- Handle terminal operations
	if isFirstTerminal then 
		return nil, nil
	end

	self._collection = result

	return result
end

function Chain.ToTable<K, V>(self: Types.Dictionary<K, V>)
	return self:_Execute()
end

return Chain :: {
	new: <K, V>(collection: {[K]: V}?) -> Types.Dictionary<K, V>,
}
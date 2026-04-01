--!strict
--!native
--!optimize 2
local Parser = {}
local Types = require(script.Parent.Types)

local MATCH = string.match
local TONUMBER = tonumber
local TYPEOF = typeof

function Parser.GetPredicate(request: Types.GenericPredicate): Types.GenericPredicate?
	local requestType = TYPEOF(request)
	if requestType == "function" then
		return request
	elseif requestType ~= "string" then
		return nil
	end

	-- Checks if it is a valid string query comparison
	local key, operator, value = MATCH(request :: string, "^%s*(%w-)%s*([><=~]=?)%s*(%w+)%s*$")
	if key and operator ~= "=" then
		local finalValue = TONUMBER(value) or value
		local keyIsEmpty = key == ""
		
		if operator == ">" then
			if keyIsEmpty then
				return function(item)
					return item > finalValue
				end
			else
				return function(item)
					return item[key] > finalValue
				end
			end
		elseif operator == "<" then
			if keyIsEmpty then
				return function(item)
					return item < finalValue
				end
			else
				return function(item)
					return item[key] < finalValue
				end
			end
		elseif operator == "==" then
			if keyIsEmpty then
				return function(item)
					return item == finalValue
				end
			else
				return function(item)
					return item[key] == finalValue
				end
			end
		elseif operator == "~=" then
			if keyIsEmpty then
				return function(item)
					return item ~= finalValue
				end
			else
				return function(item)
					return item[key] ~= finalValue
				end
			end
		elseif operator == ">=" then
			if keyIsEmpty then
				return function(item)
					return item >= finalValue
				end
			else
				return function(item)
					return item[key] >= finalValue
				end
			end
		elseif operator == "<=" then
			if keyIsEmpty then
				return function(item)
					return item <= finalValue
				end
			else
				return function(item)
					return item[key] <= finalValue
				end
			end
		end
	end
	
	-- If it is not a string query comparison, assume it is a selection.
	return function(item)
		return item[request]
	end
end

function Parser.GetPredicateOrThrow(request: Types.GenericPredicate, stackLevel: number?): Types.GenericPredicate
	return Parser.GetPredicate(request)
		or error("Parser failed. Invalid instructions", stackLevel or 2)
end

return Parser
--!native
--!optimize 2
local _setmetatable = setmetatable
local _getmetatable = getmetatable
local _type = type
local _CREATE_TABLE = table.create

local function RecursiveCopy<T>(tbl: {T}): {T}
	if _type(tbl) ~= "table" then
		return tbl
	end

	local n = #tbl
	local copy = n > 0 and _CREATE_TABLE(n) or {}
	for key, value in pairs(tbl) do
		local newKey = (_type(key) == "table") and RecursiveCopy(key) or key
		copy[newKey] = (_type(value) == "table") and RecursiveCopy(value) or value
	end

	local mt = _getmetatable(tbl)
	if mt then
		_setmetatable(copy, mt)
	end

	return copy
end

return RecursiveCopy
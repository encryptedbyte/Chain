--!native
--!optimize 2
local function RecursiveCopy<T>(tbl: {T}): {T}
	if typeof(tbl) ~= "table" then -- Only deep copies tables
		return tbl
	end

	-- Iterate over the table and deep copy it recursively
	local tableSize = #tbl
	local tableCopy: {T} = tableSize > 0 and table.create(tableSize) or {}

	for key, value in pairs(tbl) do
		local newKey = (typeof(key) == "table") and RecursiveCopy(key) or key
		local newValue = (typeof(value) == "table") and RecursiveCopy(value) or value
		tableCopy[newKey] = newValue
	end

	-- Copy the original table's metatable (if it exists)
	local mt = getmetatable(tbl)
	if mt then
		setmetatable(tableCopy, mt)
	end

	return tableCopy
end

return RecursiveCopy
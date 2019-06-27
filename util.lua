--[[

util.lua
Utility functions.

]]

return {
	-- append head array to the end of tail array in-place
	append = function(tail, head)
		if head then
			local ltail = #tail
			for i = 1, #head do
				tail[i + ltail] = head[i]
			end
		end
		return tail
	end,
	
	-- merge two tables in-place, replacing elements of old table with new
	merge = function(old, new)
		for k,v in pairs(new) do
			old[k] = new
		end
		return old
	end,
}

--[[

tokenizer.lua
Tools for tokenizing options.

]]

-- todo: make it return nil every time it can't find a match instead of nil arithmeticing after one failure

return function(input, last)
	local first, token
	last = last - 1
	return function(arg)
		if arg == nil then
			first, last, token = input:find("^(%S+)%s*", last + 1)
			return token
		-- elseif arg == false then
			-- todo: return everything from last up to end of string
		elseif arg == true then
			-- more info about the match
			return input, first, last, token
		end
	end
end

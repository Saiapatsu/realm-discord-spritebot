--[[

manual.lua
Loads images from disk and processes them offline using routines of the bot.

]]

local outsuffix = "_sprite.png"

_G.childprocess = require("childprocess")
_G.fs = require("fs")
_G.util = require("util")
context = require("context")
tokenizer = require("tokenizer")

print("\027[1mPass any options. Todo: /help\027[0m")
io.write("> ") local options = io.read()

local ctx = context.static()
if #options > 0 then
	local success, errmsg = pcall(ctx.parse, ctx, tokenizer(options, 1))
	if not success then
		p(errmsg)
		io.read()
		os.exit()
	else
		ctx = success
	end
end

local die = 0 -- count of active sprite processings

for i = 3, #args do
	die = die + 1
	local path = args[i]
	p(path)
	
	-- pick context
	local ctx = ctx
	local nameargs = path:match(";([^\\.]+)[^\\]+$")
	if nameargs then
		ctx = context.static()
		
		local success, errmsg
		
		success, errmsg = pcall(ctx.parse, ctx, tokenizer(nameargs, 1))
		if not success then
			p(errmsg)
			io.read()
			os.exit()
		end
		
		success, errmsg = pcall(ctx.parse, ctx, tokenizer(options, 1))
		if not success then
			p(errmsg)
			io.read()
			os.exit()
		end
		
		ctx = ctx:parse(tokenizer(nameargs, 1))
		ctx = ctx:parse(tokenizer(options, 1))
	end
	
	ctx:process(
		fs.readFileSync(path),
		function(data)
			if #data > 0 then
				local outpath = path:match("(.*)%.") .. outsuffix
				fs.writeFileSync(outpath, data)
				p("Wrote file " .. outpath)
			else
				p("Failed to process " .. path)
			end
			
			die = die - 1
			if die == 0 then
				print("Finished")
				os.exit()
			end
		end
	)
end

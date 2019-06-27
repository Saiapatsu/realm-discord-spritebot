--[[

commands.lua
Commands.

]]

--[[

id	snowflake	attachment id
filename	string	name of file attached
size	integer	size of file in bytes
url	string	source url of file
proxy_url	string	a proxied url of file
height	?integer	height of file (if image)
width	?integer	width of file (if image)

]]

childprocess = childprocess
https = https
context = require("context")

verbs = {}
helptopics = {} -- populated with command help and then other topics such as colors and defaults

----------------------------------------
-- Functions
----------------------------------------

function registerCommand(...)
	--[[
		arguments in order:
	*	any amount of string keywords
	*	help string
	*	command function
			arguments: message message, function nextToken
	]]
	
	local arg = {...}
	local func = table.remove(arg)
	local helpstr = table.remove(arg)
	for i = 1, #arg do
		verbs[arg[i]] = func
		helptopics[arg[i]] = helpstr
	end
end

----------------------------------------
-- Commands
----------------------------------------

-- Manual
registerCommand("help",
[[Spritebot commands:
`help`
`item`
``]],
function(message, nextToken)
	local reply = helptopics[nextToken() or "help"]
	if reply then message:reply(reply) end
end)

-- Magick a spritesheet of items
registerCommand("item",
[[.**item** [*context*]...
Decorates a sheet of 8x8 item sprites.
--------------------
Parameters:
**size** *percentage*
Same as in the game - `100` scales 5x and `80` scales 4x.
**tile** *size*
Specifies the width and height of a tile on the sheet in pixels.
**glow** {*color* | **off**}
**outline** {*color* | **off**}
Colors or removes the glow or outline.
**copy** {**on** | **off**}
Whether to append the original spritesheet below the result.]],
-- **inv**
-- Applies `size 80 zoom 100` and overlays the sprites on a mock in-game inventory.
-- --------------------
-- Default: `item size 80 tile 8`
function(message, nextToken)
	-- check and reject any non-image attachments
	-- todo
	-- dl last attachment
	local attachments = message.channel._lastAttachments
	if not attachments or #attachments == 0 then return end
	local attachment = attachments[1]
	if not (attachment.width and attachment.height) then
		p("No actual images attached")
		return
	end -- assert(..., none of the attachments are images)
	
	-- default context for sheets of non-moving sprites such as items
	local ctx = context.static()
	
	-- fill the context with command-based defaults
	-- util.merge(ctx, {etc.})
	
	-- and user-defined changes
	local success, errmsg = pcall(ctx.parse, ctx, nextToken)
	if not success then
		-- nextToken(true) returns everything it knows about its state
		-- todo: if message is long, crop it around the input
		local input, first, last, token = nextToken(true)
		-- wipe stack trace before serving
		-- todo: learn to error without trace
		local cleanerrmsg = errmsg:match("[^:]+: (.*)")
		message:reply(("%s at position %s: %s.\n`%s\n%s^`"):format(
			errmsg:match("[^:]+: (.*)"),
			first, token,
			input:gsub("`", "´"),
			(" "):rep(first and (first + last) / 2 or #input - 1)
		))
		return client:warning(("%s at position %s: %s.\n%s\n%s^"):format(
			errmsg,
			first, token,
			input,
			(" "):rep(first and (first + last) / 2 or #input - 1)
		))
	end
	
	print("Context dump:") p(ctx)
	
	-- idea todo: an attachment object may have a _monkeypatched ["data"] attribute
	-- if an online file is requested, then it is either supplied from that cache or loaded from the url
	
	-- GET the file
	local time = os.clock() -- performance monitoring
	https.get(attachment.url, function(response) -- todo: un-closure if possible
		
		-- http response goes here
		local rope = {}
		local i = 1
		
		-- fired each time a chunk is received.
		response:on("data", function(data)
			-- p("HTTP data:", data)
			rope[i] = data
			i = i + 1
		end)
		
		response:once("end", function()
			p("HTTP response time: " .. os.clock() - time)
			time = os.clock()
			
			-- send it off!
			-- todo: this is a mock pcall, use a real pcall. though errors might not propagate thru callback hell properly
			ctx:process(table.concat(rope), function(data, errmsg)
				if not data then
					 -- for when magick fails for any reason, magickal or mundane.
					print("no final data", errmsg)
				end
				
				p("Time between HTTP end and magick output: " .. os.clock() - time)
				message:reply{
					content = "Here's the sprite",
					-- todo: unique filename based on user and input filename
					file = {"sprite.png", data}
				}
			end)
		end)
	end)
	:on("error", function(failure)
		p("HTTP error:", failure)
		-- GET failure. coro? todo: test all these failure cases
	end)
end)

--[=[
-- Hello world
registerCommand("ping", "pong", "foo",
[[`ping`, `pong`, `foo`
Responds with "Pong!"]],
function(message)
	message:reply("Pong!")
end)

-- Lexer test
registerCommand("test",
[[...]],
function(message, nextToken)
	local reply = {}
	for token in nextToken do
		reply[#reply + 1] = token
	end
	message:reply(table.concat(reply, "\n"))
end)
]=]

return verbs

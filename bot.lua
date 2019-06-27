--[[

bot.bat
Makes the script available through Discord.

]]

_G.childprocess = require("childprocess")
_G.json = require("json")
_G.https = require("https")
_G.fs = require("fs")

_G.util = require("util")
_G.discordia = require("discordia")
_G.client = discordia.Client()
_G.conf = {guilds = {}, channels = {}} -- persistent state. just a whitelist rn

commands = require("commands")
tokenizer = require("tokenizer")

_G.exit = function() process:exit() end

--------------------------------------------------------------------------
--							Chat handling
--------------------------------------------------------------------------

client:on("messageCreate", function(message)
	-- Choose whether to respond to the message
	
	-- Bots are ignored
	if message.author.bot then return end
	
	-- Only work in whitelisted channels
	if not conf.channels[message.channel] then return end
	
	-- find a potential image attachment (links are ignored for now)
	if message.attachment then
		message.channel._lastAttachments = message.attachments
		-- p("Attachment found:", message.attachments)
	end
	
	-- Look for the prefix, which is .
	if message.content:sub(1, 1) ~= "." then return end
	
	-- initialize the tokenizer and use it once to find the verb
	local nextToken = tokenizer(message.content, 2)
	local verb = nextToken()
	if not verb then return end
	
	verb = commands[verb:lower()]
	if verb then
		local success, errmsg = pcall(verb, message, nextToken)
		if not success then
			client:warning(string.format("command error:\n%s", tostring(errmsg)))
		end
	end
end)

--------------------------------------------------------------------------
--								Setup
--------------------------------------------------------------------------

-- load the whitelist from a file. serialize it again if _G.exit is called
-- wholly untested except for whatever makes it work
client:once("ready", function()
	local file = assert(fs.readFileSync[[conf.json]], "conf.json missing")
	client:info(file) -- keep a backup in the log file just in case lightning strikes the laptop and sets it on fire
	local parsed, _, failure = json.parse(file)
	assert(parsed, failure)
	
	-- dereference IDs, form the conf table and add custom properties/methods. custom keys need an underscore prefix
	for guildid, guildobj in pairs(parsed.guilds) do
		local guild = client:getGuild(guildid)
		if not guild then
			client:warning("Guild could not be resolved: " .. guildid)
		else
			conf.guilds[guild] = guild
			for channelid, channelobj in pairs(guildobj.channels) do
				local channel = guild:getChannel(channelid)
				if not channel then
					client:warning("Channel could not be resolved: " .. guildid .. "/" .. channelid)
				else
					conf.channels[channel] = channel
				end
			end
		end
	end
	
	-- todo: coerce references to ids on save
	-- serialize and save state to disk on exit
	-- process:once("exit", function()
		-- -- (parsed) is the original table before being dereferenced, which won't be changed, so this is staying commented out...
		-- fs.writeFileSync([[conf.json]], json.stringify(parsed))
	-- end)
end)

client:on("ready", function()
	client:info("Logged in as " .. client.user.tag)
	client:setGame(".help")
end)

print("Press enter to start") io.read()
-- client:run(fs.readFileSync[[token]])
client:run(table.remove(args))

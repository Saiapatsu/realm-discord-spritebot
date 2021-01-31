--[[

magick.lua
Interactions with ImageMagick.

]]

local MAGICK_CONFIGURE_PATH = args[1]:match(".*\\") -- directory of the bot
-- todo: bug: ignored by manual.lua

function autocrop(ctx, data, callback)
	print("autocrop enter")
	-- suprise! autocrop!
	-- todo: test with an image of 0 width/height
	local magick = childprocess.spawn("magick", 
		{
			-- gifs can be loaded because some phone spriting applications export them for some reason
			"-[0]",
			
			-- -trim will mark as extraneous anything that's the same color as the corners. 
			-- there is no "option" that makes it only trim away transparent areas. the official
			-- and Right Way is to add a border
			"-bordercolor", ctx.cmatte or "#00000000",
			"-border", "1",
			
			-- report back the bounding box that -trim would crop to. this is used to
			-- crop the initial spritesheet and divine the image dimensions
			-- a good opportunity to return the dynamic range, too, haven't done that yet
			"-format", "%@",
			"info:-"
		},
		{env={MAGICK_CONFIGURE_PATH = MAGICK_CONFIGURE_PATH}}
	)
	
	local rope = {}
	local i = 1
	
	magick.stdout:on("data", function(data)
		print("autocrop data")
		rope[i] = data
		i = i + 1
	end)
	
	magick.stdout:once("end", function()
		print("autocrop end")
		if i == 1 then
			return callback(nil, "Autocrop failed and I can't see stderr from here")
		end
		
		return magItem(ctx, data, table.concat(rope), callback)
	end)
	
	magick.stderr:on("data", function(data)
		print("autocrop stderr:\n" .. data)
	end)
	
	magick.stdin:write(data)
	magick.stdin:_end()
end

function magItem(ctx, data, coord, callback)
	local wtile = ctx.wtile -- 8
	local htile = ctx.htile -- 8
	
	-- parse the results of the autocrop detection phase
	-- and account for the -border 1...
	local wsheet, hsheet, xcrop, ycrop = coord:match("(%d+)x(%d+)%+(%d+)%+(%d+)")
	wsheet, hsheet, xcrop, ycrop =
		math.ceil(wsheet / wtile) * wtile,
		math.ceil(hsheet / htile) * htile,
		math.floor((xcrop-1) / wtile) * wtile,
		math.floor((ycrop-1) / htile) * htile
	
	print(coord, wsheet, hsheet, xcrop, ycrop)
	
	local anim, wanim, hanim, tanim, tpsanim = ctx.anim, ctx.wanim, ctx.hanim, ctx.tanim, ctx.tpsanim
	
	local scale = ctx.scale
	
	local cglow = ctx.cglow
	local coutline = ctx.coutline
	local cbackground = ctx.cbackground
	local cmatte = ctx.cmatte
	
	local rglow = cglow and ctx.rglow or 0
	local routline = coutline and 1 or 0 -- todo: multiple outlines
	local rborder = ctx.rborder or math.max(rglow, routline)
	
	local sappend = ctx.sappend
	
	-- magick command-line arguments
	-- todo: a command that tells you the arguments instead of passing them to magick for you
	local args = ({
		-- don't ever yap into stdout
		"-quiet",
		
		a = util.append
	})
	
	-- prepare for animation
	:a(anim == "tile" and {
		"-dispose", "background",
		"-delay", (tanim or 100) .. "x" .. (tpsanim or 1000)
	})
	
	:a({
		-- read from stdout
		"-[0]",
		
		-- apply the autocrop
		"-crop", ("%sx%s+%s+%s"):format(wsheet, hsheet, xcrop, ycrop),
		"+repage"
	})
	
	-- erase matte color
	:a(cmatte and {"-transparent", cmatte})
	
	-- set the original sheet aside if the original is necessary
	:a(sappend and {"(", "+clone"})
	
	-- scale up if needed
	:a(scale ~= 1 and {"-sample", ("%sx%s"):format(wsheet * scale, hsheet * scale)})
	
	-- padding between and around the sprites
	:a(rborder > 0 and ctx:padding(rborder, wsheet, hsheet)) -- todo: make nicer
	
	-- glow
	:a(cglow and {
		-- clone the sprites, which are guaranteed to be the last layer
		"(", "+clone",
		
		-- alpha channel only
		"-channel", "A",
		
		-- two-pass box blur
		"-define", "convolve:scale=!",
		-- "-morphology", "Convolve", "Square:" .. math.floor(rglow / 2), -- any point in using 2 1d kernels instead?
		-- "-morphology", "Convolve", "Square:" ..  math.ceil(rglow / 2), -- -morphology {method}[:{iterations}] {kernel}[:[k_args}] --> use :iterations
		"-morphology", "Convolve:2", "Square:" ..  math.ceil(rglow / 2),
		
		-- adjust levels
		"-level", "0,17990", -- 0,70 on a scale from 0 to 65535
		-- "-clamp", -- necessary only in HDRI versions of ImageMagick
		"+level", "0,17990",
		
		-- colorize
		"-channel", "RGB",
		"+level-colors", cglow,
		
		-- put glow under the sprite
		")", "+swap",
	})
	
	-- outline
	:a(coutline and {
		-- clone the sprites, which are guaranteed to be the last layer
		"(", "+clone",
		
		"-morphology", "EdgeOut", "Square", -- Dilate is also a good fit here
		
		-- colorize and alphaize
		"-channel", "RGB",
		"+level-colors", coutline,
		"-channel", "A",
		"+level", "0,52428", -- 0,204
		
		-- put outline under the sprite and above the glow
		")", "+swap",
	})
	
	-- merge and output
	:a({
		"-compose", "Over",
		"-background", cbackground or "#00000000", -- user-set bg here. cbackground or "#00000000"
		"-layers", "flatten",
	})
	
	-- animate. other half is above
	-- todo
	-- https://legacy.imagemagick.org/discourse-server/viewtopic.php?t=33797
	-- https://stackoverflow.com/questions/49488629/append-two-gifs-side-by-side-with-imagemagick-on-windows
	-- https://legacy.imagemagick.org/Usage/anim_mods/#composite_single
	:a(anim == "tile" and {
		"-crop", (wanim and wanim * 56 or "") .. "x" .. (hanim and hanim * 56 or ""),
		"+repage",
		"-alpha", "remove"
	})
	
	-- append the original sheet
	:a(sappend and {")", "+swap", wsheet >= hsheet and "-append" or "+append"})
	
	-- output to stdout
	:a({anim and "gif:-" or "png32:-"}) -- todo: choose png24 if there is a background
	
	args.a = nil
	
	print("Args dump:") p(args)
	
	local magick = childprocess.spawn("magick", args, {env={MAGICK_CONFIGURE_PATH = MAGICK_CONFIGURE_PATH}})
	local rope = {}
	local i = 1
	
	magick.stdout:on("data", function(data)
		rope[i] = data
		i = i + 1
	end)
	
	magick.stdout:once("end", coroutine.wrap(function()
		print("magick end")
		if i == 1 then
			return callback(nil, "magick failed") -- big stinky
		end
		
		return callback(table.concat(rope))
	end))
	
	magick.stderr:on("data", function(data)
		print("magick2 stderr:\n" .. data)
		-- Reply with an error (give it a coroutine as well)
		-- don't forget to only fire on stderr end, not data
	end)
	
	magick.stdin:write(data)
	magick.stdin:_end()
	
	-- Note: Luvit does not check whether Content-Length and the length of the body which has been transmitted are equal or not.
end

return autocrop
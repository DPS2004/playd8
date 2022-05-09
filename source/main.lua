--playd8

pda = import "pda"

loc = import "loc"

pda:setPlatform('playdate')

loc:load('localization.json')


nacho = import "nacho"




if pda.platform == 'playdate' then
	import "CoreLibs/graphics"
	import "CoreLibs/math"

	playdate.display.setRefreshRate(50)
	
	
	bit = (import "bitops/funcs")

	local oldbor = bit.bor

	bit.bor = function(x,y)
		--terrible hack, please fix!
		x |= y
		return x
	end
	
	nacho.setup(true,bit)
	
end


function loadrom(path,chip)
	local romfile = playdate.file.open(path,playdate.file.kFileRead)
	local rom,romsize = romfile:read(4096)
	for i=1,romsize do
		local byte = string.byte(string.sub(rom,i,i))
		chip.mem[0x200+(i-1)] = byte
    end
end

chipdraw = {
	scale = 3,
	x = 206,
	y = 2
}

function updatechip()
	chip.timerdec()
	local bonusframes = 0
	if chip.cf.dotimedupdate then
		local ops = chip.timedupdate()
	else
		leftoverinstructions = leftoverinstructions + chip.cf.ips % 50
		if leftoverinstructions >= 50 then
			bonusframes = math.floor(leftoverinstructions / 50)
			leftoverinstructions = leftoverinstructions - (bonusframes * 50)
		end
		
		for i=1,math.floor(chip.cf.ips/50) do
			chip.update()
		end
	end
end

function drawchip(force)
	pda:color(0)
	pda:rectfill(chipdraw.x,chipdraw.y,64*chipdraw.scale,32*chipdraw.scale)
	if chip.screenupdated or force then
		pda:color(1)
		for x=0,chip.cf.sw-1 do
			for y=0,chip.cf.sw-1 do
				if chip.display[x][y] then
					playdate.graphics.fillRect(x*chipdraw.scale + chipdraw.x ,y*chipdraw.scale + chipdraw.y ,chipdraw.scale,chipdraw.scale)
				end
			end
		end
	end
end

mainfont = pda:newFont('dos')
pda:setFont(mainfont)

--0 = lua
--1 = image
--2 = sample

statestoload = {

}

gfxtoload = {
	
}

audiotoload = {
	
}





function loadassets(tb,cpath)
	local newtab = {}
	for k,v in pairs(tb) do
		if v == 0 then
			print('not on playdate, sorry!')
		elseif v == 1 then
			local txtpath = ''
			for _i,_v in ipairs(cpath) do
				txtpath = txtpath .. _v .. '/'
			end
			txtpath = txtpath ..k .. '.png'
			print('loading image '..txtpath)
			newtab[k] = pda:newImage(txtpath)
		elseif v == 2 then
			local txtpath = ''
			for _i,_v in ipairs(cpath) do
				txtpath = txtpath .. _v .. '/'
			end
			txtpath = txtpath ..k .. '.wav'
			print('loading audio '..txtpath)
			newtab[k] = playdate.sound.sampleplayer.new(txtpath)
		else
			local newcpath = {}
			for _i,_v in ipairs(cpath) do
				table.insert(newcpath,_v)
			end
			table.insert(newcpath,k)
				
			newtab[k] = loadassets(v,newcpath)
		end
	end
	return newtab
end

states = {
	boot = import 'states/boot',
	romselect = import 'states/romselect'
}

gfx = loadassets(gfxtoload,{'gfx'})
audio = loadassets(audiotoload,{'audio'})


function changestate(s)
	cstate = s
	states[cstate]:init()
	states[cstate]:update(dt)
end

cstate = 'romselect'
states[cstate]:init()


function playdate.update()
	dt = playdate.getElapsedTime() * 60
	playdate.resetElapsedTime()
	
	states[cstate]:update(dt)
	
	states[cstate]:draw()
end
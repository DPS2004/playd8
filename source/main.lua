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
	y = 2,
	dscale = 3,
	dx = 206,
	dy = 2
}

function chipinput()
	for k,v in pairs(loadedrom.keys) do
		if v ~= -1 then
			if pda:btnp(k) then
				chip.keys[v].pressed = true
				chip.keys[v].down = true
			end
			
			if pda:btnr(k) then
				chip.keys[v].down = false
				chip.keys[v].released = true
			end
		end
	end
end

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
	
	
	for i=0,15 do
		chip.keys[i].pressed = false
		chip.keys[i].released = false
	end
	
end

function drawchip(force)
	
	chipdraw.dscale = (chipdraw.dscale*3 + chipdraw.scale) / 4
	chipdraw.dx = (chipdraw.dx*3 + chipdraw.x) / 4
	chipdraw.dy = (chipdraw.dy*3 + chipdraw.y) / 4
	
	pda:color(0)
	
	if chip.screenupdated or force then
		pda:rectfill(chipdraw.dx,chipdraw.dy,64*chipdraw.dscale,32*chipdraw.dscale)
		pda:color(1)
		for x=0,chip.cf.sw-1 do
			for y=0,chip.cf.sw-1 do
				if chip.display[x][y] then
					playdate.graphics.fillRect(x*chipdraw.dscale + chipdraw.dx ,y*chipdraw.dscale + chipdraw.dy ,chipdraw.dscale,chipdraw.dscale)
				end
			end
		end
		chip.screenupdated = false
	end
end

keypad = {
	x = -72,
	y = 240,
	dx = -72,
	dy = 240,
	cx = 0,
	cy = 0,
	dcx = 0,
	dcy = 0,
}

function updatekeypad()
	
end

function drawkeypad()

	keypad.dx = (keypad.dx*3 + keypad.x)/4
	keypad.dy = (keypad.dy*3 + keypad.y)/4
	keypad.dcx = (keypad.dcx*2 + keypad.cx)/3
	keypad.dcy = (keypad.dcy*2 + keypad.cy)/3
	if keypad.dy < 239 then
		
		gfx.keypad:draw(keypad.dx,keypad.dy)
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
	keypad = 1,
	cursor_pressed = 1,
	cursor_released = 1
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
	romselect = import 'states/romselect',
	play = import 'states/play'
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
playdate.gameWillPause = function()
	local menu = playdate.getSystemMenu()
	menu:removeAllMenuItems()
	if states[cstate].onpause then
		states[cstate]:onpause(menu)
	end
end


function playdate.update()
	dt = playdate.getElapsedTime() * 60
	playdate.resetElapsedTime()
	
	states[cstate]:update(dt)
	
	states[cstate]:draw()
end
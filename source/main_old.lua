print('hi from playdate')

nacho = import "nacho"

bit = (import "bitops/funcs")

local oldbor = bit.bor

bit.bor = function(x,y)
	--terrible hack, please fix!
	x |= y
	return x
end

nacho.setup(true,bit)

print('loaded')

function loadrom(path,chip)
	local romfile = playdate.file.open(path,playdate.file.kFileRead)
	local rom,romsize = romfile:read(4096)
	for i=1,romsize do
		local byte = string.byte(string.sub(rom,i,i))
		chip.mem[0x200+(i-1)] = byte
    end
end

chip = nacho.init()

loadrom('roms/test_opcode.ch8',chip)

leftoverinstructions = 0

screenscale = 6

playdate.graphics.clear(playdate.graphics.kColorBlack)

function playdate.update()
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
  
	if chip.screenupdated then
		playdate.graphics.clear(playdate.graphics.kColorBlack)
		playdate.graphics.setColor(playdate.graphics.kColorWhite)
		for x=0,chip.cf.sw-1 do
			for y=0,chip.cf.sw-1 do
				if chip.display[x][y] then
					playdate.graphics.fillRect(x*screenscale,y*screenscale,screenscale,screenscale)
				end
			end
		end
	end
	
end
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



playdate.graphics.clear(playdate.graphics.kColorBlack)

function playdate.update()
	chip.timerdec()
	local bonusframes = 0
	leftoverinstructions = leftoverinstructions + chip.cf.ips % 60
	if leftoverinstructions >= 60 then
		bonusframes = math.floor(leftoverinstructions / 60)
		leftoverinstructions = leftoverinstructions - (bonusframes * 60)
	end
	for i=1,math.floor(chip.cf.ips/60) do
		chip.update()
	end
	
	if chip.screenupdated then
		playdate.graphics.clear(playdate.graphics.kColorBlack)
		playdate.graphics.setColor(playdate.graphics.kColorWhite)
		for x=0,chip.cf.sw-1 do
			for y=0,chip.cf.sw-1 do
				if chip.display[x][y] then
					playdate.graphics.fillRect(x*4,y*4,4,4)
				end
			end
		end
	end
	
end
local state = {}

function state:init()
	transitioning = true

end

function state:update(dt)
	chipinput()
	updatechip()
	
	if chipdraw.dx < 8.5 then
		chipdraw.dx = 8
		chipdraw.dy = 8
		chipdraw.dscale = 6
		transitioning = false
	end
	
	if not transitioning then
	
	end

end

function state:onpause(menu)
	menu:addMenuItem('To ROM select',function()
		transitioning = true
		changestate('romselect')
		chipdraw.scale = 3
		chipdraw.x = 206
		chipdraw.y = 2
		keypad.x = -72
		keypad.y = 240
	end)
end

function state:draw()
	if transitioning then
		pda:cls(0)
	end
	drawchip(transitioning)
	drawkeypad()

end

return state
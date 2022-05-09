local state = {}

function state:init()
	self.timer = 0
	print('boot init')
end

function state:update(dt)
	self.timer = self.timer + dt
	
	if pda:btnp('a') then
		--changestate('game')
	end
end

function state:draw()
	pda:cls(0)
	pda:color(1)
	pda:print('PLAYD8',200,105,true)
end

return state
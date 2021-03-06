local state = {}

function state:init()
	romdatabase = json.decodeFile('roms/database.json')
	
	for i,v in ipairs(playdate.file.listFiles('roms/')) do
		local indb = false
		for _i, _v in ipairs(romdatabase) do
			if _v.filename == v then
				indb = true
				break
			end
		end
		if not indb then
			if v ~= "database.json" then
				table.insert(romdatabase,{
					filename = v, 
					name = v, 
					author = '???',
					description = '',
					mode = "cosmac",
					keys = {
						u = -1,
						d = -1,
						l = -1,
						r = -1,
						a = -1,
						b = -1
					},
					showkeypad = true
				})
			end
		
		end
	end
	
	self.selection = 0
	self.dselection = 0
	
	if not loadedrom then
		chip = nacho.init(romdatabase[self.selection+1].mode)
		loadrom('roms/'..romdatabase[self.selection+1].filename,chip)
		loadedrom = romdatabase[self.selection+1]
		selectedrom = self.selection
	else
		self.selection = selectedrom
		self.dselection = selectedrom
	end
end

function state:update(dt)
	
	local updatescreen = false
	
	if pda:btnp('up') then
		self.selection = (self.selection - 1)% #romdatabase
		updatescreen = true
	end
	
	if pda:btnp('down') then
		self.selection = (self.selection + 1)% #romdatabase
		updatescreen = true
	end
	
	if updatescreen then
		loadedrom = romdatabase[self.selection+1]
		chip = nacho.init(romdatabase[self.selection+1].mode)
		loadrom('roms/'..romdatabase[self.selection+1].filename,chip)
		selectedrom = self.selection
	end
	
	if pda:btnp('a') then
		
		if loadedrom.showkeypad then
			chipdraw.x = 40
			chipdraw.y = 8
			chipdraw.scale = 5
			keypad.x = 0
			keypad.y = 168
		else
			chipdraw.x = 8
			chipdraw.y = 8
			chipdraw.scale = 6
		end
	
		changestate('play')
	end
	
	
	updatechip()
	
	self.dselection = (self.dselection * 3 + self.selection) / 4

end

function state:draw()
	pda:cls(0)
	pda:color(1)
	for i,v in ipairs(romdatabase) do
		if i - 1 == self.selection then
			pda:print('> '.. v.name,1,12 * (i - self.dselection +8))
			local desctext = v.name .. '\nBy ' .. v.author .. '\n\n' .. v.description
			pda:rectprint(desctext,202,100,196,138)
		else
			pda:print('  '.. v.name,1,12 * (i - self.dselection +8))
		end
		
	end
	drawchip(true)
	drawkeypad()
end

return state
local pda = {
	crank = {
		angle = 0,
		dangle = 0,
		d = 0,
		ad = 0
	}
}

function pda:setPlatform(x)
	self.platform = x
	print('set platform to ' .. x)
end

function pda:cls(c)
	if self.platform == 'playdate' then
		if c == 1 then
			playdate.graphics.clear(playdate.graphics.kColorWhite)
		else
			playdate.graphics.clear(playdate.graphics.kColorBlack)
		end
	end
end

function pda:initCrank()
	if self.platform == 'playdate' then
		self.crank.angle = playdate.getCrankPosition()
		self.crank.dangle = playdate.getCrankPosition()
		playdate.cranked = function(c, ac)
			self.crank.angle = self.crank.angle + c
			self.crank.dangle = self.crank.dangle + ac
			self.crank.d = c
			self.crank.ad = ac
		
		end
	end
end

function pda:newFont(i)
	if self.platform == 'playdate' then
		return playdate.graphics.font.new(i)
	end

end
function pda:setFont(f)
	if self.platform == 'playdate' then
		playdate.graphics.setFont(f)
	end

end

function pda:newImage(i)
	if self.platform == 'playdate' then
		return playdate.graphics.image.new(i)
	end

end

function pda:color(c)
	self.c = c
	if self.platform == 'playdate' then
		if c == 1 then
			playdate.graphics.setColor(playdate.graphics.kColorWhite)
		elseif c == 2 then
			playdate.graphics.setColor(playdate.graphics.kColorClear)
		else
			playdate.graphics.setColor(playdate.graphics.kColorBlack)
		end
	end
end

function pda:lineWidth(w)
	if self.platform == 'playdate' then
		playdate.graphics.setLineWidth(w-1)
	end
end

function pda:circ(x,y,r)
	if self.platform == 'playdate' then
		playdate.graphics.drawCircleAtPoint(x,y,r)
	end
end

function pda:circfill(x,y,r)
	if self.platform == 'playdate' then
		playdate.graphics.fillCircleAtPoint(x,y,r)
	end
end

function pda:rect(x,y,w,h)
	if self.platform == 'playdate' then
		playdate.graphics.drawRect(x,y,w,h)
	end
end

function pda:rectfill(x,y,w,h)
	if self.platform == 'playdate' then
		playdate.graphics.fillRect(x,y,w,h)
	end
end

function pda:btnp(b) 
	if self.platform == 'playdate' then
		return playdate.buttonJustPressed(b)
	end
end
function pda:btn(b) 
	if self.platform == 'playdate' then
		return playdate.buttonIsPressed(b)
	end
end

function pda:print(t,x,y,c)
	if self.platform == 'playdate' then
		if self.c == 1 then
			playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeFillWhite)
		end
		
		if c then
			playdate.graphics.drawTextAligned(t,x,y,kTextAlignment.center)
		else
			playdate.graphics.drawText(t,x,y)
		end
		
		if self.c == 1 then
			playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeCopy)
		end
	end
end

function pda:rectprint(t,x,y,w,h)
	if self.platform == 'playdate' then
		if self.c == 1 then
			playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeFillWhite)
		end
		
		playdate.graphics.drawTextInRect(t, x, y, w, h)
		
		if self.c == 1 then
			playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeCopy)
		end
	end
end


return pda
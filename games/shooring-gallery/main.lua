function love.load()
	target = {}
	target.x = 250
	target.y = 250
	target.radius = 50

	gameState = 1

	score = 0
	timer = 0

	gameFont = love.graphics.newFont(40)

	sprites = {}
	sounds = {}

	gunshot = love.audio.newSource("gunshot.wav", "static")
	gunshot:setVolume(0.5)

	sprites.sky = love.graphics.newImage("sky.png")
	sprites.target = love.graphics.newImage("target.png")
	sprites.crosshairs = love.graphics.newImage("crosshairs.png")

	love.mouse.setVisible(false)
end

-- runs 60 times per second, because LOVE runs 60 fps per second (on average)
function love.update(dt)
	if (timer > 0) then
		timer = timer - dt
		if timer < 0 then
			gameState = 1
			timer = 0
			score = 0
		end
	end
end

function love.draw()
	love.graphics.draw(sprites.sky, 0, 0)
	love.graphics.setColor(1, 1, 1)
	love.graphics.setFont(gameFont)
	love.graphics.print("Score: " .. score, 5, 0)
	love.graphics.print("Time: " .. math.ceil(timer), 250, 0)

	if gameState == 1 then
		love.graphics.printf("Click to start a game", 0, 250, love.graphics.getWidth(), "center")
	end

	if gameState == 2 then
		love.graphics.draw(sprites.target, target.x - target.radius, target.y - target.radius)
	end

	love.graphics.draw(sprites.crosshairs, love.mouse.getX() - 20, love.mouse.getY() - 20)
end

function love.mousepressed(x, y, button, istouch, presses)
	if button == 1 and gameState == 2 then
		gunshot:play()
		local mouseToTarget = distanceBetween(x, y, target.x, target.y)

		if mouseToTarget < target.radius then
			score = score + 1

			target.x = math.random(target.radius, love.graphics.getWidth() - target.radius)
			target.y = math.random(target.radius, love.graphics.getHeight() - target.radius)
		end
	elseif gameState == 1 then
		timer = 10
		gameState = 2
	end
end

function distanceBetween(x1, y1, x2, y2)
	local distance = math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)

	return distance
end

function love.load()
  gameState = 1
  maxTime = 2
  timer = maxTime
  score = 0
  sprites = {}
  sprites.background = love.graphics.newImage("background.png")
  sprites.bullet = love.graphics.newImage("bullet.png")
  sprites.player = love.graphics.newImage("player.png")
  sprites.zombie = love.graphics.newImage("zombie.png")

  player = {}
  zombies = {}
  player.x = love.graphics.getWidth() / 2
  player.y = love.graphics.getHeight() / 2
  player.speed = 300
  player.rotation = 0

  bullets = {}
end

function love.update(dt)
  if gameState == 2 then
    if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
      player.x = player.x + player.speed * dt
    end
    if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
      player.x = player.x - player.speed * dt
    end
    if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
      player.y = player.y - player.speed * dt
    end
    if love.keyboard.isDown("s") or love.keyboard.isDown("down") then
      player.y = player.y + player.speed * dt
    end
  end


  local w, h = love.graphics.getDimensions()
  player.x = math.max(0, math.min(w, player.x))
  player.y = math.max(0, math.min(h, player.y))

  player.rotation = player.rotation + 0.01

  for i, z in ipairs(zombies) do
    z.y = z.y + math.sin(zombiePlayerAngle(z)) * z.speed * dt
    z.x = z.x + math.cos(zombiePlayerAngle(z)) * z.speed * dt

    if distanceBetween(z.x, z.y, player.x, player.y) < 30 then
      for index, value in ipairs(zombies) do
        zombies[index] = nil
        gameState = 1
      end
    end
  end

  for i, b in ipairs(bullets) do
    b.y = b.y + math.sin(b.direction) * b.speed * dt
    b.x = b.x + math.cos(b.direction) * b.speed * dt
  end


  for i = #bullets, 1, -1 do
    local b = bullets[i]

    if b.x > love.graphics.getWidth() or b.y > love.graphics.getHeight() then
      table.remove(bullets, i)
    end
  end

  for i, z in ipairs(zombies) do
    for j, b in ipairs(bullets) do
      if (distanceBetween(z.x, z.y, b.x, b.y)) < 20 then
        z.dead = true
        b.dead = true
        score = score + 1
      end
    end
  end

  for i = #zombies, 1, -1 do
    local z = zombies[i]

    if z.dead == true then
      table.remove(zombies, i)
    end
  end

  for i = #bullets, 1, -1 do
    local z = bullets[i]

    if z.dead == true then
      table.remove(bullets, i)
    end
  end

  if gameState == 2 then
    timer = timer - dt
    if timer <= 0 then
      spawnZombie()
      maxTime = 0.95 * maxTime
      timer = maxTime
      score = 0
    end
  end
end

function love.draw()
  love.graphics.draw(sprites.background, 0, 0)

  if gameState == 1 then
    love.graphics.printf("Click anywhere to begin!", 0, 50, love.graphics.getWidth(), "center")
  end

  love.graphics.printf("Score; " .. score, 0, love.graphics.getHeight() - 100, love.graphics.getWidth(), "center")

  love.graphics.draw(sprites.player, player.x, player.y, playerMouseAngle(), 1, 1, sprites.player:getWidth() / 2,
    sprites.player:getHeight() / 2)

  for i, z in ipairs(zombies) do
    love.graphics.draw(sprites.zombie, z.x, z.y, zombiePlayerAngle(z), 1, 1, sprites.zombie:getWidth() / 2,
      sprites.zombie:getHeight() / 2)
  end

  for i, b, value in ipairs(bullets) do
    love.graphics.draw(sprites.bullet, b.x, b.y, b.direction, 0.35, 0.35, sprites.bullet:getWidth() / 2,
      sprites.bullet:getHeight() / 2)
  end
end

function love.keypressed(key)
  if (key == "space") then
    spawnZombie()
  end
end

function love.mousepressed(x, y, button)
  if button == 1 and gameState == 2 then
    spawnBullet()
  elseif button == 1 and gameState == 1 then
    gameState = 2
    maxTime = 2
    timer = maxTime
  end
end

function playerMouseAngle()
  return math.atan2(player.y - love.mouse.getY(), player.x - love.mouse.getX()) + math.pi
end

function zombiePlayerAngle(enemy)
  return math.atan2(player.y - enemy.y, player.x - enemy.x)
end

function spawnZombie()
  local zombie = {}
  zombie.x = math.random(0, love.graphics.getWidth())
  zombie.y = math.random(0, love.graphics.getHeight())
  zombie.speed = math.random(10, 100)
  zombie.dead = false
  table.insert(zombies, zombie);
end

function distanceBetween(x1, y1, x2, y2)
  local distance = math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)

  return distance
end

function spawnBullet()
  local bullet = {}

  bullet.x = player.x
  bullet.y = player.y
  bullet.dead = false
  bullet.speed = 500
  bullet.direction = playerMouseAngle()
  table.insert(bullets, bullet)
end

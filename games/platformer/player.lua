player = world:newRectangleCollider(360, 100, 40, 100, { collision_class = "Player" })
player.speed = 240
player.grounded = true
player.animation = animations.idle
player.isMoving = false
player.direction = 1
player:setFixedRotation(true)


function playerUpdate(dt)
  if not player or not player.body then
    return -- or show "Press R to restart" etc.
  end

  player.isMoving = false

  local colliders = world:queryRectangleArea(
    player:getX() - 20,
    player:getY() + 45, -- slightly above bottom
    40, 10, { "Platform" }
  )

  if #colliders > 0 then
    player.grounded = true
  else
    player.grounded = false
  end
  local px, py = player:getPosition()
  if love.keyboard.isDown('right') then
    player.isMoving = true
    player.direction = 1
    player:setX(px + player.speed * dt)
  end
  if love.keyboard.isDown('left') then
    player.isMoving = true
    player:setX(px - player.speed * dt)
    player.direction = -1
  end

  if player:enter("Danger") then
    print("Player died!")
    player:destroy()
  end

  if player.grounded then
    if player.isMoving then
      player.animation = animations.run
    else
      player.animation = animations.idle
    end
  else
    player.animation = animations.jump
  end

  player.animation:update(dt)


  if player:enter("Danger") then
    print("Player died!")
    player:destroy()
    player = nil -- ← important to prevent further access
  end
end


function drawPlayer()
  local px, py = player:getPosition()

  player.animation:draw(sprites.playerSheet, px, py, nil, 0.25 * player.direction, 0.25, 130, 300)
end
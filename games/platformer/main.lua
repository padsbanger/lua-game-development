function love.load()
  anim8 = require 'anim8/anim8'
  wf = require 'windfield/windfield'
  sti = require('sti/sti')
  cameraFile = require('hump/camera')

  cam = cameraFile()
  sprites = {}
  sprites.playerSheet = love.graphics.newImage('playerSheet.png')

  local grid = anim8.newGrid(614, 564, sprites.playerSheet:getWidth(), sprites.playerSheet:getHeight())

  animations = {}

  animations.idle = anim8.newAnimation(grid('1-15', 1), 0.035)
  animations.jump = anim8.newAnimation(grid('1-7', 2), 0.035)
  animations.run = anim8.newAnimation(grid('1-15', 3), 0.035)

  world = wf.newWorld(0, 800, false)
  world:setQueryDebugDrawing(true)

  world:addCollisionClass("Player")
  world:addCollisionClass("Platform")
  world:addCollisionClass("Danger")

  require('player')


  -- dangerZone = world:newRectangleCollider(0, 550, 800, 50, { collision_class = "Danger" })
  -- dangerZone:setType("static")

  platforms = {}

  loadMap()
end

function love.update(dt)
  world:update(dt)
  gameMap:update(dt)
  playerUpdate(dt)
  local px, py = player:getPosition()
  cam:lookAt(px, love.graphics.getHeight() / 2)
end

function love.draw()
  cam:attach()
  gameMap:drawLayer(gameMap.layers["Tile Layer 1"])
  world:draw()
  drawPlayer()
  cam:detach()
end

function love.keypressed(key)
  if key == 'up' then
    if player.grounded then
      player.animation = animations.jump
      player:applyLinearImpulse(0, -4500) -- tune this value
    end
  end
end

function spawnPlatform(x, y, width, height)
  if width > 0 and height > 0 then
    local platform = world:newRectangleCollider(x, y, width, height, { collision_class = "Platform" })
    platform:setType("static")

    table.insert(platforms, platform)
  end
end

function loadMap()
  gameMap = sti('level1.lua')
  for i, obj in pairs(gameMap.layers["Platforms"].objects) do
    spawnPlatform(obj.x, obj.y, obj.width, obj.height)
  end
end

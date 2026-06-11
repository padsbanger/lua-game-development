local lg = love.graphics
local lk = love.keyboard
local lm = love.mouse
local lf = love.filesystem

local TAU = math.pi * 2

local game = {}
local player = {}
local bullets = {}
local enemies = {}
local cores = {}
local particles = {}
local stars = {}
local sprites = {}

local score = 0
local highScore = 0
local elapsed = 0
local combo = 1
local comboTimer = 0
local spawnTimer = 0
local messageTimer = 0
local shake = 0
local paused = false
local gameOver = false

local function clamp(value, low, high)
  return math.max(low, math.min(high, value))
end

local function length(x, y)
  return math.sqrt(x * x + y * y)
end

local function angleOf(y, x)
  if math.atan2 then
    return math.atan2(y, x)
  end
  return math.atan(y, x)
end

local function normalize(x, y)
  local len = length(x, y)
  if len == 0 then
    return 1, 0
  end
  return x / len, y / len
end

local function distanceSquared(ax, ay, bx, by)
  local dx = ax - bx
  local dy = ay - by
  return dx * dx + dy * dy
end

local function randomRange(low, high)
  return low + love.math.random() * (high - low)
end

local function currentDifficulty()
  return 1 + elapsed / 42
end

local function saveHighScore()
  if score > highScore then
    highScore = score
    lf.write("highscore.txt", tostring(highScore))
  end
end

local function loadHighScore()
  if lf.getInfo("highscore.txt") then
    highScore = tonumber(lf.read("highscore.txt")) or 0
  end
end

local function makeCanvas(size, draw)
  local canvas = lg.newCanvas(size, size)
  lg.push("all")
  lg.setCanvas(canvas)
  lg.clear(0, 0, 0, 0)
  draw(size)
  lg.setCanvas()
  lg.pop()
  return canvas
end

local function buildSprites()
  sprites.ship = makeCanvas(64, function(size)
    local c = size / 2

    lg.setColor(0.1, 0.95, 0.78, 0.23)
    lg.circle("fill", c, c + 2, 25)

    lg.setColor(0.93, 0.96, 0.9)
    lg.polygon("fill", c + 25, c, c - 18, c - 16, c - 8, c, c - 18, c + 16)

    lg.setColor(0.09, 0.74, 0.76)
    lg.polygon("fill", c + 12, c, c - 14, c - 9, c - 7, c, c - 14, c + 9)

    lg.setColor(1, 0.55, 0.23)
    lg.polygon("fill", c - 16, c - 8, c - 29, c, c - 16, c + 8)

    lg.setColor(0.08, 0.12, 0.16)
    lg.circle("fill", c + 6, c, 5)
  end)

  sprites.comet = makeCanvas(72, function(size)
    local c = size / 2

    lg.setColor(1, 0.44, 0.22, 0.24)
    lg.circle("fill", c, c, 31)

    lg.setColor(0.33, 0.29, 0.36)
    lg.polygon(
      "fill",
      c + 29, c - 2,
      c + 17, c + 20,
      c - 5, c + 28,
      c - 28, c + 8,
      c - 24, c - 18,
      c - 3, c - 29,
      c + 20, c - 21
    )

    lg.setColor(0.74, 0.53, 0.38)
    lg.polygon("line", c + 22, c - 4, c + 12, c + 15, c - 7, c + 21, c - 21, c + 6, c - 15, c - 15, c + 3, c - 21)
    lg.setLineWidth(2)
    lg.setColor(1, 0.77, 0.32)
    lg.circle("fill", c - 6, c + 2, 5)
    lg.setColor(1, 0.35, 0.21)
    lg.circle("fill", c + 11, c - 9, 4)
  end)

  sprites.core = makeCanvas(40, function(size)
    local c = size / 2

    lg.setColor(0.3, 1, 0.62, 0.22)
    lg.circle("fill", c, c, 17)

    lg.setColor(0.73, 1, 0.58)
    lg.polygon("fill", c, c - 15, c + 13, c, c, c + 15, c - 13, c)

    lg.setColor(1, 1, 0.8)
    lg.circle("fill", c, c, 5)
  end)
end

local function addParticle(x, y, vx, vy, radius, r, g, b, life)
  particles[#particles + 1] = {
    x = x,
    y = y,
    vx = vx,
    vy = vy,
    radius = radius,
    r = r,
    g = g,
    b = b,
    life = life,
    maxLife = life
  }
end

local function burst(x, y, amount, r, g, b, speed, radius)
  for _ = 1, amount do
    local angle = love.math.random() * TAU
    local power = randomRange(speed * 0.25, speed)
    addParticle(
      x,
      y,
      math.cos(angle) * power,
      math.sin(angle) * power,
      randomRange(radius * 0.45, radius),
      r,
      g,
      b,
      randomRange(0.25, 0.75)
    )
  end
end

local function resetPlayer()
  local w, h = lg.getDimensions()

  player = {
    x = w * 0.5,
    y = h * 0.55,
    vx = 0,
    vy = 0,
    radius = 17,
    angle = 0,
    health = 100,
    maxHealth = 100,
    cooldown = 0,
    dashCooldown = 0,
    dashTime = 0,
    invulnerable = 0
  }
end

local function resetGame()
  score = 0
  elapsed = 0
  combo = 1
  comboTimer = 0
  spawnTimer = 0.35
  messageTimer = 2
  shake = 0
  paused = false
  gameOver = false

  bullets = {}
  enemies = {}
  cores = {}
  particles = {}

  resetPlayer()
end

local function spawnEnemy()
  local w, h = lg.getDimensions()
  local side = love.math.random(4)
  local margin = 50
  local x
  local y

  if side == 1 then
    x = -margin
    y = randomRange(0, h)
  elseif side == 2 then
    x = w + margin
    y = randomRange(0, h)
  elseif side == 3 then
    x = randomRange(0, w)
    y = -margin
  else
    x = randomRange(0, w)
    y = h + margin
  end

  local difficulty = currentDifficulty()
  local roll = love.math.random()
  local enemy = {
    x = x,
    y = y,
    vx = 0,
    vy = 0,
    wobble = love.math.random() * TAU,
    angle = love.math.random() * TAU,
    spin = randomRange(-1.5, 1.5),
    hitFlash = 0
  }

  if roll < clamp(0.13 + difficulty * 0.035, 0.13, 0.34) then
    enemy.kind = "skimmer"
    enemy.radius = 13
    enemy.speed = randomRange(130, 160) + difficulty * 8
    enemy.health = 24 + difficulty * 5
    enemy.value = 70
    enemy.damage = 12
    enemy.color = {0.96, 0.31, 0.62}
  elseif roll > 0.79 and elapsed > 22 then
    enemy.kind = "brute"
    enemy.radius = 29
    enemy.speed = randomRange(40, 58) + difficulty * 3
    enemy.health = 110 + difficulty * 20
    enemy.value = 160
    enemy.damage = 24
    enemy.color = {1, 0.62, 0.25}
  else
    enemy.kind = "comet"
    enemy.radius = 19
    enemy.speed = randomRange(68, 92) + difficulty * 5
    enemy.health = 48 + difficulty * 9
    enemy.value = 100
    enemy.damage = 16
    enemy.color = {0.93, 0.75, 0.44}
  end

  enemy.maxHealth = enemy.health
  enemies[#enemies + 1] = enemy
end

local function fireBullet()
  if player.cooldown > 0 then
    return
  end

  local mx, my = lm.getPosition()
  local dx, dy = normalize(mx - player.x, my - player.y)
  local muzzle = player.radius + 12

  bullets[#bullets + 1] = {
    x = player.x + dx * muzzle,
    y = player.y + dy * muzzle,
    vx = dx * 680,
    vy = dy * 680,
    radius = 4.5,
    damage = 30,
    life = 0.82,
    angle = angleOf(dy, dx)
  }

  player.vx = player.vx - dx * 36
  player.vy = player.vy - dy * 36
  player.cooldown = 0.13

  addParticle(player.x - dx * 17, player.y - dy * 17, -dx * 110, -dy * 110, 5, 1, 0.45, 0.2, 0.18)
end

local function dash()
  if player.dashCooldown > 0 then
    return
  end

  local mx, my = lm.getPosition()
  local dx, dy = normalize(mx - player.x, my - player.y)

  player.vx = player.vx + dx * 560
  player.vy = player.vy + dy * 560
  player.dashCooldown = 1.7
  player.dashTime = 0.18
  player.invulnerable = math.max(player.invulnerable, 0.22)
  shake = math.max(shake, 4)
  burst(player.x, player.y, 22, 0.1, 0.9, 0.78, 180, 5)
end

local function dropCore(enemy)
  local amount = enemy.kind == "brute" and 4 or 1
  if enemy.kind == "skimmer" then
    amount = 2
  end

  for _ = 1, amount do
    local angle = love.math.random() * TAU
    local speed = randomRange(45, 145)
    cores[#cores + 1] = {
      x = enemy.x,
      y = enemy.y,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      radius = 9,
      life = 12,
      spin = randomRange(-4, 4)
    }
  end
end

local function destroyEnemy(index)
  local enemy = enemies[index]
  local points = math.floor(enemy.value * combo)

  score = score + points
  combo = clamp(combo + 0.15, 1, 6)
  comboTimer = 2.4
  shake = math.max(shake, enemy.kind == "brute" and 11 or 6)
  burst(enemy.x, enemy.y, enemy.kind == "brute" and 42 or 24, enemy.color[1], enemy.color[2], enemy.color[3], 260, 6)
  dropCore(enemy)
  table.remove(enemies, index)
end

local function damagePlayer(enemy)
  if player.invulnerable > 0 or player.dashTime > 0 then
    return
  end

  player.health = player.health - enemy.damage
  player.invulnerable = 0.68
  shake = math.max(shake, 10)

  local dx, dy = normalize(player.x - enemy.x, player.y - enemy.y)
  player.vx = player.vx + dx * 260
  player.vy = player.vy + dy * 260

  burst(player.x, player.y, 28, 1, 0.18, 0.13, 280, 5)

  if player.health <= 0 then
    player.health = 0
    gameOver = true
    paused = false
    saveHighScore()
    burst(player.x, player.y, 70, 0.1, 0.9, 0.78, 390, 8)
  end
end

local function updatePlayer(dt)
  local ix = 0
  local iy = 0

  if lk.isDown("a", "left") then
    ix = ix - 1
  end
  if lk.isDown("d", "right") then
    ix = ix + 1
  end
  if lk.isDown("w", "up") then
    iy = iy - 1
  end
  if lk.isDown("s", "down") then
    iy = iy + 1
  end

  if ix ~= 0 or iy ~= 0 then
    ix, iy = normalize(ix, iy)
    local acceleration = player.dashTime > 0 and 450 or 980
    player.vx = player.vx + ix * acceleration * dt
    player.vy = player.vy + iy * acceleration * dt
  end

  local mx, my = lm.getPosition()
  player.angle = angleOf(my - player.y, mx - player.x)

  if lm.isDown(1) or lk.isDown("space") then
    fireBullet()
  end

  if lm.isDown(2) or lk.isDown("lshift") or lk.isDown("x") then
    dash()
  end

  local drag = player.dashTime > 0 and 0.985 or 0.89
  player.vx = player.vx * (drag ^ (dt * 60))
  player.vy = player.vy * (drag ^ (dt * 60))

  player.x = player.x + player.vx * dt
  player.y = player.y + player.vy * dt

  local w, h = lg.getDimensions()
  player.x = clamp(player.x, player.radius, w - player.radius)
  player.y = clamp(player.y, player.radius, h - player.radius)

  player.cooldown = math.max(0, player.cooldown - dt)
  player.dashCooldown = math.max(0, player.dashCooldown - dt)
  player.dashTime = math.max(0, player.dashTime - dt)
  player.invulnerable = math.max(0, player.invulnerable - dt)

  if player.dashTime > 0 then
    addParticle(
      player.x - math.cos(player.angle) * 16,
      player.y - math.sin(player.angle) * 16,
      randomRange(-30, 30),
      randomRange(-30, 30),
      4,
      0.1,
      0.9,
      0.78,
      0.24
    )
  end
end

local function updateBullets(dt)
  for i = #bullets, 1, -1 do
    local bullet = bullets[i]
    bullet.x = bullet.x + bullet.vx * dt
    bullet.y = bullet.y + bullet.vy * dt
    bullet.life = bullet.life - dt

    if bullet.life <= 0 then
      table.remove(bullets, i)
    else
      local hit = false
      for j = #enemies, 1, -1 do
        local enemy = enemies[j]
        local radius = bullet.radius + enemy.radius
        if distanceSquared(bullet.x, bullet.y, enemy.x, enemy.y) <= radius * radius then
          enemy.health = enemy.health - bullet.damage
          enemy.hitFlash = 0.09
          enemy.vx = enemy.vx + bullet.vx * 0.035
          enemy.vy = enemy.vy + bullet.vy * 0.035
          burst(bullet.x, bullet.y, 8, 1, 0.94, 0.58, 150, 3)

          table.remove(bullets, i)
          hit = true

          if enemy.health <= 0 then
            destroyEnemy(j)
          end
          break
        end
      end

      if not hit then
        local w, h = lg.getDimensions()
        if bullet.x < -30 or bullet.x > w + 30 or bullet.y < -30 or bullet.y > h + 30 then
          table.remove(bullets, i)
        end
      end
    end
  end
end

local function updateEnemies(dt)
  for i = #enemies, 1, -1 do
    local enemy = enemies[i]
    local dx, dy = normalize(player.x - enemy.x, player.y - enemy.y)
    local tangentX = -dy
    local tangentY = dx
    local wobble = math.sin(elapsed * 2.8 + enemy.wobble)
    local steerX = dx + tangentX * wobble * (enemy.kind == "skimmer" and 0.7 or 0.24)
    local steerY = dy + tangentY * wobble * (enemy.kind == "skimmer" and 0.7 or 0.24)

    steerX, steerY = normalize(steerX, steerY)
    enemy.vx = enemy.vx + steerX * enemy.speed * 2.7 * dt
    enemy.vy = enemy.vy + steerY * enemy.speed * 2.7 * dt

    local maxSpeed = enemy.speed
    local speed = length(enemy.vx, enemy.vy)
    if speed > maxSpeed then
      enemy.vx = enemy.vx / speed * maxSpeed
      enemy.vy = enemy.vy / speed * maxSpeed
    end

    enemy.x = enemy.x + enemy.vx * dt
    enemy.y = enemy.y + enemy.vy * dt
    enemy.angle = enemy.angle + enemy.spin * dt
    enemy.hitFlash = math.max(0, enemy.hitFlash - dt)

    local radius = enemy.radius + player.radius
    if distanceSquared(enemy.x, enemy.y, player.x, player.y) <= radius * radius then
      damagePlayer(enemy)
      enemy.vx = enemy.vx - dx * 240
      enemy.vy = enemy.vy - dy * 240
    end
  end
end

local function updateCores(dt)
  for i = #cores, 1, -1 do
    local core = cores[i]
    local dx = player.x - core.x
    local dy = player.y - core.y
    local dist = length(dx, dy)

    if dist < 165 then
      dx, dy = normalize(dx, dy)
      local pull = 360 * (1 - dist / 165)
      core.vx = core.vx + dx * pull * dt * 7
      core.vy = core.vy + dy * pull * dt * 7
    end

    core.vx = core.vx * (0.95 ^ (dt * 60))
    core.vy = core.vy * (0.95 ^ (dt * 60))
    core.x = core.x + core.vx * dt
    core.y = core.y + core.vy * dt
    core.life = core.life - dt

    local radius = core.radius + player.radius
    if distanceSquared(core.x, core.y, player.x, player.y) <= radius * radius then
      score = score + math.floor(45 * combo)
      player.health = math.min(player.maxHealth, player.health + 3)
      combo = clamp(combo + 0.08, 1, 6)
      comboTimer = 2.4
      burst(core.x, core.y, 14, 0.38, 1, 0.6, 170, 4)
      table.remove(cores, i)
    elseif core.life <= 0 then
      table.remove(cores, i)
    end
  end
end

local function updateParticles(dt)
  for i = #particles, 1, -1 do
    local p = particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.vx = p.vx * (0.92 ^ (dt * 60))
    p.vy = p.vy * (0.92 ^ (dt * 60))
    p.life = p.life - dt

    if p.life <= 0 then
      table.remove(particles, i)
    end
  end
end

local function updateStars(dt)
  local w, h = lg.getDimensions()
  for _, star in ipairs(stars) do
    star.y = star.y + star.speed * dt
    if star.y > h + 6 then
      star.x = randomRange(0, w)
      star.y = -6
    end
  end
end

local function updateSpawner(dt)
  spawnTimer = spawnTimer - dt
  if spawnTimer <= 0 then
    local difficulty = currentDifficulty()
    spawnEnemy()

    if elapsed > 35 and love.math.random() < 0.28 then
      spawnEnemy()
    end

    spawnTimer = randomRange(0.42, 0.95) / clamp(difficulty, 1, 3.3)
  end
end

local function updateCombo(dt)
  if comboTimer > 0 then
    comboTimer = comboTimer - dt
  else
    combo = math.max(1, combo - dt * 0.5)
  end
end

function love.load()
  love.math.setRandomSeed(os.time())
  lg.setDefaultFilter("nearest", "nearest")

  game.font = lg.newFont(18)
  game.bigFont = lg.newFont(44)
  game.smallFont = lg.newFont(13)

  buildSprites()
  loadHighScore()

  local w, h = lg.getDimensions()
  stars = {}
  for _ = 1, 95 do
    stars[#stars + 1] = {
      x = randomRange(0, w),
      y = randomRange(0, h),
      size = randomRange(1, 2.8),
      speed = randomRange(8, 34),
      alpha = randomRange(0.25, 0.9)
    }
  end

  resetGame()
end

function love.update(dt)
  dt = math.min(dt, 1 / 30)

  updateStars(dt)
  updateParticles(dt)

  if paused or gameOver then
    shake = math.max(0, shake - dt * 24)
    return
  end

  elapsed = elapsed + dt
  messageTimer = math.max(0, messageTimer - dt)
  shake = math.max(0, shake - dt * 28)

  updatePlayer(dt)
  updateSpawner(dt)
  updateBullets(dt)
  updateEnemies(dt)
  updateCores(dt)
  updateCombo(dt)
end

local function drawBackground()
  local w, h = lg.getDimensions()

  lg.clear(0.035, 0.039, 0.055)

  for _, star in ipairs(stars) do
    lg.setColor(0.82, 0.92, 1, star.alpha)
    lg.circle("fill", star.x, star.y, star.size)
  end

  lg.setColor(0.12, 0.18, 0.2, 0.22)
  lg.setLineWidth(1)
  local grid = 48
  local offset = (elapsed * 20) % grid
  for x = -grid, w + grid, grid do
    lg.line(x, 0, x + offset * 0.24, h)
  end
  for y = -grid, h + grid, grid do
    lg.line(0, y + offset, w, y)
  end

  lg.setColor(0.1, 0.58, 0.48, 0.08)
  lg.polygon("fill", -80, h * 0.2, w * 0.36, h * 0.02, w * 0.56, h * 0.16, w * 0.08, h * 0.36)
  lg.setColor(0.78, 0.26, 0.46, 0.07)
  lg.polygon("fill", w * 0.62, h, w + 70, h * 0.66, w + 70, h * 0.88, w * 0.48, h + 40)
end

local function drawShip()
  local flash = player.invulnerable > 0 and math.sin(elapsed * 40) > 0
  if flash then
    lg.setColor(1, 1, 1, 0.35)
  else
    lg.setColor(1, 1, 1)
  end

  lg.draw(sprites.ship, player.x, player.y, player.angle, 1, 1, 32, 32)

  if player.dashTime > 0 then
    lg.setColor(0.25, 1, 0.78, 0.38)
    lg.circle("line", player.x, player.y, player.radius + 10 + math.sin(elapsed * 44) * 3)
  end
end

local function drawEnemies()
  for _, enemy in ipairs(enemies) do
    local scale = enemy.radius / 22
    local alpha = enemy.hitFlash > 0 and 1 or 0.88

    lg.setColor(enemy.color[1], enemy.color[2], enemy.color[3], 0.18)
    lg.circle("fill", enemy.x, enemy.y, enemy.radius * 1.9)

    if enemy.kind == "skimmer" then
      lg.push()
      lg.translate(enemy.x, enemy.y)
      lg.rotate(enemy.angle)
      lg.setColor(enemy.hitFlash > 0 and 1 or 0.96, enemy.hitFlash > 0 and 1 or 0.31, enemy.hitFlash > 0 and 1 or 0.62, alpha)
      lg.polygon("fill", 0, -enemy.radius, enemy.radius * 1.15, 0, 0, enemy.radius, -enemy.radius * 1.15, 0)
      lg.setColor(0.08, 0.05, 0.09, 0.8)
      lg.circle("fill", 0, 0, enemy.radius * 0.35)
      lg.pop()
    else
      lg.setColor(enemy.hitFlash > 0 and 1 or 0.95, enemy.hitFlash > 0 and 1 or 0.95, enemy.hitFlash > 0 and 1 or 0.95, alpha)
      lg.draw(sprites.comet, enemy.x, enemy.y, enemy.angle, scale, scale, 36, 36)

      if enemy.kind == "brute" then
        lg.setLineWidth(3)
        lg.setColor(1, 0.62, 0.25, 0.65)
        lg.circle("line", enemy.x, enemy.y, enemy.radius + 5)
      end
    end

    local healthRatio = enemy.health / enemy.maxHealth
    if healthRatio < 0.98 then
      lg.setColor(0.02, 0.02, 0.03, 0.65)
      lg.rectangle("fill", enemy.x - enemy.radius, enemy.y - enemy.radius - 12, enemy.radius * 2, 4, 2, 2)
      lg.setColor(enemy.color[1], enemy.color[2], enemy.color[3], 0.95)
      lg.rectangle("fill", enemy.x - enemy.radius, enemy.y - enemy.radius - 12, enemy.radius * 2 * healthRatio, 4, 2, 2)
    end
  end
end

local function drawBullets()
  for _, bullet in ipairs(bullets) do
    lg.push()
    lg.translate(bullet.x, bullet.y)
    lg.rotate(bullet.angle)
    lg.setColor(1, 0.84, 0.28, 0.24)
    lg.rectangle("fill", -11, -4, 22, 8, 4, 4)
    lg.setColor(1, 0.95, 0.62)
    lg.rectangle("fill", -5, -2, 13, 4, 2, 2)
    lg.pop()
  end
end

local function drawCores()
  for _, core in ipairs(cores) do
    local pulse = 1 + math.sin(elapsed * 7 + core.x * 0.03) * 0.08
    lg.setColor(1, 1, 1, clamp(core.life / 0.4, 0, 1))
    lg.draw(sprites.core, core.x, core.y, elapsed * core.spin, pulse, pulse, 20, 20)
  end
end

local function drawParticles()
  for _, p in ipairs(particles) do
    local ratio = p.life / p.maxLife
    lg.setColor(p.r, p.g, p.b, ratio)
    lg.circle("fill", p.x, p.y, p.radius * ratio)
  end
end

local function drawBar(x, y, w, h, ratio, r, g, b)
  lg.setColor(0.02, 0.025, 0.03, 0.7)
  lg.rectangle("fill", x, y, w, h, 3, 3)
  lg.setColor(r, g, b, 0.95)
  lg.rectangle("fill", x, y, w * clamp(ratio, 0, 1), h, 3, 3)
  lg.setColor(1, 1, 1, 0.16)
  lg.rectangle("line", x, y, w, h, 3, 3)
end

local function drawHud()
  local w = lg.getWidth()
  lg.setFont(game.font)

  lg.setColor(0.96, 0.97, 0.9)
  lg.print("Score " .. score, 22, 18)

  lg.setFont(game.smallFont)
  lg.setColor(0.78, 0.86, 0.84)
  lg.print("Best " .. highScore, 24, 43)
  lg.print("Wave " .. math.floor(currentDifficulty()), w - 88, 20)

  drawBar(22, 68, 178, 12, player.health / player.maxHealth, 0.95, 0.18, 0.16)
  drawBar(22, 88, 178, 7, 1 - player.dashCooldown / 1.7, 0.1, 0.85, 0.72)

  if combo > 1.05 then
    lg.setFont(game.font)
    lg.setColor(0.75, 1, 0.58)
    lg.printf(string.format("x%.1f", combo), 0, 20, w - 22, "right")
  end

  if messageTimer > 0 then
    lg.setFont(game.font)
    lg.setColor(0.86, 0.93, 0.86, messageTimer / 2)
    lg.printf("Comet Orchard", 0, lg.getHeight() - 46, w, "center")
  end
end

local function drawOverlay(title, subtitle)
  local w, h = lg.getDimensions()
  lg.setColor(0.02, 0.025, 0.03, 0.72)
  lg.rectangle("fill", 0, 0, w, h)

  lg.setFont(game.bigFont)
  lg.setColor(0.96, 0.97, 0.9)
  lg.printf(title, 0, h * 0.36, w, "center")

  lg.setFont(game.font)
  lg.setColor(0.74, 0.9, 0.82)
  lg.printf(subtitle, 0, h * 0.36 + 58, w, "center")
end

function love.draw()
  drawBackground()

  local sx = 0
  local sy = 0
  if shake > 0 then
    sx = randomRange(-shake, shake)
    sy = randomRange(-shake, shake)
  end

  lg.push()
  lg.translate(sx, sy)
  drawCores()
  drawBullets()
  drawEnemies()
  drawShip()
  drawParticles()
  lg.pop()

  drawHud()

  if paused then
    drawOverlay("Paused", "P or Esc")
  elseif gameOver then
    drawOverlay("Orchard Lost", "R to restart")
  end
end

function love.keypressed(key)
  if key == "r" and gameOver then
    resetGame()
    return
  end

  if key == "p" or key == "escape" then
    if not gameOver then
      paused = not paused
    end
  end
end

function love.resize(width, height)
  player.x = clamp(player.x, player.radius, width - player.radius)
  player.y = clamp(player.y, player.radius, height - player.radius)
end

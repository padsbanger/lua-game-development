local lg = love.graphics
local lk = love.keyboard
local lf = love.filesystem

local VW, VH = 360, 80
local SCALE = 2
local SAVE_FILE = "save.lua"
local VERSION = 1

local GLYPHS = require("data.glyphs")
local classes = require("data.classes")
local zones = require("data.zones")
local monsterTypes = require("data.monster_types")
local rarity = require("data.rarity")
local itemNames = require("data.item_names")

local canvas
local buttons = {}
local particles = {}
local floaters = {}
local attackEffects = {}
local lastSave = 0
local appMode = "menu"
local state
local sprites = {
  heroes = {},
  monsters = {}
}

local rebuildButtons
local rebuildMenuButtons

local function clamp(value, low, high)
  return math.max(low, math.min(high, value))
end

local function copyColor(color, alpha)
  return color[1], color[2], color[3], alpha or color[4] or 1
end

local function loadSprite(path)
  if not lf.getInfo(path) then
    return nil
  end

  local image = lg.newImage(path)
  image:setFilter("nearest", "nearest")
  return image
end

local function loadGraphicsPack()
  sprites.heroes = {}
  sprites.monsters = {}

  for _, c in ipairs(classes) do
    sprites.heroes[c.id] = loadSprite("assets/heroes/" .. c.id .. ".png")
  end

  for _, monsterType in ipairs(monsterTypes) do
    sprites.monsters[monsterType.shape] = loadSprite("assets/monsters/" .. monsterType.shape .. ".png")
  end
end

local function drawSprite(image, x, y, width, height)
  local scale = math.min(width / image:getWidth(), height / image:getHeight())
  local drawX = math.floor(x + (width - image:getWidth() * scale) / 2)
  local drawY = math.floor(y + (height - image:getHeight() * scale) / 2)
  lg.setColor(1, 1, 1)
  lg.draw(image, drawX, drawY, 0, scale, scale)
end

local function textWidth(text)
  text = tostring(text):upper()
  if #text == 0 then
    return 0
  end
  return #text * 4 - 1
end

local function pxPrint(text, x, y, color)
  text = tostring(text):upper()
  if color then
    lg.setColor(copyColor(color))
  end

  for i = 1, #text do
    local ch = text:sub(i, i)
    local glyph = GLYPHS[ch] or GLYPHS["?"]
    local ox = x + (i - 1) * 4
    for row = 1, 5 do
      local line = glyph[row]
      for col = 1, 3 do
        if line:sub(col, col) == "1" then
          lg.rectangle("fill", ox + col - 1, y + row - 1, 1, 1)
        end
      end
    end
  end
end

local function pxPrintf(text, x, y, width, align, color)
  local drawX = x
  local w = textWidth(text)
  if align == "center" then
    drawX = x + math.floor((width - w) / 2)
  elseif align == "right" then
    drawX = x + width - w
  end
  pxPrint(text, drawX, y, color)
end

local function fitText(text, maxWidth)
  text = tostring(text)
  if textWidth(text) <= maxWidth then
    return text
  end

  local maxChars = math.max(1, math.floor((maxWidth + 1) / 4))
  return text:sub(1, maxChars)
end

local function pick(list)
  return list[love.math.random(#list)]
end

local function pickWeighted(list)
  local total = 0
  for _, item in ipairs(list) do
    total = total + item.weight
  end

  local roll = love.math.random() * total
  local seen = 0
  for _, item in ipairs(list) do
    seen = seen + item.weight
    if roll <= seen then
      return item
    end
  end

  return list[#list]
end

local function class()
  return classes[state.classIndex]
end

local function xpToNext()
  return 22 + state.level * state.level * 6
end

local function upgradeCost()
  return math.floor(18 * (state.upgrades + 1) ^ 1.55)
end

local function itemPower(item)
  if not item then
    return 0
  end
  return item.atk * 2.1 + item.def * 2 + item.hp * 0.32 + item.speed * 4
end

local function stats()
  local c = class()
  local s = {
    maxHp = c.hp + state.level * 5 + state.upgrades * 3,
    atk = c.atk + state.level * 2 + state.upgrades,
    def = c.def + math.floor(state.level / 3),
    speed = c.speed,
    crit = 0.05
  }

  for _, item in pairs(state.gear) do
    if item then
      s.maxHp = s.maxHp + item.hp
      s.atk = s.atk + item.atk
      s.def = s.def + item.def
      s.speed = s.speed + item.speed
      s.crit = s.crit + item.crit
    end
  end

  s.speed = clamp(s.speed, 0.6, 3.2)
  s.crit = clamp(s.crit, 0.02, 0.45)
  return s
end

local function log(text, color)
  state.log = text
  state.logTimer = 3.5
  state.logColor = color or {0.86, 0.9, 0.78}
end

local function addFloater(text, x, y, color)
  floaters[#floaters + 1] = {
    text = text,
    x = x,
    y = y,
    vy = -14,
    life = 0.75,
    color = color
  }
end

local function addParticle(x, y, color)
  particles[#particles + 1] = {
    x = x,
    y = y,
    vx = love.math.random(-35, 35) / 10,
    vy = love.math.random(-45, 8) / 10,
    life = love.math.random(35, 70) / 100,
    color = color
  }
end

local function addAttackEffect(kind, skillHit, color)
  attackEffects[#attackEffects + 1] = {
    kind = kind,
    skillHit = skillHit,
    color = color,
    life = kind == "sword" and 0.22 or 0.34,
    maxLife = kind == "sword" and 0.22 or 0.34
  }
end

local function serialize(value, indent)
  indent = indent or ""
  local t = type(value)

  if t == "number" or t == "boolean" then
    return tostring(value)
  end

  if t == "string" then
    return string.format("%q", value)
  end

  if t ~= "table" then
    return "nil"
  end

  local nextIndent = indent .. "  "
  local parts = {"{"}
  for key, item in pairs(value) do
    local encodedKey
    if type(key) == "string" and key:match("^[%a_][%w_]*$") then
      encodedKey = key
    else
      encodedKey = "[" .. serialize(key) .. "]"
    end
    parts[#parts + 1] = nextIndent .. encodedKey .. " = " .. serialize(item, nextIndent) .. ","
  end
  parts[#parts + 1] = indent .. "}"
  return table.concat(parts, "\n")
end

local function save()
  state.savedAt = os.time()
  state.version = VERSION
  lf.write(SAVE_FILE, "return " .. serialize(state))
  lastSave = love.timer.getTime()
end

local function defaultState()
  return {
    version = VERSION,
    savedAt = os.time(),
    classIndex = 1,
    zone = 1,
    unlockedZone = 1,
    level = 1,
    xp = 0,
    gold = 0,
    gems = 0,
    upgrades = 0,
    kills = 0,
    zoneKills = 0,
    heroHp = 44,
    skill = 0,
    heroTimer = 0,
    monsterTimer = 0,
    recovery = 0,
    bag = {},
    gear = {
      weapon = nil,
      armor = nil,
      charm = nil
    },
    log = "Deskbar Quest begins.",
    logTimer = 3,
    logColor = {0.86, 0.9, 0.78}
  }
end

local function spawnMonster()
  local zone = zones[state.zone]
  local level = zone.level + math.floor(state.zoneKills / 7) + math.floor(state.kills / 25)
  local variant = pickWeighted(monsterTypes)
  local baseName = pick(zone.monsters)
  local name = variant.title ~= "" and (variant.title .. " " .. baseName) or baseName
  local maxHp = math.floor((28 + level * 9 + state.zone * 8) * variant.hp)

  state.monster = {
    name = name,
    baseName = baseName,
    type = variant.id,
    shape = variant.shape,
    color = variant.color,
    reward = variant.reward,
    drop = variant.drop,
    attackDelay = 1.55 * variant.speed,
    effect = variant.effect,
    level = level,
    maxHp = maxHp,
    hp = maxHp,
    atk = math.floor((4 + level * 2 + state.zone) * variant.atk),
    def = math.floor(level * 0.8 * variant.def),
    timer = 0,
    frame = 0
  }
end

local function loadSave()
  state = defaultState()

  if lf.getInfo(SAVE_FILE) then
    local chunk = lf.load(SAVE_FILE)
    if chunk then
      local ok, loaded = pcall(chunk)
      if ok and type(loaded) == "table" then
        for key, value in pairs(loaded) do
          state[key] = value
        end
      end
    end
  end

  state.bag = state.bag or {}
  state.gear = state.gear or {weapon = nil, armor = nil, charm = nil}
  state.classIndex = clamp(state.classIndex or 1, 1, #classes)
  state.unlockedZone = clamp(state.unlockedZone or 1, 1, #zones)
  state.zone = clamp(state.zone or 1, 1, state.unlockedZone)

  local s = stats()
  state.heroHp = clamp(state.heroHp or s.maxHp, 1, s.maxHp)
  spawnMonster()
end

local function makeItem()
  local roll = love.math.random(100)
  local r = rarity[1]
  local acc = 0
  for _, candidate in ipairs(rarity) do
    acc = acc + candidate.chance
    if roll <= acc then
      r = candidate
      break
    end
  end

  local slotRoll = love.math.random(3)
  local slot = slotRoll == 1 and "weapon" or slotRoll == 2 and "armor" or "charm"
  local level = math.max(1, state.monster.level + love.math.random(-1, 2))
  local mult = r.mult
  local item = {
    slot = slot,
    rarity = r.name,
    color = r.color,
    name = pick(itemNames[slot]),
    level = level,
    atk = 0,
    def = 0,
    hp = 0,
    speed = 0,
    crit = 0
  }

  if slot == "weapon" then
    item.atk = math.floor((2 + level * 1.35) * mult)
    item.crit = r.name == "Rare" and 0.03 or r.name == "Mythic" and 0.06 or 0
  elseif slot == "armor" then
    item.def = math.floor((1 + level * 0.85) * mult)
    item.hp = math.floor((6 + level * 3) * mult)
  else
    item.atk = math.floor((1 + level * 0.55) * mult)
    item.hp = math.floor((3 + level * 1.5) * mult)
    item.speed = (r.name == "Mythic" and 0.18 or r.name == "Rare" and 0.11 or 0.05)
  end

  return item
end

local function awardXp(amount)
  state.xp = state.xp + amount
  while state.xp >= xpToNext() do
    state.xp = state.xp - xpToNext()
    state.level = state.level + 1
    local s = stats()
    state.heroHp = s.maxHp
    log("Level " .. state.level .. " reached.", {0.96, 0.92, 0.45})
    addFloater("LEVEL UP", 64, 27, {0.96, 0.92, 0.45})
  end
end

local function killMonster()
  local monster = state.monster
  local reward = monster.reward or 1
  local gold = math.floor((6 + monster.level * 3 + love.math.random(0, state.zone * 4)) * reward)
  local xp = math.floor((8 + monster.level * 4) * reward)

  state.gold = state.gold + gold
  state.kills = state.kills + 1
  state.zoneKills = state.zoneKills + 1
  awardXp(xp)
  addFloater("+" .. gold .. "g", 245, 32, {1, 0.84, 0.28})

  if love.math.random() < 0.34 * (monster.drop or 1) then
    local item = makeItem()
    if #state.bag < 6 then
      state.bag[#state.bag + 1] = item
      log(item.rarity .. " " .. item.name, item.color)
    else
      state.gold = state.gold + 5 + item.level * 2
      log("Bag full. Loot sold.", {0.78, 0.8, 0.72})
    end
  end

  if state.zoneKills >= 16 and state.unlockedZone < #zones then
    state.unlockedZone = state.unlockedZone + 1
    state.zoneKills = 0
    log(zones[state.unlockedZone].name .. " unlocked.", {0.46, 0.86, 1})
  end

  for _ = 1, 8 do
    addParticle(265, 43, monster.color or {0.95, 0.55, 0.28})
  end

  spawnMonster()
end

local function attackMonster(skillHit)
  local s = stats()
  local monster = state.monster
  local c = class()
  local defenseFactor = c.attack == "lightning" and 0.18 or c.attack == "bow" and 0.34 or 0.55
  local base = math.max(1, s.atk - monster.def * defenseFactor)
  local damage = math.floor(base * love.math.random(82, 118) / 100)
  local hitCount = 1

  if c.attack == "sword" then
    damage = math.floor(damage * 1.18 + s.def * 0.45)
  elseif c.attack == "lightning" then
    damage = math.floor(damage * 0.92 + state.level * 0.35)
  elseif c.attack == "bow" then
    damage = math.floor(damage * 0.82)
    hitCount = skillHit and 3 or 1
  end

  if love.math.random() < s.crit then
    damage = math.floor(damage * 1.85)
    addFloater("crit " .. damage, 249, 27, {1, 0.55, 0.24})
  else
    addFloater(tostring(damage), 252, 30, {0.96, 0.92, 0.72})
  end

  if skillHit then
    if c.attack == "sword" then
      damage = math.floor(damage * 2.35 + s.def)
    elseif c.attack == "lightning" then
      damage = math.floor(damage * 2.65 + state.level * 3)
    elseif c.attack == "bow" then
      damage = math.floor(damage * 1.15 + state.level)
    end
    addFloater(c.skill, 181, 12, c.color)
    state.skill = 0
  end

  local totalDamage = damage * hitCount
  monster.hp = monster.hp - totalDamage
  addAttackEffect(c.attack, skillHit, c.color)

  if hitCount > 1 then
    addFloater(tostring(totalDamage), 259, 39, c.color)
  end

  for _ = 1, skillHit and 10 or 4 do
    addParticle(252, 42, c.color)
  end

  if monster.hp <= 0 then
    killMonster()
  end
end

local function monsterAttack()
  local s = stats()
  local monster = state.monster
  local damage = math.max(1, monster.atk - s.def)

  if monster.effect == "blast" then
    damage = math.floor(damage * 1.35 + monster.level)
    addFloater("blast", 239, 20, monster.color)
  elseif monster.effect == "poison" then
    damage = damage + math.max(1, math.floor(s.maxHp * 0.04))
    addFloater("sting", 239, 20, monster.color)
  elseif monster.effect == "rage" and monster.hp < monster.maxHp * 0.45 then
    damage = math.floor(damage * 1.55)
    addFloater("rage", 239, 20, monster.color)
  end

  state.heroHp = state.heroHp - damage
  addFloater("-" .. damage, 93, 28, {1, 0.32, 0.26})

  if state.heroHp <= 0 then
    state.heroHp = 0
    state.recovery = 4
    log("Recovering...", {1, 0.35, 0.28})
  end
end

local function equipBest()
  if #state.bag == 0 then
    log("No loot in bag.", {0.76, 0.78, 0.72})
    return
  end

  local equipped = 0
  for i = #state.bag, 1, -1 do
    local item = state.bag[i]
    local current = state.gear[item.slot]
    if itemPower(item) > itemPower(current) then
      state.gear[item.slot] = item
      table.remove(state.bag, i)
      equipped = equipped + 1
    end
  end

  local s = stats()
  state.heroHp = clamp(state.heroHp, 1, s.maxHp)
  log(equipped > 0 and "Equipped " .. equipped .. " item(s)." or "No upgrades found.", {0.52, 0.88, 1})
end

local function sellBag()
  if #state.bag == 0 then
    log("Bag is empty.", {0.76, 0.78, 0.72})
    return
  end

  local gold = 0
  for _, item in ipairs(state.bag) do
    gold = gold + 6 + item.level * 3 + math.floor(itemPower(item))
  end
  state.bag = {}
  state.gold = state.gold + gold
  log("Sold loot for " .. gold .. "g.", {1, 0.84, 0.28})
end

local function buyUpgrade()
  local cost = upgradeCost()
  if state.gold < cost then
    log("Need " .. cost .. "g for upgrade.", {0.9, 0.48, 0.38})
    return
  end

  state.gold = state.gold - cost
  state.upgrades = state.upgrades + 1
  local s = stats()
  state.heroHp = s.maxHp
  log("Training rank " .. state.upgrades .. ".", {0.78, 1, 0.52})
end

local function changeZone(delta)
  local nextZone = clamp(state.zone + delta, 1, state.unlockedZone)
  if nextZone ~= state.zone then
    state.zone = nextZone
    state.zoneKills = 0
    spawnMonster()
    log("Travel: " .. zones[state.zone].name, {0.52, 0.88, 1})
  end
end

local function changeClass(index)
  state.classIndex = clamp(index, 1, #classes)
  local s = stats()
  state.heroHp = s.maxHp
  state.skill = 0
  log("Class: " .. class().name, class().color)
end

local function offlineProgress()
  local savedAt = state.savedAt or os.time()
  local away = clamp(os.time() - savedAt, 0, 60 * 60 * 6)
  if away < 20 then
    return
  end

  local s = stats()
  local zone = zones[state.zone]
  local monsterLevel = zone.level + math.floor(state.kills / 28)
  local estimatedKillTime = clamp((34 + monsterLevel * 9) / math.max(1, s.atk * s.speed), 3.5, 28)
  local kills = math.floor(away / estimatedKillTime)

  if kills <= 0 then
    return
  end

  kills = math.min(kills, 160)
  local gold = kills * (8 + monsterLevel * 3)
  local xp = kills * (9 + monsterLevel * 4)

  state.gold = state.gold + gold
  state.kills = state.kills + kills
  state.zoneKills = state.zoneKills + kills
  awardXp(xp)

  while state.zoneKills >= 16 and state.unlockedZone < #zones do
    state.unlockedZone = state.unlockedZone + 1
    state.zoneKills = state.zoneKills - 16
  end

  local previousMonster = state.monster
  local drops = math.min(6 - #state.bag, math.floor(kills / 5))
  for _ = 1, drops do
    state.monster = {level = monsterLevel}
    state.bag[#state.bag + 1] = makeItem()
  end
  state.monster = previousMonster

  log("Away " .. math.floor(away / 60) .. "m: +" .. gold .. "g, " .. kills .. " wins.", {0.56, 0.92, 1})
end

local function resetSave()
  lf.remove(SAVE_FILE)
  state = defaultState()
  spawnMonster()
  log("Save reset.", {1, 0.56, 0.44})
end

local function hasSave()
  return lf.getInfo(SAVE_FILE) ~= nil
end

local function beginNewGame()
  lf.remove(SAVE_FILE)
  state = defaultState()
  particles = {}
  floaters = {}
  attackEffects = {}
  spawnMonster()
  appMode = "playing"
  rebuildButtons()
  save()
end

local function beginLoadGame()
  if not hasSave() then
    beginNewGame()
    return
  end

  particles = {}
  floaters = {}
  attackEffects = {}
  loadSave()
  offlineProgress()
  appMode = "playing"
  rebuildButtons()
  save()
end

local function addButton(label, x, y, w, h, action, disabled)
  buttons[#buttons + 1] = {label = label, x = x, y = y, w = w, h = h, action = action, disabled = disabled}
end

rebuildMenuButtons = function()
  buttons = {}
  addButton("NEW GAME", 113, 43, 62, 16, beginNewGame)
  addButton("LOAD SAVE", 184, 43, 62, 16, beginLoadGame, not hasSave())
end

rebuildButtons = function()
  buttons = {}
  addButton("U", 285, 8, 18, 13, buyUpgrade)
  addButton("E", 306, 8, 18, 13, equipBest)
  addButton("S", 327, 8, 18, 13, sellBag)
  addButton("<", 134, 62, 15, 11, function() changeZone(-1) end)
  addButton(">", 211, 62, 15, 11, function() changeZone(1) end)
  addButton("1", 8, 62, 14, 11, function() changeClass(1) end)
  addButton("2", 25, 62, 14, 11, function() changeClass(2) end)
  addButton("3", 42, 62, 14, 11, function() changeClass(3) end)
end

local function updateCombat(dt)
  local s = stats()

  if state.recovery > 0 then
    state.recovery = state.recovery - dt
    state.heroHp = clamp(state.heroHp + s.maxHp * dt / 4, 0, s.maxHp)
    if state.recovery <= 0 then
      state.heroHp = s.maxHp
      log("Back in action.", {0.66, 0.94, 0.55})
    end
    return
  end

  state.heroTimer = state.heroTimer + dt * s.speed
  state.monsterTimer = state.monsterTimer + dt
  state.skill = clamp(state.skill + dt * (7 + s.speed * 3), 0, 100)

  if state.heroTimer >= 1 then
    state.heroTimer = state.heroTimer - 1
    local skillHit = state.skill >= 100
    attackMonster(skillHit)
  end

  local delay = state.monster.attackDelay or 1.55
  if state.monsterTimer >= delay then
    state.monsterTimer = state.monsterTimer - delay
    monsterAttack()
  end
end

local function updateEffects(dt)
  for i = #particles, 1, -1 do
    local p = particles[i]
    p.x = p.x + p.vx
    p.y = p.y + p.vy
    p.vy = p.vy + dt * 18
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(particles, i)
    end
  end

  for i = #floaters, 1, -1 do
    local f = floaters[i]
    f.y = f.y + f.vy * dt
    f.life = f.life - dt
    if f.life <= 0 then
      table.remove(floaters, i)
    end
  end

  for i = #attackEffects, 1, -1 do
    local effect = attackEffects[i]
    effect.life = effect.life - dt
    if effect.life <= 0 then
      table.remove(attackEffects, i)
    end
  end

  state.logTimer = math.max(0, (state.logTimer or 0) - dt)
end

function love.load()
  love.math.setRandomSeed(os.time())
  lg.setDefaultFilter("nearest", "nearest")
  lg.setLineStyle("rough")
  canvas = lg.newCanvas(VW, VH)
  canvas:setFilter("nearest", "nearest")
  loadGraphicsPack()

  local desktopW, desktopH = love.window.getDesktopDimensions()
  love.window.setPosition(math.max(0, desktopW - 740), math.max(0, desktopH - 230))

  state = defaultState()
  spawnMonster()
  rebuildMenuButtons()
end

function love.update(dt)
  dt = math.min(dt, 1 / 20)

  if appMode == "playing" then
    updateCombat(dt)
  end

  updateEffects(dt)

  if appMode == "playing" and love.timer.getTime() - lastSave > 5 then
    save()
  end
end

local function rect(x, y, w, h, color)
  lg.setColor(copyColor(color))
  lg.rectangle("fill", x, y, w, h)
end

local function bar(x, y, w, h, value, max, color)
  rect(x, y, w, h, {0.08, 0.08, 0.1})
  rect(x, y, math.floor(w * clamp(value / max, 0, 1)), h, color)
  lg.setColor(0.96, 0.94, 0.82, 0.25)
  lg.rectangle("line", x, y, w, h)
end

local function drawHero(x, y)
  local c = class().color
  local attack = class().attack
  local sprite = sprites.heroes[class().id]
  if sprite then
    drawSprite(sprite, x - 3, y - 2, 28, 28)
    return
  end

  rect(x + 3, y + 4, 10, 15, {0.12, 0.12, 0.14})
  rect(x + 5, y, 7, 6, {0.92, 0.72, 0.5})
  rect(x + 4, y + 7, 9, 8, c)
  rect(x + 2, y + 15, 4, 6, {0.18, 0.2, 0.24})
  rect(x + 10, y + 15, 4, 6, {0.18, 0.2, 0.24})

  if attack == "sword" then
    if state.heroTimer > 0.78 then
      rect(x + 11, y + 8, 5, 4, {0.42, 0.24, 0.14})
      rect(x + 15, y + 10, 14, 3, {0.74, 0.82, 0.9})
      rect(x + 17, y + 9, 12, 1, {1, 1, 0.88})
      rect(x + 29, y + 9, 3, 5, {0.94, 0.98, 1})
      rect(x + 12, y + 7, 6, 2, {0.86, 0.62, 0.2})
      rect(x + 12, y + 13, 6, 2, {0.86, 0.62, 0.2})
    elseif state.heroTimer > 0.48 then
      rect(x + 10, y + 6, 5, 5, {0.42, 0.24, 0.14})
      rect(x + 12, y - 10, 4, 17, {0.74, 0.82, 0.9})
      rect(x + 13, y - 11, 2, 15, {1, 1, 0.88})
      rect(x + 10, y - 12, 8, 3, {0.94, 0.98, 1})
      rect(x + 7, y + 6, 11, 2, {0.86, 0.62, 0.2})
    else
      rect(x + 12, y + 10, 5, 4, {0.42, 0.24, 0.14})
      rect(x + 16, y + 12, 4, 5, {0.74, 0.82, 0.9})
      rect(x + 19, y + 16, 4, 4, {0.74, 0.82, 0.9})
      rect(x + 22, y + 19, 4, 4, {0.94, 0.98, 1})
      rect(x + 13, y + 9, 8, 2, {0.86, 0.62, 0.2})
      rect(x + 18, y + 13, 1, 3, {1, 1, 0.88})
    end
  elseif attack == "lightning" then
    rect(x + 14, y + 4, 2, 15, {0.42, 0.28, 0.18})
    rect(x + 13, y + 2, 4, 4, {0.52, 0.86, 1})
    if state.heroTimer > 0.72 then
      rect(x + 19, y + 6, 3, 3, {0.82, 0.94, 1})
    end
  elseif attack == "bow" then
    rect(x + 14, y + 5, 2, 13, {0.72, 0.48, 0.22})
    rect(x + 16, y + 7, 2, 2, {0.9, 0.82, 0.5})
    rect(x + 16, y + 14, 2, 2, {0.9, 0.82, 0.5})
    if state.heroTimer > 0.72 then
      rect(x + 18, y + 10, 7, 1, {0.92, 0.94, 0.72})
    end
  elseif state.heroTimer > 0.72 then
    rect(x + 15, y + 9, 9, 2, {0.92, 0.94, 0.72})
  else
    rect(x + 13, y + 9, 5, 2, {0.92, 0.94, 0.72})
  end
end

local function drawAttackEffects()
  for _, effect in ipairs(attackEffects) do
    local t = 1 - effect.life / effect.maxLife
    local color = effect.color

    if effect.kind == "sword" then
      local x = math.floor((effect.skillHit and 176 or 184) + 38 * t)
      local y = math.floor((effect.skillHit and 24 or 29) + 5 * t)

      rect(x - 2, y + 16, 8, 3, {0.86, 0.62, 0.2})
      rect(x + 3, y + 13, 7, 3, {0.42, 0.24, 0.14})

      lg.setColor(0.94, 0.98, 1, 0.95)
      lg.line(x + 8, y + 14, x + 54, y - 4)
      lg.line(x + 8, y + 16, x + 55, y - 2)
      lg.line(x + 10, y + 18, x + 54, y)

      lg.setColor(1, 1, 0.84, 0.95)
      lg.line(x + 14, y + 14, x + 48, y + 1)

      lg.setColor(copyColor(color, 0.55))
      lg.line(x + 1, y + 22, x + 53, y + 4)
      lg.line(x + 7, y + 25, x + 58, y + 8)

      if effect.skillHit then
        lg.setColor(1, 0.92, 0.32, 0.9)
        lg.line(x - 4, y + 26, x + 62, y + 4)
        lg.line(x + 1, y + 30, x + 67, y + 9)
        rect(x + 55, y - 6, 5, 5, {1, 0.96, 0.45})
      end
    elseif effect.kind == "lightning" then
      local x = math.floor(178 + 62 * t)
      local y = 39 + math.floor(math.sin(t * 12) * 3)
      rect(x, y, effect.skillHit and 6 or 4, effect.skillHit and 6 or 4, color)
      rect(x + 2, y - 3, 2, 2, {0.86, 0.96, 1})
      if effect.skillHit then
        rect(x - 5, y + 2, 4, 2, {0.86, 0.96, 1})
        rect(x + 7, y + 1, 5, 2, {0.86, 0.96, 1})
      end
    elseif effect.kind == "bow" then
      local arrows = effect.skillHit and 3 or 1
      for i = 1, arrows do
        local x = math.floor(177 + 65 * t)
        local y = 37 + (i - 2) * 4
        rect(x, y, 10, 1, {0.9, 0.82, 0.5})
        rect(x + 9, y - 1, 2, 3, color)
      end
    end
  end
end

local function lightened(color, amount)
  return {
    clamp(color[1] + amount, 0, 1),
    clamp(color[2] + amount, 0, 1),
    clamp(color[3] + amount, 0, 1)
  }
end

local function drawMonster(x, y)
  local monster = state.monster
  local sprite = sprites.monsters[monster.shape]
  if sprite then
    drawSprite(sprite, x - 2, y - 1, 28, 28)
    return
  end

  local base = monster.color or lightened(zones[state.zone].tint, 0.2)
  local glow = lightened(base, 0.22)
  local bob = math.sin(love.timer.getTime() * 4) > 0 and 1 or 0

  if monster.shape == "wing" then
    rect(x + 1, y + 8 + bob, 6, 5, glow)
    rect(x + 17, y + 8 + bob, 6, 5, glow)
    rect(x + 7, y + 5 + bob, 10, 10, {0.12, 0.1, 0.12})
    rect(x + 9, y + 3 + bob, 6, 7, base)
    rect(x + 9, y + 10 + bob, 2, 2, {1, 0.86, 0.45})
    rect(x + 14, y + 10 + bob, 2, 2, {1, 0.86, 0.45})
  elseif monster.shape == "shield" then
    rect(x + 3, y + 4 + bob, 18, 18, {0.1, 0.1, 0.12})
    rect(x + 6, y + 2 + bob, 12, 20, base)
    rect(x + 9, y + 5 + bob, 6, 12, glow)
    rect(x + 7, y + 10 + bob, 3, 2, {0.12, 0.08, 0.08})
    rect(x + 15, y + 10 + bob, 3, 2, {0.12, 0.08, 0.08})
  elseif monster.shape == "slime" then
    rect(x + 2, y + 13 + bob, 20, 8, {0.1, 0.1, 0.12})
    rect(x + 4, y + 8 + bob, 16, 11, base)
    rect(x + 7, y + 5 + bob, 10, 5, glow)
    rect(x + 8, y + 12 + bob, 3, 2, {0.1, 0.08, 0.08})
    rect(x + 15, y + 12 + bob, 3, 2, {0.1, 0.08, 0.08})
  elseif monster.shape == "wisp" then
    rect(x + 8, y + 3 + bob, 10, 15, base)
    rect(x + 10, y + 1 + bob, 6, 7, glow)
    rect(x + 5, y + 13 + bob, 5, 3, base)
    rect(x + 16, y + 15 + bob, 6, 3, base)
    rect(x + 11, y + 9 + bob, 2, 2, {1, 0.92, 0.5})
    rect(x + 16, y + 9 + bob, 2, 2, {1, 0.92, 0.5})
  elseif monster.shape == "mimic" then
    rect(x + 2, y + 9 + bob, 20, 13, {0.1, 0.08, 0.07})
    rect(x + 4, y + 5 + bob, 16, 7, base)
    rect(x + 6, y + 12 + bob, 12, 5, {0.35, 0.08, 0.08})
    rect(x + 8, y + 13 + bob, 2, 2, {1, 0.95, 0.72})
    rect(x + 14, y + 13 + bob, 2, 2, {1, 0.95, 0.72})
    rect(x + 11, y + 3 + bob, 3, 3, glow)
  elseif monster.shape == "elite" then
    rect(x + 2, y + 7 + bob, 20, 15, {0.1, 0.08, 0.08})
    rect(x + 5, y + 4 + bob, 14, 14, base)
    rect(x + 7, y + 1 + bob, 3, 4, {1, 0.84, 0.24})
    rect(x + 12, y + 0 + bob, 3, 5, {1, 0.84, 0.24})
    rect(x + 17, y + 1 + bob, 3, 4, {1, 0.84, 0.24})
    rect(x + 8, y + 9 + bob, 3, 2, {1, 0.9, 0.45})
    rect(x + 16, y + 9 + bob, 3, 2, {1, 0.9, 0.45})
  else
    rect(x + 2, y + 6 + bob, 17, 13, {0.12, 0.1, 0.12})
    rect(x + 5, y + 2 + bob, 12, 8, base)
    rect(x + 7, y + 8 + bob, 3, 2, {1, 0.86, 0.45})
    rect(x + 14, y + 8 + bob, 3, 2, {1, 0.86, 0.45})
    rect(x + 4, y + 19 + bob, 4, 4, {0.09, 0.08, 0.1})
    rect(x + 15, y + 19 + bob, 4, 4, {0.09, 0.08, 0.1})
  end
end

local function drawLoot()
  for i = 1, 6 do
    local x = 286 + (i - 1) * 10
    rect(x, 60, 8, 8, {0.11, 0.11, 0.13})
    local item = state.bag[i]
    if item then
      rect(x + 1, 61, 6, 6, item.color)
    end
  end
end

local function drawGear()
  local slots = {{"weapon", 286}, {"armor", 309}, {"charm", 332}}
  for _, pair in ipairs(slots) do
    local item = state.gear[pair[1]]
    rect(pair[2], 39, 18, 13, {0.1, 0.1, 0.12})
    if item then
      rect(pair[2] + 2, 41, 14, 9, item.color)
    end
    pxPrint(pair[1]:sub(1, 1), pair[2] + 7, 28, {0.7, 0.72, 0.66})
  end
end

local function drawButtons()
  local mx, my = love.mouse.getPosition()
  mx, my = math.floor(mx / SCALE), math.floor(my / SCALE)

  for _, b in ipairs(buttons) do
    local hover = mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h
    local body = hover and {0.32, 0.34, 0.28} or {0.18, 0.19, 0.18}
    local text = {0.9, 0.9, 0.76}
    if b.disabled then
      body = {0.09, 0.09, 0.1}
      text = {0.38, 0.39, 0.36}
    end
    rect(b.x, b.y, b.w, b.h, body)
    pxPrintf(b.label, b.x, b.y + 4, b.w, "center", text)
  end
end

local function drawLocationDetail(zone)
  local style = zone.style

  if style == "desert" then
    rect(132, 47, 21, 2, {0.72, 0.54, 0.24})
    rect(185, 49, 28, 2, {0.64, 0.45, 0.2})
    rect(221, 34, 3, 13, {0.21, 0.45, 0.28})
    rect(218, 39, 3, 2, {0.21, 0.45, 0.28})
    rect(224, 37, 3, 2, {0.21, 0.45, 0.28})
  elseif style == "jungle" then
    for x = 130, 229, 17 do
      rect(x, 18, 3, 31, {0.06, 0.19, 0.11})
      rect(x - 3, 15, 9, 4, {0.16, 0.56, 0.18})
      rect(x + 2, 22, 7, 3, {0.22, 0.67, 0.22})
    end
  elseif style == "swamp" then
    rect(132, 48, 35, 3, {0.2, 0.38, 0.28})
    rect(190, 47, 41, 4, {0.18, 0.34, 0.26})
    rect(137, 43, 2, 8, {0.34, 0.43, 0.22})
    rect(203, 41, 2, 10, {0.34, 0.43, 0.22})
    rect(217, 44, 2, 7, {0.34, 0.43, 0.22})
  elseif style == "dungeon" then
    for x = 130, 230, 16 do
      rect(x, 16, 13, 2, {0.34, 0.34, 0.36})
      rect(x + 2, 30, 12, 2, {0.1, 0.1, 0.12})
    end
    rect(132, 22, 3, 8, {0.92, 0.48, 0.18})
    rect(226, 22, 3, 8, {0.92, 0.48, 0.18})
  elseif style == "dock" then
    for x = 132, 226, 14 do
      rect(x, 46, 10, 2, {0.36, 0.26, 0.17})
      rect(x + 2, 48, 2, 6, {0.2, 0.16, 0.13})
    end
  elseif style == "ash" then
    rect(133, 48, 30, 3, {0.28, 0.18, 0.13})
    rect(198, 47, 29, 4, {0.32, 0.16, 0.12})
    rect(150, 39, 2, 7, {0.84, 0.32, 0.12})
    rect(213, 37, 2, 9, {0.84, 0.32, 0.12})
  elseif style == "moon" then
    rect(136, 18, 2, 2, {0.78, 0.85, 1})
    rect(176, 14, 2, 2, {0.78, 0.85, 1})
    rect(218, 20, 2, 2, {0.78, 0.85, 1})
    rect(223, 41, 9, 2, {0.35, 0.31, 0.52})
  else
    for x = 130, 232, 10 do
      rect(x, 53 + (x % 3), 5, 2, {0.17, 0.25, 0.17})
    end
  end
end

local function drawScene()
  local zone = zones[state.zone]
  rect(126, 8, 112, 54, {zone.tint[1], zone.tint[2], zone.tint[3]})
  rect(126, 51, 112, 11, {0.09, 0.14, 0.12})
  drawLocationDetail(zone)

  drawHero(154, 32)
  drawAttackEffects()
  drawMonster(243, 30)

  local monster = state.monster
  pxPrint(fitText(monster.name, 64), 139, 10, {0.92, 0.9, 0.78})
  pxPrint("Lv " .. monster.level, 207, 10, {0.66, 0.68, 0.62})
  bar(142, 22, 82, 5, monster.hp, monster.maxHp, {0.92, 0.24, 0.22})

  pxPrintf(zone.name, 149, 64, 62, "center", {0.8, 0.86, 0.78})
end

local function drawUi()
  local s = stats()
  local c = class()

  rect(0, 0, VW, VH, {0.045, 0.047, 0.055})
  rect(0, 0, VW, 7, {0.11, 0.12, 0.13})

  pxPrint("Deskbar Quest", 8, 10, {0.94, 0.92, 0.78})
  pxPrint(c.name .. " Lv " .. state.level, 8, 22, c.color)
  bar(8, 35, 100, 5, state.heroHp, s.maxHp, {0.35, 0.9, 0.43})
  bar(8, 44, 100, 4, state.xp, xpToNext(), {0.35, 0.62, 1})
  bar(8, 52, 100, 4, state.skill, 100, {0.96, 0.6, 0.2})

  pxPrint(state.gold .. "g", 71, 62, {0.86, 0.8, 0.55})
  pxPrint("K " .. state.kills, 103, 62, {0.65, 0.68, 0.64})

  drawScene()
  drawGear()
  drawLoot()
  drawButtons()

  pxPrint("Train", 284, 23, {0.72, 0.74, 0.68})
  pxPrint("Gear", 287, 30, {0.72, 0.74, 0.68})
  pxPrint("Bag", 287, 52, {0.72, 0.74, 0.68})
  pxPrint("Next " .. upgradeCost() .. "g", 239, 10, {0.8, 0.78, 0.66})

  if state.logTimer > 0 then
    local color = state.logColor or {0.86, 0.9, 0.78}
    pxPrint(state.log or "", 124, 2, {color[1], color[2], color[3], clamp(state.logTimer / 0.35, 0, 1)})
  end

  for _, p in ipairs(particles) do
    lg.setColor(copyColor(p.color, clamp(p.life, 0, 1)))
    lg.rectangle("fill", math.floor(p.x), math.floor(p.y), 2, 2)
  end

  for _, f in ipairs(floaters) do
    local color = f.color
    pxPrint(f.text, math.floor(f.x), math.floor(f.y), {color[1], color[2], color[3], clamp(f.life / 0.75, 0, 1)})
  end
end

local function drawMenu()
  rect(0, 0, VW, VH, {0.045, 0.047, 0.055})
  rect(0, 0, VW, 7, {0.11, 0.12, 0.13})
  rect(102, 12, 156, 54, {0.08, 0.09, 0.1})
  rect(106, 16, 148, 46, {0.11, 0.15, 0.14})

  pxPrintf("Deskbar Quest", 0, 17, VW, "center", {0.94, 0.92, 0.78})
  pxPrintf("Idle Pixel RPG", 0, 29, VW, "center", {0.54, 0.88, 0.78})
  drawButtons()

  if hasSave() then
    pxPrintf("N new  L load", 0, 65, VW, "center", {0.62, 0.66, 0.6})
  else
    pxPrintf("No save yet", 0, 65, VW, "center", {0.62, 0.66, 0.6})
  end

  drawHero(72, 34)
  drawMonster(270, 32)
end

function love.draw()
  lg.setCanvas(canvas)
  lg.clear()
  if appMode == "menu" then
    drawMenu()
  else
    drawUi()
  end
  lg.setCanvas()

  lg.setColor(1, 1, 1)
  lg.draw(canvas, 0, 0, 0, SCALE, SCALE)
end

function love.mousepressed(x, y, button)
  if button ~= 1 then
    return
  end

  local vx = math.floor(x / SCALE)
  local vy = math.floor(y / SCALE)

  for _, b in ipairs(buttons) do
    if not b.disabled and vx >= b.x and vx <= b.x + b.w and vy >= b.y and vy <= b.y + b.h then
      b.action()
      if appMode == "playing" then
        save()
      end
      return
    end
  end
end

function love.keypressed(key)
  if appMode == "menu" then
    if key == "n" or key == "return" or key == "space" then
      beginNewGame()
    elseif key == "l" and hasSave() then
      beginLoadGame()
    end
    return
  end

  if key == "u" then
    buyUpgrade()
  elseif key == "e" then
    equipBest()
  elseif key == "s" then
    sellBag()
  elseif key == "a" or key == "left" then
    changeZone(-1)
  elseif key == "d" or key == "right" then
    changeZone(1)
  elseif key == "1" or key == "2" or key == "3" then
    changeClass(tonumber(key))
  elseif key == "r" then
    resetSave()
  end
  save()
end

function love.quit()
  if appMode == "playing" then
    save()
  end
end

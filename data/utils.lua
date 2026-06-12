local function createWindowIcon()
  local imageData = love.image.newImageData(32, 32)
  local bg = {0.07, 0.08, 0.1, 1}
  local border = {0.14, 0.16, 0.2, 1}
  local gold = {0.95, 0.8, 0.28, 1}
  local steel = {0.78, 0.86, 0.94, 1}
  local hilt = {0.5, 0.3, 0.16, 1}
  local glow = {0.32, 0.78, 0.66, 1}

  local function pixel(x, y, color)
    imageData:setPixel(x, y, color[1], color[2], color[3], color[4])
  end

  for y = 0, 31 do
    for x = 0, 31 do
      pixel(x, y, bg)
    end
  end

  for i = 0, 31 do
    pixel(i, 0, border)
    pixel(i, 31, border)
    pixel(0, i, border)
    pixel(31, i, border)
  end

  for y = 6, 25 do
    for x = 6, 25 do
      pixel(x, y, {0.1, 0.12, 0.15, 1})
    end
  end

  for x = 9, 22 do
    pixel(x, 23, gold)
  end
  for y = 8, 22 do
    pixel(15, y, steel)
    pixel(16, y, steel)
  end
  for y = 10, 20 do
    pixel(14, y, steel)
    pixel(17, y, steel)
  end
  for x = 12, 19 do
    pixel(x, 22, hilt)
  end
  for y = 23, 27 do
    pixel(15, y, hilt)
    pixel(16, y, hilt)
  end
  pixel(14, 7, glow)
  pixel(17, 7, glow)
  pixel(13, 8, glow)
  pixel(18, 8, glow)
  pixel(12, 9, glow)
  pixel(19, 9, glow)

  return imageData
end

return createWindowIcon

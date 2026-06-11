function love.conf(t)
  t.identity = "deskbar_quest"
  t.appendidentity = false

  t.window.title = "Deskbar Quest"
  t.window.width = 720
  t.window.height = 160
  t.window.minwidth = 720
  t.window.minheight = 160
  t.window.resizable = false
  t.window.vsync = 1
  t.window.highdpi = false
  t.window.usedpiscale = false

  t.modules.joystick = false
  t.modules.physics = false
  t.modules.video = false
end

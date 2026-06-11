function love.conf(t)
  t.identity = "comet_orchard"
  t.appendidentity = false

  t.window.title = "Comet Orchard"
  t.window.width = 960
  t.window.height = 540
  t.window.minwidth = 720
  t.window.minheight = 405
  t.window.resizable = true
  t.window.vsync = 1

  t.modules.joystick = false
  t.modules.physics = false
end

# Comet Orchard

A small arcade survival game made with Lua and LÖVE. Fly through the orchard, crack open hostile comets, and collect the cores they leave behind.

## Run

Install [LÖVE](https://love2d.org/), then run one of these commands:

```powershell
love games/comet-orchard
```

On Windows, if `love` is not on your PATH, use the launcher from the project root:

```powershell
.\run-comet-orchard.bat
```

Or call your installed LÖVE executable directly:

```powershell
& "C:\Program Files\LOVE\love.exe" "games\comet-orchard"
```

## Windows exe build

From the project root:

```powershell
.\build-comet-orchard.bat
```

The build appears in `build\comet-orchard`. Send the whole folder, not only `CometOrchard.exe`, because the exe needs LÖVE's DLL files beside it.

or from this folder:

```powershell
love .
```

## Controls

- Move: `WASD` or arrow keys
- Aim: mouse
- Shoot: left mouse button or `Space`
- Dash: right mouse button, `Left Shift`, or `X`
- Pause: `P` or `Esc`
- Restart after game over: `R`

The game uses procedural drawing, so there are no image or sound assets to download.

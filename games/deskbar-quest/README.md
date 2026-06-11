# Deskbar Quest

A tiny AFK pixel RPG for LÖVE. It sits in a slim desktop window while your hero auto-battles, levels up, gathers loot, and earns offline progress.

## Run

From the project root:

```powershell
.\run-deskbar-quest.bat
```

or directly:

```powershell
& "C:\Program Files\LOVE\love.exe" "games\deskbar-quest"
```

## Build

From the project root:

```powershell
.\build-deskbar-quest.bat
```

The Windows build appears in `build\deskbar-quest`. Send the whole folder, not just the exe.

## Controls

- `U`: buy an upgrade
- `E`: equip the best loot in the bag
- `S`: sell the bag
- `A` / `D`: change zone
- `1`, `2`, `3`: switch class
- `R`: reset save
- Mouse: click the command buttons

Progress is saved automatically.

## Graphics Pack

Deskbar Quest can use external PNG sprites. Put pixel-art sprites in:

```text
games\deskbar-quest\assets\heroes
games\deskbar-quest\assets\monsters
```

Use the filenames listed in `games\deskbar-quest\assets\README.md`. If a sprite is missing, the game falls back to its built-in rectangle art.

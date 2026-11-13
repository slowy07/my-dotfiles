-- bust lua require cache so reload picks up scheme changes
for k in pairs(package.loaded) do
    if k:match("^scheme%.") or k == "variables" or k:match("^hyprland%.") then
        package.loaded[k] = nil
    end
end

-- Monitor: scale is decided by hypr (the shell sets it later via Rules.monitor)
hl.monitor({ output = "", mode = "highres", position = "auto", scale = "auto" })

-- XWayland is scaled by hypr: blurry on HiDPI, but the size is correct at any scale. Sharp at integer scale in user.lua:
--   hl.config({ xwayland = { force_zero_scaling = true } }); hl.env("GDK_SCALE", "2")

-- Configs
require("hyprland.env")
require("hyprland.general")
require("hyprland.input")
require("hyprland.misc")
require("hyprland.animations")
require("hyprland.decoration")
require("hyprland.group")
require("hyprland.execs")
require("hyprland.rules")
require("hyprland.gestures")
require("hyprland.keybinds")

-- custom binds and overrides on top of the rice: hypr/user.lua (in .gitignore, repo updates do not touch it)
local user = io.open(os.getenv("HOME") .. "/.config/hypr/user.lua")
if user then user:close(); require("user") end

-- bust lua require cache so reload picks up scheme changes
for k in pairs(package.loaded) do
    if k:match("^scheme%.") or k == "variables" or k:match("^hyprland%.") then
        package.loaded[k] = nil
    end
end

-- Monitor: масштаб решает hypr (его же потом ставит шелл, Rules.monitor)
hl.monitor({ output = "", mode = "highres", position = "auto", scale = "auto" })

-- XWayland масштабирует hypr: на HiDPI мыльно, зато размер верный при любом масштабе. Чётко на целом масштабе — в user.lua:
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

-- свои бинды и правки поверх риса: hypr/user.lua (в .gitignore, обновления репо его не трогают)
local user = io.open(os.getenv("HOME") .. "/.config/hypr/user.lua")
if user then user:close(); require("user") end

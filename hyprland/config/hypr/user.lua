-- bspwm keybinds ported to Hyprland.
-- Where bspwm and glyph-rice use the same chord, bspwm wins: the glyph bind is
-- removed first and glyph's launcherInterrupt is put back, so tap-Super still
-- opens the launcher. X11-only bspwm scripts are mapped to Wayland/rice
-- equivalents or skipped (see the end of the file).

local vars = require("variables")

local home      = os.getenv("HOME")
local bspwm_bin = home .. "/.config/bspwm/bin/"

-- Remove a glyph bind, then restore glyph's "key was used" marker for tap-Super.
local function take(chord)
    hl.unbind(chord)
    hl.bind(chord, hl.dsp.global("shell:launcherInterrupt"), { non_consuming = true })
end

for _, chord in ipairs({
    -- glyph app / panel binds that bspwm reuses
    "SUPER + Q", "SUPER + W", "SUPER + E", "SUPER + F", "SUPER + V",
    "SUPER + M", "SUPER + P", "SUPER + space", "SUPER + Space",
    "SUPER + Escape", "SUPER + N",
    -- glyph directional focus vs bspwm workspace switch
    "SUPER + left", "SUPER + right",
    -- glyph resize vs bspwm directional focus
    "SUPER + ALT + left", "SUPER + ALT + down", "SUPER + ALT + up", "SUPER + ALT + right",
    -- glyph move-to-special vs bspwm screenshot
    "SUPER + ALT + S",
    -- glyph group/prev/next focus vs bspwm move-window
    "CTRL + SUPER + left", "CTRL + SUPER + Left",
    "CTRL + SUPER + right", "CTRL + SUPER + Right",
    "CTRL + SUPER + Minus",
    -- glyph rice restart vs bspwm reboot
    "CTRL + SUPER + ALT + R",
}) do take(chord) end
for i = 0, 9 do take("CTRL + SUPER + " .. i) end

-- Monitors: HDMI on the left, laptop (eDP-1) on the right. Explicit so
-- position="auto" cannot flip them and the pointer crosses right into eDP.
hl.monitor({ output = "HDMI-A-1", mode = "highres", position = "0x0", scale = "auto" })
hl.monitor({ output = "eDP-1", mode = "highres", position = "auto-right", scale = 1.0 })

-- Workspaces: 1-4 on HDMI, 5-8 on the laptop (eDP). Default workspace on
-- each monitor is 1 and 5, so a fresh session starts there.
hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", default = true })
for i = 2, 4 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "HDMI-A-1" })
end
hl.workspace_rule({ workspace = "5", monitor = "eDP-1", default = true })
for i = 6, 8 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "eDP-1" })
end

-- bspwm launches floating terms/yazi/ncmpcpp with class FloaTerm
hl.window_rule({
    name  = "bspwm-floatterm",
    match = { class = "FloaTerm" },
    float = true,
    size  = "(monitor_w*0.6) (monitor_h*0.6)",
    center = true,
})

hl.window_rule({
    name  = "bspwm-scratch",
    match = { class = "bspwm-scratch" },
    workspace = "special:scratch",
    float = true,
    size  = "(monitor_w*0.7) (monitor_h*0.35)",
    center = true,
})

local function tile()
    hl.dispatch(hl.dsp.window.fullscreen({ action = "unset" }))
    hl.dispatch(hl.dsp.window.pseudo({ action = "off" }))
    hl.dispatch(hl.dsp.window.float({ action = "off" }))
end

local function change_opacity(delta, toggle)
    local f = io.popen("hyprctl getprop active opacity 2>/dev/null")
    local cur = tonumber(f and f:read("*a") or "") or 1.0
    if f then f:close() end

    local value
    if toggle then
        value = (cur < 0.99) and 1.0 or 0.9
    else
        value = math.max(0.2, math.min(1.0, cur + delta))
    end
    hl.exec_cmd(string.format("hyprctl setprop active opacity %.2f", value))
end

-- Marked windows: Hyprland tags stand in for bspwm's marked flag.
local function is_marked(win)
    for _, tag in ipairs(win.tags or {}) do
        if tag == "marked" then return true end
    end
    return false
end

local function toggle_mark()
    local win = hl.get_active_window()
    if not win then return end
    if is_marked(win) then
        hl.dispatch(hl.dsp.window.clear_tags({ window = "address:" .. win.address }))
    else
        hl.dispatch(hl.dsp.window.tag({ tag = "marked", window = "address:" .. win.address }))
    end
end

local function close_others(kill)
    local ws  = hl.get_active_workspace()
    local cur = hl.get_active_window()
    if not ws then return end
    for _, win in ipairs(ws:get_windows()) do
        if not cur or win.address ~= cur.address then
            local d = kill and hl.dsp.window.kill({ window = "address:" .. win.address })
                or hl.dsp.window.close({ window = "address:" .. win.address })
            hl.dispatch(d)
        end
    end
end

local function move_marked_here()
    local ws = hl.get_active_workspace()
    if not ws then return end
    for _, win in ipairs(hl.get_windows({ tag = "marked" })) do
        hl.dispatch(hl.dsp.window.move({
            workspace = tostring(ws.id),
            window    = "address:" .. win.address,
        }))
    end
end

local function move_workspace_here(id)
    local ws = hl.get_workspace(tostring(id))
    local here = hl.get_active_workspace()
    if not ws or not here then return end
    for _, win in ipairs(ws:get_windows()) do
        hl.dispatch(hl.dsp.window.move({
            workspace = tostring(here.id),
            window    = "address:" .. win.address,
        }))
    end
end

-- Applications
hl.bind("SUPER + Return", hl.dsp.exec_cmd(vars.terminal))
hl.bind("SUPER + ALT + Return", hl.dsp.exec_cmd("kitty -1 --class=FloaTerm"))
hl.bind("SUPER + B", hl.dsp.exec_cmd(vars.browser))
hl.bind("SUPER + E", hl.dsp.exec_cmd("geany"))
hl.bind("SUPER + F", hl.dsp.exec_cmd(vars.fileExplorer))
hl.bind("SUPER + Y", hl.dsp.exec_cmd("kitty --hold --name=YaziTerm --class=FloaTerm -e yazi"))
hl.bind("SUPER + V", hl.dsp.exec_cmd("kitty -e nvim"))
hl.bind("SUPER + M", hl.dsp.exec_cmd("kitty --name=MusicTerm --class=FloaTerm -e ncmpcpp"))
hl.bind("SUPER + P", hl.dsp.exec_cmd(vars.audioSettings))
hl.bind("SUPER + T", hl.dsp.exec_cmd("firefox -new-tab https://web.telegram.org/"))
hl.bind("SUPER + W", hl.dsp.exec_cmd("firefox -new-tab https://web.whatsapp.com/"))
hl.bind("SUPER + Space", hl.dsp.global("shell:launcher"))
hl.bind("ALT + Space", hl.dsp.global("shell:settings"))

-- Rofi applets -> rice globals
hl.bind("SUPER + ALT + W", hl.dsp.global("shell:wall"))
hl.bind("SUPER + ALT + C", hl.dsp.global("shell:clip"))
hl.bind("SUPER + ALT + S", hl.dsp.global("shell:shot"))
hl.bind("SUPER + ALT + P", hl.dsp.global("shell:power"))
hl.bind("SUPER + ALT + K", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"))
hl.bind("SUPER + ALT + A", hl.dsp.exec_cmd(bspwm_bin .. "AndroidMount"))
hl.bind("SUPER + ALT + N", hl.dsp.exec_cmd("nm-connection-editor"))
hl.bind("SUPER + ALT + B", hl.dsp.exec_cmd("blueman-manager"))
hl.bind("SUPER + ALT + O", function()
    local ws = hl.get_workspace("special:scratch")
    if not ws or #ws:get_windows() == 0 then
        hl.dispatch(hl.dsp.exec_cmd("kitty -1 --class=bspwm-scratch"))
    end
    hl.dispatch(hl.dsp.workspace.toggle_special("scratch"))
end)

-- Power / session
hl.bind("CTRL + SUPER + ALT + P", hl.dsp.exec_cmd("systemctl poweroff"))
hl.bind("CTRL + SUPER + ALT + R", hl.dsp.exec_cmd("systemctl reboot"))
hl.bind("CTRL + SUPER + ALT + Q", hl.dsp.exit())
hl.bind("CTRL + SUPER + ALT + L", hl.dsp.exec_cmd(vars.lockCmd))
hl.bind("CTRL + SUPER + ALT + K", hl.dsp.exec_cmd("hyprctl kill"))
hl.bind("CTRL + SUPER + ALT + S", hl.dsp.reload_config())

-- Reload
hl.bind("SUPER + ALT + R", hl.dsp.reload_config())
hl.bind("SUPER + Escape", hl.dsp.reload_config())

-- Windows
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + Q", hl.dsp.window.kill())

-- bspwm pointer_modifier=mod4: Super+left drags the window, Super+right resizes it
take("SUPER + mouse:272")
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
take("SUPER + mouse:273")
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("ALT + T", tile)
hl.bind("ALT + SHIFT + T", hl.dsp.window.pseudo({ action = "toggle" }))
hl.bind("ALT + A", hl.dsp.window.float({ action = "toggle" }))
hl.bind("ALT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
-- pin disabled: windows stay on their workspace like bspwm
hl.bind("ALT + M", toggle_mark)
hl.bind("ALT + H", hl.dsp.window.move({ workspace = "special:hidden" }))
hl.bind("CTRL + ALT + H", hl.dsp.workspace.toggle_special("hidden"))
hl.bind("CTRL + TAB", hl.dsp.layout("rotatesplit"))

-- Desktop focus / send
hl.bind("SUPER + left", hl.dsp.focus({ workspace = "-1" }), { repeating = true })
hl.bind("SUPER + right", hl.dsp.focus({ workspace = "+1" }), { repeating = true })
hl.bind("CTRL + SUPER + left", hl.dsp.window.move({ workspace = "-1" }))
hl.bind("CTRL + SUPER + right", hl.dsp.window.move({ workspace = "+1" }))
for i = 1, 10 do
    hl.bind("CTRL + SUPER + " .. (i % 10), hl.dsp.window.move({ workspace = tostring(i) }))
end

-- Focus / swap / move
hl.bind("SUPER + ALT + left", hl.dsp.focus({ direction = "left" }), { repeating = true })
hl.bind("SUPER + ALT + down", hl.dsp.focus({ direction = "down" }), { repeating = true })
hl.bind("SUPER + ALT + up", hl.dsp.focus({ direction = "up" }), { repeating = true })
hl.bind("SUPER + ALT + right", hl.dsp.focus({ direction = "right" }), { repeating = true })

hl.bind("CTRL + ALT + left", hl.dsp.window.swap({ direction = "left" }))
hl.bind("CTRL + ALT + down", hl.dsp.window.swap({ direction = "down" }))
hl.bind("CTRL + ALT + up", hl.dsp.window.swap({ direction = "up" }))
hl.bind("CTRL + ALT + right", hl.dsp.window.swap({ direction = "right" }))

hl.bind("CTRL + SHIFT + Comma", hl.dsp.focus({ last = true }))
hl.bind("CTRL + SHIFT + Period", hl.dsp.focus({ workspace = "previous" }))

-- Resize
hl.bind("SUPER + ALT + SHIFT + Equal", hl.dsp.window.resize({ x = 20, y = 20, relative = true }), { repeating = true })
hl.bind("SUPER + ALT + Minus", hl.dsp.window.resize({ x = -20, y = -20, relative = true }), { repeating = true })
hl.bind("SUPER + CTRL + SHIFT + Equal", hl.dsp.window.resize({ x = 50, y = 25, relative = true }), { repeating = true })
hl.bind("SUPER + CTRL + Minus", hl.dsp.window.resize({ x = -50, y = -25, relative = true }), { repeating = true })

-- Transparency (picom-trans replacement)
hl.bind("CTRL + ALT + SHIFT + Equal", function() change_opacity(0.03, false) end)
hl.bind("CTRL + ALT + Minus", function() change_opacity(-0.03, false) end)
hl.bind("CTRL + ALT + T", function() change_opacity(0, true) end)

-- Close everything on the desktop
hl.bind("CTRL + SUPER + X", function()
    local ws = hl.get_active_workspace()
    if not ws then return end
    for _, win in ipairs(ws:get_windows()) do
        hl.dispatch(hl.dsp.window.close({ window = "address:" .. win.address }))
    end
end)

-- super + n ; x|k|m|1-9
hl.define_submap("bspwm_multi", function()
    hl.bind("X", function() close_others(false) end)
    hl.bind("K", function() close_others(true) end)
    hl.bind("M", move_marked_here)
    for i = 1, 9 do
        hl.bind(tostring(i), function() move_workspace_here(i) end)
    end
    hl.bind("Escape", hl.dsp.submap("reset"))
end)
hl.bind("SUPER + N", hl.dsp.submap("bspwm_multi"))

-- Skipped: X11/rofi/bspwm-only binds with no working Wayland equivalent:
--   alt+F1 KeyHelp, alt+space RiceSelector (-> settings), super+r RiceEditor,
--   super+alt+t terminal picker, super+alt+l rofi style, super+alt+x RofiPass,
--   super+alt+h/u bar toggle, alt+x locked, alt+p private,
--   super+ctrl+h/v/q preselect, super+ctrl+b balance, super+{n};{...} is above.
-- Volume, media and brightness keys already exist in keybinds.lua with the same
-- actions, so they are not bound twice.

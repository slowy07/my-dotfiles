-- Follows the Glyph colorscheme stored in ~/.local/state/rice/glyph.json.
local M = {}

local state = vim.fn.expand "~/.local/state/rice/glyph.json"

local function read_scheme()
  local file = io.open(state, "r")
  if not file then
    return "everblush"
  end
  local text = file:read "*a"
  file:close()
  local ok, data = pcall(vim.json.decode, text)
  if ok and data.scheme == "aphelion" then
    return "aphelion"
  end
  return "everblush"
end

M.current = read_scheme

function M.apply()
  local scheme = read_scheme()
  local ok, nvconfig = pcall(require, "nvconfig")
  if not ok or nvconfig.base46.theme == scheme then
    return
  end
  require("nvchad.themes.utils").reload_theme(scheme)
end

function M.watch()
  local uv = vim.uv or vim.loop
  local watcher = uv.new_fs_event()
  if not watcher then
    return
  end
  watcher:start(vim.fn.fnamemodify(state, ":h"), {}, vim.schedule_wrap(function(err, filename)
    if err or (filename and filename ~= "glyph.json") then
      return
    end
    M.apply()
  end))
end

return M

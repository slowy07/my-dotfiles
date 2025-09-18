require "nvchad.options"

local M = {}

M.stbufnr = function()
  return vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
end

-- add yours here!

local o = vim.o
o.cursorlineopt = "both" -- to enable cursorline!
o.background = "dark"
vim.opt.relativenumber = true


local highlights = {
  Normal          = { fg = "#f4f4f4", bg = "#141b1e" },
  Separator       = { fg = "#232a2d", bg = "#141b1e" },
  Separator2      = { fg = "#3a435a", bg = "#232a2d" },
  ModeText        = { fg = "#956dca", bg = "#232a2d" },
  PathText        = { fg = "#956dca", bg = "#232a2d" },
  FileText        = { fg = "#f4f3ee", bg = "#232a2d" },
  FileType        = { fg = "#e37e4f", bg = "#232a2d" },
  BranchName      = { fg = "#69bfce", bg = "#232a2d" },
  LineText        = { fg = "#e34f4f", bg = "#232a2d" },
  ColumnText      = { fg = "#5679e3", bg = "#232a2d" },
  PercentageText  = { fg = "#5599e2", bg = "#232a2d" },
  TotalLineText   = { fg = "#956dca", bg = "#232a2d" },
  DiagnosticsText = { fg = "#67b0e8", bg = "#232a2d" },
  LSPColor        = { fg = "#8ccf7e", bg = "#232a2d" },

  DiagError       = { fg = "#e06c75", bg = "#232a2d" },
  DiagWarn        = { fg = "#e5c07b", bg = "#232a2d" },
  DiagInfo        = { fg = "#61afef", bg = "#232a2d" },
  DiagHint        = { fg = "#98c379", bg = "#232a2d" },
}

for group, opts in pairs(highlights) do
  vim.api.nvim_set_hl(0, group, opts)
end

_G.RecolorMode = function()
  local mode = vim.fn.mode()
  local color_map = {
    n     = { fg = "#5599e2", bg = "#232a2d" },
    i     = { fg = "#e34f4f", bg = "#232a2d" },
    R     = { fg = "#69bfce", bg = "#141b1e" },
    v     = { fg = "#e37e4f", bg = "#232a2d" },
    V     = { fg = "#e37e4f", bg = "#141b1e" },
    ["V"] = { fg = "#e37e4f", bg = "#141b1e" },
    c     = { fg = "#5679e3", bg = "#232a2d" },
    t     = { fg = "#5679e3", bg = "#141b1e" },
  }

  local hl = color_map[mode]
  if hl then
    vim.api.nvim_set_hl(0, "ModeText", hl)
  end
  return ""
end

_G.SetFiletype = function(filetype)
  return (filetype == nil or filetype == "") and "unknown" or filetype
end

_G.file = function()
  local icon = "󰈤"
  local path = vim.api.nvim_buf_get_name(M.stbufnr())
  local name = (path == "" and "Empty") or path:match "([^/\\]+)[/\\]*$"

  if name ~= "Empty" then
    local devicons_present, devicons = pcall(require, "nvim-web-devicons")

    if devicons_present then
      local ft_icon = devicons.get_icon(name)
      icon = (ft_icon ~= nil and ft_icon) or icon
    end
  end

  return " " .. icon .. " " .. name
end

_G.git = function()
  if not vim.b[M.stbufnr()].gitsigns_head or vim.b[M.stbufnr()].gitsigns_git_status then
    return " no repo"
  end

  local git_status = vim.b[M.stbufnr()].gitsigns_status_dict

  local added = (git_status.added and git_status.added ~= 0) and ("  " .. git_status.added) or ""
  local changed = (git_status.changed and git_status.changed ~= 0) and ("  " .. git_status.changed) or ""
  local removed = (git_status.removed and git_status.removed ~= 0) and ("  " .. git_status.removed) or ""
  local branch_name = " " .. git_status.head

  return " " .. branch_name .. added .. changed .. removed .. " "
end

_G.diagnostics_color = function()
  if not rawget(vim, "lsp") then
    return "%#DiagnosticsText#󰞇 %*"
  end

  local err = #vim.diagnostic.get(M.stbufnr(), { severity = vim.diagnostic.severity.ERROR })
  local warn = #vim.diagnostic.get(M.stbufnr(), { severity = vim.diagnostic.severity.WARN })
  local info = #vim.diagnostic.get(M.stbufnr(), { severity = vim.diagnostic.severity.INFO })
  local hints = #vim.diagnostic.get(M.stbufnr(), { severity = vim.diagnostic.severity.HINT })

  local parts = {}
  if err > 0 then
    table.insert(parts, "%#DiagError# " .. err .. " %*")
  end
  if warn > 0 then
    table.insert(parts, "%#DiagWarn# " .. warn .. " %*")
  end
  if info > 0 then
    table.insert(parts, "%#DiagInfo#󰋼 " .. info .. " %*")
  end
  if hints > 0 then
    table.insert(parts, "%#DiagHint#󰛩 " .. hints .. " %*")
  end

  if #parts == 0 then
    return "%#DiagnosticsText#󰞇 %*"
  else
    return table.concat(parts, "")
  end
end

_G.lsp = function()
  if rawget(vim, "lsp") then
    for _, client in ipairs(vim.lsp.get_clients()) do
      if client.attached_buffers[M.stbufnr()] then
        return (vim.o.columns > 100 and "   LSP ~ " .. client.name .. " ") or "   LSP "
      end
    end
  end

  return ""
end

_G.HandleColumnGap = function()
  local col = vim.fn.col(".")
  return col > 9 and " " or " "
end

vim.opt.statusline = table.concat({
  "%{%v:lua.RecolorMode()%}",

  "%#Separator#█",
  "%#ModeText#",
  "%#Separator#██",

  "%#PathText#%{expand('%:p:h:t')}",
  "%#Separator#██",
  "%{%v:lua.diagnostics_color()%}",
  "%#Separator#",

  "%=",

  "%#Separator#",
  "%#FileType#%{v:lua.file()}",
  "%#Separator# ",

  "%#Separator#",
  "%#BranchName#%{v:lua.git()}",
  "%#Separator# ",

  "%#Separator#",
  "%#LSPColor#%{v:lua.lsp()}",
  "%#Separator#█",
  "%#BranchName#%{v:lua.HandleColumnGap()}",
  "%#ColumnText#%2c",

  "%#Separator2#",
  "%#Separator#██",
  "%#PercentageText#%p%%",
  "%#Separator#█",
  "%#Separator2#",
  "%#Separator#█",
  "%#TotalLineText#%L",
  "%#Separator#█",
})

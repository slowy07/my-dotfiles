require("mywpm").setup({
  notify = false,
  show_virtual_text = true,
  follow_cursor = true,
  virt_wpm_pos = "eol",
  mapping = false, -- mapped manually in lua/mappings.lua
  virt_wpm = function(wpm)
    return (" speed: %0.f"):format(wpm)
  end
})

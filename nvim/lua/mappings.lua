require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

-- NeoCodeium (Windsurf AI) -- leader + a, then the action's first letter:
--   a accept   w accept word   l accept line   d dismiss
--   n next      p previous
--   t toggle    b buffer        c chat          e log
local function ai()
  require("lazy").load { plugins = { "monkoose/neocodeium" } }
  return require "neocodeium"
end

local function ai_cmd(action)
  require("lazy").load { plugins = { "monkoose/neocodeium" } }
  require("neocodeium.commands")[action]()
end

map("i", "<leader>aa", function() ai().accept() end, { desc = "AI accept suggestion" })
map("i", "<leader>aw", function() ai().accept_word() end, { desc = "AI accept word" })
map("i", "<leader>al", function() ai().accept_line() end, { desc = "AI accept line" })
map("i", "<leader>an", function() ai().cycle(1) end, { desc = "AI next suggestion" })
map("i", "<leader>ap", function() ai().cycle(-1) end, { desc = "AI previous suggestion" })
map("i", "<leader>ad", function() ai().clear() end, { desc = "AI dismiss suggestion" })

map("n", "<leader>at", function() ai_cmd "toggle" end, { desc = "AI toggle (global)" })
map("n", "<leader>ab", function() ai_cmd "toggle_buffer" end, { desc = "AI toggle (buffer)" })
map("n", "<leader>ac", function() ai_cmd "chat" end, { desc = "AI chat in browser" })
map("n", "<leader>ae", function() ai_cmd "open_log" end, { desc = "AI open log" })

-- cmp no longer auto-triggers (see plugins/init.lua); <C-Space> is the NvChad
-- default, this is the leader fallback (macOS can steal <C-Space>)
map("i", "<leader>cc", function()
  require("cmp").complete()
end, { desc = "cmp complete" })

-- table-mode.nvim: a Lua port of dhruvasagar/vim-table-mode
if vim.g.loaded_table_mode then
  return
end
vim.g.loaded_table_mode = 1

require('table-mode.config').init()

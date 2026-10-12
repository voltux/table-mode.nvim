-- Port of autoload/tablemode/logger.vim
local M = {}

function M.log(message)
  if vim.g.table_mode_verbose ~= 0 then
    vim.api.nvim_echo({ { message } }, true, {})
  end
end

return M

-- Port of plugin/table-mode.vim: option defaults, commands and mappings.
local fn = vim.fn
local api = vim.api

local M = {}

-- Options whose current value is a default, so init() may recompute it
-- after setup() changes what it is derived from (e.g. map_prefix).
local defaulted = {}
-- Global mappings made by init(), removed when it runs again.
local global_maps = {}

local function SetGlobalOptDefault(opt, val)
  local name = 'table_mode_' .. opt
  if vim.g[name] == nil or defaulted[name] then
    vim.g[name] = val
    defaulted[name] = true
  end
end

local function map(mode, lhs, rhs, opts)
  vim.keymap.set(mode, lhs, rhs, opts)
  if not lhs:find('^<Plug>') then
    global_maps[#global_maps + 1] = { mode, lhs }
  end
end

function M.init()
  local g = vim.g

  for _, m in ipairs(global_maps) do
    pcall(vim.keymap.del, m[1], m[2])
  end
  global_maps = {}

  -- Set Global Defaults {{{1
  SetGlobalOptDefault('corner', '+')
  SetGlobalOptDefault('verbose', 1)
  SetGlobalOptDefault('separator', '|')
  -- '|' is a special character, we need to map <Bar> instead
  -- the character to map from
  SetGlobalOptDefault('separator_map', g.table_mode_separator)
  if g.table_mode_separator_map == '|' then
    g.table_mode_separator_map = '<Bar>'
  end
  -- the character to map to (when inserting the separator)
  g.table_mode_separator_map_target = g.table_mode_separator
  if g.table_mode_separator_map_target == '|' then
    g.table_mode_separator_map_target = '<Bar>'
  end
  SetGlobalOptDefault('escaped_separator_regex', [[\V\C\\\@1<!]] .. fn.escape(g.table_mode_separator, '\\'))
  SetGlobalOptDefault('fillchar', '-')
  SetGlobalOptDefault('header_fillchar', '-')
  SetGlobalOptDefault('map_prefix', '<Leader>t')
  SetGlobalOptDefault('toggle_map', 'm')
  SetGlobalOptDefault('always_active', 0)
  SetGlobalOptDefault('delimiter', ',')
  SetGlobalOptDefault('corner_corner', '|')
  SetGlobalOptDefault('align_char', ':')
  SetGlobalOptDefault('disable_mappings', 0)
  SetGlobalOptDefault('disable_tableize_mappings', 0)

  SetGlobalOptDefault('motion_up_map', '{<Bar>')
  SetGlobalOptDefault('motion_down_map', '}<Bar>')
  SetGlobalOptDefault('motion_left_map', '[<Bar>')
  SetGlobalOptDefault('motion_right_map', ']<Bar>')

  SetGlobalOptDefault('cell_text_object_a_map', 'a<Bar>')
  SetGlobalOptDefault('cell_text_object_i_map', 'i<Bar>')

  local prefix = g.table_mode_map_prefix
  SetGlobalOptDefault('realign_map', prefix .. 'r')
  SetGlobalOptDefault('delete_row_map', prefix .. 'dd')
  SetGlobalOptDefault('delete_column_map', prefix .. 'dc')
  SetGlobalOptDefault('insert_column_before_map', prefix .. 'iC')
  SetGlobalOptDefault('insert_column_after_map', prefix .. 'ic')
  SetGlobalOptDefault('add_formula_map', prefix .. 'fa')
  SetGlobalOptDefault('eval_formula_map', prefix .. 'fe')
  SetGlobalOptDefault('echo_cell_map', prefix .. '?')
  SetGlobalOptDefault('sort_map', prefix .. 's')
  SetGlobalOptDefault('tableize_map', prefix .. 't')
  SetGlobalOptDefault('tableize_d_map', '<Leader>T')

  SetGlobalOptDefault('syntax_dict', {
    contains = 'TableBorder,TableSeparator,TableColumnAlign,'
      .. 'yesCell,noCell,maybeCell,redCell,greenCell,yellowCell,blueCell,whiteCell,darkCell',
    containedin = 'ALL',
  })

  SetGlobalOptDefault('syntax', 1)
  SetGlobalOptDefault('auto_align', 1)
  SetGlobalOptDefault('update_time', 500)
  SetGlobalOptDefault('tableize_auto_border', 0)
  SetGlobalOptDefault('ignore_align', 0)

  -- Commands and mappings {{{1
  local cmd = api.nvim_create_user_command
  if g.table_mode_always_active == 0 then
    if g.table_mode_disable_mappings == 0 then
      map('n', g.table_mode_map_prefix .. g.table_mode_toggle_map,
        [[:<C-U>lua require('table-mode').Toggle()<CR>]], { silent = true })
    end
    cmd('TableModeToggle', function() require('table-mode').Toggle() end, { nargs = 0 })
    cmd('TableModeEnable', function() require('table-mode').Enable() end, { nargs = 0 })
    cmd('TableModeDisable', function() require('table-mode').Disable() end, { nargs = 0 })
  else
    pcall(api.nvim_del_user_command, 'TableModeToggle')
    pcall(api.nvim_del_user_command, 'TableModeEnable')
    pcall(api.nvim_del_user_command, 'TableModeDisable')
    map('i', g.table_mode_separator_map,
      g.table_mode_separator_map_target .. [[<Esc>:lua require('table-mode').TableizeInsertMode()<CR>a]],
      { silent = true })
  end

  -- Like `:<line1>,<line2>call`, put the cursor at the start of the range.
  -- For TableSort this means it sorts on the first column, as upstream does.
  cmd('Tableize', function(o)
    api.nvim_win_set_cursor(0, { o.line1, 0 })
    require('table-mode').TableizeRange(o.args, o.line1, o.line2)
  end, { nargs = '?', range = true })
  cmd('TableSort', function(o)
    api.nvim_win_set_cursor(0, { o.line1, 0 })
    require('table-mode.spreadsheet').Sort(o.bang, o.args, o.line1, o.line2)
  end, { nargs = '?', bang = true, range = true })
  cmd('TableAddFormula', function() require('table-mode.spreadsheet.formula').Add() end, {})
  cmd('TableModeRealign', function() require('table-mode.table').Realign('.') end, {})
  cmd('TableEvalFormulaLine', function() require('table-mode.spreadsheet.formula').EvaluateFormulaLine() end, {})

  local s = { silent = true }
  map('i', '<Plug>(table-mode-tableize)',
    g.table_mode_separator_map .. [[<Esc>:lua require('table-mode').TableizeInsertMode()<CR>a]], s)

  map('n', '<Plug>(table-mode-tableize)', ':Tableize<CR>', s)
  map('x', '<Plug>(table-mode-tableize)', ':Tableize<CR>', s)
  map('x', '<Plug>(table-mode-tableize-delimiter)', [[:<C-U>lua require('table-mode').TableizeByDelimiter()<CR>]], s)

  -- Without <C-U>, a count calls these once per line, as in vim-table-mode.
  map('n', '<Plug>(table-mode-realign)', [[:call v:lua.require'table-mode.table'.Realign('.')<CR>]], s)

  for plug, dir in pairs({ up = 'k', down = 'j', left = 'h', right = 'l' }) do
    map('n', '<Plug>(table-mode-motion-' .. plug .. ')',
      [[:<C-U>lua require('table-mode.spreadsheet.cell').Motion(']] .. dir .. [[')<CR>]], s)
  end

  for _, mode in ipairs({ 'o', 'x' }) do
    map(mode, '<Plug>(table-mode-cell-text-object-a)', [[:<C-U>lua require('table-mode.spreadsheet.cell').TextObject(false)<CR>]], s)
    map(mode, '<Plug>(table-mode-cell-text-object-i)', [[:<C-U>lua require('table-mode.spreadsheet.cell').TextObject(true)<CR>]], s)
  end

  map('n', '<Plug>(table-mode-delete-row)', [[:<C-U>lua require('table-mode.spreadsheet').DeleteRow()<CR>]], s)
  map('n', '<Plug>(table-mode-delete-column)', [[:<C-U>lua require('table-mode.spreadsheet').DeleteColumn()<CR>]], s)
  map('n', '<Plug>(table-mode-insert-column-before)', [[:<C-U>lua require('table-mode.spreadsheet').InsertColumn(false)<CR>]], s)
  map('n', '<Plug>(table-mode-insert-column-after)', [[:<C-U>lua require('table-mode.spreadsheet').InsertColumn(true)<CR>]], s)

  map('n', '<Plug>(table-mode-add-formula)', [[:call v:lua.require'table-mode.spreadsheet.formula'.Add()<CR>]], s)
  map('n', '<Plug>(table-mode-eval-formula)', [[:call v:lua.require'table-mode.spreadsheet.formula'.EvaluateFormulaLine()<CR>]], s)

  map('n', '<Plug>(table-mode-echo-cell)', [[:call v:lua.require'table-mode.spreadsheet'.EchoCell()<CR>]], s)

  map('n', '<Plug>(table-mode-sort)', [[:<C-U>lua require('table-mode.config').sort_map()<CR>]], s)

  if g.table_mode_disable_tableize_mappings == 0 then
    if fn.hasmapto('<Plug>(table-mode-tableize)') == 0 then
      map('n', g.table_mode_tableize_map, '<Plug>(table-mode-tableize)', { remap = true })
      map('x', g.table_mode_tableize_map, '<Plug>(table-mode-tableize)', { remap = true })
    end

    if fn.hasmapto('<Plug>(table-mode-tableize-delimiter)') == 0 then
      map('x', g.table_mode_tableize_d_map, '<Plug>(table-mode-tableize-delimiter)', { remap = true })
    end
  end

  local group = api.nvim_create_augroup('TableMode', { clear = true })
  api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'TableModeEnabled',
    callback = function() require('table-mode.logger').log('Table Mode Enabled') end,
  })
  api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'TableModeDisabled',
    callback = function() require('table-mode.logger').log('Table Mode Disabled') end,
  })
end

-- <Plug>(table-mode-sort): `:call Sort('')` with an optional count, which
-- vim-table-mode turns into a `.,.+(count-1)` range.
function M.sort_map()
  local spreadsheet = require('table-mode.spreadsheet')
  local count = vim.v.count
  if count == 0 then
    return spreadsheet.Sort(false, '')
  end
  local first = fn.line('.')
  local last = first + count - 1
  if last > fn.line('$') then
    vim.notify('E16: Invalid range', vim.log.levels.ERROR)
    return
  end
  -- unlike with :TableSort, the cursor column survives the range here
  local curswant = fn.getcurpos()[5]
  api.nvim_win_set_cursor(0, { first, 0 })
  spreadsheet.Sort(false, '', first, last, curswant)
end

function M.setup(opts)
  for key, val in pairs(opts or {}) do
    local name = 'table_mode_' .. key
    vim.g[name] = val
    defaulted[name] = nil
  end
  if opts and opts.separator ~= nil then
    -- recompute what derives from the separator unless given too
    for _, key in ipairs({ 'separator_map', 'escaped_separator_regex' }) do
      if opts[key] == nil then
        defaulted['table_mode_' .. key] = true
      end
    end
  end
  M.init()
end

return M

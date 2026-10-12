-- Port of autoload/tablemode.vim
local fn = vim.fn
local api = vim.api
local utils = require('table-mode.utils')
local tbl = require('table-mode.table')

local M = {}

-- Private Functions {{{1
local function SetBufferOptDefault(opt, val)
  if vim.b[opt] == nil then
    vim.b[opt] = val
  end
end

local function Map(map, to, mode)
  if to ~= nil and to ~= '' and to ~= 0 and fn.hasmapto(map, mode) == 0 then
    for m in mode:gmatch('.') do
      vim.cmd(m .. 'map <buffer> ' .. to .. ' ' .. map)
    end
  end
end

local function UnMap(map, mode)
  if fn.maparg(map, mode) ~= '' then
    for m in mode:gmatch('.') do
      pcall(vim.cmd, m .. 'unmap <buffer> ' .. map)
    end
  end
end

local function ToggleMapping()
  local g = vim.g
  if g.table_mode_disable_mappings ~= 0 then
    return
  end
  if M.IsActive() then
    Map('<Plug>(table-mode-tableize)', g.table_mode_separator_map, 'i')
    Map('<Plug>(table-mode-motion-up)', g.table_mode_motion_up_map, 'n')
    Map('<Plug>(table-mode-motion-down)', g.table_mode_motion_down_map, 'n')
    Map('<Plug>(table-mode-motion-left)', g.table_mode_motion_left_map, 'n')
    Map('<Plug>(table-mode-motion-right)', g.table_mode_motion_right_map, 'n')

    Map('<Plug>(table-mode-cell-text-object-a)', g.table_mode_cell_text_object_a_map, 'ox')
    Map('<Plug>(table-mode-cell-text-object-i)', g.table_mode_cell_text_object_i_map, 'ox')

    Map('<Plug>(table-mode-realign)', g.table_mode_realign_map, 'n')
    Map('<Plug>(table-mode-delete-row)', g.table_mode_delete_row_map, 'n')
    Map('<Plug>(table-mode-delete-column)', g.table_mode_delete_column_map, 'n')
    Map('<Plug>(table-mode-insert-column-before)', g.table_mode_insert_column_before_map, 'n')
    Map('<Plug>(table-mode-insert-column-after)', g.table_mode_insert_column_after_map, 'n')
    Map('<Plug>(table-mode-add-formula)', g.table_mode_add_formula_map, 'n')
    Map('<Plug>(table-mode-eval-formula)', g.table_mode_eval_formula_map, 'n')
    Map('<Plug>(table-mode-echo-cell)', g.table_mode_echo_cell_map, 'n')
    Map('<Plug>(table-mode-sort)', g.table_mode_sort_map, 'n')
  else
    UnMap(g.table_mode_separator_map, 'i')
    UnMap(g.table_mode_motion_up_map, 'n')
    UnMap(g.table_mode_motion_down_map, 'n')
    UnMap(g.table_mode_motion_left_map, 'n')
    UnMap(g.table_mode_motion_right_map, 'n')

    UnMap(g.table_mode_cell_text_object_a_map, 'ox')
    UnMap(g.table_mode_cell_text_object_i_map, 'ox')

    UnMap(g.table_mode_realign_map, 'n')
    UnMap(g.table_mode_delete_row_map, 'n')
    UnMap(g.table_mode_delete_column_map, 'n')
    UnMap(g.table_mode_insert_column_before_map, 'n')
    UnMap(g.table_mode_insert_column_after_map, 'n')
    UnMap(g.table_mode_add_formula_map, 'n')
    UnMap(g.table_mode_eval_formula_map, 'n')
    UnMap(g.table_mode_echo_cell_map, 'n')
    UnMap(g.table_mode_sort_map, 'n')
  end
end

local function ToggleSyntax()
  if vim.g.table_mode_syntax == 0 then
    return
  end

  if M.IsActive() then
    local syntax_dict = utils.get_buffer_or_global_option('table_mode_syntax_dict')
    vim.cmd('syntax match Table'
      .. ' /' .. tbl.StartExpr() .. [[\zs|.\+|\ze]] .. tbl.EndExpr() .. '/'
      .. ' contains=' .. syntax_dict.contains
      .. ' containedin=' .. syntax_dict.containedin)
    vim.cmd([[
      syntax match TableSeparator /|/ contained
      syntax match TableColumnAlign /:/ contained
      syntax match TableBorder /[\-+]\+/ contained

      hi! link TableBorder Delimiter
      hi! link TableSeparator Delimiter
      hi! link TableColumnAlign Type

      syntax match redCell '|\zs *r:[^|]*' contained
      hi redCell ctermfg=9 ctermbg=1

      syntax match greenCell '|\zs *g:[^|]*' contained
      hi greenCell ctermfg=10 ctermbg=2

      syntax match yellowCell '|\zs *y:[^|]*' contained
      hi yellowCell ctermfg=11 ctermbg=3

      syntax match blueCell  '|\zs *b:[^|]*' contained
      hi blueCell ctermfg=12 ctermbg=4

      syntax match whiteCell '|\zs *w:[^|]*' contained
      hi whiteCell ctermfg=0 ctermbg=15

      syntax match darkCell '|\zs *d:[^|]*' contained
      hi darkCell ctermfg=15 ctermbg=0
    ]])

    local color_cells = vim.g.table_mode_color_cells
    if color_cells ~= nil and color_cells ~= 0 and color_cells ~= false then
      vim.cmd([[
        syntax match yesCell '|\zs *yes[^|]*' contained
        syntax match noCell '|\zs *no\A[^|]*' contained
        syntax match maybeCell '|\zs *?[^|]*' contained
      ]])
    end
  else
    for _, group in ipairs({ 'Table', 'TableBorder', 'TableSeparator', 'TableColumnAlign' }) do
      pcall(vim.cmd, 'syntax clear ' .. group)
    end

    vim.cmd([[
      hi! link TableBorder NONE
      hi! link TableSeparator NONE
      hi! link TableColumnAlign NONE
    ]])
  end
end

local function ToggleAutoAlign()
  if vim.g.table_mode_auto_align == 0 then
    return
  end

  if M.IsActive() then
    local group = api.nvim_create_augroup('TableModeAutoAlign', { clear = true })
    api.nvim_create_autocmd('CursorHold', {
      group = group,
      buffer = 0,
      nested = true,
      callback = function()
        if vim.bo.modified then
          pcall(tbl.Realign, '.')
        end
      end,
    })
  else
    pcall(api.nvim_clear_autocmds, { group = 'TableModeAutoAlign' })
  end
end

local function ToggleOptions()
  if M.IsActive() then
    vim.b.old_update_time = vim.o.updatetime
    vim.o.updatetime = vim.g.table_mode_update_time
  else
    vim.o.updatetime = vim.b.old_update_time or 4000
  end
end

local function SetActive(bool)
  vim.b.table_mode_active = bool and 1 or 0
  ToggleSyntax()
  ToggleMapping()
  ToggleAutoAlign()
  ToggleOptions()
  if M.IsActive() then
    api.nvim_exec_autocmds('User', { pattern = 'TableModeEnabled' })
  else
    api.nvim_exec_autocmds('User', { pattern = 'TableModeDisabled' })
  end
end

local function ConvertDelimiterToSeparator(line, delim)
  local old_gdefault = vim.o.gdefault
  vim.o.gdefault = false

  delim = delim or vim.g.table_mode_delimiter
  if delim == ',' then
    vim.cmd('silent! ' .. line .. [=[s/['"][^'"]*\zs,\ze[^'"]*['"]/__COMMA__/g]=])
  end

  local cstart, cend = tbl.GetCommentStart(), tbl.GetCommentEnd()
  local match_char_start, match_char_end = '.', '.'
  if utils.strlen(cend) > 0 then
    match_char_end = '[^' .. cend .. ']'
  end
  if utils.strlen(cstart) > 0 then
    match_char_start = '[^' .. cstart .. ']'
  end

  vim.cmd('silent! ' .. line .. 's/' .. tbl.StartExpr() .. [[\zs\ze]] .. match_char_start
    .. [[\|]] .. delim .. [[\|]] .. match_char_end .. [[\zs\ze]] .. tbl.EndExpr() .. '/'
    .. vim.g.table_mode_separator .. '/g')

  if delim == ',' then
    vim.cmd('silent! ' .. line .. [=[s/['"][^'"]*\zs__COMMA__\ze[^'"]*['"]/,/g]=])
  end

  vim.o.gdefault = old_gdefault
end

local function Tableizeline(line, delim_arg)
  local delim = vim.g.table_mode_delimiter
  if type(delim_arg) == 'string' and delim_arg ~= '' then
    delim = delim_arg:sub(2)
  end
  ConvertDelimiterToSeparator(line, delim)
end

-- Public API {{{1
function M.IsActive()
  if vim.g.table_mode_always_active ~= 0 then
    return true
  end

  SetBufferOptDefault('table_mode_active', 0)
  local active = vim.b.table_mode_active
  return active ~= 0 and active ~= false
end

function M.TableizeInsertMode()
  if not M.IsActive() then
    return
  end
  local sep = vim.g.table_mode_separator
  local text = fn.getline('.')
  if utils.ismatch(text, tbl.StartExpr() .. sep .. sep .. tbl.EndExpr()) then
    tbl.AddBorder('.')
    vim.cmd('normal! A')
  elseif utils.ismatch(text, tbl.StartExpr() .. sep) then
    local upto = utils.slice(text, 0, fn.col('.'))
    local column = utils.strlen(fn.substitute(upto, '[^' .. sep .. ']', '', 'g'))
    local position = utils.strlen(fn.matchstr(upto, '.*' .. sep .. [[\s*\zs.*]]))
    tbl.Realign('.')
    vim.cmd('normal! 0')
    fn.search(string.rep('[^' .. sep .. ']*' .. sep, column) .. [[\s\{-\}]] .. string.rep('.', position), 'ce', fn.line('.'))
  end
end

function M.Enable()
  SetActive(true)
end

function M.Disable()
  SetActive(false)
end

function M.Toggle()
  if vim.g.table_mode_always_active ~= 0 then
    return 1
  end

  SetBufferOptDefault('table_mode_active', 0)
  SetActive(not M.IsActive())
end

-- delim: the delimiter prefixed with any character (e.g. '/;'), or '' to use
-- g:table_mode_delimiter.
function M.TableizeRange(delim, firstline, lastline)
  firstline = firstline or fn.line('.')
  lastline = lastline or firstline
  local lnum = firstline
  local total = lastline - firstline + 1
  local cntr = 1
  while cntr <= total do
    Tableizeline(lnum, delim)
    pcall(vim.cmd.undojoin)
    if vim.g.table_mode_tableize_auto_border ~= 0 then
      if cntr == 1 then
        vim.cmd('normal! O')
        tbl.AddBorder('.')
        vim.cmd('normal! j')
        lnum = lnum + 1
      end
      vim.cmd('normal! o')
      tbl.AddBorder('.')
      lnum = lnum + 1
    end
    cntr = cntr + 1
    lnum = lnum + 1
  end

  tbl.Realign(lnum - 1)
end

function M.TableizeByDelimiter()
  local ok, delim = pcall(fn.input, '/')
  if not ok then
    return
  end
  if delim:find('\27', 1, true) or delim:find('\3', 1, true) then
    return
  end
  local vm = fn.visualmode()
  if vm:lower() == 'line' or vm:lower() == 'v' then
    local firstline, lastline = fn.line("'<"), fn.line("'>")
    api.nvim_win_set_cursor(0, { firstline, 0 })
    M.TableizeRange('/' .. delim, firstline, lastline)
  end
end

if fn.hlexists('yesCell') == 0 then vim.cmd('hi yesCell cterm=bold ctermfg=10 ctermbg=2') end
if fn.hlexists('noCell') == 0 then vim.cmd('hi noCell cterm=bold ctermfg=9 ctermbg=1') end
if fn.hlexists('maybeCell') == 0 then vim.cmd('hi maybeCell cterm=bold ctermfg=11 ctermbg=3') end

-- Setup {{{1
-- Every option of vim-table-mode is a g:table_mode_* variable; setup() takes
-- them without the prefix, e.g. setup({ corner = '|', map_prefix = '<Leader>T' }).
function M.setup(opts)
  require('table-mode.config').setup(opts)
end

return M

-- Port of autoload/tablemode/spreadsheet.vim
local fn = vim.fn
local utils = require('table-mode.utils')
local tbl = require('table-mode.table')

local M = {}

-- Private Functions {{{1
-- Cell values are strings, ranges spanning several columns are lists of
-- lists. Each helper returns the value and whether Vimscript would have
-- produced a Float, so formulas evaluate exactly as in vim-table-mode.
local function empty(item)
  if type(item) == 'table' then
    return #item == 0
  elseif type(item) == 'number' then
    return item == 0
  end
  return item == nil or item == ''
end

local function TotalCells(list)
  local result = 0
  for _, item in ipairs(list) do
    if type(item) == 'table' then
      result = result + TotalCells(item)
    else
      result = result + 1
    end
  end
  return result
end

local function Extremum(list, better)
  local found = false
  local result, is_float = 0, false
  for _, item in ipairs(list) do
    if not empty(item) then
      local val, vfloat
      if type(item) == 'number' then
        val, vfloat = item, false
      elseif type(item) == 'string' then
        val, vfloat = fn.str2float(item), true
      else
        val, vfloat = Extremum(item, better)
      end
      if not found or better(val, result) then
        found = true
        result, is_float = val, vfloat
      end
    end
  end
  return result, is_float
end

local function Min(list)
  return Extremum(list, function(a, b) return a < b end)
end

local function Max(list)
  return Extremum(list, function(a, b) return a > b end)
end

local function CountE(list)
  local result = 0
  for _, item in ipairs(list) do
    if empty(item) then
      result = result + 1
    elseif type(item) == 'table' then
      result = result + CountE(item)
    end
  end
  return result
end

local function CountNE(list)
  local result = 0
  for _, item in ipairs(list) do
    if type(item) == 'table' then
      result = result + CountNE(item)
    elseif not empty(item) then
      result = result + 1
    end
  end
  return result
end

-- Vimscript integer division
local function idiv(a, b)
  if b == 0 then
    return a == 0 and -0x7fffffffffffffff or (a > 0 and 0x7fffffffffffffff or -0x7fffffffffffffff)
  end
  local q = a / b
  return q >= 0 and math.floor(q) or math.ceil(q)
end

local function PercentE(list)
  return idiv(CountE(list) * 100, TotalCells(list))
end

local function PercentNE(list)
  return idiv(CountNE(list) * 100, TotalCells(list))
end

local function Sum(list)
  local result = 0.0
  for _, item in ipairs(list) do
    if type(item) == 'number' then
      result = result + item
    elseif type(item) == 'string' then
      result = result + fn.str2float(item)
    elseif type(item) == 'table' then
      result = result + Sum(item)
    end
  end
  return result
end

local function Average(list)
  return Sum(list) / TotalCells(list)
end

local function AverageNE(list)
  return Sum(list) / CountNE(list)
end

-- Public Functions {{{1
function M.GetFirstRow(line)
  if tbl.IsRow(line) then
    line = utils.line(line)

    while not tbl.IsHeader(line - 1) and (tbl.IsRow(line - 1) or tbl.IsBorder(line - 1)) do
      line = line - 1
    end
    if tbl.IsBorder(line) then
      line = line + 1
    end

    return line
  end
  return 0
end

function M.GetFirstRowOrHeader(line)
  if tbl.IsRow(line) then
    line = utils.line(line)

    while tbl.IsTable(line - 1) do
      line = line - 1
    end
    if tbl.IsBorder(line) then
      line = line + 1
    end

    return line
  end
  return 0
end

function M.MoveToFirstRow()
  if tbl.IsRow('.') then
    utils.MoveToLine(M.GetFirstRow('.'))
  end
end

function M.MoveToFirstRowOrHeader()
  if tbl.IsRow('.') then
    utils.MoveToLine(M.GetFirstRowOrHeader('.'))
  end
end

function M.GetLastRow(line)
  if tbl.IsRow(line) then
    line = utils.line(line)

    while tbl.IsTable(line + 1) do
      line = line + 1
    end
    if tbl.IsBorder(line) then
      line = line - 1
    end

    return line
  end
  return 0
end

function M.MoveToLastRow()
  if tbl.IsRow('.') then
    utils.MoveToLine(M.GetLastRow('.'))
  end
end

function M.LineNr(line, row)
  if tbl.IsRow(line) then
    line = M.GetFirstRow(line)
    local row_nr = 0

    while tbl.IsTable(line + 1) do
      if tbl.IsRow(line) then
        row_nr = row_nr + 1
        if row == row_nr then
          break
        end
      end
      line = line + 1
    end

    return line
  end
  return 0
end

function M.RowNr(line)
  line = utils.line(line)

  local rowNr = 0
  while not tbl.IsHeader(line) and tbl.IsTable(line) do
    if tbl.IsRow(line) then
      rowNr = rowNr + 1
    end
    line = line - 1
  end

  return rowNr
end

function M.RowCount(line)
  line = utils.line(line)

  local tline, totalRowCount = line, 0
  while not tbl.IsHeader(tline) and tbl.IsTable(tline) do
    if tbl.IsRow(tline) then
      totalRowCount = totalRowCount + 1
    end
    tline = tline - 1
  end

  tline = line + 1
  while not tbl.IsHeader(tline) and tbl.IsTable(tline) do
    if tbl.IsRow(tline) then
      totalRowCount = totalRowCount + 1
    end
    tline = tline + 1
  end

  return totalRowCount
end

-- pos: a position string like '.', or a { line, col } list
function M.ColumnNr(pos)
  if type(pos) == 'string' then
    pos = { fn.line(pos), fn.col(pos) }
  elseif type(pos) ~= 'table' then
    return 0
  end
  local text = fn.getline(pos[1])
  local row_start = fn.stridx(text, vim.g.table_mode_separator)
  return utils.SeparatorCount(utils.slice(text, row_start, pos[2] - 2))
end

function M.ColumnCount(line)
  return utils.SeparatorCount(fn.getline(utils.line(line))) - 1
end

function M.IsFirstCell()
  return M.ColumnNr('.') == 1
end

function M.IsLastCell()
  return M.ColumnNr('.') == M.ColumnCount('.')
end

function M.MoveToStartOfCell()
  if utils.char(fn.getline('.'), fn.col('.') - 1) ~= vim.g.table_mode_separator or M.IsLastCell() then
    fn.search(vim.g.table_mode_escaped_separator_regex, 'b', fn.line('.'))
  end
  vim.cmd('normal! 2l')
end

function M.MoveToEndOfCell()
  fn.search(vim.g.table_mode_escaped_separator_regex, 'z', fn.line('.'))
  vim.cmd('normal! 2h')
end

function M.DeleteColumn()
  if tbl.IsRow('.') then
    for _ = 1, vim.v.count1 do
      M.MoveToStartOfCell()
      M.MoveToFirstRowOrHeader()
      vim.cmd([[silent! execute "normal! h\<C-V>"]])
      M.MoveToEndOfCell()
      vim.cmd('normal! 2l')
      M.MoveToLastRow()
      vim.cmd('normal! d')
    end

    tbl.Realign('.')
  end
end

function M.DeleteRow()
  if tbl.IsRow('.') then
    for _ = 1, vim.v.count1 do
      if tbl.IsRow('.') then
        vim.cmd('normal! dd')
      end

      if not tbl.IsRow('.') then
        vim.cmd('normal! k')
      end
    end

    tbl.Realign('.')
  end
end

function M.InsertColumn(after)
  if tbl.IsRow('.') then
    local quantity = vim.v.count1
    local sep = vim.g.table_mode_separator
    local fillchar = vim.g.table_mode_fillchar

    M.MoveToFirstRowOrHeader()
    M.MoveToStartOfCell()
    if after then
      M.MoveToEndOfCell()
      vim.cmd('normal! 3l')
    end
    vim.cmd([[execute "normal! h\<C-V>"]])
    M.MoveToLastRow()
    vim.cmd('normal! y')

    local corner = utils.get_buffer_or_global_option('table_mode_corner')
    local cell_line, header_line
    if after then
      cell_line = sep .. '  '
      header_line = corner .. fillchar .. fillchar
    else
      cell_line = '  ' .. sep
      header_line = fillchar .. fillchar .. corner
    end
    cell_line = fn.escape(cell_line, [[\&]])
    header_line = fn.escape(header_line, [[\&]])

    -- This transforms the character column before or after the column separator
    -- into a new column with separator.
    -- This requires, that
    --      g:table_mode_separator != g:table_mode_fillchar
    --   && g:table_mode_separator != g:table_mode_header_fillchar
    --   && g:table_mode_separator != g:table_mode_align_char
    fn.setreg('"', fn.substitute(
      fn.substitute(fn.getreg('"'), ' ', cell_line, 'g'),
      [[\V\C]] .. fn.escape(fillchar, '\\')
        .. [[\|]] .. fn.escape(vim.g.table_mode_header_fillchar, '\\')
        .. [[\|]] .. fn.escape(vim.g.table_mode_align_char, '\\'),
      header_line,
      'g'), 'b')

    if after then
      vim.cmd('normal! ' .. quantity .. 'pl')
    else
      vim.cmd('normal! ' .. quantity .. 'P')
    end

    tbl.Realign('.')
    vim.cmd.startinsert()
  end
end

-- Aggregate functions usable in formulas. Each takes a range string like
-- '1:3' or '1,1:3,2' and optionally the line and column it is relative to.
local aggregates = {
  Min = Min,
  Max = Max,
  CountE = function(l) return CountE(l), false end,
  CountNE = function(l) return CountNE(l), false end,
  PercentE = function(l) return PercentE(l), false end,
  PercentNE = function(l) return PercentNE(l), false end,
  Sum = function(l) return Sum(l), true end,
  Average = function(l) return Average(l), true end,
  AverageNE = function(l) return AverageNE(l), true end,
}

M.formula_functions = {}
for name, agg in pairs(aggregates) do
  M[name] = function(range, ...)
    return (agg(require('table-mode.spreadsheet.cell').GetCellRange(range, ...)))
  end
  -- Formulas are Vimscript expressions: keep Floats as Floats there.
  M.formula_functions[name] = function(range, ...)
    local val, is_float = agg(require('table-mode.spreadsheet.cell').GetCellRange(range, ...))
    if is_float then
      return { [vim.type_idx] = vim.types.float, [vim.val_idx] = val }
    end
    return val
  end
end

-- Sort on the cursor's column. bang: boolean, opts: string,
-- firstline/lastline: the range (defaults to the current line), curswant:
-- the column to sort on (defaults to the cursor's).
function M.Sort(bang, opts, firstline, lastline, curswant)
  local col = curswant or fn.getcurpos()[5]
  opts = opts or ''
  local bang_str = bang and '!' or ''
  firstline = firstline or fn.line('.')
  lastline = lastline or firstline
  local firstRow, lastRow
  if firstline == lastline then
    firstRow, lastRow = M.GetFirstRow('.'), M.GetLastRow('.')
  else
    firstRow, lastRow = firstline, lastline
  end
  M.MoveToStartOfCell()
  vim.cmd(':undojoin | ' .. firstRow .. ',' .. lastRow .. 'sort' .. bang_str .. ' ' .. opts .. ' ' .. [[/.*\%]] .. col .. 'v/')
end

function M.EchoCell()
  if tbl.IsRow('.') then
    vim.api.nvim_echo({ { '$' .. M.RowNr('.') .. ',' .. M.ColumnNr('.') } }, true, {})
  end
end

return M

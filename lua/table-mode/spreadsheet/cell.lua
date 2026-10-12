-- Port of autoload/tablemode/spreadsheet/cell.vim
local fn = vim.fn
local utils = require('table-mode.utils')
local tbl = require('table-mode.table')

local M = {}

local function spreadsheet()
  return require('table-mode.spreadsheet')
end

-- Split the separated part of a row into its cells.
local function RowCells(line)
  local sep = vim.g.table_mode_separator
  local text = fn.getline(line)
  return fn.split(utils.slice(text, fn.stridx(text, sep), fn.strridx(text, sep)), sep)
end

-- Private Functions {{{1
-- range: A string representing range of cells.
--        - Can be row1:row2 for values in the current columns in those rows.
--        - Can be row1,col1:row2,col2 for range between row1,col1 till
--          row2,col2.
local function ParseRange(range, default_col)
  if default_col == nil then
    default_col = spreadsheet().ColumnNr('.')
  end

  range = tostring(range)

  local parts = fn.split(range, ':')
  if #parts ~= 2 then
    utils.throw('Invalid Range')
  end
  local rcs1 = vim.tbl_map(fn.str2nr, fn.split(parts[1], ','))
  local rcs2 = vim.tbl_map(fn.str2nr, fn.split(parts[2], ','))

  local row1, col1, row2, col2
  if #rcs1 == 2 then
    row1, col1 = rcs1[1], rcs1[2]
  else
    row1, col1 = rcs1[1], default_col
  end

  if #rcs2 == 2 then
    row2, col2 = rcs2[1], rcs2[2]
  else
    row2, col2 = rcs2[1], default_col
  end

  return row1, col1, row2, col2
end

-- Public Functions {{{1
-- Get values of cells in a table:
-- GetCells(line)            - Get values of all cells in a row as a List.
-- GetCells(line, row)       - Get values of all cells in a row as a List.
-- GetCells(line, 0, col)    - Get values of all cells in a column as a List.
-- GetCells(line, row, col)  - Get the value of table cell by given row, col.
function M.GetCells(line, ...)
  local nargs = select('#', ...)
  line = utils.line(line)

  if not tbl.IsRow(line) then
    return 0
  end

  local row, colm
  if nargs < 1 then
    row, colm = line, 0
  elseif nargs < 2 then
    row, colm = utils.tonr(...), 0
  else
    local r, c = ...
    row, colm = utils.tonr(r), utils.tonr(c)
  end
  local idx = colm > 0 and colm - 1 or colm

  local first_row = spreadsheet().GetFirstRow(line)
  local last_row = spreadsheet().GetLastRow(line)
  if row == 0 then
    local values = {}
    line = first_row
    while tbl.IsTable(line) do
      if tbl.IsRow(line) then
        values[#values + 1] = utils.strip(utils.get(RowCells(line), idx, ''))
      end
      line = line + 1
    end
    return values
  end

  local row_nr = 0
  local row_diff = row > 0 and 1 or -1
  line = row > 0 and first_row or last_row
  while tbl.IsTable(line) do
    if tbl.IsRow(line) then
      row_nr = row_nr + row_diff
      if row == row_nr then
        break
      end
    end
    line = line + row_diff
  end

  if colm == 0 then
    return vim.tbl_map(utils.strip, RowCells(line))
  end
  return utils.strip(utils.get(RowCells(line), idx, ''))
end

function M.GetCell(...)
  local row, colm
  if select('#', ...) == 0 then
    row, colm = spreadsheet().RowNr('.'), spreadsheet().ColumnNr('.')
  else
    row, colm = ...
  end

  return M.GetCells('.', row, colm)
end

function M.GetRow(row, line)
  return M.GetCells(line or '.', row)
end

function M.GetRowColumn(col, line)
  local row = spreadsheet().RowNr('.')
  return M.GetCells(line or '.', row, col)
end

function M.GetColumn(col, line)
  return M.GetCells(line or '.', 0, col)
end

function M.GetColumnRow(row, line)
  local col = spreadsheet().ColumnNr('.')
  return M.GetCells(line or '.', row, col)
end

function M.GetCellRange(range, ...)
  local nargs = select('#', ...)
  local line, colm
  if nargs < 1 then
    line, colm = '.', spreadsheet().ColumnNr('.')
  elseif nargs < 2 then
    line, colm = ..., spreadsheet().ColumnNr('.')
  elseif nargs < 3 then
    line, colm = ...
  else
    utils.throw('Invalid Range')
  end

  local values = {}

  if tbl.IsRow(line) then
    local row1, col1, row2, col2 = ParseRange(range, colm)

    if row1 == row2 then
      if col1 == col2 then
        values[#values + 1] = M.GetCells(line, row1, col1)
      else
        values = utils.list_slice(M.GetRow(row1, line), col1 - 1, col2 - 1)
      end
    else
      if col1 == col2 then
        values = utils.list_slice(M.GetColumn(col1, line), row1 - 1, row2 - 1)
      else
        local tcol = col1
        while tcol <= col2 do
          values[#values + 1] = utils.list_slice(M.GetColumn(tcol, line), row1 - 1, row2 - 1)
          tcol = tcol + 1
        end
      end
    end
  end

  return values
end

-- SetCell(val)                  - Set the value of the cell under the cursor.
-- SetCell(val, row, col)        - Set the value of a cell of the table under the cursor.
-- SetCell(val, line, row, col)  - Set the value of a cell of the table at line.
function M.SetCell(val, ...)
  local nargs = select('#', ...)
  local line, row, colm
  if nargs == 0 then
    line, row, colm = '.', spreadsheet().RowNr('.'), spreadsheet().ColumnNr('.')
  elseif nargs == 2 then
    line = '.'
    row, colm = ...
  else
    line, row, colm = ...
  end
  row, colm = utils.tonr(row), utils.tonr(colm)

  -- Account for negative values to reference from relatively from the last
  if row < 0 then
    row = spreadsheet().RowCount(line) + row + 1
  end
  if colm < 0 then
    colm = spreadsheet().ColumnCount(line) + colm + 1
  end

  if tbl.IsRow(line) then
    local sep = vim.g.table_mode_separator
    line = spreadsheet().LineNr(line, row)
    local line_val = fn.getline(line)
    local cstartexpr = tbl.StartCommentExpr()
    local values = RowCells(line)
    if #values < colm then
      return
    end
    local idx = colm - 1
    if idx < 0 then
      idx = #values + idx
    end
    values[idx + 1] = tostring(val)
    local line_value = sep .. table.concat(values, sep) .. sep
    if utils.strlen(cstartexpr) > 0 and utils.ismatch(line_val, cstartexpr) then
      local sce = fn.matchstr(line_val, tbl.StartCommentExpr())
      local ece = fn.matchstr(line_val, tbl.EndCommentExpr())
      line_value = sce .. line_value .. ece
    end
    fn.setline(line, line_value)
    tbl.Realign(line)
  end
end

function M.TextObject(inner)
  local sep = vim.g.table_mode_separator
  if tbl.IsRow('.') then
    spreadsheet().MoveToStartOfCell()
    if inner then
      vim.cmd('normal! v')
      fn.search('[^' .. sep .. [[]\ze\s*]] .. sep)
    else
      vim.cmd('normal! vf' .. sep .. 'l')
    end
  end
end

function M.Motion(direction, count)
  local sep = vim.g.table_mode_separator
  local ss = spreadsheet()
  count = count or (vim.v.count + 1)
  if not tbl.IsRow('.') then
    return
  end
  for _ = 1, count do
    local line = fn.line('.')
    if direction == 'l' then
      if ss.IsLastCell() then
        if not tbl.IsRow(line + 1) and (tbl.IsBorder(line + 1) and not tbl.IsRow(line + 2)) then
          return
        end
        M.Motion('j', 1)
        vim.cmd('normal! 0')
      end

      -- If line starts with g:table_mode_separator
      if utils.char(fn.getline('.'), fn.col('.') - 1) == sep then
        vim.cmd('normal! 2l')
      else
        vim.cmd('normal! f' .. sep .. '2l')
      end
    elseif direction == 'h' then
      if ss.IsFirstCell() then
        if not tbl.IsRow(line - 1) and (tbl.IsBorder(line - 1) and not tbl.IsRow(line - 2)) then
          return
        end
        M.Motion('k', 1)
        vim.cmd('normal! $')
      end

      -- If line ends with g:table_mode_separator
      if utils.char(fn.getline('.'), fn.col('.') - 1) == sep then
        vim.cmd('normal! F' .. sep .. '2l')
      else
        vim.cmd('normal! 2F' .. sep .. '2l')
      end
    elseif direction == 'j' then
      if tbl.IsRow(line + 1) then
        vim.cmd('normal! j')
      elseif tbl.IsBorder(line + 1) and tbl.IsRow(line + 2) then
        vim.cmd('normal! 2j')
      end
    elseif direction == 'k' then
      if tbl.IsRow(line - 1) then
        vim.cmd('normal! k')
      elseif tbl.IsBorder(line - 1) and tbl.IsRow(line - 2) then
        vim.cmd('normal! 2k')
      end
    end
  end
end

return M

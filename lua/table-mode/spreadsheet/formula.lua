-- Port of autoload/tablemode/spreadsheet/formula.vim
local fn = vim.fn
local utils = require('table-mode.utils')
local tbl = require('table-mode.table')
local spreadsheet = require('table-mode.spreadsheet')
local cell = require('table-mode.spreadsheet.cell')

local M = {}

-- Private Functions {{{1
local function IsFormulaLine(line)
  return utils.ismatch(fn.getline(line), 'tmf: ')
end

local function IsHTMLComment(line)
  return not IsFormulaLine(line) and utils.ismatch(fn.getline(line), [[^\s*<!--]])
end

local function IsBlankLine(line)
  return utils.ismatch(fn.getline(line), [[^\s*$]])
end

-- Formulas are Vimscript expressions, as in vim-table-mode. Aggregate
-- functions resolve to the Lua implementations through v:lua.
local FUNCTIONS = { 'Min', 'Max', 'CountE', 'CountNE', 'PercentE', 'PercentNE', 'Sum', 'Average', 'AverageNE' }
local BRIDGE = [[v:lua.require'table-mode.spreadsheet'.formula_functions.]]

-- Evaluate a Vimscript expression to the string join() would make of it.
-- Like `silent! eval()`, an invalid expression evaluates to 0.
local function eval(expr)
  local ok, val = pcall(fn.eval, [[printf('%s', ]] .. expr .. ')')
  return ok and val or '0'
end

-- Public Functions {{{1
function M.Add(fr)
  if fr == nil then
    fr = fn.input('f=')
  end
  local row = spreadsheet.RowNr('.')
  local colm = spreadsheet.ColumnNr('.')
  local indent_str = string.rep(' ', fn.indent('.'))

  if fr == '' then
    return
  end

  fr = '$' .. row .. ',' .. colm .. '=' .. fr
  local fline = spreadsheet.GetLastRow('.') + 1
  if tbl.IsBorder(fline) then
    fline = fline + 1
  end
  if IsHTMLComment(fline) then
    fline = fline + 1
  end
  local cursor_pos = { fn.line('.'), fn.col('.') }
  if utils.ismatch(fn.getline(fline), 'tmf: ') then
    -- Comment line correctly
    local line_val = fn.getline(fline)
    local start_pos = fn.match(line_val, tbl.StartCommentExpr())
    local end_pos = fn.match(line_val, tbl.EndCommentExpr())
    if end_pos == 0 then
      end_pos = #line_val
    end
    local line_expr = fn.strpart(line_val, start_pos, end_pos)
    local sce = fn.matchstr(line_val, tbl.StartCommentExpr() .. [[\zs]])
    local ece = fn.matchstr(line_val, tbl.EndCommentExpr())
    fn.setline(fline, sce .. line_expr .. '; ' .. fr .. ece)
  else
    local cstring = vim.bo.commentstring
    local cmss, cmse = '', ''
    if #cstring > 0 then
      local cms = fn.split(cstring, '%s')
      if #cms == 2 then
        cmss, cmse = cms[1], cms[2]
      else
        cmss, cmse = cms[1] or '', ''
      end
    end
    fr = indent_str .. cmss .. ' tmf: ' .. fr .. ' ' .. cmse
    fn.append(fline - 1, fr)
    fn.cursor(cursor_pos)
  end
  M.EvaluateFormulaLine()
end

function M.EvaluateExpr(expr, line)
  line = utils.line(line)
  local parts = vim.tbl_map(utils.strip, fn.split(expr, '='))
  if #parts ~= 2 then
    utils.throw('Invalid formula: ' .. expr)
  end
  local target
  target, expr = parts[1], parts[2]
  local tcell = fn.substitute(target, [[\$]], '', '')
  local row, colm
  if utils.ismatch(tcell, ',') then
    local rc = vim.tbl_map(fn.str2nr, fn.split(tcell, ','))
    row, colm = rc[1], rc[2]
  else
    row, colm = 0, fn.str2nr(tcell)
  end

  for _, name in ipairs(FUNCTIONS) do
    if utils.ismatch(expr, name .. '(.*)') then
      expr = fn.substitute(expr, name .. [[(\([^)]*\))]],
        BRIDGE .. name .. [[("\1",]] .. line .. ',' .. colm .. ')', 'g')
    end
  end

  if utils.ismatch(expr, [[\$\-\?\d\+,\-\?\d\+]]) then
    expr = fn.substitute(expr, [[\$\(\-\?\d\+\),\(\-\?\d\+\)]], function(m)
      return cell.GetCells(line, m[2], m[3])
    end, 'g')
  end

  if utils.ismatch(tcell, ',') then
    if utils.ismatch(expr, [[\$]]) then
      expr = fn.substitute(expr, [[\$\(\d\+\)]], function(m)
        return cell.GetCells(line, row, m[2])
      end, 'g')
    end
    pcall(cell.SetCell, eval(expr), line, row, colm)
  else
    local last = fn.line('$')
    row, line = 1, spreadsheet.GetFirstRow(line)
    while not IsFormulaLine(line) and line <= last do
      if not tbl.IsBorder(line) then
        local texpr = expr
        if utils.ismatch(expr, [[\$]]) then
          local r = row
          texpr = fn.substitute(texpr, [[\$\(\d\+\)]], function(m)
            return cell.GetCells(line, r, m[2])
          end, 'g')
        end

        pcall(cell.SetCell, eval(texpr), line, row, colm)
        row = row + 1
      end
      line = line + 1
    end
  end
end

function M.EvaluateFormulaLine()
  local exprs = {}
  local cstring = vim.bo.commentstring
  local matchexpr
  if #cstring > 0 then
    local cms = fn.split(cstring, '%s')
    if #cms == 2 then
      matchexpr = [[^\s*]] .. fn.escape(cms[1], '/*') .. [[\s*tmf: \zs.*\ze]] .. fn.escape(cms[2], '/*') .. [[\s*$]]
    else
      matchexpr = [[^\s*]] .. fn.escape(cms[1] or '', '/*') .. [[\s*tmf: \zs.*$]]
    end
  else
    matchexpr = [[^\s* tmf: \zs.*$]]
  end

  local function collect(fline)
    while IsFormulaLine(fline) do
      vim.list_extend(exprs, fn.split(fn.matchstr(fn.getline(fline), matchexpr), ';'))
      fline = fline + 1
    end
  end

  local line
  if tbl.IsRow('.') then -- We're inside the table
    line = spreadsheet.GetLastRow('.')
    local fline = line + 1
    if IsHTMLComment(fline) then fline = fline + 1 end
    if tbl.IsBorder(fline) then fline = fline + 1 end
    if IsBlankLine(fline) then fline = fline + 1 end
    collect(fline)
  elseif IsBlankLine('.') then -- We're possibly in the blank line above the formula line
    local fline = fn.line('.') + 1
    line = fn.line('.') - 1
    if IsHTMLComment(fline) then fline = fline + 1 end
    if tbl.IsBorder(line) then line = line - 1 end
    collect(fline)
  elseif IsFormulaLine('.') then
    local fline = fn.line('.')
    line = fn.line('.') - 1
    while IsFormulaLine(line) do
      fline = line
      line = line - 1
    end
    if IsHTMLComment(line) then line = line - 1 end
    if IsBlankLine(line) then line = line - 1 end
    if tbl.IsBorder(line) then line = line - 1 end
    if tbl.IsRow(line) then
      collect(fline)
    end
  end

  for _, expr in ipairs(exprs) do
    local ok, err = pcall(M.EvaluateExpr, expr, line)
    if not ok then
      vim.notify(tostring(err), vim.log.levels.ERROR)
    end
  end
end

return M

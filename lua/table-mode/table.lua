-- Port of autoload/tablemode/table.vim
local fn = vim.fn
local utils = require('table-mode.utils')

local M = {}

-- Private Functions {{{1
local function blank(str)
  return utils.ismatch(str, [[^\s*$]])
end

local function opt(name)
  return utils.get_buffer_or_global_option(name)
end

local function BorderExpr()
  local corner = opt('table_mode_corner')
  local corner_corner = opt('table_mode_corner_corner')
  local header_fillchar = opt('table_mode_header_fillchar')
  return M.StartExpr()
    .. '[' .. corner .. corner_corner .. ']'
    .. '[' .. fn.escape(vim.g.table_mode_fillchar .. header_fillchar .. corner .. vim.g.table_mode_align_char, '-') .. ']\\+'
    .. '[' .. corner .. corner_corner .. ']'
    .. M.EndExpr()
end

local function DefaultBorder()
  if require('table-mode').IsActive() then
    local corner = opt('table_mode_corner')
    local corner_corner = opt('table_mode_corner_corner')
    local fillchar = vim.g.table_mode_fillchar
    return corner_corner .. fillchar .. corner .. fillchar .. corner_corner
  end
  return ''
end

local function GenerateHeaderBorder(line)
  line = utils.line(line)
  if not (M.IsRow(line - 1) or M.IsRow(line + 1)) then
    return DefaultBorder()
  end

  local sep = vim.g.table_mode_separator
  local align_char = vim.g.table_mode_align_char

  local line_val = ''
  if M.IsRow(line + 1) then
    line_val = fn.getline(line + 1)
  end
  if M.IsRow(line - 1) and utils.strlen(line_val) < utils.strlen(fn.getline(line - 1)) then
    line_val = fn.getline(line - 1)
  end
  if utils.strlen(line_val) <= 1 then
    return DefaultBorder()
  end

  local corner = opt('table_mode_corner')
  local corner_corner = opt('table_mode_corner_corner')
  local header_fillchar = opt('table_mode_header_fillchar')

  local tline = utils.slice(line_val, fn.stridx(line_val, sep), fn.strridx(line_val, sep))
  local fillchar = M.IsHeader(line - 1) and header_fillchar or vim.g.table_mode_fillchar

  local special_replacement = '___'
  local border = fn.substitute(tline, vim.g.table_mode_escaped_separator_regex, special_replacement, 'g')
  local seperator_match_regex = special_replacement .. [[\zs\(.\{-}\)\ze]] .. special_replacement
  border = fn.substitute(border, seperator_match_regex, function(m)
    return string.rep(fillchar, utils.StrDisplayWidth(m[1]))
  end, 'g')
  border = fn.substitute(border, special_replacement, sep, 'g')
  border = fn.substitute(border, sep, corner, 'g')
  border = fn.substitute(border, '^' .. corner .. [[\(.*\)]] .. corner .. '$', corner_corner .. [[\1]] .. corner_corner, '')

  -- Incorporate header alignment chars
  if utils.ismatch(fn.getline(line), align_char) then
    local pat = '[' .. corner_corner .. corner .. ']'
    local align = require('table-mode.align')
    local hcols = align.Split(fn.getline(line), pat)
    local gcols = align.Split(border, pat)

    for idx = 1, #hcols do
      if utils.ismatch(hcols[idx], align_char) then
        local gcol = gcols[idx] or ''
        if utils.ismatch(hcols[idx], align_char .. '[^' .. align_char .. ']\\+' .. align_char) then
          -- center align
          gcols[idx] = align_char .. utils.slice(gcol, 1, -2) .. align_char
        elseif utils.ismatch(hcols[idx], align_char .. '$') then
          gcols[idx] = utils.slice(gcol, 0, -2) .. align_char
        else
          gcols[idx] = align_char .. utils.slice(gcol, 1)
        end
      end
    end
    border = table.concat(gcols, '')
  end

  local cstartexpr = M.StartCommentExpr()
  if utils.strlen(cstartexpr) > 0 and utils.ismatch(fn.getline(line), cstartexpr) then
    local sce = fn.matchstr(line_val, M.StartCommentExpr())
    local ece = fn.matchstr(line_val, M.EndCommentExpr())
    return sce .. border .. ece
  elseif utils.ismatch(fn.getline(line), M.StartExpr()) then
    local indent = fn.matchstr(line_val, M.StartExpr())
    return indent .. border
  end
  return border
end

-- Public Functions {{{1
function M.GetCommentStart()
  local cstring = vim.bo.commentstring
  if utils.strlen(cstring) > 0 then
    local cst = fn.split(cstring, '%s')
    if #cst == 0 then
      return ''
    end
    return fn.substitute(cst[1], '[^(%)]', [[\\\0]], 'g')
  end
  return ''
end

function M.StartCommentExpr()
  local cstartexpr = M.GetCommentStart()
  if utils.strlen(cstartexpr) > 0 then
    return [[^\s*]] .. cstartexpr .. [[\s*]]
  end
  return ''
end

function M.GetCommentEnd()
  local cstring = vim.bo.commentstring
  if utils.strlen(cstring) > 0 then
    local cst = fn.split(cstring, '%s')
    if #cst == 2 then
      return fn.substitute(cst[2], '[^()]', [[\\\0]], 'g')
    end
  end
  return ''
end

function M.EndCommentExpr()
  local cendexpr = M.GetCommentEnd()
  if utils.strlen(cendexpr) > 0 then
    return [[.*\zs\s\+]] .. cendexpr .. [[\s*$]]
  end
  return ''
end

function M.StartExpr()
  local cstart = M.GetCommentStart()
  if utils.strlen(cstart) > 0 then
    return [[^\s*\(]] .. cstart .. [[\)\?\s*]]
  end
  return [[^\s*]]
end

function M.EndExpr()
  local cend = M.GetCommentEnd()
  if utils.strlen(cend) > 0 then
    return [[\s*\(\s\+]] .. cend .. [[\)\?\s*$]]
  end
  return [[\s*$]]
end

function M.IsBorder(line)
  local text = fn.getline(line)
  return not blank(text) and utils.ismatch(text, BorderExpr())
end

function M.IsHeader(line)
  line = utils.line(line)
  return M.IsRow(line)
    and not M.IsRow(line - 1)
    and not M.IsRow(line - 2)
    and not M.IsBorder(line - 2)
    and M.IsBorder(line + 1)
end

function M.IsRow(line)
  local sep = vim.g.table_mode_separator
  return not M.IsBorder(line)
    and utils.ismatch(fn.getline(line), M.StartExpr() .. sep .. '[^' .. sep .. ']\\+')
end

function M.IsTable(line)
  return M.IsRow(line) or M.IsBorder(line)
end

function M.AddBorder(line)
  fn.setline(line, GenerateHeaderBorder(line))
end

function M.Realign(line)
  local utree = fn.undotree()
  if utree.seq_cur ~= utree.seq_last then
    -- skip during undo
    return
  end

  local current_fm = vim.wo.foldmethod -- save foldmethod to be restored
  vim.opt_local.foldmethod = 'manual' -- manual foldmethod while table is being aligned

  line = utils.line(line)

  local lines = {}
  local lnum, blines = line, {}
  while M.IsTable(lnum) do
    if M.IsBorder(lnum) then
      table.insert(blines, 1, lnum)
    else
      table.insert(lines, 1, { lnum = lnum, text = fn.getline(lnum) })
    end
    lnum = lnum - 1
  end

  lnum = line + 1
  while M.IsTable(lnum) do
    if M.IsBorder(lnum) then
      blines[#blines + 1] = lnum
    else
      lines[#lines + 1] = { lnum = lnum, text = fn.getline(lnum) }
    end
    lnum = lnum + 1
  end

  lines = require('table-mode.align').Align(lines)

  for _, aline in ipairs(lines) do
    pcall(vim.cmd.undojoin)
    fn.setline(aline.lnum, aline.text)
  end

  for _, bline in ipairs(blines) do
    pcall(vim.cmd.undojoin)
    M.AddBorder(bline)
  end

  -- restore foldmethod
  vim.opt_local.foldmethod = current_fm
end

return M

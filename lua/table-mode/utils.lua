-- Port of autoload/tablemode/utils.vim, plus the Vimscript semantics
-- (string/list slicing, `=~#`, get()) the rest of the port relies on.
local fn = vim.fn

local M = {}

-- Vimscript helpers {{{1

-- `str =~# pat`: like match(), but always case sensitive.
function M.ismatch(str, pat)
  return fn.match(str, '\\C' .. pat) ~= -1
end

-- `str[a : b]` on a String: byte indexes, 0-based and inclusive, negative
-- indexes count from the end.
function M.slice(str, a, b)
  local len = #str
  a = a or 0
  if a < 0 then
    a = math.max(len + a, 0)
  end
  if b == nil then
    b = len - 1
  elseif b < 0 then
    b = len + b
  elseif b >= len then
    b = len - 1
  end
  if a >= len or b < 0 or a > b then
    return ''
  end
  return str:sub(a + 1, b + 1)
end

-- `list[a : b]` on a List: like slice(), but a start that is still negative
-- after counting from the end gives an empty list.
function M.list_slice(list, a, b)
  local len = #list
  if a < 0 then
    a = len + a
  end
  if b < 0 then
    b = len + b
  elseif b >= len then
    b = len - 1
  end
  local rv = {}
  if a < 0 or a >= len or a > b then
    return rv
  end
  for i = a + 1, b + 1 do
    rv[#rv + 1] = list[i]
  end
  return rv
end

-- `str[i]`: a single byte, or '' when out of range.
function M.char(str, i)
  if i < 0 then
    return ''
  end
  return str:sub(i + 1, i + 1)
end

-- get(list, idx, default) with a 0-based, possibly negative idx.
function M.get(list, idx, default)
  if idx < 0 then
    idx = #list + idx
  end
  local val = idx >= 0 and list[idx + 1] or nil
  if val == nil then
    return default
  end
  return val
end

-- str2nr() for values that may already be numbers.
function M.tonr(val)
  if type(val) == 'number' then
    return val
  end
  return fn.str2nr(val or '')
end

-- Public Functions {{{1
function M.throw(str)
  vim.v.errmsg = 'table-mode: ' .. str
  error(vim.v.errmsg, 0)
end

function M.line(row)
  if type(row) == 'string' then
    return fn.line(row)
  end
  return row
end

function M.strip(str)
  return fn.matchstr(str, [[^\s*\zs.\{-}\ze\s*$]])
end

-- To count multibyte characters accurately
function M.strlen(text)
  return fn.strlen(fn.substitute(text, '.', 'x', 'g'))
end

function M.StrDisplayWidth(str)
  return fn.strdisplaywidth(str)
end

function M.get_buffer_or_global_option(table_option)
  local val = vim.b[table_option]
  if val == nil then
    val = vim.g[table_option]
  end
  if val == nil then
    val = 0
  end
  return val
end

function M.MoveToLine(line)
  local offset = M.line(line) - fn.line('.')
  if offset > 0 then
    vim.cmd('normal! ' .. offset .. 'j')
  elseif offset < 0 then
    vim.cmd('normal! ' .. -offset .. 'k')
  end
end

function M.SeparatorCount(str)
  local sep = vim.g.table_mode_separator
  return M.strlen(fn.substitute(str,
    [[\V\C\(\\]] .. fn.escape(sep, '\\') .. [[\|\[^]] .. fn.escape(sep, ']^-\\') .. [[]\)]],
    '', 'g'))
end

return M

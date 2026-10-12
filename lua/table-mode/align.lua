-- Port of autoload/tablemode/align.vim (borrowed from Tabular)
local fn = vim.fn
local utils = require('table-mode.utils')

local M = {}

-- Private Functions {{{1
-- Remove all trailing spaces from a string.
local function StripTrailingSpaces(str)
  return fn.matchstr(str, [[^.\{-}\ze\s*$]])
end

local function Padding(str, length, where)
  local gap_length = length - utils.StrDisplayWidth(str)
  if utils.ismatch(where, 'l') then
    return str .. string.rep(' ', gap_length)
  elseif utils.ismatch(where, 'r') then
    return string.rep(' ', gap_length) .. str
  elseif utils.ismatch(where, 'c') then
    local right = math.floor(gap_length / 2)
    local left = right + ((right * 2 ~= gap_length) and 1 or 0)
    return string.rep(' ', left) .. str .. string.rep(' ', right)
  end
  return '0'
end

-- Public Functions {{{1
-- Split a string into fields and delimiters.
-- Like split(), but include the delimiters as elements.
-- All even numbered elements (1-based) are delimiters,
-- all odd numbered elements are non-delimiters.
function M.Split(str, delim)
  local rv = {}
  local beg = 0

  local len = #str
  local searchoff = 0

  while true do
    local mid = fn.match(str, delim, beg + searchoff, 1)
    if mid == -1 or mid == len then
      break
    end

    local matchstr = fn.matchstr(str, delim, beg + searchoff, 1)
    local length = #matchstr

    if length == 0 and beg == mid then
      -- Zero-length match for a zero-length delimiter - advance past it
      searchoff = searchoff + 1
    else
      if beg == mid then
        rv[#rv + 1] = ''
      else
        rv[#rv + 1] = utils.slice(str, beg, mid - 1)
      end

      rv[#rv + 1] = matchstr

      beg = mid + length
      searchoff = 0
    end
  end

  rv[#rv + 1] = str:sub(beg + 1)

  return rv
end

function M.alignments(lnum, ncols)
  local tbl = require('table-mode.table')
  local achr = vim.g.table_mode_align_char
  local alignments = {}
  if tbl.IsBorder(lnum + 1) then
    local corner = utils.get_buffer_or_global_option('table_mode_corner')
    local corner_corner = utils.get_buffer_or_global_option('table_mode_corner_corner')
    local hcols = M.Split(fn.getline(lnum + 1), '[' .. corner .. corner_corner .. ']')
    for idx = 1, #hcols do
      alignments[idx] = 'l'
      if utils.ismatch(hcols[idx], achr .. '[^' .. achr .. ']\\+' .. achr) then
        alignments[idx] = 'c'
      elseif utils.ismatch(hcols[idx], achr .. '$') then
        alignments[idx] = 'r'
      end
    end
  end
  return alignments
end

function M.Align(lines)
  if #lines == 0 then
    return {}
  end
  local tbl = require('table-mode.table')
  for _, line in ipairs(lines) do
    line.text = M.Split(line.text, vim.g.table_mode_escaped_separator_regex)
  end

  for _, line in ipairs(lines) do
    local stext = line.text
    if #stext > 1 then
      if fn.match(stext[1], tbl.StartExpr()) == -1 then
        stext[1] = StripTrailingSpaces(stext[1])
      end
      for i = 2, #stext do
        stext[i] = utils.strip(stext[i])
      end
    end
  end

  local maxes = {}
  for _, line in ipairs(lines) do
    local stext = line.text
    if #stext > 1 then
      for i = 1, #stext do
        local width = utils.StrDisplayWidth(stext[i])
        if i > #maxes then
          maxes[#maxes + 1] = width
        else
          maxes[i] = math.max(maxes[i], width)
        end
      end
    end
  end

  local alignments
  if utils.get_buffer_or_global_option('table_mode_ignore_align') == 1 then
    alignments = {}
  else
    alignments = M.alignments(lines[1].lnum, #lines[1].text)
  end

  for _, line in ipairs(lines) do
    local tline = line.text
    if #tline > 1 then
      for jdx = 1, #tline do
        -- Dealing with the header being the first line
        if jdx > #alignments then
          alignments[#alignments + 1] = 'l'
        end
        local field = Padding(tline[jdx], maxes[jdx], alignments[jdx])
        tline[jdx] = field .. (jdx == 1 and '' or ' ')
      end
      line.text = StripTrailingSpaces(table.concat(tline, ''))
    else
      line.text = table.concat(tline, '')
    end
  end

  return lines
end

return M

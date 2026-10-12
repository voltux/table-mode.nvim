-- Differential test: drives table-mode only through its user interface
-- (commands and mappings) and dumps buffer, cursor and mode after each
-- scenario, so the output of vim-table-mode and table-mode.nvim can be
-- diffed. See tests/compare.sh.
--
--   nvim --headless --clean --cmd 'set rtp^=<plugin>' -c 'luafile tests/scenarios.lua' -- <fixtures> <out>
local fixtures = _G.arg and _G.arg[1] or vim.v.argv[#vim.v.argv - 1]
local out = vim.v.argv[#vim.v.argv]

local results = {}

local function keys(str)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(str, true, false, true), 'xt', false)
end

local function fixture(name)
  return vim.fn.readfile(fixtures .. '/' .. name)
end

local function scenario(name, lines, setup, run)
  vim.cmd('enew!')
  vim.cmd('setlocal buftype=nofile noswapfile')
  vim.bo.commentstring = ''
  if setup then setup() end
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.cmd('messages clear')
  local ok, err = pcall(run)
  local res = {
    name = name,
    ok = ok,
    lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
    cursor = vim.api.nvim_win_get_cursor(0),
    mode = vim.api.nvim_get_mode().mode,
    messages = vim.fn.execute('messages'),
  }
  if not ok then res.err = tostring(err) end
  results[#results + 1] = res
  if vim.api.nvim_get_mode().mode ~= 'n' then keys('<Esc>') end
  pcall(vim.cmd, 'TableModeDisable')
  vim.g.table_mode_tableize_auto_border = 0
  vim.g.table_mode_ignore_align = 0
end

local function cur(l, c) vim.api.nvim_win_set_cursor(0, { l, c }) end

local sample = fixture('sample.txt')
local big = fixture('big_sample.txt')

-- Tableize {{{1
scenario('tableize', fixture('tableize.txt'), nil, function() vim.cmd('%Tableize') end)
scenario('tableize auto border', fixture('tableize.txt'), function() vim.g.table_mode_tableize_auto_border = 1 end,
  function() vim.cmd('%Tableize') end)
scenario('tableize delimiter', { 'a;b;c', 'dd;ee;ff', 'x;"y;z";w' }, nil, function() vim.cmd('%Tableize/;') end)
scenario('tableize quoted comma', { 'a,"b,c",d', "e,'f,g',h" }, nil, function() vim.cmd('%Tableize') end)
scenario('tableize map', { 'a,b', 'c,d', 'e,f' }, nil, function() keys('2\\tt') end)
scenario('tableize visual', { 'a,b', 'c,d', 'e,f' }, nil, function() keys('Vj\\tt') end)
scenario('tableize by delimiter', { 'a:b', 'c:d', 'e:f' }, nil, function() keys('Vjj\\T:<CR>') end)
scenario('tableize commented', { '# a,b', '# cc,dd' }, function() vim.bo.commentstring = '# %s' end,
  function() vim.cmd('%Tableize') end)
scenario('tableize html commented', { '<!-- a,b -->', '<!-- cc,dd -->' }, function() vim.bo.commentstring = '<!-- %s -->' end,
  function() vim.cmd('%Tableize') end)

-- Realign {{{1
for _, f in ipairs({
  'table/sample_realign_before.txt', 'table/sample_realign_unicode_before.txt',
  'table/sample_header_realign_before.txt', 'table/sample_header_realign_unicode_before.txt',
  'complex_header.txt', 'escaped_seperator.txt', 'big_sample.txt', 'align/simple_before.txt',
  'align/unicode_before.txt', 'table/sample_for_header.txt', 'table/sample_for_header_unicode.txt',
}) do
  scenario('realign ' .. f, fixture(f), nil, function()
    vim.cmd('TableModeEnable')
    for l = 1, vim.fn.line('$') do
      cur(l, 0)
      vim.cmd('TableModeRealign')
    end
  end)
end
scenario('realign ignore_align', fixture('complex_header.txt'), function() vim.g.table_mode_ignore_align = 1 end,
  function() cur(3, 0); vim.cmd('TableModeRealign') end)
scenario('realign map with count', { '|a|b|', '', '|cc|d|', '|e|ffff|' }, nil, function()
  vim.cmd('TableModeEnable'); keys('3\\tr')
end)
scenario('realign commented', { '  # |a|bbbbb|', '  # |cccc|d|', '  # |-|' }, function() vim.bo.commentstring = '# %s' end,
  function() vim.cmd('TableModeEnable'); cur(1, 0); vim.cmd('TableModeRealign') end)
scenario('realign markdown', { '|a|b|', '|-|', '|cccc|d|' }, function() vim.bo.filetype = 'markdown'; vim.bo.commentstring = '' end,
  function() vim.cmd('TableModeEnable'); cur(1, 0); vim.cmd('TableModeRealign') end)
scenario('realign rst', { '+-+', '|a|b|', '|-|', '|cccc|d|', '+-+' }, function() vim.bo.filetype = 'rst'; vim.bo.commentstring = '' end,
  function() vim.cmd('TableModeEnable'); cur(2, 0); vim.cmd('TableModeRealign') end)

-- Typing {{{1
scenario('type table', {}, nil, function()
  vim.cmd('TableModeEnable')
  keys('i| Name | Age |<CR>||<CR>| Bob | 42 |<CR>| Alexandra | 7 |<Esc>')
end)
scenario('type table header alignment', {}, nil, function()
  vim.cmd('TableModeEnable')
  keys('i| Name | Age | City |<CR>|:-|-:|:-:|<CR>| Bob | 42 | Paris |<CR>| Alexandra | 7 | NY |<Esc>')
end)
scenario('type commented table', {}, function() vim.bo.commentstring = '// %s' end, function()
  vim.cmd('TableModeEnable')
  keys('i// | a | b |<CR>// ||<CR>// | ccc | ddddd |<Esc>')
end)
scenario('type rst table', {}, function() vim.bo.filetype = 'rst'; vim.bo.commentstring = '' end, function()
  vim.cmd('TableModeEnable')
  keys('i||<CR>| a | b |<CR>||<CR>| ccc | ddddd |<CR>||<Esc>')
end)
scenario('type mid cell', { '| aaaa | bb |' }, nil, function()
  vim.cmd('TableModeEnable')
  cur(1, 4); keys('aX|<Esc>')
end)

-- Motions {{{1
local function motion_trace(seq)
  return function()
    vim.cmd('TableModeEnable')
    cur(3, 2)
    local trace = {}
    for _, k in ipairs(seq) do
      keys(k)
      trace[#trace + 1] = table.concat(vim.api.nvim_win_get_cursor(0), ':')
    end
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { table.concat(trace, ' ') })
  end
end
scenario('motions', big, nil, motion_trace({
  ']|', ']|', ']|', ']|', ']|', ']|', '[|', '[|', '[|', '[|', '[|', '}|', '}|', '}|', '{|', '{|', '{|',
  '2]|', '3[|', '2}|', '2{|', '5]|', '9[|',
}))
scenario('motions header', fixture('complex_header.txt'), nil, motion_trace({ '{|', '{|', '}|', '}|', '}|', '}|', '}|', ']|', '[|' }))

-- Text objects {{{1
scenario('text object di|', sample, nil, function() vim.cmd('TableModeEnable'); cur(3, 4); keys('di|') end)
scenario('text object da|', sample, nil, function() vim.cmd('TableModeEnable'); cur(3, 4); keys('da|') end)
scenario('text object ci|', sample, nil, function() vim.cmd('TableModeEnable'); cur(3, 10); keys('ci|new<Esc>') end)
scenario('text object vi|', sample, nil, function() vim.cmd('TableModeEnable'); cur(4, 12); keys('vi|y'); vim.fn.append(0, vim.fn.getreg('"')) end)
scenario('text object va|', sample, nil, function() vim.cmd('TableModeEnable'); cur(4, 12); keys('va|y'); vim.fn.append(0, vim.fn.getreg('"')) end)

-- Row / column manipulation {{{1
scenario('delete row', sample, nil, function() vim.cmd('TableModeEnable'); cur(3, 3); keys('\\tdd') end)
scenario('delete 2 rows', big, nil, function() vim.cmd('TableModeEnable'); cur(3, 3); keys('2\\tdd') end)
scenario('delete column', sample, nil, function() vim.cmd('TableModeEnable'); cur(3, 3); keys('\\tdc') end)
scenario('delete column header', fixture('complex_header.txt'), nil, function() vim.cmd('TableModeEnable'); cur(5, 15); keys('\\tdc') end)
scenario('delete 2 columns', big, nil, function() vim.cmd('TableModeEnable'); cur(3, 3); keys('2\\tdc') end)
scenario('insert column before', sample, nil, function() vim.cmd('TableModeEnable'); cur(3, 3); keys('\\tiCx<Esc>') end)
scenario('insert column after', sample, nil, function() vim.cmd('TableModeEnable'); cur(3, 3); keys('$\\ticx<Esc>') end)
scenario('insert 2 columns header', fixture('complex_header.txt'), nil, function() vim.cmd('TableModeEnable'); cur(5, 15); keys('2\\ticx<Esc>') end)
scenario('insert column unicode', fixture('table/sample_realign_unicode_after.txt'), nil, function()
  vim.cmd('TableModeEnable'); cur(2, 3); keys('\\tiCx<Esc>')
end)

-- Echo / sort {{{1
scenario('echo cell', big, nil, function()
  vim.cmd('TableModeEnable')
  for _, p in ipairs({ { 3, 3 }, { 4, 12 }, { 6, 20 }, { 1, 0 } }) do cur(p[1], p[2]); keys('\\t?') end
end)
scenario('sort map', big, nil, function() vim.cmd('TableModeEnable'); cur(3, 12); keys('\\ts') end)
scenario('sort map count', big, nil, function() vim.cmd('TableModeEnable'); cur(4, 12); keys('3\\ts') end)
scenario('sort command', big, nil, function() cur(4, 12); vim.cmd('TableSort') end)
scenario('sort command bang', big, nil, function() cur(4, 3); vim.cmd('TableSort!') end)
scenario('sort command range opts', big, nil, function() cur(3, 12); vim.cmd('3,6TableSort n') end)

-- Formulas {{{1
scenario('formula add', fixture('formula/sample.txt'), nil, function()
  vim.cmd('TableModeEnable')
  cur(7, 15); keys('\\tfaSum(1:3)<CR>')
  cur(8, 15); keys('\\tfaSum(1:-1)<CR>')
end)
scenario('formula add command', fixture('formula/sample.txt'), nil, function()
  cur(7, 15); keys(':TableAddFormula<CR>Average(1:3)<CR>')
end)
scenario('formula eval', fixture('formula/formula.txt'), nil, function()
  vim.cmd('TableModeEnable'); cur(3, 3); keys('\\tfe')
end)
scenario('formula eval from formula line', fixture('formula/formula.txt'), nil, function()
  cur(7, 3); vim.cmd('TableEvalFormulaLine')
end)
local formulas = {
  '| a | b | c | d |',
  '|---+---+---+---|',
  '| 1 | 2 |   |   |',
  '| 3 |   |   |   |',
  '| 5 | 6 |   |   |',
  '|   |   |   |   |',
}
local function formula_case(name, f, extra)
  local lines = vim.deepcopy(formulas)
  vim.list_extend(lines, extra or {})
  lines[#lines + 1] = ' tmf: ' .. f
  scenario('formula ' .. name, lines, nil, function() cur(3, 2); vim.cmd('TableEvalFormulaLine') end)
end
formula_case('min', '$4,1=Min(1:3)')
formula_case('max', '$4,1=Max(1:3)')
formula_case('counte', '$4,2=CountE(1:3)')
formula_case('countne', '$4,2=CountNE(1:3)')
formula_case('percente', '$4,2=PercentE(1:3)')
formula_case('percentne', '$4,2=PercentNE(1:3)')
formula_case('sum', '$4,1=Sum(1:3)')
formula_case('average', '$4,2=Average(1:3)')
formula_case('averagene', '$4,2=AverageNE(1:3)')
formula_case('cell refs', '$4,3=$1,1 * $3,2 + 1')
formula_case('negative refs', '$1,4=$-2,1 - $-4,-4')
formula_case('column', '$3=$1 + $2')
formula_case('column float', '$4=$1 * 1.5')
formula_case('range 2d', '$4,4=Sum(1,1:3,2)')
formula_case('row range', '$4,3=Sum(3,1:3,2)')
formula_case('multiple', '$4,1=Sum(1:3); $4,2=Max(1:3);$4,3=CountNE(1,1:3,2)')
formula_case('string', [[$4,4='x' . $1,1]])
formula_case('two formula lines', '$4,1=Sum(1:3)', { ' tmf: $4,2=Sum(1:3)' })
scenario('formula markdown', {
  '| a | b |',
  '|---|---|',
  '| 1 | 2 |',
  '| 3 | 4 |',
  '|   |   |',
  '<!-- tmf: $3,1=Sum(1:2) -->',
}, function() vim.bo.filetype = 'markdown' end, function() cur(3, 2); vim.cmd('TableEvalFormulaLine') end)
scenario('formula add markdown', {
  '| a | b |',
  '|---|---|',
  '| 1 | 2 |',
  '| 3 | 4 |',
  '|   |   |',
}, function() vim.bo.filetype = 'markdown' end, function()
  vim.cmd('TableModeEnable')
  cur(5, 2); keys('\\tfaSum(1:2)<CR>')
  cur(5, 6); keys('\\tfaSum(1:2)<CR>')
end)
scenario('formula add commented', {
  '# | a | b |',
  '# | 1 | 2 |',
  '# | 3 | 4 |',
  '# |   |   |',
}, function() vim.bo.commentstring = '# %s' end, function()
  vim.cmd('TableModeEnable')
  cur(4, 4); keys('\\tfa$1 + $2<CR>')
  cur(4, 8); keys('\\tfaSum(1:2)<CR>')
end)

-- State {{{1
scenario('toggle state', sample, nil, function()
  local trace = {}
  local function snap()
    local maps = {}
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, '')) do maps[#maps + 1] = m.mode .. m.lhs end
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, 'i')) do maps[#maps + 1] = m.mode .. m.lhs end
    table.sort(maps)
    trace[#trace + 1] = tostring(vim.b.table_mode_active) .. ' ut=' .. vim.o.updatetime .. ' ' .. table.concat(maps, ',')
  end
  snap()
  keys('\\tm'); snap()
  keys('\\tm'); snap()
  vim.cmd('TableModeEnable'); snap()
  vim.cmd('TableModeDisable'); snap()
  vim.api.nvim_buf_set_lines(0, -1, -1, false, trace)
end)
scenario('syntax', sample, function() vim.cmd('syntax on') end, function()
  vim.cmd('TableModeEnable')
  local trace = {}
  for _, p in ipairs({ { 1, 0 }, { 1, 1 }, { 1, 3 }, { 2, 1 }, { 2, 2 }, { 3, 0 }, { 3, 4 } }) do
    local stack = {}
    for _, id in ipairs(vim.fn.synstack(p[1], p[2] + 1)) do stack[#stack + 1] = vim.fn.synIDattr(id, 'name') end
    trace[#trace + 1] = table.concat(stack, '>')
  end
  vim.cmd('TableModeDisable')
  vim.api.nvim_buf_set_lines(0, -1, -1, false, trace)
end)

vim.fn.writefile({ vim.json.encode(results) }, out)
vim.cmd('qa!')

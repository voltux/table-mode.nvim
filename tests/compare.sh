#!/usr/bin/env bash
# Run tests/scenarios.lua against vim-table-mode and table-mode.nvim and diff
# the results. Usage: tests/compare.sh [path/to/vim-table-mode]
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
upstream=${1:-$HOME/.local/share/nvim/lazy/vim-table-mode}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

run() {
  nvim --headless --clean --cmd "set rtp^=$1" -c "luafile $here/tests/scenarios.lua" \
    -- "$here/tests/fixtures" "$2" >/dev/null 2>&1
}
run "$upstream" "$tmp/upstream.json"
run "$here" "$tmp/lua.json"

nvim --headless --clean -l /dev/stdin "$tmp/upstream.json" "$tmp/lua.json" <<'LUA'
local a = vim.json.decode(table.concat(vim.fn.readfile(_G.arg[1]), '\n'))
local b = vim.json.decode(table.concat(vim.fn.readfile(_G.arg[2]), '\n'))
local failed = 0
for i, ra in ipairs(a) do
  local rb = b[i] or {}
  local diffs = {}
  for _, k in ipairs({ 'ok', 'lines', 'cursor', 'mode', 'messages' }) do
    if not vim.deep_equal(ra[k], rb[k]) then
      diffs[#diffs + 1] = ('  %s:\n    upstream: %s\n    lua:      %s'):format(k, vim.inspect(ra[k]), vim.inspect(rb[k]))
    end
  end
  if #diffs > 0 then
    failed = failed + 1
    print('FAIL ' .. ra.name .. (rb.err and (' (' .. rb.err .. ')') or ''))
    print(table.concat(diffs, '\n'))
  end
end
print(('%d/%d scenarios identical'):format(#a - failed, #a))
os.exit(failed == 0 and 0 or 1)
LUA

# table-mode.nvim

A Lua port of [dhruvasagar/vim-table-mode](https://github.com/dhruvasagar/vim-table-mode)
(v4.8.1) for Neovim. Thank you so much for your work!

Create tables as you type, turn delimited text into
tables, move between cells, insert and delete rows and columns, sort, and
evaluate spreadsheet formulas.

```
| Item     | Cost |
|----------+------|
| Bread    | 20   |
| Tomatoes | 5    |
| Total    | 25.0 |
 tmf: $3,2=Sum(1:2)
```

It's a drop-in replacement for vim-table-mode. The `g:table_mode_*` options,
commands, default and `<Plug>` mappings, and `User TableModeEnabled` /
`TableModeDisabled` autocommands all match the original, so an existing
vim-table-mode configuration works unchanged. Install one or the other, not
both.

## Requirements

Neovim 0.8 or later. It's tested on 0.12.

## Installation

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "voltux/table-mode.nvim",
  opts = {}, -- calls require("table-mode").setup(opts), see Configuration
}
```

[vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'voltux/table-mode.nvim'
```

Native packages (`:h vim.pack`, Neovim 0.12):

```lua
vim.pack.add({ "https://github.com/voltux/table-mode.nvim" })
```

Calling `setup()` is optional. The plugin defines its commands and mappings
when it loads.

## Usage

Run `:TableModeToggle` (`<Leader>tm`) and start typing a table. Each `|` you
type realigns the row, and `||` on an empty line draws a border:

```
| Name | Age |
||
| Bob | 42 |
```

That becomes:

```
| Name | Age |
|------+-----|
| Bob  | 42  |
```

Put `:` on the header border to align a column right (`|-:|`) or centre it
(`|:-:|`).

| Command                                   | Default mapping               | Action                                             |
| ------------------------------------      | ---------------               | -------------------------------------------        |
| `:TableModeToggle` / `Enable` / `Disable` | `<Leader>tm`                  | Toggle table mode for the buffer                   |
| `:[range]Tableize[/{delim}]`              | `<Leader>tt`                  | Turn delimited lines (`,` by default) into a table |
|                                           | `<Leader>T` (visual)          | Tableize, asking for the delimiter                 |
| `:TableModeRealign`                       | `<Leader>tr`                  | Realign the table                                  |
| `:[range]TableSort[!] [flags]`            | `<Leader>ts`                  | Sort rows (`!` reverses; flags as `:sort`)         |
| `:TableAddFormula`                        | `<Leader>tfa`                 | Add a formula for the current cell                 |
| `:TableEvalFormulaLine`                   | `<Leader>tfe`                 | Evaluate the table's formulas                      |
|                                           | `<Leader>t?`                  | Echo the cell's `$row,col` reference               |
|                                           | `<Leader>tdd` / `<Leader>tdc` | Delete row / column (with a count)                 |
|                                           | `<Leader>tiC` / `<Leader>tic` | Insert column before / after                       |
|                                           | `[\|` `]\|` `{\|` `}\|`       | Move to the cell left / right / up / down          |
|                                           | `i\|` `a\|`                   | Cell text objects                                  |

Every mapping except the toggle and tableize ones exists only while table mode
is on. Each one also has a `<Plug>(table-mode-…)` form for remapping.

Formulas live on `tmf:` lines under the table, or inside a comment there,
following `'commentstring'`. A formula targets either a cell (`$row,col=…`) or
a whole column (`$col=…`). Formulas are Vimscript expressions that can use
`$row,col` or `$col` references and the functions `Sum`, `Average`,
`AverageNE`, `Min`, `Max`, `CountE`, `CountNE`, `PercentE` and `PercentNE`
over ranges like `1:3` or `1,1:3,2`. Negative numbers count from the end.

The full documentation is in `:help table-mode.nvim`.

## Configuration

Every option is a `g:table_mode_*` variable, as in vim-table-mode. You can
set them before the plugin loads:

```lua
vim.g.table_mode_corner = "|" -- markdown-style borders
```

Or pass them to `setup()` without the `table_mode_` prefix:

```lua
require("table-mode").setup({
  corner = "|",
  map_prefix = "<Leader>T",
  disable_mappings = 0,
})
```

`setup()` redefines the global commands and mappings. That lets options read
at load time, such as `map_prefix`, `toggle_map` and `always_active`, take
effect even when the plugin is already loaded. Buffer-local `b:table_mode_*`
values override the global ones; markdown and rst set some by default. To
choose a corner per filetype:

```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = "org",
  callback = function() vim.b.table_mode_corner = "+" end,
})
```

The main options are listed below. Numeric flags take `0` or `1`.

| Option                      | Default      | Meaning                                       |
| -----------------------     | ------------ | --------------------------------------------- |
| `corner`                    | `+`          | Character where borders and columns meet      |
| `corner_corner`             | `\|`         | Character at the ends of a border             |
| `separator`                 | `\|`         | Column separator                              |
| `fillchar`                  | `-`          | Border fill character                         |
| `header_fillchar`           | `-`          | Fill character of the header border           |
| `align_char`                | `:`          | Column alignment marker on the header border  |
| `delimiter`                 | `,`          | Default delimiter for `:Tableize`             |
| `map_prefix`                | `<Leader>t`  | Prefix of the default mappings                |
| `toggle_map`                | `m`          | Toggle mapping, after the prefix              |
| `disable_mappings`          | `0`          | Don't define any mappings                     |
| `disable_tableize_mappings` | `0`          | Don't define the tableize mappings            |
| `always_active`             | `0`          | Table mode on in every buffer                 |
| `auto_align`                | `1`          | Realign on `CursorHold`                       |
| `update_time`               | `500`        | `'updatetime'` while table mode is on         |
| `syntax`                    | `1`          | Highlight tables                              |
| `tableize_auto_border`      | `0`          | Add borders when tableizing                   |
| `ignore_align`              | `0`          | Ignore alignment markers                      |
| `verbose`                   | `1`          | Echo when table mode is toggled               |

## Lua API

The modules mirror the autoload files of vim-table-mode and keep their
function names:

```lua
require("table-mode").Toggle()
require("table-mode.table").Realign(".")
require("table-mode.spreadsheet").Sum("1:3")              -- tablemode#spreadsheet#Sum
require("table-mode.spreadsheet.cell").GetCell(2, 1)      -- tablemode#spreadsheet#cell#GetCell
require("table-mode.spreadsheet.formula").EvaluateFormulaLine()
```

## Differences from vim-table-mode

Behaviour, including the original's quirks, is kept identical to
vim-table-mode on purpose:

- `:TableSort` sorts on the first column, while the `<Leader>ts` mapping sorts
  on the cursor's column.
- Turning on table mode in one buffer stops automatic realigning in the other
  buffers that have it on.
- A cell whose formula fails to evaluate is set to `0`.

These are the only changes:

- Evaluating a column formula no longer hangs when no `tmf:` line follows the
  table.
- A few harmless error messages are no longer shown, for example
  `:TableModeDisable` in a buffer that never enabled table mode.

## Tests

`tests/compare.sh` checks this port against vim-table-mode. It runs the
keystroke-driven scenarios in `tests/scenarios.lua` with each plugin and
diffs the resulting buffers, cursor positions, modes and messages:

```sh
git clone https://github.com/dhruvasagar/vim-table-mode /tmp/vim-table-mode
tests/compare.sh /tmp/vim-table-mode
```

The fixtures in `tests/fixtures` come from vim-table-mode.

## Credits

All design and behaviour are from [vim-table-mode](https://github.com/dhruvasagar/vim-table-mode)
by Dhruva Sagar. Both projects use the MIT license; see [LICENSE](LICENSE).

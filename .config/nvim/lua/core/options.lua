vim.wo.number = true -- Make line numbers default (default: false)
vim.o.relativenumber = true -- Set relative numbered lines (default: false)
vim.o.clipboard = 'unnamedplus' -- Sync clipboard between OS and Neovim. (default: '')
vim.o.wrap = false -- Display lines as one long line (default: true)
vim.o.linebreak = true -- Companion to wrap, don't split words (default: false)
vim.o.breakindent = true -- Enable break indent (default: false)
vim.o.mouse = 'a' -- Enable mouse mode (default: '')
vim.o.autoindent = true -- Copy indent from current line when starting new one (default: true)
vim.o.ignorecase = true -- Case-insensitive searching UNLESS \C or capital in search (default: false)
vim.o.smartcase = true -- Smart case (default: false)
vim.o.shiftwidth = 4 -- The number of spaces inserted for each indentation (default: 8)
vim.o.tabstop = 4 -- Insert n spaces for a tab (default: 8)
vim.o.softtabstop = 4 -- Number of spaces that a tab counts for while performing editing operations (default: 0)
vim.o.expandtab = true -- Convert tabs to spaces (default: false)
vim.o.scrolloff = 4 -- Minimal number of screen lines to keep above and below the cursor (default: 0)
vim.o.sidescrolloff = 8 -- Minimal number of screen columns either side of cursor if wrap is `false` (default: 0)
vim.o.cursorline = true -- Highlight the current line (default: false)
vim.o.cursorlineopt = 'both' -- Highlight both the current line number and line
vim.o.splitbelow = true -- Force all horizontal splits to go below current window (default: false)
vim.o.splitright = true -- Force all vertical splits to go to the right of current window (default: false)
vim.o.hlsearch = false -- Set highlight on search (default: true)
vim.o.showmode = false -- We don't need to see things like -- INSERT -- anymore (default: true)
vim.opt.termguicolors = true -- Set termguicolors to enable highlight groups (default: false)
vim.o.whichwrap = 'bs<>[]hl' -- Which "horizontal" keys are allowed to travel to prev/next line (default: 'b,s')
vim.o.numberwidth = 4 -- Set number column width to 2 {default 4} (default: 4)
vim.o.swapfile = false -- Creates a swapfile (default: true)
vim.o.smartindent = true -- Make indenting smarter again (default: false)
vim.o.showtabline = 2 -- Always show tabs (default: 1)
vim.o.backspace = 'indent,eol,start' -- Allow backspace on (default: 'indent,eol,start')
vim.o.pumheight = 10 -- Pop up menu height (default: 0)
vim.o.conceallevel = 0 -- So that `` is visible in markdown files (default: 1)
vim.opt.signcolumn = 'yes' -- Keep signcolumn on by default (default: 'auto')
vim.o.fileencoding = 'utf-8' -- The encoding written to a file (default: 'utf-8')
vim.o.cmdheight = 0 -- No command line area, statusline sticks to the bottom
vim.o.updatetime = 250 -- Decrease update time (default: 4000)
vim.o.timeoutlen = 300 -- Time to wait for a mapped sequence to complete (in milliseconds) (default: 1000)
vim.o.backup = false -- Creates a backup file (default: false)
vim.o.writebackup = false -- If a file is being edited by another program (or was written to file while editing with another program), it is not allowed to be edited (default: true)
vim.o.autoread = true -- Reload files changed outside Neovim when safe
vim.o.undofile = false -- Save undo history (default: false)
vim.o.completeopt = 'menuone,noselect' -- Set completeopt to have a better completion experience (default: 'menu,preview')
vim.opt.shortmess:append 'c' -- Don't give |ins-completion-menu| messages (default: does not include 'c')
vim.opt.formatoptions:remove { 'c', 'r', 'o' } -- Don't insert the current comment leader automatically for auto-wrapping comments using 'textwidth', hitting <Enter> in insert mode, or hitting 'o' or 'O' in normal mode. (default: 'croql')
vim.opt.runtimepath:remove '/usr/share/vim/vimfiles' -- Separate Vim plugins from Neovim in case Vim still in use (default: includes this path if Vim is installed)

-- Treesitter-based folding (set per-buffer so Treesitter is attached first)
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldenable = true
vim.o.foldopen = 'block,hor,jump,mark,percent,quickfix,search,tag,undo'
vim.opt.fillchars:append { fold = ' ' }

local function get_fold_summary_text(fold_start, fold_end)
  local hidden_lines = fold_end - fold_start
  local line_word = hidden_lines == 1 and 'line' or 'lines'

  return string.format('  +-- %d %s of code minimized', hidden_lines, line_word)
end

function _G.VSCodeFoldText()
  return {
    { vim.fn.getline(vim.v.foldstart), 'Normal' },
    { get_fold_summary_text(vim.v.foldstart, vim.v.foldend), 'Folded' },
    { string.rep(' ', vim.o.columns), 'Normal' },
  }
end

vim.o.foldtext = 'v:lua.VSCodeFoldText()'

local old_fold_virtual_lines_ns = vim.api.nvim_create_namespace 'vscode-fold-virtual-lines'
for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_loaded(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, old_fold_virtual_lines_ns, 0, -1)
  end
end

local smart_fold_cache = {}

local markup_fold_filetypes = {
  astro = true,
  html = true,
  markdown = true,
  svelte = true,
  vue = true,
}

local ignored_fold_node_types = {
  chunk = true,
  document = true,
  module = true,
  program = true,
  source_file = true,
  translation_unit = true,
  -- Its body starts on the same line. Keeping both ranges makes `za` select
  -- the wider try/catch fold instead of only the body under `try {`.
  try_statement = true,
}

local semantic_fold_node_types = {
  argument_list = true,
  arguments = true,
  arrow_function = true,
  array = true,
  block = true,
  call = true,
  call_expression = true,
  case_statement = true,
  catch_clause = true,
  class_body = true,
  class_declaration = true,
  class_definition = true,
  compound_statement = true,
  constructor = true,
  declaration_list = true,
  dictionary = true,
  do_statement = true,
  else_clause = true,
  enum_declaration = true,
  element = true,
  field_declaration_list = true,
  for_in_statement = true,
  for_statement = true,
  function_call = true,
  function_declaration = true,
  function_definition = true,
  function_expression = true,
  function_item = true,
  if_statement = true,
  impl_item = true,
  interface_declaration = true,
  lambda = true,
  lambda_expression = true,
  list = true,
  match_statement = true,
  method_declaration = true,
  method_definition = true,
  object = true,
  object_type = true,
  parenthesized_expression = true,
  repeat_statement = true,
  return_statement = true,
  set = true,
  script_element = true,
  statement_block = true,
  struct_declaration = true,
  style_element = true,
  switch_statement = true,
  table_constructor = true,
  template_element = true,
  trait_item = true,
  tuple = true,
  while_statement = true,
  jsx_element = true,
  jsx_fragment = true,
  jsx_self_closing_element = true,
}

local function is_semantic_fold_node(node_type)
  if ignored_fold_node_types[node_type] then
    return false
  end

  if semantic_fold_node_types[node_type] then
    return true
  end

  return node_type:match('block$') ~= nil
    or node_type:match('body$') ~= nil
    or node_type:match('function') ~= nil
    or node_type:match('method') ~= nil
    or node_type:match('class') ~= nil
    or node_type:match('interface') ~= nil
end

local function fold_has_nonblank_content(bufnr, start_line, end_line)
  -- The start line is the fold heading. Check only the lines it would hide.
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
  for _, line in ipairs(lines) do
    if line:match('%S') then
      return true
    end
  end

  return false
end

local function collect_semantic_fold_ranges(node, ranges, seen, line_count, line_offset, source)
  line_offset = line_offset or 0
  local node_type = node:type()
  local start_row, _, end_row, end_col = node:range()
  local start_line = start_row + line_offset + 1
  -- Tree-sitter ranges are end-exclusive. An end at column 0 belongs to the
  -- previous line, otherwise folding also consumes the following sibling.
  local end_line = end_row + line_offset + (end_col == 0 and 0 or 1)

  -- Keep a standalone closing-delimiter line visible below the folded text.
  -- Besides being easier to scan, this prevents boundaries such as
  -- `} catch (...) {` from merging two adjacent folds.
  if end_col > 0 and end_line > start_line then
    -- Read only the final line of the node from the buffer — cheap O(1) slice
    -- instead of allocating the full node text via get_node_text.
    local last_line_idx = end_row  -- 0-indexed, inclusive
    local bufnr_for_line = type(source) == 'number' and source or 0
    local ok_line, last_lines = pcall(vim.api.nvim_buf_get_lines, bufnr_for_line, last_line_idx, last_line_idx + 1, false)
    local final_node_line = (ok_line and last_lines and last_lines[1]) or ''
    local standalone_delimiter = final_node_line:match('^%s*[%]%)%}>;<,]+%s*$')
      or final_node_line:match('^%s*</[%w_.:-]+>%s*$')
      or final_node_line:match('^%s*</>%s*$')

    if standalone_delimiter then
      end_line = end_line - 1
    end
  end

  end_line = math.min(end_line, line_count)

  if end_line > start_line and is_semantic_fold_node(node_type) then
    local bufnr_for_content = type(source) == 'number' and source or 0
    if fold_has_nonblank_content(bufnr_for_content, start_line, end_line) then
      local key = start_line .. ':' .. end_line
      if not seen[key] then
        seen[key] = true
        table.insert(ranges, { start_line = start_line, end_line = end_line, source = 'semantic' })
      end
    end
  end

  for child in node:iter_children() do
    collect_semantic_fold_ranges(child, ranges, seen, line_count, line_offset, source)
  end
end

local function line_for_offset(line_starts, offset)
  local low = 1
  local high = #line_starts

  while low <= high do
    local mid = math.floor((low + high) / 2)
    local next_start = line_starts[mid + 1] or math.huge

    if offset < line_starts[mid] then
      high = mid - 1
    elseif offset >= next_start then
      low = mid + 1
    else
      return mid
    end
  end

  return #line_starts
end

local function add_fold_range(ranges, seen, start_line, end_line, source)
  if end_line <= start_line then
    return
  end

  local key = start_line .. ':' .. end_line
  if seen[key] then
    if source then
      for _, range in ipairs(ranges) do
        if range.start_line == start_line and range.end_line == end_line then
          range.source = source == 'markup' and 'markup' or range.source or source
          break
        end
      end
    end
    return
  end

  seen[key] = true
  table.insert(ranges, { start_line = start_line, end_line = end_line, source = source })
end

local function collect_markup_tag_fold_ranges(bufnr, ranges, seen, line_count)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, '\n')
  local line_starts = {}
  local offset = 1

  for _, line in ipairs(lines) do
    table.insert(line_starts, offset)
    offset = offset + #line + 1
  end

  local stack = {}
  local pos = 1

  while pos <= #text do
    local start_pos, end_pos, tag = text:find('<(.-)>', pos)
    if not start_pos then
      break
    end

    local start_line = line_for_offset(line_starts, start_pos)
    local end_line = math.min(line_for_offset(line_starts, end_pos), line_count)
    local prefix = lines[start_line]:sub(1, start_pos - line_starts[start_line])
    local trimmed = tag:match('^%s*(.-)%s*$') or ''
    local is_special = trimmed:match('^[!?]') ~= nil
    local is_closing = trimmed:match('^/') ~= nil
    local is_self_closing = trimmed:match('/%s*$') ~= nil
    local name = nil

    if trimmed == '' then
      name = ''
    elseif is_closing then
      name = trimmed:match('^/%s*([%w_.:-]+)') or ''
    elseif not is_special then
      name = trimmed:match('^([%w_.:-]+)')
    end

    if name then
      if is_closing then
        for i = #stack, 1, -1 do
          if stack[i].name == name and (prefix:match('^%s*$') or stack[i].line == start_line) then
            local open = table.remove(stack, i)
            add_fold_range(ranges, seen, open.line, end_line, 'markup')
            break
          end
        end
      elseif is_self_closing and prefix:match('^%s*$') then
        add_fold_range(ranges, seen, start_line, end_line, 'markup')
      elseif prefix:match('^%s*$') then
        table.insert(stack, { name = name, line = start_line })
      end
    end

    pos = end_pos + 1
  end
end

local function build_fold_data(line_count, ranges)
  local normalized_ranges = {}
  local starts = {}
  local ends = {}
  local deltas = {}

  for _, range in ipairs(ranges) do
    local start_line = math.max(1, math.min(range.start_line, line_count))
    local end_line = math.max(start_line, math.min(range.end_line, line_count))

    if end_line > start_line then
      table.insert(normalized_ranges, { start_line = start_line, end_line = end_line, source = range.source })
      starts[start_line] = true
      ends[end_line] = (ends[end_line] or 0) + 1
      deltas[start_line] = (deltas[start_line] or 0) + 1
      deltas[end_line + 1] = (deltas[end_line + 1] or 0) - 1
    end
  end

  local levels = {}
  local exprs = {}
  local active_level = 0

  for line = 1, line_count do
    active_level = active_level + (deltas[line] or 0)
    levels[line] = active_level

    if starts[line] then
      exprs[line] = '>' .. active_level
    elseif ends[line] then
      -- Multiple nested ranges can end together, such as a JSX element and
      -- its parenthesized expression. Close from the outermost ending level.
      exprs[line] = '<' .. (active_level - ends[line] + 1)
    else
      exprs[line] = active_level
    end
  end

  return {
    exprs = exprs,
    levels = levels,
    ranges = normalized_ranges,
    start_lines = starts,
  }
end

local function get_vue_script_parser_lang(script_text)
  local lang = script_text:match('<script[^>]-lang%s*=%s*["\']?([%w_-]+)')
  lang = lang and lang:lower() or nil

  if lang == 'ts' or lang == 'typescript' then
    return 'typescript'
  end

  if lang == 'tsx' then
    return 'tsx'
  end

  if lang == 'jsx' then
    return 'jsx'
  end

  return 'javascript'
end

local function collect_vue_embedded_script_fold_ranges(node, bufnr, ranges, seen, line_count)
  if node:type() == 'script_element' then
    local raw_text_node = nil

    for child in node:iter_children() do
      if child:type() == 'raw_text' then
        raw_text_node = child
        break
      end
    end

    if raw_text_node then
      local script_text = vim.treesitter.get_node_text(node, bufnr)
      local raw_text = vim.treesitter.get_node_text(raw_text_node, bufnr)
      local parser_lang = get_vue_script_parser_lang(script_text)
      local ok, parser = pcall(vim.treesitter.get_string_parser, raw_text, parser_lang)

      if ok and parser then
        local parse_ok, trees = pcall(parser.parse, parser)
        if parse_ok and trees and trees[1] then
          local raw_start_row = raw_text_node:range()
          collect_semantic_fold_ranges(trees[1]:root(), ranges, seen, line_count, raw_start_row, raw_text)
        end
      end
    end
  end

  for child in node:iter_children() do
    collect_vue_embedded_script_fold_ranges(child, bufnr, ranges, seen, line_count)
  end
end

local function recompute_smart_fold_data(bufnr)
  local changedtick = vim.b[bufnr].changedtick
  local filetype = vim.bo[bufnr].filetype
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local empty_data = build_fold_data(line_count, {})

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    smart_fold_cache[bufnr] = { changedtick = changedtick, filetype = filetype, data = empty_data }
    return
  end

  local parse_ok, trees = pcall(parser.parse, parser)
  if not parse_ok or not trees or not trees[1] then
    smart_fold_cache[bufnr] = { changedtick = changedtick, filetype = filetype, data = empty_data }
    return
  end

  local ranges = {}
  local seen = {}
  local root = trees[1]:root()
  collect_semantic_fold_ranges(root, ranges, seen, line_count, nil, bufnr)

  if filetype == 'vue' then
    collect_vue_embedded_script_fold_ranges(root, bufnr, ranges, seen, line_count)
  end

  if markup_fold_filetypes[filetype] then
    collect_markup_tag_fold_ranges(bufnr, ranges, seen, line_count)
  end

  local data = build_fold_data(line_count, ranges)
  smart_fold_cache[bufnr] = { changedtick = changedtick, filetype = filetype, data = data }
end

local function get_smart_fold_data(bufnr)
  local changedtick = vim.b[bufnr].changedtick
  local cached = smart_fold_cache[bufnr]

  if cached and cached.changedtick == changedtick and cached.filetype == vim.bo[bufnr].filetype then
    return cached.data
  end

  -- Rebuild once for this buffer change.  Calling `zx` here would refresh the
  -- folds too, but it also discards the folds the user manually closed.
  recompute_smart_fold_data(bufnr)
  return smart_fold_cache[bufnr].data
end

function _G.SmartTreesitterFoldexpr(lnum)
  local data = get_smart_fold_data(vim.api.nvim_get_current_buf())
  return data.exprs[lnum] or 0
end

local function shortest_range_starting_at(data, lnum, source)
  local best = nil

  for _, range in ipairs(data.ranges) do
    if range.start_line == lnum and (not source or range.source == source) and (not best or range.end_line < best.end_line) then
      best = range
    end
  end

  return best
end

local jsx_fold_cache = {}

local function parse_jsx_folds(bufnr)
  local changedtick = vim.b[bufnr].changedtick
  local cached = jsx_fold_cache[bufnr]
  if cached and cached.changedtick == changedtick then
    return cached
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, '\n')
  local line_starts = {}
  local offset = 1

  for _, line in ipairs(lines) do
    table.insert(line_starts, offset)
    offset = offset + #line + 1
  end

  local stack = {}
  local ranges = {}
  local pos = 1

  while pos <= #text do
    local start_pos, end_pos, tag = text:find('<(.-)>', pos)
    if not start_pos then
      break
    end

    local start_line = line_for_offset(line_starts, start_pos)
    local end_line = line_for_offset(line_starts, end_pos)
    local trimmed = tag:match('^%s*(.-)%s*$') or ''
    local is_special = trimmed:match('^[!?]') ~= nil
    local is_closing = trimmed:match('^/') ~= nil
    local is_self_closing = trimmed:match('/%s*$') ~= nil
    local name = nil

    if trimmed == '' then
      name = ''
    elseif is_closing then
      name = trimmed:match('^/%s*([%w_.:-]+)') or ''
    elseif not is_special then
      name = trimmed:match('^([%w_.:-]+)')
    end

    if name then
      if is_closing then
        for i = #stack, 1, -1 do
          if stack[i].name == name then
            local open = table.remove(stack, i)
            local fold_end_line = end_line
            local closing_line = lines[end_line] or ''

            if closing_line:match('^%s*</[%w_.:-]+>%s*$') or closing_line:match('^%s*</>%s*$') then
              fold_end_line = fold_end_line - 1
            end

            if open.line < fold_end_line then
              table.insert(ranges, { start_line = open.line, end_line = fold_end_line })
            end
            break
          end
        end
      elseif is_self_closing then
        if start_line < end_line then
          table.insert(ranges, { start_line = start_line, end_line = end_line })
        end
      else
        table.insert(stack, { name = name, line = start_line })
      end
    end

    pos = end_pos + 1
  end

  local data = build_fold_data(#lines, ranges)

  cached = {
    changedtick = changedtick,
    data = data,
  }
  jsx_fold_cache[bufnr] = cached
  return cached
end

function _G.ReactJsxFoldexpr(lnum)
  local bufnr = vim.api.nvim_get_current_buf()
  local jsx_data = parse_jsx_folds(bufnr).data
  local smart_data = get_smart_fold_data(bufnr)
  local jsx_level = jsx_data.levels[lnum] or 0
  local smart_level = smart_data.levels[lnum] or 0

  if jsx_data.start_lines[lnum] or smart_data.start_lines[lnum] then
    return '>' .. math.max(jsx_level, smart_level)
  end

  local jsx_expr = jsx_data.exprs[lnum]
  local smart_expr = smart_data.exprs[lnum]
  local jsx_ends = type(jsx_expr) == 'string' and jsx_expr:sub(1, 1) == '<'
  local smart_ends = type(smart_expr) == 'string' and smart_expr:sub(1, 1) == '<'

  if jsx_ends or smart_ends then
    local combined_level = math.max(jsx_level, smart_level)
    local ending_count = 0

    if jsx_ends then
      ending_count = math.max(ending_count, jsx_level - tonumber(jsx_expr:sub(2)) + 1)
    end
    if smart_ends then
      ending_count = math.max(ending_count, smart_level - tonumber(smart_expr:sub(2)) + 1)
    end

    return '<' .. (combined_level - ending_count + 1)
  end

  return math.max(jsx_level, smart_level)
end

function _G.SmartFoldStartsAt(lnum)
  local bufnr = vim.api.nvim_get_current_buf()
  local smart_data = get_smart_fold_data(bufnr)

  if smart_data.start_lines[lnum] then
    return true
  end

  if vim.bo[bufnr].filetype == 'javascriptreact' or vim.bo[bufnr].filetype == 'typescriptreact' then
    return parse_jsx_folds(bufnr).data.start_lines[lnum] == true
  end

  return false
end

function _G.SmartFoldRangeAtStart(lnum)
  local bufnr = vim.api.nvim_get_current_buf()
  local smart_data = get_smart_fold_data(bufnr)
  local best = shortest_range_starting_at(smart_data, lnum)

  if markup_fold_filetypes[vim.bo[bufnr].filetype] then
    best = shortest_range_starting_at(smart_data, lnum, 'markup') or best
  end

  if vim.bo[bufnr].filetype == 'javascriptreact' or vim.bo[bufnr].filetype == 'typescriptreact' then
    local jsx_range = shortest_range_starting_at(parse_jsx_folds(bufnr).data, lnum)
    if jsx_range and (not best or jsx_range.end_line < best.end_line) then
      best = jsx_range
    end
  end

  return best
end

vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile', 'FileType' }, {
  group = vim.api.nvim_create_augroup('ts-folding', { clear = true }),
  callback = function()
    if vim.bo.filetype == 'javascriptreact' or vim.bo.filetype == 'typescriptreact' then
      vim.opt_local.foldmethod = 'expr'
      vim.opt_local.foldexpr = 'v:lua.ReactJsxFoldexpr(v:lnum)'
      return
    end

    -- Only enable if Treesitter can parse this buffer
    local ok = pcall(vim.treesitter.get_parser, 0)
    if ok then
      vim.opt_local.foldmethod = 'expr'
      vim.opt_local.foldexpr = 'v:lua.SmartTreesitterFoldexpr(v:lnum)'
    else
      vim.opt_local.foldmethod = 'indent' -- fallback for unsupported filetypes
    end
  end,
})

-- Note: Telescope literal search is handled via --fixed-strings in vimgrep_arguments
-- (see telescope.lua). Do NOT set vim.o.magic = false here — it breaks Telescope's
-- internal cursor positioning when jumping to matched lines.
vim.o.title = true -- Set the terminal title (default: false)
vim.o.titlestring = '%{fnamemodify(getcwd(), ":t")}' -- Show only the folder name

-- Friendly quit commands: show clear messages instead of cryptic E37/E162
vim.api.nvim_create_user_command('Q', function(opts)
  local ok, err = pcall(vim.cmd, 'q' .. (opts.bang and '!' or ''))
  if not ok then
    if err:match 'E37' or err:match 'E162' then
      vim.notify(
        ' You have unsaved changes!\n'
          .. '  :wq  → save and quit\n'
          .. '  :q!  → discard changes and quit\n'
          .. '  :wqa → save all files and quit\n'
          .. '  :qa! → discard all and quit',
        vim.log.levels.WARN
      )
    else
      vim.notify(err, vim.log.levels.ERROR)
    end
  end
end, { bang = true, desc = 'Quit with friendly messages' })

vim.api.nvim_create_user_command('Qa', function(opts)
  local ok, err = pcall(vim.cmd, 'qa' .. (opts.bang and '!' or ''))
  if not ok then
    if err:match 'E37' or err:match 'E162' then
      vim.notify(' You have unsaved files!\n' .. '  :wqa → save all and quit\n' .. '  :qa! → discard all changes and quit', vim.log.levels.WARN)
    else
      vim.notify(err, vim.log.levels.ERROR)
    end
  end
end, { bang = true, desc = 'Quit all with friendly messages' })

vim.api.nvim_create_user_command('Wqa', function(opts)
  vim.cmd('wqa' .. (opts.bang and '!' or ''))
end, { bang = true, desc = 'Save all files and quit' })

-- Redirect :q and :qa to the friendly versions
vim.api.nvim_create_user_command('W', function(opts)
  if vim.bo.filetype == 'spectre_panel' then
    require('spectre.actions').run_replace()
  else
    vim.cmd('write' .. (opts.bang and '!' or ''))
  end
end, { bang = true, desc = 'Save file' })
vim.cmd [[cabbrev q Q]]
vim.cmd [[cabbrev qa Qa]]

-- Refresh buffers when files change outside Neovim (for example in VS Code)
-- FocusGained: fire immediately (user switches back to terminal, correct to check right away)
-- BufEnter/CursorHold: debounced — avoids a synchronous disk stat on every tab switch
local checktime_timer = nil
vim.api.nvim_create_autocmd('FocusGained', {
  group = vim.api.nvim_create_augroup('auto-reload-on-focus', { clear = true }),
  callback = function()
    if vim.fn.mode() ~= 'c' then
      vim.cmd 'checktime'
    end
  end,
})
vim.api.nvim_create_autocmd({ 'BufEnter', 'CursorHold', 'CursorHoldI', 'TermClose', 'TermLeave' }, {
  group = vim.api.nvim_create_augroup('auto-reload-debounced', { clear = true }),
  callback = function()
    if vim.fn.mode() == 'c' then
      return
    end
    if checktime_timer then
      checktime_timer:stop()
      checktime_timer:close()
      checktime_timer = nil
    end
    checktime_timer = vim.uv.new_timer()
    checktime_timer:start(50, 0, vim.schedule_wrap(function()
      if checktime_timer then
        checktime_timer:close()
        checktime_timer = nil
      end
      pcall(vim.cmd, 'checktime')
    end))
  end,
})

-- Auto-detect when buffer content matches the saved file and clear "modified" flag
-- This lets you :q without errors if you manually revert your changes
vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
  group = vim.api.nvim_create_augroup('auto-unmodify', { clear = true }),
  callback = function(ev)
    local buf = ev.buf
    -- Only check named files that are marked as modified
    local filename = vim.api.nvim_buf_get_name(buf)
    if filename == '' or not vim.bo[buf].modified then
      return
    end
    -- Skip large files to avoid blocking I/O on every keypress
    local stat = vim.uv.fs_stat(filename)
    if not stat or stat.size > 500 * 1024 then
      return
    end
    -- Read the file from disk and compare with buffer content
    local ok, disk_lines = pcall(vim.fn.readfile, filename)
    if not ok then
      return
    end
    local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    if #disk_lines ~= #buf_lines then
      return
    end
    for i = 1, #disk_lines do
      if disk_lines[i] ~= buf_lines[i] then
        return
      end
    end
    -- Content matches the saved file, clear the modified flag
    vim.bo[buf].modified = false
    -- Notify Neo-tree so the [+] indicator updates immediately
    vim.api.nvim_exec_autocmds('BufModifiedSet', { buffer = buf })
  end,
})

-- Filetype overrides for project-specific files.
vim.filetype.add(require('config.languages').filetype_detection)

local function setup_yarn_lock_buffer(bufnr)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end

  if vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':t') ~= 'yarn.lock' then
    return
  end

  vim.bo[bufnr].filetype = 'yarnlock'
  vim.bo[bufnr].syntax = 'yarnlock'

  vim.api.nvim_buf_call(bufnr, function()
    vim.opt_local.commentstring = '# %s'
    vim.opt_local.comments = ':#'
    vim.opt_local.foldmethod = 'manual'
    vim.opt_local.iskeyword:append { '@', '-', '.', '/' }

    vim.b.current_syntax = nil
    vim.cmd [[
      syntax clear
      syntax case match

      syntax match yarnLockComment /^#.*$/ contains=yarnLockTodo,@Spell
      syntax keyword yarnLockTodo contained TODO FIXME NOTE XXX

      syntax match yarnLockPackageName /@\=[A-Za-z0-9_.-][A-Za-z0-9_./-]*/ contained
      syntax match yarnLockProtocol /\<\%(npm\|patch\|portal\|workspace\|link\|file\|exec\|git\|github\|https\?\):/ contained
      syntax match yarnLockVersionRange /[@:^~*<>|=][A-Za-z0-9_.:+~*<>=|-]\+/ contained
      syntax match yarnLockChecksum /\<\%(sha1\|sha512\|[0-9a-f]\{32,}\)-[A-Za-z0-9+/=]\+\|\<\%(sha1\|sha512\)-[A-Za-z0-9+/=]\+/ contained
      syntax match yarnLockUrl /\vhttps?:\/\/[^ "'']+/ contained

      syntax region yarnLockString start=/"/ skip=/\\"/ end=/"/ contains=yarnLockProtocol,yarnLockVersionRange,yarnLockUrl,yarnLockChecksum
      syntax region yarnLockString start=/'/ skip=/\\'/ end=/'/ contains=yarnLockProtocol,yarnLockVersionRange,yarnLockUrl,yarnLockChecksum

      syntax match yarnLockKey /^\S.\{-}:\s*$/ contains=yarnLockString,yarnLockPackageName,yarnLockProtocol,yarnLockVersionRange
      syntax match yarnLockProperty /^\s\+\zs[A-Za-z][A-Za-z0-9_.-]*\ze\%(:\|\s\)/ contained
      syntax match yarnLockNumber /\v<\d+(\.\d+){0,3}>/ contained
      syntax keyword yarnLockBoolean true false contained

      syntax region yarnLockEntry start=/^\S/ end=/^\ze\S/ contains=yarnLockKey,yarnLockComment,yarnLockField,yarnLockDependency,yarnLockString,yarnLockNumber,yarnLockBoolean keepend
      syntax match yarnLockField /^\s\+[A-Za-z][A-Za-z0-9_.-]*\%(:\|\s\)/ contains=yarnLockProperty,yarnLockString,yarnLockProtocol,yarnLockVersionRange,yarnLockChecksum,yarnLockUrl,yarnLockNumber,yarnLockBoolean
      syntax match yarnLockDependency /^\s\{4,}\S.\+$/ contains=yarnLockString,yarnLockPackageName,yarnLockProtocol,yarnLockVersionRange,yarnLockChecksum,yarnLockUrl,yarnLockNumber,yarnLockBoolean

      highlight default link yarnLockComment Comment
      highlight default link yarnLockTodo Todo
      highlight default link yarnLockKey Identifier
      highlight default link yarnLockPackageName Type
      highlight default link yarnLockProtocol Special
      highlight default link yarnLockVersionRange Number
      highlight default link yarnLockChecksum Constant
      highlight default link yarnLockUrl Directory
      highlight default link yarnLockString String
      highlight default link yarnLockProperty Keyword
      highlight default link yarnLockNumber Number
      highlight default link yarnLockBoolean Boolean
      highlight default link yarnLockField Normal
      highlight default link yarnLockDependency Normal
    ]]
    vim.b.current_syntax = 'yarnlock'
  end)
end

local yarn_lock_group = vim.api.nvim_create_augroup('yarn-lock-support', { clear = true })

vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile', 'FileType', 'Syntax' }, {
  pattern = { 'yarn.lock', 'yarnlock' },
  group = yarn_lock_group,
  callback = function(event)
    setup_yarn_lock_buffer(event.buf)
  end,
})

vim.schedule(function()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    setup_yarn_lock_buffer(bufnr)
  end
end)

-- .js and .ts files are always treated as plain JavaScript/TypeScript.
-- Use .jsx / .tsx extensions for React files.

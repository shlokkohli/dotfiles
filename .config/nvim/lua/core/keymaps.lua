local opts = { noremap = true, silent = true }
-- Set leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Keep word-under-cursor searches exact even though normal `/` searches are smart case.
vim.keymap.set('n', '*', [[/\C\<<C-r><C-w>\><CR>]], opts)
vim.keymap.set('n', '#', [[?\C\<<C-r><C-w>\><CR>]], opts)

-- Insert mode: Option+B = move back 1 word, Option+W = move forward 1 word
vim.keymap.set('i', '<M-b>', '<C-o>b', opts)
vim.keymap.set('i', '<M-w>', '<C-o>w', opts)
vim.keymap.set('i', '∫', '<C-o>b', opts) -- macOS Option+B
vim.keymap.set('i', '∑', '<C-o>w', opts) -- macOS Option+W

-- Insert mode: Option+J = move down 1 line, Option+K = move up 1 line
-- vim.keymap.set('i', '<M-j>', '<C-o>j', opts)
vim.keymap.set('i', '<M-k>', '<C-o>k', opts)
vim.keymap.set('i', '∆', '<Esc>:m .+1<CR>==gi', { silent = true }) -- macOS Option+J (move line down)
vim.keymap.set('i', '˚', '<Esc>:m .-2<CR>==gi', { silent = true }) -- macOS Option+K (move line up)

-- normal mode
vim.keymap.set('n', '<A-Up>', ':m .-2<CR>==', { silent = true })
vim.keymap.set('n', '<A-Down>', ':m .+1<CR>==', { silent = true })
vim.keymap.set('n', '<A-k>', ':m .-2<CR>==', { silent = true })
vim.keymap.set('n', '<A-j>', ':m .+1<CR>==', { silent = true })
vim.keymap.set('n', '<C-k>', ':m .-2<CR>==', { silent = true })
vim.keymap.set('n', '<C-j>', ':m .+1<CR>==', { silent = true })
vim.keymap.set('n', '˚', ':m .-2<CR>==', { silent = true }) -- macOS Option+K
vim.keymap.set('n', '∆', ':m .+1<CR>==', { silent = true }) -- macOS Option+J

local function open_line_with_same_indent(direction)
  local line_number = vim.api.nvim_win_get_cursor(0)[1]
  local source_line_number = line_number
  local insert_after_line_number = line_number

  if direction == 'above' and line_number > 1 then
    source_line_number = line_number - 1
  end

  if direction == 'below' and vim.fn.foldclosed(line_number) == line_number then
    insert_after_line_number = vim.fn.foldclosedend(line_number)
  end

  local line = vim.api.nvim_buf_get_lines(0, source_line_number - 1, source_line_number, false)[1] or ''
  local indent = line:match '^%s*' or ''
  local count = vim.v.count1
  local lines = {}

  for _ = 1, count do
    table.insert(lines, indent)
  end

  local insert_at = direction == 'below' and insert_after_line_number or line_number - 1
  vim.api.nvim_buf_set_lines(0, insert_at, insert_at, true, lines)
  vim.api.nvim_win_set_cursor(0, { insert_at + 1, #indent })
  vim.cmd 'startinsert!'
end

vim.keymap.set('n', 'o', function()
  open_line_with_same_indent 'below'
end, { desc = 'Open line below with same indent', silent = true })

vim.keymap.set('n', 'O', function()
  open_line_with_same_indent 'above'
end, { desc = 'Open line above with same indent', silent = true })


vim.keymap.set('n', '<leader>n', ':enew<CR>', { noremap = true, silent = true })

vim.keymap.set('c', '<CR>', function()
  if vim.fn.getcmdtype() ~= ':' then
    return '<CR>'
  end

  local cmdline = vim.fn.getcmdline()
  local filename = cmdline:match '^%s*new%s+(.+)%s*$'

  if cmdline:match '^%s*new%s*$' then
    return '<C-u>enew<CR>'
  end

  if filename then
    return '<C-u>edit ' .. vim.fn.fnameescape(filename) .. '<CR>'
  end

  return '<CR>'
end, { expr = true, noremap = true })
-- visual mode
local function set_visual_line_marks(start_line, end_line)
  vim.fn.setpos("'<", { 0, start_line, 1, 0 })
  vim.fn.setpos("'>", { 0, end_line, 1, 0 })
end

local function move_visual_lines(direction)
  local cursor_line = vim.fn.line '.'
  local anchor_line = vim.fn.line 'v'
  local start_line = math.min(cursor_line, anchor_line)
  local end_line = math.max(cursor_line, anchor_line)
  local buffer_line_count = vim.api.nvim_buf_line_count(0)

  if direction == 'up' then
    if start_line == 1 then
      set_visual_line_marks(start_line, end_line)
      return
    end

    local previous_line = vim.api.nvim_buf_get_lines(0, start_line - 2, start_line - 1, false)
    local selected_lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    vim.api.nvim_buf_set_lines(0, start_line - 2, end_line, false, vim.list_extend(selected_lines, previous_line))
    start_line = start_line - 1
    end_line = end_line - 1
  else
    if end_line == buffer_line_count then
      set_visual_line_marks(start_line, end_line)
      return
    end

    local selected_lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    local next_line = vim.api.nvim_buf_get_lines(0, end_line, end_line + 1, false)
    vim.api.nvim_buf_set_lines(0, start_line - 1, end_line + 1, false, vim.list_extend(next_line, selected_lines))
    start_line = start_line + 1
    end_line = end_line + 1
  end

  set_visual_line_marks(start_line, end_line)
end

local function move_visual_lines_key(direction)
  move_visual_lines(direction)
  vim.cmd 'normal! gv'
end

vim.keymap.set('x', '<A-Up>', function()
  move_visual_lines_key 'up'
end, { silent = true })
vim.keymap.set('x', '<A-Down>', function()
  move_visual_lines_key 'down'
end, { silent = true })
vim.keymap.set('x', '<A-k>', function()
  move_visual_lines_key 'up'
end, { silent = true })
vim.keymap.set('x', '<A-j>', function()
  move_visual_lines_key 'down'
end, { silent = true })
vim.keymap.set('x', '<C-k>', function()
  move_visual_lines_key 'up'
end, { silent = true })
vim.keymap.set('x', '<C-j>', function()
  move_visual_lines_key 'down'
end, { silent = true })
vim.keymap.set('x', '˚', function()
  move_visual_lines_key 'up'
end, { silent = true }) -- macOS Option+K
vim.keymap.set('x', '∆', function()
  move_visual_lines_key 'down'
end, { silent = true }) -- macOS Option+J

-- insert mode
vim.keymap.set('i', '<C-h>', '<Left>', opts)
vim.keymap.set('i', '<C-j>', '<Down>', opts)
vim.keymap.set('i', '<C-k>', '<Up>', opts)
vim.keymap.set('i', '<C-l>', '<Right>', opts)
vim.keymap.set('i', '<A-Up>', '<Esc>:m .-2<CR>==gi', { silent = true })
vim.keymap.set('i', '<A-Down>', '<Esc>:m .+1<CR>==gi', { silent = true })
vim.keymap.set('i', '<A-k>', '<Esc>:m .-2<CR>==gi', { silent = true })
vim.keymap.set('i', '<A-j>', '<Esc>:m .+1<CR>==gi', { silent = true })

-- Switch to insert mode
for _, escape_sequence in ipairs({ 'jk', 'Jk', 'jK', 'JK' }) do
  vim.keymap.set('i', escape_sequence, '<Esc>', { noremap = true, silent = true })
end

-- Disable the spacebar key's default behavior in Normal and Visual modes
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })
vim.keymap.set({ 'n', 'i', 'v', 'x', 's', 'o', 'c', 't' }, '<C-z>', '<Nop>', { silent = true, desc = 'Disable suspend' })

vim.keymap.set('n', '<leader>cc', '<cmd>cclose<CR>', { desc = 'Close quickfix' })

-- Avoid opening keyword help when pressing Shift+K on a visual selection.
vim.keymap.set({ 'v', 'x', 's' }, 'K', '<Nop>', { noremap = true, silent = true })

-- normal and visual mode: d = delete (no yank)
vim.keymap.set({ 'n', 'v' }, 'd', '"_d', { noremap = true, silent = true })
vim.keymap.set({ 'n', 'v' }, 'D', '"_D', { noremap = true, silent = true })

-- visual mode: _d = cut selection to clipboard + delete
vim.keymap.set('v', '_d', '"+d', { noremap = true, silent = true })
vim.keymap.set('v', '_D', '"+D', { noremap = true, silent = true })
-- normal mode: _d is a cut-operator prefix (compose like _dd, _diw, _d$); _d alone does nothing
vim.keymap.set('n', '_d', '"+d', { noremap = true, silent = true })
vim.keymap.set('n', '_D', '"+D', { noremap = true, silent = true })

-- normal and visual mode: c = change (no yank)
vim.keymap.set({ 'n', 'v' }, 'c', '"_c', { noremap = true, silent = true })
vim.keymap.set({ 'n', 'v' }, 'C', '"_C', { noremap = true, silent = true })

-- normal and visual mode: _c = cut to clipboard + change
vim.keymap.set({ 'n', 'v' }, '_c', '"+c', { noremap = true, silent = true })
vim.keymap.set({ 'n', 'v' }, '_C', '"+C', { noremap = true, silent = true })

-- visual mode: y = yank without moving cursor
vim.keymap.set({ 'v', 'x' }, 'y', 'ygv<Esc>', { noremap = true, silent = true, desc = 'Yank without moving cursor' })

local function flash_copied_filename()
  local bufferline_groups = {
    'BufferCurrent',
    'BufferCurrentIndex',
    'BufferCurrentMod',
    'BufferCurrentSign',
    'BufferCurrentIcon',
  }
  local original_highlights = {}

  for _, group in ipairs(bufferline_groups) do
    local ok, highlight = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
    original_highlights[group] = ok and highlight or nil
    pcall(vim.api.nvim_set_hl, 0, group, { link = 'IncSearch' })
  end

  vim.cmd.redrawtabline()

  vim.defer_fn(function()
    for _, group in ipairs(bufferline_groups) do
      pcall(vim.api.nvim_set_hl, 0, group, original_highlights[group] or {})
    end

    vim.cmd.redrawtabline()
  end, 180)
end

local function flash_copied_filepath()
  vim.g.copied_filepath_flash = true
  pcall(function()
    require('lualine').refresh()
  end)

  vim.defer_fn(function()
    vim.g.copied_filepath_flash = false
    pcall(function()
      require('lualine').refresh()
    end)
  end, 180)
end

vim.keymap.set('n', '<leader>yf', function()
  local filename = vim.fn.expand '%:t'
  vim.fn.setreg('+', filename)
  flash_copied_filename()
  vim.notify('Copied file name: ' .. filename)
end, { desc = 'Copy current file name' })

vim.keymap.set('n', '<leader>yp', function()
  local path = vim.fn.expand '%:p'
  if path == '' then
    vim.notify('Current buffer has no file path', vim.log.levels.WARN)
    return
  end

  local home = vim.fn.expand '~'
  if path:sub(1, #home + 1) == home .. '/' then
    path = path:sub(#home + 2)
  end

  vim.fn.setreg('+', path)
  flash_copied_filepath()
  vim.notify('Copied file path: ' .. path)
end, { desc = 'Copy current file path' })

-- save file

-- save file without auto-formatting
vim.keymap.set('n', '<leader>sn', '<cmd>noautocmd w <CR>', opts)

-- quit file
vim.keymap.set('n', '<C-q>', '<cmd> q <CR>', opts)

-- Select all
vim.keymap.set('n', '<leader>a', 'ggVG', opts)

-- delete single character without copying into register
vim.keymap.set('n', 'x', '"_x', opts)

-- Vertical scroll and center
vim.keymap.set('n', '<C-d>', '<C-d>zz', opts)
vim.keymap.set('n', '<C-u>', '<C-u>zz', opts)

-- Find and center
vim.keymap.set('n', 'n', 'nzzzv', opts)
vim.keymap.set('n', 'N', 'Nzzzv', opts)

local function replace_in_current_file(find_text)
  vim.ui.input({ prompt = 'Replace with: ' }, function(replace_text)
    if replace_text == nil then
      return
    end

    local buffer_text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
    local parts = {}
    local count = 0
    local start_index = 1

    while true do
      local match_start, match_end = buffer_text:find(find_text, start_index, true)
      if not match_start then
        table.insert(parts, buffer_text:sub(start_index))
        break
      end

      table.insert(parts, buffer_text:sub(start_index, match_start - 1))
      table.insert(parts, replace_text)
      count = count + 1
      start_index = match_end + 1
    end

    if count == 0 then
      vim.notify('No matches found in current file', vim.log.levels.INFO)
      return
    end

    vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(table.concat(parts), '\n', { plain = true }))
    vim.notify(('Replaced %d match%s in current file'):format(count, count == 1 and '' or 'es'))
  end)
end

local function replace_visual_selection_in_current_file()
  local mode = vim.fn.mode()
  local visual_type = (mode == 's' or mode == 'S') and 'v' or mode
  local lines = vim.fn.getregion(vim.fn.getpos 'v', vim.fn.getpos '.', { type = visual_type })
  local find_text = table.concat(lines, '\n')

  if find_text == '' then
    return
  end

  local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
  vim.api.nvim_feedkeys(esc, 'n', false)

  vim.schedule(function()
    replace_in_current_file(find_text)
  end)
end

local function prompt_replace_in_current_file()
  vim.ui.input({ prompt = 'Find in current file: ' }, function(find_text)
    if not find_text or find_text == '' then
      return
    end

    replace_in_current_file(find_text)
  end)
end

vim.keymap.set('n', '<leader>R', prompt_replace_in_current_file, { desc = 'Find and replace in current file', silent = true })
vim.keymap.set({ 'x', 's' }, '<leader>R', replace_visual_selection_in_current_file, { desc = 'Replace selection in current file', silent = true })

local function is_fold_start(line)
  if _G.SmartFoldStartsAt and _G.SmartFoldStartsAt(line) then
    return true
  end

  if line <= 1 then
    return vim.fn.foldlevel(line) > 0
  end

  return vim.fn.foldlevel(line) > vim.fn.foldlevel(line - 1)
end

local function fold_at_start(command, range)
  vim.cmd(('%d%s'):format(range.start_line, command))
end

local function is_smart_fold_buffer()
  local smart_filetypes = {
    astro = true,
    html = true,
    javascriptreact = true,
    svelte = true,
    typescriptreact = true,
    vue = true,
  }

  if smart_filetypes[vim.bo.filetype] and _G.SmartFoldRangeAtStart then
    return true
  end

  if vim.wo.foldmethod ~= 'expr' then
    return false
  end

  return vim.wo.foldexpr:match 'SmartTreesitterFoldexpr' ~= nil or vim.wo.foldexpr:match 'ReactJsxFoldexpr' ~= nil
end

vim.keymap.set('n', 'za', function()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local closed_start = vim.fn.foldclosed(line)
  local smart_range = _G.SmartFoldRangeAtStart and _G.SmartFoldRangeAtStart(line) or nil
  local use_smart_fold = is_smart_fold_buffer()

  if closed_start ~= -1 and closed_start ~= line then
    return
  end

  if closed_start == line then
    if smart_range then
      fold_at_start('foldopen', smart_range)
    elseif use_smart_fold then
      return
    else
      pcall(vim.cmd, 'normal! za')
    end
  elseif smart_range then
    fold_at_start('foldclose', smart_range)
  elseif use_smart_fold then
    return
  elseif is_fold_start(line) then
    pcall(vim.cmd, 'normal! za')
  end
end, { desc = 'Toggle fold from its first line', silent = true })

vim.keymap.set('n', 'w', function()
  local count = vim.v.count1
  local line = vim.api.nvim_win_get_cursor(0)[1]

  -- `w` normally skips a fold when the cursor is already on its first line.
  -- Reveal that fold first, then keep the standard word-motion behavior.
  if vim.fn.foldclosed(line) ~= -1 then
    vim.cmd 'normal! zv'
  end

  vim.cmd(('normal! %dw'):format(count))
end, { desc = 'Move to next word, opening the current fold', silent = true })

local function go_to_line_percent(percent)
  local first_code_column = math.max(1, vim.fn.indent('.') + 1)
  local line_width = math.max(first_code_column, vim.fn.virtcol('$') - 1)
  local code_width = math.max(1, line_width - first_code_column + 1)
  local column = first_code_column + math.floor(code_width * percent)
  vim.cmd('normal! ' .. column .. '|')
end

vim.keymap.set({ 'n', 'x' }, 'gm', function()
  go_to_line_percent(0.5)
end, { desc = 'Go to middle of text line', noremap = true })

vim.keymap.set({ 'n', 'x' }, 'gq', function()
  go_to_line_percent(0.25)
end, { desc = 'Go to 25% of text line', noremap = true })

vim.keymap.set({ 'n', 'x' }, 'gqq', function()
  go_to_line_percent(0.75)
end, { desc = 'Go to 75% of text line', noremap = true })

-- Swap zero and caret (0 goes to first word, ^ goes to column 0)
vim.keymap.set({ 'n', 'v', 'o' }, '0', '^', { desc = 'Go to first non-blank character', noremap = true })
vim.keymap.set({ 'n', 'v', 'o' }, '^', '0', { desc = 'Go to absolute start of line', noremap = true })

local last_dollar_motion = nil
local uv = vim.uv or vim.loop

vim.keymap.set('n', '$', function()
  vim.cmd('normal! ' .. vim.v.count1 .. '$')
  last_dollar_motion = {
    bufnr = vim.api.nvim_get_current_buf(),
    winid = vim.api.nvim_get_current_win(),
    time = uv.hrtime(),
  }
end, { desc = 'Go to end of line', silent = true })

vim.keymap.set('x', '$', 'g_', { desc = 'Select to end of visible text', noremap = true, silent = true })

vim.keymap.set('n', 'I', function()
  local just_pressed_dollar = last_dollar_motion
    and last_dollar_motion.bufnr == vim.api.nvim_get_current_buf()
    and last_dollar_motion.winid == vim.api.nvim_get_current_win()
    and (uv.hrtime() - last_dollar_motion.time) < 300000000

  if just_pressed_dollar then
    vim.cmd 'startinsert'
  else
    vim.cmd 'normal! ^'
    vim.cmd 'startinsert'
  end

  last_dollar_motion = nil
end, { desc = 'Insert at line start, or after fast $ typo', silent = true })

-- Resize with arrows
local function resize_visible_neotree(delta)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == 'neo-tree' then
      local width = vim.api.nvim_win_get_width(win)
      vim.api.nvim_win_set_width(win, math.max(1, width + delta))
      return true
    end
  end

  return false
end

vim.keymap.set('n', '<Up>', ':resize -2<CR>', opts)
vim.keymap.set('n', '<Down>', ':resize +2<CR>', opts)
vim.keymap.set('n', '<Left>', function()
  if not resize_visible_neotree(-2) then
    vim.cmd 'vertical resize -2'
  end
end, opts)
vim.keymap.set('n', '<Right>', function()
  if not resize_visible_neotree(2) then
    vim.cmd 'vertical resize +2'
  end
end, opts)

-- Buffers: after switching away in Visual mode, `gv` restores selection when re-entering the buffer
local restore_visual_on_enter = {}
local function mark_restore_visual_if_needed()
  local m = vim.fn.mode()
  local b = string.byte(m, 1) or 0
  if m == 'v' or m == 'V' or m == 's' or m == 'S' or b == 22 then
    restore_visual_on_enter[vim.api.nvim_get_current_buf()] = true
  end
end
local function buffer_next_maybe_restore_visual()
  mark_restore_visual_if_needed()
  vim.cmd.BufferNext()
end
local function buffer_prev_maybe_restore_visual()
  mark_restore_visual_if_needed()
  vim.cmd.BufferPrevious()
end
local function buffer_goto_maybe_restore_visual(index)
  return function()
    mark_restore_visual_if_needed()
    vim.cmd.BufferGoto(index)
  end
end
local function listed_normal_buffers()
  return vim.tbl_filter(function(bufnr)
    return vim.api.nvim_buf_is_valid(bufnr)
      and vim.bo[bufnr].buflisted
      and vim.bo[bufnr].buftype == ''
  end, vim.api.nvim_list_bufs())
end

local function close_current_buffer(force)
  local current = vim.api.nvim_get_current_buf()
  local alternate = vim.fn.bufnr '#'
  local target = nil

  if
    alternate > 0
    and alternate ~= current
    and vim.api.nvim_buf_is_valid(alternate)
    and vim.bo[alternate].buflisted
    and vim.bo[alternate].buftype == ''
    and vim.bo[alternate].filetype ~= 'neo-tree'
  then
    target = alternate
  else
    for _, bufnr in ipairs(listed_normal_buffers()) do
      if bufnr ~= current then
        target = bufnr
        break
      end
    end
  end

  if target then
    vim.api.nvim_win_set_buf(0, target)
  else
    vim.g.skip_neotree_last_window_fallback = true
    vim.cmd.enew()
  end

  pcall(vim.api.nvim_buf_delete, current, { force = force })
  vim.g.skip_neotree_last_window_fallback = false
end

local restore_visual_au = vim.api.nvim_create_augroup('buffer-restore-visual', { clear = true })
vim.api.nvim_create_autocmd('BufEnter', {
  group = restore_visual_au,
  callback = function(args)
    local buf = args.buf
    if not restore_visual_on_enter[buf] then
      return
    end
    restore_visual_on_enter[buf] = nil
    vim.schedule(function()
      if vim.api.nvim_get_current_buf() ~= buf then
        return
      end
      pcall(vim.cmd, 'normal! gv')
    end)
  end,
})
vim.api.nvim_create_autocmd('BufDelete', {
  group = restore_visual_au,
  callback = function(args)
    restore_visual_on_enter[args.buf] = nil
  end,
})

-- Buffers
vim.keymap.set('n', '<C-o>', '<Cmd>BufferNext<CR>', opts)
vim.keymap.set('n', '<Tab>', '<Cmd>BufferNext<CR>', opts)
vim.keymap.set('n', '<S-Tab>', '<Cmd>BufferPrevious<CR>', opts)
vim.keymap.set('v', '<C-o>', buffer_next_maybe_restore_visual, opts)
vim.keymap.set('v', '<Tab>', buffer_next_maybe_restore_visual, opts)
vim.keymap.set('v', '<S-Tab>', buffer_prev_maybe_restore_visual, opts)
vim.keymap.set('n', '<leader>b', '<cmd> enew <CR>', opts) -- new buffer
vim.keymap.set('n', '<leader>x', '<Cmd>BufferClose<CR>', vim.tbl_extend('force', opts, {
  nowait = true,
}))
vim.keymap.set('n', '<leader>X', function()
  close_current_buffer(true)
end, vim.tbl_extend('force', opts, {
  nowait = true,
  desc = 'Force close buffer without saving',
}))
vim.keymap.set('n', '<leader>xa', '<Cmd>BufferCloseAllButCurrent<CR>', vim.tbl_extend('force', opts, {
  desc = 'Close all buffers except current',
}))

-- Window management
vim.keymap.set('n', '<leader>v', '<C-w>v', opts) -- split window vertically
vim.keymap.set('n', '<leader>h', '<C-w>s', opts) -- split window horizontally
vim.keymap.set('n', '<leader>se', '<C-w>=', opts) -- make split windows equal width & height
vim.keymap.set('n', '<leader>xs', '<cmd>close<CR>', opts) -- close current split window

-- Navigate between splits
vim.keymap.set('n', '<C-h>', ':wincmd h<CR>', opts)
vim.keymap.set('n', '<C-l>', ':wincmd l<CR>', opts)

-- Tabs
vim.keymap.set('n', '<leader>to', ':tabnew<CR>', opts) -- open new tab
vim.keymap.set('n', '<leader>tx', ':tabclose<CR>', opts) -- close current tab
vim.keymap.set('n', '<leader>tn', ':tabn<CR>', opts) --  go to next tab
vim.keymap.set('n', '<leader>tp', ':tabp<CR>', opts) --  go to previous tab
vim.keymap.set('n', '<C-Tab>', '<Cmd>BufferNext<CR>', opts)
vim.keymap.set('n', '<C-S-Tab>', '<Cmd>BufferPrevious<CR>', opts)
vim.keymap.set('v', '<C-Tab>', buffer_next_maybe_restore_visual, opts)
vim.keymap.set('v', '<C-S-Tab>', buffer_prev_maybe_restore_visual, opts)
-- Ghostty sends these kitty protocol sequences for Ctrl+Tab / Ctrl+Shift+Tab
vim.keymap.set('n', '\x1b[9;5u', '<Cmd>BufferNext<CR>', opts)
vim.keymap.set('n', '\x1b[9;6u', '<Cmd>BufferPrevious<CR>', opts)
vim.keymap.set('v', '\x1b[9;5u', buffer_next_maybe_restore_visual, opts)
vim.keymap.set('v', '\x1b[9;6u', buffer_prev_maybe_restore_visual, opts)
-- Ghostty custom sequences from ~/.config/ghostty/config
vim.keymap.set('n', '\x1b[27;5;9~', '<Cmd>BufferNext<CR>', opts)
vim.keymap.set('n', '\x1b[27;6;9~', '<Cmd>BufferPrevious<CR>', opts)
vim.keymap.set('v', '\x1b[27;5;9~', buffer_next_maybe_restore_visual, opts)
vim.keymap.set('v', '\x1b[27;6;9~', buffer_prev_maybe_restore_visual, opts)
vim.keymap.set('n', '\x1b[105;5u', '<Cmd>BufferPrevious<CR>', opts)
vim.keymap.set('n', '\x1b[111;5u', '<Cmd>BufferNext<CR>', opts)
vim.keymap.set('v', '\x1b[105;5u', buffer_prev_maybe_restore_visual, opts)
vim.keymap.set('v', '\x1b[111;5u', buffer_next_maybe_restore_visual, opts)
vim.keymap.set('n', '\x1b[27;5;105~', '<Cmd>BufferPrevious<CR>', opts)
vim.keymap.set('n', '\x1b[27;5;111~', '<Cmd>BufferNext<CR>', opts)
vim.keymap.set('v', '\x1b[27;5;105~', buffer_prev_maybe_restore_visual, opts)
vim.keymap.set('v', '\x1b[27;5;111~', buffer_next_maybe_restore_visual, opts)
vim.keymap.set('n', '<C-i>', '<Cmd>BufferPrevious<CR>', opts)
vim.keymap.set('v', '<C-i>', buffer_prev_maybe_restore_visual, opts)
-- Ghostty Ctrl+1-9 → BufferGoto (kitty protocol: ASCII code of digit + ;5u)
vim.keymap.set('n', '\x1b[49;5u', '<Cmd>BufferGoto 1<CR>', opts)
vim.keymap.set('n', '\x1b[50;5u', '<Cmd>BufferGoto 2<CR>', opts)
vim.keymap.set('n', '\x1b[51;5u', '<Cmd>BufferGoto 3<CR>', opts)
vim.keymap.set('n', '\x1b[52;5u', '<Cmd>BufferGoto 4<CR>', opts)
vim.keymap.set('n', '\x1b[53;5u', '<Cmd>BufferGoto 5<CR>', opts)
vim.keymap.set('n', '\x1b[54;5u', '<Cmd>BufferGoto 6<CR>', opts)
vim.keymap.set('n', '\x1b[55;5u', '<Cmd>BufferGoto 7<CR>', opts)
vim.keymap.set('n', '\x1b[56;5u', '<Cmd>BufferGoto 8<CR>', opts)
vim.keymap.set('n', '\x1b[57;5u', '<Cmd>BufferGoto 9<CR>', opts)
vim.keymap.set('v', '\x1b[49;5u', buffer_goto_maybe_restore_visual(1), opts)
vim.keymap.set('v', '\x1b[50;5u', buffer_goto_maybe_restore_visual(2), opts)
vim.keymap.set('v', '\x1b[51;5u', buffer_goto_maybe_restore_visual(3), opts)
vim.keymap.set('v', '\x1b[52;5u', buffer_goto_maybe_restore_visual(4), opts)
vim.keymap.set('v', '\x1b[53;5u', buffer_goto_maybe_restore_visual(5), opts)
vim.keymap.set('v', '\x1b[54;5u', buffer_goto_maybe_restore_visual(6), opts)
vim.keymap.set('v', '\x1b[55;5u', buffer_goto_maybe_restore_visual(7), opts)
vim.keymap.set('v', '\x1b[56;5u', buffer_goto_maybe_restore_visual(8), opts)
vim.keymap.set('v', '\x1b[57;5u', buffer_goto_maybe_restore_visual(9), opts)

-- Toggle line wrapping
vim.keymap.set('n', '<leader>lw', '<cmd>set wrap!<CR>', opts)

-- Stay in indent mode
vim.keymap.set('v', '<', '<gv', opts)
vim.keymap.set('v', '>', '>gv', opts)

-- Keep last yanked when pasting
vim.keymap.set('v', 'p', '"_dP', opts)

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic message' })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic message' })
vim.keymap.set('n', '<leader>d', vim.diagnostic.open_float, { desc = 'Open floating diagnostic message' })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostics list' })

-- Select inner line (excluding indentation and trailing whitespace).
local function with_folds_temporarily_disabled(command)
  local folds_were_enabled = vim.wo.foldenable
  vim.wo.foldenable = false
  vim.cmd(command)
  vim.wo.foldenable = folds_were_enabled
end

vim.keymap.set('x', 'il', function()
  -- `v` is already active here. Move one end to the first non-blank
  -- character, swap ends with `o`, then move the other to the last one.
  with_folds_temporarily_disabled 'normal! ^og_'
end, { desc = 'Select inner physical line' })

vim.keymap.set('o', 'il', function()
  with_folds_temporarily_disabled 'normal! ^vg_'
end, { desc = 'Inside physical line' })

vim.keymap.set('n', '<A-l>', '5zl', { silent = true })
vim.keymap.set('n', '<A-h>', '5zh', { silent = true })
-- Many macOS terminals send Meta instead of Alt
vim.keymap.set('n', '<M-l>', '5zl', { silent = true })
vim.keymap.set('n', '<M-h>', '5zh', { silent = true })
-- macOS specific: if Option key types special characters instead of sending Alt
vim.keymap.set('n', '¬', '5zl', { silent = true }) -- Option+L
vim.keymap.set('n', '˙', '5zh', { silent = true }) -- Option+H

-- Option-Backspace deletes one shell-style/text-object chunk, so
-- `font-semibold` becomes `font` before the next press deletes `font`.
local function delete_option_backspace_chunk()
  local _, col = unpack(vim.api.nvim_win_get_cursor(0))
  local mode = vim.fn.mode()
  local line = vim.api.nvim_get_current_line()

  if col == 0 then
    return '<C-G>u<BS>'
  end

  if not mode:match('^[iR]') and col < #line then
    col = col + 1
  end

  local before = line:sub(1, col)
  local start = col

  while start > 0 and before:sub(start, start):match('%s') do
    start = start - 1
  end

  local chunk_end = start

  if chunk_end == 0 then
    return '<C-G>u' .. string.rep('<BS>', col)
  end

  local char = before:sub(chunk_end, chunk_end)

  if char:match('[%w_]') then
    while start > 0 and before:sub(start, start):match('[%w_]') do
      start = start - 1
    end

    if start > 0 and before:sub(start, start):match('[^%w_%s]') then
      start = start - 1
    end
  else
    while start > 0 and before:sub(start, start):match('[^%w_%s]') do
      start = start - 1
    end
  end

  return '<C-G>u' .. string.rep('<BS>', col - start)
end

vim.keymap.set('i', '<M-BS>', delete_option_backspace_chunk, { expr = true, noremap = true })

-- Command-Backspace clears the current insert line. Ghostty sends the custom
-- escape sequence below because terminals do not consistently pass Cmd keys.
vim.keymap.set('i', '<D-BS>', '<C-G>u<C-u><C-o>D', { noremap = true })
vim.keymap.set('i', '\x1b[127;9u', '<C-G>u<C-u><C-o>D', { noremap = true })

-- Insert mode: csl instantly expands to console.log()
vim.keymap.set('i', 'csl', 'console.log', { noremap = true })

-- set toggle word wrap
vim.keymap.set('n', '<A-z>', ':set wrap!<CR>', { noremap = true, silent = true })

-- personal changes
vim.keymap.set('t', '<Esc>', [[<C-\><C-n>]], { desc = 'Exit terminal mode' })
vim.api.nvim_create_autocmd('TermOpen', {
  callback = function()
    vim.cmd 'startinsert'
  end,
})

-- Smart open terminal: works even when no file is open (e.g. nvim opened on a folder)
local function open_terminal()
  local buf = vim.api.nvim_get_current_buf()
  local buftype = vim.bo[buf].buftype
  local filetype = vim.bo[buf].filetype
  local is_special = buftype ~= '' or filetype == 'neo-tree' or filetype == 'netrw'
  if is_special then
    vim.cmd 'new | terminal'
  else
    vim.cmd 'terminal'
  end
end

vim.keymap.set('n', '<leader>tt', open_terminal, { desc = 'Open terminal' })
vim.api.nvim_create_user_command('Terminal', open_terminal, { desc = 'Open terminal' })

-- barbar keymaps
vim.keymap.set('n', '<A-,>', '<Cmd>BufferPrevious<CR>', { silent = true })
vim.keymap.set('n', '<A-.>', '<Cmd>BufferNext<CR>', { silent = true })
vim.keymap.set('n', '<A-<>', '<Cmd>BufferMovePrevious<CR>', { silent = true })
vim.keymap.set('n', '<A->>', '<Cmd>BufferMoveNext<CR>', { silent = true })
vim.keymap.set('v', '<A-,>', buffer_prev_maybe_restore_visual, { silent = true })
vim.keymap.set('v', '<A-.>', buffer_next_maybe_restore_visual, { silent = true })
vim.keymap.set('n', '<C-1>', '<Cmd>BufferGoto 1<CR>', { silent = true })
vim.keymap.set('n', '<C-2>', '<Cmd>BufferGoto 2<CR>', { silent = true })
vim.keymap.set('n', '<C-3>', '<Cmd>BufferGoto 3<CR>', { silent = true })
vim.keymap.set('n', '<C-4>', '<Cmd>BufferGoto 4<CR>', { silent = true })
vim.keymap.set('n', '<C-5>', '<Cmd>BufferGoto 5<CR>', { silent = true })
vim.keymap.set('n', '<C-6>', '<Cmd>BufferGoto 6<CR>', { silent = true })
vim.keymap.set('n', '<C-7>', '<Cmd>BufferGoto 7<CR>', { silent = true })
vim.keymap.set('n', '<C-8>', '<Cmd>BufferGoto 8<CR>', { silent = true })
vim.keymap.set('n', '<C-9>', '<Cmd>BufferGoto 9<CR>', { silent = true })
vim.keymap.set('v', '<C-1>', buffer_goto_maybe_restore_visual(1), { silent = true })
vim.keymap.set('v', '<C-2>', buffer_goto_maybe_restore_visual(2), { silent = true })
vim.keymap.set('v', '<C-3>', buffer_goto_maybe_restore_visual(3), { silent = true })
vim.keymap.set('v', '<C-4>', buffer_goto_maybe_restore_visual(4), { silent = true })
vim.keymap.set('v', '<C-5>', buffer_goto_maybe_restore_visual(5), { silent = true })
vim.keymap.set('v', '<C-6>', buffer_goto_maybe_restore_visual(6), { silent = true })
vim.keymap.set('v', '<C-7>', buffer_goto_maybe_restore_visual(7), { silent = true })
vim.keymap.set('v', '<C-8>', buffer_goto_maybe_restore_visual(8), { silent = true })
vim.keymap.set('v', '<C-9>', buffer_goto_maybe_restore_visual(9), { silent = true })
vim.keymap.set('n', '<A-0>', '<Cmd>BufferLast<CR>', { silent = true })
vim.keymap.set('n', '<A-c>', '<Cmd>BufferClose<CR>', { silent = true })
vim.keymap.set('n', '<leader>u', '<Cmd>BufferRestore<CR>', { silent = true })
vim.keymap.set('n', '<', '<Cmd>BufferMovePrevious<CR>', { silent = true })
vim.keymap.set('n', '>', '<Cmd>BufferMoveNext<CR>', { silent = true })

-- Prevent neo-tree from becoming the last window
vim.api.nvim_create_autocmd("BufDelete", {
  callback = function()
    if vim.g.skip_neotree_last_window_fallback then
      return
    end

    vim.schedule(function()
      local wins = vim.api.nvim_list_wins()
      local non_tree_exists = false

      for _, win in ipairs(wins) do
        local buf = vim.api.nvim_win_get_buf(win)
        local ft = vim.bo[buf].filetype

        if ft ~= "neo-tree" then
          non_tree_exists = true
          break
        end
      end

      -- if only neo-tree remains, open empty buffer on the right
      if not non_tree_exists then
        vim.cmd("vsplit | enew")
      end
    end)
  end,
})

-- Smart bracket text objects: select the nearest enclosing (), [], or {} pair.
local function smart_bracket_textobject(kind)
  local brackets = { { '(', ')' }, { '[', ']' }, { '{', '}' } }
  local best = nil

  -- Save cursor position
  local save_cursor = vim.fn.getpos('.')

  for _, pair in ipairs(brackets) do
    -- Restore cursor before each search
    vim.fn.setpos('.', save_cursor)

    -- Search backward for the opening bracket of this type
    -- searchpairpos searches for a matching pair, skipping nested pairs
    local row, col = unpack(vim.fn.searchpairpos(
      '\\V' .. pair[1], '', '\\V' .. pair[2], 'bnW'
    ))

    if row ~= 0 then
      -- Found an enclosing bracket of this type
      -- The closer the opening bracket is to the cursor, the more "inner" it is
      local cursor_row = save_cursor[2]
      local cursor_col = save_cursor[3]

      -- Calculate distance (row distance is weighted heavily)
      local dist = (cursor_row - row) * 10000 + (cursor_col - col)

      if best == nil or dist < best.dist then
        best = { dist = dist, open = pair[1] }
      end
    end
  end

  -- Restore cursor position
  vim.fn.setpos('.', save_cursor)

  if best then
    local char = best.open
    local command = kind == 'inner' and 'vi' or 'va'

    if char == '(' then
      vim.cmd('normal! ' .. command .. '(')
    elseif char == '[' then
      vim.cmd('normal! ' .. command .. '[')
    elseif char == '{' then
      vim.cmd('normal! ' .. command .. '{')
    end
  end
end

local function smart_around_bracket()
  smart_bracket_textobject('around')
end

local function smart_inner_bracket()
  smart_bracket_textobject('inner')
end

vim.keymap.set('n', 'vab', smart_around_bracket, { desc = 'Select around nearest bracket', silent = true })
vim.keymap.set('n', 'vib', smart_inner_bracket, { desc = 'Select inside nearest bracket', silent = true })
vim.keymap.set('x', 'ab', smart_around_bracket, { desc = 'Expand selection to around nearest bracket', silent = true })
vim.keymap.set('x', 'ib', smart_inner_bracket, { desc = 'Shrink selection to inside nearest bracket', silent = true })
vim.keymap.set('o', 'ab', smart_around_bracket, { desc = 'Around nearest bracket (operator pending)', silent = true })
vim.keymap.set('o', 'ib', smart_inner_bracket, { desc = 'Inside nearest bracket (operator pending)', silent = true })

local function node_type_matches_function(node)
  local node_type = node:type()
  return node_type:find('function', 1, true) ~= nil
    or node_type:find('method', 1, true) ~= nil
    or node_type == 'arrow_function'
    or node_type == 'lambda'
    or node_type == 'closure_expression'
end

local function get_function_node()
  local ok, node = pcall(vim.treesitter.get_node)
  if not ok then
    node = nil
  end

  if not node then
    local parser_ok, parser = pcall(vim.treesitter.get_parser, 0)
    if not parser_ok or not parser then
      return nil
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local col = cursor[2]
    local tree = parser:parse()[1]
    node = tree and tree:root():named_descendant_for_range(row, col, row, col)
  end

  while node do
    if node_type_matches_function(node) then
      return node
    end
    node = node:parent()
  end

  return nil
end

local function trim_range(start_row, start_col, end_row, end_col)
  local lines = vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, false)
  if #lines == 0 then
    return start_row, start_col, end_row, end_col
  end

  while #lines > 0 and lines[1]:match('^%s*$') do
    start_row = start_row + 1
    table.remove(lines, 1)
    start_col = 0
  end

  while #lines > 0 and lines[#lines]:match('^%s*$') do
    end_row = end_row - 1
    table.remove(lines)
    end_col = #(lines[#lines] or '')
  end

  if #lines == 0 then
    return start_row, start_col, end_row, end_col
  end

  local first_indent = lines[1]:sub(start_col + 1):match('^%s*') or ''
  start_col = start_col + #first_indent

  local last_content_end = lines[#lines]:match('^.*%S()')
  if last_content_end then
    end_col = last_content_end - 1
  end

  return start_row, start_col, end_row, end_col
end

local function inclusive_end_position(row, col)
  if col > 0 then
    return row, col
  end

  if row == 0 then
    return row, col
  end

  local previous_line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ''
  return row - 1, #previous_line
end

local function select_range(start_row, start_col, end_row, end_col)
  end_row, end_col = inclusive_end_position(end_row, end_col)

  if end_row < start_row or (end_row == start_row and end_col < start_col) then
    return
  end

  local old_virtualedit = vim.o.virtualedit
  if not vim.tbl_contains(vim.split(old_virtualedit, ',', { plain = true }), 'onemore') then
    vim.o.virtualedit = old_virtualedit == '' and 'onemore' or (old_virtualedit .. ',onemore')
  end

  vim.fn.setpos('.', { 0, start_row + 1, start_col + 1, 0 })
  vim.cmd('normal! v')
  vim.fn.setpos('.', { 0, end_row + 1, end_col, 0 })
  vim.o.virtualedit = old_virtualedit
end

local element_node_types = {
  element = true,
  jsx_element = true,
  jsx_fragment = true,
  jsx_self_closing_element = true,
}

local opening_tag_node_types = {
  jsx_opening_element = true,
  jsx_opening_fragment = true,
  start_tag = true,
}

local closing_tag_node_types = {
  jsx_closing_element = true,
  jsx_closing_fragment = true,
  end_tag = true,
}

local self_closing_tag_node_types = {
  jsx_self_closing_element = true,
  self_closing_tag = true,
}

local function range_contains_position(start_row, start_col, end_row, end_col, row, col)
  if row < start_row or row > end_row then
    return false
  end

  if row == start_row and col < start_col then
    return false
  end

  -- Tree-sitter ranges end immediately after the final character.
  return row ~= end_row or col < end_col
end

local function smallest_tag_element_at(node, row, col)
  local start_row, start_col, end_row, end_col = node:range()
  if not range_contains_position(start_row, start_col, end_row, end_col, row, col) then
    return nil
  end

  for child in node:iter_children() do
    local match = smallest_tag_element_at(child, row, col)
    if match then
      return match
    end
  end

  return element_node_types[node:type()] and node or nil
end

local function get_tag_element_node()
  local parser_ok, parser = pcall(vim.treesitter.get_parser, 0)
  if not parser_ok or not parser then
    return nil
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]
  local tree = parser:parse()[1]

  -- In Vue directives get_node() can return an injected JavaScript node, whose
  -- parents do not include the surrounding template element.
  return tree and smallest_tag_element_at(tree:root(), row, col) or nil
end

local function find_direct_child_by_type(node, types)
  for child in node:iter_children() do
    if types[child:type()] then
      return child
    end
  end

  return nil
end

local function select_tag(inner)
  local node = get_tag_element_node()
  if not node then
    vim.notify('No Treesitter tag found under cursor', vim.log.levels.INFO)
    return
  end

  if not inner then
    select_range(node:range())
    return
  end

  if self_closing_tag_node_types[node:type()] or find_direct_child_by_type(node, self_closing_tag_node_types) then
    vim.notify('Self-closing tag has no inner content', vim.log.levels.INFO)
    return
  end

  local opening = find_direct_child_by_type(node, opening_tag_node_types)
  local closing = find_direct_child_by_type(node, closing_tag_node_types)
  if not opening or not closing then
    vim.notify('No matching tag pair found under cursor', vim.log.levels.INFO)
    return
  end

  local start_row, start_col = select(3, opening:range())
  local end_row, end_col = closing:range()
  select_range(start_row, start_col, end_row, end_col)
end

local function python_def_indent(line)
  return line:match('^(%s*)async%s+def%s+') or line:match('^(%s*)def%s+')
end

local function leading_whitespace(line)
  return line:match('^%s*') or ''
end

local function select_python_function(inner)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_row = cursor[1] - 1
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local start_row = nil
  local def_indent = nil

  for row = cursor_row, 0, -1 do
    local indent = python_def_indent(lines[row + 1] or '')
    if indent then
      start_row = row
      def_indent = indent
      break
    end
  end

  if not start_row then
    return false
  end

  local end_row = #lines - 1
  local last_content_row = start_row

  for row = start_row + 1, #lines - 1 do
    local line = lines[row + 1] or ''
    if line:match('%S') then
      local indent = leading_whitespace(line)
      if #indent <= #def_indent then
        end_row = math.max(start_row, row - 1)
        break
      end
      last_content_row = row
    end
  end

  if inner then
    start_row = start_row + 1
    while start_row <= end_row and not (lines[start_row + 1] or ''):match('%S') do
      start_row = start_row + 1
    end

    end_row = last_content_row
    while end_row >= start_row and not (lines[end_row + 1] or ''):match('%S') do
      end_row = end_row - 1
    end
  end

  if end_row < start_row then
    return false
  end

  local start_col = inner and #leading_whitespace(lines[start_row + 1] or '') or 0
  local end_col = #(lines[end_row + 1] or '')
  select_range(start_row, start_col, end_row, end_col)
  return true
end

local function function_body_node(function_node)
  local ok, body = pcall(function()
    return function_node:field('body')[1]
  end)

  if ok and body then
    return body
  end

  for child in function_node:iter_children() do
    local node_type = child:type()
    if node_type:find('block', 1, true) or node_type == 'body' then
      return child
    end
  end

  return nil
end

local function select_function(inner)
  local function_node = get_function_node()
  if not function_node then
    if vim.bo.filetype == 'python' and select_python_function(inner) then
      return
    end

    vim.notify('No Treesitter function found under cursor', vim.log.levels.INFO)
    return
  end

  local start_row, start_col, end_row, end_col = function_node:range()

  if inner then
    local body = function_body_node(function_node)
    if body then
      start_row, start_col, end_row, end_col = body:range()

      local first_line = vim.api.nvim_buf_get_lines(0, start_row, start_row + 1, false)[1] or ''
      local last_line = vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1] or ''

      if first_line:sub(start_col + 1, start_col + 1) == '{' then
        start_col = start_col + 1
      end

      if end_col > 0 and last_line:sub(end_col, end_col) == '}' then
        end_col = end_col - 1
      end

      start_row, start_col, end_row, end_col = trim_range(start_row, start_col, end_row, end_col)
    end
  end

  select_range(start_row, start_col, end_row, end_col)
end

vim.keymap.set({ 'x', 'o' }, 'af', function()
  select_function(false)
end, { desc = 'Around function', silent = true })

vim.keymap.set({ 'x', 'o' }, 'if', function()
  select_function(true)
end, { desc = 'Inside function', silent = true })

vim.keymap.set('n', 'vaf', function()
  select_function(false)
end, { desc = 'Select around function', silent = true })

vim.keymap.set('n', 'vif', function()
  select_function(true)
end, { desc = 'Select inside function', silent = true })

vim.keymap.set({ 'x', 'o' }, 'at', function()
  select_tag(false)
end, { desc = 'Around tag', silent = true })

vim.keymap.set({ 'x', 'o' }, 'it', function()
  select_tag(true)
end, { desc = 'Inside tag', silent = true })

vim.keymap.set('n', 'vat', function()
  select_tag(false)
end, { desc = 'Select around tag', silent = true })

vim.keymap.set('n', 'vit', function()
  select_tag(true)
end, { desc = 'Select inside tag', silent = true })

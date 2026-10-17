-- Full Git workflow: gutter signs, merge conflicts, and VS Code–style diffs
local diffview_buffers = {
  active = false,
  pre_existing = {},
}

local function is_listed_loaded_buffer(buf)
  return vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted
end

local function hide_pre_diffview_buffers()
  diffview_buffers.active = true
  diffview_buffers.pre_existing = {}

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if is_listed_loaded_buffer(buf) then
      diffview_buffers.pre_existing[buf] = true
      vim.bo[buf].buflisted = false
    end
  end
end

local function restore_pre_diffview_buffers()
  for buf in pairs(diffview_buffers.pre_existing) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      vim.bo[buf].buflisted = true
    end
  end
end

local function cleanup_diffview_buffers()
  if not diffview_buffers.active then
    return
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if is_listed_loaded_buffer(buf) and not diffview_buffers.pre_existing[buf] then
      vim.cmd('bwipeout! ' .. buf)
    end
  end

  restore_pre_diffview_buffers()
  diffview_buffers.active = false
  diffview_buffers.pre_existing = {}
end

return {
  -- Gutter signs + blame
  {
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '▎' },
        change = { text = '▎' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      signs_staged = {
        add = { text = '▎' },
        change = { text = '▎' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      current_line_blame = false, -- toggle with <leader>tb (perf: avoid git blame on every cursor move)
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local map = function(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        map('n', ']c', gs.next_hunk, { desc = 'Next Git Hunk' })
        map('n', '[c', gs.prev_hunk, { desc = 'Prev Git Hunk' })

        -- VS Code style: peek at the original code before it was changed
        map('n', '<leader>hp', gs.preview_hunk, { desc = 'Preview git hunk (like VS Code)' })
        map('n', '<leader>hr', gs.reset_hunk, { desc = 'Revert (reset) this git change' })
        map('n', '<leader>tb', gs.toggle_current_line_blame, { desc = '[T]oggle git [B]lame' })
      end,
    },
    config = function(_, opts)
      require('gitsigns').setup(opts)

      -- Define a function to set dimmer/lighter shades for staged changes
      local function set_staged_hls()
        -- You can tweak these hex colors to be as light or dim as you prefer
        vim.api.nvim_set_hl(0, 'GitSignsStagedAdd', { fg = '#4a6a4a' })           -- Dimmed green
        vim.api.nvim_set_hl(0, 'GitSignsStagedChange', { fg = '#3a5a7a' })        -- Dimmed blue
        vim.api.nvim_set_hl(0, 'GitSignsStagedDelete', { fg = '#7a3a3a' })        -- Dimmed red
        vim.api.nvim_set_hl(0, 'GitSignsStagedTopdelete', { fg = '#7a3a3a' })
        vim.api.nvim_set_hl(0, 'GitSignsStagedChangedelete', { fg = '#7a3a3a' })
      end

      -- Apply immediately
      set_staged_hls()

      -- Ensure the colors persist even if the colorscheme is changed/reloaded
      vim.api.nvim_create_autocmd('ColorScheme', {
        pattern = '*',
        callback = set_staged_hls,
      })
    end,
  },

  -- Merge conflict resolver
  {
    'akinsho/git-conflict.nvim',
    version = '*',
    event = { 'BufReadPost', 'BufNewFile' },
    cmd = {
      'GitConflictChooseOurs',
      'GitConflictChooseTheirs',
      'GitConflictChooseBoth',
      'GitConflictChooseNone',
    },
    keys = {
      { '<leader>go', '<cmd>GitConflictChooseOurs<cr>', desc = 'Choose ours' },
      { '<leader>gt', '<cmd>GitConflictChooseTheirs<cr>', desc = 'Choose theirs' },
      { '<leader>gb', '<cmd>GitConflictChooseBoth<cr>', desc = 'Choose both' },
      { '<leader>gn', '<cmd>GitConflictChooseNone<cr>', desc = 'Choose none' },
    },
    config = function()
      local ok, git_conflict = pcall(require, 'git-conflict')
      if not ok then
        vim.notify('git-conflict.nvim failed to load', vim.log.levels.ERROR)
        return
      end

      git_conflict.setup {
        default_mappings = false,
        default_commands = true,
        disable_diagnostics = false,
      }

      vim.keymap.set('n', '<leader>go', ':GitConflictChooseOurs<CR>', { desc = 'Choose ours' })
      vim.keymap.set('n', '<leader>gt', ':GitConflictChooseTheirs<CR>', { desc = 'Choose theirs' })
      vim.keymap.set('n', '<leader>gb', ':GitConflictChooseBoth<CR>', { desc = 'Choose both' })
      vim.keymap.set('n', '<leader>gn', ':GitConflictChooseNone<CR>', { desc = 'Choose none' })
    end,
  },

  -- Main Git interface
  {
    'NeogitOrg/neogit',
    cmd = 'Neogit',
    keys = {
      {
        '<leader>gs',
        function()
          require('neogit').open { kind = 'tab' }
        end,
        desc = 'Open Neogit (tab)',
      },
      { '<leader>gd', desc = 'Toggle Diffview' },
      { '<leader>gD', desc = 'Toggle Diffview' },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'sindrets/diffview.nvim',
      'nvim-telescope/telescope.nvim',
    },
    config = function()
      local neogit = require 'neogit'
      neogit.setup {
        integrations = {
          diffview = true,
        },
        kind = 'tab',
        disable_commit_confirmation = true,
      }

      vim.keymap.set('n', '<leader>gs', function()
        neogit.open { kind = 'tab' }
      end, { desc = 'Open Neogit (tab)' })

      local function toggle_diffview()
        local lib_ok, lib = pcall(require, 'diffview.lib')
        if lib_ok and lib.get_current_view() then
          vim.cmd('DiffviewClose')
          vim.schedule(cleanup_diffview_buffers)
        else
          hide_pre_diffview_buffers()
          local ok, err = pcall(vim.cmd, 'DiffviewOpen --no-ignore-whitespace')
          if not ok then
            restore_pre_diffview_buffers()
            diffview_buffers.active = false
            diffview_buffers.pre_existing = {}
            vim.notify('Not in a git repository', vim.log.levels.WARN)
          end
        end
      end

      -- show whitespace changes also, toggle
      vim.keymap.set('n', '<leader>gd', toggle_diffview, { desc = 'Toggle Diffview' })
      vim.keymap.set('n', '<leader>gD', toggle_diffview, { desc = 'Toggle Diffview' })
    end,
  },

  -- Better diff viewing
  {
    'sindrets/diffview.nvim',
    cmd = {
      'DiffviewOpen',
      'DiffviewClose',
      'DiffviewToggleFiles',
      'DiffviewFocusFiles',
      'DiffviewFileHistory',
    },
    dependencies = 'nvim-lua/plenary.nvim',
    config = function()
      local actions = require 'diffview.actions'
      local left_focus_request = 0
      local deleted_file_match = [[^D \zs.*$]]
      local untracked_file_match = [[^U\ze ]]
      local deleted_file_group = vim.api.nvim_create_augroup('DiffviewDeletedFileStrike', { clear = true })

      local function set_deleted_file_hl()
        vim.api.nvim_set_hl(0, 'DiffviewDeletedFile', { strikethrough = true })
      end

      local function display_untracked_as_u(buf)
        if not (buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == 'DiffviewFiles') then
          return
        end

        local was_modifiable = vim.bo[buf].modifiable
        local was_modified = vim.bo[buf].modified
        vim.bo[buf].modifiable = true

        for line_num, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
          if line:sub(1, 2) == '? ' then
            vim.api.nvim_buf_set_text(buf, line_num - 1, 0, line_num - 1, 1, { 'U' })
          end
        end

        vim.bo[buf].modifiable = was_modifiable
        vim.bo[buf].modified = was_modified
      end

      local function patch_diffview_file_panel()
        local ok, file_panel = pcall(require, 'diffview.scene.views.diff.file_panel')
        if not ok or file_panel.FilePanel._display_untracked_as_u then
          return
        end

        local original_redraw = file_panel.FilePanel.redraw
        file_panel.FilePanel.redraw = function(panel)
          original_redraw(panel)
          display_untracked_as_u(panel.bufid)
        end
        file_panel.FilePanel._display_untracked_as_u = true
      end

      local function add_deleted_file_match()
        if vim.bo.filetype ~= 'DiffviewFiles' then
          return
        end

        if not vim.w.diffview_deleted_file_match then
          vim.w.diffview_deleted_file_match = vim.fn.matchadd('DiffviewDeletedFile', deleted_file_match, 20)
        end

        if not vim.w.diffview_untracked_file_match then
          vim.w.diffview_untracked_file_match = vim.fn.matchadd('DiffviewStatusUntracked', untracked_file_match, 30)
        end

        display_untracked_as_u(vim.api.nvim_get_current_buf())
      end

      set_deleted_file_hl()
      patch_diffview_file_panel()

      vim.api.nvim_create_autocmd('ColorScheme', {
        group = deleted_file_group,
        pattern = '*',
        callback = set_deleted_file_hl,
      })

      vim.api.nvim_create_autocmd({ 'FileType', 'BufWinEnter', 'WinEnter' }, {
        group = deleted_file_group,
        pattern = '*',
        callback = add_deleted_file_match,
      })

      local function focus_left_diff_pane()
        local ok, lib = pcall(require, 'diffview.lib')
        local view = ok and lib.get_current_view()
        local item = view and view.panel and view.panel:get_item_at_cursor()

        if item and type(item.collapsed) == 'boolean' then
          view.panel:toggle_item_fold(item)
          return
        end

        left_focus_request = left_focus_request + 1
        local request = left_focus_request

        require('diffview').emit 'focus_entry'

        local function focus_left(attempt)
          if request ~= left_focus_request then
            return
          end

          local ok, lib = pcall(require, 'diffview.lib')
          if not ok then
            return
          end

          local view = lib.get_current_view()
          local left_win = view and view.cur_layout and view.cur_layout.a and view.cur_layout.a.id
          if left_win and vim.api.nvim_win_is_valid(left_win) then
            vim.api.nvim_set_current_win(left_win)
          end

          if attempt < 6 then
            vim.defer_fn(function()
              focus_left(attempt + 1)
            end, 25)
          end
        end

        vim.schedule(function()
          focus_left(1)
        end)
      end

      local function confirm_restore_entry()
        local ok, lib = pcall(require, 'diffview.lib')
        local view = ok and lib.get_current_view()
        local file = view and view.infer_cur_file and view:infer_cur_file()
        local name = file and file.path and vim.fn.fnamemodify(file.path, ':t') or 'this file'

        if vim.fn.confirm('Discard changes in ' .. name .. '?', '&Yes\n&No', 1) == 1 then
          actions.restore_entry()
        end
      end

      local function file_panel_half_page(down)
        local ok, lib = pcall(require, 'diffview.lib')
        local view = ok and lib.get_current_view()
        local panel = view and view.panel
        if not panel or not panel:is_open() then
          return
        end
        local win = panel.winid
        if not win or not vim.api.nvim_win_is_valid(win) or type(panel.constrain_cursor) ~= 'function' then
          return
        end
        local count = vim.v.count
        if count == 0 then
          count = math.max(1, math.floor(vim.api.nvim_win_get_height(win) / 2))
        end
        if not down then
          count = -count
        end
        pcall(vim.api.nvim_win_set_cursor, win, { panel.constrain_cursor(win, count), 0 })
      end

      require('diffview').setup {
        enhanced_diff_hl = true,
        hooks = {
          view_closed = cleanup_diffview_buffers,
        },
        view = {
          default = {
            layout = 'diff2_horizontal',
          },
        },
        file_panel = {
          win_config = { position = 'left', width = 35 },
        },
        keymaps = {
          view = {
            { 'n', '<leader>e', actions.toggle_files, { desc = 'Toggle the file panel' } },
            { 'n', '<leader>b', false },
          },
          file_panel = {
            { 'n', '<cr>', focus_left_diff_pane, { desc = 'Open selected file and focus left diff' } },
            { 'n', 'd', confirm_restore_entry, { desc = 'Discard selected file changes' } },
            { 'n', 'X', confirm_restore_entry, { desc = 'Restore entry to the state on the left side' } },
            { 'n', '<leader>e', actions.toggle_files, { desc = 'Toggle the file panel' } },
            { 'n', '<leader>b', false },
            { 'n', '<C-d>', function()
              file_panel_half_page(true)
            end, { desc = 'Half page down (stay in file list)' } },
            { 'n', '<C-u>', function()
              file_panel_half_page(false)
            end, { desc = 'Half page up (stay in file list)' } },
          },
        },
      }
    end,
  },
}

return {
  'nvim-neo-tree/neo-tree.nvim',
  branch = 'v3.x',
  cmd = 'Neotree',
  keys = {
    { '\\', '<cmd>Neotree reveal<cr>', desc = 'Reveal current file in Neo-tree' },
    { '<leader>e', '<cmd>Neotree toggle position=left<cr>', desc = 'Toggle Neo-tree' },
    { '<leader>ngs', '<cmd>Neotree float git_status<cr>', desc = 'Neo-tree git status' },
  },
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons',
    'MunifTanjim/nui.nvim',

    {
      's1n7ax/nvim-window-picker',
      version = '2.*',
      config = function()
        require('window-picker').setup {
          filter_rules = {
            include_current_win = false,
            autoselect_one = true,
            -- filter using buffer options
            bo = {
              -- if the file type is one of following, the window will be ignored
              filetype = { 'neo-tree', 'neo-tree-popup', 'notify' },
              -- if the buffer type is one of following, the window will be ignored
              buftype = { 'terminal', 'quickfix' },
            },
          },
        }
      end,
    },
  },
  config = function()
    -- If you want icons for diagnostic errors, you'll need to define them somewhere:
    vim.fn.sign_define('DiagnosticSignError', { text = ' ', texthl = 'DiagnosticSignError' })
    vim.fn.sign_define('DiagnosticSignWarn', { text = ' ', texthl = 'DiagnosticSignWarn' })
    vim.fn.sign_define('DiagnosticSignInfo', { text = ' ', texthl = 'DiagnosticSignInfo' })
    vim.fn.sign_define('DiagnosticSignHint', { text = '󰌵', texthl = 'DiagnosticSignHint' })

    local function set_neotree_git_hls()
      vim.api.nvim_set_hl(0, 'NeoTreeGitUntracked', { fg = '#98c379' })
    end

    set_neotree_git_hls()

    vim.api.nvim_create_autocmd('ColorScheme', {
      pattern = '*',
      callback = set_neotree_git_hls,
    })

    local function trash_paths(paths)
      if vim.fn.has 'mac' == 1 then
        local trash_dir = vim.fn.expand '~/.Trash'
        local uv = vim.uv or vim.loop
        vim.fn.mkdir(trash_dir, 'p')

        local errors = {}
        for _, path in ipairs(paths) do
          local base = vim.fn.fnamemodify(path, ':t')
          local target = trash_dir .. '/' .. base
          local counter = 0

          while uv.fs_stat(target) do
            counter = counter + 1
            target = trash_dir .. '/' .. base .. ' ' .. os.date('%Y%m%d%H%M%S') .. '-' .. counter
          end

          local result = vim.fn.system({ 'mv', path, target })
          if vim.v.shell_error ~= 0 then
            table.insert(errors, result)
          end
        end

        return table.concat(errors, '\n'), #errors
      end

      local trash_cmd = nil
      if vim.fn.executable 'trash-put' == 1 then
        trash_cmd = { 'trash-put' }
      elseif vim.fn.executable 'gio' == 1 then
        trash_cmd = { 'gio', 'trash' }
      elseif vim.fn.executable 'trash' == 1 then
        trash_cmd = { 'trash' }
      end

      if not trash_cmd then
        return 'No trash command found. Install trash-cli, gio, or trash.', 1
      end

      return vim.fn.system(vim.list_extend(trash_cmd, paths)), vim.v.shell_error
    end

    local function refresh_neotree(state)
      require('neo-tree.sources.manager').refresh(state.name)
    end

    -- Neo-tree runs file actions from its own window. Deleting a file that is
    -- displayed in another window would otherwise close that window, leaving
    -- Neo-tree as the only one and triggering the last-window fallback below.
    -- Keep a small MRU list so the editor can show the next recent file instead.
    local recent_file_buffers = {}

    local function is_file_buffer(bufnr, excluded)
      if excluded[bufnr] or not vim.api.nvim_buf_is_valid(bufnr) then
        return false
      end

      if not vim.bo[bufnr].buflisted or vim.bo[bufnr].buftype ~= '' then
        return false
      end

      local path = vim.api.nvim_buf_get_name(bufnr)
      local stat = path ~= '' and (vim.uv or vim.loop).fs_stat(path)
      return stat and stat.type == 'file'
    end

    vim.api.nvim_create_autocmd('BufEnter', {
      group = vim.api.nvim_create_augroup('neo-tree-recent-file-buffers', { clear = true }),
      callback = function(args)
        local bufnr = args.buf
        if vim.bo[bufnr].buftype ~= '' or vim.api.nvim_buf_get_name(bufnr) == '' then
          return
        end

        for index = #recent_file_buffers, 1, -1 do
          if recent_file_buffers[index] == bufnr then
            table.remove(recent_file_buffers, index)
          end
        end
        table.insert(recent_file_buffers, bufnr)
      end,
    })

    local function replacement_buffer(excluded)
      for index = #recent_file_buffers, 1, -1 do
        local bufnr = recent_file_buffers[index]
        if is_file_buffer(bufnr, excluded) then
          return bufnr
        end
        table.remove(recent_file_buffers, index)
      end

      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if is_file_buffer(bufnr, excluded) then
          return bufnr
        end
      end
    end

    local function close_trashed_buffers(paths)
      local trashed_buffers = {}
      for _, path in ipairs(paths) do
        local bufnr = vim.fn.bufnr(path)
        if bufnr ~= -1 then
          trashed_buffers[bufnr] = true
        end
      end

      if next(trashed_buffers) == nil then
        return
      end

      local replacement = replacement_buffer(trashed_buffers)
      for _, winid in ipairs(vim.api.nvim_list_wins()) do
        if trashed_buffers[vim.api.nvim_win_get_buf(winid)] then
          if replacement then
            vim.api.nvim_win_set_buf(winid, replacement)
          else
            vim.api.nvim_win_call(winid, function()
              vim.cmd 'enew'
            end)
          end
        end
      end

      for bufnr in pairs(trashed_buffers) do
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end

    local function confirm_trash(paths)
      local label = #paths == 1 and vim.fn.fnamemodify(paths[1], ':t') or #paths .. ' items'
      return vim.fn.confirm('Move ' .. label .. ' to Trash?', '&Yes\n&No', 1) == 1
    end

    local function trash_nodes(state, nodes)
      local paths = {}
      for _, node in pairs(nodes) do
        if node.type ~= 'file' and node.type ~= 'directory' then
          vim.notify('Only files and directories can be moved to Trash', vim.log.levels.WARN)
          return
        end

        if node:get_depth() == 1 then
          vim.notify('Neo-tree root cannot be moved to Trash from here', vim.log.levels.ERROR)
          return
        end

        table.insert(paths, node.path)
      end

      if #paths == 0 or not confirm_trash(paths) then
        return
      end

      local output, code = trash_paths(paths)
      if code ~= 0 then
        vim.notify('Could not move to Trash: ' .. output, vim.log.levels.ERROR)
        return
      end

      close_trashed_buffers(paths)
      refresh_neotree(state)
      vim.notify('Moved to Trash: ' .. (#paths == 1 and vim.fn.fnamemodify(paths[1], ':t') or #paths .. ' items'))
    end

    local custom_trash = function(state)
      local node = state.tree:get_node()
      trash_nodes(state, { node })
    end

    local custom_trash_visual = function(state, selected_nodes)
      trash_nodes(state, selected_nodes)
    end

    require('neo-tree').setup {
      close_if_last_window = false, -- Close Neo-tree if it is the last window left in the tab
      popup_border_style = 'rounded',
      enable_git_status = true,
      enable_diagnostics = true,
      hide_root_node = true,  -- hide the full path root header
      retain_hidden_root_indent = true,  -- keep proper indentation
      -- enable_normal_mode_for_inputs = false,                             -- Enable normal mode for input dialogs.
      open_files_do_not_replace_types = { 'terminal', 'trouble', 'qf' }, -- when opening files, do not use windows containing these filetypes or buftypes
      sort_case_insensitive = false, -- used when sorting files and directories in the tree
      sort_function = nil, -- use a custom function for sorting files and directories in the tree
      -- sort_function = function (a,b)
      --       if a.type == b.type then
      --           return a.path > b.path
      --       else
      --           return a.type > b.type
      --       end
      --   end , -- this sorts files and directories descendantly
      default_component_configs = {
        container = {
          enable_character_fade = true,
        },
        indent = {
          indent_size = 2,
          padding = 1, -- extra padding on left hand side
          -- indent guides
          with_markers = true,
          indent_marker = '│',
          last_indent_marker = '└',
          highlight = 'NeoTreeIndentMarker',
          -- expander config, needed for nesting files
          with_expanders = nil, -- if nil and file nesting is enabled, will enable expanders
          expander_collapsed = '',
          expander_expanded = '',
          expander_highlight = 'NeoTreeExpander',
        },
        icon = {
          folder_closed = '',
          folder_open = '',
          folder_empty = '󰜌',
          -- The next two settings are only a fallback, if you use nvim-web-devicons and configure default icons there
          -- then these will never be used.
          default = '*',
          highlight = 'NeoTreeFileIcon',
        },
        modified = {
          symbol = '[+]',
          highlight = 'NeoTreeModified',
        },
        name = {
          trailing_slash = false,
          use_git_status_colors = true,
          highlight = 'NeoTreeFileName',
        },
        git_status = {
          symbols = {
            -- Change type
            added = 'A',
            modified = 'M',
            deleted = 'D',
            renamed = 'R',
            -- Status type
            untracked = 'U',
            ignored = '◌',
            unstaged = '',
            staged = '',
            conflict = 'C',
          },
        },
        -- If you don't want to use these columns, you can set `enabled = false` for each of them individually
        file_size = {
          enabled = true,
          required_width = 64, -- min width of window required to show this column
        },
        type = {
          enabled = true,
          required_width = 122, -- min width of window required to show this column
        },
        last_modified = {
          enabled = true,
          required_width = 88, -- min width of window required to show this column
        },
        created = {
          enabled = true,
          required_width = 110, -- min width of window required to show this column
        },
        symlink_target = {
          enabled = false,
        },
      },
      -- A list of functions, each representing a global custom command
      -- that will be available in all sources (if not overridden in `opts[source_name].commands`)
      -- see `:h neo-tree-custom-commands-global`
      commands = {
        shrink_width = function()
          local width = vim.api.nvim_win_get_width(0)
          vim.api.nvim_win_set_width(0, math.max(1, width - 2))
        end,
        expand_width = function()
          local width = vim.api.nvim_win_get_width(0)
          vim.api.nvim_win_set_width(0, width + 2)
        end,
        trash = custom_trash,
        trash_visual = custom_trash_visual,
      },
      window = {
        position = 'left',
        width = 40,
        mapping_options = {
          noremap = true,
          nowait = true,
        },
        mappings = {
          ['<space>'] = {
            'toggle_node',
            nowait = false, -- disable `nowait` if you have existing combos starting with this char that you want to use
          },
          ['<2-LeftMouse>'] = 'open',
          ['<cr>'] = 'open',
          ['<esc>'] = 'cancel', -- close preview or floating neo-tree window
          ['P'] = { 'toggle_preview', config = { use_float = true } },
          ['<Left>'] = 'shrink_width',
          ['<Right>'] = 'expand_width',
          ['l'] = 'open',
          ['S'] = 'open_split',
          ['s'] = 'open_vsplit',
          -- ["S"] = "split_with_window_picker",
          -- ["s"] = "vsplit_with_window_picker",
          ['t'] = 'open_tabnew',
          -- ["<cr>"] = "open_drop",
          -- ["t"] = "open_tab_drop",
          ['w'] = 'open_with_window_picker',
          --["P"] = "toggle_preview", -- enter preview mode, which shows the current node without focusing
          ['C'] = 'close_node',
          -- ['C'] = 'close_all_subnodes',
          ['z'] = 'close_all_nodes',
          --["Z"] = "expand_all_nodes",
          ['n'] = {
            'add',
            -- this command supports BASH style brace expansion ("x{a,b,c}" -> xa,xb,xc). see `:h neo-tree-file-actions` for details
            -- some commands may take optional config options, see `:h neo-tree-mappings` for details
            config = {
              show_path = 'none', -- "none", "relative", "absolute"
            },
          },
          ['A'] = 'add_directory', -- also accepts the optional config.show_path option like "add". this also supports BASH style brace expansion.
          ['d'] = 'trash',
          ['r'] = 'rename',
          ['y'] = 'copy_to_clipboard',
          ['x'] = 'cut_to_clipboard',
          ['p'] = 'paste_from_clipboard',
          ['c'] = 'copy', -- takes text input for destination, also accepts the optional config.show_path option like "add":
          -- ["c"] = {
          --  "copy",
          --  config = {
          --    show_path = "none" -- "none", "relative", "absolute"
          --  }
          --}
          ['m'] = 'move', -- takes text input for destination, also accepts the optional config.show_path option like "add".
          ['q'] = 'close_window',
          ['R'] = 'refresh',
          ['?'] = 'show_help',
          ['<'] = 'prev_source',
          ['>'] = 'next_source',
          ['i'] = 'show_file_details',
        },
      },
      nesting_rules = {},
      filesystem = {
        filtered_items = {
          visible = false, -- when true, they will just be displayed differently than normal items
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_hidden = false, -- only works on Windows for hidden files/directories
          hide_by_name = {
            '.DS_Store',
            'thumbs.db',
            '__pycache__',
            '.virtual_documents',
            '.git',
            '.python-version',
            '.venv',
            '.turbo',
          },
          hide_by_pattern = { -- uses glob style patterns
            --"*.meta",
            --"*/src/*/tsconfig.json",
          },
          always_show = { -- remains visible even if other settings would normally hide it
            --".gitignored",
          },
          never_show = { -- remains hidden even if visible is toggled to true, this overrides always_show
            '.cache',
            --".DS_Store",
            --"thumbs.db"
          },
          never_show_by_pattern = { -- uses glob style patterns
            --".null-ls_*",
          },
        },
        follow_current_file = {
          enabled = true, -- This will find and focus the file in the active buffer every time
          --               -- the current file is changed while the tree is open.
          leave_dirs_open = false, -- `false` closes auto expanded dirs, such as with `:Neotree reveal`
        },
        group_empty_dirs = false, -- when true, empty folders will be grouped together
        hijack_netrw_behavior = 'open_default', -- netrw disabled, opening a directory opens neo-tree
        -- in whatever position is specified in window.position
        -- "open_current",  -- netrw disabled, opening a directory opens within the
        -- window like netrw would, regardless of window.position
        -- "disabled",    -- netrw left alone, neo-tree does not handle opening dirs
        use_libuv_file_watcher = false, -- disabled: FocusGained autocmd handles refresh instead
        window = {
          mappings = {
            ['<bs>'] = 'navigate_up',
            ['.'] = 'set_root',
            ['H'] = 'toggle_hidden',
            ['/'] = 'fuzzy_finder',
            ['D'] = 'fuzzy_finder_directory',
            ['#'] = 'fuzzy_sorter', -- fuzzy sorting using the fzy algorithm
            -- ["D"] = "fuzzy_sorter_directory",
            ['f'] = 'filter_on_submit',
            ['<c-x>'] = 'clear_filter',
            ['[g'] = 'prev_git_modified',
            [']g'] = 'next_git_modified',
            ['o'] = { 'show_help', nowait = false, config = { title = 'Order by', prefix_key = 'o' } },
            ['oc'] = { 'order_by_created', nowait = false },
            ['od'] = { 'order_by_diagnostics', nowait = false },
            ['og'] = { 'order_by_git_status', nowait = false },
            ['om'] = { 'order_by_modified', nowait = false },
            ['on'] = { 'order_by_name', nowait = false },
            ['os'] = { 'order_by_size', nowait = false },
            ['ot'] = { 'order_by_type', nowait = false },
          },
          fuzzy_finder_mappings = { -- define keymaps for filter popup window in fuzzy_finder_mode
            ['<down>'] = 'move_cursor_down',
            ['<C-n>'] = 'move_cursor_down',
            ['<up>'] = 'move_cursor_up',
            ['<C-p>'] = 'move_cursor_up',
          },
        },

        commands = {
          trash = custom_trash,
          trash_visual = custom_trash_visual,
        }, -- Add a custom command or override a global one using the same function name
      },
      buffers = {
        follow_current_file = {
          enabled = true, -- This will find and focus the file in the active buffer every time
          --              -- the current file is changed while the tree is open.
          leave_dirs_open = false, -- `false` closes auto expanded dirs, such as with `:Neotree reveal`
        },
        group_empty_dirs = true, -- when true, empty folders will be grouped together
        show_unloaded = true,
        window = {
          mappings = {
            ['bd'] = 'buffer_delete',
            ['<bs>'] = 'navigate_up',
            ['.'] = 'set_root',
            ['o'] = { 'show_help', nowait = false, config = { title = 'Order by', prefix_key = 'o' } },
            ['oc'] = { 'order_by_created', nowait = false },
            ['od'] = { 'order_by_diagnostics', nowait = false },
            ['om'] = { 'order_by_modified', nowait = false },
            ['on'] = { 'order_by_name', nowait = false },
            ['os'] = { 'order_by_size', nowait = false },
            ['ot'] = { 'order_by_type', nowait = false },
          },
        },
      },
      git_status = {
        window = {
          position = 'float',
          mappings = {
            ['A'] = 'git_add_all',
            ['gu'] = 'git_unstage_file',
            ['ga'] = 'git_add_file',
            ['gr'] = 'git_revert_file',
            ['gc'] = 'git_commit',
            ['gp'] = 'git_push',
            ['gg'] = 'git_commit_and_push',
            ['o'] = { 'show_help', nowait = false, config = { title = 'Order by', prefix_key = 'o' } },
            ['oc'] = { 'order_by_created', nowait = false },
            ['od'] = { 'order_by_diagnostics', nowait = false },
            ['om'] = { 'order_by_modified', nowait = false },
            ['on'] = { 'order_by_name', nowait = false },
            ['os'] = { 'order_by_size', nowait = false },
            ['ot'] = { 'order_by_type', nowait = false },
          },
        },
        commands = {
          trash = custom_trash,
          trash_visual = custom_trash_visual,
        },
      },
    }

    vim.keymap.set('n', '\\', ':Neotree reveal<CR>', { noremap = true, silent = true, desc = 'Reveal current file in Neo-tree' })
    vim.keymap.set('n', '<leader>e', ':Neotree toggle position=left<CR>', { noremap = true, silent = true, desc = 'Toggle Neo-tree' }) -- focus file explorer
    vim.keymap.set('n', '<leader>ngs', ':Neotree float git_status<CR>', { noremap = true, silent = true, desc = 'Neo-tree git status' }) -- open git status window

    -- Refresh neo-tree git status on user interaction (not continuous watching)
    local function refresh_neotree_git()
      local ok, manager = pcall(require, "neo-tree.sources.manager")
      if ok then
        manager.refresh("filesystem")
        manager.refresh("git_status")
      end
    end

    -- When you alt-tab back to Neovim (e.g. after committing in terminal)
    vim.api.nvim_create_autocmd("FocusGained", {
      callback = refresh_neotree_git,
    })

    -- When you enter a neo-tree window (click/navigate into the sidebar)
    vim.api.nvim_create_autocmd("BufEnter", {
      pattern = "neo-tree *",
      callback = refresh_neotree_git,
    })

    -- When Neogit finishes an action
    vim.api.nvim_create_autocmd("User", {
      pattern = { "NeogitStatusRefreshed", "NeogitCommitComplete", "NeogitPushComplete" },
      callback = refresh_neotree_git,
    })
  end,
}

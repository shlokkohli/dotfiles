-- Full Git workflow: gutter signs, merge conflicts, and VS Code–style diffs
return {
  -- Gutter signs + blame
  {
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      signs_staged = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      current_line_blame = true, -- show blame info at end of line
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local map = function(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigate hunks
        map('n', ']c', gs.next_hunk, { desc = 'Next Git Hunk' })
        map('n', '[c', gs.prev_hunk, { desc = 'Prev Git Hunk' })
      end,
    },
  },

  -- Merge conflict resolver
  {
    'akinsho/git-conflict.nvim',
    version = '*',
    config = function()
      local ok, git_conflict = pcall(require, 'git-conflict')
      if not ok then
        vim.notify('git-conflict.nvim failed to load', vim.log.levels.ERROR)
        return
      end

      git_conflict.setup {
        default_mappings = false, -- disable built-in keymaps if you want custom ones
        default_commands = true, -- enables :GitConflictChooseOurs etc.
        disable_diagnostics = false,
      }

      -- Custom keybindings for conflict resolution
      vim.keymap.set('n', '<leader>go', ':GitConflictChooseOurs<CR>', { desc = 'Choose ours' })
      vim.keymap.set('n', '<leader>gt', ':GitConflictChooseTheirs<CR>', { desc = 'Choose theirs' })
      vim.keymap.set('n', '<leader>gb', ':GitConflictChooseBoth<CR>', { desc = 'Choose both' })
      vim.keymap.set('n', '<leader>gn', ':GitConflictChooseNone<CR>', { desc = 'Choose none' })
    end,
  },

  -- Main Git interface
  {
    'NeogitOrg/neogit',
    dependencies = {
      'nvim-lua/plenary.nvim', -- required
      'sindrets/diffview.nvim', -- for rich diffs
      'nvim-telescope/telescope.nvim', -- optional, for selecting commits/branches
    },
    config = function()
      local neogit = require 'neogit'
      neogit.setup {
        integrations = {
          diffview = true, -- use diffview for diffs
        },
        kind = 'tab', -- open in a new tab like VS Code's Source Control
        disable_commit_confirmation = true,
      }

      -- Keymaps for Neogit & Diffview
      vim.keymap.set('n', '<leader>gs', function()
        neogit.open { kind = 'tab' }
      end, { desc = 'Open Neogit (tab)' })

      vim.keymap.set('n', '<leader>gd', '<cmd>DiffviewOpen<CR>', { desc = 'Open Diffview' })
      vim.keymap.set('n', '<leader>gD', '<cmd>DiffviewClose<CR>', { desc = 'Close Diffview' })
    end,
  },

  -- Better diff viewing
  {
    'sindrets/diffview.nvim',
    dependencies = 'nvim-lua/plenary.nvim',
    config = function()
      require('diffview').setup {
        enhanced_diff_hl = true, -- better syntax highlighting in diffs
        view = {
          default = {
            layout = 'diff2_horizontal', -- side-by-side
          },
        },
        file_panel = {
          win_config = { position = 'left', width = 35 },
        },
      }
    end,
  },
}

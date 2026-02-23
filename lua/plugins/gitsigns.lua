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
      current_line_blame = true,
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local map = function(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

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

      -- show whitespace changes also
      vim.keymap.set('n', '<leader>gd', function()
        vim.cmd('DiffviewOpen --no-ignore-whitespace')
      end, { desc = 'Open Diffview (show all changes)' })

      vim.keymap.set('n', '<leader>gD', '<cmd>DiffviewClose<CR>', { desc = 'Close Diffview' })
    end,
  },

  -- Better diff viewing
  {
    'sindrets/diffview.nvim',
    dependencies = 'nvim-lua/plenary.nvim',
    config = function()
      require('diffview').setup {
        enhanced_diff_hl = true,
        view = {
          default = {
            layout = 'diff2_horizontal',
          },
        },
        file_panel = {
          win_config = { position = 'left', width = 35 },
        },
      }
    end,
  },
}

return {
  'nvimtools/none-ls.nvim',
  dependencies = {
    'nvimtools/none-ls-extras.nvim',
    'jayp0521/mason-null-ls.nvim',
  },
  config = function()
    local null_ls = require 'null-ls'
    local formatting = null_ls.builtins.formatting
    local diagnostics = null_ls.builtins.diagnostics
    local util = require 'lspconfig.util'

    local function has_eslint_config(dir)
      local config_files = {
        '.eslintrc.js',
        '.eslintrc.cjs',
        '.eslintrc.json',
        '.eslintrc',
      }
      for _, file in ipairs(config_files) do
        if util.path.exists(util.path.join(dir, file)) then
          return true
        end
      end
      return false
    end

    local eslint_root = util.root_pattern('.eslintrc.js', '.eslintrc.cjs', '.eslintrc.json', '.eslintrc')

    local eslint_d = require('none-ls.diagnostics.eslint_d').with {
      cwd = function(params)
        return eslint_root(params.bufname)
      end,
      condition = function(utils)
        local root = eslint_root(utils.bufname)
        return root ~= nil and has_eslint_config(root)
      end,
    }

    require('mason-null-ls').setup {
      ensure_installed = {
        'prettier',
        'stylua',
        'eslint_d',
        'shfmt',
        'checkmake',
        'ruff',
        'clang_format',
      },
      automatic_installation = true,
    }

    local sources = {
      diagnostics.checkmake,
      eslint_d,
      formatting.clang_format.with { filetypes = { 'c', 'cpp' } },
      formatting.prettier.with {
        filetypes = {
          'javascript',
          'typescript',
          'javascriptreact',
          'typescriptreact',
          'json',
          'yaml',
          'markdown',
          'html',
        },
        extra_args = { '--plugin', 'prettier-plugin-organize-imports' },
      },
      formatting.stylua,
      formatting.shfmt.with { args = { '-i', '4' } },
      formatting.terraform_fmt,
      require('none-ls.formatting.ruff').with { extra_args = { '--extend-select', 'I' } },
      require 'none-ls.formatting.ruff_format',
    }

    null_ls.setup {
      sources = sources,
      on_attach = function(client, bufnr)
        if client.name == 'null-ls' and (vim.bo[bufnr].filetype == 'c' or vim.bo[bufnr].filetype == 'cpp') then
          client.server_capabilities.definitionProvider = false
          client.server_capabilities.hoverProvider = false
          client.server_capabilities.referencesProvider = false
          client.server_capabilities.renameProvider = false
        end
      end,
    }
  end,
}

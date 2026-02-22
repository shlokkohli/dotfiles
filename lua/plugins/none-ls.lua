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

    -- function to check if a folder has an eslint config file
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

    -- root finder for eslint (only looking for actual config files)
    local eslint_root = util.root_pattern('.eslintrc.js', '.eslintrc.cjs', '.eslintrc.json', '.eslintrc')

    -- eslint_d config with cwd + skip when no config
    local eslint_d = require('none-ls.diagnostics.eslint_d').with {
      cwd = function(params)
        return eslint_root(params.bufname)
      end,
      condition = function(utils)
        local root = eslint_root(utils.bufname)
        return root ~= nil and has_eslint_config(root)
      end,
    }

    -- Install formatters & linters via Mason
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
      -- LINTERS
      diagnostics.checkmake,
      eslint_d,
      formatting.clang_format.with {
        filetypes = { 'c', 'cpp' },
      },
      -- FORMATTERS
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

    local augroup = vim.api.nvim_create_augroup('LspFormatting', {})

    null_ls.setup {
      sources = sources,
      on_attach = function(client, bufnr)
        if client.name == 'null-ls' and (vim.bo[bufnr].filetype == 'c' or vim.bo[bufnr].filetype == 'cpp') then
          client.server_capabilities.definitionProvider = false -- don't override clangd
          client.server_capabilities.hoverProvider = false
          client.server_capabilities.referencesProvider = false
          client.server_capabilities.renameProvider = false
        end
        if client.supports_method 'textDocument/formatting' then
          vim.api.nvim_clear_autocmds { group = augroup, buffer = bufnr }
          vim.api.nvim_create_autocmd('BufWritePre', {
            group = augroup,
            buffer = bufnr,
            callback = function()
              vim.lsp.buf.format { async = false }
            end,
          })
        end

        -- Optional: run diagnostics again on save
        if client.supports_method 'textDocument/diagnostic' then
          vim.api.nvim_create_autocmd('BufWritePost', {
            group = augroup,
            buffer = bufnr,
            callback = function()
              require('none-ls').try_lsp_diagnostic(bufnr)
            end,
          })
        end
      end,
    }
  end,
}

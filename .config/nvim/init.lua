local orig = vim.deprecate
vim.deprecate = function(name, alternative, version, plugin, backtrace)
  if name and name:match 'sign_define' then
    return
  end
  return orig(name, alternative, version, plugin, backtrace)
end

require 'core.options' -- Load general options
require 'core.keymaps' -- Load general keymaps
require 'core.snippets' -- Custom code snippets

-- Set up the Lazy plugin manager
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Set up plugins
require('lazy').setup {
  require 'plugins.neotree',
  require 'plugins.colortheme',
  require 'plugins.visual-multi',
  require 'plugins.barbar',
  require 'plugins.lualine',
  require 'plugins.treesitter',
  require 'plugins.surround',
  require 'plugins.spectre',
  require 'plugins.telescope',
  require 'plugins.flash',
  require 'plugins.lsp',
  require 'plugins.autocompletion',
  require 'plugins.conform',
  require 'plugins.gitsigns',
  require 'plugins.indent-blankline',
  require 'plugins.misc',
  require 'plugins.comment',
  require 'plugins.tailwind',
  require 'plugins.tailwind-tools',
  require 'plugins.scrollbar',
  require 'plugins.autotag',
}

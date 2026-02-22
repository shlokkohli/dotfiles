return {
  'romgrk/barbar.nvim',
  dependencies = {
    'lewis6991/gitsigns.nvim', -- optional
    'nvim-tree/nvim-web-devicons', -- optional
  },
  init = function()
    vim.g.barbar_auto_setup = false -- disable auto setup
  end,
  opts = {
    animation = true,
  },
}

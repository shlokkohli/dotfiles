return {
  'lukas-reineke/indent-blankline.nvim',
  main = 'ibl',
  opts = {
    debounce = 100, -- reduce redraw frequency
    indent = {
      char = '▏',
    },
    scope = {
      enabled = false, -- disable scope highlighting (major perf gain)
      show_start = false,
      show_end = false,
      show_exact_scope = false,
    },
    exclude = {
      filetypes = {
        'help',
        'startify',
        'dashboard',
        'packer',
        'neogitstatus',
        'NvimTree',
        'Trouble',
      },
    },
  },
}

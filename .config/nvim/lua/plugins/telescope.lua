return {
  'nvim-telescope/telescope.nvim',
  cmd = 'Telescope',
  keys = {
    { '<leader>sk', mode = { 'n', 'x' } },
    { '<leader>sf', mode = { 'n', 'x' } },
    { '<leader>ss', mode = { 'n', 'x' } },
    { '<leader>sc', mode = { 'n', 'x' } },
    { '<leader>sg', mode = { 'n', 'x' } },
    { '<leader>sG', mode = { 'n', 'x' } },
    { '<leader>sd', mode = { 'n', 'x' } },
    { '<leader>sb', mode = { 'n', 'x' } },
    { '<leader>s.', mode = { 'n', 'x' } },
    { '<leader>sr', mode = { 'n', 'x' } },
    { '<leader><leader>', mode = { 'n', 'x' } },
    { '<leader>/', mode = { 'n', 'x' } },
    { '<leader>s/', mode = { 'n', 'x' } },
  },
  -- We removed the '0.1.x' branch to ensure you get the latest fixes for Neovim 0.10+
  dependencies = {
    'nvim-lua/plenary.nvim',
    {
      'nvim-telescope/telescope-fzf-native.nvim',
      build = 'make',
      cond = function()
        return vim.fn.executable 'make' == 1
      end,
    },
    { 'nvim-telescope/telescope-ui-select.nvim' },
    { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
  },
  config = function()
    local Path = require 'plenary.path'
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'
    local conf = require('telescope.config').values
    local finders = require 'telescope.finders'
    local from_entry = require 'telescope.from_entry'
    local make_entry = require 'telescope.make_entry'
    local pickers = require 'telescope.pickers'
    local previewers = require 'telescope.previewers'
    local sorters = require 'telescope.sorters'
    local utils = require 'telescope.utils'
    local search_config = require 'config.search'

    local telescope_toggle_keys = {
      '<leader>sk',
      '<leader>sf',
      '<leader>ss',
      '<leader>sc',
      '<leader>sg',
      '<leader>sG',
      '<leader>sd',
      '<leader>sr',
      '<leader>s.',
      '<leader>sb',
      '<leader>/',
      '<leader>s/',
    }

    local active_telescope_key = nil
    local telescope_launchers = {}

    local telescope_close_mappings = {
      ['<leader>/'] = actions.close,
      ['<leader><leader>'] = actions.close,
    }

    for _, key in ipairs(telescope_toggle_keys) do
      telescope_close_mappings[key] = function(prompt_bufnr)
        if active_telescope_key == key then
          actions.close(prompt_bufnr)
          return
        end

        actions.close(prompt_bufnr)
        vim.schedule(function()
          local launcher = telescope_launchers[key]
          if launcher then
            launcher()
          end
        end)
      end
    end

    local function with_telescope_close_mappings(mappings)
      return vim.tbl_extend('force', telescope_close_mappings, mappings)
    end

    local function clear_prompt(prompt_bufnr)
      action_state.get_current_picker(prompt_bufnr):set_prompt ''
    end

    local function open_telescope(key, open_picker)
      active_telescope_key = key
      open_picker()
    end

    local function toggle_telescope(key, open_picker)
      telescope_launchers[key] = function()
        open_telescope(key, open_picker)
      end

      return function()
        if vim.bo.filetype == 'TelescopePrompt' and active_telescope_key == key then
          actions.close(vim.api.nvim_get_current_buf())
          return
        end

        open_telescope(key, open_picker)
      end
    end

    local function grep_preview_query(opts, status)
      if status and status.picker and status.picker._get_prompt then
        local prompt = status.picker:_get_prompt()
        if prompt and prompt ~= '' then
          return prompt
        end
      end

      if type(opts.search) == 'string' and opts.search ~= '' then
        return opts.search
      end

      if type(opts.default_text) == 'string' and opts.default_text ~= '' then
        return opts.default_text
      end
    end

    local function grep_preview_pattern(query)
      if not query or query == '' then
        return nil
      end

      query = query:gsub('\\n', '\n')

      local case_prefix = ''
      if vim.o.ignorecase then
        case_prefix = (vim.o.smartcase and query:find('%u')) and '\\C' or '\\c'
      end

      return case_prefix .. '\\V' .. query:gsub('\\', '\\\\'):gsub('\n', '\\n')
    end

    local function literal_grep_previewer(opts)
      opts = opts or {}
      local cwd = opts.cwd or vim.uv.cwd()

      local function configure_preview_window(winid)
        if not winid or not vim.api.nvim_win_is_valid(winid) then
          return
        end

        vim.wo[winid].cursorline = true
        vim.wo[winid].cursorlineopt = 'number'
        vim.wo[winid].number = true
        vim.wo[winid].relativenumber = true
        vim.wo[winid].numberwidth = vim.o.numberwidth
      end

      local function clear_match(self)
        if self.state and self.state.hl_id then
          pcall(vim.fn.matchdelete, self.state.hl_id, self.state.winid)
          self.state.hl_id = nil
        end
      end

      local function jump_to_match(self, bufnr, entry, status)
        clear_match(self)
        configure_preview_window(self.state and self.state.winid)

        if entry.lnum and entry.lnum > 0 and self.state.winid and vim.api.nvim_win_is_valid(self.state.winid) then
          local col = math.max(0, (entry.col or 1) - 1)
          pcall(vim.api.nvim_win_set_cursor, self.state.winid, { entry.lnum, col })
          vim.api.nvim_buf_call(bufnr, function()
            vim.cmd 'norm! zz'
          end)
        end

        local pattern = grep_preview_pattern(grep_preview_query(opts, status))
        if not pattern then
          return
        end

        vim.api.nvim_buf_call(bufnr, function()
          self.state.hl_id = vim.fn.matchadd('TelescopePreviewMatch', pattern)
        end)
      end

      return previewers.new_buffer_previewer {
        title = 'Grep Preview',
        dyn_title = function(_, entry)
          return Path:new(from_entry.path(entry, false, false)):normalize(cwd)
        end,
        teardown = function(self)
          clear_match(self)
        end,
        get_buffer_by_name = function(_, entry)
          return from_entry.path(entry, false, false)
        end,
        define_preview = function(self, entry, status)
          local has_buftype = entry.bufnr
            and vim.api.nvim_buf_is_valid(entry.bufnr)
            and vim.bo[entry.bufnr].buftype ~= ''
            or false
          local path

          if not has_buftype then
            path = from_entry.path(entry, true, false)
            if path == nil or path == '' then
              return
            end
          end

          if entry.bufnr and (path == '[No Name]' or has_buftype) then
            local lines = vim.api.nvim_buf_get_lines(entry.bufnr, 0, -1, false)
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
            vim.schedule(function()
              if vim.api.nvim_buf_is_valid(self.state.bufnr) then
                jump_to_match(self, self.state.bufnr, entry, status)
              end
            end)
            return
          end

          conf.buffer_previewer_maker(path, self.state.bufnr, {
            bufname = self.state.bufname,
            winid = self.state.winid,
            preview = opts.preview,
            callback = function(bufnr)
              jump_to_match(self, bufnr, entry, status)
            end,
            file_encoding = opts.file_encoding,
          })
        end,
      }
    end

    local function current_buffer_literal_find(default_text, full_size)
      local literal_line_number_sorter = sorters.Sorter:new {
        discard = true,
        scoring_function = function(_, prompt, _, entry)
          if prompt == '' then
            return entry.lnum or 1
          end

          local needle = prompt
          local haystack = entry.ordinal or ''
          if vim.o.ignorecase and not (vim.o.smartcase and prompt:find '%u') then
            needle = prompt:lower()
            haystack = haystack:lower()
          end

          local match_start = haystack:find(needle, 1, true)
          if not match_start then
            return -1
          end

          return entry.lnum or 1
        end,
        highlighter = function(_, prompt, display)
          if prompt == '' then
            return {}
          end

          local needle = prompt
          local haystack = display
          if vim.o.ignorecase and not (vim.o.smartcase and prompt:find '%u') then
            needle = prompt:lower()
            haystack = display:lower()
          end

          local match_start = haystack:find(needle, 1, true)
          if not match_start then
            return {}
          end

          return {
            {
              start = match_start,
              finish = match_start + #prompt - 1,
            },
          }
        end,
      }

      local bufnr = vim.api.nvim_get_current_buf()
      local filename = vim.api.nvim_buf_get_name(bufnr)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local lines_with_numbers = {}

      for lnum, line in ipairs(lines) do
        table.insert(lines_with_numbers, {
          lnum = lnum,
          bufnr = bufnr,
          filename = filename,
          text = line,
        })
      end

      local picker_opts = {
        default_text = default_text and default_text ~= '' and default_text or nil,
        prompt_title = 'Current Buffer Search',
      }

      if full_size then
        picker_opts.previewer = literal_grep_previewer {
          default_text = default_text,
        }
      else
        picker_opts = require('telescope.themes').get_dropdown(vim.tbl_extend('force', picker_opts, {
          winblend = 10,
          previewer = false,
        }))
      end

      pickers
        .new(picker_opts, {
          finder = finders.new_table {
            results = lines_with_numbers,
            entry_maker = make_entry.gen_from_buffer_lines(picker_opts),
          },
          sorter = literal_line_number_sorter,
          attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
              local selection = action_state.get_selected_entry()
              if not selection then
                return
              end

              local prompt = action_state.get_current_line()
              local line = selection.text or ''
              local needle = prompt
              local haystack = line

              if vim.o.ignorecase and not (vim.o.smartcase and prompt:find '%u') then
                needle = prompt:lower()
                haystack = line:lower()
              end

              local col = 0
              local match_start = haystack:find(needle, 1, true)
              if match_start then
                col = match_start - 1
              end

              actions.close(prompt_bufnr)
              vim.schedule(function()
                vim.cmd "normal! m'"
                vim.api.nvim_win_set_cursor(0, { selection.lnum, col })
              end)
            end)

            return true
          end,
        })
        :find()
    end

    local vimgrep_arguments = {
      'rg',
      '--color=never',
      '--no-heading',
      '--with-filename',
      '--line-number',
      '--column',
      '--ignore-case',
      '--fixed-strings',
    }
    vim.list_extend(vimgrep_arguments, search_config.default_vimgrep_globs())

    require('telescope').setup {
      defaults = {
        grep_previewer = literal_grep_previewer,
        layout_strategy = 'horizontal',
        layout_config = {
          horizontal = {
            preview_width = 0.55,
          },
        },
        -- VS Code-style literal search: override rg defaults to include --fixed-strings
        -- so dots, brackets, etc. are matched literally and trailing spaces matter.
        vimgrep_arguments = vimgrep_arguments,
        preview = {
          treesitter = false,
          wrap = true,  -- wrap long lines so matches at end of line are visible
        },
        mappings = {
          i = with_telescope_close_mappings {
            ['<C-/>'] = false,
            ['<C-_>'] = false,
            -- Ghostty sends Cmd-Backspace as <C-u>; clear pasted prompts in insert mode.
            ['<C-u>'] = clear_prompt,
            ['<C-d>'] = actions.preview_scrolling_down,
            ['<C-k>'] = require('telescope.actions').move_selection_previous, -- move to prev result
            ['<C-j>'] = require('telescope.actions').move_selection_next, -- move to next result
            ['<D-BS>'] = clear_prompt,
            ['\x1b[127;9u'] = clear_prompt,
            -- Custom select: re-applies cursor AFTER neo-tree/barbar BufEnter callbacks settle
            ['<CR>'] = function(prompt_bufnr)
              local entry = require('telescope.actions.state').get_selected_entry()
              require('telescope.actions').select_default(prompt_bufnr)
              if entry and entry.lnum then
                vim.schedule(function()
                  pcall(vim.api.nvim_win_set_cursor, 0, { entry.lnum, math.max(0, (entry.col or 1) - 1) })
                end)
              end
            end,
            ['<C-l>'] = function(prompt_bufnr)
              local entry = require('telescope.actions.state').get_selected_entry()
              require('telescope.actions').select_default(prompt_bufnr)
              if entry and entry.lnum then
                vim.schedule(function()
                  pcall(vim.api.nvim_win_set_cursor, 0, { entry.lnum, math.max(0, (entry.col or 1) - 1) })
                end)
              end
            end,
            -- Paste multi-line clipboard into single-line prompt.
            -- Joins lines with \\n so ripgrep --multiline can match across lines.
            ['<C-v>'] = function(prompt_bufnr)
              local clipboard = vim.fn.getreg '+'
              if not clipboard or clipboard == '' then
                return
              end
              -- Strip trailing newline and collapse into one line
              clipboard = clipboard:gsub('[\r\n]+$', '')
              local lines = vim.split(clipboard, '\n', { plain = true })
              local text
              if #lines > 1 then
                -- Join with literal \n for display; the search itself will use
                -- grep_string --multiline when triggered from live_grep_smart
                text = table.concat(lines, '\\n')
              else
                text = lines[1]
              end
              local action_state = require 'telescope.actions.state'
              local picker = action_state.get_current_picker(prompt_bufnr)
              picker:set_prompt(text)
            end,
          },
          n = with_telescope_close_mappings {
            ['?'] = false,
            ['<C-u>'] = actions.preview_scrolling_up,
            ['<C-d>'] = actions.preview_scrolling_down,
            -- Also fix <CR> in Telescope's normal mode
            ['<CR>'] = function(prompt_bufnr)
              local entry = require('telescope.actions.state').get_selected_entry()
              require('telescope.actions').select_default(prompt_bufnr)
              if entry and entry.lnum then
                vim.schedule(function()
                  pcall(vim.api.nvim_win_set_cursor, 0, { entry.lnum, math.max(0, (entry.col or 1) - 1) })
                end)
              end
            end,
          },
        },
      },
      pickers = {
        find_files = {
          find_command = search_config.find_command(),
        },
        live_grep = {
          file_ignore_patterns = search_config.picker_ignore_patterns(),
          additional_args = function(_)
            return { '--hidden' }
          end,
        },
      },
      extensions = {
        fzf = {
          fuzzy = false,  -- exact substring matching instead of fuzzy
        },
        ['ui-select'] = {
          require('telescope.themes').get_dropdown(),
        },
      },
    }

    -- Enable Telescope extensions if they are installed
    pcall(require('telescope').load_extension, 'fzf')
    pcall(require('telescope').load_extension, 'ui-select')

    -- See `:help telescope.builtin`
    local builtin = require 'telescope.builtin'

    local function search_current_word_in_buffer()
      local word = vim.fn.expand '<cword>'

      current_buffer_literal_find(word, true)
    end

    local function hidden_grep_args_without_exact_env()
      return {
        '--hidden',
        '--glob', '!.env',
        '--glob', '!**/.env',
        '--glob', '!**/.git/**',
      }
    end

    local function literal_grep(search, opts)
      if not search or search == '' then
        return
      end

      local additional_args = { '--hidden' }
      vim.list_extend(additional_args, search_config.literal_grep_globs())

      if opts and opts.multiline then
        table.insert(additional_args, 2, '--multiline')
      end

      builtin.grep_string {
        prompt_title = opts and opts.prompt_title or 'Grep literal',
        search = search,
        use_regex = true,
        additional_args = additional_args,
        search_dirs = opts and opts.search_dirs or nil,
      }
    end

    local function search_text_from_prompt(prompt)
      if not prompt or prompt == '' then
        return nil
      end

      return prompt:gsub('\\n', '\n')
    end

    local function multiline_prompt_text(text)
      text = text and text:gsub('[\r\n]+$', '') or ''
      if text == '' then
        return ''
      end

      return table.concat(vim.split(text, '\n', { plain = true }), '\\n')
    end

    local function paste_multiline_search(prompt_bufnr)
      local clipboard = vim.fn.getreg '+'
      if not clipboard or clipboard == '' then
        return
      end

      local picker = action_state.get_current_picker(prompt_bufnr)
      picker:set_prompt(multiline_prompt_text(clipboard))
    end

    local function install_multiline_paste_handler(prompt_bufnr)
      local original_paste = vim.paste
      local paste_chunks = {}

      local paste_handler
      paste_handler = function(lines, phase)
        if vim.api.nvim_get_current_buf() ~= prompt_bufnr then
          return original_paste(lines, phase)
        end

        local text = table.concat(lines, '\n')
        if phase == 1 then
          paste_chunks = { text }
          return true
        end

        if phase == 2 then
          table.insert(paste_chunks, text)
          return true
        end

        if phase == 3 then
          table.insert(paste_chunks, text)
          text = table.concat(paste_chunks)
          paste_chunks = {}
        end

        if not text:find('\n', 1, true) then
          return original_paste({ text }, -1)
        end

        local picker = action_state.get_current_picker(prompt_bufnr)
        local prompt = picker:_get_prompt()
        picker:set_prompt(prompt .. multiline_prompt_text(text))
        return true
      end
      vim.paste = paste_handler

      vim.api.nvim_create_autocmd({ 'BufWipeout', 'BufDelete' }, {
        buffer = prompt_bufnr,
        once = true,
        callback = function()
          if vim.paste == paste_handler then
            vim.paste = original_paste
          end
        end,
      })
    end

    local function live_grep_multiline(opts)
      opts = opts or {}
      opts.cwd = opts.cwd or vim.uv.cwd()

      local function make_json_grep_entry(line)
        local ok, item = pcall(vim.json.decode, line)
        if not ok or not item or item.type ~= 'match' then
          return nil
        end

        local data = item.data or {}
        local path = data.path and data.path.text
        if not path then
          return nil
        end

        local text = data.lines and data.lines.text or ''
        text = text:gsub('[\r\n]+$', '')
        local display_text = text:gsub('\n', '\\n')
        local submatch = data.submatches and data.submatches[1]
        local col = submatch and submatch.start and submatch.start + 1 or 1
        local absolute_path = Path:new(path):is_absolute() and path or Path:new({ opts.cwd, path }):absolute()

        return make_entry.set_default_entry_mt({
          value = line,
          ordinal = path .. ':' .. display_text,
          display = function(entry)
            local display_filename, path_style = utils.transform_path(opts, entry.display_filename)
            local display, hl_group, icon = utils.transform_devicons(
              entry.display_filename,
              string.format('%s:%s:%s:%s', display_filename, entry.lnum, entry.col, entry.text),
              opts.disable_devicons
            )

            if hl_group then
              local style = { { { 0, #icon }, hl_group } }
              style = utils.merge_styles(style, path_style, #icon + 1)
              return display, style
            end

            return display, path_style
          end,
          display_filename = path,
          filename = absolute_path,
          path = absolute_path,
          lnum = data.line_number,
          col = col,
          text = display_text,
        })
      end

      local vimgrep_arguments = opts.vimgrep_arguments or conf.vimgrep_arguments
      local base_args = vim.deepcopy(vimgrep_arguments)
      table.insert(base_args, '--hidden')
      vim.list_extend(base_args, search_config.multiline_grep_globs())

      local case_sensitive = false

      local title_prefix = opts.prompt_title and (opts.prompt_title .. ' ') or ''
      local function case_mode_title()
        return title_prefix .. (case_sensitive and '[Case Sensitive]' or '[Case Insensitive]')
      end

      opts.__inverted = false
      opts.__matches = false

      local function make_live_grepper()
        return finders.new_job(function(prompt)
          local search = search_text_from_prompt(prompt)
          if not search then
            return nil
          end

          local args = vim.deepcopy(base_args)
          -- Put the selected case flag after the defaults so it overrides the
          -- global --ignore-case setting when case-sensitive mode is enabled.
          table.insert(args, case_sensitive and '--case-sensitive' or '--ignore-case')
          if search:find('\n', 1, true) then
            table.insert(args, 2, '--multiline')
          end
          table.insert(args, 2, '--json')

          vim.list_extend(args, { '--', search })
          -- Restrict to diff files when search_dirs is set
          if opts.search_dirs and #opts.search_dirs > 0 then
            vim.list_extend(args, opts.search_dirs)
          end
          return args
        end, opts.entry_maker or make_json_grep_entry, opts.max_results, opts.cwd)
      end

      local live_grepper = make_live_grepper()

      pickers
        .new(opts, {
          prompt_title = case_mode_title(),
          finder = live_grepper,
          previewer = conf.grep_previewer(opts),
          sorter = sorters.highlighter_only(opts),
          attach_mappings = function(prompt_bufnr, map)
            install_multiline_paste_handler(prompt_bufnr)

            local function toggle_case_sensitivity()
              case_sensitive = not case_sensitive
              local picker = action_state.get_current_picker(prompt_bufnr)
              picker.prompt_border:change_title(case_mode_title())
              live_grepper = make_live_grepper()
              picker:refresh(live_grepper, { reset_prompt = false })
            end

            map('i', '<M-c>', toggle_case_sensitivity)
            map('n', '<M-c>', toggle_case_sensitivity)
            -- macOS terminals may send the literal character ç for Option+C
            -- instead of an Alt/Meta key sequence.
            map('i', 'ç', toggle_case_sensitivity)
            map('n', 'ç', toggle_case_sensitivity)
            map('i', '<C-space>', actions.to_fuzzy_refine)
            map('i', '<C-v>', paste_multiline_search)
            map('i', '<D-v>', paste_multiline_search)
            map('i', '<C-r>+', paste_multiline_search)
            map('i', '<C-r>*', paste_multiline_search)
            return true
          end,
          push_cursor_on_edit = true,
        })
        :find()
    end

    local function get_visual_selection()
      local save_v = vim.fn.getreg 'v'
      vim.cmd [[noautocmd sil norm! "vy]]
      local text = vim.fn.getreg 'v'
      vim.fn.setreg('v', save_v)
      return text
    end

    -- Telescope prompts are single-line, so show pasted newlines as \n while
    -- sending real newlines to ripgrep with --multiline.
    -- Returns true when a diffview tab is currently open
    local function is_in_diffview()
      local ok, lib = pcall(require, 'diffview.lib')
      return ok and lib.get_current_view() ~= nil
    end

    -- Returns a list of absolute file paths that are part of the current diff
    -- (modified, staged, and untracked files relative to the git root).
    local function get_diffview_changed_files()
      local root = vim.fn.systemlist({ 'git', 'rev-parse', '--show-toplevel' })
      if vim.v.shell_error ~= 0 or #root == 0 then
        return nil
      end
      local git_root = root[1]

      -- staged + unstaged changes
      local changed = vim.fn.systemlist({ 'git', 'diff', '--name-only', 'HEAD' })
      -- untracked files
      local untracked = vim.fn.systemlist({ 'git', 'ls-files', '--others', '--exclude-standard' })

      local seen = {}
      local files = {}
      for _, rel in ipairs(vim.list_extend(changed, untracked)) do
        local abs = git_root .. '/' .. rel
        if not seen[abs] then
          seen[abs] = true
          table.insert(files, abs)
        end
      end
      return #files > 0 and files or nil
    end

    local function live_grep_smart()
      local mode = vim.fn.mode()

      -- Scope to diff files when diffview is active
      local diff_files = is_in_diffview() and get_diffview_changed_files() or nil
      local extra_opts = diff_files and {
        search_dirs = diff_files,
        prompt_title = 'Grep (Diff Files)',
      } or {}

      if mode == 'v' or mode == 'V' or mode == '\22' then
        -- Visual mode: grab the selection
        local text = get_visual_selection()
        local trimmed = text and text:gsub('[\r\n]+$', '') or ''
        local lines = vim.fn.split(trimmed, '\n', true)

        if #lines > 1 and trimmed ~= '' then
          live_grep_multiline(vim.tbl_extend('force', extra_opts, {
            default_text = multiline_prompt_text(trimmed),
          }))
        else
          live_grep_multiline(vim.tbl_extend('force', extra_opts, {
            default_text = trimmed ~= '' and multiline_prompt_text(trimmed) or nil,
          }))
        end
      else
        live_grep_multiline(extra_opts)
      end
    end

    local function search_by_literal_grep()
      local mode = vim.fn.mode()

      -- Scope to diff files when diffview is active
      local diff_files = is_in_diffview() and get_diffview_changed_files() or nil

      local function do_literal_grep(query, opts)
        opts = opts or {}
        if diff_files then
          opts.search_dirs = diff_files
          opts.prompt_title = (opts.prompt_title or 'Grep literal') .. ' (Diff Files)'
        end
        literal_grep(query, opts)
      end

      if mode == 'v' or mode == 'V' or mode == '\22' then
        local text = get_visual_selection()
        local selected = text and text:gsub('[\r\n]+$', '') or ''
        local lines = vim.fn.split(selected, '\n', true)

        do_literal_grep(selected, {
          prompt_title = #lines > 1 and 'Grep multiline' or 'Grep literal',
          multiline = #lines > 1,
        })
        return
      end

      local query = vim.fn.input 'Grep literal > '
      do_literal_grep(query, { prompt_title = 'Grep literal' })
    end

    local function current_buffer_diagnostics()
      local bufnr = vim.api.nvim_get_current_buf()
      local opts = {
        bufnr = 0,
        path_display = 'hidden',
      }

      if not vim.tbl_isempty(vim.diagnostic.get(bufnr)) then
        builtin.diagnostics(opts)
        return
      end

      pickers
        .new(opts, {
          prompt_title = 'Document Diagnostics',
          finder = finders.new_table {
            results = {},
            entry_maker = make_entry.gen_from_diagnostics(opts),
          },
          previewer = conf.qflist_previewer(opts),
          sorter = conf.prefilter_sorter {
            tag = 'type',
            sorter = conf.generic_sorter(opts),
          },
        })
        :find()
    end

    local telescope_modes = { 'n', 'x' }
    vim.keymap.set(telescope_modes, '<leader>sk', toggle_telescope('<leader>sk', builtin.keymaps), { desc = '[S]earch [K]eymaps' })
    vim.keymap.set(telescope_modes, '<leader>sf', toggle_telescope('<leader>sf', function()
      local diff_files = is_in_diffview() and get_diffview_changed_files() or nil
      if diff_files then
        -- Build a minimal picker listing exactly the diff files
        pickers
          .new({}, {
            prompt_title = 'Find Files (Diff)',
            finder = finders.new_table {
              results = diff_files,
              entry_maker = make_entry.gen_from_file {},
            },
            previewer = conf.file_previewer {},
            sorter = conf.file_sorter {},
          })
          :find()
      else
        builtin.find_files()
      end
    end), { desc = '[S]earch [F]iles' })
    vim.keymap.set(telescope_modes, '<leader>ss', toggle_telescope('<leader>ss', builtin.builtin), { desc = '[S]earch [S]elect Telescope' })
    vim.keymap.set(telescope_modes, '<leader>sc', toggle_telescope('<leader>sc', function()
      builtin.grep_string {
        search = vim.fn.expand '<cword>',
        additional_args = hidden_grep_args_without_exact_env,
      } -- uses global default preview_width = 0.55
    end), { desc = '[S]earch [C]urrent word' })
    vim.keymap.set({ 'n', 'x' }, '<leader>sg', toggle_telescope('<leader>sg', live_grep_smart), { desc = '[S]earch by [G]rep' })
    vim.keymap.set({ 'n', 'x' }, '<leader>sG', toggle_telescope('<leader>sG', search_by_literal_grep), { desc = '[S]earch by literal [G]rep' })
    vim.keymap.set(telescope_modes, '<leader>sd', toggle_telescope('<leader>sd', current_buffer_diagnostics), { desc = '[S]earch [D]iagnostics' })
    vim.keymap.set(telescope_modes, '<leader>sb', toggle_telescope('<leader>sb', builtin.resume), { desc = '[S]earch Resume' })
    vim.keymap.set(telescope_modes, '<leader>s.', toggle_telescope('<leader>s.', builtin.oldfiles), { desc = '[S]earch Recent Files' })
    vim.keymap.set(telescope_modes, '<leader>sr', toggle_telescope('<leader>sr', builtin.buffers), { desc = '[S]earch Buffe[R]s' })
    vim.keymap.set(telescope_modes, '<leader><leader>', toggle_telescope('<leader><leader>', search_current_word_in_buffer), { desc = 'Search current word in buffer' })

    -- Slightly advanced example of overriding default behavior and theme
    vim.keymap.set(telescope_modes, '<leader>/', toggle_telescope('<leader>/', function()
      current_buffer_literal_find()
    end), { desc = '[/] Search in current buffer' })

    -- Search specifically in files currently open in buffers
    -- (falls back to diff files when diffview is active)
    vim.keymap.set(telescope_modes, '<leader>s/', toggle_telescope('<leader>s/', function()
      if is_in_diffview() then
        local diff_files = get_diffview_changed_files()
        if diff_files then
          builtin.live_grep {
            search_dirs = diff_files,
            prompt_title = 'Live Grep in Diff Files',
          }
          return
        end
      end
      builtin.live_grep {
        grep_open_files = true,
        prompt_title = 'Live Grep in Open Files',
      }
    end), { desc = '[S]earch [/] in Open Files' })
  end,
}

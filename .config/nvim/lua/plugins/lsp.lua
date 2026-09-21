return {
  -- Main LSP Configuration
  'neovim/nvim-lspconfig',
  dependencies = {
    -- Automatically install LSPs and related tools to stdpath for Neovim
    { 'williamboman/mason.nvim', config = true }, -- NOTE: Must be loaded before dependants
    'williamboman/mason-lspconfig.nvim',
    'WhoIsSethDaniel/mason-tool-installer.nvim',


    -- Allows extra capabilities provided by nvim-cmp
    'hrsh7th/cmp-nvim-lsp',
  },
  config = function()
    -- Brief aside: **What is LSP?**
    --
    -- LSP is an initialism you've probably heard, but might not understand what it is.
    --
    -- LSP stands for Language Server Protocol. It's a protocol that helps editors
    -- and language tooling communicate in a standardized fashion.
    --
    -- In general, you have a "server" which is some tool built to understand a particular
    -- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
    -- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
    -- processes that communicate with some "client" - in this case, Neovim!
    --
    -- LSP provides Neovim with features like:
    --  - Go to definition
    --  - Find references
    --  - Autocompletion
    --  - Symbol Search
    --  - and more!
    --
    -- Thus, Language Servers are external tools that must be installed separately from
    -- Neovim. This is where `mason` and related plugins come into play.
    --
    -- If you're wondering about lsp vs treesitter, you can check out the wonderfully
    -- and elegantly composed help section, `:help lsp-vs-treesitter`

    -- disable LSP logging to avoid performance and freeze issues
    vim.lsp.log.set_level(vim.log.levels.OFF)

    -- Toggle context float: second K closes the float.
    -- Prefer diagnostics at the cursor (like VS Code hover on squiggles),
    -- then fall back to normal LSP hover documentation.
    local info_winid = nil
    local function close_lsp_float()
      local bufnr = vim.api.nvim_get_current_buf()

      if info_winid and vim.api.nvim_win_is_valid(info_winid) then
        vim.api.nvim_win_close(info_winid, true)
        info_winid = nil
        return true
      end

      local existing_float = vim.b[bufnr].lsp_floating_preview
      if existing_float and vim.api.nvim_win_is_valid(existing_float) then
        vim.api.nvim_win_close(existing_float, true)
        info_winid = nil
        return true
      end

      for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(winid) then
          local ok, preview_bufnr = pcall(vim.api.nvim_win_get_var, winid, 'lsp_floating_bufnr')
          if ok and preview_bufnr == bufnr then
            vim.api.nvim_win_close(winid, true)
            info_winid = nil
            return true
          end
        end
      end

      info_winid = nil
      return false
    end

    local function toggle_lsp_hover()
      if close_lsp_float() then
        return
      end

      local cursor = vim.api.nvim_win_get_cursor(0)
      local line = cursor[1] - 1
      local line_diags = vim.diagnostic.get(0, { lnum = line })
      local has_line_diag = #line_diags > 0

      if has_line_diag then
        local _, winid = vim.diagnostic.open_float(0, {
          scope = 'line',
          focus = false,
          max_width = 80,
          wrap = true,
          border = 'rounded',
          source = 'always',
        })
        if winid and vim.api.nvim_win_is_valid(winid) then
          info_winid = winid
        end
        return
      end

      vim.lsp.buf.hover {
        focus = false,
        max_width = 80,
        max_height = 20,
        wrap = true,
      }
    end

    -- When you <C-w>w into the hover float, pressing <C-w>w again closes it
    -- and returns focus to the exact code window you came from.
    vim.api.nvim_create_autocmd('WinEnter', {
      group = vim.api.nvim_create_augroup('lsp-hover-float-nav', { clear = true }),
      callback = function()
        local winid = vim.api.nvim_get_current_win()
        local cfg = vim.api.nvim_win_get_config(winid)
        if cfg.relative ~= '' then
          -- Capture the window we came from *right now*, before we settle into the float.
          -- winnr('#') is Vim's "previous window" number at the moment WinEnter fires.
          local prev_win = vim.fn.win_getid(vim.fn.winnr '#')
          local function close_and_return()
            vim.api.nvim_win_close(winid, true)
            info_winid = nil
            -- Explicitly jump back instead of letting Neovim cycle to the next window.
            if prev_win and prev_win ~= 0 and vim.api.nvim_win_is_valid(prev_win) then
              vim.api.nvim_set_current_win(prev_win)
            end
          end
          vim.keymap.set('n', '<Esc>', close_and_return, { buffer = true, desc = 'Close hover float and return to code' })
        end
      end,
    })

    --  This function gets run when an LSP attaches to a particular buffer.
    --    That is to say, every time a new file is opened that is associated with
    --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
    --    function will be executed to configure the current buffer
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
      callback = function(event)
        -- NOTE: Remember that Lua is a real programming language, and as such it is possible
        -- to define small helper and utility functions so you don't have to repeat yourself.
        --
        -- In this case, we create a function that lets us more easily define mappings specific
        -- for LSP related items. It sets the mode, buffer and description for us each time.
        local map = function(keys, func, desc, mode)
          mode = mode or 'n'
          vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        -- Jump to the definition of the word under your cursor.
        --  This is where a variable was first declared, or where a function is defined, etc.
        --  To jump back, press <C-t>.
        local client = vim.lsp.get_client_by_id(event.data.client_id)

        local function get_ts_client(bufnr)
          for _, c in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
            if c.name == 'ts_ls' then
              return c
            end
          end
          return nil
        end

        local function has_definition_client(bufnr)
          local definition_method = vim.lsp.protocol.Methods.textDocument_definition
          return not vim.tbl_isempty(vim.lsp.get_clients({
            bufnr = bufnr,
            method = definition_method,
          }))
        end

        local function push_tagstack(tagname)
          local from = { vim.fn.bufnr('%'), vim.fn.line('.'), vim.fn.col('.'), 0 }
          local items = { { tagname = tagname, from = from } }
          vim.fn.settagstack(vim.fn.win_getid(), { items = items }, 't')
        end

        local function show_locations_in_telescope(items, title)
          -- Telescope's quickfix picker gives these location-shaped items a
          -- searchable list and a full file preview without opening a split.
          vim.fn.setqflist({}, ' ', {
            title = title,
            items = items,
          })
          require('telescope.builtin').quickfix {
            prompt_title = title,
            -- Definition previews should look like normal source buffers even
            -- though Treesitter is disabled for other Telescope previews.
            -- TypeScript's lib.dom.d.ts is larger than Telescope's default
            -- 1 MB highlight limit, so allow highlighting larger declaration
            -- files here without changing every Telescope picker.
            preview = {
              treesitter = true,
              highlight_limit = 10,
            },
          }
        end

        local function grep_definition_fallback(symbol, root)
          local current_file = vim.api.nvim_buf_get_name(0)
          local current_line = vim.api.nvim_win_get_cursor(0)[1]
          local output = vim.fn.systemlist({
            'rg',
            '--vimgrep',
            '--smart-case',
            '--glob',
            '!**/node_modules/**',
            '--glob',
            '!**/dist/**',
            symbol,
            root,
          })
          if vim.v.shell_error ~= 0 and #output == 0 then
            vim.notify('No definition found for ' .. symbol, vim.log.levels.INFO)
            return
          end

          local items = {}
          for _, line in ipairs(output) do
            local filename, lnum, col, text = line:match '^(.-):(%d+):(%d+):(.*)$'
            local is_current_line = filename == current_file and tonumber(lnum) == current_line
            local is_method_call = text and text:find('.' .. symbol, 1, true)
            if filename and not is_current_line and not is_method_call then
              table.insert(items, {
                filename = filename,
                lnum = tonumber(lnum),
                col = tonumber(col),
                text = text,
              })
            end
          end

          if #items == 0 then
            vim.notify('No definition found for ' .. symbol, vim.log.levels.INFO)
            return
          end

          local escaped = vim.pesc(symbol)
          local declaration_patterns = {
            -- function declarations (named / exported)
            '%f[%w_]function%s+' .. escaped .. '%f[^%w_]',
            -- const/let/var arrow-function or value assignments
            '%f[%w_]const%s+' .. escaped .. '%f[^%w_]',
            '%f[%w_]let%s+' .. escaped .. '%f[^%w_]',
            '%f[%w_]var%s+' .. escaped .. '%f[^%w_]',
            -- class / interface / type alias
            '%f[%w_]class%s+' .. escaped .. '%f[^%w_]',
            '%f[%w_]interface%s+' .. escaped .. '%f[^%w_]',
            '%f[%w_]type%s+' .. escaped .. '%f[^%w_]',
          }

          local declarations = vim.tbl_filter(function(item)
            local text = item.text or ''
            -- Exclude pure import lines and JSX usage lines
            if text:match '^%s*import%s*{' or text:match '^%s*import%s+' then
              return false
            end
            if text:match('^%s*<%/?' .. escaped) then
              return false
            end
            for _, pat in ipairs(declaration_patterns) do
              if text:match(pat) then
                return true
              end
            end
            return false
          end, items)

          if #declarations == 1 then
            push_tagstack(symbol)
            if declarations[1].filename ~= current_file then
              vim.cmd('edit ' .. vim.fn.fnameescape(declarations[1].filename))
            end
            vim.api.nvim_win_set_cursor(0, { declarations[1].lnum, math.max(declarations[1].col - 1, 0) })
            vim.cmd 'normal! zz'
            return
          end

          if #items == 1 then
            push_tagstack(symbol)
            if items[1].filename ~= current_file then
              vim.cmd('edit ' .. vim.fn.fnameescape(items[1].filename))
            end
            vim.api.nvim_win_set_cursor(0, { items[1].lnum, math.max(items[1].col - 1, 0) })
            vim.cmd 'normal! zz'
            return
          end

          show_locations_in_telescope(items, 'Definition search: ' .. symbol)
        end

        local function jump_to_location(loc, offset_encoding)
          local uri = loc.uri or loc.targetUri
          local range = loc.range or loc.targetSelectionRange or loc.targetRange
          if not uri or not range then
            return false
          end
          push_tagstack(vim.fn.expand '<cword>')
          local ok = pcall(vim.lsp.util.show_document, {
            uri = uri,
            range = range,
          }, offset_encoding, { focus = true })
          if ok then
            return true
          end

          if not vim.startswith(uri, 'file://') then
            return false
          end

          vim.cmd('edit ' .. vim.fn.fnameescape(vim.uri_to_fname(uri)))
          local line_count = math.max(vim.api.nvim_buf_line_count(0), 1)
          local line = math.min((range.start and range.start.line or 0) + 1, line_count)
          local line_text = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1] or ''
          local col = math.min(range.start and range.start.character or 0, #line_text)
          vim.api.nvim_win_set_cursor(0, { line, col })
          vim.cmd 'normal! zz'
          return true
        end

        local function location_start_line(loc)
          local range = loc.range or loc.targetSelectionRange or loc.targetRange
          return range and range.start and range.start.line or nil
        end

        local function location_line_text(loc)
          local uri = loc.uri or loc.targetUri
          local line = location_start_line(loc)
          if not uri or not line then
            return nil
          end

          local bufnr = vim.uri_to_bufnr(uri)
          if vim.api.nvim_buf_is_loaded(bufnr) then
            return vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1]
          end

          local filename = vim.uri_to_fname(uri)
          local ok, lines = pcall(vim.fn.readfile, filename, '', line + 1)
          if ok then
            return lines[line + 1]
          end

          return nil
        end

        local function unique_locations(locs)
          local seen = {}
          local unique = {}
          for _, loc in ipairs(locs) do
            local uri = loc.uri or loc.targetUri or ''
            local line = location_start_line(loc) or ''
            local key = uri .. ':' .. line
            if not seen[key] then
              seen[key] = true
              table.insert(unique, loc)
            end
          end
          return unique
        end

        local function declaration_locations(locs, symbol)
          local escaped = vim.pesc(symbol)
          return vim.tbl_filter(function(loc)
            local text = location_line_text(loc)
            if not text then
              return false
            end

            return text:match('%f[%w_]const%s+' .. escaped .. '%f[^%w_]')
              or text:match('%f[%w_]let%s+' .. escaped .. '%f[^%w_]')
              or text:match('%f[%w_]var%s+' .. escaped .. '%f[^%w_]')
              or text:match('%f[%w_]function%s+' .. escaped .. '%f[^%w_]')
              or text:match('%f[%w_]class%s+' .. escaped .. '%f[^%w_]')
              or text:match('%f[%w_]interface%s+' .. escaped .. '%f[^%w_]')
              or text:match('%f[%w_]type%s+' .. escaped .. '%f[^%w_]')
          end, locs)
        end

        local function jump_or_list_locations(locs, offset_encoding, title, symbol)
          local unique = unique_locations(locs)
          if #unique == 0 then
            return false
          end

          if #unique == 1 then
            return jump_to_location(unique[1], offset_encoding)
          end

          -- Tier 1: strong declaration signals (const/let/function/class/etc.)
          local declarations = declaration_locations(unique, symbol)
          if #declarations == 1 then
            return jump_to_location(declarations[1], offset_encoding)
          end

          if #declarations == 0 then
            local escaped = vim.pesc(symbol)
            local pure_bindings = vim.tbl_filter(function(loc)
              local text = location_line_text(loc) or ''
              -- Line must start with (optional whitespace + optional rest-spread + symbol)
              if not text:match('^%s*%.?%.?%.?' .. escaped) then
                return false
              end
              -- Reject type-annotation lines: symbol followed by optional '?' then ':'
              -- e.g. `  entryPrice: string;` or `  entryPrice?: boolean;`
              if text:match('^%s*%.?%.?%.?' .. escaped .. '%s*%??%s*:') then
                return false
              end
              return true
            end, unique)

            if #pure_bindings == 1 then
              return jump_to_location(pure_bindings[1], offset_encoding)
            end
          end

          show_locations_in_telescope(vim.lsp.util.locations_to_items(unique, offset_encoding), title)
          return true
        end

        local function cursor_is_on_identifier()
          local cursor = vim.api.nvim_win_get_cursor(0)
          local line = vim.api.nvim_get_current_line()
          local char = line:sub(cursor[2] + 1, cursor[2] + 1)
          return char:match '[%w_$]' ~= nil
        end

        local html_tags = vim.iter({
          'a', 'abbr', 'address', 'area', 'article', 'aside', 'audio', 'b', 'base', 'bdi', 'bdo',
          'blockquote', 'body', 'br', 'button', 'canvas', 'caption', 'cite', 'code', 'col',
          'colgroup', 'data', 'datalist', 'dd', 'del', 'details', 'dfn', 'dialog', 'div', 'dl',
          'dt', 'em', 'embed', 'fieldset', 'figcaption', 'figure', 'footer', 'form', 'h1', 'h2',
          'h3', 'h4', 'h5', 'h6', 'head', 'header', 'hgroup', 'hr', 'html', 'i', 'iframe',
          'img', 'input', 'ins', 'kbd', 'label', 'legend', 'li', 'link', 'main', 'map', 'mark',
          'menu', 'meta', 'meter', 'nav', 'noscript', 'object', 'ol', 'optgroup', 'option',
          'output', 'p', 'picture', 'pre', 'progress', 'q', 'rp', 'rt', 'ruby', 's', 'samp',
          'script', 'search', 'section', 'select', 'slot', 'small', 'source', 'span', 'strong',
          'style', 'sub', 'summary', 'sup', 'table', 'tbody', 'td', 'template', 'textarea',
          'tfoot', 'th', 'thead', 'time', 'title', 'tr', 'track', 'u', 'ul', 'var', 'video',
          'wbr',
        }):fold({}, function(tags, tag)
          tags[tag] = true
          return tags
        end)

        local function cursor_is_on_native_html_tag(symbol)
          -- Vue components can be PascalCase versions of native tag names, like
          -- <Section>. Only lowercase template tags should be treated as native.
          if symbol ~= symbol:lower() or not html_tags[symbol] then
            return false
          end

          local cursor_col = vim.api.nvim_win_get_cursor(0)[2] + 1
          local line = vim.api.nvim_get_current_line()
          local word_start = cursor_col
          while word_start > 1 and line:sub(word_start - 1, word_start - 1):match '[%w:_-]' do
            word_start = word_start - 1
          end

          return line:sub(1, word_start - 1):match '<%/?%s*$' ~= nil
        end

        map('gd', function()
          if not cursor_is_on_identifier() then
            return
          end

          local ts = get_ts_client(event.buf)
          local symbol = vim.fn.expand '<cword>'
          -- Native HTML elements have no source definition. In particular, do
          -- not send them through the text-search fallback when the LSP returns
          -- nothing; this matches VS Code's Command-click behaviour.
          if cursor_is_on_native_html_tag(symbol) then
            return
          end
          if not ts then
            if has_definition_client(event.buf) then
              -- Request definitions manually so we can deduplicate and jump
              -- directly instead of always opening a location list.
              local win = vim.api.nvim_get_current_win()
              local method = vim.lsp.protocol.Methods.textDocument_definition
              local lsp_client = vim.iter(vim.lsp.get_clients({ bufnr = event.buf, method = method })):next()
              if not lsp_client then
                vim.notify('No LSP client with definition support is attached to this buffer', vim.log.levels.WARN)
                return
              end
              local params = vim.lsp.util.make_position_params(win, lsp_client.offset_encoding)
              lsp_client:request(method, params, function(err, result)
                if err or not result or (type(result) == 'table' and vim.tbl_isempty(result)) then
                  vim.notify('No definition found', vim.log.levels.INFO)
                  return
                end
                -- Normalise to a list
                local locs = vim.islist(result) and result or { result }
                jump_or_list_locations(locs, lsp_client.offset_encoding, 'Definitions', symbol)
              end, event.buf)
            else
              vim.notify('No LSP client with definition support is attached to this buffer', vim.log.levels.WARN)
            end
            return
          end

          local win = vim.api.nvim_get_current_win()
          local params = vim.lsp.util.make_position_params(win, ts.offset_encoding)
          local root = ts.config.root_dir or vim.fn.getcwd()

          local function fallback_to_search()
            grep_definition_fallback(symbol, root)
          end

          local function try_source_definition()
            ts:exec_cmd({
              command = '_typescript.goToSourceDefinition',
              title = 'Go to source definition',
              arguments = { params.textDocument.uri, params.position },
            }, { bufnr = event.buf }, function(err, result)
              if err or not result or vim.tbl_isempty(result) or not jump_to_location(result[1], ts.offset_encoding) then
                fallback_to_search()
              end
            end)
          end

          ts:request('textDocument/definition', params, function(err, result)
            if err or not result or vim.tbl_isempty(result) then
              try_source_definition()
              return
            end

            local locs = vim.islist(result) and result or { result }
            if not jump_or_list_locations(locs, ts.offset_encoding, 'Definitions', symbol) then
              try_source_definition()
            end
          end, event.buf)
        end, '[G]oto [D]efinition')

        -- For TypeScript, keep source-definition on a separate key so we can still
        -- jump through re-exports or .d.ts shims without breaking local definitions.
        if client and client.name == 'ts_ls' then
          map('gS', function()
            local win = vim.api.nvim_get_current_win()
            local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
            client:exec_cmd({
              command = '_typescript.goToSourceDefinition',
              title = 'Go to source definition',
              arguments = { params.textDocument.uri, params.position },
            }, { bufnr = event.buf }, function(err, result)
              if err then
                vim.notify('Go to source definition failed: ' .. err.message, vim.log.levels.ERROR)
                return
              end

              if not result or vim.tbl_isempty(result) then
                vim.notify('No source definition found', vim.log.levels.INFO)
                return
              end

              vim.lsp.util.show_document(result[1], client.offset_encoding, { focus = true })
            end)
          end, '[G]oto [S]ource Definition')
        end

        -- Find references for the word under your cursor.
        map('gr', function() require('telescope.builtin').lsp_references() end, '[G]oto [R]eferences')

        -- Jump to the implementation of the word under your cursor.
        --  Useful when your language has ways of declaring types without an actual implementation.
        map('gI', function() require('telescope.builtin').lsp_implementations() end, '[G]oto [I]mplementation')

        -- Jump to the type of the word under your cursor.
        --  Useful when you're not sure what type a variable is and you want to see
        --  the definition of its *type*, not where it was *defined*.
        map('<leader>D', function() require('telescope.builtin').lsp_type_definitions() end, 'Type [D]efinition', { 'n', 'x' })

        -- Fuzzy find all the symbols in your current document.
        --  Symbols are things like variables, functions, types, etc.
        map('<leader>ds', function() require('telescope.builtin').lsp_document_symbols() end, '[D]ocument [S]ymbols', { 'n', 'x' })

        -- Fuzzy find all the symbols in your current workspace.
        --  Similar to document symbols, except searches over your entire project.
        map('<leader>ws', function() require('telescope.builtin').lsp_dynamic_workspace_symbols() end, '[W]orkspace [S]ymbols', { 'n', 'x' })

        -- Rename the variable under your cursor.
        --  Most Language Servers support renaming across files, etc.
        map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')

        -- Execute a code action, usually your cursor needs to be on top of an error
        -- or a suggestion from your LSP for this to activate.
        map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction', { 'n', 'x' })

        -- WARN: This is not Goto Definition, this is Goto Declaration.
        --  For example, in C this would take you to the header.
        map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

        map('K', toggle_lsp_hover, 'Hover Documentation')

        -- The following two autocommands are used to highlight references of the
        -- word under your cursor when your cursor rests there for a little while.
        --    See `:help CursorHold` for information about when this is executed
        --
        -- When you move your cursor, the highlights will be cleared (the second autocommand).
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
          local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
          vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.document_highlight,
          })

          vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.clear_references,
          })

          vim.api.nvim_create_autocmd('LspDetach', {
            group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
            callback = function(event2)
              vim.lsp.buf.clear_references()
              vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
            end,
          })
        end

        -- The following code creates a keymap to toggle inlay hints in your
        -- code, if the language server you are using supports them
        --
        -- This may be unwanted, since they displace some of your code
        if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
          map('<leader>th', function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
          end, '[T]oggle Inlay [H]ints')
        end
      end,
    })

    -- LSP servers and clients are able to communicate to each other what features they support.
    --  By default, Neovim doesn't support everything that is in the LSP specification.
    --  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
    --  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

    -- Enable the following language servers
    --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
    --
    --  Add any additional override configuration in the following tables. Available keys are:
    --  - cmd (table): Override the default command used to start the server
    --  - filetypes (table): Override the default list of associated filetypes for the server
    --  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
    --  - settings (table): Override the default settings passed when initializing the server.
    --        For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
    local language_config = require 'config.languages'
    local servers = language_config.lsp_servers()

    -- Ensure the servers and tools above are installed
    --  To check the current status of installed tools and/or manually install
    --  other tools, you can run
    --    :Mason
    --
    --  You can press `g?` for help in this menu.
    require('mason').setup()

    -- You can add other tools here that you want Mason to install
    -- for you, so that they are available from within Neovim.
    local ensure_installed = vim.tbl_keys(servers or {})
    vim.list_extend(ensure_installed, language_config.mason_extra_tools)
    require('mason-tool-installer').setup { ensure_installed = ensure_installed }

    -- mason-lspconfig v2 can auto-enable installed servers with their default
    -- configs. Disable that so our explicit per-server settings actually win.
    require('mason-lspconfig').setup {
      automatic_enable = false,
    }

    for server_name, server in pairs(servers) do
      -- This handles overriding only values explicitly passed
      -- by the server configuration above. Useful when disabling
      -- certain features of an LSP (for example, turning off formatting for tsserver)
      server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
      vim.lsp.config(server_name, server)
      vim.lsp.enable(server_name)
    end

    -- The built-in nvim-lspconfig :LspRestart command only understands clients
    -- that were registered through vim.lsp.config(). That excludes null-ls,
    -- which causes "Invalid server name 'null-ls'" when restarting a buffer
    -- that has both ts_ls and null-ls attached.
    pcall(vim.api.nvim_del_user_command, 'LspRestart')
    vim.api.nvim_create_user_command('LspRestart', function(info)
      local bufnr = vim.api.nvim_get_current_buf()
      local targets = {}
      local wanted = {}

      for _, name in ipairs(info.fargs or {}) do
        wanted[name] = true
      end

      for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
        if vim.tbl_isempty(wanted) or wanted[client.name] then
          table.insert(targets, client)
        end
      end

      if #targets == 0 then
        vim.notify('No LSP clients attached to this buffer', vim.log.levels.INFO)
        return
      end

      local managed = {}
      for _, client in ipairs(targets) do
        if vim.lsp.config[client.name] ~= nil then
          managed[client.name] = true
        end
        client:stop(info.bang or false)
      end

      vim.defer_fn(function()
        for name, _ in pairs(managed) do
          vim.lsp.enable(name)
        end

        if vim.api.nvim_buf_is_valid(bufnr) then
          vim.schedule(function()
            vim.cmd 'edit'
          end)
        end
      end, 300)
    end, {
      desc = 'Restart LSP clients for the current buffer',
      nargs = '*',
      bang = true,
      complete = function()
        return vim
          .iter(vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() }))
          :map(function(client)
            return client.name
          end)
          :totable()
      end,
    })

    vim.diagnostic.config {
      -- Keep only the red squiggle in the buffer; details still show via K.
      virtual_text = false,
      virtual_lines = false,
      underline = true,
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = 'E',
          [vim.diagnostic.severity.WARN] = 'W',
          [vim.diagnostic.severity.INFO] = 'I',
          [vim.diagnostic.severity.HINT] = 'H',
        },
      },
      update_in_insert = false,
      severity_sort = true,
      float = {
        focusable = true,
        border = 'rounded',
        source = 'always',
        header = '',
        prefix = '',
      },
    }

    -- Fade unused variables/functions like VS Code does
    vim.api.nvim_set_hl(0, 'DiagnosticUnnecessary', { fg = '#6b7280', italic = true })
    vim.api.nvim_set_hl(0, 'DiagnosticUnderlineError', { undercurl = true, sp = '#e06c75' })
    -- VS Code Dark+ diagnostic warning squiggle.
    vim.api.nvim_set_hl(0, 'DiagnosticUnderlineWarn', { undercurl = true, sp = '#cca700' })
    vim.api.nvim_set_hl(0, 'DiagnosticUnderlineInfo', { undercurl = true, sp = '#61afef' })
    vim.api.nvim_set_hl(0, 'DiagnosticUnderlineHint', { undercurl = true, sp = '#56b6c2' })

    -- Override float to enforce wrapping and max_width
    local orig_util_open_float = vim.diagnostic.open_float
    vim.diagnostic.open_float = function(bufnr, opts)
      opts = opts or {}
      opts.max_width = 80
      opts.wrap = true
      opts.border = 'rounded'
      return orig_util_open_float(bufnr, opts)
    end
    vim.keymap.set('n', '<leader>d', function()
      vim.diagnostic.open_float(0, {
        scope = 'line',
        max_width = 80,
        wrap = true,
        border = 'rounded',
      })
    end, { desc = 'Show diagnostic (wrapped)' })
  end,
}

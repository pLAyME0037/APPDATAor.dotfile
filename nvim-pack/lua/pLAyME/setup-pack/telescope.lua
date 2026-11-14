local telescope = require("telescope")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local builtin = require("telescope.builtin")

telescope.setup({
    defaults = {
        path_display = function(_, path)
            local sep = "/"
            local parts = vim.split(path, sep, { plain = true })
            if parts[1] == "" then
                table.remove(parts, 1)
            end
            if #parts <= 3 then
                return path
            end
            return parts[1] .. sep .. ".." .. sep .. parts[#parts - 1] .. sep .. parts[#parts]
        end,

        preview = { wrap = true },
        sorting_strategy = "descending",

        layout_config = {
            prompt_position = "bottom",

            width = function(_, cols, _)
                return math.floor(cols * 0.95)
            end,

            height = function(_, _, lines)
                return math.floor(lines * 0.95)
            end,

            preview_width = 0.6,
        },

        mappings = {
            i = {
                ["<C-k>"] = actions.move_selection_previous,
                ["<C-j>"] = actions.move_selection_next,
            },
        },
    },

    extensions = {
        fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = "smart_case",
        },

        themes = {
            enable_previewer = true,
            enable_live_preview = true,
            persist = {
                enabled = true,
                path = vim.fn.stdpath("config") .. "/lua/colorscheme.lua",
            },
        },
    },

    pickers = {
        buffers = {
            ignore_current_buffer = true,
            sort_mru = true,
            mappings = {
                i = { ["<C-d>"] = actions.delete_buffer },
                n = { ["dd"] = actions.delete_buffer },
            },
        },
    },
})

pcall(telescope.load_extension, "fzf")
pcall(telescope.load_extension, "themes")

-- Custom picker: functions in current file
-- ┌─────────────┬─────────────────────────────────────────────────────────────┐
-- │Token        │Means                                                        │
-- ├─────────────┼─────────────────────────────────────────────────────────────┤
-- │^            │Line start                                                   │
-- ├─────────────┼─────────────────────────────────────────────────────────────┤
-- │%s*          │Zero or more whitespace                                      │
-- ├─────────────┼─────────────────────────────────────────────────────────────┤
-- │static       │Literal static                                               │
-- ├─────────────┼─────────────────────────────────────────────────────────────┤
-- │%s+          │One or more whitespace                                       │
-- ├─────────────┼─────────────────────────────────────────────────────────────┤
-- │([%w_]+)     │Capture 1: identifier (letters/digits/underscore) — captures │
-- │             │return TYPE (e.g.void)                                       │
-- ├─────────────┼─────────────────────────────────────────────────────────────┤
-- │[%s%*]*      │Zero or more whitespace or * — handles void*, void *         │
-- ├─────────────┼─────────────────────────────────────────────────────────────┤
-- │%(           │Literal ( (Lua: % escapes magic char ()                      │
-- ├─────────────┼─────────────────────────────────────────────────────────────┤
-- │[^)]-        │Zero or more non-) chars — matches (naked inside ((naked))   │
-- ├─────────────┼─────────────────────────────────────────────────────────────┤
-- │%)%)         │Two literal ) — matches )) closing ((naked))                 │
-- └─────────────┴─────────────────────────────────────────────────────────────┘
-- File scope configuration
local patterns = {
    lua = {
        definition = {
            "^%s*local%s+([%w_]+)%s*=%s*function",
            "^%s*function%s+([%w_]+)",
            "^%s*local%s+function%s+([%w_]+)",
            "^%s*([%w_]+)%s*=%s*function%s*%(",
            "^%s*M%.([%w_]+)%s*=%s*function",
            "^%s*function%s+[%w_]+%.([%w_]+)",
            "^%s*function%s+[%w_]+%:([%w_]+)",
        },
    },
    python = {
        definition = {
            "^%s*def%s+([%w_]+)",
            "^%s*async%s+def%s+([%w_]+)",
            "^%s*class%s+([%w_]+)",
        },
    },
    go = {
        definition = {
            "^%s*func%s+([%w_]+)%s*%(",
        },
    },
    rust = {
        definition = {
            "^%s*[%w_%s%*%(%)]*%s*fn%s+([%w_]+)%s*%(",
            "^%s*impl%b<>%s+([%w_]+)",
            "^%s*impl%s+([%w_]+)",
        },
    },
    c = {
        definition = {
            "^%s*([%w_][%w_%s%*%&%:<>]*[%s%*%&%:]+)([%w_]+)%s*%(",
            "^%s*#%s*define%s+([%w_]+)%s*%(",
        },
    },
    cpp = {
        definition = {
            "^%s*([%w_][%w_%s%*%&%:<>]*[%s%*%&%:]+)([~]?[%w_]+)%s*%(", -- out-of-class methods / destructor
            "^%s*([~]?[%w_]+)%s*%([^)]*%)%s*[:{]",                     -- in-class constructors / destructor
            "^%s*#%s*define%s+([%w_]+)%s*%(",                          -- macros
        },
    },
    php = {
        definition = {
            "^%s*[%w_%s]*%s*function%s+([%w_]+)%s*%(",                -- strict named function block
            "^%s*class%s+([%w_]+)",
            "^%s*trait%s+([%w_]+)",
            "^%s*interface%s+([%w_]+)",
        },
    },
    javascript = {
        definition = {
            "^%s*([%w_][%w_%s%*%&%:<>]*[%s%*%&%:]+)([%w_]+)%s*%(", -- export, async, static modifiers
            "^%s*([%w_]+)%s*%([^)]*%)%s*{",                        -- plain class methods
            "^%s*const%s+([%w_]+)%s*=%s*function%s*%(",
            "^%s*const%s+([%w_]+)%s*=%s*%(.-%)%s*=>",
            "^%s*const%s+([%w_]+)%s*=%s*([%w_]+)%s*=>",
            "^%s*let%s+([%w_]+)%s*=%s*function%s*%(",
            "^%s*let%s+([%w_]+)%s*=%s*%(.-%)%s*=>",
            "^%s*let%s+([%w_]+)%s*=%s*([%w_]+)%s*=>",
            "^%s*class%s+([%w_]+)",
        }
    }
}

patterns.java       = patterns.c
patterns.cs         = patterns.c
patterns.dart       = patterns.c
patterns.typescript = patterns.javascript
patterns.sh         = patterns.javascript

local scope_patterns = {
    lua = {},
    php = {
        "^%s*namespace%s+([%w%_\\\\]+)%s*;",
        "^%s*class%s+([%w_]+)"
    },
    javascript = { "^%s*class%s+([%w_]+)" },
    typescript = {
        "^%s*class%s+([%w_]+)",
        "^%s*interface%s+([%w_]+)"
    },
    sh = {},
    python = { "^%s*class%s+([%w_]+)" },
    go = { "^%s*type%s+([%w_]+)%s+struct" },
    rust = {
        "^%s*impl%s+%s*([%w<>]+)%s*%{",
        "^%s*pub%s+trait%s+([%w_]+)",
        "^%s*trait%s+([%w_]+)"
    },
    c = {},
    cpp = {
        "^%s*class%s+([%w_]+)",
        "^%s*struct%s+([%w_]+)",
        "^%s*namespace%s+([%w_]+)"
    },
    java = {
        "^%s*class%s+([%w_]+)",
        "^%s*interface%s+([%w_]+)"
    },
    cs = {
        "^%s*namespace%s+([%w%.]+)",
        "^%s*class%s+([%w_]+)"
    },
}

-- Raw literals for exact character matches (avoids regex escape bugs)
local comment_chars = {
    lua = {
        single = "--",
        block_start = "--[[",
        block_end = "]]"
    },
    python = {
        single = "#",
        block_start = '"""', block_end = '"""',
        block_start_alt = "'''", block_end_alt = "'''"
    },
    c = {
        single = "//",
        block_start = "/*",
        block_end = "*/"
    },
}
comment_chars.cpp        = comment_chars.c
comment_chars.java       = comment_chars.c
comment_chars.cs         = comment_chars.c
comment_chars.dart       = comment_chars.c
comment_chars.php        = comment_chars.c
comment_chars.go         = comment_chars.c
comment_chars.rust       = comment_chars.c
comment_chars.javascript = comment_chars.c
comment_chars.typescript = comment_chars.c
comment_chars.sh         = comment_chars.python

local reserve_words = {
    ["if"]=true,        ["while"]=true,     ["for"]=true,
    ["switch"]=true,    ["return"]=true,    ["catch"]=true,
    ["throw"]=true,     ["try"]=true,       ["case"]=true,
    ["default"]=true,   ["do"]=true,        ["else"]=true,
    ["template"]=true,  ["typename"]=true,  ["class"]=true,
    ["struct"]=true,    ["namespace"]=true, ["using"]=true,
    ["const"]=true,     ["static"]=true,    ["inline"]=true,
    ["virtual"]=true,   ["explicit"]=true,  ["new"]=true,
    ["delete"]=true,    ["operator"]=true,  ["public"]=true,
    ["private"]=true,   ["protected"]=true,
    ["function"]=true,  ["async"]=true,     ["await"]=true,
    ["typeof"]=true,    ["import"]=true,    ["export"]=true,
    ["in"]=true,        ["var"]=true,       ["let"]=true,
    ["this"]=true,      ["super"]=true,     ["extends"]=true,
    ["yield"]=true,     ["get"]=true,       ["set"]=true,
}

local reject_start = {
    ["return"]=true,  ["if"]=true,     ["while"]=true,
    ["for"]   =true,     ["switch"]=true, ["else"]=true,
    ["typedef"]=true, ["using"]=true,  ["throw"]=true,
    ["new"]=true,     ["delete"]=true
}

local function strip_line_comments(line, style, state)
    local out = {}
    local idx = 1
    local len = #line

    while idx <= len do
        if state.in_block then
            local end_idx = line:find(style.block_end, idx, true)
            if end_idx then
                state.in_block = false
                idx = end_idx + #style.block_end
            else
                return table.concat(out)
            end
        elseif state.in_block_alt then
            local end_idx = line:find(style.block_end_alt, idx, true)
            if end_idx then
                state.in_block_alt = false
                idx = end_idx + #style.block_end_alt
            else
                return table.concat(out)
            end
        else
            local b_idx = nil
            if style.block_start then
                b_idx = line:find(style.block_start, idx, true)
            end
            local ba_idx = nil
            if style.block_start_alt then
                ba_idx = line:find(style.block_start_alt, idx, true)
            end
            local s_idx = nil
            if style.single then
                s_idx = line:find(style.single, idx, true)
            end

            -- Treat block comment start as higher priority when at same index (e.g. "--[[" vs "--")
            local earliest = nil
            local kind = nil

            if b_idx then
                earliest = b_idx
                kind = "block"
            end
            if ba_idx and (earliest == nil or ba_idx < earliest) then
                earliest = ba_idx
                kind = "block_alt"
            end
            if s_idx and (earliest == nil or s_idx < earliest) then
                earliest = s_idx
                kind = "single"
            end

            if earliest == nil then
                table.insert(out, line:sub(idx))
                break
            end

            if earliest > idx then
                table.insert(out, line:sub(idx, earliest - 1))
            end

            if kind == "single" then
                break
            elseif kind == "block" then
                state.in_block = true
                idx = earliest + #style.block_start
            else
                state.in_block_alt = true
                idx = earliest + #style.block_start_alt
            end
        end
    end

    return table.concat(out)
end

local function list_functions()
    local buf     = vim.api.nvim_get_current_buf()
    local lines   = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local results = {}
    local lang    = vim.bo.filetype

    local lang_patterns = patterns[lang]
    if lang_patterns == nil then
        lang_patterns = patterns.lua
    end
    local current_scope = ""
    local scope_indent  = 0
    local sp = scope_patterns[lang]
    if sp == nil then
        sp = {}
    end
    local keywords = nil
    if lang == "javascript" or lang == "typescript" or lang == "cpp" then
        keywords = reserve_words
    end
    local comment_style = comment_chars[lang]
    if comment_style == nil then
        comment_style = comment_chars.c
    end

    local comment_state = {
        in_block     = false,
        in_block_alt = false,
    }

    local function add_result(i, line, name, raw_name)
        table.insert(results, {
            line = i,
            text = line:match("^%s*(.-)%s*$"),
            name = name,
            raw_name = raw_name,
            type = "fn",
        })
    end

    for i, raw_line in ipairs(lines) do
        local is_c_like, first_word, is_closing, current_indent, recv, fn_name
        local line = strip_line_comments(raw_line, comment_style, comment_state)
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed == nil then
            trimmed = ""
        end

        if trimmed == "" then
            goto continue
        end

        if lang == "python" then
            local indent = line:match("^%s*")
            if #indent == 0 and line:match("%w") then
                current_scope = ""
            end
        end

        if current_scope ~= "" then
            is_closing = line:match("^%s*}%s*;?%s*$")
            if is_closing then
                current_indent = #line:match("^%s*")
                if current_indent <= scope_indent then
                    current_scope = ""
                end
            end
        end

        for _, pat in ipairs(sp) do
            local s = line:match(pat)
            if s then
                current_scope = s
                scope_indent = #line:match("^%s*")
                break
            end
        end

        is_c_like = (lang == "c"  or lang == "cpp"  or lang == "java" or
                     lang == "cs" or lang == "dart" or lang == "php" or
                     lang == "go" or lang == "rust" or lang == "javascript" or
                     lang == "typescript")

        if is_c_like and line:match(";%s*$") then
            goto continue
        end

        first_word = line:match("^%s*([%w_]+)")
        if first_word and reject_start[first_word] then
            goto continue
        end

        recv, fn_name = line:match("^%s*func%s+%(%s*[%w_]+%s+[%*]?([%w_]+)%s*%)%s*([%w_]+)%s*%(")
        if recv and fn_name then
            add_result(i, line, recv .. "." .. fn_name, fn_name)
            goto continue
        end

        for _, pattern in ipairs(lang_patterns.definition) do
            local captures = { line:match(pattern) }
            if #captures > 0 then
                local raw = captures[#captures]
                if raw and raw ~= "" and not (keywords and keywords[raw]) then
                    local name = raw
                    if current_scope ~= "" then
                        name = current_scope .. "." .. raw
                    end
                    add_result(i, line, name, raw)
                    break
                end
            end
        end

        ::continue::
    end

    for _, entry in ipairs(results) do
        local raw = entry.raw_name
        if not raw then
            raw = entry.name:match("[^.]*$")
        end
        if not raw then
            raw = entry.name
        end
        local safe_raw = raw:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1")
        local count = 0
        for i, line in ipairs(lines) do
            if i ~= entry.line and line:match(safe_raw .. "%s*%(") then
                count = count + 1
            end
        end
        entry.call_count = count
    end

    require("telescope.pickers")
    .new({}, {
        prompt_title = "Functions in file",
        finder = require("telescope.finders").new_table({
            results = results,
            entry_maker = function(entry)
                local sig = entry.text
                local start = sig:find(entry.raw_name, 1, true)
                if start then
                    sig = entry.name .. sig:sub(start + #entry.raw_name):gsub("^%s*=%s*", ""):gsub("%s+$", "")
                end
                local left = "fn(" .. entry.call_count .. ")"
                local pad = string.rep(" ", math.max(0, 6 - #left))
                return {
                    value = entry,
                    display = left .. pad .. " | " .. sig,
                    ordinal = entry.name .. " " .. entry.text,
                }
            end,
        }),
        sorter = require("telescope.config").values.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, _)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                if not selection or not selection.value then
                    return
                end
                local entry = selection.value
                actions.close(prompt_bufnr)
                vim.api.nvim_win_set_cursor(0, { entry.line, 0 })
                vim.cmd("normal! zv")
            end)
            return true
        end,
    })
    :find()
end

local search_home_dirs = function(is_cd)
    local home = vim.fn.expand("~")
    local candidate_dirs = {
        home,
        home .. "/mythings/studying_code",
        home .. "/Projects/github",
        home .. "/opt",
    }
    local dirs = {}
    for _, d in ipairs(candidate_dirs) do
        if vim.fn.isdirectory(d) == 1 then
            table.insert(dirs, d)
        end
    end

    if #dirs == 0 then
        vim.notify("No configured search directories exist", vim.log.levels.WARN)
        return
    end

    builtin.find_files({
        prompt_title = "jump to dir",
        find_command = {
            "fd",
            "--type", "d",
            "--hidden",
            "--ignore-case",
            "--max-depth", "3",
            "--exclude", ".git",
            "--exclude", ".gitignore",
            "--exclude", ".cache",
            "--exclude", ".analysis-driver",
            "--exclude", "node_modules",
            "--exclude", "vendors",
            "--exclude", "plugins",
            "--exclude", "packs",
            "--exclude", "packages",
            "--exclude", "legal",
            ".",
            unpack(dirs)
        },

        path_display = function(_, path)
            if type(path) ~= "string" then
                return tostring(path)
            end
            local parts = vim.split(path, "/", { plain = true, trimempty = true })
            if #parts >= 2 then
                return parts[#parts - 1] .. "/" .. parts[#parts]
            end
            return path
        end,

        attach_mappings = function(prompt_bufnr, _)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                if not selection or not selection.value then
                    return
                end
                local dir = selection.value

                actions.close(prompt_bufnr)
                if is_cd == true then
                    vim.api.nvim_set_current_dir(dir)
                    print("Switch to " .. dir)
                end
                builtin.find_files({ cwd = dir })
            end)
            return true
        end,
    })
end

-- vim.keymap.set('i', '<C-p>', builtin.git_files, {})
vim.keymap.set('n', '<leader>fd', function() search_home_dirs(true) end, { desc = "[F]ind [D]ir and jump to dir" })
vim.keymap.set('n', '<leader>df', function() search_home_dirs(false) end, { desc = "[D]ir [F]ind" })
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>bf', builtin.buffers, { desc = "[B]uffer Lists"})
vim.keymap.set('n', '<leader>fn', list_functions, { desc = "[F]u[N]ctions Find in file"})
vim.keymap.set('n', '<leader>pws', function()
    local word = vim.fn.expand("<cword>")
    builtin.grep_string({ search = word })
end)
vim.keymap.set('n', '<leader>pWs', function()
    local word = vim.fn.expand("<cWORD>")
    builtin.grep_string({ search = word })
end)
vim.keymap.set('n', '<leader>ps', function()
    builtin.grep_string({ search = vim.fn.input("Grep > ") })
end)
vim.keymap.set('n', '<leader>vh', builtin.help_tags, {})
vim.keymap.set("n", "<leader>ths", "<cmd>Telescope themes<CR>", { noremap = true, silent = true, desc = "Theme Switcher" })

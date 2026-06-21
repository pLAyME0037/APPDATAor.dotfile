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

telescope.load_extension("fzf")
telescope.load_extension("themes")

-- Custom picker: functions in current file
-- ┌─────────────┬────────────────────────────────────────────────────────────────────────────────┐
-- │Token        │Means                                                                           │
-- ├─────────────┼────────────────────────────────────────────────────────────────────────────────┤
-- │^            │Line start                                                                      │
-- ├─────────────┼────────────────────────────────────────────────────────────────────────────────┤
-- │%s*          │Zero or more whitespace                                                         │
-- ├─────────────┼────────────────────────────────────────────────────────────────────────────────┤
-- │static       │Literal static                                                                  │
-- ├─────────────┼────────────────────────────────────────────────────────────────────────────────┤
-- │%s+          │One or more whitespace                                                          │
-- ├─────────────┼────────────────────────────────────────────────────────────────────────────────┤
-- │([%w_]+)     │Capture 1: identifier (letters/digits/underscore) — captures return TYPE (e.g.  │
-- │             │void)                                                                           │
-- ├─────────────┼────────────────────────────────────────────────────────────────────────────────┤
-- │[%s%*]*      │Zero or more whitespace or * — handles void*, void *                            │
-- ├─────────────┼────────────────────────────────────────────────────────────────────────────────┤
-- │%(           │Literal ( (Lua: % escapes magic char ()                                         │
-- ├─────────────┼────────────────────────────────────────────────────────────────────────────────┤
-- │[^)]-        │Zero or more non-) chars — matches (naked inside ((naked))                      │
-- ├─────────────┼────────────────────────────────────────────────────────────────────────────────┤
-- │%)%)         │Two literal ) — matches )) closing ((naked))                                    │
-- └─────────────┴────────────────────────────────────────────────────────────────────────────────┘
local function list_functions()
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local results = {}
    local lang = vim.bo.filetype

    local patterns = {
        lua = {
            definition = {
                "^%s*local%s+([%w_]+)%s*=%s*function",
                "^%s*function%s+([%w_]+)",
                "^%s*local%s+function%s+([%w_]+)",
                "^%s*([%w_]+)%s*=%s*function%s*%(",
                "^%s*M%.([%w_]+)%s*=%s*function",
            },
        },
        php = {
            definition = {
                "^%s*([%w]+)[%s%*]+([%w]+)[%s%*]+([%w_]+)%s*%(",
                "^%s*([%w]+)[%s%*]+([%w_]+)%s*%(",
                "^%s*class%s+([%w_]+)",
            },
        },
        javascript = {
            definition = {
                "^%s*function%s+([%w_]+)",
                "^%s*export%s+function%s+([%w_]+)",
                "^%s*export%s+default%s+function%s+([%w_]+)",
                "^%s*async%s+function%s+([%w_]+)",
                "^%s*export%s+async%s+function%s+([%w_]+)",
                "^%s*class%s+([%w_]+)",
                "^%s*export%s+class%s+([%w_]+)",
                "^%s*const%s+([%w_]+)%s*=%s*function%s*%(",
                "^%s*const%s+([%w_]+)%s*=%s*%(.-%)%s*=>",
                "^%s*const%s+([%w_]+)%s*=%s*([%w_]+)%s*=>",
                "^%s*let%s+([%w_]+)%s*=%s*function%s*%(",
                "^%s*let%s+([%w_]+)%s*=%s*%(.-%)%s*=>",
                "^%s*let%s+([%w_]+)%s*=%s*([%w_]+)%s*=>",
                "^%s+([%w_]+)%s*%([^)]-%)%s*{",
            },
        },
        typescript = {
            definition = {
                "^%s*function%s+([%w_]+)",
                "^%s*const%s+([%w_]+)%s*=",
                "^%s*class%s+([%w_]+)",
                "^%s*interface%s+([%w_]+)",
                "^%s*type%s+([%w_]+)",
                "^%s*async%s+function%s+([%w_]+)",
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
                "^%s*func%s+%(([%w_]+)%s+%w+%)%s+([%w_]+)",
            },
        },
        rust = {
            definition = {
                "^%s*fn%s+([%w_]+)",
                "^%s*pub%s+fn%s+([%w_]+)",
                "^%s*impl%s+",
            },
        },
        dart = {
            definition = {
                "^%s*static%s+([%w_]+)[%s%*]+([%w_]+)%s*%(",
                "^%s*([%w_]+)[%s%*]+([%w_]+)%s*%(",
                "^%s*class%s+([%w_]+)",
            },
        },
        c = {
            definition = {
                "^%s*static%s+([%w_]+)[%s%*]*__attribute__%s*%([^)]-%)%)%s+([%w_]+)%s*%(",
                "^%s*static%s+([%w_]+)[%s%*]+([%w_]+)%s*%(",
                "^%s*([%w_]+)[%s%*]*__attribute__%s*%([^)]-%)%)%s+([%w_]+)%s*%(",
                "^%s*([%w_]+)[%s%*]+([%w_]+)%s*%(",
                "^%s*struct%s+([%w_]+)",
            },
        },
        cpp = {
            definition = {
                "^%s*class%s+([%w_]+)",
                "^%s*struct%s+([%w_]+)",
                "^%s*[%w_:]+[%s%*&]*operator([^%s%(]+)",
                "^%s+([%w_]+)%s*%([^)]-%)%s*{",
                "^%s*const%s+[%w_:<>]+[%s%*&]*([%w_~]+)%s*%(",
                "^%s*unsigned%s+[%w_:<>]+[%s%*&]*([%w_~]+)%s*%(",
                "^%s*static%s+[%w_:<>]+[%s%*&]*([%w_~]+)%s*%(",
                "^%s*inline%s+[%w_:<>]+[%s%*&]*([%w_~]+)%s*%(",
                "^%s*virtual%s+[%w_:<>]+[%s%*&]*([%w_~]+)%s*%(",
                "^%s*explicit%s+[%w_:<>]+[%s%*&]*([%w_~]+)%s*%(",
                "^%s*[%w_:<>]+[%s%*&]+([%w_~]+)%s*%(",
                -- "^%s*~?([%w_]+)%s*%(",
            },
        },
        java = {
            definition = {
                "^%s*([%w]+)[%s%*]+([%w]+)[%s%*]+([%w]+)[%s%*]+([%w_]+)%s*%(",
                "^%s*([%w]+)[%s%*]+([%w]+)[%s%*]+([%w_]+)%s*%(",
                "^%s*([%w]+)[%s%*]+([%w_]+)%s*%(",
                "^%s*class%s+([%w_]+)",
            },
        },
        cs = {
            definition = {
                "^%s*([%w]+)[%s%*]+([%w]+)[%s%*]+([%w]+)[%s%*]+([%w_]+)%s*%(",
                "^%s*([%w]+)[%s%*]+([%w]+)[%s%*]+([%w_]+)%s*%(",
                "^%s*([%w]+)[%s%*]+([%w_]+)%s*%(",
                "^%s*namespace%s+([%w%.]+)",
                "^%s*class%s+([%w_]+)",
            },
        },
    }

    local lang_patterns = patterns[lang] or patterns.lua
    local current_scope = ""

    local scope_patterns = {
        lua = {},
        php = { "^%s*namespace%s+([%w%_\\\\]+)%s*;", "^%s*class%s+([%w_]+)" },
        javascript = { "^%s*class%s+([%w_]+)" },
        typescript = { "^%s*class%s+([%w_]+)", "^%s*interface%s+([%w_]+)" },
        python = { "^%s*class%s+([%w_]+)" },
        go = { "^%s*type%s+([%w_]+)%s+struct" },
        rust = { "^%s*impl%s+%s*([%w<>]+)%s*%{", "^%s*pub%s+trait%s+([%w_]+)", "^%s*trait%s+([%w_]+)" },
        c = {},
        cpp = { "^%s*class%s+([%w_]+)", "^%s*struct%s+([%w_]+)", "^%s*namespace%s+([%w_]+)" },
        java = { "^%s*class%s+([%w_]+)", "^%s*interface%s+([%w_]+)" },
        cs = { "^%s*namespace%s+([%w%.]+)", "^%s*class%s+([%w_]+)" },
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

    for i, line in ipairs(lines) do
        -- Track scope
        local sp = scope_patterns[lang] or {}
        for _, pat in ipairs(sp) do
            local s = line:match(pat)
            if s then
                current_scope = s
                break
            end
        end

        -- Go methods: func (r Receiver) Name(...)
        local recv, fn_name = line:match("^%s*func%s+%(([%w_]+)%s+%w+%)%s+([%w_]+)")
        if recv and fn_name then
            add_result(i, line, recv .. "." .. fn_name, fn_name)
            goto continue
        end

        -- Standard definitions (use last capture group as name)
        local keywords = (lang == "javascript" or lang == "cpp") and {
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
            -- JS-only (harmless for cpp)
            ["function"]=true,  ["async"]=true,     ["await"]=true,
            ["typeof"]=true,    ["import"]=true,    ["export"]=true,
            ["in"]=true,        ["var"]=true,       ["let"]=true,
            ["this"]=true,      ["super"]=true,     ["extends"]=true,
            ["yield"]=true,     ["get"]=true,       ["set"]=true,
        } or nil
        for _, pattern in ipairs(lang_patterns.definition) do
            local captures = {line:match(pattern)}
            if #captures > 0 then
                local raw = captures[#captures]
                if raw and raw ~= "" and (not keywords or not keywords[raw]) then
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

    -- Add call counts
    for _, entry in ipairs(results) do
        local raw = entry.raw_name or entry.name:match("[^.]*$") or entry.name
        local count = 0
        for i, line in ipairs(lines) do
            if i ~= entry.line and line:match(raw .. "%s*%(") then
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
                -- Build signature: scoped_name(params...) { from raw line
                local sig = entry.text
                local start = sig:find(entry.raw_name, 1, true)
                if start then
                    sig = entry.name .. sig:sub(start + #entry.raw_name):gsub("^%s*=%s*", ""):gsub("%s+$", "")
                end
                local left = "fn(" .. entry.call_count .. ")"
                local pad = string.rep(" ", 6 - #left)
                return {
                    value = entry,
                    display = left .. pad .. " | " .. sig,
                    ordinal = entry.name .. " " .. entry.text,
                }
            end,
        }),
        sorter = require("telescope.config").values.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
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

local search_home_dirs = function()
    local home = vim.fn.expand("~")
    local dirs = {
        home,
        home .. "/mythings/study_my_code",
        home .. "/Projects/github",
        home .. "/opt_at_home",
        "/mnt/disk2/MyThings/study_my_code"
    }

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
            "--exclude", ".analysis-driver",
            "--exclude", "node_modules",
            "--exclude", "vendors",
            "--exclude", "plugins",
            "--exclude", "legal",
            ".",
            unpack(dirs)
        },

        path_display = function (_, path)
            if type(path) ~= "string" then return tostring(path) end
            local parts = vim.split(path, "/", { plain = true, trimempty = true})
            if #parts >= 2 then
                return parts[#parts - 1] .. "/" .. parts[#parts]
            end
            return path
        end,

        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                local dir = selection.value

                actions.close(prompt_bufnr)
                vim.api.nvim_set_current_dir(dir)
                builtin.find_files({ cwd = dir })
                print("Switch to " .. dir)
            end)
            return true
        end,
    })
end

vim.keymap.set('n', '<C-p>', builtin.git_files, {})
vim.keymap.set('n', '<leader>fd', search_home_dirs, { desc = "[F]ind [D]ir and jump" })
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>bf', builtin.buffers, { desc = "[B]uffer Lists"})
vim.keymap.set('n', '<leader>fn', list_functions, { desc = "[F]ind [N]unctions in file"})
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
vim.keymap.set("n", "<leader>ths", "<cmd>Telescope themes<CR>", {
    noremap = true,
    silent = true,
    desc = "Theme Switcher"
})



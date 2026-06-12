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
local function list_functions()
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local results = {}
    local lang = vim.bo.filetype

    local patterns = {
        lua = {
            definition = {
                "^%s*function%s+(%w+)",
                "^%s*local%s+function%s+(%w+)",
                "^%s*(%w+)%s*=%s*function%s*%(",
                "^%s*M%.(%w+)%s*=%s*function",
            },
            import = {
                "require%s*%(?['\"]([^'\"]+)['\"]%)?",
                "^%s*local%s+(%w+)%s*=%s*require",
            },
        },
        php = {
            definition = {
                "^%s*function%s+(%w+)",
                "^(public|private|protected|static|abstract)%s+function%s+(%w+)",
            },
            import = {
                "^%s*use%s+([%w%_\\\\]+)%s*;",
                "^%s*use%s+([%w%_\\\\]+)%s+as%s+([%w%_]+)%s*;",
                "^%s*namespace%s+([%w%_\\\\]+)%s*;",
            },
        },
        javascript = {
            definition = {
                "^%s*function%s+(%w+)",
                "^%s*const%s+(%w+)%s*=",
                "^%s*let%s+(%w+)%s*=",
                "^%s*class%s+(%w+)",
                "^%s*async%s+function%s+(%w+)",
                "^(export%s+)?const%s+(%w+)%s*=%s*%(?",
            },
            import = {
                "^%s*import%s+.*from%s+['\"]([^'\"]+)['\"]",
                "^%s*const%s+(%w+)%s*=%s*require%(%s*['\"]([^'\"]+)['\"]",
            },
        },
        typescript = {
            definition = {
                "^%s*function%s+(%w+)",
                "^%s*const%s+(%w+)%s*=",
                "^%s*class%s+(%w+)",
                "^%s*interface%s+(%w+)",
                "^%s*type%s+(%w+)",
                "^%s*async%s+function%s+(%w+)",
            },
            import = {
                "^%s*import%s+.*from%s+['\"]([^'\"]+)['\"]",
                "^%s*import%s+{.*}%s+from%s+['\"]([^'\"]+)['\"]",
            },
        },
        python = {
            definition = {
                "^%s*def%s+(%w+)",
                "^%s*async%s+def%s+(%w+)",
                "^%s*class%s+(%w+)",
            },
            import = {
                "^%s*import%s+(%w+)",
                "^%s*from%s+(%w+)%s+import",
            },
        },
        go = {
            definition = {
                "^%s*func%s+(%w+)%s*%(",
                "^%s*func%s+%((%w+)%s+%w+%)%s+(%w+)",
            },
            import = {
                "^%s*import%s+%(.",
                "^%s*import%s+[\"]([^\"]+)[\"]",
            },
        },
        rust = {
            definition = {
                "^%s*fn%s+(%w+)",
                "^%s*pub%s+fn%s+(%w+)",
                "^%s*impl%s+",
            },
            import = {
                "^%s*use%s+([^;]+)",
            },
        },
        c = {
            definition = {
                "^(void|int|char|float|double|struct|enum|typedef)%s+%w+%s*%(",
                "^%s*static%s+(void|int|char|float|double)%s+%w+%s*%(",
                "^%s*(void|int|char|float|double)%s+%w+%s*%(",
            },
            import = {
                "^%s*#include%s+[<\"]([^>\"]+)[>\"]",
            },
        },
        cpp = {
            definition = {
                "^[%w:]+%s+[%w:]+%s*%(",
                "^%s*void%s+[%w:]+%s*%(",
                "^%s*int%s+[%w:]+%s*%(",
                "^%s*class%s+[%w:]+",
                "^%s*struct%s+[%w:]+",
                "^%s*public:%s*$",
                "^%s*private:%s*$",
                "^%s*protected:%s*$",
            },
            import = {
                "^%s*#include%s+[<\"][^>]+[>\"]",
                "^%s*using%s+namespace%s+[%w_]+",
            },
        },
        java = {
            definition = {
                "^%s*(public|private|protected|static)%s+(void|int|String|boolean|class|interface)%s+%w+%s*%(",
                "^%s*(public|private|protected)%s+class%s+(%w+)",
                "^%s*(public|private|protected)%s+interface%s+(%w+)",
                "^%s*void%s+%w+%s*%(",
                "^%s*class%s+(%w+)",
            },
            import = {
                "^%s*import%s+([%w%.]+)%s*;",
            },
        },
        cs = {
            definition = {
                "^(public|private|protected|internal|static)%s+(void|int|string|bool|class|interface|struct|enum)%s+%w+%s*%(",
                "^%s*namespace%s+([%w%.]+)",
                "^%s*class%s+(%w+)",
            },
            import = {
                "^%s*using%s+([%w%.]+)%s*;",
            },
        },
    }

    local lang_patterns = patterns[lang] or patterns.lua
    local line_has_entry = {}

    for i, line in ipairs(lines) do
        for _, pattern in ipairs(lang_patterns.definition) do
            local match = line:match(pattern)
            if match then
                table.insert(results, {
                    line = i,
                    text = line:match("^%s*(.-)%s*$"),
                    name = match,
                    type = "fn",
                })
                line_has_entry[i] = true
                break
            end
        end
    end

    for i, line in ipairs(lines) do
        if not line_has_entry[i] then
            for _, pattern in ipairs(lang_patterns.import) do
                local match = line:match(pattern)
                if match then
                    table.insert(results, {
                        line = i,
                        text = line:match("^%s*(.-)%s*$"),
                        name = match,
                        type = "import",
                    })
                    break
                end
            end
        end
    end

    require("telescope.pickers")
    .new({}, {
        prompt_title = "Functions in file",
        finder = require("telescope.finders").new_table({
            results = results,
            entry_maker = function(entry)
                local icon = entry.type == "fn" and "fn " or "-> "
                return {
                    value = entry,
                    display = icon .. entry.name .. " │ " .. entry.text:sub(1, 60),
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

    builtin.find_files({
        prompt_title = "jump to home",
        cwd = home,
        find_command = {
            "fd",
            "--type", "d",
            "--hidden",
            "--max-depth", "6",
            "--exclude", ".git",
            "--exclude", ".gitignore",
            "--exclude", ".cache",
            "--exclude", "node_modules",
            "--exclude", "vendors",
            "--exclude", ".android",
            "--exclude", ".bash_history",
            "--exclude", ".bash_logout",
            "--exclude", ".cache",
            "--exclude", ".cargo",
            "--exclude", ".dart-tool",
            "--exclude", ".dartServer",
            "--exclude", ".face",
            "--exclude", ".face.icon",
            "--exclude", ".flutter",
            "--exclude", ".fzf",
            "--exclude", ".gitconfig",
            "--exclude", ".gnupg",
            "--exclude", ".gradle",
            "--exclude", ".gtkrc-2.0",
            "--exclude", ".mozilla",
            "--exclude", ".npm",
            "--exclude", ".nvim",
            "--exclude", ".pki",
            "--exclude", ".profile",
            "--exclude", ".pub-cache",
            "--exclude", ".rustup",
            "--exclude", ".ssh",
            "--exclude", ".sudo_as_admin_successful",
            "--exclude", ".var",
            "--exclude", ".wget-hsts",
            "."
        },
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)

                local dir = home .. "/" .. selection.value

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


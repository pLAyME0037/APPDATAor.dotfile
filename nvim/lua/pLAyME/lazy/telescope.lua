return {
    {
        "nvim-telescope/telescope.nvim",
        branch = "master", -- using master to fix issues with deprecated to definition warnings
        -- '0.1.x' for stable ver.
        dependencies = {
            "nvim-lua/plenary.nvim",
            { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
            "nvim-tree/nvim-web-devicons",
            "andrew-george/telescope-themes",
        },
        config = function()
            local telescope    = require("telescope")
            local actions      = require("telescope.actions")
            local action_state = require("telescope.actions.state")
            local builtin      = require("telescope.builtin")


            telescope.setup({
                defaults = {
                    path_display = { "smart" },
                    sorting_strategy = "descending",
                    layout_config = { prompt_position = "bottom" },
                    -- height = 0.80,
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
                        sort_mru = true, -- Sort by Most recently use
                        mappings = {
                            i = { ["<C-d>"] = actions.delete_buffer, },
                            n = { ["dd"] = actions.delete_buffer, },
                        }
                    }
                },
            })

            telescope.load_extension("fzf")
            telescope.load_extension("themes")

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

            -- Keymaps
            vim.keymap.set('n', '<C-p>', builtin.git_files, {})
            vim.keymap.set('n', '<leader>fd', search_home_dirs, { desc = "[F]ind [D]ir and jump" })
            vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
            vim.keymap.set('n', '<leader>bf', builtin.buffers, { desc = "[B]uffer Lists"})
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
        end,
    }

    -- for windows build with visual studio
    -- {
    --     'nvim-telescope/telescope-fzf-native.nvim',
    --     -- If you have CMake and Visual Studio installed, use this:
    --     build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build'
    -- }
}



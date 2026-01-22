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
            local telescope = require("telescope")
            local actions = require("telescope.actions")
            local builtin = require("telescope.builtin")


            telescope.setup({
                defaults = {
                    path_display = { "smart" },
                    mappings = {
                        i = {
                            ["<C-k>"] = actions.move_selection_previous,
                            ["<C-j>"] = actions.move_selection_next,
                        },
                    },
                },
                extensions = {
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

            -- Keymaps
        vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
        vim.keymap.set('n', '<C-p>', builtin.git_files, {})
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
    },

   -- {
   --      'nvim-telescope/telescope-fzf-native.nvim',
   --      -- If you have CMake and Visual Studio installed, use this:
   --      build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build'
   --  }
}

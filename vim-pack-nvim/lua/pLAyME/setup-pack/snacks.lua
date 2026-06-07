return {
    {
        src = "https://github.com/folke/snacks.nvim",
        priority = 1000,
        lazy = false,
        config = function()
            require("snacks").setup({
                styles = {
                    input = {
                        keys = {
                            n_esc = { "<C-c>", { "cmp_close", "cancel" }, mode = "n", expr = true },
                            i_esc = { "<C-c>", { "cmp_close", "stopinsert" }, mode = "i", expr = true },
                        },
                    }
                },
                input = { enabled = true },
                quickfile = {
                    enabled = true,
                    exclude = { "latex" },
                },
                picker = {
                    enabled = true,
                    matchers = {
                        frecency = true,
                        cwd_bonus = false,
                    },
                    exclude = {
                        ".git",
                        "node_modules",
                        "dist",
                        "build",
                    },
                    formatters = {
                        file = {
                            filename_first = true,
                            filename_only = false,
                            icon_width = 2,
                        },
                    },
                    layout = {
                        preset = "telescope",
                        cycle = false,
                    },
                    layouts = {
                        select = {
                            preview = false,
                            layout = {
                                backdrop = false,
                                width = 0.6,
                                min_width = 80,
                                height = 0.4,
                                min_height = 10,
                                box = "vertical",
                                border = "rounded",
                                title = "{title}",
                                title_pos = "center",
                                { win = "input", height = 1, border = "bottom" },
                                { win = "list", border = "none" },
                                { win = "preview", title = "{preview}", width = 0.6, height = 0.4, border = "top" },
                            }
                        },
                        telescope = {
                            reverse = true,
                            layout = {
                                box = "horizontal",
                                backdrop = false,
                                width = 0.8,
                                height = 0.9,
                                border = "none",
                                {
                                    box = "vertical",
                                    { win = "list", title = " Results ", title_pos = "center", border = "rounded" },
                                    { win = "input", height = 1, border = "rounded", title = "{title} {live} {flags}", title_pos = "center" },
                                },
                                {
                                    win = "preview",
                                    title = "{preview:Preview}",
                                    width = 0.50,
                                    border = "rounded",
                                    title_pos = "center",
                                },
                            },
                        },
                        ivy = {
                            layout = {
                                box = "vertical",
                                backdrop = false,
                                width = 0,
                                height = 0.4,
                                position = "bottom",
                                border = "top",
                                title = " {title} {live} {flags}",
                                title_pos = "left",
                                { win = "input", height = 1, border = "bottom" },
                                {
                                    box = "horizontal",
                                    { win = "list", border = "none" },
                                    { win = "preview", title = "{preview}", width = 0.5, border = "left" },
                                },
                            },
                        },
                    }
                },
            })

            vim.keymap.set("n", "<leader>lg", function() require("snacks").lazygit() end, { desc = "Lazygit" })
            vim.keymap.set("n", "<leader>gl", function() require("snacks").lazygit.log() end, { desc = "Lazygit Logs" })
            vim.keymap.set("n", "<leader>gbr", function() require("snacks").picker.git_branches({ layout = "select" }) end, { desc = "Pick and Switch Git Branches" })
        end,
    },
}

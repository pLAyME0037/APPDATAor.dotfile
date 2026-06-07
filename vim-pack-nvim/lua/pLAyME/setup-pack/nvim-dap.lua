return {
    src = "https://github.com/mfussenegger/nvim-dap",
    dependencies = {
        -- UI enhancements
        "https://github.com/rcarriga/nvim-dap-ui",
        "https://github.com/theHamsta/nvim-dap-virtual-text",
        "https://github.com/nvim-neotest/nvim-nio",

        -- Mason integration to manage debug adapters
        "https://github.com/williamboman/mason.nvim",
        "https://github.com/jay-babu/mason-nvim-dap.nvim",

        -- Add specific language extensions if you want simpler setup for them
        "https://github.com/leoluz/nvim-dap-go", -- Optional: better Go support
    },
    config = function()
        local dap = require("dap")
        local dapui = require("dapui")

        -- 1. Setup UI
        dapui.setup()
        require("nvim-dap-virtual-text").setup({})

        -- Open UI automatically when debugging starts
        dap.listeners.before.attach.dapui_config = function() dapui.open() end
        dap.listeners.before.launch.dapui_config = function() dapui.open() end
        dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
        dap.listeners.before.event_exited.dapui_config = function() dapui.close() end

        -- 2. Setup Mason Integration
        require("mason-nvim-dap").setup({
            -- Ensures these adapters are installed automatically
            ensure_installed = {
                "codelldb", -- C, C++, Rust
                "python",   -- Python (debugpy)
                "delve",    -- Go
                "node2",    -- Node.js (older but reliable) or 'js'
                "php",      -- PHP
                "coreclr",  -- C# (netcoredbg)
                "javadbg",  -- Java
            },
            handlers = {
                -- Default handler: Setup adapter with default settings
                function(config)
                    require("mason-nvim-dap").default_setup(config)
                end,

                -- Custom handler for Java (complex, usually needs nvim-jdtls, but this is a fallback)
                javadbg = function(config)
                    config.adapters = {
                        type = 'executable',
                        command = 'java-debug-adapter',
                        name = "java"
                    }
                    require('mason-nvim-dap').default_setup(config)
                end,

                -- Custom handler for Python (if you need specific python paths)
                python = function(config)
                    config.adapters = {
                        type = "executable",
                        command = "/usr/bin/python3",
                        args = { "-m", "debugpy.adapter" },
                    }
                    require('mason-nvim-dap').default_setup(config)
                end,
            },
        })

        -- 3. Language Specific Configurations

        -- C, C++, Rust (via codelldb)
        dap.configurations.cpp = {
            {
                name = "Launch file",
                type = "codelldb",
                request = "launch",
                program = function()
                    return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
                end,
                cwd = "${workspaceFolder}",
                stopOnEntry = false,
            },
        }
        -- Reuse C++ config for C and Rust
        dap.configurations.c = dap.configurations.cpp
        dap.configurations.rust = dap.configurations.cpp

        -- Go
        -- (Requires 'delve' to be installed)
        dap.configurations.go = {
            {
                type = "go",
                name = "Debug",
                request = "launch",
                program = "${file}",
            },
        }

        -- Python
        dap.configurations.python = {
            {
                type = "python",
                request = "launch",
                name = "Launch file",
                program = "${file}",
                pythonPath = function()
                    return "/usr/bin/python3" -- Adjust to your venv if needed
                end,
            },
        }

        -- Javascript / Typescript (Node)
        dap.configurations.javascript = {
            {
                type = "node2",
                request = "launch",
                program = "${file}",
                cwd = vim.fn.getcwd(),
                sourceMaps = true,
                protocol = "inspector",
                console = "integratedTerminal",
            },
        }
        dap.configurations.typescript = dap.configurations.javascript

        -- PHP
        dap.configurations.php = {
            {
                type = "php",
                request = "launch",
                name = "Listen for Xdebug",
                port = 9003,
            },
        }

        -- C#
        dap.configurations.cs = {
            {
                type = "coreclr",
                name = "launch - netcoredbg",
                request = "launch",
                program = function()
                    return vim.fn.input('Path to dll: ', vim.fn.getcwd() .. '/bin/Debug/', 'file')
                end,
            },
        }

        -- 4. Keybindings
        vim.keymap.set("n", "<F5>", dap.continue, { desc = "Debug: Start/Continue" })
        vim.keymap.set("n", "<F1>", dap.step_into, { desc = "Debug: Step Into" })
        vim.keymap.set("n", "<F2>", dap.step_over, { desc = "Debug: Step Over" })
        vim.keymap.set("n", "<F3>", dap.step_out, { desc = "Debug: Step Out" })
        vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint, { desc = "Debug: Toggle Breakpoint" })
        vim.keymap.set("n", "<leader>B", function()
            dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
        end, { desc = "Debug: Set Conditional Breakpoint" })

        -- Toggle UI manually if needed
        vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "Debug: Toggle UI" })
    end,
}

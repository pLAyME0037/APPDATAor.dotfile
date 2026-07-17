vim.schedule(function()
    local dap   = require("dap")
    local dapui = require("dapui")

    -- Open UI automatically when session starts (either launch or attach)
    dap.listeners.after.event_initialized.dapui_config = function() dapui.open() end
    dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
    dap.listeners.before.event_exited.dapui_config     = function() dapui.close() end

    -- Sign Definitions
    vim.fn.sign_define('DapBreakpoint', {
        text = '⚪',
        texthl = 'DapBreakpointSymbol',
        linehl = 'DapBreakpoint',
        numhl = 'DapBreakpoint'
    })
    vim.fn.sign_define('DapStopped', {
        text = '🔴',
        texthl = 'yellow',
        linehl = 'DapBreakpoint',
        numhl = 'DapBreakpoint'
    })
    vim.fn.sign_define('DapBreakpointRejected', {
        text = '⭕',
        texthl = 'DapStoppedSymbol',
        linehl = 'DapBreakpoint',
        numhl = 'DapBreakpoint'
    })

    -- ----------------------------------------------------
    -- 1. ADAPTER DEFINITIONS
    -- ----------------------------------------------------
    -- local codelldb_bin = vim.fn.stdpath("data") .. "/mason/bin/codelldb"
    -- dap.adapters.codelldb = {
    --     type = "server",
    --     port = "${port}",
    --     executable = {
    --         command = codelldb_bin,
    --         args = { "--port", "${port}" },
    --     }
    -- }

    -- local netcoredbg = vim.fn.stdpath("data") .. "/mason/packages/netcoredbg/netcoredbg"
    -- local netcoredbg_adapter = {
    --     type = "executable",
    --     command = netcoredbg,
    --     args = { "--interpreter=vscode" },
    -- }
    -- dap.adapters.netcoredbg = netcoredbg_adapter
    -- dap.adapters.coreclr = netcoredbg_adapter

    require("mason-nvim-dap").setup({
        automatic_setup = true,
        handlers = {}, -- Required for automatic setup to register adapters properly
        ensure_installed = { "codelldb" }, -- Forces Mason to download codelldb if missing
    })

    -- ----------------------------------------------------
    -- 2. LANGUAGE CONFIGURATIONS
    -- ----------------------------------------------------

    -- C#
    dap.configurations.cs = {
        {
            type = "coreclr",
            name = "LAUNCH directly from nvim",
            request = "launch",
            -- console = "integratedTerminal",
            runInTerminal = true,
            program = function()
                return vim.fn.input("Path to exec: ", vim.fn.getcwd() .. "/", "file")
            end
        },
    }

    -- C, C++, Rust
    dap.configurations.cpp = {
        {
            name = "Launch Executable",
            type = "codelldb",
            request = "launch",
            program = function()
                return vim.fn.input("Path to exec: ", vim.fn.getcwd() .. "/", "file")
            end,
            cwd = "${workspaceFolder}",
            stopOnEntry = false,
        },
    }
    dap.configurations.c = dap.configurations.cpp
    dap.configurations.rust = dap.configurations.cpp

    -- NOTE on Python, Go, PHP, Node:
    -- If you are not defining manual adapters for these, it is highly recommended
    -- to call `require("mason-nvim-dap").setup({ automatic_setup = true })`
    -- earlier in your config so it automatically registers `python`, `go`, `php`, etc.

    dap.configurations.go = {
        {
            type = "go",
            name = "Debug",
            request = "launch",
            console = "integratedTerminal",
            program = "${file}",
        },
    }

    dap.configurations.python = {
        {
            type = "python",
            request = "launch",
            console = "integratedTerminal",
            name = "Launch file",
            program = "${file}",
            pythonPath = function()
                return "/usr/bin/python3"
            end,
        },
    }

    dap.configurations.javascript = {
        {
            type = "node2",
            request = "launch",
            program = "${file}",
            cwd = vim.fn.getcwd(),
            sourceMaps = true,
            protocol = "inspector",
        },
    }
    dap.configurations.typescript = dap.configurations.javascript

    dap.configurations.php = {
        {
            type = "php",
            request = "launch",
            console = "integratedTerminal",
            name = "Listen for Xdebug",
            port = 9003,
        },
    }

    -- ----------------------------------------------------
    -- 3. DAP UI & OTHER PLUGINS
    -- ----------------------------------------------------
    dapui.setup({
        expand_lines = true,
        controls = { enabled = false },
        floating = { border = "rounded" },

        -- Set dapui window
        render = {
            max_type_length = 60,
            max_value_lines = 200,
        },

        layouts = {
            -- Left Panel: Houses scopes and stacks vertically
            {
                elements = {
                    { id = "scopes", size = 0.56 }, -- height of left panel
                    { id = "stacks", size = 0.44 }, -- height of left panel
                },
                size = 60,                         -- WIDTH of the left panel in columns
                position = "left",                 -- Left side of screen
            },
            -- Bottom Panel: Houses REPL and console side-by-side
            {
                elements = {
                    { id = "repl", size = 0.5 },    -- 50% width of bottom panel
                    { id = "console", size = 0.5 }, -- 50% width of bottom panel
                },
                size = 15,                         -- HEIGHT of the bottom panel in lines
                position = "bottom",               -- Bottom of screen
            },
        },
    })

    require('lualine').setup({
        options = {
            globalstatus = true, -- Single statusline for the entire Neovim window
        }
    })

    local neotest = require("neotest")
    neotest.setup({
        adapters = {
            require("neotest-dotnet"),
        }
    })

    -- Keymaps
    vim.keymap.set("n", "<F5>",  dap.continue, { desc = "Debug: Start/Continue" })
    vim.keymap.set("n", "<F6>",  function() neotest.run.run({ strategy = "dap" }) end, { desc = "Debug nearest test"})
    vim.keymap.set("n", "<F9>",  dap.toggle_breakpoint, { desc = "DAP: Toggle breakpoint" })
    vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Debug: Step Into" })
    vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Debug: Step Over" })
    vim.keymap.set("n", "<F8>",  dap.step_out, { desc = "Debug: Step Out" })

    vim.keymap.set("n", "<leader>dr", dap.repl.open, { desc = "DAP: REPL open" })
    vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = "DAP: Run last" })
    vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "Debug: Toggle UI" })

    vim.keymap.set({ "n", "v" }, "Q", function() dapui.eval() end, { desc = "DAP Peek"})
    vim.keymap.set(
        { "n", "v" }, "<leader>dw",
        function() dapui.eval(nil, { enter = true }) end,
        { desc = "DAP Add word under cursor to Watches"}
    )
end)

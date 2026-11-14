vim.schedule(function()
    local dap = require("dap")
    local Session = require("dap.session")

    local ok_dapui, dapui = pcall(require, "dapui")
    local ok_dap_view, dap_view = pcall(require, "dap-view")
    local ok_disasm, dap_disasm = pcall(require, "dap-disasm")
    local ok_memview, dap_memview = pcall(require, "dap-memview")
    local ok_neotest, neotest = pcall(require, "neotest")

    -- Sign Definitions
    vim.fn.sign_define("DapBreakpoint", {
        text = "⚪",
        texthl = "DapBreakpointSymbol",
        linehl = "DapBreakpoint",
        numhl = "DapBreakpoint",
    })
    vim.fn.sign_define("DapStopped", {
        text = "🔴",
        texthl = "yellow",
        linehl = "DapBreakpoint",
        numhl = "DapBreakpoint",
    })
    vim.fn.sign_define("DapBreakpointRejected", {
        text = "⭕",
        texthl = "DapStoppedSymbol",
        linehl = "DapBreakpoint",
        numhl = "DapBreakpoint",
    })

    local last_cli_args = ""

    local function parse_cli_args(raw)
        local args = {}
        local current = {}
        local in_single = false
        local in_double = false
        local escaped = false
        local has_token = false

        for i = 1, #raw do
            local ch = raw:sub(i, i)
            if escaped then
                table.insert(current, ch)
                escaped = false
                has_token = true
            elseif ch == "\\" and not in_single then
                escaped = true
                has_token = true
            elseif ch == "'" and not in_double then
                in_single = not in_single
                has_token = true
            elseif ch == '"' and not in_single then
                in_double = not in_double
                has_token = true
            elseif ch:match("%s") and not in_single and not in_double then
                if has_token then
                    table.insert(args, table.concat(current))
                    current = {}
                    has_token = false
                end
            else
                table.insert(current, ch)
                has_token = true
            end
        end

        if in_single or in_double or escaped then
            return nil, "Unterminated quote or trailing escape in arguments"
        end

        if has_token then
            table.insert(args, table.concat(current))
        end

        return args, nil
    end

    local function prompt_exec_path()
        local sentinel = "__DAP_ABORT__"
        local exec_path = vim.fn.input({
            prompt = "Path to exec: ",
            default = vim.fn.getcwd() .. "/",
            completion = "file",
            cancelreturn = sentinel,
        })
        if exec_path == sentinel or vim.trim(exec_path) == "" then
            return dap.ABORT
        end
        return exec_path
    end

    local function prompt_cli_args()
        local sentinel = "__DAP_ABORT__"
        local raw = vim.fn.input({
            prompt = "Arguments: ",
            default = last_cli_args,
            cancelreturn = sentinel,
        })
        if raw == sentinel then
            return dap.ABORT
        end
        local parsed, err = parse_cli_args(raw)
        if err ~= nil then
            vim.notify(err, vim.log.levels.ERROR)
            return dap.ABORT
        end
        last_cli_args = raw
        return parsed
    end

    -- ----------------------------------------------------
    -- 1. ADAPTER DEFINITIONS
    -- ----------------------------------------------------
    require("mason-nvim-dap").setup({
        automatic_setup = true,
        handlers = {},
        ensure_installed = { "codelldb" },
    })

    local ok_dap_go, dap_go = pcall(require, "dap-go")
    if ok_dap_go then
        dap_go.setup()
    end

    -- ----------------------------------------------------
    -- 2. LANGUAGE CONFIGURATIONS
    -- ----------------------------------------------------
    dap.configurations.lua = {
        {
            type = "nlua",
            request = "attach",
            name = "Attach to running Neovim instance",
            host = function() return "127.0.0.1" end,
            port = function()
                local val = 54231
                return val
            end
        }
    }

    dap.configurations.cs = {
        {
            type = "coreclr",
            name = "LAUNCH directly from nvim",
            request = "launch",
            runInTerminal = true,
            program = prompt_exec_path,
        },
    }

    dap.configurations.cpp = {
        {
            name = "Launch Executable",
            type = "codelldb",
            request = "launch",
            program = prompt_exec_path,
            cwd = "${workspaceFolder}",
            stopOnEntry = false,
        },
        {
            name = "Launch Executable (with args)",
            type = "codelldb",
            request = "launch",
            program = prompt_exec_path,
            args = prompt_cli_args,
            cwd = "${workspaceFolder}",
            stopOnEntry = false,
        },
    }
    dap.configurations.c = dap.configurations.cpp
    dap.configurations.rust = dap.configurations.cpp

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
    -- 3. UI SETUP (nvim-dap-view + nvim-dap-disasm + Q eval)
    -- ----------------------------------------------------
    if ok_dapui then
        dapui.setup({
            expand_lines = true,
            controls = { enabled = false },
            floating = { border = "rounded" },
            render = {
                max_type_length = 60,
                max_value_lines = 200,
            },
        })
    end

    local dap_sections = {
        "scopes",
        "watches",
        "threads",
        "breakpoints",
        "console",
        "repl",
    }
    if ok_disasm then
        table.insert(dap_sections, "disassembly")
    end

    if ok_dap_view then
        dap_view.setup({
            winbar = {
                show            = true,
                sections        = dap_sections,
                default_section = "scopes",
                controls        = {
                    enabled     = true,
                    position    = "right",
                },
            },
            windows = {
                size            = 0.28,
                position        = "below",
            },
            auto_toggle         = true,
        })
    end

    if ok_memview then dap_memview.setup({}) end

    if ok_disasm then
        dap_disasm.setup({
            dapui_register    = false,
            dapview_register  = true,
            dapview           = {
                keymap        = "D",
                label         = "Disassembly [D]",
                short_label   = "󰒓 [D]",
            },
            sign              = "DapStopped",
            ins_before_memref = 16,
            ins_after_memref  = 16,
            columns           = {
                "address",
                "instructionBytes",
                "instruction",
            },
        })
    end

    if ok_neotest then
        neotest.setup({
            adapters = {
                require("neotest-dotnet"),
            },
        })
    end

    -- ----------------------------------------------------
    -- 4a. RAD-DEBUGGER WORKFLOW HELPERS
    -- ----------------------------------------------------
    local assembly_mode = false
    local hex_mode = false
    local current_tab_idx = 1

    local view_tabs = {
        { id = "scopes",      key = "S" },
        { id = "watches",     key = "W" },
        { id = "threads",     key = "T" },
        { id = "breakpoints", key = "B" },
        { id = "console",     key = "C" },
        { id = "repl",        key = "R" },
    }
    if ok_disasm then
        table.insert(view_tabs, { id = "disassembly", key = "D" })
    end

    local dap_filetypes = {
        ["dap-view"]          = true,
        ["dap-view-term"]     = true,
        ["dap-repl"]          = true,
        ["dap-disasm"]        = true,
        ["dapui_scopes"]      = true,
        ["dapui_watches"]     = true,
        ["dapui_stacks"]      = true,
        ["dapui_breakpoints"] = true,
        ["dapui_console"]     = true,
    }

    local function is_dap_filetype(ft)
        if type(ft) ~= "string" then
            return false
        end
        if dap_filetypes[ft] then
            return true
        end
        return false
    end

    local function find_dap_win(prefer_winbar)
        local wins = vim.api.nvim_tabpage_list_wins(0)
        if prefer_winbar then
            for _, win in ipairs(wins) do
                local buf = vim.api.nvim_win_get_buf(win)
                local ft = vim.bo[buf].filetype
                if ft == "dap-view" or ft == "dap-disasm" then
                    return win
                end
            end
            return nil
        end

        for _, win in ipairs(wins) do
            local buf = vim.api.nvim_win_get_buf(win)
            local ft = vim.bo[buf].filetype
            if is_dap_filetype(ft) then
                return win
            end
        end
        return nil
    end

    local function sync_tab_index(target_id)
        for idx, tab in ipairs(view_tabs) do
            if tab.id == target_id then
                current_tab_idx = idx
                return
            end
        end
    end

    local function switch_dap_view(target_id, target_key)
        if not ok_dap_view then
            vim.notify("nvim-dap-view is not loaded", vim.log.levels.WARN)
            return
        end

        local orig_win = vim.api.nvim_get_current_win()
        local orig_buf = vim.api.nvim_win_get_buf(orig_win)
        local was_in_dap = is_dap_filetype(vim.bo[orig_buf].filetype)

        if find_dap_win(false) == nil then
            pcall(dap_view.open)
        end

        sync_tab_index(target_id)

        if type(dap_view.show_view) == "function" then
            local ok_sv = pcall(dap_view.show_view, target_id)
            if ok_sv then
                return
            end
        end

        local dap_win = find_dap_win(true)
        if dap_win == nil then
            dap_win = find_dap_win(false)
        end
        if dap_win == nil or not vim.api.nvim_win_is_valid(dap_win) then
            return
        end

        vim.api.nvim_set_current_win(dap_win)
        local mode = vim.api.nvim_get_mode().mode
        if mode:sub(1, 1) == "t" then
            local esc = vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true)
            vim.api.nvim_feedkeys(esc, "nx", false)
        elseif mode:sub(1, 1) == "i" then
            vim.cmd("stopinsert")
        end

        vim.api.nvim_feedkeys(target_key, "mx", false)

        if not was_in_dap and vim.api.nvim_win_is_valid(orig_win) then
            vim.cmd("stopinsert")
            vim.api.nvim_set_current_win(orig_win)
        end
    end

    local function cycle_dap_tab()
        local ok_state, dv_state = pcall(require, "dap-view.state")
        if ok_state and type(dv_state) == "table" and type(dv_state.current_section) == "string" then
            sync_tab_index(dv_state.current_section)
        end

        current_tab_idx = (current_tab_idx % #view_tabs) + 1
        local next_tab = view_tabs[current_tab_idx]
        switch_dap_view(next_tab.id, next_tab.key)
    end

    local function toggle_fullscreen_element()
        if vim.t.dap_fullscreen_tab == true then
            if vim.fn.tabpagenr("$") > 1 then
                vim.t.dap_fullscreen_tab = nil
                pcall(vim.cmd, "tabclose")
            else
                vim.t.dap_fullscreen_tab = nil
                vim.notify("No layout tab to return to", vim.log.levels.WARN)
            end
            return
        end

        local wins = vim.api.nvim_tabpage_list_wins(0)
        if #wins <= 1 then
            vim.notify("Already in single-window view", vim.log.levels.INFO)
            return
        end

        vim.cmd("tab split")
        vim.t.dap_fullscreen_tab = true
    end

    local function toggle_assembly_mode()
        assembly_mode = not assembly_mode
        if assembly_mode then
            if not ok_disasm then
                assembly_mode = false
                vim.notify("nvim-dap-disasm not installed; run :PackUpdate", vim.log.levels.WARN)
                return
            end
            if find_dap_win() ~= nil or dap.session() ~= nil then
                switch_dap_view("disassembly", "D")
            end
            vim.notify("DAP Assembly Mode: ON (instruction stepping)", vim.log.levels.INFO)
        else
            if find_dap_win() ~= nil or dap.session() ~= nil then
                switch_dap_view("scopes", "S")
            end
            vim.notify("DAP Assembly Mode: OFF (statement stepping)", vim.log.levels.INFO)
        end
    end

    local function is_pointer_type(var_type)
        if type(var_type) ~= "string" then
            return false
        end
        local lower = var_type:lower()
        if lower:find("%*") or lower:find("ptr") or lower:find("pointer") or lower:find("addr") then
            return true
        end
        return false
    end

    local function u53_to_hex(num)
        if num == 0 then
            return "0x0"
        end
        local lo = num % 4294967296
        local hi = math.floor(num / 4294967296)
        if hi > 0 then
            return string.format("0x%x%08x", hi, lo)
        end
        return string.format("0x%x", lo)
    end

    local function format_int_value(val, to_hex, var_type)
        if type(val) ~= "string" then
            return val
        end
        local trimmed = vim.trim(val)
        if to_hex then
            local sign, digits = trimmed:match("^(-?)(%d+)$")
            if digits then
                local num = tonumber(digits)
                if num and num <= 9007199254740991 then
                    local hex_str = u53_to_hex(num)
                    if sign == "-" and num > 0 then
                        return "-" .. hex_str
                    end
                    return hex_str
                end
            end
        else
            if is_pointer_type(var_type) then
                return val
            end
            local sign, hex_digits = trimmed:match("^(-?)0[xX](%x+)$")
            if hex_digits then
                local num = tonumber(hex_digits, 16)
                if num and num <= 9007199254740991 then
                    if sign == "-" and num > 0 then
                        return string.format("-%.0f", num)
                    end
                    return string.format("%.0f", num)
                end
            end
        end
        return val
    end

    if not Session._hex_format_patched then
        Session._hex_format_patched = true
        local orig_request = Session.request
        Session.request = function(self, command, arguments, callback)
            local args = arguments
            if command == "variables" or command == "evaluate" then
                local caps = self.capabilities
                if type(caps) == "table" and caps.supportsValueFormattingOptions then
                    local base = {}
                    if type(arguments) == "table" then
                        base = arguments
                    end
                    args = vim.tbl_extend("force", base, {
                        format = { hex = hex_mode },
                    })
                end
            end
            return orig_request(self, command, args, callback)
        end
    end

    dap.listeners.before.variables["hex_mode_formatter"] = function(session, err, response)
        if err or type(response) ~= "table" or type(response.variables) ~= "table" then
            return
        end
        local caps = nil
        if session then
            caps = session.capabilities
        end
        local native_hex = type(caps) == "table" and caps.supportsValueFormattingOptions == true
        if not hex_mode and native_hex then
            return
        end
        for _, var in ipairs(response.variables) do
            if type(var) == "table" and type(var.value) == "string" then
                if hex_mode then
                    var.value = format_int_value(var.value, true, var.type)
                elseif type(var.type) == "string" then
                    var.value = format_int_value(var.value, false, var.type)
                end
            end
        end
    end

    dap.listeners.before.evaluate["hex_mode_formatter"] = function(session, err, response)
        if err or type(response) ~= "table" or type(response.result) ~= "string" then
            return
        end
        local caps = nil
        if session then
            caps = session.capabilities
        end
        local native_hex = type(caps) == "table" and caps.supportsValueFormattingOptions == true
        if not hex_mode and native_hex then
            return
        end
        if hex_mode then
            response.result = format_int_value(response.result, true, response.type)
        elseif type(response.type) == "string" then
            response.result = format_int_value(response.result, false, response.type)
        end
    end

    local function format_int_value(val, to_hex, var_type)
        if type(val) ~= "string" then
            return val
        end
        local trimmed = vim.trim(val)
        if to_hex then
            local sign, digits = trimmed:match("^(-?)(%d+)$")
            if digits then
                local num = tonumber(digits)
                if num and num <= 9007199254740991 then
                    if sign == "-" and num > 0 then
                        return string.format("-0x%x", num)
                    end
                    return string.format("0x%x", num)
                end
            end
        else
            if is_pointer_type(var_type) then
                return val
            end
            local sign, hex_digits = trimmed:match("^(-?)0[xX](%x+)$")
            if hex_digits then
                local num = tonumber(hex_digits, 16)
                if num and num <= 9007199254740991 then
                    if sign == "-" and num > 0 then
                        return string.format("-%d", num)
                    end
                    return string.format("%d", num)
                end
            end
        end
        return val
    end

    if not Session._hex_format_patched then
        Session._hex_format_patched = true
        local orig_request = Session.request
        Session.request = function(self, command, arguments, callback)
            local args = arguments
            if command == "variables" or command == "evaluate" then
                local caps = self.capabilities
                if type(caps) == "table" and caps.supportsValueFormattingOptions then
                    local base = {}
                    if type(arguments) == "table" then
                        base = arguments
                    end
                    args = vim.tbl_extend("force", base, {
                        format = { hex = hex_mode },
                    })
                end
            end
            return orig_request(self, command, args, callback)
        end
    end

    dap.listeners.before.variables["hex_mode_formatter"] = function(session, err, response)
        if err or type(response) ~= "table" or type(response.variables) ~= "table" then
            return
        end
        local caps = nil
        if session then
            caps = session.capabilities
        end
        local native_hex = type(caps) == "table" and caps.supportsValueFormattingOptions == true
        if not hex_mode and native_hex then
            return
        end
        for _, var in ipairs(response.variables) do
            if type(var) == "table" and type(var.value) == "string" then
                if hex_mode then
                    var.value = format_int_value(var.value, true, var.type)
                elseif type(var.type) == "string" then
                    var.value = format_int_value(var.value, false, var.type)
                end
            end
        end
    end

    dap.listeners.before.evaluate["hex_mode_formatter"] = function(session, err, response)
        if err or type(response) ~= "table" or type(response.result) ~= "string" then
            return
        end
        local caps = nil
        if session then
            caps = session.capabilities
        end
        local native_hex = type(caps) == "table" and caps.supportsValueFormattingOptions == true
        if not hex_mode and native_hex then
            return
        end
    end

    local function toggle_hex_mode()
        hex_mode = not hex_mode
        local session = dap.session()
        if session and session.current_frame and type(session._frame_set) == "function" then
            pcall(function()
                session:_frame_set(session.current_frame)
            end)
        end
        if hex_mode then
            vim.notify("DAP Display Mode: HEX", vim.log.levels.INFO)
        else
            vim.notify("DAP Display Mode: DECIMAL", vim.log.levels.INFO)
        end
    end

    local function step_opts()
        if assembly_mode then
            return { granularity = "instruction" }
        end
        return nil
    end

    -- ----------------------------------------------------
    -- 4b. RAD MEMORY & INTERLEAVED SOURCE+ASM INSPECTORS
    -- ----------------------------------------------------
    local function normalize_hex_addr(addr)
        if type(addr) ~= "string" then
            return ""
        end
        local digits = addr:match("^0[xX](%x+)$")
        if not digits then
            return vim.trim(addr):lower()
        end
        local stripped = digits:gsub("^0+", "")
        if stripped == "" then
            stripped = "0"
        end
        return "0x" .. stripped:lower()
    end

    local function add_hex_offset(addr_str, offset)
        local digits = addr_str:match("^0[xX](%x+)$")
        if not digits or #digits > 16 then
            return string.format("%s+%d", addr_str, offset)
        end
        local padded = string.rep("0", 16 - #digits) .. digits
        local hi = tonumber(padded:sub(1, 8), 16)
        local lo = tonumber(padded:sub(9, 16), 16)
        if not hi or not lo then
            return string.format("%s+%d", addr_str, offset)
        end
        local new_lo = lo + offset
        local carry = math.floor(new_lo / 4294967296)
        new_lo = new_lo % 4294967296
        local new_hi = (hi + carry) % 4294967296
        if new_hi > 0 then
            return string.format("0x%x%08x", new_hi, new_lo)
        end
        return string.format("0x%x", new_lo)
    end

    local function open_scratch_float(title, lines, ft, initial_line)
        vim.schedule(function()
            local buf = vim.api.nvim_create_buf(false, true)
            vim.bo[buf].bufhidden = "wipe"
            vim.bo[buf].modifiable = true
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            vim.bo[buf].modifiable = false
            if ft and ft ~= "" then
                vim.bo[buf].filetype = ft
            end

            local max_w = 0
            for _, line in ipairs(lines) do
                if #line > max_w then
                    max_w = #line
                end
            end
            local width = math.min(math.max(max_w + 4, 68), math.floor(vim.o.columns * 0.88))
            local height = math.min(math.max(#lines + 2, 8), math.floor(vim.o.lines * 0.78))

            local win = vim.api.nvim_open_win(buf, true, {
                relative = "editor",
                width = width,
                height = height,
                row = math.floor((vim.o.lines - height) / 2),
                col = math.floor((vim.o.columns - width) / 2),
                style = "minimal",
                border = "rounded",
                title = " " .. title .. " ",
                title_pos = "center",
            })

            if type(initial_line) == "number" and initial_line >= 1 and initial_line <= #lines then
                pcall(vim.api.nvim_win_set_cursor, win, { initial_line, 0 })
            end

            vim.keymap.set("n", "q", function()
                if vim.api.nvim_win_is_valid(win) then
                    vim.api.nvim_win_close(win, true)
                end
            end, { buffer = buf, nowait = true, silent = true })
            vim.keymap.set("n", "<Esc>", function()
                if vim.api.nvim_win_is_valid(win) then
                    vim.api.nvim_win_close(win, true)
                end
            end, { buffer = buf, nowait = true, silent = true })
        end)
    end

    local function byte_to_bin(byte)
        local bits = {}
        for shift = 7, 0, -1 do
            local divisor = 2 ^ shift
            local bit_val = math.floor(byte / divisor) % 2
            table.insert(bits, tostring(bit_val))
        end
        return table.concat(bits)
    end

    local function decode_f32_le(b1, b2, b3, b4)
        local sign = math.floor(b4 / 128) % 2
        local exp = (b4 % 128) * 2 + math.floor(b3 / 128)
        local mant = (b3 % 128) * 65536 + b2 * 256 + b1
        if exp == 0 and mant == 0 then
            if sign == 1 then
                return "-0.0"
            end
            return "0.0"
        end
        if exp == 255 then
            if mant == 0 then
                if sign == 1 then
                    return "-Inf"
                end
                return "Inf"
            end
            return "NaN"
        end
        local scale = 1 - 2 * sign
        local val
        if exp == 0 then
            val = scale * math.ldexp(mant / 8388608, -126)
        else
            val = scale * math.ldexp(1 + mant / 8388608, exp - 127)
        end
        return string.format("%.7g", val)
    end

    local function decode_f64_le(b1, b2, b3, b4, b5, b6, b7, b8)
        local sign = math.floor(b8 / 128) % 2
        local exp = (b8 % 128) * 16 + math.floor(b7 / 16)
        local mant = (b7 % 16) * (2 ^ 48)
        + b6 * (2 ^ 40)
        + b5 * (2 ^ 32)
        + b4 * (2 ^ 24)
        + b3 * (2 ^ 16)
        + b2 * (2 ^ 8)
        + b1
        if exp == 0 and mant == 0 then
            if sign == 1 then
                return "-0.0"
            end
            return "0.0"
        end
        if exp == 2047 then
            if mant == 0 then
                if sign == 1 then
                    return "-Inf"
                end
                return "Inf"
            end
            return "NaN"
        end
        local scale = 1 - 2 * sign
        local val
        if exp == 0 then
            val = scale * math.ldexp(mant / 4503599627370496, -1022)
        else
            val = scale * math.ldexp(1 + mant / 4503599627370496, exp - 1023)
        end
        return string.format("%.15g", val)
    end

    local function format_le_memory_lines(expr, addr_str, region_info, raw_bytes_str)
        local bytes = {}
        for i = 1, #raw_bytes_str do
            table.insert(bytes, string.byte(raw_bytes_str, i))
        end

        local lines = {
            "Expr   : " .. expr,
            "Address: " .. addr_str,
        }
        if region_info and region_info ~= "" then
            table.insert(lines, "Region : " .. region_info)
        end
        table.insert(lines, string.rep("-", 72))
        table.insert(lines, "Little-Endian Interpretations (at " .. addr_str .. "):")

        if #bytes >= 1 then
            local u8 = bytes[1]
            local i8 = u8
            if u8 >= 128 then
                i8 = u8 - 256
            end
            table.insert(lines, string.format(
                "  8-bit  [LE: %02x]             hex: 0x%02x  |  dec: %d (i8: %d)  |  bin: %s",
                bytes[1], u8, u8, i8, byte_to_bin(bytes[1])
            ))
        end

        if #bytes >= 2 then
            local u16 = bytes[1] + bytes[2] * 256
            local i16 = u16
            if u16 >= 32768 then
                i16 = u16 - 65536
            end
            table.insert(lines, string.format(
                "  16-bit [LE: %02x %02x]          hex: 0x%04x  |  dec: %d (i16: %d)  |  bin: %s %s",
                bytes[1], bytes[2], u16, u16, i16,
                byte_to_bin(bytes[2]), byte_to_bin(bytes[1])
            ))
        end

        if #bytes >= 4 then
            local u32 = bytes[1] + bytes[2] * 256 + bytes[3] * 65536 + bytes[4] * 16777216
            local i32 = u32
            if u32 >= 2147483648 then
                i32 = u32 - 4294967296
            end
            local f32 = decode_f32_le(bytes[1], bytes[2], bytes[3], bytes[4])
            table.insert(lines, string.format(
                "  32-bit [LE: %02x %02x %02x %02x]    hex: 0x%08x  |  dec: %.0f (i32: %.0f)  |  f32: %s",
                bytes[1], bytes[2], bytes[3], bytes[4], u32, u32, i32, f32
            ))
            table.insert(lines, string.format(
                "         bin32: %s %s %s %s",
                byte_to_bin(bytes[4]), byte_to_bin(bytes[3]),
                byte_to_bin(bytes[2]), byte_to_bin(bytes[1])
            ))
        end

        if #bytes >= 8 then
            local hex64 = string.format(
                "0x%02x%02x%02x%02x%02x%02x%02x%02x",
                bytes[8], bytes[7], bytes[6], bytes[5],
                bytes[4], bytes[3], bytes[2], bytes[1]
            )
            local dec64 = "(>53-bit; hex exact)"
            if bytes[8] == 0 and bytes[7] < 32 then
                local u64 = bytes[1]
                + bytes[2] * (2 ^ 8)
                + bytes[3] * (2 ^ 16)
                + bytes[4] * (2 ^ 24)
                + bytes[5] * (2 ^ 32)
                + bytes[6] * (2 ^ 40)
                + bytes[7] * (2 ^ 48)
                dec64 = string.format("%.0f", u64)
            end
            local f64 = decode_f64_le(
                bytes[1], bytes[2], bytes[3], bytes[4],
                bytes[5], bytes[6], bytes[7], bytes[8]
            )
            table.insert(lines, string.format(
                "  64-bit [LE: %02x %02x %02x %02x %02x %02x %02x %02x]",
                bytes[1], bytes[2], bytes[3], bytes[4],
                bytes[5], bytes[6], bytes[7], bytes[8]
            ))
            table.insert(lines, string.format(
                "         hex: %s  |  dec: %s  |  f64: %s",
                hex64, dec64, f64
            ))
            table.insert(lines, string.format(
                "         bin64: %s %s %s %s %s %s %s %s",
                byte_to_bin(bytes[8]), byte_to_bin(bytes[7]),
                byte_to_bin(bytes[6]), byte_to_bin(bytes[5]),
                byte_to_bin(bytes[4]), byte_to_bin(bytes[3]),
                byte_to_bin(bytes[2]), byte_to_bin(bytes[1])
            ))
        end

        table.insert(lines, string.rep("-", 72))
        table.insert(lines, "Raw Memory Dump (8 bytes/row, press 'm' for live DapMemView, 'q' to close):")

        for row_offset = 0, #bytes - 1, 8 do
            local hex_col = {}
            local ascii_col = {}
            for col = 1, 8 do
                local idx = row_offset + col
                if idx <= #bytes then
                    local b = bytes[idx]
                    table.insert(hex_col, string.format("%02x", b))
                    if b >= 32 and b <= 126 then
                        table.insert(ascii_col, string.char(b))
                    else
                        table.insert(ascii_col, ".")
                    end
                else
                    table.insert(hex_col, "  ")
                    table.insert(ascii_col, " ")
                end
            end
            local row_label = add_hex_offset(addr_str, row_offset)
            table.insert(lines, string.format(
                "  %s:  %-24s  |%s|",
                row_label, table.concat(hex_col, " "), table.concat(ascii_col)
            ))
        end

        return lines
    end

    local function default_mem_expr()
        local cword = vim.fn.expand("<cword>")
        local cWORD = vim.fn.expand("<cWORD>")
        local hex_match = cWORD:match("0[xX]%x+")
        if hex_match then
            return hex_match
        end
        if cword ~= "" then
            return cword
        end
        return ""
    end

    local function resolve_addr_expr(session, input_expr, callback)
        local trimmed = vim.trim(input_expr)
        if trimmed == "" then
            return
        end

        if trimmed:match("^0[xX]%x+$") then
            callback(trimmed, trimmed)
            return
        end

        local frame_id = nil
        if session.current_frame then
            frame_id = session.current_frame.id
        end

        local function eval_expr(expr_to_eval, allow_addr_fallback)
            session:request("evaluate", {
                expression = expr_to_eval,
                frameId = frame_id,
                context = "watch",
            }, function(eval_err, eval_resp)
                if eval_err or type(eval_resp) ~= "table" then
                    vim.schedule(function()
                        vim.notify("Failed to evaluate: " .. expr_to_eval, vim.log.levels.ERROR)
                    end)
                    return
                end

                local is_register = expr_to_eval:sub(1, 1) == "$"
                local is_addr_expr = expr_to_eval:sub(1, 1) == "&"
                local is_ptr = is_pointer_type(eval_resp.type)
                local addr_from_result = nil
                if type(eval_resp.result) == "string" and (is_ptr or is_addr_expr or is_register) then
                    addr_from_result = eval_resp.result:match("0[xX]%x+")
                end

                local mem_ref = eval_resp.memoryReference
                if (type(mem_ref) ~= "string" or mem_ref == "") and addr_from_result then
                    mem_ref = addr_from_result
                end

                if allow_addr_fallback and not is_addr_expr and not is_register and not is_ptr then
                    eval_expr("&(" .. expr_to_eval .. ")", false)
                    return
                end

                if type(mem_ref) ~= "string" or mem_ref == "" then
                    vim.schedule(function()
                        vim.notify("No memory reference for: " .. expr_to_eval, vim.log.levels.WARN)
                    end)
                    return
                end

                local addr_label = mem_ref
                if addr_from_result then
                    addr_label = addr_from_result
                end
                callback(mem_ref, addr_label)
            end)
        end

        eval_expr(trimmed, true)
    end

    local function read_and_display_memory(session, expr, mem_ref, addr_label)
        session:request("readMemory", {
            memoryReference = mem_ref,
            offset = 0,
            count = 64,
        }, function(mem_err, mem_resp)
            if mem_err or type(mem_resp) ~= "table" or type(mem_resp.data) ~= "string" then
                vim.schedule(function()
                    local msg = "readMemory failed"
                    if mem_err and mem_err.message then
                        msg = msg .. ": " .. mem_err.message
                    end
                    vim.notify(msg, vim.log.levels.ERROR)
                end)
                return
            end

            if not vim.base64 or type(vim.base64.decode) ~= "function" then
                vim.schedule(function()
                    vim.notify("vim.base64.decode unavailable in this Neovim build", vim.log.levels.ERROR)
                end)
                return
            end

            local ok_dec, raw_bytes = pcall(vim.base64.decode, mem_resp.data)
            if not ok_dec or type(raw_bytes) ~= "string" or #raw_bytes == 0 then
                vim.schedule(function()
                    vim.notify("Failed to decode readMemory base64 payload", vim.log.levels.ERROR)
                end)
                return
            end

            local final_addr = addr_label
            if type(mem_resp.address) == "string" and mem_resp.address ~= "" then
                final_addr = mem_resp.address
            end

            local function show_with_region(region_text)
                local lines = format_le_memory_lines(expr, final_addr, region_text, raw_bytes)
                vim.schedule(function()
                    local buf = vim.api.nvim_create_buf(false, true)
                    vim.bo[buf].bufhidden = "wipe"
                    vim.bo[buf].modifiable = true
                    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                    vim.bo[buf].modifiable = false

                    local max_w = 0
                    for _, line in ipairs(lines) do
                        if #line > max_w then
                            max_w = #line
                        end
                    end
                    local width = math.min(math.max(max_w + 4, 76), math.floor(vim.o.columns * 0.9))
                    local height = math.min(math.max(#lines + 2, 12), math.floor(vim.o.lines * 0.8))

                    local win = vim.api.nvim_open_win(buf, true, {
                        relative = "editor",
                        width = width,
                        height = height,
                        row = math.floor((vim.o.lines - height) / 2),
                        col = math.floor((vim.o.columns - width) / 2),
                        style = "minimal",
                        border = "rounded",
                        title = " RAD Memory Inspector ",
                        title_pos = "center",
                    })

                    vim.keymap.set("n", "q", function()
                        if vim.api.nvim_win_is_valid(win) then
                            vim.api.nvim_win_close(win, true)
                        end
                    end, { buffer = buf, nowait = true, silent = true })
                    vim.keymap.set("n", "<Esc>", function()
                        if vim.api.nvim_win_is_valid(win) then
                            vim.api.nvim_win_close(win, true)
                        end
                    end, { buffer = buf, nowait = true, silent = true })
                    vim.keymap.set("n", "m", function()
                        if vim.api.nvim_win_is_valid(win) then
                            vim.api.nvim_win_close(win, true)
                        end
                        if ok_memview then
                            vim.cmd("DapMemView " .. final_addr)
                        else
                            vim.notify("nvim-dap-memview not loaded", vim.log.levels.WARN)
                        end
                    end, { buffer = buf, nowait = true, silent = true })
                end)
            end

            local frame_id = nil
            if session.current_frame then
                frame_id = session.current_frame.id
            end

            if session.config and session.config.type == "codelldb" then
                session:request("evaluate", {
                    expression = "`memory region " .. final_addr,
                    frameId = frame_id,
                    context = "repl",
                }, function(reg_err, reg_resp)
                    local region_text = ""
                    if not reg_err and type(reg_resp) == "table" and type(reg_resp.result) == "string" then
                        region_text = vim.trim(reg_resp.result):gsub("\n", " | ")
                    end
                    show_with_region(region_text)
                end)
            else
                show_with_region("")
            end
        end)
    end

    local function inspect_memory_prompt()
        local session = dap.session()
        if not session then
            vim.notify("Start a debug session and hit a breakpoint first", vim.log.levels.WARN)
            return
        end

        vim.ui.input({
            prompt = "Inspect memory (&var, var, or 0xADDR): ",
            default = default_mem_expr(),
        }, function(input)
            if input and vim.trim(input) ~= "" then
                local expr = vim.trim(input)
                resolve_addr_expr(session, expr, function(mem_ref, addr_label)
                    read_and_display_memory(session, expr, mem_ref, addr_label)
                end)
            end
        end)
    end

    local function open_live_memview_prompt()
        if not ok_memview then
            vim.notify("nvim-dap-memview is not loaded", vim.log.levels.WARN)
            return
        end
        if not dap.session() then
            vim.notify("Start a debug session and hit a breakpoint first", vim.log.levels.WARN)
            return
        end

        local def = default_mem_expr()
        if def ~= "" and not def:match("^0[xX]%x+$") and def:sub(1, 1) ~= "&" then
            def = "&" .. def
        end

        vim.ui.input({
            prompt = "DapMemView expr/addr: ",
            default = def,
        }, function(input)
            if input and vim.trim(input) ~= "" then
                vim.cmd("DapMemView " .. vim.trim(input))
            end
        end)
    end

    local function lldb_virtual_memory_menu()
        local session = dap.session()
        if not session then
            vim.notify("No active DAP session", vim.log.levels.WARN)
            return
        end

        local actions = {
            { id = "region",   label = "1. Region info for address (memory region <addr>)" },
            { id = "all_regs", label = "2. All virtual memory regions (memory region --all)" },
            { id = "lookup",   label = "3. Symbol / section at address (image lookup -a <addr>)" },
            { id = "find",     label = "4. Search bytes/string in range (memory find)" },
        }

        vim.ui.select(actions, {
            prompt = "LLDB Virtual Memory Tools:",
            format_item = function(item)
                return item.label
            end,
        }, function(choice)
            if not choice then
                return
            end

            local frame_id = nil
            if session.current_frame then
                frame_id = session.current_frame.id
            end

            local function run_repl_cmd(cmd_str, title)
                local eval_cmd = cmd_str
                if session.config and session.config.type == "codelldb" and eval_cmd:sub(1, 1) ~= "`" then
                    eval_cmd = "`" .. eval_cmd
                end
                session:request("evaluate", {
                    expression = eval_cmd,
                    frameId = frame_id,
                    context = "repl",
                }, function(err, resp)
                    if err or type(resp) ~= "table" then
                        vim.schedule(function()
                            vim.notify("Command failed: " .. cmd_str, vim.log.levels.ERROR)
                        end)
                        return
                    end
                    local text = resp.result
                    if type(text) ~= "string" or vim.trim(text) == "" then
                        text = "(no output)"
                    end
                    local out_lines = vim.split(text, "\n", { plain = true })
                    table.insert(out_lines, 1, "Command: " .. cmd_str)
                    table.insert(out_lines, 2, string.rep("-", 72))
                    open_scratch_float(title, out_lines, "")
                end)
            end

            if choice.id == "all_regs" then
                run_repl_cmd("memory region --all", "Virtual Memory Map")
                return
            end

            if choice.id == "region" or choice.id == "lookup" then
                local def = default_mem_expr()
                vim.ui.input({ prompt = "Address (0x... or &var): ", default = def }, function(addr_in)
                    if not addr_in or vim.trim(addr_in) == "" then
                        return
                    end
                    resolve_addr_expr(session, addr_in, function(_, resolved_addr)
                        if choice.id == "region" then
                            run_repl_cmd("memory region " .. resolved_addr, "Memory Region")
                        else
                            run_repl_cmd("image lookup -a " .. resolved_addr, "Image Lookup")
                        end
                    end)
                end)
                return
            end

            if choice.id == "find" then
                vim.ui.input({
                    prompt = "LLDB memory find args (e.g. -e 255 0x7fff0000 0x7ffff000): ",
                }, function(find_args)
                    if not find_args or vim.trim(find_args) == "" then
                        return
                    end
                    run_repl_cmd("memory find " .. vim.trim(find_args), "Memory Search")
                end)
            end
        end)
    end

    local function show_interleaved_source_asm()
        local session = dap.session()
        if not session or not session.current_frame then
            vim.notify("Pause at a breakpoint first", vim.log.levels.WARN)
            return
        end

        local frame = session.current_frame
        local pc_ref = frame.instructionPointerReference
        if type(pc_ref) ~= "string" or pc_ref == "" then
            vim.notify("Current adapter/frame has no instructionPointerReference", vim.log.levels.WARN)
            return
        end
        local norm_pc = normalize_hex_addr(pc_ref)

        session:request("disassemble", {
            memoryReference = pc_ref,
            instructionOffset = -12,
            instructionCount = 40,
            resolveSymbols = true,
        }, function(err, resp)
            if err or type(resp) ~= "table" or type(resp.instructions) ~= "table" then
                vim.schedule(function()
                    vim.notify("DAP disassemble failed", vim.log.levels.ERROR)
                end)
                return
            end

            local file_cache = {}
            local function read_source_line(path, line_num)
                if type(path) ~= "string" or path == "" or type(line_num) ~= "number" or line_num < 1 then
                    return nil
                end
                if file_cache[path] == nil then
                    if vim.fn.filereadable(path) == 1 then
                        file_cache[path] = vim.fn.readfile(path)
                    else
                        file_cache[path] = false
                    end
                end
                local cached = file_cache[path]
                if type(cached) == "table" then
                    return cached[line_num]
                end
                return nil
            end

            local lines = {
                "PC: " .. pc_ref .. "  (q / <Esc> to close)",
                string.rep("-", 78),
            }
            local last_loc_key = ""
            local pc_line_nr = nil

            for _, inst in ipairs(resp.instructions) do
                local src_path = nil
                if type(inst.location) == "table" then
                    src_path = inst.location.path
                end
                local src_line_nr = inst.line
                if type(src_path) == "string" and type(src_line_nr) == "number" then
                    local loc_key = src_path .. ":" .. tostring(src_line_nr)
                    if loc_key ~= last_loc_key then
                        last_loc_key = loc_key
                        local src_text = read_source_line(src_path, src_line_nr)
                        local fname = vim.fn.fnamemodify(src_path, ":t")
                        if src_text then
                            table.insert(lines, string.format(
                                "  ; [%s:%d] %s",
                                fname, src_line_nr, vim.trim(src_text)
                            ))
                        else
                            table.insert(lines, string.format("  ; [%s:%d]", fname, src_line_nr))
                        end
                    end
                end

                local addr = inst.address or ""
                local bytes = inst.instructionBytes or ""
                local asm = inst.instruction or ""
                local is_pc = normalize_hex_addr(addr) == norm_pc
                local marker = "  "
                if is_pc then
                    marker = "->"
                end
                local sym = ""
                if type(inst.symbol) == "string" and inst.symbol ~= "" then
                    sym = "<" .. inst.symbol .. "> "
                end

                table.insert(lines, string.format(
                    "%s %-14s  %-22s  %s%s",
                    marker, addr, bytes, sym, asm
                ))
                if is_pc then
                    pc_line_nr = #lines
                end
            end

            open_scratch_float("Interleaved Source + ASM", lines, "asm", pc_line_nr)
        end)
    end
    -- ----------------------------------------------------
    -- 5. KEYMAPS
    -- ----------------------------------------------------
    vim.keymap.set("n", "<F5>", dap.continue, { desc = "Debug: Start/Continue" })
    if ok_neotest then
        vim.keymap.set("n", "<F6>", function()
            neotest.run.run({ strategy = "dap" })
        end, { desc = "Debug nearest test" })
    end
    vim.keymap.set("n", "<F9>", dap.toggle_breakpoint, { desc = "DAP: Toggle breakpoint" })
    vim.keymap.set("n", "<F11>", function()
        dap.step_into(step_opts())
    end, { desc = "Debug: Step Into (statement/instruction)" })
    vim.keymap.set("n", "<F10>", function()
        dap.step_over(step_opts())
    end, { desc = "Debug: Step Over (statement/instruction)" })
    vim.keymap.set("n", "<F8>", function()
        dap.step_out(step_opts())
    end, { desc = "Debug: Step Out (statement/instruction)" })

    vim.keymap.set("n", "<leader>dr", dap.repl.open, { desc = "DAP: REPL open" })
    vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = "DAP: Run last" })
    vim.keymap.set("n", "<leader>du", function()
        if ok_dap_view then
            dap_view.toggle(true)
        end
    end, { desc = "Debug: Toggle DAP View" })

    vim.keymap.set("n", "<leader>dz", toggle_fullscreen_element, { desc = "DAP: Toggle fullscreen element / layout" })
    vim.keymap.set("n", "<leader>dt", cycle_dap_tab, { desc = "DAP: Cycle view tabs" })
    vim.keymap.set("n", "<leader>da", toggle_assembly_mode, { desc = "DAP: Toggle Assembly Mode" })
    vim.keymap.set("n", "<leader>dh", toggle_hex_mode, { desc = "DAP: Toggle Hex / Decimal Mode" })
    vim.keymap.set("n", "<leader>dm", inspect_memory_prompt, { desc = "DAP: Inspect memory (Hex/Dec/Bin LE)" })
    vim.keymap.set("n", "<leader>dM", open_live_memview_prompt, { desc = "DAP: Open live DapMemView" })
    vim.keymap.set("n", "<leader>dR", lldb_virtual_memory_menu, { desc = "DAP: Virtual memory region / search" })
    vim.keymap.set("n", "<leader>ds", show_interleaved_source_asm, { desc = "DAP: Interleaved Source + ASM" })

    if ok_dapui then
        vim.keymap.set({ "n", "v" }, "Q", function()
            dapui.eval()
        end, { desc = "DAP Peek" })
        vim.keymap.set({ "n", "v" }, "<leader>dw", function()
            dapui.eval(nil, { enter = true })
        end, { desc = "DAP Add word under cursor to Watches" })
    end
end)

vim.schedule(function()
    local dap     = require("dap")
    local Session = require("dap.session")

    local ok_dapui,    dapui       = pcall(require, "dapui")
    local ok_dap_view, dap_view    = pcall(require, "dap-view")
    local ok_disasm,   dap_disasm  = pcall(require, "dap-disasm")
    local ok_memview,  dap_memview = pcall(require, "dap-memview")
    local ok_neotest,  neotest     = pcall(require, "neotest")

    -- Sign Definitions
    vim.fn.sign_define("DapBreakpoint", {
        text   = "⚪",
        texthl = "DapBreakpointSymbol",
        linehl = "DapBreakpoint",
        numhl  = "DapBreakpoint",
    })
    vim.fn.sign_define("DapStopped", {
        text   = "🔴",
        texthl = "DiagnosticWarn",
        linehl = "DapBreakpoint",
        numhl  = "DapBreakpoint",
    })
    vim.fn.sign_define("DapBreakpointRejected", {
        text   = "⭕",
        texthl = "DapStoppedSymbol",
        linehl = "DapBreakpoint",
        numhl  = "DapBreakpoint",
    })

    local last_cli_args = ""
    local wine_sessions = {
        job_id         = nil,
        out_buf        = nil,
        out_win        = nil,
        rpc_dir        = nil,
        pending_target = nil,
    }

    local function remove_dir_recursive(dir_path)
        if type(dir_path) ~= "string" or dir_path == "" then
            return
        end
        pcall(vim.fn.delete, dir_path, "rf")
    end

    local function cleanup_wine_session()
        if wine_sessions.job_id ~= nil then
            pcall(vim.fn.jobstop, wine_sessions.job_id)
            wine_sessions.job_id = nil
        end
        wine_sessions.pending_target = nil
        if wine_sessions.rpc_dir ~= nil then
            remove_dir_recursive(wine_sessions.rpc_dir)
            wine_sessions.rpc_dir = nil
        end
    end

    local function parse_cli_args(raw)
        local args      = {}
        local current   = {}
        local in_single = false
        local in_double = false
        local escaped   = false
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
        local sentinel  = "__DAP_ABORT__"
        local exec_path = vim.fn.input({
            prompt       = "Path to exec: ",
            default      = vim.fn.getcwd() .. "/",
            completion   = "file",
            cancelreturn = sentinel,
        })
        if exec_path == sentinel or vim.trim(exec_path) == "" then
            return dap.ABORT
        end
        local real_path = vim.uv.fs_realpath(exec_path)
        if real_path ~= nil then
            return real_path
        end
        return exec_path
    end

    local function prompt_cli_args()
        local sentinel = "__DAP_ABORT__"
        local raw = vim.fn.input({
            prompt       = "Arguments: ",
            default      = last_cli_args,
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

    local function find_build_sh_root()
        local raw_dir = vim.fn.expand("%:p:h")
        if raw_dir == "" then
            raw_dir = vim.fn.getcwd()
        end
        local dir = vim.uv.fs_realpath(raw_dir) or raw_dir
        local home_dir = vim.fs.normalize(vim.fn.expand("~"))
        dir = vim.fs.normalize(dir)

        while true do
            if vim.fn.filereadable(dir .. "/build.sh") == 1 then
                return dir
            end
            if dir == home_dir or dir == "/" then
                break
            end
            local parent = vim.fn.fnamemodify(dir, ":h")
            if parent == dir then
                break
            end
            dir = parent
        end
        return nil
    end

    local function pick_wine_exe_path(root)
        local candidate = root .. "/build/handmade.exe"
        if vim.fn.filereadable(candidate) == 1 then
            local real = vim.uv.fs_realpath(candidate)
            if real ~= nil then
                return real
            end
            return candidate
        end
        local found = vim.fn.glob(root .. "/build/*.exe", false, true)
        if #found > 0 then
            local real = vim.uv.fs_realpath(found[1])
            if real ~= nil then
                return real
            end
            return found[1]
        end
        return nil
    end

    local function append_wine_output_lines(chunks)
        local buf = wine_sessions.out_buf
        if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
            return
        end
        local lines = {}
        for _, chunk in ipairs(chunks) do
            if type(chunk) == "string" and chunk ~= "" then
                local clean = chunk:gsub("\r", "")
                table.insert(lines, clean)
            end
        end
        if #lines == 0 then
            return
        end
        vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(buf) then
                return
            end
            local was_mod = vim.bo[buf].modifiable
            vim.bo[buf].modifiable = true
            local line_count = vim.api.nvim_buf_line_count(buf)
            local first_line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
            if line_count == 1 and first_line == "" then
                vim.api.nvim_buf_set_lines(buf, 0, 1, false, lines)
            else
                vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
            end
            vim.bo[buf].modifiable = was_mod
            if wine_sessions.out_win ~= nil and vim.api.nvim_win_is_valid(wine_sessions.out_win) then
                local last = vim.api.nvim_buf_line_count(buf)
                pcall(vim.api.nvim_win_set_cursor, wine_sessions.out_win, { last, 0 })
            end
        end)
    end

    local function find_normal_source_win()
        local cur_win = vim.api.nvim_get_current_win()
        local cur_buf = vim.api.nvim_win_get_buf(cur_win)
        if vim.bo[cur_buf].buftype == "" and not vim.b[cur_buf].is_compile_output then
            return cur_win
        end
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].buftype == "" and not vim.b[buf].is_compile_output then
                return win
            end
        end
        return cur_win
    end

    local function close_compile_output_windows()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) and vim.b[buf].is_compile_output == true then
                for _, win in ipairs(vim.fn.win_findbuf(buf)) do
                    if vim.api.nvim_win_is_valid(win) and #vim.api.nvim_tabpage_list_wins(0) > 1 then
                        pcall(vim.api.nvim_win_close, win, true)
                    end
                end
                pcall(vim.api.nvim_buf_delete, buf, { force = true })
            end
        end
    end

    local function ensure_wine_output_window()
        close_compile_output_windows()
        local prev_win = find_normal_source_win()

        if wine_sessions.out_buf == nil or not vim.api.nvim_buf_is_valid(wine_sessions.out_buf) then
            local buf = vim.api.nvim_create_buf(false, true)
            vim.bo[buf].bufhidden = "hide"
            vim.bo[buf].buftype = "nofile"
            vim.bo[buf].swapfile = false
            vim.bo[buf].modifiable = false
            pcall(vim.api.nvim_buf_set_name, buf, "Wine Debug Output")
            vim.keymap.set("n", "q", function()
                if wine_sessions.out_win ~= nil and vim.api.nvim_win_is_valid(wine_sessions.out_win) then
                    vim.api.nvim_win_close(wine_sessions.out_win, true)
                    wine_sessions.out_win = nil
                end
            end, { buffer = buf, nowait = true, silent = true })
            wine_sessions.out_buf = buf
        else
            vim.bo[wine_sessions.out_buf].modifiable = true
            vim.api.nvim_buf_set_lines(wine_sessions.out_buf, 0, -1, false, {})
            vim.bo[wine_sessions.out_buf].modifiable = false
        end

        if wine_sessions.out_win == nil or not vim.api.nvim_win_is_valid(wine_sessions.out_win) then
            vim.cmd("botright 8split")
            local win = vim.api.nvim_get_current_win()
            vim.api.nvim_win_set_buf(win, wine_sessions.out_buf)
            pcall(vim.api.nvim_set_option_value, "winfixbuf", true, { win = win })
            wine_sessions.out_win = win
            if vim.api.nvim_win_is_valid(prev_win) then
                vim.api.nvim_set_current_win(prev_win)
            end
        end
    end

    local function toggle_wine_output_window()
        if wine_sessions.out_win ~= nil and vim.api.nvim_win_is_valid(wine_sessions.out_win) then
            vim.api.nvim_win_close(wine_sessions.out_win, true)
            wine_sessions.out_win = nil
            return
        end
        if wine_sessions.out_buf == nil or not vim.api.nvim_buf_is_valid(wine_sessions.out_buf) then
            vim.notify("No Wine debug output buffer yet", vim.log.levels.INFO)
            return
        end
        local prev_win = find_normal_source_win()
        vim.cmd("botright 8split")
        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, wine_sessions.out_buf)
        pcall(vim.api.nvim_set_option_value, "winfixbuf", true, { win = win })
        wine_sessions.out_win = win
        if vim.api.nvim_win_is_valid(prev_win) then
            vim.api.nvim_set_current_win(prev_win)
        end
    end

    local function alloc_free_localhost_port()
        local tcp = vim.uv.new_tcp()
        if tcp == nil then
            return nil
        end
        local ok_bind = tcp:bind("127.0.0.1", 0)
        if not ok_bind then
            tcp:close()
            return nil
        end
        local sock = tcp:getsockname()
        tcp:close()
        if type(sock) == "table" and type(sock.port) == "number" then
            return sock.port
        end
        return nil
    end

    local function build_and_start_wine_server()
        cleanup_wine_session()

        local root = find_build_sh_root()
        if root == nil then
            vim.notify("No build.sh found in parent directories", vim.log.levels.ERROR)
            return dap.ABORT
        end

        ensure_wine_output_window()
        append_wine_output_lines({ "[build] Running " .. root .. "/build.sh build-debug ..." })

        local build_res = vim.system({ "bash", root .. "/build.sh", "build-debug" }, {
            cwd = root,
            text = true,
        }):wait()

        if type(build_res.stdout) == "string" and build_res.stdout ~= "" then
            append_wine_output_lines(vim.split(build_res.stdout, "\n", { plain = true }))
        end
        if type(build_res.stderr) == "string" and build_res.stderr ~= "" then
            append_wine_output_lines(vim.split(build_res.stderr, "\n", { plain = true }))
        end

        if build_res.code ~= 0 then
            vim.notify("build.sh build-debug failed (see Wine Debug Output)", vim.log.levels.ERROR)
            return dap.ABORT
        end

        local exe_path = pick_wine_exe_path(root)
        if exe_path == nil then
            vim.notify("No compiled .exe found in " .. root .. "/build", vim.log.levels.ERROR)
            return dap.ABORT
        end

        local port = alloc_free_localhost_port()
        if port == nil then
            vim.notify("Failed to allocate free localhost port for winedbg", vim.log.levels.ERROR)
            return dap.ABORT
        end

        local wineprefix = root .. "/.wine"
        local winedebug = "fixme-all,warn+debugstr,warn+seh"
        local server_cmd
        if vim.env.WINE_USE_GDBSERVER == "1" and vim.fn.executable("gdbserver.exe") == 1 then
            server_cmd = { "wine", "gdbserver.exe", "127.0.0.1:" .. tostring(port), exe_path }
        else
            server_cmd = { "winedbg", "--gdb", "--no-start", "--port", tostring(port), exe_path }
        end

        append_wine_output_lines({
            "[wine] WINEPREFIX=" .. wineprefix .. " WINEDEBUG=" .. winedebug,
            "[wine] " .. table.concat(server_cmd, " "),
        })

        local ready = false
        local exited = false
        local exit_code = nil

        local function handle_stream(_, data)
            if type(data) ~= "table" then
                return
            end
            append_wine_output_lines(data)
            for _, line in ipairs(data) do
                if type(line) == "string" then
                    if line:find("target remote", 1, true) or line:find("Listening on port", 1, true) then
                        ready = true
                    end
                end
            end
        end

        local job_id = vim.fn.jobstart(server_cmd, {
            cwd = root,
            env = {
                WINEPREFIX = wineprefix,
                WINEDEBUG = winedebug,
            },
            on_stdout = handle_stream,
            on_stderr = handle_stream,
            on_exit = function(_, code)
                exited = true
                exit_code = code
                append_wine_output_lines({ "[wine] Process exited with code " .. tostring(code) })
                if wine_sessions.job_id == job_id then
                    wine_sessions.job_id = nil
                end
            end,
        })

        if job_id <= 0 then
            vim.notify("Failed to start winedbg job", vim.log.levels.ERROR)
            return dap.ABORT
        end

        wine_sessions.job_id = job_id
        wine_sessions.pending_target = "127.0.0.1:" .. tostring(port)

        local wait_ok = vim.wait(10000, function()
            return ready or exited
        end, 25)

        if exited then
            vim.notify("winedbg exited early with code " .. tostring(exit_code), vim.log.levels.ERROR)
            cleanup_wine_session()
            return dap.ABORT
        end
        if not wait_ok then
            vim.notify("Timed out waiting for winedbg GDB port", vim.log.levels.ERROR)
            cleanup_wine_session()
            return dap.ABORT
        end

        return exe_path
    end

    local function prompt_wine_attach_exe()
        local root = find_build_sh_root()
        if root ~= nil then
            local found = pick_wine_exe_path(root)
            if found ~= nil then
                return found
            end
        end
        return prompt_exec_path()
    end

    local function prompt_remote_target()
        local sentinel = "__DAP_ABORT__"
        local raw = vim.fn.input({
            prompt       = "GDB remote target (host:port): ",
            default      = "127.0.0.1:31337",
            cancelreturn = sentinel,
        })
        if raw == sentinel or vim.trim(raw) == "" then
            return dap.ABORT
        end
        return vim.trim(raw)
    end

    -- ----------------------------------------------------
    -- 1. ADAPTER DEFINITIONS
    -- ----------------------------------------------------
    require("mason-nvim-dap").setup({
        automatic_setup  = true,
        handlers         = {},
        ensure_installed = { "codelldb" },
    })

    if dap.defaults ~= nil then
        if dap.defaults.gdb == nil then
            dap.defaults.gdb = {}
        end
        dap.defaults.gdb.exception_breakpoints = {}
    end

    local gdb_tools_path = vim.fs.normalize(vim.fn.stdpath("config") .. "/scripts/gdb_wine_tools.py")

    dap.adapters.gdb = function(callback, config)
        if wine_sessions.rpc_dir ~= nil then
            remove_dir_recursive(wine_sessions.rpc_dir)
            wine_sessions.rpc_dir = nil
        end

        local rpc_dir = vim.fn.tempname() .. "_gdb_rpc"
        local mk_ok = vim.uv.fs_mkdir(rpc_dir, 448)
        if not mk_ok then
            rpc_dir = nil
        end
        wine_sessions.rpc_dir = rpc_dir

        local gdb_args = {
            "-nx",
            "-q",
            "--interpreter=dap",
            "-iex", "set confirm off",
            "-iex", "set debuginfod enabled off",
            "-iex", "set auto-solib-add off",
            "-iex", "set pagination off",
            "-iex", "set print elements 0",
            "-iex", "set print repeats 0",
        }
        if vim.fn.filereadable(gdb_tools_path) == 1 then
            table.insert(gdb_args, "-iex")
            table.insert(gdb_args, "source " .. gdb_tools_path)
        end

        local env_map = {}
        if rpc_dir ~= nil then
            env_map.NVIM_GDB_RPC_DIR = rpc_dir
        end
        if type(config.program) == "string" and config.program ~= "" then
            env_map.NVIM_GDB_PROGRAM = config.program
        end

        callback({
            type = "executable",
            command = "gdb",
            args = gdb_args,
            options = {
                env = env_map,
                initialize_timeout_sec = 20,
            },
            enrich_config = function(cfg, on_config)
                local final_cfg = vim.deepcopy(cfg)
                if final_cfg.wine_launch == true then
                    if type(wine_sessions.pending_target) == "string" then
                        final_cfg.target = wine_sessions.pending_target
                        wine_sessions.pending_target = nil
                    end
                    final_cfg.wine_launch = nil
                end
                if rpc_dir ~= nil then
                    final_cfg._rpc_dir = rpc_dir
                end
                on_config(final_cfg)
            end,
        })
    end

    local function has_any_user_breakpoints()
        local ok_bp, breakpoints = pcall(require, "dap.breakpoints")
        if not ok_bp or type(breakpoints) ~= "table" then
            return false
        end
        local all_bps = breakpoints.get()
        if type(all_bps) ~= "table" then
            return false
        end
        for _, buf_bps in pairs(all_bps) do
            if type(buf_bps) == "table" and #buf_bps > 0 then
                return true
            end
        end
        return false
    end

    if dap.defaults ~= nil then
        if dap.defaults.fallback == nil then
            dap.defaults.fallback = {}
        end
        dap.defaults.fallback.switchbuf = "useopen,uselast"
    end

    local function close_duplicate_source_windows(source_path, stopped_line)
        if type(source_path) ~= "string" or source_path == "" then
            return
        end
        local target_real = vim.fs.normalize(vim.uv.fs_realpath(source_path) or source_path)
        local matches = {}
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            local buf = vim.api.nvim_win_get_buf(win)
            local bname = vim.api.nvim_buf_get_name(buf)
            if bname ~= "" and vim.bo[buf].buftype == "" then
                local breal = vim.fs.normalize(vim.uv.fs_realpath(bname) or bname)
                if breal == target_real then
                    table.insert(matches, {
                        win  = win,
                        buf  = buf,
                        area = vim.api.nvim_win_get_height(win) * vim.api.nvim_win_get_width(win),
                    })
                end
            end
        end

        if #matches <= 1 then
            return
        end

        local keep = matches[1]
        for idx = 2, #matches do
            if matches[idx].area > keep.area then
                keep = matches[idx]
            end
        end

        local active_win = vim.api.nvim_get_current_win()
        local active_buf = vim.api.nvim_win_get_buf(active_win)
        local active_real = ""
        if active_win ~= keep.win and vim.api.nvim_buf_get_name(active_buf) ~= "" then
            active_real = vim.fs.normalize(vim.uv.fs_realpath(vim.api.nvim_buf_get_name(active_buf)) or vim.api.nvim_buf_get_name(active_buf))
        end

        if active_real == target_real and active_buf ~= keep.buf then
            pcall(vim.api.nvim_win_set_buf, keep.win, active_buf)
        end

        for _, item in ipairs(matches) do
            if item.win ~= keep.win and vim.api.nvim_win_is_valid(item.win) then
                pcall(vim.api.nvim_win_close, item.win, true)
            end
        end

        if vim.api.nvim_win_is_valid(keep.win) then
            vim.api.nvim_set_current_win(keep.win)
            if type(stopped_line) == "number" and stopped_line >= 1 then
                pcall(vim.api.nvim_win_set_cursor, keep.win, { stopped_line, 0 })
            end
        end
    end

    dap.listeners.after.stackTrace["wine_skip_attach_pause"] = function(session, err, response)
        if err or type(response) ~= "table" or type(response.stackFrames) ~= "table" then
            return
        end
        local frame1 = response.stackFrames[1]
        if type(frame1) ~= "table" then
            return
        end

        local has_source = type(frame1.source) == "table" and type(frame1.source.path) == "string" and frame1.source.path ~= ""

        if not has_source then
            if session == nil or type(session.config) ~= "table" or session.config._wine_attach ~= true then
                return
            end
            if session._wine_attach_continued == true then
                return
            end
            session._wine_attach_continued = true

            vim.schedule(function()
                if dap.session() ~= session then
                    return
                end
                if has_any_user_breakpoints() then
                    dap.continue()
                else
                    session:request("setFunctionBreakpoints", {
                        breakpoints = {
                            { name = "WinMain" },
                            { name = "main" },
                        },
                    }, function()
                        vim.schedule(function()
                            if dap.session() == session then
                                dap.continue()
                            end
                        end)
                    end)
                end
            end)
            return
        end

        vim.schedule(function()
            if dap.session() == session then
                close_duplicate_source_windows(frame1.source.path, frame1.line)
            end
        end)
    end

    dap.listeners.after.event_terminated["wine_gdb_cleanup"] = function()
        cleanup_wine_session()
    end
    dap.listeners.after.event_exited["wine_gdb_cleanup"] = function()
        cleanup_wine_session()
    end
    dap.listeners.after.disconnect["wine_gdb_cleanup"] = function()
        cleanup_wine_session()
    end

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
            name = "Linux: Launch Executable (gdb)",
            type = "gdb",
            request = "launch",
            program = prompt_exec_path,
            cwd = "${workspaceFolder}",
            stopAtBeginningOfMainSubprogram = false,
        }, {
            name = "Linux: Launch Executable (gdb, with args)",
            type = "gdb",
            request = "launch",
            program = prompt_exec_path,
            args = prompt_cli_args,
            cwd = "${workspaceFolder}",
            stopAtBeginningOfMainSubprogram = false,
        }, {
            name = "Wine: Build & Debug (winedbg + live output)",
            type = "gdb",
            request = "attach",
            wine_launch = true,
            _wine_attach = true,
            program = build_and_start_wine_server,
            cwd = "${workspaceFolder}",
        }, {
            name = "Wine: Attach to running winedbg (127.0.0.1:31337)",
            type = "gdb",
            request = "attach",
            _wine_attach = true,
            program = prompt_wine_attach_exe,
            target = prompt_remote_target,
            cwd = "${workspaceFolder}",
        }, {
            name = "Linux: Launch Executable (codelldb)",
            type = "codelldb",
            request = "launch",
            program = prompt_exec_path,
            cwd = "${workspaceFolder}",
            terminal = "integrated",
            stopOnEntry = false,
        }, {
            name = "Linux: Launch Executable (codelldb, with args)",
            type = "codelldb",
            request = "launch",
            program = prompt_exec_path,
            args = prompt_cli_args,
            cwd = "${workspaceFolder}",
            terminal = "integrated",
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
            if vim.api.nvim_get_mode().mode:sub(1, 1) == "t" then
                local esc = vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true)
                vim.api.nvim_feedkeys(esc, "nx", false)
            else
                vim.cmd("stopinsert")
            end
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

    local function hex_digits_to_dec(digits)
        local dec = { 0 }
        for i = 1, #digits do
            local nibble = tonumber(digits:sub(i, i), 16)
            if nibble == nil then
                return nil
            end
            local carry = nibble
            for j = #dec, 1, -1 do
                local val = dec[j] * 16 + carry
                dec[j] = val % 10
                carry = math.floor(val / 10)
            end
            while carry > 0 do
                table.insert(dec, 1, carry % 10)
                carry = math.floor(carry / 10)
            end
        end
        return table.concat(dec)
    end

    local function dec_digits_to_hex(digits)
        local bytes = {}
        local n = {}
        for i = 1, #digits do
            local d = tonumber(digits:sub(i, i))
            if d == nil then
                return nil
            end
            table.insert(n, d)
        end
        while #n > 0 do
            local rem = 0
            local next_n = {}
            for i = 1, #n do
                local cur = rem * 10 + n[i]
                local q = math.floor(cur / 16)
                rem = cur % 16
                if #next_n > 0 or q > 0 then
                    table.insert(next_n, q)
                end
            end
            table.insert(bytes, 1, string.format("%x", rem))
            n = next_n
        end
        if #bytes == 0 then
            return "0x0"
        end
        return "0x" .. table.concat(bytes)
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
                local hex_str = nil
                if num and num <= 9007199254740991 then
                    hex_str = u53_to_hex(num)
                else
                    hex_str = dec_digits_to_hex(digits)
                end
                if hex_str ~= nil then
                    if sign == "-" and hex_str ~= "0x0" then
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
                local dec_str = nil
                if num and num <= 9007199254740991 then
                    dec_str = string.format("%.0f", num)
                else
                    dec_str = hex_digits_to_dec(hex_digits)
                end
                if dec_str ~= nil then
                    if sign == "-" and dec_str ~= "0" then
                        return "-" .. dec_str
                    end
                    return dec_str
                end
            end
        end
        return val
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

    local function format_instruction_bytes_mode(raw_hex_bytes, mode)
        if type(raw_hex_bytes) ~= "string" or raw_hex_bytes == "" then
            return raw_hex_bytes
        end
        local parts = {}
        for byte_hex in raw_hex_bytes:gmatch("%x%x") do
            local val = tonumber(byte_hex, 16)
            if val ~= nil then
                if mode == "hex" then
                    table.insert(parts, string.format("%02x", val))
                elseif mode == "bin" then
                    table.insert(parts, byte_to_bin(val))
                else
                    table.insert(parts, string.format("%03d", val))
                end
            end
        end
        if #parts == 0 then
            return raw_hex_bytes
        end
        return table.concat(parts, " ")
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

    dap.listeners.before.disassemble["hex_mode_formatter"] = function(_, err, response)
        if err or type(response) ~= "table" or type(response.instructions) ~= "table" then
            return
        end
        local target_mode = "dec"
        if hex_mode then
            target_mode = "hex"
        end
        for _, inst in ipairs(response.instructions) do
            if type(inst) == "table" and type(inst.instructionBytes) == "string" then
                if inst._raw_hex_bytes == nil then
                    inst._raw_hex_bytes = inst.instructionBytes
                end
                inst.instructionBytes = format_instruction_bytes_mode(inst._raw_hex_bytes, target_mode)
            end
        end
    end

    local refresh_mem_inspector = nil
    local refresh_asm_viewer = nil

    local function restore_focus_and_cursor(orig_win, orig_buf, orig_cursor)
        if not vim.api.nvim_win_is_valid(orig_win) then
            return
        end
        local cur_win = vim.api.nvim_get_current_win()
        if cur_win ~= orig_win then
            pcall(vim.api.nvim_set_current_win, orig_win)
        end
        if vim.api.nvim_win_get_buf(orig_win) == orig_buf then
            local line_count = vim.api.nvim_buf_line_count(orig_buf)
            local target_row = math.min(orig_cursor[1], line_count)
            if target_row < 1 then
                target_row = 1
            end
            local target_line = vim.api.nvim_buf_get_lines(orig_buf, target_row - 1, target_row, false)[1]
            local max_col = 0
            if type(target_line) == "string" and #target_line > 0 then
                max_col = #target_line - 1
            end
            local target_col = math.min(orig_cursor[2], max_col)
            pcall(vim.api.nvim_win_set_cursor, orig_win, { target_row, target_col })
        end
    end

    local function should_refresh_event_stopped_key(key, has_dap_win)
        if type(key) ~= "string" then
            return false
        end
        if key:find("virtual_text", 1, true) then
            return true
        end
        if not has_dap_win then
            return false
        end
        if key:find("disasm", 1, true) then
            return true
        end
        if key:find("dap%-view") or key:find("dap_view") then
            return true
        end
        if key:find("dapui", 1, true) then
            return true
        end
        return false
    end

    local function toggle_hex_mode()
        local orig_win = vim.api.nvim_get_current_win()
        local orig_buf = vim.api.nvim_win_get_buf(orig_win)
        local orig_cursor = vim.api.nvim_win_get_cursor(orig_win)

        hex_mode = not hex_mode

        if type(refresh_mem_inspector) == "function" then
            refresh_mem_inspector(false, true)
        end
        if type(refresh_asm_viewer) == "function" then
            refresh_asm_viewer(false, true)
        end

        local session = dap.session()
        if session then
            local function run_ui_refresh()
                local has_dap_win = find_dap_win(false) ~= nil
                local stopped_body = {
                    reason = "step",
                    threadId = session.stopped_thread_id,
                }
                for key, listener in pairs(dap.listeners.after.event_stopped) do
                    if should_refresh_event_stopped_key(key, has_dap_win) then
                        pcall(listener, session, nil, stopped_body)
                    end
                end
                if ok_dap_view and has_dap_win and type(dap_view.show_view) == "function" then
                    local ok_state, dv_state = pcall(require, "dap-view.state")
                    if ok_state and type(dv_state) == "table" and type(dv_state.current_section) == "string" then
                        pcall(dap_view.show_view, dv_state.current_section)
                    end
                end
                restore_focus_and_cursor(orig_win, orig_buf, orig_cursor)
                vim.schedule(function()
                    restore_focus_and_cursor(orig_win, orig_buf, orig_cursor)
                end)
                vim.defer_fn(function()
                    local cur_win = vim.api.nvim_get_current_win()
                    if cur_win ~= orig_win then
                        local cur_ft = vim.bo[vim.api.nvim_win_get_buf(cur_win)].filetype
                        if is_dap_filetype(cur_ft) then
                            restore_focus_and_cursor(orig_win, orig_buf, orig_cursor)
                        end
                    end
                end, 35)
            end

            if session.current_frame and type(session.current_frame.id) == "number" then
                local frame = session.current_frame
                session:request("scopes", { frameId = frame.id }, function(err, resp)
                    if not err and type(resp) == "table" and type(resp.scopes) == "table" then
                        frame.scopes = resp.scopes
                    end
                    vim.schedule(run_ui_refresh)
                end)
            else
                run_ui_refresh()
            end
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
    -- 4b. RAD MEMORY, ADDRESS, VIRTUAL-SEARCH & ASM TOOLS
    -- ----------------------------------------------------
    local function get_gdb_rpc_dir(session)
        if session and type(session.config) == "table" and type(session.config._rpc_dir) == "string" then
            return session.config._rpc_dir
        end
        return wine_sessions.rpc_dir
    end

    local function gdb_rpc_call(session, payload, callback)
        local rpc_dir = get_gdb_rpc_dir(session)
        if type(rpc_dir) ~= "string" or rpc_dir == "" then
            callback(nil, "GDB RPC directory is not active")
            return
        end

        local req_path = rpc_dir .. "/req.json"
        local resp_path = rpc_dir .. "/resp.json"
        pcall(vim.fn.delete, resp_path)

        local ok_enc, encoded = pcall(vim.json.encode, payload)
        if not ok_enc then
            callback(nil, "Failed to encode RPC request")
            return
        end

        local wrote = vim.fn.writefile({ encoded }, req_path)
        if wrote ~= 0 then
            callback(nil, "Failed to write RPC request")
            return
        end

        local frame_id = nil
        if session.current_frame then
            frame_id = session.current_frame.id
        end

        session:request("evaluate", {
            expression = "$_nvim_rpc()",
            frameId = frame_id,
            context = "watch",
        }, function(err, _)
            if err then
                local msg = "GDB RPC evaluate failed"
                if type(err.message) == "string" then
                    msg = err.message
                end
                callback(nil, msg)
                return
            end
            local ok_read, lines = pcall(vim.fn.readfile, resp_path)
            if not ok_read or #lines == 0 then
                callback(nil, "GDB RPC produced no response file")
                return
            end
            local ok_dec, data = pcall(vim.json.decode, table.concat(lines, "\n"))
            if not ok_dec or type(data) ~= "table" then
                callback(nil, "Failed to parse GDB RPC response JSON")
                return
            end
            if data.ok ~= true then
                callback(nil, tostring(data.error or "Unknown GDB RPC error"))
                return
            end
            callback(data, nil)
        end)
    end

    local function expr_under_cursor()
        local mode = vim.api.nvim_get_mode().mode
        if mode == "v" or mode == "V" or mode == "\22" then
            local s_pos = vim.fn.getpos("v")
            local e_pos = vim.fn.getpos(".")
            local r1 = s_pos[2]
            local c1 = s_pos[3]
            local r2 = e_pos[2]
            local c2 = e_pos[3]
            if r1 > r2 or (r1 == r2 and c1 > c2) then
                r1, r2 = r2, r1
                c1, c2 = c2, c1
            end
            if r1 == r2 then
                local line = vim.api.nvim_buf_get_lines(0, r1 - 1, r1, false)[1] or ""
                local sel = vim.trim(line:sub(c1, c2))
                if sel ~= "" then
                    return sel
                end
            end
        end

        local line = vim.api.nvim_get_current_line()
        local col = vim.api.nvim_win_get_cursor(0)[2] + 1
        local ch = line:sub(col, col)
        if not ch:match("[%w_%.%->%[%]%*&]") then
            local cword = vim.fn.expand("<cword>")
            return cword
        end

        local function is_expr_char(c)
            return c:match("[%w_%.%-%[%]>*&]") ~= nil
        end

        local left = col
        while left > 1 do
            local prev = line:sub(left - 1, left - 1)
            if is_expr_char(prev) then
                left = left - 1
            else
                break
            end
        end

        local right = col
        while right < #line do
            local nxt = line:sub(right + 1, right + 1)
            if is_expr_char(nxt) then
                right = right + 1
            else
                break
            end
        end

        local raw = line:sub(left, right)
        raw = raw:gsub("^[%.%->]+", ""):gsub("[%.%->]+$", "")
        if raw ~= "" then
            return raw
        end
        return vim.fn.expand("<cword>")
    end

    local function default_mem_expr()
        local cWORD = vim.fn.expand("<cWORD>")
        local hex_match = cWORD:match("0[xX]%x+")
        if hex_match then
            return hex_match
        end
        return expr_under_cursor()
    end

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

    local function open_scratch_float(title, lines, ft, initial_line, on_buf_ready)
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
            local width = math.min(math.max(max_w + 4, 72), math.floor(vim.o.columns * 0.90))
            local height = math.min(math.max(#lines + 2, 10), math.floor(vim.o.lines * 0.80))

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

            local function close_win()
                if vim.api.nvim_win_is_valid(win) then
                    vim.api.nvim_win_close(win, true)
                end
            end

            vim.keymap.set("n", "q", close_win, { buffer = buf, nowait = true, silent = true })
            vim.keymap.set("n", "<Esc>", close_win, { buffer = buf, nowait = true, silent = true })

            if type(on_buf_ready) == "function" then
                on_buf_ready(buf, win, close_win)
            end
        end)
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

    local mem_insp_ns = vim.api.nvim_create_namespace("dap_memory_inspector")

    local function ensure_mem_highlights()
        vim.api.nvim_set_hl(0, "DapMemHeader",    { link = "Title",          default = true })
        vim.api.nvim_set_hl(0, "DapMemSeparator", { link = "WinSeparator",   default = true })
        vim.api.nvim_set_hl(0, "DapMemAddr",      { link = "Constant",       default = true })
        vim.api.nvim_set_hl(0, "DapMemBitWidth",  { link = "Type",           default = true })
        vim.api.nvim_set_hl(0, "DapMemBytes",     { link = "Comment",        default = true })
        vim.api.nvim_set_hl(0, "DapMemModeTag",   { link = "DiagnosticInfo", default = true })
        vim.api.nvim_set_hl(0, "DapMemLabel",     { link = "Keyword",        default = true })
        vim.api.nvim_set_hl(0, "DapMemValue",     { link = "Number",         default = true })
        vim.api.nvim_set_hl(0, "DapMemSecondary", { link = "Special",        default = true })
        vim.api.nvim_set_hl(0, "DapMemAscii",     { link = "String",         default = true })
        vim.api.nvim_set_hl(0, "DapMemHint",      { link = "Comment",        default = true })
    end

    local function hex_addr_to_dec(addr_str)
        local digits = addr_str:match("^0?[xX]?(%x+)$")
        if not digits then
            return addr_str
        end
        local res = hex_digits_to_dec(digits)
        if res == nil then
            return addr_str
        end
        return res
    end

    local function format_dump_addr(addr_str, use_dec)
        if use_dec then
            return hex_addr_to_dec(addr_str)
        end
        return addr_str:lower()
    end

    local function bytes_le_to_u64_str(bytes)
        local hex_str = string.format(
            "%02x%02x%02x%02x%02x%02x%02x%02x",
            bytes[8], bytes[7], bytes[6], bytes[5],
            bytes[4], bytes[3], bytes[2], bytes[1]
        )
        local dec_str = hex_digits_to_dec(hex_str)
        if dec_str == nil then
            return "0x" .. hex_str
        end
        return dec_str
    end

    local function bytes_le_to_i64_str(bytes)
        if bytes[8] < 128 then
            return bytes_le_to_u64_str(bytes)
        end
        local inv = {}
        local carry = 1
        for i = 1, 8 do
            local v = (255 - bytes[i]) + carry
            inv[i] = v % 256
            carry = math.floor(v / 256)
        end
        local hex_str = string.format(
            "%02x%02x%02x%02x%02x%02x%02x%02x",
            inv[8], inv[7], inv[6], inv[5],
            inv[4], inv[3], inv[2], inv[1]
        )
        local mag = hex_digits_to_dec(hex_str)
        if mag == nil then
            return "-?"
        end
        if mag == "0" then
            return "0"
        end
        return "-" .. mag
    end

    local mem_insp_state = {
        buf         = nil,
        win         = nil,
        expr        = nil,
        mem_ref     = nil,
        addr_label  = nil,
        base_addr   = nil,
        region_text = "",
        offset      = 0,
        count       = 256,
        interp_mode = "hex",
        dec_addr    = false,
        raw_bytes   = nil,
    }

    local function next_interp_mode(cur)
        if cur == "dec" then
            return "hex"
        end
        if cur == "hex" then
            return "bin"
        end
        return "dec"
    end

    local search_virtual_memory_for_address = nil

    local function build_mem_inspector_content()
        local raw = mem_insp_state.raw_bytes
        if type(raw) ~= "string" or #raw == 0 then
            return { "(no memory bytes)" }, {}
        end

        local bytes = {}
        for i = 1, #raw do
            table.insert(bytes, string.byte(raw, i))
        end

        local lines = {}
        local hls = {}

        local function add_hl(row_0, col_start, col_end, group)
            if col_end > col_start then
                table.insert(hls, { row_0, col_start, col_end, group })
            end
        end

        local function add_kv_line(key_label, val_text, val_group, extra_text, extra_group)
            local prefix = string.format("%-7s: ", key_label)
            local line = prefix .. val_text
            if extra_text ~= nil and extra_text ~= "" then
                line = line .. extra_text
            end
            local row_0 = #lines
            table.insert(lines, line)
            add_hl(row_0, 0, #prefix, "DapMemHeader")
            add_hl(row_0, #prefix, #prefix + #val_text, val_group)
            if extra_text ~= nil and extra_text ~= "" and extra_group ~= nil then
                add_hl(row_0, #prefix + #val_text, #line, extra_group)
            end
        end

        local cur_hex_addr = add_hex_offset(mem_insp_state.base_addr, mem_insp_state.offset)
        local cur_addr_display = format_dump_addr(cur_hex_addr, mem_insp_state.dec_addr)
        add_kv_line("Expr", mem_insp_state.expr, "DapMemValue", nil, nil)
        add_kv_line(
            "Address",
            cur_addr_display,
            "DapMemAddr",
            string.format("  (Offset: %+d)", mem_insp_state.offset),
            "DapMemHint"
        )
        if type(mem_insp_state.region_text) == "string" and mem_insp_state.region_text ~= "" then
            add_kv_line("Region", mem_insp_state.region_text, "DapMemHint", nil, nil)
        end

        local sep_line = string.rep("-", 78)
        table.insert(lines, sep_line)
        add_hl(#lines - 1, 0, #sep_line, "DapMemSeparator")

        local mode_tag     = "[" .. mem_insp_state.interp_mode:upper() .. "]"
        local interp_title = "Little-Endian Interpretations "
        local interp_hint  = "  [f/Tab] Mode: dec -> hex -> bin"
        local interp_hdr   = interp_title .. mode_tag .. interp_hint
        table.insert(lines, interp_hdr)
        add_hl(#lines - 1, 0, #interp_title, "DapMemHeader")
        add_hl(#lines - 1, #interp_title, #interp_title + #mode_tag, "DapMemModeTag")
        add_hl(#lines - 1, #interp_title + #mode_tag, #interp_hdr, "DapMemHint")

        local rows_spec = {
            { width = "8-bit",  n = 1, bin_label = "bin8:" },
            { width = "16-bit", n = 2, bin_label = "bin16:" },
            { width = "32-bit", n = 4, bin_label = "bin32:" },
            { width = "64-bit", n = 8, bin_label = "bin64:" },
        }

        local left_col_width = 40
        for _, spec in ipairs(rows_spec) do
            if #bytes >= spec.n then
                local hex_parts = {}
                for idx = 1, spec.n do
                    table.insert(hex_parts, string.format("%02x", bytes[idx]))
                end
                local bit_col       = string.format("%-6s", spec.width)
                local le_col        = "[LE: " .. table.concat(hex_parts, " ") .. "]"
                local left_text     = "  " .. bit_col .. " " .. le_col
                local pad_len       = math.max(2, left_col_width - #left_text)
                local padding       = string.rep(" ", pad_len)

                local fmt_label     = ""
                local primary_val   = ""
                local secondary_val = ""

                if mem_insp_state.interp_mode == "hex" then
                    fmt_label = string.format("%-7s", "hex:")
                    local be_hex = {}
                    for idx = spec.n, 1, -1 do
                        table.insert(be_hex, string.format("%02x", bytes[idx]))
                    end
                    primary_val = "0x" .. table.concat(be_hex)
                elseif mem_insp_state.interp_mode == "bin" then
                    fmt_label = string.format("%-7s", spec.bin_label)
                    local bin_parts = {}
                    for idx = spec.n, 1, -1 do
                        table.insert(bin_parts, byte_to_bin(bytes[idx]))
                    end
                    primary_val = table.concat(bin_parts, " ")
                else
                    fmt_label = string.format("%-7s", "dec:")
                    if spec.n == 1 then
                        local u8 = bytes[1]
                        local i8 = u8
                        if u8 >= 128 then
                            i8 = u8 - 256
                        end
                        primary_val = tostring(u8)
                        secondary_val = string.format("  (i8: %d)", i8)
                    elseif spec.n == 2 then
                        local u16 = bytes[1] + bytes[2] * 256
                        local i16 = u16
                        if u16 >= 32768 then
                            i16 = u16 - 65536
                        end
                        primary_val = tostring(u16)
                        secondary_val = string.format("  (i16: %d)", i16)
                    elseif spec.n == 4 then
                        local u32 = bytes[1] + bytes[2] * 256 + bytes[3] * 65536 + bytes[4] * 16777216
                        local i32 = u32
                        if u32 >= 2147483648 then
                            i32 = u32 - 4294967296
                        end
                        local f32 = decode_f32_le(bytes[1], bytes[2], bytes[3], bytes[4])
                        primary_val = string.format("%.0f", u32)
                        secondary_val = string.format("  (i32: %.0f, f32: %s)", i32, f32)
                    else
                        local u64_str = bytes_le_to_u64_str(bytes)
                        local i64_str = bytes_le_to_i64_str(bytes)
                        local f64 = decode_f64_le(
                            bytes[1], bytes[2], bytes[3], bytes[4],
                            bytes[5], bytes[6], bytes[7], bytes[8]
                        )
                        primary_val = u64_str
                        secondary_val = string.format("  (i64: %s, f64: %s)", i64_str, f64)
                    end
                end

                local line = left_text .. padding .. fmt_label .. primary_val .. secondary_val
                local row_0 = #lines
                table.insert(lines, line)

                local bit_start = 2
                local bit_end   = bit_start + #bit_col
                local le_start  = bit_end + 1
                local le_end    = le_start + #le_col
                local lbl_start = #left_text + pad_len
                local lbl_end   = lbl_start + #fmt_label
                local val_start = lbl_end
                local val_end   = val_start + #primary_val

                add_hl(row_0, bit_start, bit_end, "DapMemBitWidth")
                add_hl(row_0, le_start,  le_end,  "DapMemBytes")
                add_hl(row_0, lbl_start, lbl_end, "DapMemLabel")
                add_hl(row_0, val_start, val_end, "DapMemValue")
                if secondary_val ~= "" then
                    add_hl(row_0, val_end, #line, "DapMemSecondary")
                end
            end
        end

        table.insert(lines, sep_line)
        add_hl(#lines - 1, 0, #sep_line, "DapMemSeparator")

        local byte_tag = "[Bytes: DEC]"
        if hex_mode then
            byte_tag = "[Bytes: HEX]"
        end
        local addr_tag = "[Addr: HEX]"
        if mem_insp_state.dec_addr then
            addr_tag = "[Addr: DEC]"
        end

        local dump_title = "Raw Memory Dump (8 bytes/row)"
        local dump_tags  = byte_tag .. " " .. addr_tag
        local dump_hints = "  [x] Bytes  [a] Addr  [ [|] ] Page  [s] SearchAddr  [m] MemView  [r] Refresh  [q] Close"
        local dump_hdr = dump_title .. dump_tags .. dump_hints
        table.insert(lines, dump_hdr)
        add_hl(#lines - 1, 0, #dump_title, "DapMemHeader")
        add_hl(#lines - 1, #dump_title, #dump_title + #dump_tags, "DapMemModeTag")
        add_hl(#lines - 1, #dump_title + #dump_tags, #dump_hdr, "DapMemHint")

        local half_width = 31
        if hex_mode then
            half_width = 23
        end

        for row_offset = 0, #bytes - 1, 16 do
            local left_col = {}
            local right_col = {}
            local ascii_col = {}
            for col = 1, 16 do
                local idx = row_offset + col
                local token
                if idx <= #bytes then
                    local b = bytes[idx]
                    if hex_mode then
                        token = string.format("%02x", b)
                    else
                        token = string.format("%03d", b)
                    end
                    if b >= 32 and b <= 126 then
                        table.insert(ascii_col, string.char(b))
                    else
                        table.insert(ascii_col, ".")
                    end
                else
                    if hex_mode then
                        token = "  "
                    else
                        token = "   "
                    end
                    table.insert(ascii_col, " ")
                end

                if col <= 8 then
                    table.insert(left_col, token)
                else
                    table.insert(right_col, token)
                end
            end

            local row_hex_addr = add_hex_offset(mem_insp_state.base_addr, mem_insp_state.offset + row_offset)
            local row_label = format_dump_addr(row_hex_addr, mem_insp_state.dec_addr)
            local left_str = string.format("%-" .. tostring(half_width) .. "s", table.concat(left_col, " "))
            local right_str = string.format("%-" .. tostring(half_width) .. "s", table.concat(right_col, " "))
            local bytes_str = left_str .. "  " .. right_str
            local ascii_str = "|" .. table.concat(ascii_col) .. "|"
            local prefix = "  " .. row_label .. ":  "
            local line = prefix .. bytes_str .. "  " .. ascii_str
            local row_0 = #lines
            table.insert(lines, line)
            add_hl(row_0, 2, 2 + #row_label, "DapMemAddr")
            add_hl(row_0, #prefix, #prefix + #bytes_str, "DapMemValue")
            add_hl(row_0, #prefix + #bytes_str + 2, #line, "DapMemAscii")
        end

        return lines, hls
    end

    local function render_mem_inspector_window()
        ensure_mem_highlights()
        local lines, hls = build_mem_inspector_content()
        local max_w = 0
        for _, line in ipairs(lines) do
            if #line > max_w then
                max_w = #line
            end
        end
        local width  = math.min(math.max(max_w + 4, 88), math.floor(vim.o.columns * 0.94))
        local height = math.min(math.max(#lines + 2, 12), math.floor(vim.o.lines * 0.85))

        if mem_insp_state.buf == nil or not vim.api.nvim_buf_is_valid(mem_insp_state.buf) then
            local buf = vim.api.nvim_create_buf(false, true)
            vim.bo[buf].bufhidden = "wipe"
            mem_insp_state.buf = buf

            local function close_inspector()
                if mem_insp_state.win ~= nil and vim.api.nvim_win_is_valid(mem_insp_state.win) then
                    vim.api.nvim_win_close(mem_insp_state.win, true)
                end
                mem_insp_state.win = nil
            end

            vim.keymap.set("n", "q", close_inspector, { buffer = buf, nowait = true, silent = true })
            vim.keymap.set("n", "<Esc>", close_inspector, { buffer = buf, nowait = true, silent = true })

            vim.keymap.set("n", "f", function()
                mem_insp_state.interp_mode = next_interp_mode(mem_insp_state.interp_mode)
                render_mem_inspector_window()
            end, { buffer = buf, nowait = true, silent = true })

            vim.keymap.set("n", "<Tab>", function()
                mem_insp_state.interp_mode = next_interp_mode(mem_insp_state.interp_mode)
                render_mem_inspector_window()
            end, { buffer = buf, nowait = true, silent = true })

            vim.keymap.set("n", "x", function()
                toggle_hex_mode()
            end, { buffer = buf, nowait = true, silent = true })

            vim.keymap.set("n", "a", function()
                mem_insp_state.dec_addr = not mem_insp_state.dec_addr
                render_mem_inspector_window()
            end, { buffer = buf, nowait = true, silent = true })

            vim.keymap.set("n", "r", function()
                if type(refresh_mem_inspector) == "function" then
                    refresh_mem_inspector(true, false)
                end
            end, { buffer = buf, nowait = true, silent = true })

            vim.keymap.set("n", "]", function()
                mem_insp_state.offset = mem_insp_state.offset + mem_insp_state.count
                if type(refresh_mem_inspector) == "function" then
                    refresh_mem_inspector(true, false)
                end
            end, { buffer = buf, nowait = true, silent = true })

            vim.keymap.set("n", "[", function()
                mem_insp_state.offset = mem_insp_state.offset - mem_insp_state.count
                if type(refresh_mem_inspector) == "function" then
                    refresh_mem_inspector(true, false)
                end
            end, { buffer = buf, nowait = true, silent = true })

            vim.keymap.set("n", "s", function()
                local target_addr = add_hex_offset(mem_insp_state.base_addr, mem_insp_state.offset)
                close_inspector()
                if type(search_virtual_memory_for_address) == "function" then
                    search_virtual_memory_for_address(target_addr)
                end
            end, { buffer = buf, nowait = true, silent = true })

            vim.keymap.set("n", "m", function()
                local target_addr = add_hex_offset(mem_insp_state.base_addr, mem_insp_state.offset)
                close_inspector()
                if ok_memview then
                    vim.cmd("DapMemView " .. target_addr)
                else
                    vim.notify("nvim-dap-memview not loaded", vim.log.levels.WARN)
                end
            end, { buffer = buf, nowait = true, silent = true })
        end

        vim.bo[mem_insp_state.buf].modifiable = true
        vim.api.nvim_buf_set_lines(mem_insp_state.buf, 0, -1, false, lines)
        vim.bo[mem_insp_state.buf].modifiable = false

        vim.api.nvim_buf_clear_namespace(mem_insp_state.buf, mem_insp_ns, 0, -1)
        for _, item in ipairs(hls) do
            pcall(vim.api.nvim_buf_add_highlight, mem_insp_state.buf, mem_insp_ns, item[4], item[1], item[2], item[3])
        end

        if mem_insp_state.win == nil or not vim.api.nvim_win_is_valid(mem_insp_state.win) then
            mem_insp_state.win = vim.api.nvim_open_win(mem_insp_state.buf, true, {
                relative  = "editor",
                width     = width,
                height    = height,
                row       = math.floor((vim.o.lines - height) / 2),
                col       = math.floor((vim.o.columns - width) / 2),
                style     = "minimal",
                border    = "rounded",
                title     = " Memory Inspector ",
                title_pos = "center",
            })
        else
            pcall(vim.api.nvim_win_set_config, mem_insp_state.win, {
                relative  = "editor",
                width     = width,
                height    = height,
                row       = math.floor((vim.o.lines - height) / 2),
                col       = math.floor((vim.o.columns - width) / 2),
            })
        end
    end

    refresh_mem_inspector = function(re_read, sync_global_hex)
        if mem_insp_state.win == nil or not vim.api.nvim_win_is_valid(mem_insp_state.win) then
            return
        end
        if sync_global_hex and mem_insp_state.interp_mode ~= "bin" then
            if hex_mode then
                mem_insp_state.interp_mode = "hex"
            else
                mem_insp_state.interp_mode = "dec"
            end
        end
        if not re_read and type(mem_insp_state.raw_bytes) == "string" then
            render_mem_inspector_window()
            return
        end
        local session = dap.session()
        if not session or type(mem_insp_state.mem_ref) ~= "string" then
            return
        end
        session:request("readMemory", {
            memoryReference = mem_insp_state.mem_ref,
            offset          = mem_insp_state.offset,
            count           = mem_insp_state.count,
        }, function(mem_err, mem_resp)
            if mem_err or type(mem_resp) ~= "table" or type(mem_resp.data) ~= "string" then
                vim.schedule(function()
                    vim.notify("readMemory failed in Memory Inspector", vim.log.levels.ERROR)
                end)
                return
            end
            if not vim.base64 or type(vim.base64.decode) ~= "function" then
                return
            end
            local ok_dec, decoded = pcall(vim.base64.decode, mem_resp.data)
            if not ok_dec or type(decoded) ~= "string" or #decoded == 0 then
                return
            end
            mem_insp_state.raw_bytes = decoded
            if type(mem_resp.address) == "string" and mem_resp.address ~= "" and mem_insp_state.offset == 0 then
                mem_insp_state.base_addr = mem_resp.address
            end
            vim.schedule(render_mem_inspector_window)
        end)
    end

    dap.listeners.after.event_stopped["mem_inspector_refresh"] = function()
        if mem_insp_state.win ~= nil and vim.api.nvim_win_is_valid(mem_insp_state.win) then
            refresh_mem_inspector(true, false)
        end
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
            count = mem_insp_state.count,
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
                mem_insp_state.expr        = expr
                mem_insp_state.mem_ref     = mem_ref
                mem_insp_state.addr_label  = addr_label
                mem_insp_state.base_addr   = final_addr
                mem_insp_state.region_text = region_text
                mem_insp_state.offset      = 0
                mem_insp_state.raw_bytes   = raw_bytes
                if hex_mode then
                    mem_insp_state.interp_mode = "hex"
                else
                    mem_insp_state.interp_mode = "dec"
                end
                vim.schedule(render_mem_inspector_window)
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
            elseif session.config and session.config.type == "gdb" then
                gdb_rpc_call(session, { action = "region", expr = final_addr }, function(rpc_res, _)
                    local region_text = ""
                    if type(rpc_res) == "table" and type(rpc_res.region) == "string" then
                        region_text = rpc_res.region
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

    local function display_gdb_search_results(session, res)
        local out_lines = {
            string.format("Query: [%s] %s  |  Scope: %s", tostring(res.kind), tostring(res.query), tostring(res.scope)),
            string.format("Map  : %s (%d regions)  |  Hits: %d", tostring(res.map_source), tonumber(res.region_count) or 0, #res.hits),
            "Keys : [<CR>/m] Inspect Memory  [s] Search For Hit Addr  [y] Yank Addr  [q] Close",
            string.rep("-", 92),
        }

        if #res.hits == 0 then
            table.insert(out_lines, "(no matches found)")
        else
            for _, hit in ipairs(res.hits) do
                table.insert(out_lines, string.format(
                    "%-18s  [%-7s]  (%-8s)  %s  %s",
                    tostring(hit.addr),
                    tostring(hit.tag),
                    tostring(hit.perms),
                    tostring(hit.preview),
                    tostring(hit.label)
                ))
            end
        end

        open_scratch_float("Virtual Memory Search Results", out_lines, "", 5, function(buf, _, close_win)
            local function line_addr()
                local cur = vim.api.nvim_get_current_line()
                return cur:match("0[xX]%x+")
            end

            vim.keymap.set("n", "y", function()
                local addr = line_addr()
                if addr then
                    vim.fn.setreg("+", addr)
                    vim.notify("Yanked " .. addr, vim.log.levels.INFO)
                end
            end, { buffer = buf, nowait = true, silent = true })

            vim.keymap.set("n", "<CR>", function()
                local addr = line_addr()
                if addr then
                    close_win()
                    read_and_display_memory(session, addr, addr, addr)
                end
            end, { buffer = buf, nowait = true, silent = true })

            vim.keymap.set("n", "m", function()
                local addr = line_addr()
                if addr then
                    close_win()
                    read_and_display_memory(session, addr, addr, addr)
                end
            end, { buffer = buf, nowait = true, silent = true })

            vim.keymap.set("n", "s", function()
                local addr = line_addr()
                if addr then
                    close_win()
                    if type(search_virtual_memory_for_address) == "function" then
                        search_virtual_memory_for_address(addr)
                    end
                end
            end, { buffer = buf, nowait = true, silent = true })
        end)
    end

    search_virtual_memory_for_address = function(default_query)
        local session = dap.session()
        if not session then
            vim.notify("No active DAP session", vim.log.levels.WARN)
            return
        end

        local adapter_type = ""
        if type(session.config) == "table" and type(session.config.type) == "string" then
            adapter_type = session.config.type
        end

        if adapter_type ~= "gdb" then
            vim.ui.input({
                prompt = "LLDB memory find args (e.g. -p " .. tostring(default_query or "0x...") .. " START END): ",
            }, function(find_args)
                if not find_args or vim.trim(find_args) == "" then
                    return
                end
                local frame_id = nil
                if session.current_frame then
                    frame_id = session.current_frame.id
                end
                local eval_cmd = "memory find " .. vim.trim(find_args)
                if adapter_type == "codelldb" then
                    eval_cmd = "`" .. eval_cmd
                end
                session:request("evaluate", {
                    expression = eval_cmd,
                    frameId = frame_id,
                    context = "repl",
                }, function(err, resp)
                    if err or type(resp) ~= "table" then
                        vim.schedule(function()
                            vim.notify("LLDB memory find failed", vim.log.levels.ERROR)
                        end)
                        return
                    end
                    local out_lines = vim.split(tostring(resp.result or "(no output)"), "\n", { plain = true })
                    open_scratch_float("LLDB Memory Search", out_lines, "")
                end)
            end)
            return
        end

        local kinds = {
            { id = "ptr",   label = "1. Pointer / Address (64-bit & 32-bit LE)" },
            { id = "ascii", label = "2. ASCII / UTF-8 String" },
            { id = "utf16", label = "3. Windows UTF-16LE Wide String" },
            { id = "u32",   label = "4. Unsigned 32-bit Integer (u32 LE)" },
            { id = "i32",   label = "5. Signed 32-bit Integer (i32 LE)" },
            { id = "u64",   label = "6. Unsigned 64-bit Integer (u64 LE)" },
            { id = "hex",   label = "7. Raw Hex Byte Pattern (e.g. 48 8b 05)" },
        }

        vim.ui.select(kinds, {
            prompt = "Virtual Memory Search Type:",
            format_item = function(item)
                return item.label
            end,
        }, function(kind_choice)
            if not kind_choice then
                return
            end

            local seed = ""
            if kind_choice.id == "ptr" then
                if type(default_query) == "string" and default_query ~= "" then
                    seed = default_query
                else
                    seed = default_mem_expr()
                end
            end

            vim.ui.input({
                prompt = "Search value (" .. kind_choice.id .. ", expr or literal): ",
                default = seed,
            }, function(query)
                if not query or vim.trim(query) == "" then
                    return
                end

                local scopes = {
                    { id = "app",   label = "1. App scan (stack around $rsp + main exe, <0.2s)" },
                    { id = "heap",  label = "2. Heap + App scan (stack + exe + private RW)" },
                    { id = "all",   label = "3. Full scan (entire readable virtual memory)" },
                    { id = "range", label = "4. Explicit address range (start - end)" },
                }

                vim.ui.select(scopes, {
                    prompt = "Scan Scope:",
                    format_item = function(item)
                        return item.label
                    end,
                }, function(scope_choice)
                    if not scope_choice then
                        return
                    end

                    if scope_choice.id == "range" then
                        vim.ui.input({ prompt = "Start address (0x...): " }, function(start_in)
                            if not start_in or vim.trim(start_in) == "" then
                                return
                            end
                            vim.ui.input({ prompt = "End address (0x...): " }, function(end_in)
                                if not end_in or vim.trim(end_in) == "" then
                                    return
                                end
                                gdb_rpc_call(session, {
                                    action = "search",
                                    kind = kind_choice.id,
                                    query = vim.trim(query),
                                    scope = "all",
                                    start = vim.trim(start_in),
                                    ["end"] = vim.trim(end_in),
                                    max_hits = 128,
                                }, function(res, err_msg)
                                    if err_msg ~= nil then
                                        vim.schedule(function()
                                            vim.notify("Search failed: " .. err_msg, vim.log.levels.ERROR)
                                        end)
                                        return
                                    end
                                    display_gdb_search_results(session, res)
                                end)
                            end)
                        end)
                        return
                    end

                    gdb_rpc_call(session, {
                        action = "search",
                        kind = kind_choice.id,
                        query = vim.trim(query),
                        scope = scope_choice.id,
                        max_hits = 128,
                    }, function(res, err_msg)
                        if err_msg ~= nil then
                            vim.schedule(function()
                                vim.notify("Search failed: " .. err_msg, vim.log.levels.ERROR)
                            end)
                            return
                        end
                        display_gdb_search_results(session, res)
                    end)
                end)
            end)
        end)
    end

    local function print_expr_address_prompt()
        local session = dap.session()
        if not session then
            vim.notify("Pause at a breakpoint first", vim.log.levels.WARN)
            return
        end

        local default_expr = expr_under_cursor()
        vim.ui.input({
            prompt = "Print Address (&var, obj.field, ptr->member): ",
            default = default_expr,
        }, function(input)
            if not input or vim.trim(input) == "" then
                return
            end
            local expr = vim.trim(input)
            local adapter_type = ""
            if type(session.config) == "table" and type(session.config.type) == "string" then
                adapter_type = session.config.type
            end

            if adapter_type == "gdb" then
                gdb_rpc_call(session, { action = "addr", expr = expr }, function(res, err_msg)
                    if err_msg ~= nil then
                        vim.schedule(function()
                            vim.notify("Address lookup failed: " .. err_msg, vim.log.levels.ERROR)
                        end)
                        return
                    end

                    local lval = res.lvalue_addr or "(register / non-lvalue)"
                    local targ = res.target_addr
                    local insp = res.inspect_addr

                    local lines = {
                        "Expression     : " .. tostring(res.expr),
                        "Type / Size    : " .. tostring(res.type) .. " (" .. tostring(res.size) .. " bytes)",
                        "Address (&expr): " .. tostring(lval),
                    }
                    if targ ~= nil then
                        table.insert(lines, "Target Pointer : " .. tostring(targ))
                    end
                    table.insert(lines, "Value          : " .. tostring(res.value))
                    table.insert(lines, string.rep("-", 72))
                    table.insert(lines, "Keys: [m] Inspect &expr  [p] Inspect Target  [s] Search &expr  [S] Search Target  [y] Yank  [q] Close")

                    open_scratch_float("Variable / Field Address", lines, "", 3, function(buf, _, close_win)
                        vim.keymap.set("n", "y", function()
                            local to_yank = insp or targ
                            if to_yank then
                                vim.fn.setreg("+", to_yank)
                                vim.notify("Yanked " .. to_yank, vim.log.levels.INFO)
                            end
                        end, { buffer = buf, nowait = true, silent = true })

                        vim.keymap.set("n", "m", function()
                            if insp then
                                close_win()
                                read_and_display_memory(session, "&(" .. expr .. ")", insp, insp)
                            else
                                vim.notify("No addressable memory location", vim.log.levels.WARN)
                            end
                        end, { buffer = buf, nowait = true, silent = true })

                        vim.keymap.set("n", "p", function()
                            if targ then
                                close_win()
                                read_and_display_memory(session, expr, targ, targ)
                            else
                                vim.notify("Expression is not a pointer/array", vim.log.levels.WARN)
                            end
                        end, { buffer = buf, nowait = true, silent = true })

                        vim.keymap.set("n", "s", function()
                            if insp then
                                close_win()
                                search_virtual_memory_for_address(insp)
                            else
                                vim.notify("No addressable memory location", vim.log.levels.WARN)
                            end
                        end, { buffer = buf, nowait = true, silent = true })

                        vim.keymap.set("n", "S", function()
                            if targ then
                                close_win()
                                search_virtual_memory_for_address(targ)
                            else
                                vim.notify("Expression is not a pointer/array", vim.log.levels.WARN)
                            end
                        end, { buffer = buf, nowait = true, silent = true })
                    end)
                end)
                return
            end

            resolve_addr_expr(session, expr, function(mem_ref, addr_label)
                local frame_id = nil
                if session.current_frame then
                    frame_id = session.current_frame.id
                end
                session:request("evaluate", {
                    expression = expr,
                    frameId = frame_id,
                    context = "watch",
                }, function(_, eval_resp)
                    local val_str = "(unavailable)"
                    local type_str = "(unknown)"
                    if type(eval_resp) == "table" then
                        if type(eval_resp.result) == "string" then
                            val_str = eval_resp.result
                        end
                        if type(eval_resp.type) == "string" then
                            type_str = eval_resp.type
                        end
                    end
                    local lines = {
                        "Expression     : " .. expr,
                        "Type           : " .. type_str,
                        "Address        : " .. tostring(addr_label),
                        "Value          : " .. val_str,
                        string.rep("-", 72),
                        "Keys: [m] Inspect Memory  [y] Yank Address  [q] Close",
                    }
                    open_scratch_float("Variable / Field Address", lines, "", 3, function(buf, _, close_win)
                        vim.keymap.set("n", "y", function()
                            vim.fn.setreg("+", tostring(addr_label))
                            vim.notify("Yanked " .. tostring(addr_label), vim.log.levels.INFO)
                        end, { buffer = buf, nowait = true, silent = true })

                        vim.keymap.set("n", "m", function()
                            close_win()
                            read_and_display_memory(session, expr, mem_ref, addr_label)
                        end, { buffer = buf, nowait = true, silent = true })
                    end)
                end)
            end)
        end)
    end

    local function virtual_memory_menu()
        local session = dap.session()
        if not session then
            vim.notify("No active DAP session", vim.log.levels.WARN)
            return
        end

        local adapter_type = ""
        if type(session.config) == "table" and type(session.config.type) == "string" then
            adapter_type = session.config.type
        end

        if adapter_type == "gdb" then
            local actions = {
                { id = "search", label = "1. Search address / pattern in virtual memory" },
                { id = "vmmap",  label = "2. All virtual memory regions (vmmap / monitor mem)" },
                { id = "region", label = "3. Region info for address / &var" },
                { id = "lookup", label = "4. Symbol / section at address (info symbol)" },
            }

            vim.ui.select(actions, {
                prompt = "GDB / Wine Virtual Memory Tools:",
                format_item = function(item)
                    return item.label
                end,
            }, function(choice)
                if not choice then
                    return
                end

                if choice.id == "search" then
                    search_virtual_memory_for_address(nil)
                    return
                end

                if choice.id == "vmmap" then
                    gdb_rpc_call(session, { action = "vmmap" }, function(res, err_msg)
                        if err_msg ~= nil then
                            vim.schedule(function()
                                vim.notify("vmmap failed: " .. err_msg, vim.log.levels.ERROR)
                            end)
                            return
                        end
                        local out_lines = {
                            "Source: " .. tostring(res.source),
                            string.rep("-", 78),
                        }
                        if type(res.regions) == "table" and #res.regions > 0 then
                            for _, r in ipairs(res.regions) do
                                table.insert(out_lines, string.format(
                                    "0x%016x - 0x%016x  %-10s  %s",
                                    r.start, r["end"], tostring(r.perms), tostring(r.label)
                                ))
                            end
                        end
                        if type(res.raw) == "string" and vim.trim(res.raw) ~= "" then
                            table.insert(out_lines, string.rep("-", 78))
                            table.insert(out_lines, "Raw debugger output:")
                            for _, l in ipairs(vim.split(res.raw, "\n", { plain = true })) do
                                table.insert(out_lines, l)
                            end
                        end
                        open_scratch_float("Virtual Memory Map", out_lines, "")
                    end)
                    return
                end

                if choice.id == "region" then
                    vim.ui.input({ prompt = "Address or &var: ", default = default_mem_expr() }, function(addr_in)
                        if not addr_in or vim.trim(addr_in) == "" then
                            return
                        end
                        gdb_rpc_call(session, { action = "region", expr = vim.trim(addr_in) }, function(res, err_msg)
                            if err_msg ~= nil then
                                vim.schedule(function()
                                    vim.notify("Region lookup failed: " .. err_msg, vim.log.levels.ERROR)
                                end)
                                return
                            end
                            local txt = res.region
                            if type(txt) ~= "string" or vim.trim(txt) == "" then
                                txt = "(no matching region found)"
                            end
                            open_scratch_float("Memory Region", {
                                "Target: " .. vim.trim(addr_in),
                                string.rep("-", 72),
                                txt,
                            }, "")
                        end)
                    end)
                    return
                end

                if choice.id == "lookup" then
                    vim.ui.input({ prompt = "Address or &var: ", default = default_mem_expr() }, function(addr_in)
                        if not addr_in or vim.trim(addr_in) == "" then
                            return
                        end
                        local frame_id = nil
                        if session.current_frame then
                            frame_id = session.current_frame.id
                        end
                        session:request("evaluate", {
                            expression = "info symbol " .. vim.trim(addr_in),
                            frameId = frame_id,
                            context = "repl",
                        }, function(err, resp)
                            if err or type(resp) ~= "table" then
                                vim.schedule(function()
                                    vim.notify("info symbol failed", vim.log.levels.ERROR)
                                end)
                                return
                            end
                            local out_lines = vim.split(tostring(resp.result or "(no output)"), "\n", { plain = true })
                            open_scratch_float("Symbol Lookup", out_lines, "")
                        end)
                    end)
                end
            end)
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
                if adapter_type == "codelldb" and eval_cmd:sub(1, 1) ~= "`" then
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
                search_virtual_memory_for_address(nil)
            end
        end)
    end

    local asm_view_state = {
        buf          = nil,
        win          = nil,
        pc_ref       = "",
        instructions = {},
        byte_mode    = "dec",
        dec_addr     = false,
    }

    local function build_asm_lines()
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

        local pc_display = asm_view_state.pc_ref
        if asm_view_state.dec_addr then
            pc_display = hex_addr_to_dec(asm_view_state.pc_ref)
        end

        local mode_tag = "[" .. asm_view_state.byte_mode:upper() .. "]"
        local addr_tag = "[Addr: HEX]"
        if asm_view_state.dec_addr then
            addr_tag = "[Addr: DEC]"
        end

        local lines = {
            "PC: " .. pc_display .. "  " .. mode_tag .. " " .. addr_tag .. "  ([f/Tab] dec->hex->bin  [a] addr  [r] refresh  q/<Esc> close)",
            string.rep("-", 92),
        }

        local byte_col_width = 34
        if asm_view_state.byte_mode == "bin" then
            byte_col_width = 62
        elseif asm_view_state.byte_mode == "hex" then
            byte_col_width = 26
        end

        local norm_pc = normalize_hex_addr(asm_view_state.pc_ref)
        local last_loc_key = ""
        local pc_line_nr = nil

        for _, inst in ipairs(asm_view_state.instructions) do
            local src_path = inst.path
            if src_path == nil and type(inst.location) == "table" then
                src_path = inst.location.path
            end
            local src_line_nr = inst.line
            if type(src_path) == "string" and src_path ~= "" and type(src_line_nr) == "number" then
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

            local raw_addr = tostring(inst.address or "")
            local disp_addr = raw_addr
            if asm_view_state.dec_addr then
                disp_addr = hex_addr_to_dec(raw_addr)
            end

            local raw_hex = inst._raw_hex_bytes
            if raw_hex == nil then
                raw_hex = tostring(inst.instructionBytes or "")
            end
            local bytes_str = format_instruction_bytes_mode(raw_hex, asm_view_state.byte_mode)

            local asm = tostring(inst.instruction or "")
            local is_pc = normalize_hex_addr(raw_addr) == norm_pc
            local marker = "  "
            if is_pc then
                marker = "->"
            end
            local sym = ""
            if type(inst.symbol) == "string" and inst.symbol ~= "" then
                sym = "<" .. inst.symbol .. "> "
            end

            table.insert(lines, string.format(
                "%s %-18s  %-" .. tostring(byte_col_width) .. "s  %s%s",
                marker, disp_addr, bytes_str, sym, asm
            ))
            if is_pc then
                pc_line_nr = #lines
            end
        end

        return lines, pc_line_nr
    end

    local function render_asm_window()
        local lines, pc_line_nr = build_asm_lines()
        local max_w = 0
        for _, line in ipairs(lines) do
            if #line > max_w then
                max_w = #line
            end
        end
        local width  = math.min(math.max(max_w + 4, 82), math.floor(vim.o.columns * 0.94))
        local height = math.min(math.max(#lines + 2, 12), math.floor(vim.o.lines * 0.82))

        if asm_view_state.buf == nil or not vim.api.nvim_buf_is_valid(asm_view_state.buf) then
            local buf = vim.api.nvim_create_buf(false, true)
            vim.bo[buf].bufhidden = "wipe"
            vim.bo[buf].filetype = "asm"
            asm_view_state.buf = buf

            local function close_asm()
                if asm_view_state.win ~= nil and vim.api.nvim_win_is_valid(asm_view_state.win) then
                    vim.api.nvim_win_close(asm_view_state.win, true)
                end
                asm_view_state.win = nil
            end

            vim.keymap.set("n", "q", close_asm, { buffer = buf, nowait = true, silent = true })
            vim.keymap.set("n", "<Esc>", close_asm, { buffer = buf, nowait = true, silent = true })

            vim.keymap.set("n", "f", function()
                asm_view_state.byte_mode = next_interp_mode(asm_view_state.byte_mode)
                render_asm_window()
            end, { buffer = buf, nowait = true, silent = true })

            vim.keymap.set("n", "<Tab>", function()
                asm_view_state.byte_mode = next_interp_mode(asm_view_state.byte_mode)
                render_asm_window()
            end, { buffer = buf, nowait = true, silent = true })

            vim.keymap.set("n", "a", function()
                asm_view_state.dec_addr = not asm_view_state.dec_addr
                render_asm_window()
            end, { buffer = buf, nowait = true, silent = true })

            vim.keymap.set("n", "r", function()
                if type(refresh_asm_viewer) == "function" then
                    refresh_asm_viewer(true, false)
                end
            end, { buffer = buf, nowait = true, silent = true })
        end

        vim.bo[asm_view_state.buf].modifiable = true
        vim.api.nvim_buf_set_lines(asm_view_state.buf, 0, -1, false, lines)
        vim.bo[asm_view_state.buf].modifiable = false

        if asm_view_state.win == nil or not vim.api.nvim_win_is_valid(asm_view_state.win) then
            asm_view_state.win = vim.api.nvim_open_win(asm_view_state.buf, true, {
                relative  = "editor",
                width     = width,
                height    = height,
                row       = math.floor((vim.o.lines - height) / 2),
                col       = math.floor((vim.o.columns - width) / 2),
                style     = "minimal",
                border    = "rounded",
                title     = " Interleaved Source + ASM ",
                title_pos = "center",
            })
        else
            pcall(vim.api.nvim_win_set_config, asm_view_state.win, {
                relative  = "editor",
                width     = width,
                height    = height,
                row       = math.floor((vim.o.lines - height) / 2),
                col       = math.floor((vim.o.columns - width) / 2),
            })
        end

        if type(pc_line_nr) == "number" and asm_view_state.win ~= nil and vim.api.nvim_win_is_valid(asm_view_state.win) then
            pcall(vim.api.nvim_win_set_cursor, asm_view_state.win, { pc_line_nr, 0 })
        end
    end

    local function fetch_and_show_asm(open_if_closed)
        local session = dap.session()
        if not session or not session.current_frame then
            vim.notify("Pause at a breakpoint first", vim.log.levels.WARN)
            return
        end

        local frame = session.current_frame
        local pc_ref = frame.instructionPointerReference
        local adapter_type = ""
        if type(session.config) == "table" and type(session.config.type) == "string" then
            adapter_type = session.config.type
        end

        local function apply_and_render(pc_str, insns)
            asm_view_state.pc_ref = pc_str
            asm_view_state.instructions = insns
            if hex_mode and asm_view_state.byte_mode ~= "bin" then
                asm_view_state.byte_mode = "hex"
            elseif not hex_mode and asm_view_state.byte_mode ~= "bin" then
                asm_view_state.byte_mode = "dec"
            end
            vim.schedule(function()
                if open_if_closed or (asm_view_state.win ~= nil and vim.api.nvim_win_is_valid(asm_view_state.win)) then
                    render_asm_window()
                end
            end)
        end

        if type(pc_ref) == "string" and pc_ref ~= "" then
            session:request("disassemble", {
                memoryReference   = pc_ref,
                instructionOffset = -12,
                instructionCount  = 40,
                resolveSymbols    = true,
            }, function(err, resp)
                if not err and type(resp) == "table" and type(resp.instructions) == "table" and #resp.instructions > 0 then
                    apply_and_render(pc_ref, resp.instructions)
                    return
                end
                if adapter_type == "gdb" then
                    gdb_rpc_call(session, { action = "asm", expr = "$pc", before = 12, after = 28 }, function(res, rpc_err)
                        if rpc_err ~= nil then
                            vim.schedule(function()
                                vim.notify("Disassemble failed: " .. rpc_err, vim.log.levels.ERROR)
                            end)
                            return
                        end
                        for _, inst in ipairs(res.instructions) do
                            inst._raw_hex_bytes = inst.instructionBytes
                        end
                        apply_and_render(res.pc, res.instructions)
                    end)
                    return
                end
                vim.schedule(function()
                    vim.notify("DAP disassemble failed", vim.log.levels.ERROR)
                end)
            end)
            return
        end

        if adapter_type == "gdb" then
            gdb_rpc_call(session, { action = "asm", expr = "$pc", before = 12, after = 28 }, function(res, rpc_err)
                if rpc_err ~= nil then
                    vim.schedule(function()
                        vim.notify("Disassemble failed: " .. rpc_err, vim.log.levels.ERROR)
                    end)
                    return
                end
                for _, inst in ipairs(res.instructions) do
                    inst._raw_hex_bytes = inst.instructionBytes
                end
                apply_and_render(res.pc, res.instructions)
            end)
            return
        end

        vim.notify("Current adapter/frame has no instructionPointerReference", vim.log.levels.WARN)
    end

    refresh_asm_viewer = function(re_read, sync_global_hex)
        if asm_view_state.win == nil or not vim.api.nvim_win_is_valid(asm_view_state.win) then
            return
        end
        if sync_global_hex and asm_view_state.byte_mode ~= "bin" then
            if hex_mode then
                asm_view_state.byte_mode = "hex"
            else
                asm_view_state.byte_mode = "dec"
            end
        end
        if not re_read and #asm_view_state.instructions > 0 then
            render_asm_window()
            return
        end
        fetch_and_show_asm(false)
    end

    dap.listeners.after.event_stopped["asm_viewer_refresh"] = function()
        if asm_view_state.win ~= nil and vim.api.nvim_win_is_valid(asm_view_state.win) then
            refresh_asm_viewer(true, false)
        end
    end

    local function show_interleaved_source_asm()
        fetch_and_show_asm(true)
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
    vim.keymap.set("n", "<leader>dp", print_expr_address_prompt, { desc = "DAP: Print &var / field address + value" })
    vim.keymap.set("n", "<leader>dR", virtual_memory_menu, { desc = "DAP: Virtual memory region / search" })
    vim.keymap.set("n", "<leader>ds", show_interleaved_source_asm, { desc = "DAP: Interleaved Source + ASM (Dec/Hex/Bin)" })
    vim.keymap.set("n", "<leader>do", toggle_wine_output_window, { desc = "DAP: Toggle Wine debug output window" })

    if ok_dapui then
        vim.keymap.set({ "n", "v" }, "Q", function()
            dapui.eval()
        end, { desc = "DAP Peek" })
        vim.keymap.set({ "n", "v" }, "<leader>dw", function()
            dapui.eval(nil, { enter = true })
        end, { desc = "DAP Add word under cursor to Watches" })
    end
end)

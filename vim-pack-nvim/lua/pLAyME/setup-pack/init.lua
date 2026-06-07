local dir = vim.fs.dir(vim.fs.joinpath(vim.fn.stdpath("config"), 
                       "lua", "pLAyME", "setup-pack"))

local specs = {}
local configs = {}

for name, ftype in dir do
    if ftype == "file" and name:match("%.lua$") and name ~= "init.lua" then
        local ok, mod = pcall(require, "pLAyME.setup-pack." .. name:gsub("%.lua$", ""))
        if ok and type(mod) == "table" then
            for _, entry in ipairs(mod) do
                if type(entry) == "table" then
                    local src_entry = entry.src and entry or entry[1]
                    if src_entry and src_entry.src then
                        specs[#specs + 1] = { src = src_entry.src, version = src_entry.version or src_entry.branch }
                    end
                    if entry.dependencies then
                        for _, dep in ipairs(entry.dependencies) do
                            if type(dep) == "string" then
                                specs[#specs + 1] = dep
                            elseif type(dep) == "table" and dep.src then
                                specs[#specs + 1] = { src = dep.src, version = dep.version or dep.branch }
                            end
                        end
                    end
                    if entry.init or entry.config then
                        configs[#configs + 1] = entry
                    end
                end
            end
            if mod.src then
                specs[#specs + 1] = { src = mod.src, version = mod.version or mod.branch }
            end
            if mod.dependencies then
                for _, dep in ipairs(mod.dependencies) do
                    if type(dep) == "string" then
                        specs[#specs + 1] = dep
                    elseif type(dep) == "table" and dep.src then
                        specs[#specs + 1] = { src = dep.src, version = dep.version or dep.branch }
                    end
                end
            end
            if mod.init or mod.config then
                configs[#configs + 1] = mod
            end
        end
    end
end

if #specs > 0 then
    vim.pack.add(specs)
end

vim.schedule(function()
    for _, mod in ipairs(configs) do
        local ok = true
        if mod.init then
            ok = pcall(mod.init)
        end
        if ok and mod.config then
            pcall(mod.config)
        end
    end
end)

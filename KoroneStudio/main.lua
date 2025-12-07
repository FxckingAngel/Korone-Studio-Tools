-- 🌙 Korone Studio Tools - Universal Loader (PC + Mobile)
-- Credits: Moon (Dex inspiration) + Korone

print("[KoroneStudio] Booting...")

-- make sure we even have a filesystem
if not (typeof(readfile) == "function" and typeof(isfile) == "function") then
    warn("[KoroneStudio] This executor has no filesystem (readfile/isfile).")
    warn("[KoroneStudio] Use the single-file version instead.")
    return
end

-- try a bunch of common base paths so it works on most executors
local candidateBases = {
    "KoroneStudio/",                             -- folder in workspace root
    "",                                          -- same folder as main.lua
    "workspace/KoroneStudio/",                   -- some PC executors
    "workspace/",                                -- files all directly in workspace
    "/workspace/KoroneStudio/",                  -- some linux-style envs
    "/workspace/",

    -- common mobile / Delta paths (if user saved there)
    "/storage/emulated/0/Delta/Workspace/KoroneStudio/",
    "/storage/emulated/0/Delta/Workspace/",
}

local BASE = nil

for _, base in ipairs(candidateBases) do
    if isfile(base .. "KS_Util.lua") then
        BASE = base
        break
    end
end

if not BASE then
    warn("[KoroneStudio] Could not locate KS_Util.lua in any known path.")
    warn("[KoroneStudio] Make sure ALL files are together, e.g.:")
    warn("  workspace/KoroneStudio/main.lua")
    warn("  workspace/KoroneStudio/KS_Util.lua (and the others)")
    return
end

print("[KoroneStudio] Using base path:", BASE)

local function safeLoad(file)
    local path = BASE .. file

    if not isfile(path) then
        warn("[KoroneStudio] Missing file:", path)
        return
    end

    local src = readfile(path)
    local fn, err = loadstring(src, "=" .. file)

    if not fn then
        warn("[KoroneStudio] Compile error in " .. file .. ": " .. tostring(err))
        return
    end

    local ok, runErr = pcall(fn)
    if not ok then
        warn("[KoroneStudio] Runtime error in " .. file .. ": " .. tostring(runErr))
    end
end

-- load in the correct order so globals are ready
safeLoad("KS_Util.lua")      -- sets _G.KS_UTIL + _G.KS_Shared
safeLoad("Editor.lua")
safeLoad("Explorer.lua")
safeLoad("RSpy.lua")
safeLoad("SecretPanel.lua")
safeLoad("ModelViewer.lua")
safeLoad("Hub.lua")

print("[KoroneStudio] ✅ Loaded – look for the 🌙 hub on the left.")

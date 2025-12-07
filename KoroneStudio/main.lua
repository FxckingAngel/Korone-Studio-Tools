-- 🌙 Korone Studio Tools - SANDBOX SAFE UNIVERSAL LOADER
-- Credits: Moon (Dex inspiration) + Korone

print("[KoroneStudio] Booting...")

if not (typeof(readfile) == "function" and typeof(isfile) == "function") then
    warn("[KoroneStudio] Executor has no filesystem access.")
    warn("[KoroneStudio] Use the single-file version instead.")
    return
end

-- ✅ ONLY use local relative paths (no directory escaping)
local BASE = ""

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

-- 🔧 SPECIAL HANDLER JUST FOR DEX EXPLORER
local function initDexExplorer()
    local path = BASE .. "Explorer.lua"

    if not isfile(path) then
        warn("[KoroneStudio] Missing file:", path)
        return
    end

    local src = readfile(path)
    local fn, err = loadstring(src, "=Explorer.lua")

    if not fn then
        warn("[KoroneStudio] Compile error in Explorer.lua: " .. tostring(err))
        return
    end

    -- Run Dex module and capture what it returns (if anything)
    local ok, result = pcall(fn)
    if not ok then
        warn("[KoroneStudio] Runtime error in Explorer.lua: " .. tostring(result))
        return
    end

    -- Dex might return the explorer table OR put it on _G
    local ex = result or _G.KS_Explorer or _G.Explorer or _G.Dex

    if not ex then
        warn("[KoroneStudio] Explorer.lua did not expose an explorer table.")
        return
    end

    -- ✅ These are the typical Dex init functions
    if ex.InitDeps then
        pcall(ex.InitDeps)
    end

    if ex.InitAfterMain then
        pcall(ex.InitAfterMain)
    end

    if ex.Main then
        local okMain, errMain = pcall(ex.Main)
        if not okMain then
            warn("[KoroneStudio] Explorer main() failed: " .. tostring(errMain))
        end
    end

    _G.KS_Explorer = ex

    if ex.Toggle then
        print("[KoroneStudio] Dex Explorer initialised.")
    else
        warn("[KoroneStudio] Explorer has no Toggle() function – hub button may do nothing.")
    end
end

-- ✅ Correct load order
safeLoad("KS_Util.lua")
safeLoad("Editor.lua")

-- 🔥 DEX GOES HERE INSTEAD OF safeLoad("Explorer.lua")
initDexExplorer()

safeLoad("RSpy.lua")
safeLoad("SecretPanel.lua")
safeLoad("ModelViewer.lua")
safeLoad("Hub.lua")

print("[KoroneStudio] ✅ Loaded successfully – look for the 🌙 hub.")

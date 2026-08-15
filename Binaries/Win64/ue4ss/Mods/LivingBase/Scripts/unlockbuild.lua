--[[
 LivingBase / unlockbuild.lua  (Config.UNLOCK_HIDDEN_BUILDING)

 Surface the build-menu pieces that are HIDDEN from standard play, while leaving normal progression
 intact. Learned from two reference mods:
   - the "UnlockAllBuildings" DLL enumerates every UR5BuildingItem and unlocks ALL of them, and
   - the "UnlockAllBuildAndRecipes" PAK force-completes the whole DA_QP_RecipePaperUnlock_* research set.
 Both hand you the ENTIRE standard catalog for free — which breaks progression, the opposite of what
 RedFalcon wants.

 The right lever is on each UR5BuildingItem (a UPrimaryDataAsset):
   DrawData : FR5BuildingItemDrawData { bool bShowItem; bool bLockedByRecipe; }
 A STANDARD piece has bShowItem = true (it appears in the menu) and bLockedByRecipe = true until you
 research it — that's normal progression, so we DON'T touch it. A piece that is NOT part of standard
 play has bShowItem = false: it never appears no matter how far you progress. THOSE are the ones to
 surface. So: only for items with bShowItem == false, set bShowItem = true + bLockedByRecipe = false.

 Data assets are re-created from disk every launch, so this only lives for the session and CANNOT touch
 the save. All engine access is pcall'd. The log lists the hidden items it finds, so the first runs
 double as a diagnostic: we confirm the hidden set really is cut/dev content before trusting it.
]]

local Config = require("config")

local UnlockBuild = {}

local function log(m) print("[LivingBase:UnlockBuild] " .. tostring(m) .. "\n") end

local function shortName(o)
    local n = ""
    pcall(function() n = o:GetFullName() end)
    return (tostring(n):match("([%w_]+)$")) or tostring(n)
end

-- One pass. Returns totalFound so the caller's retry loop knows when the catalog has loaded.
function UnlockBuild.Run(listNames)
    local items = {}
    pcall(function() items = FindAllOf("R5BuildingItem") or {} end)
    local total, hidden, flipped = 0, 0, 0
    local sample = {}
    for _, it in ipairs(items) do
        if it and it:IsValid() then
            total = total + 1
            local shown = true
            pcall(function() shown = it.DrawData.bShowItem end)
            if shown == false then
                hidden = hidden + 1
                if #sample < 40 then sample[#sample + 1] = shortName(it) end
                local ok = pcall(function()
                    it.DrawData.bShowItem = true
                    it.DrawData.bLockedByRecipe = false
                end)
                if ok then flipped = flipped + 1 end
            end
        end
    end
    log(string.format("scan: %d build items | %d hidden (bShowItem=false) | %d unlocked  (standard items untouched)",
        total, hidden, flipped))
    if listNames and hidden > 0 then
        log("hidden items surfaced:")
        for _, nm in ipairs(sample) do log("   + " .. nm) end
        if hidden > #sample then log(string.format("   ... and %d more", hidden - #sample)) end
    end
    if total == 0 then log("0 items found — build catalog not loaded yet (open the build menu once); will retry.") end
    return total
end

return UnlockBuild

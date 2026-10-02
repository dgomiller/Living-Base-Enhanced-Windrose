--[[
 LivingBase / niagaraoff.lua (2026-09-30)

 Switch off the Niagara (particle) effects on an actor -- e.g. the "pick-up" sparkle on the Faith of the Prophet stele
 (component FX_PickUP_Chest_01, system FX_PickUP_Object_01). Deactivate + hide + auto-activate off, NOT destroy: the mod
 only has precedent for Deactivate() on Niagara (see Spawner.MakeLootDecor); destroying one is unproven.

   * Config.NIAGARA_OFF_CLASSES = { [classPath] = true }  -- applied on every spawn AND restore (hooked in Spawner.Spawn),
     re-asserted a few times because the owning actor can restart its own effect.
   * Console: lbniagara [list|off|on]  -- acts on the locked target (Numpad +) or else the last-probed actor.
]]

local Config = require("config")

local N = {}

local function log(m) print("[LivingBase] [niagara] " .. tostring(m) .. "\n") end

-- Every NiagaraComponent on `actor` (valid ones only), unwrapped the same way Spawner's stripComponentsOfClass does it.
local function niagaraComponents(actor)
    local out = {}
    pcall(function()
        local cls = StaticFindObject("/Script/Niagara.NiagaraComponent")
        if not (cls and cls:IsValid()) then return end
        local arr = actor:K2_GetComponentsByClass(cls)
        local n = 0
        pcall(function() n = arr:GetArrayNum() end)
        if n == 0 then pcall(function() n = #arr end) end
        for i = 1, n do
            local raw
            local ok, v = pcall(function() return arr[i] end)
            if ok then raw = v end
            if not raw then
                local ok2, v2 = pcall(function() return arr:Get(i) end)
                if ok2 then raw = v2 end
            end
            local c = raw
            if raw then
                local ok3, u = pcall(function() return raw:get() end)
                if ok3 and u then c = u end
            end
            if c then
                local okV, valid = pcall(function() return c:IsValid() end)
                if okV and valid then out[#out + 1] = c end
            end
        end
    end)
    return out
end

function N.Off(actor)
    local list = niagaraComponents(actor)
    for _, c in ipairs(list) do
        pcall(function() c:SetAutoActivate(false) end)
        pcall(function() c:Deactivate() end)
        pcall(function() c:SetVisibility(false, false) end)
        pcall(function() c:SetHiddenInGame(true, false) end)
    end
    return #list
end

function N.On(actor)
    local list = niagaraComponents(actor)
    for _, c in ipairs(list) do
        pcall(function() c:SetHiddenInGame(false, false) end)
        pcall(function() c:SetVisibility(true, false) end)
        pcall(function() c:SetAutoActivate(true) end)
        pcall(function() c:Activate(true) end)
    end
    return #list
end

-- Called from Spawner.Spawn for every spawn / restore: if the class is listed, switch its Niagara off and keep it off.
function N.ApplyForClass(actor, classPath)
    local map = Config and Config.NIAGARA_OFF_CLASSES
    if not (map and map[classPath]) then return false end
    local n = N.Off(actor)
    log(string.format("%s: switched off %d Niagara component(s)", tostring(classPath):match("([^/%.]+)$") or tostring(classPath), n))
    local tries = 0
    local function again()
        ExecuteInGameThread(function()
            pcall(function()
                if actor and actor:IsValid() then N.Off(actor) end
            end)
        end)
        tries = tries + 1
        if tries < 4 and ExecuteWithDelay then ExecuteWithDelay(750, again) end
    end
    if ExecuteWithDelay and ExecuteInGameThread then ExecuteWithDelay(750, again) end
    return true
end

local function describe(c)
    local name, asset, active = "?", "?", "?"
    pcall(function() name = c:GetFName():ToString() end)
    pcall(function() local a = c.Asset; if a and a:IsValid() then asset = a:GetFullName() end end)
    pcall(function() active = tostring(c:IsActive()) end)
    return string.format("%s  asset=%s  active=%s", name, asset, active)
end

function N.Install(Spawner)
    if not RegisterConsoleCommandHandler then return end
    do local reg = rawget(_G, "__LB_RegisterCmdInfo"); if reg then reg("lbniagara", "lbniagara [list|on|off]", "Lists, enables or disables the Niagara particle effects on the targeted actor.") end end
    RegisterConsoleCommandHandler("lbniagara", function(FullCommand, Parameters, Ar)
        local function out(m)
            log(m)
            if Ar then pcall(function() Ar:Log(m) end) end
        end
        local ok, err = pcall(function()
            local actor
            local lt = Spawner and Spawner.lockedTarget
            if lt and lt.actor and lt.actor:IsValid() then actor = lt.actor end
            if not actor then
                local lp = Spawner and Spawner._lastProbedActor
                if lp and lp:IsValid() then actor = lp end
            end
            if not actor then out("no target -- lock one (Numpad +) or lbprobe it first") return end
            local verb = (Parameters and Parameters[1]) and tostring(Parameters[1]):lower() or "list"
            local nm = "?"
            pcall(function() nm = actor:GetFullName() end)
            if verb == "off" then
                out(string.format("off: %d Niagara component(s) on %s", N.Off(actor), nm))
            elseif verb == "on" then
                out(string.format("on: %d Niagara component(s) on %s", N.On(actor), nm))
            else
                local list = niagaraComponents(actor)
                out(string.format("%d Niagara component(s) on %s", #list, nm))
                for _, c in ipairs(list) do out("   " .. describe(c)) end
            end
        end)
        if not ok then out("lbniagara failed: " .. tostring(err)) end
        return true
    end)
end

return N

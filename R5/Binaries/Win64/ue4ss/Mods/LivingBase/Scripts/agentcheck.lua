-- agentcheck.lua (2026-09-30) -- READ-ONLY diagnostic for the recurring idle crash (Windrose-Win64-Shipping.exe +0x175d2e0).
-- The game's check monitor reports R5AS_MemoryComponent.cpp:48 / R5AS_ValueSelectors.cpp:307 thousands of times in every
-- session that later crashes. Hypothesis: a mod-spawned AI actor (e.g. the non-native "Mobile" merchants) has an agent-system
-- brain but no (or an unowned) R5AS memory component. `lbagentcheck` lists, per live AI pawn, whether it has one.
local Check = {}

local function nameOf(o)
    local n = "?"
    pcall(function() n = o:GetFName():ToString() end)
    return n
end

local function classOf(o)
    local n = "?"
    pcall(function() n = o:GetClass():GetFName():ToString() end)
    return n
end

function Check.Run(out, Spawner)
    local function list(cls)
        local l
        pcall(function() l = FindAllOf(cls) end)
        return l or {}
    end
    -- owner actor full name -> memory component count
    local owners, orphan, total = {}, 0, 0
    for _, c in ipairs(list("R5AS_MemoryComponent")) do
        local okV, v = pcall(function() return c:IsValid() end)
        if okV and v then
            total = total + 1
            local owner
            pcall(function() owner = c:GetOwner() end)
            local okO, vo = pcall(function() return owner and owner:IsValid() end)
            if okO and vo then
                local k = owner:GetFullName()
                owners[k] = (owners[k] or 0) + 1
            else
                orphan = orphan + 1
            end
        end
    end
    out(string.format("R5AS_MemoryComponent: %d live, %d with no valid owner", total, orphan))

    -- every live pawn that has an AIController
    local rows, missing = {}, 0
    for _, p in ipairs(list("Pawn")) do
        local okV, v = pcall(function() return p:IsValid() end)
        if okV and v then
            local ctrl
            pcall(function() ctrl = p:GetController() end)
            local hasCtrl = false
            pcall(function() hasCtrl = ctrl and ctrl:IsValid() and not tostring(classOf(ctrl)):find("PlayerController") end)
            if hasCtrl then
                local full = p:GetFullName()
                local mem = owners[full] or 0
                -- also count a memory component living on the controller
                local cfull
                pcall(function() cfull = ctrl:GetFullName() end)
                local cmem = cfull and owners[cfull] or 0
                local mine = false
                for _, e in ipairs((Spawner and Spawner.spawned) or {}) do
                    local same = false
                    pcall(function() same = e.actor and e.actor:IsValid() and e.actor:GetFullName() == full end)
                    if same then mine = true ; break end
                end
                if mem + cmem == 0 then missing = missing + 1 end
                rows[#rows + 1] = string.format("%s %-44s ctrl=%-38s memcomp pawn=%d ctrl=%d", mine and "[LB]" or "[  ]", classOf(p), classOf(ctrl), mem, cmem)
            end
        end
    end
    table.sort(rows)
    for _, r in ipairs(rows) do out(r) end
    out(string.format("AI pawns: %d, without any R5AS memory component: %d   ([LB] = spawned by the mod)", #rows, missing))
end

function Check.Install(Spawner)
    if not RegisterConsoleCommandHandler then return end
    do local reg = rawget(_G, "__LB_RegisterCmdInfo"); if reg then reg("lbagentcheck", "lbagentcheck", "Lists AI pawns and flags any without an R5AS memory component (diagnostic).") end end
    RegisterConsoleCommandHandler("lbagentcheck", function(FullCommand, Parameters, Ar)
        local function out(m)
            print("[LivingBase] [agentcheck] " .. m .. "\n")
            if Spawner and Spawner.dbg then pcall(Spawner.dbg, "[agentcheck] " .. m) end
            if Ar then pcall(function() Ar:Log(m) end) end
        end
        local ok, err = pcall(Check.Run, out, Spawner)
        if not ok then out("failed: " .. tostring(err)) end
        return true
    end)
end

return Check

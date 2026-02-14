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
function EnableFreecam()
    -- Init state une seule fois
    if not _G.vortexFreecam then
        _G.vortexFreecam = {
            isToggled = false,
            cam = nil,              -- handle camera scriptee
            pos = vector3(0, 0, 0),
            pitch = 0.0,            -- rotation haut/bas (degres)
            heading = 0.0,          -- rotation gauche/droite (degres)
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
            tpBusy = false
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

        -- Recuperer l'orientation actuelle du gameplay camera
        local gameRot = GetGameplayCamRot(2)
        fc.pitch = gameRot.x
        fc.heading = gameRot.z
        fc.pos = vector3(coords.x, coords.y, coords.z + 1.0)
        fc.currentSpeed = 0.0
        fc.lastMoveDir = vector3(0, 0, 0)
        fc.currentFeature = fc.savedFeature or 1
        fc.tpBusy = false

        -- Creer la camera scriptee (completement detachee du ped)
        if fc.cam and DoesCamExist(fc.cam) then
            DestroyCam(fc.cam, false)
        end
        fc.cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        SetCamCoord(fc.cam, fc.pos.x, fc.pos.y, fc.pos.z)
        SetCamRot(fc.cam, fc.pitch, 0.0, fc.heading, 2)
        SetCamFov(fc.cam, GetGameplayCamFov())
        SetCamActive(fc.cam, true)
        RenderScriptCams(true, false, 0, true, true)

        -- Verrouiller le ped (invisible, freeze, no collision)
        FreezeEntityPosition(ped, true)
        SetEntityVisible(ped, false, false)
        SetEntityInvincible(ped, true)
        SetEntityCollision(ped, false, false)
        SetEntityAlpha(ped, 0, false)

        -- Threads (une seule fois)
        if not fc.threadsStarted then
            fc.threadsStarted = true

            -- Thread UI
            Citizen.CreateThread(function()
                while _G.vortexFreecam and not _G.vortexFreecam.shutdown do
                    if _G.vortexFreecam.isToggled then
                        vortex_fcDrawUI()
                    end
                    Citizen.Wait(0)
                end
            end)

            -- Thread principal (mouvement + features)
            Citizen.CreateThread(function()
                while _G.vortexFreecam and not _G.vortexFreecam.shutdown do
                    if _G.vortexFreecam.isToggled then
                        vortex_fcTick()
                    end
                    Citizen.Wait(0)
                end
            end)
        end

        print("^2[FREECAM] ON^0")

    else
        -----------------------------------------------
        -- DESACTIVATION
        -----------------------------------------------
        fc.savedFeature = fc.currentFeature
        fc.currentSpeed = 0.0

        -- Detruire la camera scriptee, retour camera gameplay
        if fc.cam and DoesCamExist(fc.cam) then
            RenderScriptCams(false, false, 0, true, true)
            SetCamActive(fc.cam, false)
            DestroyCam(fc.cam, false)
            fc.cam = nil
        end

        -- Restaurer le ped
        local ped = PlayerPedId()
        ResetEntityAlpha(ped)
        SetEntityVisible(ped, true, false)
        SetEntityCollision(ped, true, true)
        SetEntityInvincible(ped, false)
        FreezeEntityPosition(ped, false)

        -- TP le ped a la position de la camera
        SetEntityCoords(ped, fc.pos.x, fc.pos.y, fc.pos.z - 1.0, false, false, false, false)
        SetFocusEntity(ped)
        ClearFocus()

        -- Cleanup RC car
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

-- Touche maintenue (Susano)
function vortex_fcKeyDown(vk)
    if type(Susano) == "table" and type(Susano.GetAsyncKeyState) == "function" then
        local down = Susano.GetAsyncKeyState(vk)
        return down
    end
    return false
end

-- Touche juste pressee (front montant)
function vortex_fcKeyJustPressed(vk)
    local fc = _G.vortexFreecam
    if not fc then return false end
    local down = vortex_fcKeyDown(vk)
    local was = fc.prevKeys[vk] or false
    fc.prevKeys[vk] = down
    return down and not was
end

-- Siege vide dans vehicule
function vortex_fcGetEmptySeat(vehicle)
    for _, seat in ipairs({ -1, 0, 1, 2 }) do
        if IsVehicleSeatFree(vehicle, seat) then return seat end
    end
    return -1
end

------------------------------------------------------------
-- UI : crosshair + liste features
------------------------------------------------------------
function vortex_fcDrawUI()
    local fc = _G.vortexFreecam
    if not fc then return end

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
    if not fc.cam or not DoesCamExist(fc.cam) then return end

    local dt = GetFrameTime()
    if dt <= 0 or dt > 0.1 then dt = 0.016 end

    -----------------------------------------------
    -- DESACTIVER TOUS LES CONTROLES, puis reactiver
    -- ce dont on a besoin (souris, scroll, HUD)
    -----------------------------------------------
    DisableAllControlActions(0)

    -- Souris look (on lit les valeurs AVANT de les desactiver)
    -- Controls 1/2 = mouse X/Y (on les laisse disabled mais on lit avec GetDisabledControlNormal)
    -- Scroll wheel pour features
    EnableControlAction(0, 241, true)  -- Scroll up
    EnableControlAction(0, 242, true)  -- Scroll down
    -- HUD
    EnableControlAction(0, 245, true)  -- Chat
    EnableControlAction(0, 200, true)  -- Pause menu
    EnableControlAction(0, 322, true)  -- Escape

    -----------------------------------------------
    -- ROTATION CAMERA (souris)
    -- GetDisabledControlNormal lit l'input meme si le controle est disabled
    -- Control 1 = Mouse X (gauche/droite), Control 2 = Mouse Y (haut/bas)
    -----------------------------------------------
    local mouseX = GetDisabledControlNormal(0, 1)  -- -1.0 a 1.0 (gauche/droite)
    local mouseY = GetDisabledControlNormal(0, 2)  -- -1.0 a 1.0 (haut/bas)
    local sens = fc.mouseSensitivity

    fc.heading = fc.heading - mouseX * sens
    fc.pitch = fc.pitch - mouseY * sens

    -- Clamp pitch entre -89 et 89 degres
    if fc.pitch > 89.0 then fc.pitch = 89.0 end
    if fc.pitch < -89.0 then fc.pitch = -89.0 end

    -- Normaliser heading entre -180 et 180
    if fc.heading > 180.0 then fc.heading = fc.heading - 360.0 end
    if fc.heading < -180.0 then fc.heading = fc.heading + 360.0 end

    -----------------------------------------------
    -- VECTEURS DE DIRECTION
    -- Calcules a partir de NOS angles (pas les angles gameplay)
    -----------------------------------------------
    local pitchRad = math.rad(fc.pitch)
    local headRad = math.rad(fc.heading)

    local cp = math.cos(pitchRad)
    local sp = math.sin(pitchRad)
    local ch = math.cos(headRad)
    local sh = math.sin(headRad)

    -- Forward : direction ou la camera regarde (suit pitch + heading)
    local fwdX = -sh * cp
    local fwdY =  ch * cp
    local fwdZ =  sp

    -- Right : perpendiculaire sur le plan horizontal
    local rightX =  ch
    local rightY =  sh

    -----------------------------------------------
    -- INPUT MOUVEMENT : AZERTY (ZQSD)
    -----------------------------------------------
    local ix, iy, iz = 0.0, 0.0, 0.0

    if vortex_fcKeyDown(0x5A) then  -- Z = avancer
        ix = ix + fwdX; iy = iy + fwdY; iz = iz + fwdZ
    end
    if vortex_fcKeyDown(0x53) then  -- S = reculer
        ix = ix - fwdX; iy = iy - fwdY; iz = iz - fwdZ
    end
    if vortex_fcKeyDown(0x44) then  -- D = droite
        ix = ix + rightX; iy = iy + rightY
    end
    if vortex_fcKeyDown(0x51) then  -- Q = gauche
        ix = ix - rightX; iy = iy - rightY
    end
    if vortex_fcKeyDown(0x20) then  -- Espace = monter
        iz = iz + 1.0
    end
    if vortex_fcKeyDown(0x11) then  -- Ctrl = descendre
        iz = iz - 1.0
    end

    -----------------------------------------------
    -- ACCELERATION FLUIDE
    -----------------------------------------------
    local inputLen = math.sqrt(ix * ix + iy * iy + iz * iz)
    local hasInput = inputLen > 0.001

    local maxSpeed = fc.cameraSpeed * 30.0
    if vortex_fcKeyDown(0x10) then maxSpeed = maxSpeed * 3.0 end  -- Shift = x3

    if hasInput then
        fc.lastMoveDir = vector3(ix / inputLen, iy / inputLen, iz / inputLen)
        local accelRate = maxSpeed * 4.0
        fc.currentSpeed = math.min(fc.currentSpeed + accelRate * dt, maxSpeed)
    else
        fc.currentSpeed = fc.currentSpeed * math.max(0, 1.0 - 8.0 * dt)
        if fc.currentSpeed < 0.05 then fc.currentSpeed = 0.0 end
    end

    -- Appliquer mouvement
    if fc.currentSpeed > 0.01 then
        local delta = fc.currentSpeed * dt
        local d = fc.lastMoveDir
        fc.pos = vector3(fc.pos.x + d.x * delta, fc.pos.y + d.y * delta, fc.pos.z + d.z * delta)
    end

    -----------------------------------------------
    -- APPLIQUER POSITION + ROTATION A LA CAMERA SCRIPTEE
    -----------------------------------------------
    SetCamCoord(fc.cam, fc.pos.x, fc.pos.y, fc.pos.z)
    SetCamRot(fc.cam, fc.pitch, 0.0, fc.heading, 2)

    -- Streamer le monde autour de la camera
    SetFocusPosAndVel(fc.pos.x, fc.pos.y, fc.pos.z, 0.0, 0.0, 0.0)

    -- Verrouiller le ped chaque frame
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityInvincible(ped, true)

    -----------------------------------------------
    -- SCROLL FEATURES (molette + fleches haut/bas)
    -----------------------------------------------
    local scrollUp = IsControlJustPressed(0, 241) or IsControlJustPressed(0, 172) or vortex_fcKeyJustPressed(0x26)
    local scrollDown = IsControlJustPressed(0, 242) or IsControlJustPressed(0, 173) or vortex_fcKeyJustPressed(0x28)

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

    -- Selection modele (fleches gauche/droite)
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

    -- Mode RC Car
    if _G.rcCarControlActive and _G.rcCarControl and DoesEntityExist(_G.rcCarControl) then
        vortex_fcHandleRCCar()
        return
    end

    -----------------------------------------------
    -- RAYCAST depuis la camera (direction = forward)
    -----------------------------------------------
    local rEx = fc.pos.x + fwdX * 500.0
    local rEy = fc.pos.y + fwdY * 500.0
    local rEz = fc.pos.z + fwdZ * 500.0
    local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(
        fc.pos.x, fc.pos.y, fc.pos.z,
        rEx, rEy, rEz, -1
    )
    local _, hit, endCoords, _, entityHit = GetShapeTestResult(rayHandle)

    local lmbPressed = vortex_fcKeyJustPressed(0x01)
    local lmbDown = vortex_fcKeyDown(0x01)

    -----------------------------------------------
    -- EXECUTION DES FEATURES
    -----------------------------------------------
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

                if _G.vortexFreecam then
                    _G.vortexFreecam.tpBusy = false
                end
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
            ShootSingleBulletBetweenCoords(
                fc.pos.x, fc.pos.y, fc.pos.z,
                rEx, rEy, rEz,
                dmg, true, wh, sped, true, false, 1000.0
            )
        end

    elseif feat == "Shoot Car" then
        if lmbPressed then
            vortex_fcShootCar(vector3(fwdX, fwdY, fwdZ))
        end

    elseif feat == "Spawn Bomb" then
        if lmbPressed and hit then
            vortex_fcSpawnBomb(endCoords)
        end

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
                -- Detacher la freecam camera, attacher au vehicule
                local fc2 = _G.vortexFreecam
                if fc2.cam and DoesCamExist(fc2.cam) then
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
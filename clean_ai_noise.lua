-------------------------------------------------------------------
-- AI NOISE CLEANER PRO (Simple & Stable)
-- Sin filtros complejos, solo limpieza de ruido pura.
-------------------------------------------------------------------

local sprite = app.activeSprite
if not sprite then return app.alert("No hay sprite activo.") end

-------------------------------------------------------------------
-- 1. CONFIGURACIÓN DE PRESETS
-------------------------------------------------------------------
local PRESETS = {
    -- Nombre = { Intensidad, Umbral }
    ["Suave (Detalles finos)"] = { 4, 25 },
    ["Medio (Recomendado)"] = { 8, 45 },
    ["Fuerte (Agresivo)"] = { 15, 65 },
    ["Personalizado"] = { 8, 45 } 
}

local function getInitialPresetName()
    return "Medio (Recomendado)"
end

local function getTableKeys(t)
    local keys = {}
    for k in pairs(t) do table.insert(keys, k) end
    table.sort(keys)
    return keys
end

-------------------------------------------------------------------
-- 2. INTERFAZ DE USUARIO (UI)
-------------------------------------------------------------------
local dlg = Dialog("AI Noise Cleaner")

dlg:label{ text="Elimina pixeles sueltos y suaviza ruido." }

dlg:combobox{
    id="preset",
    label="Preset:",
    options=getTableKeys(PRESETS),
    option=getInitialPresetName(),
    onchange=function()
        local selected = dlg.data.preset
        if selected ~= "Personalizado" then
            local vals = PRESETS[selected]
            dlg:modify{ id="strength", value=vals[1] }
            dlg:modify{ id="distance", value=vals[2] }
        end
    end
}

dlg:slider{ id="strength", label="Intensidad (1-20):", min=1, max=20, value=8 }
dlg:slider{ id="distance", label="Umbral Color (1-200):", min=1, max=200, value=45 }

dlg:newrow()

dlg:combobox{
    id="mode",
    label="Método:",
    options={ "color mayoritario", "color más cercano", "borrar" },
    option="color mayoritario"
}

dlg:check{ id="ignore_transparent", label="Ignorar fondo transparente", selected=true }

dlg:button{ id="ok", text="LIMPIAR" }
dlg:button{ id="cancel", text="Cancelar" }

dlg:show()
local data = dlg.data
if not data.ok then return end

-- Variables finales
local strength = data.strength
local distanceThreshold = data.distance
local mode = data.mode
local ignoreTransparent = data.ignore_transparent

-------------------------------------------------------------------
-- 3. UTILIDADES
-------------------------------------------------------------------
local function colorDistance(c1, c2)
    -- Calcula la diferencia visual entre dos colores
    if c1 == c2 then return 0 end
    local r1,g1,b1,a1 = app.pixelColor.rgba(c1)
    local r2,g2,b2,a2 = app.pixelColor.rgba(c2)
    
    -- Protección simple contra nulos (si rgba falla, usa 0)
    r1, g1, b1 = r1 or 0, g1 or 0, b1 or 0
    r2, g2, b2 = r2 or 0, g2 or 0, b2 or 0

    local dr = r1 - r2
    local dg = g1 - g2
    local db = b1 - b2
    return dr*dr + dg*dg + db*db
end

-------------------------------------------------------------------
-- 4. PROCESO DE LIMPIEZA
-------------------------------------------------------------------
app.transaction(function()
    for _, cel in ipairs(sprite.cels) do
        local original = cel.image
        if original then 
            
            local img = original:clone()     -- Imagen para LEER
            local out = original:clone()     -- Imagen para ESCRIBIR (resultado)
            local w, h = img.width, img.height

            for y=0, h-1 do
                for x=0, w-1 do
                    local c = img:getPixel(x, y)
                    
                    -- Si ignoramos transparentes y el pixel actual es transparente, saltar
                    if ignoreTransparent and app.pixelColor.rgbaA(c) == 0 then
                        goto continuePixel
                    end

                    ------------------------------------------------
                    -- Analizar los 8 vecinos
                    ------------------------------------------------
                    local neighbors = {}
                    local counts = {}
                    local maxColor = nil
                    local maxCount = 0
                    local sameColorMatches = 0

                    for dy=-1, 1 do
                        for dx=-1, 1 do
                            if not (dx == 0 and dy == 0) then
                                local nx, ny = x + dx, y + dy
                                
                                -- Verificar límites de la imagen
                                if nx >= 0 and nx < w and ny >= 0 and ny < h then
                                    local nc = img:getPixel(nx, ny)
                                    
                                    -- Contamos cuántos vecinos son idénticos al pixel central
                                    if nc == c then
                                        sameColorMatches = sameColorMatches + 1
                                    end

                                    -- Buscamos cuál es el color dominante alrededor
                                    counts[nc] = (counts[nc] or 0) + 1
                                    if counts[nc] > maxCount then
                                        maxCount = counts[nc]
                                        maxColor = nc
                                    end
                                end
                            end
                        end
                    end

                    -- Si no hay vecinos (imagen de 1x1 pixel), saltar
                    if not maxColor then goto continuePixel end

                    ------------------------------------------------
                    -- Decidir si es "Ruido"
                    ------------------------------------------------
                    -- 1. ¿Tiene muy pocos vecinos iguales? (Intensidad)
                    local isOutlierByCount = sameColorMatches < (strength / 2.5)

                    -- 2. ¿Es el color muy diferente al dominante? (Umbral)
                    local dist = colorDistance(c, maxColor)
                    local isOutlierByColor = dist > (distanceThreshold * distanceThreshold)

                    if isOutlierByCount and isOutlierByColor then
                        -- REEMPLAZO
                        if mode == "color mayoritario" then
                            out:putPixel(x, y, maxColor)
                        elseif mode == "borrar" then
                            out:putPixel(x, y, app.pixelColor.rgba(0,0,0,0))
                        elseif mode == "color más cercano" then
                            -- Buscar entre los vecinos cuál se parece más al pixel actual
                            local best = maxColor
                            local bestDist = dist
                            for col, _ in pairs(counts) do
                                local d = colorDistance(c, col)
                                if d < bestDist then
                                    bestDist = d
                                    best = col
                                end
                            end
                            out:putPixel(x, y, best)
                        end
                    end

                    ::continuePixel::
                end
            end
            
            -- Guardar cambios en el cel
            cel.image = out
        end
    end
end)

app.refresh()
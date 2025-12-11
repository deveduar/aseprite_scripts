-------------------------------------------------------------------
-- AI NOISE CLEANER PRO (FINAL - Presets, Lógica Correcta y Preview)
-------------------------------------------------------------------

local sprite = app.activeSprite
if not sprite then return app.alert("No hay sprite activo.") end

-------------------------------------------------------------------
-- 1. CONFIGURACIÓN DE PRESETS
-------------------------------------------------------------------
local PRESETS = {
    -- Nombre = { Intensidad (Fuerza), Umbral (Tolerancia Color) }
    ["Suave (Menos limpieza)"] = { 4, 50 },
    ["Medio (Recomendado)"] = { 8, 100 },
    ["Fuerte (Máxima limpieza)"] = { 16, 180 },
    ["Personalizado"] = { 8, 100 } 
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
local dlg = Dialog("AI Noise Cleaner PRO")

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
dlg:slider{ id="distance", label="Umbral Color (1-200):", min=1, max=200, value=100 }

dlg:newrow()

dlg:combobox{
    id="mode",
    label="Método:",
    options={ "color mayoritario", "color más cercano", "borrar" },
    option="color mayoritario"
}

dlg:check{ id="ignore_transparent", label="Ignorar fondo transparente", selected=true }

-- Opción para Preview
dlg:check{ id="show_affected", label="Mostrar píxeles afectados (Magenta)", selected=false }

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
local showAffected = data.show_affected

-------------------------------------------------------------------
-- 3. UTILIDADES
-------------------------------------------------------------------

-- FIX: Usamos app.pixelColor.rgba para mayor compatibilidad
local MAGENTA_COLOR = app.pixelColor.rgba(255, 0, 255, 255)

local function colorDistance(c1, c2)
    -- Calcula la diferencia cuadrática.
    local function safeRGBA(c)
        if not c then return 0,0,0,0 end
        local r,g,b,a = app.pixelColor.rgba(c)
        -- Asegura que los componentes sean números (o 0 si son nil)
        return r or 0, g or 0, b or 0, a or 0
    end
    
    local r1,g1,b1 = safeRGBA(c1)
    local r2,g2,b2 = safeRGBA(c2)

    local dr = r1 - r2
    local dg = g1 - g2
    local db = b1 - b2
    return dr*dr + dg*dg + db*db
end

-------------------------------------------------------------------
-- 4. PROCESO DE LIMPIEZA
-------------------------------------------------------------------
app.transaction(function()
    
    -- LÓGICA INVERSA (Más valor = Más efecto)
    
    -- Mapeo de Intensidad (Strength): Define cuántos vecinos idénticos se requieren para que un píxel sea "seguro".
    -- Strength=1: Requiere 7 vecinos idénticos (limpieza Suave)
    -- Strength=20: Requiere 1 vecino idéntico (limpieza Fuerte)
    local min_neighbors_required = math.ceil(8 - (strength * 7 / 20)) 
    min_neighbors_required = math.max(1, math.min(8, min_neighbors_required))

    -- Mapeo de Umbral Color (Distance Threshold): Distancia de color máxima que el pixel "ruido" puede tener respecto al dominante.
    -- Threshold=1: Distancia máxima = 1 (limpieza Suave)
    -- Threshold=200: Distancia máxima = 200 (limpieza Fuerte)
    -- Usamos el valor directamente (al cuadrado) para que más alto signifique más tolerancia a la diferencia de color.
    local max_allowed_dist_squared = distanceThreshold * distanceThreshold

    for _, cel in ipairs(sprite.cels) do
        local original = cel.image
        if original then 
            
            local img = original:clone()
            local out = original:clone()
            local w, h = img.width, img.height

            for y=0, h-1 do
                for x=0, w-1 do
                    local c = img:getPixel(x, y)
                    
                    if ignoreTransparent and app.pixelColor.rgbaA(c) == 0 then
                        goto continuePixel
                    end

                    ------------------------------------------------
                    -- Analizar los 8 vecinos
                    ------------------------------------------------
                    local counts = {}
                    local maxColor = nil
                    local maxCount = 0
                    local sameColorMatches = 0
                    local totalNeighbors = 0

                    for dy=-1, 1 do
                        for dx=-1, 1 do
                            if not (dx == 0 and dy == 0) then
                                local nx, ny = x + dx, y + dy
                                
                                if nx >= 0 and nx < w and ny >= 0 and ny < h then
                                    totalNeighbors = totalNeighbors + 1
                                    local nc = img:getPixel(nx, ny)
                                    
                                    if nc == c then sameColorMatches = sameColorMatches + 1 end

                                    counts[nc] = (counts[nc] or 0) + 1
                                    if counts[nc] > maxCount then
                                        maxCount = counts[nc]
                                        maxColor = nc
                                    end
                                end
                            end
                        end
                    end

                    if not maxColor then goto continuePixel end

                    ------------------------------------------------
                    -- Decidir si es "Ruido" (Outlier)
                    ------------------------------------------------
                    
                    -- 1. ¿El pixel está muy aislado? (Basado en Strength)
                    -- isOutlierByNeighbors es TRUE si hay MENOS vecinos idénticos de lo requerido.
                    local isIsolated = (totalNeighbors - sameColorMatches) >= min_neighbors_required
                    
                    -- 2. ¿El color es muy diferente al dominante? (Basado en Umbral)
                    -- isOutlierByColor es TRUE si la distancia es MAYOR a la tolerancia.
                    local dist = colorDistance(c, maxColor)
                    local isDissimilar = dist > max_allowed_dist_squared

                    -- El pixel se corrige si está aislado O si tiene un color muy diferente al dominante.
                    if isIsolated or isDissimilar then
                        
                        local finalColor = nil

                        if showAffected then
                            finalColor = MAGENTA_COLOR
                        else
                            -- MODO LIMPIEZA
                            if mode == "color mayoritario" then
                                finalColor = maxColor
                            elseif mode == "borrar" then
                                finalColor = app.pixelColor.rgba(0,0,0,0)
                            elseif mode == "color más cercano" then
                                local best = maxColor
                                local bestDist = dist
                                for col, _ in pairs(counts) do
                                    local d = colorDistance(c, col)
                                    if d < bestDist then
                                        bestDist = d
                                        best = col
                                    end
                                end
                                finalColor = best
                            end
                        end
                        
                        out:putPixel(x, y, finalColor)
                    end

                    ::continuePixel::
                end
            end
            
            cel.image = out
        end
    end
end)

app.refresh()
-- Reductor de Colores PRO (Optimizado + Feedback de Progreso con Label)
local sprite = app.activeSprite
if not sprite then return app.alert("No hay ningún sprite abierto.") end

-- --- PARÁMETROS ---
-- Búsqueda limitada: Solo compara un color con sus 50 vecinos más cercanos en brillo.
local SEARCH_WINDOW = 50 

-- --- UTILIDADES RÁPIDAS ---
local function getLum(r,g,b)
    return 0.299*r + 0.587*g + 0.114*b
end

local function dist3d_fast(c1, c2)
    -- Usamos distancia al cuadrado para evitar math.sqrt y ganar velocidad.
    return (c2.r - c1.r)^2 + (c2.g - c1.g)^2 + (c2.b - c1.b)^2 
end

local function mixColors_fast(c1, c2)
    local nr = math.floor((c1.r + c2.r) / 2)
    local ng = math.floor((c1.g + c2.g) / 2)
    local nb = math.floor((c1.b + c2.b) / 2)
    return {
        r = nr, g = ng, b = nb, 
        lum = getLum(nr, ng, nb)
    }
end

-- --- DIÁLOGO DE CONFIGURACIÓN ---
local dlg = Dialog("Reductor PRO")
dlg:number{ id="targetCount", label="Objetivo Colores:", text="16", decimals=0 }
dlg:button{ id="ok", text="INICIAR" }
dlg:show()

local data = dlg.data
if not data.ok then return end
local targetCount = data.targetCount

-- --- FEEDBACK DE PROGRESO (Ventana Flotante con Label) ---
local progDlg = Dialog("Procesando...")
progDlg:label{ id="lbl_status", text="Inicializando...", align="center" }
progDlg:label{ id="lbl_perc", text="0%", align="center" }
progDlg:show{ wait=false } -- Mostrar ventana y continuar ejecución

local function updateProgress(pct, text)
    -- Limitamos la frecuencia de actualización para no ralentizar el bucle demasiado.
    if pct % 5 == 0 then
        if text then progDlg:modify{ id="lbl_status", text=text } end
        progDlg:modify{ id="lbl_perc", text=pct .. "%" }
    end
end

-- --- PROCESO PRINCIPAL ---
app.transaction(function()
    
    -- 0. CONFIGURACIÓN
    if sprite.colorMode ~= ColorMode.RGB then
        app.command.ChangePixelFormat{ format="rgb" }
    end

    -- 1. RECOLECCIÓN DE COLORES
    updateProgress(0, "Leyendo píxeles...")
    local uniqueMap = {}
    local paletteList = {}
    
    -- Estimación del trabajo para actualizar el progreso inicial
    local totalPixels = 0
    for _, layer in ipairs(sprite.layers) do 
        if layer.isImage and layer.isVisible then
            for _, cel in ipairs(layer.cels) do
                totalPixels = totalPixels + cel.image.width * cel.image.height
            end
        end
    end
    local processedPixels = 0

    for _, layer in ipairs(sprite.layers) do
        if layer.isImage and layer.isVisible then
            for _, cel in ipairs(layer.cels) do
                local img = cel.image
                for it in img:pixels() do
                    local val = it()
                    processedPixels = processedPixels + 1
                    
                    if app.pixelColor.rgbaA(val) > 0 then
                        if not uniqueMap[val] then
                            local r = app.pixelColor.rgbaR(val)
                            local g = app.pixelColor.rgbaG(val)
                            local b = app.pixelColor.rgbaB(val)
                            local obj = { r=r, g=g, b=b, lum=getLum(r,g,b), original=val }
                            uniqueMap[val] = obj
                            table.insert(paletteList, obj)
                        end
                    end
                end
                -- Progreso de Lectura (0% al 10% del total)
                local perc = math.floor((processedPixels / totalPixels) * 10)
                updateProgress(perc, "Leyendo píxeles...")
            end
        end
    end

    local startCount = #paletteList
    if startCount <= targetCount then
        progDlg:close()
        return app.alert("No es necesario reducir. Colores actuales: " .. startCount)
    end

    -- 2. REDUCCIÓN OPTIMIZADA (SORT & SCAN)
    local totalSteps = startCount - targetCount
    
    while #paletteList > targetCount do
        -- A. Ordenamos por luminosidad.
        table.sort(paletteList, function(a,b) return a.lum < b.lum end)
        
        local minD = 999999999
        local idx1, idx2 = -1, -1
        local pCount = #paletteList
        
        -- B. Búsqueda limitada a la ventana de vecinos
        local searchLimit = math.min(pCount, SEARCH_WINDOW)
        
        for i = 1, pCount - 1 do
            local limit = math.min(pCount, i + searchLimit)
            
            for j = i + 1, limit do
                local d = dist3d_fast(paletteList[i], paletteList[j])
                if d < minD then
                    minD = d
                    idx1 = i
                    idx2 = j
                    if d < 4 then goto found_match end
                end
            end
        end
        
        ::found_match::
        
        if idx1 ~= -1 then
            -- Fusionar y reemplazar
            local newCol = mixColors_fast(paletteList[idx1], paletteList[idx2])
            
            -- Eliminar los colores viejos (mayor índice primero para estabilidad)
            table.remove(paletteList, math.max(idx1, idx2))
            table.remove(paletteList, math.min(idx1, idx2))
            table.insert(paletteList, newCol)
        else
            break
        end
        
        -- Actualizar progreso de Reducción (10% al 90% del total)
        local stepsDone = startCount - #paletteList
        local perc = 10 + math.floor((stepsDone / totalSteps) * 80)
        updateProgress(perc, "Reduciendo: " .. #paletteList .. " restantes...")
    end

    -- 3. REMAPEO FINAL
    updateProgress(90, "Aplicando nueva paleta...")
    
    local finalInts = {}
    for _, c in ipairs(paletteList) do
        c.finalVal = app.pixelColor.rgba(c.r, c.g, c.b, 255)
        table.insert(finalInts, c)
    end
    
    local cache = {}
    
    for _, layer in ipairs(sprite.layers) do
        if layer.isImage and layer.isVisible then
            for _, cel in ipairs(layer.cels) do
                local img = cel.image
                for it in img:pixels() do
                    local val = it()
                    if app.pixelColor.rgbaA(val) > 0 then
                        local bestC
                        if cache[val] then
                            bestC = cache[val]
                        else
                            -- Encontrar más cercano
                            local r, g, b = app.pixelColor.rgbaR(val), app.pixelColor.rgbaG(val), app.pixelColor.rgbaB(val)
                            local bestD = 999999999
                            bestC = val
                            
                            for _, palCol in ipairs(finalInts) do
                                local d = (palCol.r - r)^2 + (palCol.g - g)^2 + (palCol.b - b)^2
                                if d < bestD then
                                    bestD = d
                                    bestC = palCol.finalVal
                                end
                            end
                            cache[val] = bestC
                        end
                        
                        if val ~= bestC then it(bestC) end
                    end
                end
            end
        end
    end
    
    -- 4. FINALIZAR
    updateProgress(100, "¡Completado!")
    progDlg:close()
    app.refresh()
    app.alert("¡Terminado! Imagen reducida de " .. startCount .. " a " .. #paletteList .. " colores.")
end)
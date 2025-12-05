-- Script Corregido: Reductor de Colores para Aseprite
-- Soluciona el error de "0 colores encontrados" forzando modo RGB

local sprite = app.activeSprite
if not sprite then return app.alert("No hay ningún sprite abierto.") end

-- --- UTILIDADES DE COLOR ---
local function getRGB(colorInt)
    return app.pixelColor.rgbaR(colorInt), app.pixelColor.rgbaG(colorInt), app.pixelColor.rgbaB(colorInt), app.pixelColor.rgbaA(colorInt)
end

local function makeColor(r, g, b, a)
    return app.pixelColor.rgba(r, g, b, a)
end

local function dist3d(c1, c2)
    local r1, g1, b1, a1 = getRGB(c1)
    local r2, g2, b2, a2 = getRGB(c2)
    return math.sqrt((r2-r1)^2 + (g2-g1)^2 + (b2-b1)^2)
end

local function mixColors(c1, c2)
    local r1, g1, b1, a1 = getRGB(c1)
    local r2, g2, b2, a2 = getRGB(c2)
    return makeColor(
        math.floor((r1+r2)/2),
        math.floor((g1+g2)/2),
        math.floor((b1+b2)/2),
        255 -- Forzamos opacidad completa en la mezcla
    )
end

local function findClosestColor(target, palette)
    local minDist = 999999999
    local closest = target
    for _, col in ipairs(palette) do
        local d = dist3d(target, col)
        if d < minDist then
            minDist = d
            closest = col
        end
    end
    return closest
end

-- --- DIÁLOGO ---
local dlg = Dialog("Reducir Colores")
dlg:number{ id="targetCount", label="Objetivo de Colores:", text="16", decimals=0 }
dlg:button{ id="ok", text="SIMPLIFY" }
dlg:show()

local data = dlg.data
if not data.ok then return end
local targetCount = data.targetCount

-- --- PROCESO PRINCIPAL ---
app.transaction(function()
    
    -- 1. CORRECCIÓN AUTOMÁTICA DE MODO DE COLOR
    -- Si la imagen es Indexada o Grises, la pasamos a RGB para poder manipular los colores
    if sprite.colorMode ~= ColorMode.RGB then
        print("La imagen no es RGB. Convirtiendo a RGB para procesar...")
        app.command.ChangePixelFormat{ format="rgb" }
    end

    print("Analizando píxeles...")
    
    local uniqueSet = {}
    local uniqueList = {}
    local pixelCounter = 0
    
    -- 2. RECOLECTAR COLORES (Iterando todas las capas y cels)
    for _, layer in ipairs(sprite.layers) do
        if layer.isImage and layer.isVisible then -- Solo capas visibles e imagen
            for _, cel in ipairs(layer.cels) do
                local img = cel.image
                for it in img:pixels() do
                    local pixelValue = it()
                    
                    -- Obtenemos el Alpha (Transparencia)
                    local alpha = app.pixelColor.rgbaA(pixelValue)
                    
                    -- Consideramos válido si tiene algo de opacidad
                    if alpha > 0 then
                        if not uniqueSet[pixelValue] then
                            uniqueSet[pixelValue] = true
                            table.insert(uniqueList, pixelValue)
                        end
                        pixelCounter = pixelCounter + 1
                    end
                end
            end
        end
    end

    local startCount = #uniqueList
    print("Píxeles analizados: " .. pixelCounter)
    print("Colores únicos encontrados: " .. startCount)
    
    if startCount == 0 then
        return app.alert("Error: Sigue encontrando 0 colores. Asegúrate de que la capa no esté vacía o totalmente transparente.")
    end

    if startCount <= targetCount then
        return app.alert("No es necesario reducir: Tienes " .. startCount .. " colores, y quieres " .. targetCount .. ".")
    end

    -- 3. ALGORITMO DE CLUSTERING (Reducción)
    local currentPalette = uniqueList
    
    -- Bucle de reducción
    while #currentPalette > targetCount do
        local minD = 99999999
        local idx1, idx2 = -1, -1
        
        -- Buscamos el par más cercano (optimización simple)
        -- Nota: Para muchas imágenes grandes esto tomará unos segundos
        for i=1, #currentPalette do
            for j=i+1, #currentPalette do
                local d = dist3d(currentPalette[i], currentPalette[j])
                if d < minD then
                    minD = d
                    idx1 = i
                    idx2 = j
                end
            end
        end
        
        if idx1 ~= -1 then
            -- Fusionamos los dos colores
            local newColor = mixColors(currentPalette[idx1], currentPalette[idx2])
            
            -- Eliminar (el mayor primero para mantener orden)
            table.remove(currentPalette, idx2)
            table.remove(currentPalette, idx1)
            
            -- Insertar el nuevo color promedio
            table.insert(currentPalette, newColor)
        else
            break
        end
    end

    -- 4. APLICAR CAMBIOS
    print("Aplicando nueva paleta de " .. #currentPalette .. " colores...")
    
    local replacementCache = {}
    
    for _, layer in ipairs(sprite.layers) do
        if layer.isImage and layer.isVisible then
            for _, cel in ipairs(layer.cels) do
                local img = cel.image
                for it in img:pixels() do
                    local originalColor = it()
                    
                    if app.pixelColor.rgbaA(originalColor) > 0 then
                        local newColor
                        if replacementCache[originalColor] then
                            newColor = replacementCache[originalColor]
                        else
                            newColor = findClosestColor(originalColor, currentPalette)
                            replacementCache[originalColor] = newColor
                        end
                        
                        if originalColor ~= newColor then
                            it(newColor)
                        end
                    end
                end
            end
        end
    end
    
    app.refresh()
    app.alert("¡Listo! Colores reducidos de " .. startCount .. " a " .. #currentPalette)
end)
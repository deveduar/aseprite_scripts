-- Reductor de Colores ULTRA-RÁPIDO v3.1 (Median-Cut Corregido)

local sprite = app.activeSprite
if not sprite then return app.alert("No hay ningún sprite abierto.") end

-- --- UTILIDADES RÁPIDAS ---
local function getRGB(colorInt)
    -- Devuelve R, G, B de un color entero
    return app.pixelColor.rgbaR(colorInt), app.pixelColor.rgbaG(colorInt), app.pixelColor.rgbaB(colorInt)
end

local function makeColor(r, g, b, a)
    -- Crea un color entero de Aseprite
    return app.pixelColor.rgba(r, g, b, a)
end

-- --- CLASE DE CAJA PARA ALGORITMO MEDIAN-CUT ---
local Box = {}
Box.__index = Box

function Box.new(colors)
    local self = {
        colors = colors,
        minR = 256, minG = 256, minB = 256,
        maxR = -1, maxG = -1, maxB = -1,
        rangeR = 0, rangeG = 0, rangeB = 0,
        longestAxis = 'R',
    }
    setmetatable(self, Box)
    self:calculateBounds()
    return self
end

function Box:calculateBounds()
    local minR, minG, minB = 256, 256, 256
    local maxR, maxG, maxB = -1, -1, -1

    -- Bucle para encontrar los límites RGB de los colores en esta caja
    for _, c in ipairs(self.colors) do
        minR = math.min(minR, c.r)
        maxR = math.max(maxR, c.r)
        minG = math.min(minG, c.g)
        maxG = math.max(maxG, c.g)
        minB = math.min(minB, c.b)
        maxB = math.max(maxB, c.b)
    end
    
    self.minR, self.minG, self.minB = minR, minG, minB
    self.maxR, self.maxG, self.maxB = maxR, maxG, maxB

    self.rangeR = maxR - minR
    self.rangeG = maxG - minG
    self.rangeB = maxB - minB

    -- Determinar el eje más largo para la división
    if self.rangeR >= self.rangeG and self.rangeR >= self.rangeB then
        self.longestAxis = 'R'
    elseif self.rangeG >= self.rangeR and self.rangeG >= self.rangeB then
        self.longestAxis = 'G'
    else
        self.longestAxis = 'B'
    end
end

-- --- DIÁLOGO DE CONFIGURACIÓN ---
local dlg = Dialog("Reductor Median-Cut")
dlg:number{ id="targetCount", label="Objetivo Colores (K):", text="16", decimals=0 }
dlg:button{ id="ok", text="GENERAR PALETA" }
dlg:show()

local data = dlg.data
if not data.ok then return end
local targetCount = data.targetCount

-- --- PROCESO PRINCIPAL (O(N log K)) ---
app.transaction(function()
    
    if sprite.colorMode ~= ColorMode.RGB then
        app.command.ChangePixelFormat{ format="rgb" }
    end

    print("1. Colección de colores únicos (O(N))...")

    -- 1. COLECCIÓN DE COLORES ÚNICOS
    local uniqueMap = {}
    local allColors = {} -- Lista de tablas {r, g, b, originalInt}
    
    for _, layer in ipairs(sprite.layers) do
        if layer.isImage and layer.isVisible then
            for _, cel in ipairs(layer.cels) do
                local img = cel.image
                for it in img:pixels() do
                    local val = it()
                    
                    if app.pixelColor.rgbaA(val) > 0 and not uniqueMap[val] then
                        local r, g, b = getRGB(val)
                        local obj = { r=r, g=g, b=b, originalInt=val }
                        uniqueMap[val] = true
                        table.insert(allColors, obj)
                    end
                end
            end
        end
    end

    local startCount = #allColors
    print("Colores únicos encontrados: " .. startCount)
    
    if startCount <= targetCount then
        return app.alert("No es necesario reducir. Colores actuales: " .. startCount)
    end
    
    if startCount < 2 then
        return app.alert("La imagen solo tiene 1 color.")
    end

    -- 2. ALGORITMO MEDIAN-CUT (O(N log K))
    print("2. Aplicando Median-Cut para generar la paleta...")
    
    local boxes = { Box.new(allColors) }

    -- Bucle principal: dividir hasta obtener el número objetivo de cajas
    while #boxes < targetCount do
        
        -- Encontrar la caja con el mayor rango de color para dividir
        local bestBox = nil
        local bestBoxIndex = -1 -- ¡Corregido: guardamos el índice!
        local maxRange = -1 

        for i=1, #boxes do
            local currentBox = boxes[i]
            local currentRange = currentBox.rangeR + currentBox.rangeG + currentBox.rangeB
            
            if currentRange > maxRange then
                maxRange = currentRange
                bestBox = currentBox
                bestBoxIndex = i -- ¡Corregido: guardamos el índice!
            end
        end
        
        -- Si no se puede dividir más (ej. todas las cajas tienen colores idénticos), salir
        if maxRange <= 0 or not bestBox then break end

        -- 2a. Ordenar los colores de la caja por el eje más largo
        local axis = bestBox.longestAxis
        
        -- table.sort necesita una clave dinámica, usamos una función anónima
        table.sort(bestBox.colors, function(a, b) return a[axis:lower()] < b[axis:lower()] end)

        -- 2b. Encontrar el punto de corte (mediana)
        local medianIndex = math.floor(#bestBox.colors / 2)
        
        -- 2c. Crear las dos nuevas cajas (split)
        local newColors1 = {}
        local newColors2 = {}
        
        for i=1, #bestBox.colors do
            if i <= medianIndex then
                table.insert(newColors1, bestBox.colors[i])
            else
                table.insert(newColors2, bestBox.colors[i])
            end
        end
        
        -- Reemplazar la caja dividida con las dos nuevas
        table.remove(boxes, bestBoxIndex) -- ¡CORREGIDO! Usamos el índice guardado
        
        -- Solo insertamos si tienen colores
        if #newColors1 > 0 then table.insert(boxes, Box.new(newColors1)) end
        if #newColors2 > 0 then table.insert(boxes, Box.new(newColors2)) end
        
        if #boxes >= 1024 then break end
    end

    -- 3. CALCULAR PALETA FINAL (Promedio de las cajas)
    local finalPalette = {}
    for _, box in ipairs(boxes) do
        local sumR, sumG, sumB = 0, 0, 0
        local count = #box.colors
        
        if count > 0 then
            for _, colorObj in ipairs(box.colors) do
                sumR = sumR + colorObj.r
                sumG = sumG + colorObj.g
                sumB = sumB + colorObj.b
            end

            local avgR = math.floor(sumR / count)
            local avgG = math.floor(sumG / count)
            local avgB = math.floor(sumB / count)
            
            table.insert(finalPalette, { 
                r=avgR, g=avgG, b=avgB, 
                finalInt=makeColor(avgR, avgG, avgB, 255) 
            })
        end
    end
    
    local finalCount = #finalPalette
    print("Paleta final generada: " .. finalCount .. " colores.")

    -- 4. REMAPEO FINAL (O(N) Lineal, con caché O(1))
    print("4. Aplicando nueva paleta a los píxeles...")
    
    local cache = {} -- Caché: {colorOriginalInt: colorFinalInt}
    
    for _, layer in ipairs(sprite.layers) do
        if layer.isImage and layer.isVisible then
            for _, cel in ipairs(layer.cels) do
                local img = cel.image
                for it in img:pixels() do
                    local val = it()
                    if app.pixelColor.rgbaA(val) > 0 then
                        
                        local bestC
                        if cache[val] then
                            -- Caso 1: Color ya calculado (O(1))
                            bestC = cache[val]
                        else
                            -- Caso 2: Calcular el vecino más cercano (Rápido, paleta pequeña)
                            local r, g, b = getRGB(val)
                            local bestD = 999999999
                            bestC = val
                            
                            for _, palCol in ipairs(finalPalette) do
                                -- Distancia al cuadrado (máxima velocidad)
                                local d = (palCol.r - r)^2 + (palCol.g - g)^2 + (palCol.b - b)^2
                                if d < bestD then
                                    bestD = d
                                    bestC = palCol.finalInt
                                end
                            end
                            cache[val] = bestC -- Guardar en caché
                        end
                        
                        if val ~= bestC then it(bestC) end
                    end
                end
            end
        end
    end
    
    app.refresh()
    app.alert("¡Terminado! Reducido a " .. finalCount .. " colores con Median-Cut.")
end)
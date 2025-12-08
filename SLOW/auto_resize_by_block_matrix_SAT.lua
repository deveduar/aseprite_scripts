-- Script: Auto-resize Optimized (SAT) - No UI
-- Description: Redimensionado ultra-rápido usando tablas de suma de área.
-- Mantiene el canvas "congelado" hasta terminar para máxima velocidad.

local sprite = app.activeSprite

-- 1. VALIDACIÓN
if not sprite then return app.alert("No hay sprite activo.") end

-- 2. CLASE SAT (SUMMED AREA TABLE)
-- Esta clase permite calcular el promedio de un área en tiempo O(1)
local SAT = {}
SAT.__index = SAT

function SAT.new(image)
    local w = image.width
    local h = image.height
    local len = (w + 1) * (h + 1)
    
    -- Arrays planos para velocidad
    local sumR, sumG, sumB, sumA, sumC = {}, {}, {}, {}, {}

    -- Inicialización rápida
    for i = 1, len do
        sumR[i]=0; sumG[i]=0; sumB[i]=0; sumA[i]=0; sumC[i]=0
    end

    local self = setmetatable({
        w = w, h = h,
        r = sumR, g = sumG, b = sumB, a = sumA, c = sumC
    }, SAT)

    -- Construcción de la tabla integral
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local pixel = image:getPixel(x, y)
            local a = app.pixelColor.rgbaA(pixel)
            
            local rVal, gVal, bVal, aVal, cVal = 0, 0, 0, 0, 0
            if a > 0 then
                rVal = app.pixelColor.rgbaR(pixel)
                gVal = app.pixelColor.rgbaG(pixel)
                bVal = app.pixelColor.rgbaB(pixel)
                aVal = a
                cVal = 1
            end

            local cur = 1 + (x + 1) + (y + 1) * (w + 1)
            local left = 1 + (x) + (y + 1) * (w + 1)
            local top = 1 + (x + 1) + (y) * (w + 1)
            local diag = 1 + (x) + (y) * (w + 1)

            self.r[cur] = rVal + self.r[left] + self.r[top] - self.r[diag]
            self.g[cur] = gVal + self.g[left] + self.g[top] - self.g[diag]
            self.b[cur] = bVal + self.b[left] + self.b[top] - self.b[diag]
            self.a[cur] = aVal + self.a[left] + self.a[top] - self.a[diag]
            self.c[cur] = cVal + self.c[left] + self.c[top] - self.c[diag]
        end
    end
    return self
end

-- Obtiene la suma de un bloque rectangular
function SAT:getSum(x, y, w, h)
    local x0 = math.max(0, x)
    local y0 = math.max(0, y)
    local x1 = math.min(self.w, x + w)
    local y1 = math.min(self.h, y + h)

    if x0 >= x1 or y0 >= y1 then return 0,0,0,0,0 end

    local rowWidth = self.w + 1
    local iD = 1 + x1 + y1 * rowWidth
    local iA = 1 + x0 + y0 * rowWidth
    local iB = 1 + x1 + y0 * rowWidth
    local iC = 1 + x0 + y1 * rowWidth

    local r = self.r[iD] + self.r[iA] - self.r[iB] - self.r[iC]
    local g = self.g[iD] + self.g[iA] - self.g[iB] - self.g[iC]
    local b = self.b[iD] + self.b[iA] - self.b[iB] - self.b[iC]
    local a = self.a[iD] + self.a[iA] - self.a[iB] - self.a[iC]
    local c = self.c[iD] + self.c[iA] - self.c[iB] - self.c[iC]

    return r, g, b, a, c
end

-- 3. INTERFAZ SIMPLE
local dlg = Dialog("Reducir (SAT Rápido)")
local initialBlock = 2

dlg:label{ text="Original: " .. sprite.width .. "x" .. sprite.height .. " px" }
dlg:entry{
    id = "blockSize",
    label = "Bloque (NxN):",
    text = tostring(initialBlock),
    onchange = function()
        local val = tonumber(dlg.data.blockSize)
        if val and val > 0 then
            local newW = math.floor(sprite.width / val)
            local newH = math.floor(sprite.height / val)
            dlg:modify{ id="preview", text="Nuevo: " .. newW .. "x" .. newH .. " px" }
        end
    end
}
dlg:label{ id="preview", text="Nuevo: " .. math.floor(sprite.width/initialBlock) .. "x" .. math.floor(sprite.height/initialBlock) }
dlg:button{ id = "ok", text = "PROCESAR" }

dlg:show()
if not dlg.data.ok then return end

local blockSize = tonumber(dlg.data.blockSize)
local targetWidth = math.floor(sprite.width / blockSize)
local targetHeight = math.floor(sprite.height / blockSize)

if blockSize < 1 or targetWidth < 1 then return app.alert("Parámetros inválidos") end

-- 4. PROCESAMIENTO (Transacción Única)

app.transaction(function()
    -- Iterar capas y cels
    for _, layer in ipairs(sprite.layers) do
        if layer.isImage then
            for _, cel in ipairs(layer.cels) do
                local srcImg = cel.image
                -- Creamos la tabla integral solo para el tamaño de este cel (optimización memoria)
                local sat = SAT.new(srcImg)
                
                -- Imagen de destino pequeña
                local newCelImg = Image(targetWidth, targetHeight, sprite.colorMode)
                
                -- Posición del cel en el canvas grande
                local celX = cel.position.x
                local celY = cel.position.y

                -- Recorremos píxeles de la imagen DESTINO
                for dy = 0, targetHeight - 1 do
                    for dx = 0, targetWidth - 1 do
                        -- Coordenada en el canvas original
                        local boxX = dx * blockSize
                        local boxY = dy * blockSize

                        -- Coordenada relativa al cel actual
                        -- Esto evita tener que crear una imagen temporal de 1920x1080
                        local localX = boxX - celX
                        local localY = boxY - celY
                        
                        -- El SAT maneja internamente si las coordenadas están fuera del cel
                        local r, g, b, a, count = sat:getSum(localX, localY, blockSize, blockSize)

                        if count > 0 then
                            local finalColor = app.pixelColor.rgba(
                                math.floor(r / count),
                                math.floor(g / count),
                                math.floor(b / count),
                                math.floor(a / count)
                            )
                            newCelImg:drawPixel(dx, dy, finalColor)
                        end
                    end
                end

                -- Asignamos la nueva imagen pequeña y reseteamos la posición
                cel.image = newCelImg
                cel.position = Point(0, 0)
            end
        end
    end

    -- Finalmente ajustamos el tamaño del canvas
    app.command.CanvasSize {
        width = targetWidth,
        height = targetHeight,
        location = "Top-Left"
    }
end)

app.refresh()
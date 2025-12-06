-- Script: Auto-resize by Matrix Block (PRO)
-- Description: Reduce la imagen promediando bloques de NxN a 1x1 píxel.
-- Supports: Animaciones, Capas y Redimensionado de Canvas.

local sprite = app.activeSprite

-- 1. VALIDACIÓN
if not sprite then
    app.alert("Error: No hay ningún sprite activo.")
    return
end

-- 2. FUNCIONES AUXILIARES

-- Calcula el promedio de color de un bloque
local function getAverageColor(image, startX, startY, blockSize)
    local r, g, b, a = 0, 0, 0, 0
    local count = 0
    local imgWidth = image.width
    local imgHeight = image.height

    for y = 0, blockSize - 1 do
        for x = 0, blockSize - 1 do
            local px = startX + x
            local py = startY + y

            -- Solo procesar si está dentro de los límites de la imagen original
            if px < imgWidth and py < imgHeight then
                local color = image:getPixel(px, py)
                
                -- Extraer componentes (funciona mejor en modo RGB)
                if app.pixelColor.rgbaA(color) > 0 then
                    r = r + app.pixelColor.rgbaR(color)
                    g = g + app.pixelColor.rgbaG(color)
                    b = b + app.pixelColor.rgbaB(color)
                    a = a + app.pixelColor.rgbaA(color)
                    count = count + 1
                end
            end
        end
    end

    if count > 0 then
        return app.pixelColor.rgba(
            math.floor(r / count),
            math.floor(g / count),
            math.floor(b / count),
            math.floor(a / count)
        )
    else
        return app.pixelColor.rgba(0, 0, 0, 0) -- Transparente si no hay píxeles
    end
end

-- Procesa una imagen individual (un cel)
local function processImage(image, blockSize, targetW, targetH)
    local newImage = Image(targetW, targetH, image.colorMode)
    
    for y = 0, targetH - 1 do
        for x = 0, targetW - 1 do
            -- Mapear coordenada destino a coordenada origen (esquina superior izq del bloque)
            local srcX = x * blockSize
            local srcY = y * blockSize
            
            local avgColor = getAverageColor(image, srcX, srcY, blockSize)
            newImage:drawPixel(x, y, avgColor)
        end
    end
    return newImage
end

-- 3. INTERFAZ DE USUARIO

local dlg = Dialog("Reducir por Matriz")
local initialBlock = 2 -- Valor por defecto seguro

dlg:label{ 
    id="info", 
    text="Original: " .. sprite.width .. "x" .. sprite.height .. " px" 
}

dlg:entry{
    id = "blockSize",
    label = "Tamaño Matriz (NxN):",
    text = tostring(initialBlock),
    onchange = function()
        local val = tonumber(dlg.data.blockSize)
        if val and val > 0 then
            local newW = math.floor(sprite.width / val)
            local newH = math.floor(sprite.height / val)
            dlg:modify{ id="preview", text="Nuevo tamaño: " .. newW .. "x" .. newH .. " px" }
        else
            dlg:modify{ id="preview", text="Valor inválido" }
        end
    end
}

dlg:label{ id="preview", text="Nuevo tamaño: " .. math.floor(sprite.width/initialBlock) .. "x" .. math.floor(sprite.height/initialBlock) .. " px" }
dlg:separator{}
dlg:button{ id = "ok", text = "PROCESAR" }
dlg:button{ id = "cancel", text = "Cancelar" }

dlg:show()

if not dlg.data.ok then return end

-- 4. EJECUCIÓN PRINCIPAL

local blockSize = tonumber(dlg.data.blockSize)
if not blockSize or blockSize < 1 then
    app.alert("El tamaño del bloque debe ser mayor a 0.")
    return
end

local targetWidth = math.floor(sprite.width / blockSize)
local targetHeight = math.floor(sprite.height / blockSize)

if targetWidth < 1 or targetHeight < 1 then
    app.alert("El bloque es demasiado grande para la imagen.")
    return
end

app.transaction(function()
    -- Recorrer todas las capas y frames
    for _, layer in ipairs(sprite.layers) do
        -- Ignorar capas de grupo, solo procesar capas con contenido
        if layer.isImage then 
            for _, cel in ipairs(layer.cels) do
                -- Creamos una imagen temporal del tamaño completo del sprite original
                -- Esto es necesario porque los Cels pueden ser más pequeños que el canvas
                local fullCanvasImage = Image(sprite.width, sprite.height, sprite.colorMode)
                fullCanvasImage:drawImage(cel.image, cel.position)
                
                -- Procesamos la imagen completa
                local newCelImage = processImage(fullCanvasImage, blockSize, targetWidth, targetHeight)
                
                -- Reemplazamos la imagen del cel y reseteamos su posición
                cel.image = newCelImage
                cel.position = Point(0, 0)
            end
        end
    end

    -- Finalmente, redimensionar el canvas del sprite
    sprite:resize(targetWidth, targetHeight)
end)

app.refresh()
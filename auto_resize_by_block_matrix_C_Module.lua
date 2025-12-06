-- Script: Redimensionado Instantáneo con Comando Nativo C++
-- Description: Utiliza app.command.SpriteSize para la máxima velocidad.
-- Nota: Usa Bilineal, que es similar al promedio de bloques, pero sin el costo de Lua.

local sprite = app.activeSprite

-- 1. VALIDACIÓN
if not sprite then
    app.alert("Error: No hay ningún sprite activo.")
    return
end

-- 2. INTERFAZ DE USUARIO

local dlg = Dialog("Redimensionar Rápido (C++ Nativo)")
local initialFactor = 2 -- Valor por defecto para dividir el tamaño

dlg:label{ 
    id="info", 
    text="Original: " .. sprite.width .. "x" .. sprite.height .. " px" 
}

dlg:entry{
    id = "factor",
    label = "Factor de División (Ej. 2 para 50%):",
    text = tostring(initialFactor),
    onchange = function()
        local val = tonumber(dlg.data.factor)
        if val and val > 1 then
            local newW = math.floor(sprite.width / val)
            local newH = math.floor(sprite.height / val)
            dlg:modify{ id="preview", text="Nuevo tamaño: " .. newW .. "x" .. newH .. " px" }
        else
            dlg:modify{ id="preview", text="Factor inválido o menor a 1" }
        end
    end
}

dlg:label{ id="preview", text="Nuevo tamaño: " .. math.floor(sprite.width/initialFactor) .. "x" .. math.floor(sprite.height/initialFactor) .. " px" }
dlg:separator{}
dlg:button{ id = "ok", text = "REDIMENSIONAR INSTANTÁNEO" }
dlg:button{ id = "cancel", text = "Cancelar" }

dlg:show()

if not dlg.data.ok then return end

-- 3. EJECUCIÓN DEL COMANDO C++

local factor = tonumber(dlg.data.factor)
if not factor or factor <= 1 then
    app.alert("El factor de división debe ser mayor a 1.")
    return
end

local targetWidth = math.floor(sprite.width / factor)
local targetHeight = math.floor(sprite.height / factor)

if targetWidth < 1 or targetHeight < 1 then
    app.alert("El factor es demasiado grande. El nuevo tamaño sería 0x0.")
    return
end

-- Este comando usa el motor interno de Aseprite (C++) para redimensionar 
-- todo el sprite (todas las capas y frames) de una sola vez.
app.command.SpriteSize {
    width = targetWidth,
    height = targetHeight,
    -- Bilineal es la opción más cercana al promedio de bloques (Box filter)
    method = "bilinear", 
    -- Mantiene la posición de origen en la esquina superior izquierda
    target = "Top-Left", 
    lockRatio = true
}

app.refresh()
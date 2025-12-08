-- Script: Quitar Dithering por Desenfoque (CORREGIDO)
local sprite = app.activeSprite

if not sprite then return app.alert("Error: No hay ningún sprite activo.") end

local dlg = Dialog("Quitar Dithering (Blur)")
local initialAmount = 1

dlg:label{ text="Este script aplica un desenfoque a todas las celdas." }
dlg:entry{
    id = "amount",
    label = "Fuerza (1-5):",
    text = tostring(initialAmount)
}
dlg:button{ id = "ok", text = "APLICAR" }
dlg:show()

if not dlg.data.ok then return end

local amount = tonumber(dlg.data.amount)
if not amount or amount <= 0 then return app.alert("La fuerza debe ser positiva.") end

app.transaction(function()
    for i, frame in ipairs(sprite.frames) do
        for j, layer in ipairs(sprite.layers) do
            if layer.isImage and layer.isEditable and layer.isVisible then
                
                local cel = layer:cel(frame)
                if cel then
                    app.activeFrame = frame
                    app.activeLayer = layer

                    app.command.Despeckle{
                        ui = false,
                        channels = FilterChannels.RGBA,
                        tiledMode = "none", -- CORREGIDO
                        amount = amount
                    }

                end
            end
        end
    end
end)

app.refresh()
app.alert("Proceso completado.")

-------------------------------------------------------------------
-- AI NOISE CLEANER PRO (Final + Fix Sobel + Compatible Undo)
-- Limpia ruido de IA: anti-aliasing extraño, pixeles aislados,
-- halos de colores no deseados, etc.
-- CTRL+Z funciona (todo dentro de app.transaction).
-------------------------------------------------------------------

local sprite = app.activeSprite
if not sprite then return app.alert("No hay sprite activo.") end

-------------------------------------------------------------------
-- UI PRO
-------------------------------------------------------------------
local dlg = Dialog("AI Noise Cleaner PRO")

dlg:label{
  text="Limpieza avanzada de ruido generado por IA.\n" ..
       "Corrige AA raro, pixeles sueltos y colores incorrectos."
}

dlg:slider{
    id="strength",
    label="Intensidad (1–20):",
    min=1, max=20, value=8
}

dlg:slider{
    id="distance",
    label="Umbral distancia color (1–200):",
    min=1, max=200, value=45
}

dlg:combobox{
    id="mode",
    label="Modo de reemplazo:",
    options={
        "color mayoritario",
        "color más cercano",
        "borrar"
    },
    option="color mayoritario"
}

dlg:combobox{
    id="filter",
    label="Afectar solo:",
    options={
        "todo",
        "pixeles oscuros",
        "pixeles claros",
        "bordes"
    },
    option="todo"
}

dlg:check{
    id="ignore_transparent",
    label="Ignorar transparentes",
    selected=true
}

dlg:button{ id="ok", text="APLICAR" }
dlg:button{ id="cancel", text="Cancelar" }

dlg:show()
local data = dlg.data
if not data.ok then return end

local strength = data.strength
local distanceThreshold = data.distance
local mode = data.mode
local filter = data.filter
local ignoreTransparent = data.ignore_transparent

-------------------------------------------------------------------
-- UTILIDADES DE COLOR — SIEMPRE DEVUELVEN VALORES SEGUROS
-------------------------------------------------------------------
local function colorDistance(c1, c2)
    if not c1 or not c2 then return 1e12 end
    local r1,g1,b1,a1 = app.pixelColor.rgba(c1)
    local r2,g2,b2,a2 = app.pixelColor.rgba(c2)
    r1,g1,b1 = r1 or 0, g1 or 0, b1 or 0
    r2,g2,b2 = r2 or 0, g2 or 0, b2 or 0
    local dr = r1 - r2
    local dg = g1 - g2
    local db = b1 - b2
    return dr*dr + dg*dg + db*db
end

local function isDark(c)
    local r,g,b,a = app.pixelColor.rgba(c)
    return (r+g+b) < 384 -- 128*3
end

local function isLight(c)
    local r,g,b,a = app.pixelColor.rgba(c)
    return (r+g+b) > 384
end

-------------------------------------------------------------------
-- DETECTOR DE BORDES (SOBEL) — FIX ANTI-NIL
-------------------------------------------------------------------
local function isEdge(img, x, y)
    local w, h = img.width, img.height
    if x<=0 or x>=w-1 or y<=0 or y>=h-1 then return false end

    local function lum(px)
        if not px then return 0 end
        local r,g,b,a = app.pixelColor.rgba(px)
        r,g,b = r or 0, g or 0, b or 0
        return r*0.3 + g*0.59 + b*0.11
    end

    local gx = 
        lum(img:getPixel(x+1,y)) - lum(img:getPixel(x-1,y)) +
        lum(img:getPixel(x+1,y+1)) - lum(img:getPixel(x-1,y+1)) +
        lum(img:getPixel(x+1,y-1)) - lum(img:getPixel(x-1,y-1))

    local gy =
        lum(img:getPixel(x,y+1)) - lum(img:getPixel(x,y-1)) +
        lum(img:getPixel(x+1,y+1)) - lum(img:getPixel(x+1,y-1)) +
        lum(img:getPixel(x-1,y+1)) - lum(img:getPixel(x-1,y-1))

    local mag = gx*gx + gy*gy
    return mag > 20000
end

-------------------------------------------------------------------
-- PROCESO PRINCIPAL — CTRL+Z FUNCIONA
-------------------------------------------------------------------
app.transaction(function()

    for _, cel in ipairs(sprite.cels) do
        local original = cel.image
        if not original then goto continueCel end

        local img = original:clone()     -- lectura
        local out = original:clone()     -- escritura
        local w, h = img.width, img.height

        for y=0,h-1 do
            for x=0,w-1 do

                local c = img:getPixel(x,y)
                local r,g,b,a = app.pixelColor.rgba(c)

                if ignoreTransparent and a == 0 then
                    goto continuePixel
                end

                ---------------------------------------------------
                -- FILTROS
                ---------------------------------------------------
                if filter == "pixeles oscuros" and not isDark(c) then goto continuePixel end
                if filter == "pixeles claros" and not isLight(c) then goto continuePixel end
                if filter == "bordes" and not isEdge(img,x,y) then goto continuePixel end

                ---------------------------------------------------
                -- ANALIZAR VECINOS
                ---------------------------------------------------
                local count = {}
                local maxColor, maxCount = nil, 0
                local neighborMatches = 0

                for dy=-1,1 do
                    for dx=-1,1 do
                        if not(dx==0 and dy==0) then
                            local xx,yy = x+dx, y+dy
                            if xx>=0 and xx<w and yy>=0 and yy<h then
                                local nc = img:getPixel(xx,yy)

                                if nc == c then
                                    neighborMatches = neighborMatches + 1
                                end

                                count[nc] = (count[nc] or 0) + 1
                                if count[nc] > maxCount then
                                    maxColor = nc
                                    maxCount = count[nc]
                                end
                            end
                        end
                    end
                end

                if not maxColor then goto continuePixel end

                ---------------------------------------------------
                -- DETECCIÓN OUTLIER
                ---------------------------------------------------
                local minNeighbors = math.floor(strength / 2)
                local isOutlierByNeighbors = neighborMatches < minNeighbors

                local isOutlierByColor = 
                    colorDistance(c, maxColor) > (distanceThreshold * distanceThreshold)

                if isOutlierByNeighbors or isOutlierByColor then

                    if mode == "color mayoritario" then
                        out:putPixel(x,y, maxColor)

                    elseif mode == "color más cercano" then
                        local best = maxColor
                        local bestDist = colorDistance(c, best)
                        for col,_ in pairs(count) do
                            local d = colorDistance(c, col)
                            if d < bestDist then
                                best = col
                                bestDist = d
                            end
                        end
                        out:putPixel(x,y, best)

                    elseif mode == "borrar" then
                        out:putPixel(x,y, app.pixelColor.rgba(0,0,0,0))
                    end
                end

                ::continuePixel::
            end
        end

        -- Reasigna la imagen para generar historial de undo correcto
        cel.image = out

        ::continueCel::
    end

end)

app.refresh()
app.alert("AI Noise Cleaner PRO — Completado.")

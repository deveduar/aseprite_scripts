local sprite = app.activeSprite
if not sprite then return app.alert("No sprite activo") end

app.transaction(function()

  for _, cel in ipairs(sprite.cels) do
    local img = cel.image
    local w, h = img.width, img.height

    for y=0,h-1 do
      for x=0,w-1 do
        
        local c = img:getPixel(x,y)

        -- construir histograma de vecinos
        local count = {}
        local maxColor, maxCount = nil, 0
        
        for dy=-1,1 do
          for dx=-1,1 do
            if not (dx==0 and dy==0) then
              local xx, yy = x+dx, y+dy
              if xx>=0 and xx<w and yy>=0 and yy<h then
                local nc = img:getPixel(xx,yy)
                count[nc] = (count[nc] or 0) + 1
                if count[nc] > maxCount then
                  maxColor, maxCount = nc, count[nc]
                end
              end
            end
          end
        end

        -- si el pixel es minoritario, lo quitamos
        if count[c] == nil or count[c] < 2 then
          img:putPixel(x,y, maxColor)  -- o Color(0,0,0,0) si quieres borrar
        end
      end
    end
  end

end)

app.refresh()
app.alert("Limpieza completada.")

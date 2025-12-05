-- Aseprite Script para importar animaciones desde JSON y PNGs individuales
-- Versión: 2.0 (Estable con app.fs)

local json = {_version = "0.1.1"}

-------------------------------------------------------------------------------
-- JSON DECODE (Compactado para ahorrar espacio, funciona igual)
-------------------------------------------------------------------------------
local decode
local escape_char_map = { ["\\"] = "\\", ["\""] = "\"", ["\b"] = "\b", ["\f"] = "\f", ["\n"] = "\n", ["\r"] = "\r", ["\t"] = "\t" }
local escape_char_map_inv = { ["/"] = "/" }
for k, v in pairs(escape_char_map) do escape_char_map_inv[v] = k end
local function create_set(...) local res = {} for i = 1, select("#", ...) do res[select(i, ...)] = true end return res end
local space_chars = create_set(" ", "\t", "\r", "\n")
local delim_chars = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals = create_set("true", "false", "null")
local literal_map = { ["true"] = true, ["false"] = false, ["null"] = nil }
local function next_char(str, idx, set, negate) for i = idx, #str do if set[str:sub(i, i)] ~= negate then return i end end return #str + 1 end
local function decode_error(str, idx, msg) error(string.format("%s at char %d", msg, idx)) end
local function codepoint_to_utf8(n) return n <= 0x7f and string.char(n) or n <= 0x7ff and string.char(math.floor(n / 64) + 192, n % 64 + 128) or string.char(math.floor(n / 4096) + 224, math.floor(n % 4096 / 64) + 128, n % 64 + 128) end
local function parse_unicode_escape(s) local n1 = tonumber(s:sub(3, 6), 16) local n2 = tonumber(s:sub(9, 12), 16) if n2 then return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000) else return codepoint_to_utf8(n1) end end
local function parse_string(str, i) local has_unicode_escape = false local has_surrogate_escape = false local has_escape = false local last for j = i + 1, #str do local x = str:byte(j) if x < 32 then decode_error(str, j, "control char") end if last == 92 then if x == 117 then local hex = str:sub(j + 1, j + 5) if not hex:find("%x%x%x%x") then decode_error(str, j, "invalid unicode") end if hex:find("^[dD][89aAbB]") then has_surrogate_escape = true else has_unicode_escape = true end else local c = string.char(x) if not escape_chars[c] then decode_error(str, j, "invalid escape") end has_escape = true end last = nil elseif x == 34 then local s = str:sub(i + 1, j - 1) if has_surrogate_escape then s = s:gsub("\\u[dD][89aAbB]..\\u....", parse_unicode_escape) end if has_unicode_escape then s = s:gsub("\\u....", parse_unicode_escape) end if has_escape then s = s:gsub("\\.", escape_char_map_inv) end return s, j + 1 else last = x end end decode_error(str, i, "expected closing quote") end
local function parse_number(str, i) local x = next_char(str, i, delim_chars) local s = str:sub(i, x - 1) local n = tonumber(s) if not n then decode_error(str, i, "invalid number") end return n, x end
local function parse_literal(str, i) local x = next_char(str, i, delim_chars) local word = str:sub(i, x - 1) if not literals[word] then decode_error(str, i, "invalid literal") end return literal_map[word], x end
local function parse_array(str, i) local res = {} local n = 1 i = i + 1 while 1 do local x i = next_char(str, i, space_chars, true) if str:sub(i, i) == "]" then i = i + 1 break end x, i = decode(str, i) res[n] = x n = n + 1 i = next_char(str, i, space_chars, true) local chr = str:sub(i, i) i = i + 1 if chr == "]" then break end if chr ~= "," then decode_error(str, i, "expected ']' or ','") end end return res, i end
local function parse_object(str, i) local res = {} i = i + 1 while 1 do local key, val i = next_char(str, i, space_chars, true) if str:sub(i, i) == "}" then i = i + 1 break end if str:sub(i, i) ~= '"' then decode_error(str, i, "expected string key") end key, i = decode(str, i) i = next_char(str, i, space_chars, true) if str:sub(i, i) ~= ":" then decode_error(str, i, "expected ':'") end i = next_char(str, i + 1, space_chars, true) val, i = decode(str, i) res[key] = val i = next_char(str, i, space_chars, true) local chr = str:sub(i, i) i = i + 1 if chr == "}" then break end if chr ~= "," then decode_error(str, i, "expected '}' or ','") end end return res, i end
local char_func_map = { ['"'] = parse_string, ["0"] = parse_number, ["1"] = parse_number, ["2"] = parse_number, ["3"] = parse_number, ["4"] = parse_number, ["5"] = parse_number, ["6"] = parse_number, ["7"] = parse_number, ["8"] = parse_number, ["9"] = parse_number, ["-"] = parse_number, ["t"] = parse_literal, ["f"] = parse_literal, ["n"] = parse_literal, ["["] = parse_array, ["{"] = parse_object }
decode = function(str, idx) local chr = str:sub(idx, idx) local f = char_func_map[chr] if f then return f(str, idx) end decode_error(str, idx, "unexpected char '" .. chr .. "'") end
function json.decode(str) if type(str) ~= "string" then error("expected string") end return decode(str, next_char(str, 1, space_chars, true)) end

-------------------------------------------------------------------------------
-- LÓGICA PRINCIPAL DE IMPORTACIÓN (CORREGIDA)
-------------------------------------------------------------------------------

local function get_parent_directory(filepath)
    -- Usa app.fs para obtener el directorio del archivo JSON de forma segura
    return app.fs.filePath(filepath)
end

local function extract_frame_number(filename)
    local num = string.match(filename, "frame_(%d+)%.png")
    return tonumber(num) or 9999
end

local function load_image_safely(image_path)
    if not app.fs.isFile(image_path) then
        print("Aviso: Archivo no encontrado: " .. image_path)
        return nil
    end
    
    local sprite = Sprite{ fromFile = image_path }
    if sprite then
        local image = Image(sprite.cels[1].image)
        sprite:close() -- Cerramos el sprite temporal
        return image
    else
        print("Error cargando imagen: " .. image_path)
        return nil
    end
end

-- Función NUEVA Y ROBUSTA para encontrar archivos usando API nativa
local function get_sorted_frame_files(anim_dir_path)
    local files = {}
    
    -- Verificar si el directorio existe
    if not app.fs.isDirectory(anim_dir_path) then
        print("Directorio no encontrado: " .. anim_dir_path)
        return files
    end

    -- Usar app.fs.listFiles (Funciona en Windows/Mac/Linux sin errores de consola)
    local all_files = app.fs.listFiles(anim_dir_path)
    
    if not all_files then return files end

    for _, filename in ipairs(all_files) do
        -- Filtrar solo archivos que cumplan el patrón frame_XXX.png
        if string.match(filename, "frame_%d+%.png$") then
            table.insert(files, {
                path = app.fs.joinPath(anim_dir_path, filename),
                number = extract_frame_number(filename),
                name = filename
            })
        end
    end

    -- Ordenar por número de frame
    table.sort(files, function(a, b)
        return a.number < b.number
    end)

    return files
end

local function import_animation_frames(sprite, base_dir, anim_name, direction)
    -- Construcción de ruta segura usando joinPath
    local anim_dir = app.fs.joinPath(base_dir, "animations", anim_name, direction)
    
    local frame_files = get_sorted_frame_files(anim_dir)
    
    if #frame_files == 0 then
        -- No alertamos para no interrumpir, solo imprimimos en consola
        print("Saltando (sin frames): " .. anim_name .. " / " .. direction)
        return 0
    end
    
    local frames_imported = 0
    
    for i, frame_data in ipairs(frame_files) do
        local frame_image = load_image_safely(frame_data.path)
        
        if frame_image then
            local frame
            -- Lógica para reutilizar el primer frame si es la primera importación
            if sprite.frames[#sprite.frames] and frames_imported == 0 and #sprite.frames == 1 and #sprite.tags == 0 then
                 frame = sprite.frames[1]
            else
                 frame = sprite:newFrame()
            end
            
            -- Asegurar que existe la capa y celda
            local layer = sprite.layers[1]
            if not layer then layer = sprite:newLayer() end
            
            local cel = sprite:newCel(layer, frame)
            cel.image:drawImage(frame_image, 0, 0)
            frame.duration = 0.1
            frames_imported = frames_imported + 1
        end
    end
    
    return frames_imported
end

local function process_animation(sprite, base_dir, anim_name, anim_data, current_frame_index)
    local start_frame = current_frame_index
    local frames_added_total = 0
    
    -- Iteramos las direcciones del JSON
    for direction, frames_list in pairs(anim_data) do
        if type(frames_list) == "table" then -- Verificar que sea una lista de frames
            
            local frames_in_dir = import_animation_frames(
                sprite, base_dir, anim_name, direction
            )
            
            if frames_in_dir > 0 then
                -- Crear el Tag (Etiqueta)
                local from_frame = current_frame_index + 1
                -- Ajuste: si reutilizamos el frame 1, el índice cambia
                if current_frame_index == 0 and #sprite.frames == frames_in_dir then
                    from_frame = 1
                end
                
                local to_frame = current_frame_index + frames_in_dir
                
                local tag = sprite:newTag(from_frame, to_frame)
                tag.name = anim_name .. "_" .. direction
                tag.aniDir = AniDir.FORWARD
                
                current_frame_index = to_frame
                frames_added_total = frames_added_total + frames_in_dir
            end
        end
    end
    
    return frames_added_total
end

local function build_animations_from_json(json_path)
    local base_dir = get_parent_directory(json_path)
    
    local file = io.open(json_path, "r")
    if not file then
        app.alert("ERROR CRITICO: No se pudo abrir el archivo JSON: " .. json_path)
        return nil
    end
    
    local json_content = file:read("*a")
    file:close()
    
    -- Decodificar JSON
    local success, metadata = pcall(function() return json.decode(json_content) end)
    
    if not success or not metadata then
        app.alert("ERROR: JSON inválido.")
        return nil
    end
    
    -- Crear el Sprite
    local width = metadata.character.size.width or 64
    local height = metadata.character.size.height or 64
    
    local main_sprite = Sprite(width, height)
    main_sprite:setPalette(Palette{ fromResource="DB32" }) -- Paleta por defecto opcional
    main_sprite.filename = metadata.character.name or "Imported"
    
    app.command.BackgroundFromLayer() -- Asegurar fondo transparente si es necesario
    
    local current_frame_count = 0
    -- Si el sprite nuevo ya tiene 1 frame vacío, lo contamos como 0 para la lógica de reutilización
    if #main_sprite.frames == 1 then current_frame_count = 0 end

    local animations = metadata.frames.animations
    local anim_count = 0
    
    for anim_name, anim_data in pairs(animations) do
        local added = process_animation(main_sprite, base_dir, anim_name, anim_data, #main_sprite.frames)
        if added > 0 then
            anim_count = anim_count + 1
        end
    end
    
    -- Recortar sprite si sobraron frames vacíos al inicio (limpieza)
    if #main_sprite.frames > 1 then
        local first_cel = main_sprite.layers[1]:cel(1)
        if not first_cel or first_cel.image:isEmpty() then
             -- Si el frame 1 quedó vacío y sin uso, se podría borrar, 
             -- pero el script ya intenta reutilizarlo.
        end
    end

    app.alert("Proceso finalizado.\nAnimaciones importadas: " .. anim_count)
    return main_sprite
end

-- ENTRY POINT
local function main()
    -- Si se pasa argumento por CLI (opcional)
    local json_arg = app.params["json"]
    
    if json_arg then
        build_animations_from_json(json_arg)
    else
        local dlg = Dialog("Importador JSON")
        dlg:file{ id="json", label="Metadata JSON", open=true, filetypes={"json"} }
        dlg:button{ text="Importar", onclick=function()
            local f = dlg.data.json
            if f and f ~= "" then
                build_animations_from_json(f)
                dlg:close()
            else
                app.alert("Selecciona un archivo.")
            end
        end }
        dlg:show()
    end
end

main()
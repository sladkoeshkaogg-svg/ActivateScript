local url = "https://raw.githubusercontent.com/sladkoeshkaogg-svg/TestGGOGScript/main/GGOG.lua"

local s, res = pcall(function() 
    return game:HttpGet(url) 
end)

if s and res then
    local func, err = loadstring(res)
    if func then
        func()
    else
        warn("Ошибка синтаксиса в Main.lua: " .. err)
    end
else
    warn("Ошибка загрузки: проверь интернет или ссылку")
end

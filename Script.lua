local url = "https://raw.githubusercontent.com/sladkoeshkaogg-svg/-/main/GGOG.lua"

local request = (syn and syn.request) or (http and http.request) or http_request or request

if request then
    local response = request({
        Url = url,
        Method = "GET"
    })
    if response and response.Body then
        loadstring(response.Body)()
    else
        warn("Не удалось получить скрипт")
    end
else
    -- fallback
    loadstring(game:HttpGet(url))()
end

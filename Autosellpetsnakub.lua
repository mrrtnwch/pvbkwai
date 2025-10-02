local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")


-- Глобальная конфигурация через getgenv()
if not getgenv().AutoPetSellerConfig then
    getgenv().AutoPetSellerConfig = {
    MIN_WEIGHT_TO_KEEP = 300, -- Минимальный вес для сохранения пета
    MAX_WEIGHT_TO_KEEP = 50000, -- Максимальный вес для сохранения пета
    SELL_DELAY = 0.01, -- Задержка между продажами
    BUY_DELAY = 0.01, -- Задержка между покупками
    BUY_INTERVAL = 2, -- Интервал между циклами покупки (секунды)
    COLLECT_INTERVAL = 60, -- Интервал сбора монет (секунды)
    REPLACE_INTERVAL = 30, -- Интервал замены брейнротов (секунды)
    PLANT_INTERVAL = 10, -- Интервал посадки растений (секунды)
    WATER_INTERVAL = 5, -- Интервал полива растений (секунды)
    LOG_COPY_KEY = Enum.KeyCode.F4, -- Клавиша для копирования логов
    AUTO_BUY_SEEDS = true, -- Авто-покупка семян
    AUTO_BUY_GEAR = true, -- Авто-покупка предметов
    AUTO_COLLECT_COINS = true, -- Авто-сбор монет
    AUTO_REPLACE_BRAINROTS = true, -- Авто-замена брейнротов
    AUTO_PLANT_SEEDS = true, -- Авто-посадка семян
    AUTO_WATER_PLANTS = true, -- Авто-полив растений
    AUTO_BUY_PLATFORMS = true, -- Авто-покупка платформ
    PLATFORM_BUY_INTERVAL = 30, -- Интервал проверки покупки платформ (секунды)
    AUTO_BUY_ROWS = true, -- Авто-покупка рядов
    ROW_BUY_INTERVAL = 45, -- Интервал проверки покупки рядов (секунды)
    SMART_PLANTING = true, -- Умная система посадки растений
    MAX_PLANTS_PER_CYCLE = 10, -- Максимальное количество растений за цикл
    PLANTING_RETRY_ATTEMPTS = 3, -- Количество попыток посадки
    DEBUG_COLLECT_COINS = true, -- Отладочные сообщения для сбора монет
    DEBUG_PLANTING = true, -- Отладочные сообщения для посадки
    SMART_SELLING = true, -- Умная система продажи (адаптивная
    AUTO_REEXECUTE = true, -- Авто-перезапуск при реджойне
    ANTI_AFK = true, -- Анти-АФК система
    ANTI_AFK_INTERVAL = 30, -- Интервал анти-АФК действий (секунды)
    DISABLE_KICKSERVICE = true, -- Отключить kickservice
}
end

-- Создаем локальную ссылку для удобства
local CONFIG = getgenv().AutoPetSellerConfig

-- Редкости петов в порядке возрастания
local RARITY_ORDER = {
    ["Rare"] = 1,
    ["Epic"] = 2,
    ["Legendary"] = 3,
    ["Mythic"] = 4,
    ["Godly"] = 5,
    ["Secret"] = 6,
    ["Limited"] = 7
}

-- Переменные
local logs = {}
local itemSellRemote = nil
local useItemRemote = nil
local openEggRemote = nil
local playerData = nil
local protectedPet = nil -- Защищенный от продажи пет (в руке для замены
local petAnalysis = nil -- Анализ текущего состояния петов
local currentPlot = nil -- Текущий плот игрока
local plantedSeeds = {} -- Отслеживание посаженных семян
local diagnosticsRun = false -- Флаг для запуска диагностики
local scriptStartTime = tick() -- Время запуска скрипта
local lastActivityTime = tick() -- Время последней активности
local isRejoining = false -- Флаг реджойна

-- Централизованное логирование ошибок
local function logError(functionName, errorMessage, additionalInfo)
    local timestamp = os.date("%H:%M:%S")
    local logMessage = string.format("[%s] ОШИБКА в %s: %s", timestamp, functionName, tostring(errorMessage))
    if additionalInfo then
        logMessage = logMessage .. " | Доп.инфо: " .. tostring(additionalInfo)
    end
    warn(logMessage)
    
    -- Сохраняем в лог
    table.insert(logs, {
        timestamp = os.time(),
        action = "ERROR",
        function_name = functionName,
        error_message = errorMessage,
        additional_info = additionalInfo
    })
end

-- Коды для ввода
local CODES = {
    "based",
    "stacks",
    "frozen"
}

-- Семена для покупки
local SEEDS = {
    "Cactus Seed",
    "Strawberry Seed", 
    "Sunflower Seed",
    "Pumpkin Seed",
    "Dragon Fruit Seed",
    "Eggplant Seed",
    "Watermelon Seed",
    "Grape Seed",
    "Cocotank Seed",
    "Carnivorous Plant Seed",
    "Mr Carrot Seed",
    "Tomatrio Seed",
    "Shroombino Seed"
}

-- Предметы из Gear Shop
local GEAR_ITEMS = {
    "Water Bucket",
    "Frost Blower",
    "Frost Grenade",
    "Carrot Launcher",
    "Banana Gun"
}

-- Защищенные предметы (не продавать
local PROTECTED_ITEMS = {
    "Meme Lucky Egg",
    "Godly Lucky Egg",
    "Secret Lucky Egg"
}

-- Отключение kickservice
local function disableKickService()
    if not CONFIG.DISABLE_KICKSERVICE then
        return
    end
    
    local success, error = pcall(function()
        -- Отключаем kickservice
        if game:GetService("Players").LocalPlayer.Character then
            local humanoid = game:GetService("Players").LocalPlayer.Character:FindFirstChild("Humanoid")
            if humanoid then
                -- Устанавливаем максимальное время бездействия
                humanoid.MaxHealth = 100
                humanoid.Health = 100
            end
        end
        
        -- Отключаем автоматический кик за бездействие
        game:GetService("Players").LocalPlayer.Idled:Connect(function()
            -- Ничего не делаем - это предотвращает кик
        end)
        
        -- Дополнительная защита от кика
        local function preventKick()
            local character = game:GetService("Players").LocalPlayer.Character
            if character then
                local humanoid = character:FindFirstChild("Humanoid")
                if humanoid then
                    -- Устанавливаем максимальное здоровье
                    humanoid.MaxHealth = 100
                    humanoid.Health = 100
                    
                    -- Предотвращаем смерть
                    humanoid.Died:Connect(function()
                        -- Ничего не делаем - это предотвращает кик при смерти
                    end)
                end
            end
        end
        
        -- Вызываем функцию предотвращения кика
        preventKick()
        
        -- Повторяем каждые 30 секунд
        spawn(function()
            while true do
                wait(30)
                preventKick()
            end
        end)
        
    end)
    
    if not success then
        logError("disableKickService", error, "Не удалось отключить kickservice")
    end
end

-- Анти-АФК система (улучшенная версия)
local function performAntiAFK()
    if not CONFIG.ANTI_AFK then
        return
    end
    
    local success, error = pcall(function()
        -- Используем VirtualUser для надёжной защиты от кика
        local VirtualUser = game:GetService("VirtualUser")
        
        -- Захватываем контроллер и симулируем клик
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
        
        lastActivityTime = tick()
    end)
    
    if not success then
        logError("performAntiAFK", error, "Ошибка анти-АФК системы")
    end
end

-- Инициализация анти-АФК системы
local function initializeAntiAFK()
    if not CONFIG.ANTI_AFK then
        return
    end
    
    local success, error = pcall(function()
        -- Подключаем обработчик Idled для автоматической защиты
        LocalPlayer.Idled:Connect(function()
            if CONFIG.ANTI_AFK then
                local VirtualUser = game:GetService("VirtualUser")
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end
        end)
    end)
    
    if not success then
        logError("initializeAntiAFK", error, "Ошибка инициализации анти-АФК")
    end
end

-- Сохранение состояния скрипта
local function saveScriptState()
    local success, error = pcall(function()
        -- Сохраняем конфигурацию в глобальную переменную
        getgenv().AutoPetSellerConfig = CONFIG
        getgenv().AutoPetSellerState = {
            scriptStartTime = scriptStartTime,
            lastActivityTime = lastActivityTime,
            isRejoining = isRejoining
        }
    end)
    
    if not success then
        logError("saveScriptState", error, "Ошибка сохранения состояния скрипта")
    end
end

-- Проверка на реджойн
local function checkForRejoin()
    if not CONFIG.AUTO_REEXECUTE then
        return
    end
    
    local success, error = pcall(function()
        -- Проверяем, изменился ли игрок (реджойн)
        local currentPlayer = game:GetService("Players").LocalPlayer
        if currentPlayer.UserId ~= LocalPlayer.UserId then
            isRejoining = true
            
            -- Сохраняем состояние
            saveScriptState()
            
            -- Ждем немного и перезапускаем
            wait(2)
            loadstring(game:HttpGet("https://raw.githubusercontent.com/fornamess/dfsjdfgrj/refs/heads/main/arbuz.lua"))()
        end
    end)
    
    if not success then
        logError("checkForRejoin", error, "Ошибка проверки реджойна")
    end
end

-- Инициализация
local function initialize()
    -- Восстанавливаем состояние если есть
    if getgenv().AutoPetSellerState then
        local state = getgenv().AutoPetSellerState
        scriptStartTime = state.scriptStartTime or tick()
        lastActivityTime = state.lastActivityTime or tick()
        isRejoining = state.isRejoining or false
    end
    
    -- Ждем необходимые сервисы
    itemSellRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ItemSell")
    useItemRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UseItem")
    openEggRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("OpenEgg")
    
    -- Отключаем kickservice
    disableKickService()
    
    -- Инициализируем анти-АФК систему
    initializeAntiAFK()
    
    -- Инициализируем PlayerData
    local success, result = pcall(function()
        playerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
    end)
    if not success then
        playerData = nil
    end
    
    -- Получаем текущий плот
    local plotNumber = LocalPlayer:GetAttribute("Plot")
    if plotNumber then
        currentPlot = workspace.Plots:FindFirstChild(tostring(plotNumber))
        end
end

-- Получение веса пета из названия
local function getPetWeight(petName)
    local weight = petName:match("%[(%d+%.?%d*)%s*kg%]")
    return weight and tonumber(weight) or 0
end

-- Получение редкости пета
local function getPetRarity(pet)
    local petData = pet:FindFirstChild(pet.Name)
    if not petData then
        -- Пробуем найти по имени без веса и мутаций
        local cleanName = pet.Name:gsub("%[.*%]%s*", "")
        petData = pet:FindFirstChild(cleanName)
    end
    
    if not petData then
        -- Ищем любой дочерний объект с атрибутом Rarity
        for _, child in pairs(pet:GetChildren()) do
            if child:GetAttribute("Rarity") then
                petData = child
                break
            end
        end
    end
    
    if petData then
        return petData:GetAttribute("Rarity") or "Rare"
    end
    
    return "Rare"
end

-- Проверка защищенных мутаций
local function hasProtectedMutations(petName)
    return petName:find("%[Neon%]") or petName:find("%[Galactic%]")
end

-- Проверка защищенных предметов
local function isProtectedItem(itemName)
    for _, protected in pairs(PROTECTED_ITEMS) do
        if itemName:find(protected) then
            return true
        end
    end
    return false
end

-- Получение информации о пете
local function getPetInfo(pet)
    local petData = pet:FindFirstChild(pet.Name)
    if not petData then
        local cleanName = pet.Name:gsub("%[.*%]%s*", "")
        petData = pet:FindFirstChild(cleanName)
    end
    
    if not petData then
        for _, child in pairs(pet:GetChildren()) do
            if child:GetAttribute("Rarity") then
                petData = child
                break
            end
        end
    end
    
    -- Получаем MoneyPerSecond из UI
    local moneyPerSecond = 0
    if petData then
        local rootPart = petData:FindFirstChild("RootPart")
        if rootPart then
            local brainrotToolUI = rootPart:FindFirstChild("BrainrotToolUI")
            if brainrotToolUI then
                local moneyLabel = brainrotToolUI:FindFirstChild("Money")
                if moneyLabel then
                    -- Парсим MoneyPerSecond из текста типа "$1,234/s"
                    local moneyText = moneyLabel.Text
                    local moneyValue = moneyText:match("%$(%d+,?%d*)/s")
                    if moneyValue then
                        -- Убираем запятые и конвертируем в число
                        local cleanValue = moneyValue:gsub(",", "")
                        moneyPerSecond = tonumber(cleanValue) or 0
                    end
                end
            end
        end
    end
    
    if petData then
        return {
            name = pet.Name,
            weight = getPetWeight(pet.Name),
            rarity = petData:GetAttribute("Rarity") or "Rare",
            worth = petData:GetAttribute("Worth") or 0,
            size = petData:GetAttribute("Size") or 1,
            offset = petData:GetAttribute("Offset") or 0,
            moneyPerSecond = moneyPerSecond
        }
    end
    
    return {
        name = pet.Name,
        weight = getPetWeight(pet.Name),
        rarity = "Rare",
        worth = 0,
        size = 1,
        offset = 0,
        moneyPerSecond = moneyPerSecond
    }
end

-- Получение лучшего брейнрота из инвентаря (для проверки)
local function getBestBrainrotForReplacement()
    local backpack = LocalPlayer:WaitForChild("Backpack")
    local bestBrainrot = nil
    local bestMoneyPerSecond = 0
    
    for _, pet in pairs(backpack:GetChildren()) do
        if pet:IsA("Tool") and pet.Name:match("%[%d+%.?%d*%s*kg%]") then
            local petInfo = getPetInfo(pet)
            local moneyPerSecond = petInfo.moneyPerSecond
            
            if moneyPerSecond > bestMoneyPerSecond then
                bestMoneyPerSecond = moneyPerSecond
                bestBrainrot = pet
            end
        end
    end
    
    return bestBrainrot, bestMoneyPerSecond
end

-- Анализ текущего состояния петов
local function analyzePets()
    local backpack = LocalPlayer:WaitForChild("Backpack")
    local analysis = {
        totalPets = 0,
        petsByRarity = {},
        petsByMoneyPerSecond = {},
        bestMoneyPerSecond = 0,
        worstMoneyPerSecond = math.huge,
        averageMoneyPerSecond = 0,
        totalMoneyPerSecond = 0,
        shouldSellRare = false,
        shouldSellEpic = false,
        shouldSellLegendary = false,
        minMoneyPerSecondToKeep = 0
    }
    
    -- Собираем данные о всех петах
    for _, pet in pairs(backpack:GetChildren()) do
        if pet:IsA("Tool") and pet.Name:match("%[%d+%.?%d*%s*kg%]") then
            local petInfo = getPetInfo(pet)
            local rarity = petInfo.rarity
            local moneyPerSecond = petInfo.moneyPerSecond
            
            analysis.totalPets = analysis.totalPets + 1
            analysis.totalMoneyPerSecond = analysis.totalMoneyPerSecond + moneyPerSecond
            
            -- Группируем по редкости
            if not analysis.petsByRarity[rarity] then
                analysis.petsByRarity[rarity] = 0
            end
            analysis.petsByRarity[rarity] = analysis.petsByRarity[rarity] + 1
            
            -- Отслеживаем лучший и худший MoneyPerSecond
            if moneyPerSecond > analysis.bestMoneyPerSecond then
                analysis.bestMoneyPerSecond = moneyPerSecond
            end
            if moneyPerSecond < analysis.worstMoneyPerSecond then
                analysis.worstMoneyPerSecond = moneyPerSecond
            end
            
            -- Группируем по MoneyPerSecond
            table.insert(analysis.petsByMoneyPerSecond, {
                pet = pet,
                moneyPerSecond = moneyPerSecond,
                rarity = rarity
            })
        end
    end
    
    -- Сортируем по MoneyPerSecond
    table.sort(analysis.petsByMoneyPerSecond, function(a, b)
        return a.moneyPerSecond > b.moneyPerSecond
    end)
    -- Вычисляем средний MoneyPerSecond
    if analysis.totalPets > 0 then
        analysis.averageMoneyPerSecond = analysis.totalMoneyPerSecond / analysis.totalPets
    end
    
    -- Умная логика определения, что продавать
    if analysis.totalPets > 0 then
        -- Если у нас мало петов (меньше 10), продаем только самых плохих
        if analysis.totalPets < 10 then
            analysis.minMoneyPerSecondToKeep = analysis.averageMoneyPerSecond * 0.5 -- Оставляем только лучшие 50%
            analysis.shouldSellRare = false
            analysis.shouldSellEpic = false
            analysis.shouldSellLegendary = false
        -- Если у нас среднее количество петов (10-20), начинаем продавать Rare
        elseif analysis.totalPets < 20 then
            analysis.minMoneyPerSecondToKeep = analysis.averageMoneyPerSecond * 0.7
            analysis.shouldSellRare = true
            analysis.shouldSellEpic = false
            analysis.shouldSellLegendary = false
        -- Если у нас много петов (20+), продаем Rare и Epic
        else
            analysis.minMoneyPerSecondToKeep = analysis.averageMoneyPerSecond * 0.8
            analysis.shouldSellRare = true
            analysis.shouldSellEpic = true
            analysis.shouldSellLegendary = false
        end
        
        -- Дополнительная проверка: если у нас есть очень хорошие петы, можем продавать и Legendary
        if analysis.bestMoneyPerSecond > analysis.averageMoneyPerSecond * 2 then
            analysis.shouldSellLegendary = true
        end
        
        -- Специальная логика для мутаций: если у нас много петов с мутациями, можем продавать плохих
        local mutationPets = 0
        for _, petData in pairs(analysis.petsByMoneyPerSecond) do
            if hasProtectedMutations(petData.pet.Name) then
                mutationPets = mutationPets + 1
            end
        end
        
        -- Если у нас много петов с мутациями (больше 5), можем продавать плохих с мутациями
        if mutationPets > 5 then
            analysis.shouldSellEpic = true -- Разрешаем продавать Epic с мутациями
            if analysis.totalPets > 25 then
                analysis.shouldSellLegendary = true -- И Legendary тоже
            end
        end
    end
    
    return analysis
end

-- Определение, нужно ли продавать пета (умная система)
local function shouldSellPet(pet)
    local petName = pet.Name
    local weight = getPetWeight(petName)
    local rarity = getPetRarity(pet)
    local rarityValue = RARITY_ORDER[rarity] or 0
    local petInfo = getPetInfo(pet)
    -- Не продаем защищенного пета (который в руке для замены
    if protectedPet and pet == protectedPet then
        return false
    end
    
    -- Не продаем защищенные предметы
    if isProtectedItem(petName) then
        return false
    end
    
    -- Не продаем тяжелых петов
    if weight >= CONFIG.MIN_WEIGHT_TO_KEEP then
        return false
    end
    
    -- Не продаем высоких редкостей (Mythic и выше
    if rarityValue > RARITY_ORDER["Legendary"] then
        return false
    end
    
    -- Если умная система отключена, используем старую логику
    if not CONFIG.SMART_SELLING then
        -- Старая логика: не продаем Legendary с мутациями и брейнротов с высоким MoneyPerSecond
        if rarity == "Legendary" and hasProtectedMutations(petName) then
            return false
        end
        if petInfo.moneyPerSecond > 100 then
            return false
        end
        return true
    end
    
    -- Умная система: используем анализ петов
    if not petAnalysis then
        petAnalysis = analyzePets()
    end
    
    -- Проверяем по MoneyPerSecond
    if petInfo.moneyPerSecond >= petAnalysis.minMoneyPerSecondToKeep then
        return false
    end
    
    -- Проверяем по редкости (только если анализ говорит, что можно продавать эту редкость
    if rarity == "Rare" and not petAnalysis.shouldSellRare then
        return false
    elseif rarity == "Epic" and not petAnalysis.shouldSellEpic then
        return false
    elseif rarity == "Legendary" and not petAnalysis.shouldSellLegendary then
        return false
    end
    
    -- В умной системе НЕ защищаем мутации автоматически - пусть анализ решает
    -- Только если это очень редкие мутации (Neon/Galactic), тогда защищаем
    if hasProtectedMutations(petName) and (rarity == "Mythic" or rarity == "Godly" or rarity == "Secret") then
        return false
    end
    
    return true
end

-- Продажа пета
local function sellPet(pet)
    local character = LocalPlayer.Character
    if not character then return false end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return false end
    
    -- Берем пета в руку перед продажей
    humanoid:EquipTool(pet)
    wait(0.1) -- Ждем пока пет возьмется в руку
    
    -- Продаем пета
    itemSellRemote:FireServer(pet)
    return true
end

-- Авто-продажа петов
local function autoSellPets()
    local success, error = pcall(function()
        local backpack = LocalPlayer:WaitForChild("Backpack")
        local soldCount = 0
        local keptCount = 0
        
        -- Обновляем анализ петов перед продажей
        petAnalysis = analyzePets()
        
        -- Показываем информацию об анализе
        if CONFIG.SMART_SELLING and petAnalysis.totalPets > 0 then
            -- Считаем петов с мутациями
            local mutationPets = 0
            for _, petData in pairs(petAnalysis.petsByMoneyPerSecond) do
                if hasProtectedMutations(petData.pet.Name) then
                    mutationPets = mutationPets + 1
                end
            end
        end
        
        -- Защита лучших брейнротов больше не нужна, так как используется EquipBestBrainrots
        
        for _, pet in pairs(backpack:GetChildren()) do
            if pet:IsA("Tool") and pet.Name:match("%[%d+%.?%d*%s*kg%]") then
                if shouldSellPet(pet) then
                    local petInfo = getPetInfo(pet)
                    local sellSuccess = sellPet(pet)
                    if sellSuccess then
                        soldCount = soldCount + 1
                        
                        local reason = "Продано: " .. petInfo.rarity .. " (вес: " .. petInfo.weight .. "kg)"
                        if CONFIG.SMART_SELLING then
                            reason = reason .. " [MoneyPerSecond: " .. petInfo.moneyPerSecond .. "/s]"
                        end
                    else
                    end
                    
                    wait(CONFIG.SELL_DELAY)
                else
                    local petInfo = getPetInfo(pet)
                    local reason = "Сохранен: "
                    
                    -- Проверяем, является ли это полезным брейнротом
                    if petInfo.moneyPerSecond >= petAnalysis.minMoneyPerSecondToKeep then
                        reason = reason .. "высокий MoneyPerSecond (" .. petInfo.moneyPerSecond .. "/s)"
                    elseif petInfo.weight >= CONFIG.MIN_WEIGHT_TO_KEEP then
                        reason = reason .. "тяжелый (" .. petInfo.weight .. "kg)"
                    elseif RARITY_ORDER[petInfo.rarity] > RARITY_ORDER["Legendary"] then
                        reason = reason .. "высокая редкость (" .. petInfo.rarity .. ")"
                    elseif petInfo.rarity == "Legendary" and hasProtectedMutations(pet.Name) then
                        reason = reason .. "защищенные мутации"
                    else
                        reason = reason .. "защищенный предмет"
                    end
                    
                    keptCount = keptCount + 1
                end
            end
        end
        
        -- Снимаем защиту после продажи
        protectedPet = nil
        
        if soldCount > 0 or keptCount > 0 then
        end
    end)
    if not success then
        -- Ошибка
    end
end

-- Ввод кодов (чистый API)
local function redeemCodes()
    local success, error = pcall(function()
        local redeemedCount = 0
        
    for _, code in pairs(CODES) do
            local redeemSuccess, redeemError = pcall(function()
                local args = {code}
                game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("ClaimCode"):FireServer(unpack(args))
            end)
            if redeemSuccess then
                redeemedCount = redeemedCount + 1
            end
            
            wait()
    end
        
        if redeemedCount > 0 then
            -- Коды введены
        end
    end)
    if not success then
        -- Ошибка
    end
end

-- Автоматическое открытие яиц (ручной метод
local function autoOpenEggs()
    local success, error = pcall(function()
        local backpack = LocalPlayer:WaitForChild("Backpack")
        local openedCount = 0
        
        for _, item in pairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                for _, eggName in pairs(PROTECTED_ITEMS) do
                    if item.Name:find(eggName) then
                        local openSuccess, openError = pcall(function()
                        local args = {eggName}
                        openEggRemote:FireServer(unpack(args))
                        end)
                        if openSuccess then
                            openedCount = openedCount + 1
                        end
                        
                        wait()
                        break
                    end
                end
            end
        end
        
        if openedCount > 0 then
            -- Яйца открыты
        end
    end)
    if not success then
        -- Ошибка
    end
end

-- Проверка стока семян (ручной метод)
local function checkSeedStock(seedName)
    local success, result = pcall(function()
    local seedsGui = PlayerGui:FindFirstChild("Main")
    if not seedsGui then return false, 0 end
    
    local seedsFrame = seedsGui:FindFirstChild("Seeds")
    if not seedsFrame then return false, 0 end
    
    local scrollingFrame = seedsFrame:FindFirstChild("Frame"):FindFirstChild("ScrollingFrame")
    if not scrollingFrame then return false, 0 end
    
    local seedFrame = scrollingFrame:FindFirstChild(seedName)
    if not seedFrame then return false, 0 end
    
    local stockLabel = seedFrame:FindFirstChild("Stock")
    if not stockLabel then return false, 0 end
    
    local stockText = stockLabel.Text
    local stockCount = tonumber(stockText:match("x(%d+)")) or 0
    
    return stockCount > 0, stockCount
    end)
    if success then
        return result
    else
        return false, 0
    end
end

-- Авто-покупка семян (чистый API)
local function autoBuySeeds()
    local success, error = pcall(function()
        if not CONFIG.AUTO_BUY_SEEDS then
            return
        end
        
        local boughtCount = 0
        
        for _, seedName in pairs(SEEDS) do
            local hasStock, stockCount = checkSeedStock(seedName)
            if hasStock then
                -- Чистая покупка через BuyItem
                local buySuccess, buyError = pcall(function()
                    local args = {seedName}
                    game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("BuyItem"):FireServer(unpack(args))
                end)
                if buySuccess then
                    boughtCount = boughtCount + 1
                end
                
                wait()
            end
        end
        
        if boughtCount > 0 then
            -- Семена куплены
        end
    end)
    if not success then
        -- Ошибка
    end
end

-- Проверка стока предметов (ручной метод)
local function checkGearStock(gearName)
    local success, result = pcall(function()
    local gearsGui = PlayerGui:FindFirstChild("Main")
    if not gearsGui then return false, 0 end
    
    local gearsFrame = gearsGui:FindFirstChild("Gears")
    if not gearsFrame then return false, 0 end
    
    local scrollingFrame = gearsFrame:FindFirstChild("Frame"):FindFirstChild("ScrollingFrame")
    if not scrollingFrame then return false, 0 end
    
    local gearFrame = scrollingFrame:FindFirstChild(gearName)
    if not gearFrame then return false, 0 end
    
    local stockLabel = gearFrame:FindFirstChild("Stock")
    if not stockLabel then return false, 0 end
    
    local stockText = stockLabel.Text
    local stockCount = tonumber(stockText:match("x(%d+)")) or 0
    
    return stockCount > 0, stockCount
    end)
    if success then
        return result
    else
        return false, 0
    end
end

-- Проверка, все ли ряды куплены
local function areAllRowsBought()
    local currentPlot = nil
    for _, plot in workspace.Plots:GetChildren() do
        if plot:GetAttribute("Owner") == game.Players.LocalPlayer.Name then
            currentPlot = plot
            break
        end
    end
    
    if not currentPlot then
        return false
    end
    
    -- Получаем цены на ряды из Library
    local library = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Library"):WaitForChild("General"))
    local rowPrices = library.RowPrices
    
    if not rowPrices then
        return false
    end
    
    -- Проверяем каждый ряд в плоту
    for _, row in currentPlot.Rows:GetChildren() do
        local rowNumber = tonumber(row.Name)
        if rowNumber and not row:GetAttribute("Enabled") then
            -- Есть некупленный ряд
            return false
        end
    end
    
    return true -- Все ряды куплены
end

-- Авто-покупка предметов (только после покупки всех рядов)
local function autoBuyGear()
    local success, error = pcall(function()
        if not CONFIG.AUTO_BUY_GEAR then
            return
        end
        
        -- Проверяем, все ли ряды куплены
        if not areAllRowsBought() then
            return -- Не покупаем gear, пока не куплены все ряды
        end
        
        local boughtCount = 0
        
        for _, gearName in pairs(GEAR_ITEMS) do
            local hasStock, stockCount = checkGearStock(gearName)
            if hasStock then
                -- Чистая покупка через BuyGear
                local buySuccess, buyError = pcall(function()
                    local args = {gearName}
                    game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("BuyGear"):FireServer(unpack(args))
                end)
                if buySuccess then
                    boughtCount = boughtCount + 1
                end
                
                wait()
            end
        end
        
        if boughtCount > 0 then
            -- Предметы куплены
        end
    end)
    if not success then
        -- Ошибка
    end
end

-- Получение HumanoidRootPart
local function getHRP()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return character:WaitForChild("HumanoidRootPart")
end

-- Определение плота игрока
local function resolvePlayerPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    
    local hrp = getHRP()
    local best, bestDist
    
    for _, plot in pairs(plots:GetChildren()) do
        local brainrots = plot:FindFirstChild("Brainrots")
        if brainrots then
            for _, slot in pairs(brainrots:GetChildren()) do
                local center = slot:FindFirstChild("Center") or slot:FindFirstChildWhichIsA("BasePart")
                if center and center:IsA("BasePart") then
                    local distance = (hrp.Position - center.Position).Magnitude
                    if not bestDist or distance < bestDist then
                        best, bestDist = plot, distance
                    end
                end
            end
        end
    end
    
    return best
end

-- Получение текущего плота игрока
local function getCurrentPlot()
    -- Сначала пробуем через атрибут
    local plotNumber = LocalPlayer:GetAttribute("Plot")
    if plotNumber then
        local plot = workspace.Plots:FindFirstChild(tostring(plotNumber))
        if plot then
            return plot
        else
        end
    end
    
    -- Если не получилось через атрибут, используем определение по расстоянию
    local plot = resolvePlayerPlot()
    if plot then
        return plot
    end
    
    return nil
end

-- Получение баланса игрока
local function getPlayerBalance()
    if not playerData then
        -- Альтернативный способ получения баланса
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                local moneyValue = humanoid:FindFirstChild("Money")
                if moneyValue then
                    local balance = moneyValue.Value
                    return balance
                end
            end
        end
        return 0
    end
    
    local success, balance = pcall(function()
        return playerData.get("Money") or 0
    end)
    if success then
        return balance
    else
        -- Альтернативный способ получения баланса
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                local moneyValue = humanoid:FindFirstChild("Money")
                if moneyValue then
                    local balance = moneyValue.Value
                    return balance
                end
            end
        end
        return 0
    end
end

-- Безопасное получение числа из строки
local function tonumber_safe(x)
    if type(x) == "number" then return x end
    if type(x) ~= "string" then return nil end
    local s = x:gsub("[^%d-]", "")
    return s == "" and nil or tonumber(s)
end

-- Объединенная функция: сбор монет и замена брейнротов на лучших
local function autoCollectCoinsAndReplaceBrainrots()
    local success, error = pcall(function()
        if not CONFIG.AUTO_COLLECT_COINS and not CONFIG.AUTO_REPLACE_BRAINROTS then
            return
        end
        
        -- Используем встроенную функцию игры для сбора монет и замены брейнротов
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("EquipBestBrainrots"):FireServer()
        
        -- Логируем действие
    end)
    if not success then
        -- Ошибка
    end
end


-- Авто-покупка платформ
local function autoBuyPlatforms()
    local success, error = pcall(function()
        if not CONFIG.AUTO_BUY_PLATFORMS then
            return
        end
        
        -- Получаем данные игрока
        local playerData = require(game:GetService("ReplicatedStorage"):WaitForChild("PlayerData")):GetData()
        local currentMoney = playerData.Data.Money
        
        if not currentMoney or currentMoney <= 0 then
            return
        end
        
        -- Получаем цены на платформы из Library
        local library = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Library"):WaitForChild("General"))
        local platformPrices = library.PlatformPrices
        
        if not platformPrices then
            return
        end
        local platformsBought = 0
        
        -- Проверяем каждую платформу
        for platformId, price in pairs(platformPrices) do
            if type(platformId) == "number" and type(price) == "number" then
                if currentMoney >= price then
                    -- Покупаем платформу
                    local args = {tostring(platformId)}
                    game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("BuyPlatform"):FireServer(unpack(args))
                    
                    platformsBought = platformsBought + 1
                    currentMoney = currentMoney - price
                    
                    -- Небольшая задержка между покупками
                    wait()
                end
            end
        end
        
        if platformsBought > 0 then
            -- Платформы куплены
        else
            -- Нет доступных платформ для покупки
        end
        
    end)
    if not success then
        -- Ошибка
    end
end

-- Авто-покупка рядов
local function autoBuyRows()
    local success, error = pcall(function()
        if not CONFIG.AUTO_BUY_ROWS then
            return
        end
        
        -- Получаем данные игрока
        local playerData = require(game:GetService("ReplicatedStorage"):WaitForChild("PlayerData")):GetData()
        local currentMoney = playerData.Data.Money
        
        if not currentMoney or currentMoney <= 0 then
            return
        end
        
        -- Получаем цены на ряды из Library
        local library = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Library"):WaitForChild("General"))
        local rowPrices = library.RowPrices
        
        if not rowPrices then
            return
        end
        
        -- Получаем текущий плот игрока
        local currentPlot = nil
        for _, plot in workspace.Plots:GetChildren() do
            if plot:GetAttribute("Owner") == game.Players.LocalPlayer.Name then
                currentPlot = plot
                break
            end
        end
        
        if not currentPlot then
            return
        end
        local rowsBought = 0
        
        -- Проверяем каждый ряд в плоту
        for _, row in currentPlot.Rows:GetChildren() do
            local rowNumber = tonumber(row.Name)
            if rowNumber and rowPrices[rowNumber] then
                local price = rowPrices[rowNumber]
                
                -- Проверяем, не куплен ли уже ряд
                if not row:GetAttribute("Enabled") and currentMoney >= price then
                    -- Покупаем ряд
                    local args = {rowNumber}
                    game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("BuyRow"):FireServer(unpack(args))
                    rowsBought = rowsBought + 1
                    currentMoney = currentMoney - price
                    
                    -- Небольшая задержка между покупками
                    wait()
                end
            end
        end
        
        if rowsBought > 0 then
            -- Ряды куплены
        else
            -- Нет доступных рядов для покупки
        end
        
    end)
    if not success then
        -- Ошибка
    end
end

-- Получение первого BasePart из объекта
local function firstPart(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        if inst.PrimaryPart then return inst.PrimaryPart end
        local p = inst:FindFirstChildWhichIsA("BasePart", true)
        if p then return p end
    end
    return nil
end

-- Получение базовой части ячейки
local function getBase(cell)
    if not cell then return nil end
    if cell:IsA("BasePart") then return cell end
    for _,n in ipairs({ "Hitbox","HitBox","Floor","Tile","Pad","Base","GrassPart","Part" }) do
        local p = cell:FindFirstChild(n) or cell:FindFirstChild(n, true)
        if p and p:IsA("BasePart") then return p end
    end
    return firstPart(cell)
end

-- Сортировка по числовым именам
local function numericSort(children)
    table.sort(children, function(a,b)
        local na, nb = tonumber(a.Name), tonumber(b.Name)
        if na and nb then return na < nb end
        if na and not nb then return true end
        if nb and not na then return false end
        return a.Name < b.Name
    end)
end

-- Получение количества в стеке
local NUM_KEYS = { "Count","count","Amount","amount","Stack","stack","Quantity","quantity","Uses","uses","Left","left" }

local function numberField(tool)
    local ok, attrs = pcall(function() return tool:GetAttributes() end)
    if ok and attrs then
        for _,k in ipairs(NUM_KEYS) do
            if type(attrs[k])=="number" then return {kind="attr", key=k} end
        end
    end
    for _,d in ipairs(tool:GetDescendants()) do
        if d:IsA("IntValue") or d:IsA("NumberValue") then
            local nm = (d.Name or ""):lower()
            if nm=="count" or nm=="amount" or nm=="stack" or nm=="quantity" or nm=="uses" or nm=="left" then
                return {kind="vo", ref=d}
            end
        end
    end
end

local function stackCount(tool)
    local ref = numberField(tool)
    if not ref then return 1 end
    if ref.kind=="attr" then return math.max(0, math.floor(tool:GetAttribute(ref.key))) end
    return math.max(0, math.floor(ref.ref.Value))
end

-- Проверка, можно ли использовать инструмент
local function stillUsable(tool)
    if not tool then
        logError("stillUsable", "tool = nil", "Попытка проверить nil инструмент")
        return false
    end
    
    if not tool.Parent then
        logError("stillUsable", "tool.Parent = nil", "Инструмент: " .. tool.Name)
        return false
    end
    
    if not tool:IsDescendantOf(LocalPlayer) then
        logError("stillUsable", "tool не принадлежит игроку", "Инструмент: " .. tool.Name)
        return false
    end
    
    local count = stackCount(tool)
    if count <= 0 then
        logError("stillUsable", "stackCount = " .. count, "Инструмент: " .. tool.Name)
        return false
    end
    
    return true
end

-- Взятие инструмента в руку
local function ensureHolding(tool)
    if not (tool and tool:IsA("Tool")) then 
        logError("ensureHolding", "tool не является Tool", "tool = " .. tostring(tool))
        return false 
    end
    
    local character = LocalPlayer.Character
    if not character then 
        logError("ensureHolding", "персонаж не найден", "Инструмент: " .. tool.Name)
        return false 
    end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then 
        logError("ensureHolding", "Humanoid не найден", "Инструмент: " .. tool.Name)
        return false 
    end
    
    if tool.Parent == character then 
        return true 
    end
    
    humanoid:UnequipTools()
    wait()
    
    local ok = pcall(function() humanoid:EquipTool(tool) end)
    if not ok then 
        logError("ensureHolding", "не удалось взять инструмент", "Инструмент: " .. tool.Name)
        return false 
    end
    
    for i=1,25 do 
        if tool.Parent==character then 
            return true 
        end 
        RunService.Heartbeat:Wait() 
    end
    
    logError("ensureHolding", "таймаут взятия инструмента", "Инструмент: " .. tool.Name)
    return false
end

-- Получение отображаемого имени семени
local function seedDisplayName(tool)
    local plantAttr = tool.GetAttribute and tool:GetAttribute("Plant")
    if typeof(plantAttr)=="Instance" then return plantAttr.Name end
    if type(plantAttr)=="string" and #plantAttr>0 then return plantAttr end
    local name = tool.Name or ""
    return (name:gsub("[%[%]]",""):gsub("%s*[Ss]eed%s*",""):gsub("%s+$",""))
end

-- Получение UID инструмента
local function uidOf(tool)
    if not (tool and tool.GetAttribute) then return nil end
    for _,k in ipairs({ "UID","Uid","uuid","Uuid","Id","ID" }) do
        local v = tool:GetAttribute(k)
        if v ~= nil then return v end
    end
end


local SEED_PRIORITY = {
    -- ЛУЧШИЕ (приоритет 1) - снизу
    ["Shroombino"] = 1,
    ["Tomatrio"] = 1,
    ["Mr Carrot"] = 1,
    ["Carnivorous Plant"] = 1,
    ["Cocotank"] = 1,
    
    -- ХОРОШИЕ (приоритет 2
    ["Grape"] = 2,
    ["Watermelon"] = 2,
    ["Eggplant"] = 2,
    ["Dragon Fruit"] = 2,
    
    -- СРЕДНИЕ (приоритет 3
    ["Pumpkin"] = 3,
    ["Sunflower"] = 3,
    
    -- ПЛОХИЕ (приоритет 4
    ["Strawberry"] = 4,
    
    -- ХУДШИЕ (приоритет 5) - сверху
    ["Cactus"] = 5
}

-- Группировка семян по имени с приоритетом
local function groupSeedsByName()
    local success, result = pcall(function()
        local backpack = LocalPlayer:WaitForChild("Backpack")
        local groups = {}
        
        for _,t in ipairs(backpack:GetChildren()) do
            if t:IsA("Tool") then
                if t.Name:lower():find("seed") then
                    local nm = seedDisplayName(t)
                    if nm=="" then nm="Unknown" end
                    
                    if not groups[nm] then 
                        groups[nm] = {
                            name = nm, 
                            items = {},
                            priority = SEED_PRIORITY[nm] or 999
                        }
                    end
                    table.insert(groups[nm].items, t)
                end
            end
        end
        
        -- Сортируем группы по приоритету (от лучших к худшим)
        local sortedGroups = {}
        for _, group in pairs(groups) do
            table.insert(sortedGroups, group)
        end
        
        table.sort(sortedGroups, function(a, b)
            return a.priority < b.priority
        end)
        
        return sortedGroups
    end)
    
    if not success then
        logError("groupSeedsByName", result, "Ошибка группировки семян")
        return {}
    end
    
    return result
end

-- Обновление списка используемых предметов
local function refreshUsable(items)
    local out = {}
    for _,t in ipairs(items) do 
        if stillUsable(t) then 
            table.insert(out, t) 
        end 
    end
    return out
end

-- Взятие лопаты в руку
local function equipShovel()
    local success, error = pcall(function()
        local shovel = LocalPlayer.Backpack:FindFirstChild("Shovel") or LocalPlayer.Character:FindFirstChild("Shovel")
        if shovel and not LocalPlayer.Character:FindFirstChild("Shovel") then
            local character = LocalPlayer.Character
            if character then
                local humanoid = character:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid:EquipTool(shovel)
                    wait()
                    return true
                end
            end
        elseif shovel then
            return true
        else
            return false
        end
    end)
    if not success then
        return false
    end
end

-- Поиск корня плота
local function findPlotsRoot()
    return workspace:FindFirstChild("Plots")
end

-- Выбор моего плота (использует правильную логику определения)
local function pickMyPlot(plots)
    -- Сначала пробуем через атрибут
    local plotNumber = LocalPlayer:GetAttribute("Plot")
    if plotNumber then
        local plot = plots:FindFirstChild(tostring(plotNumber))
        if plot then
            return plot
        else
            -- Плот не найден по номеру
        end
    end
    
    -- Если не получилось через атрибут, используем определение по расстоянию
    local hrp = getHRP()
    local best, bestDist
    
    for _, plot in pairs(plots:GetChildren()) do
        local brainrots = plot:FindFirstChild("Brainrots")
        if brainrots then
            for _, slot in pairs(brainrots:GetChildren()) do
                local center = slot:FindFirstChild("Center") or slot:FindFirstChildWhichIsA("BasePart")
                if center and center:IsA("BasePart") then
                    local distance = (hrp.Position - center.Position).Magnitude
                    if not bestDist or distance < bestDist then
                        best, bestDist = plot, distance
                    end
                end
            end
        end
    end
    
    if best then
        -- Плот найден по расстоянию
    else
        -- Плот не найден
    end
    
    return best
end

-- Поиск Lawn Mower в ряду
local function findRowMower(row)
    local mower = row:FindFirstChild("Lawn Mower")
    if mower then
        return firstPart(mower)
    end
        return nil
    end
    
-- Получение первой ячейки ряда (улучшенная версия с Lawn Mower)
local function slot1CellOfRow(row)
    local grass = row:FindFirstChild("Grass")
    if not grass then return nil end
    
    -- Сначала пробуем найти Lawn Mower для точного определения первой ячейки
    local mowerPart = findRowMower(row)
    if mowerPart then
        local cells = grass:GetChildren()
        if #cells == 0 then return nil end

        -- Сортируем ячейки по расстоянию от Lawn Mower
        table.sort(cells, function(a,b)
            local pa, pb = getBase(a), getBase(b)
            if not pa or not pb then return tostring(a.Name) < tostring(b.Name) end
            local da = (pa.Position - mowerPart.Position).Magnitude
            local db = (pb.Position - mowerPart.Position).Magnitude
            return da < db
        end)
        return cells[1]
    end
    
    -- Если Lawn Mower не найден, используем старый метод
    local spawn = row:FindFirstChild("MowerSpawn")
    local refPos
    if spawn and spawn:IsA("BasePart") then
        refPos = spawn.Position
    else
        local kids = grass:GetChildren()
        numericSort(kids)
        return kids[1]
    end
    
    local best, bestDist
    for _,cell in ipairs(grass:GetChildren()) do
        local base = getBase(cell)
        if base then
            local d = (base.Position - refPos).Magnitude
            if not bestDist or d < bestDist then 
                bestDist, best = d, cell 
            end
        end
    end
    return best
end

-- Получение номера ряда из ячейки
local function getRowNumberFromCell(cell)
    local parent = cell.Parent
    while parent do
        if parent.Name:match("^%d+$") then
            return tonumber(parent.Name)
        end
        parent = parent.Parent
    end
        return nil
    end
    
-- Получение папки растений
local function plantsFolder(plot)
	return plot:FindFirstChild("Plants")
end

-- Ключи для поиска ID растений
local ID_KEYS = { "ID","Id","Uid","UID","PlantID","PlantId" }

-- Получение ID из растения
local function getAnyIDFromInstance(inst)
    if inst and inst.GetAttribute ~= nil then
        for _,k in ipairs(ID_KEYS) do
            local v = inst:GetAttribute(k)
            if v ~= nil then return v end
            end
        end
    return nil
    end
    
-- Получение растений в состоянии Countdown
local function getCountdownPlants()
    local countdownPlants = {}
    
    local success, error = pcall(function()
        local scriptedMap = workspace:FindFirstChild("ScriptedMap")
        if scriptedMap then
            local countdowns = scriptedMap:FindFirstChild("Countdowns")
            if countdowns then
                for _, countdown in pairs(countdowns:GetChildren()) do
                    if countdown:IsA("Model") then
                        local plantName = countdown:GetAttribute("PlantName") or countdown.Name
                        if plantName then
                            table.insert(countdownPlants, {
                                model = countdown,
                                name = plantName,
                                id = countdown.Name
                            })
                        end
                    end
                end
            end
        end
    end)
    if not success then
        -- Ошибка
    end
    
    return countdownPlants
end

-- Определение ряда растения по его позиции
local function getPlantRowByPosition(plot, plantPosition)
    local rows = plot:FindFirstChild("Rows")
    if not rows then return nil end
    
    local rKids = rows:GetChildren()
    numericSort(rKids)
    for _, row in ipairs(rKids) do
        local grass = row:FindFirstChild("Grass")
        if grass then
            local cells = grass:GetChildren()
            for _, cell in ipairs(cells) do
                local base = getBase(cell)
                if base then
                    local distance = (plantPosition - base.Position).Magnitude
                    if distance < 3 then -- Если растение близко к ячейке
                        return tonumber(row.Name)
                    end
                end
            end
        end
    end
    
        return nil
    end
    
-- Подсчет растений в ряду (включая ростки) - исправленная версия с использованием атрибута Row
local function countPlantsInRow(plot, rowNumber)
    local count = 0
    
    -- Считаем выросшие растения по атрибуту Row
    local plants = plantsFolder(plot)
    if plants then
        for _, plant in pairs(plants:GetChildren()) do
            if plant:IsA("Model") then
                local plantRow = plant:GetAttribute("Row")
                if plantRow and tonumber(plantRow) == rowNumber then
                        count = count + 1
                end
            end
        end
    end
    
    -- Считаем ростки (растения в состоянии Countdown) по атрибуту Row
    local countdownPlants = getCountdownPlants()
    for _, countdownPlant in ipairs(countdownPlants) do
        if countdownPlant.model then
            local plantRow = countdownPlant.model:GetAttribute("Row")
            if plantRow and tonumber(plantRow) == rowNumber then
                    count = count + 1
            end
        end
    end
    
    return count
end

-- Получение всех первых ячеек с информацией о рядах
local function listAllSlot1(plot)
    local rows = plot:FindFirstChild("Rows")
    if not rows then return {} end
    local out = {}
    local rKids = rows:GetChildren()
    if #rKids == 0 then return out end
    numericSort(rKids)
    for _,row in ipairs(rKids) do
        local c = slot1CellOfRow(row)
        if c then 
            local rowNumber = tonumber(row.Name)
            local plantCount = countPlantsInRow(plot, rowNumber)
            table.insert(out, {
                cell = c,
                row = rowNumber,
                plantCount = plantCount
                            })
                        end
                    end
    return out
end

-- Получение всех доступных ячеек в рядах (не только первых)
local function getAllAvailableCells(plot)
    local rows = plot:FindFirstChild("Rows")
    if not rows then return {} end
    
    local availableCells = {}
    local rKids = rows:GetChildren()
    if #rKids == 0 then return availableCells end
    numericSort(rKids)
    for _, row in ipairs(rKids) do
        local rowNumber = tonumber(row.Name)
        -- ПРОВЕРЯЕМ: ряд должен быть доступен (Enabled = true) И не заполнен (меньше 5 растений)
        if rowNumber and row:GetAttribute("Enabled") then
        local plantCount = countPlantsInRow(plot, rowNumber)
        -- Если в ряду меньше 5 растений, добавляем все ячейки этого ряда
        if plantCount and plantCount < 5 then
            local grass = row:FindFirstChild("Grass")
            if grass then
                local cells = grass:GetChildren()
                            -- Сортируем ячейки по позиции (к началу ряда)
                            table.sort(cells, function(a, b)
                                return a.Position.Z < b.Position.Z
                            end)
                            
                for _, cell in ipairs(cells) do
                                -- Проверяем, не занята ли ячейка
                                local isOccupied = false
                                local plants = plot:FindFirstChild("Plants")
                                if plants then
                                    for _, plant in pairs(plants:GetChildren()) do
                                        if plant:IsA("Model") and plant:GetAttribute("Floor") == cell then
                                            isOccupied = true
                                            break
                                        end
                                    end
                                end
                                
                                if not isOccupied then
                    table.insert(availableCells, {
                        cell = cell,
                        row = rowNumber,
                        plantCount = plantCount
                    })
                                end
                            end
                end
            end
        end
    end
    
    return availableCells
end

-- Удаление растения по ID
local function removePlantByID(plantID, plantName, reason)
    local success, error = pcall(function()
        local args = {tostring(plantID)}
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("RemoveItem"):FireServer(unpack(args))
        return true
    end)
    if success then
        return true
    else
        return false
    end
end

-- Получение всех растений в ряду (включая Countdown)
local function getPlantsInRow(plot, rowNumber)
    local plants = plantsFolder(plot)
    local rowPlants = {}
    
    -- Сначала добавляем выросшие растения
    if plants then
        for _, plant in pairs(plants:GetChildren()) do
            if plant:IsA("Model") then
                local row = plant:GetAttribute("Row")
                if row and tostring(row) == tostring(rowNumber) then
                    table.insert(rowPlants, plant)
                end
            end
    end
end

    -- Затем добавляем растения в состоянии Countdown
    local countdownPlants = getCountdownPlants()
    for _, countdownPlant in ipairs(countdownPlants) do
        if countdownPlant.row == tostring(rowNumber) then
            -- Создаем временный объект для подсчета
            local tempPlant = {
                Name = countdownPlant.name,
                GetAttribute = function(self, attr)
                    if attr == "Row" then return tonumber(countdownPlant.row) end
        return nil
                end
            }
            table.insert(rowPlants, tempPlant)
        end
    end
    
    return rowPlants
end

-- Перемещение растений в начало ряда
local function movePlantsToRowStart(plot, rowNumber)
    local success, error = pcall(function()
        local rowPlants = getPlantsInRow(plot, rowNumber)
        local plantCount = #rowPlants
        
        if plantCount == 0 then
            return true
        end
        
        if plantCount > 5 then
            -- Сортируем растения по приоритету (худшие сначала)
            table.sort(rowPlants, function(a, b)
                local priorityA = SEED_PRIORITY[a.Name] or 0
                local priorityB = SEED_PRIORITY[b.Name] or 0
                return priorityA < priorityB
            end)
            -- Удаляем лишние растения (оставляем только 5 лучших)
            local toRemove = plantCount - 5
            for i = 1, toRemove do
                local plant = rowPlants[i]
                local plantID = getAnyIDFromInstance(plant)
                if plantID then
                    removePlantByID(plantID, plant.Name, "Избыточное растение в ряду " .. rowNumber .. " (было " .. plantCount .. "/5)")
                    wait()
                end
            end
            
            wait(2) -- Ждем пока растения исчезнут
            rowPlants = getPlantsInRow(plot, rowNumber) -- Обновляем список
            plantCount = #rowPlants
        end
        
        if plantCount == 0 then
            return true
        end
        
        -- Получаем первую ячейку ряда
        local rows = plot:FindFirstChild("Rows")
        if not rows then return false end
        
        local row = rows:FindFirstChild(tostring(rowNumber))
        if not row then return false end
        
        local firstCell = slot1CellOfRow(row)
        if not firstCell then
        return false
    end
    
        local firstCellBase = getBase(firstCell)
        if not firstCellBase then
        return false
    end
    
        -- Перемещаем каждое растение в начало ряда
        for i, plant in ipairs(rowPlants) do
            local plantID = getAnyIDFromInstance(plant)
            if plantID then
                -- Удаляем растение с текущего места
                if removePlantByID(plantID) then
                    wait()
                    -- Создаем новое растение в начале ряда
                    local newPlantID = game:GetService("HttpService"):GenerateGUID(false)
                    local payload = {
                        ID = newPlantID,
                        CFrame = firstCellBase.CFrame,
                        Item = plant.Name,
                        Floor = firstCell,
                    }
                    local args = {payload}
                    game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("PlaceItem"):FireServer(unpack(args))
                    
                    wait()
                else
                    -- Ошибка удаления растения
                end
        end
    end
    
        return true
    end)
    if not success then
        return false
    end
end

-- Поиск худшего растения для удаления
local function findWorstPlantForRemoval(plot)
    local plants = plantsFolder(plot)
    if not plants then return nil end
    
    local worstPlant = nil
    local worstPriority = math.huge
    
    for _, plant in pairs(plants:GetChildren()) do
        if plant:IsA("Model") then
            local plantName = plant.Name
            local priority = SEED_PRIORITY[plantName] or 0
            
            -- Ищем растение с самым низким приоритетом
            if priority < worstPriority then
                worstPriority = priority
            worstPlant = plant
            end
        end
    end
    
    return worstPlant
end

-- Поиск худшего растения в конкретном ряду
local function findWorstPlantInRow(plot, rowNumber)
    local worstPlant = nil
    local worstPriority = math.huge
    
    -- Проверяем выросшие растения по атрибуту Row
    local plants = plantsFolder(plot)
    if plants then
        for _, plant in pairs(plants:GetChildren()) do
            if plant:IsA("Model") then
                local plantRow = plant:GetAttribute("Row")
                if plantRow and tonumber(plantRow) == rowNumber then
                        local plantName = plant.Name
                        local priority = SEED_PRIORITY[plantName] or 999
                        
                        if priority < worstPriority then
                            worstPriority = priority
                            worstPlant = {
                                id = getAnyIDFromInstance(plant),
                                name = plantName,
                                priority = priority,
                                model = plant
                            }
                    end
                end
            end
        end
    end
    
    -- Проверяем ростки по атрибуту Row
    local countdownPlants = getCountdownPlants()
    for _, countdownPlant in ipairs(countdownPlants) do
        if countdownPlant.model then
            local plantRow = countdownPlant.model:GetAttribute("Row")
            if plantRow and tonumber(plantRow) == rowNumber then
                    local plantName = countdownPlant.name
                    local priority = SEED_PRIORITY[plantName] or 999
                    
                    if priority < worstPriority then
                        worstPriority = priority
                        worstPlant = {
                            id = countdownPlant.id,
                            name = plantName,
                            priority = priority,
                            model = countdownPlant.model
                        }
                end
            end
        end
    end
    
    return worstPlant
end

-- Удаление худших растений для освобождения места
local function removeWorstPlants(plot, count)
    local removedCount = 0
    local plants = plantsFolder(plot)
    if not plants then return 0 end
    
    -- Собираем все растения с их приоритетами
    local plantsToRemove = {}
    for _, plant in pairs(plants:GetChildren()) do
        if plant:IsA("Model") then
            local plantName = plant.Name
            local priority = SEED_PRIORITY[plantName] or 0
            local plantID = getAnyIDFromInstance(plant)
            if plantID then
                table.insert(plantsToRemove, {
                    plant = plant,
                    name = plantName,
                    priority = priority,
                    id = plantID
                })
            end
        end
    end
    
    -- Сортируем по приоритету (худшие сначала)
    table.sort(plantsToRemove, function(a, b)
        return a.priority < b.priority
    end)
    for i, plantData in ipairs(plantsToRemove) do
        if i <= 5 then -- Показываем только первые 5
            -- Логируем растение для удаления
    end
end

    -- Удаляем худшие растения
    for i = 1, math.min(count, #plantsToRemove) do
        local plantData = plantsToRemove[i]
        
        if removePlantByID(plantData.id, plantData.name, "Удаление худшего растения (приоритет " .. plantData.priority .. ")") then
            removedCount = removedCount + 1
            wait(0.5) -- Пауза между удалениями
        else
            -- Ошибка удаления растения
        end
    end
    
    if removedCount > 0 then
        wait(2) -- Ждем пока растения исчезнут
    else
        -- Нет растений для удаления
    end
    
    return removedCount
end

-- Подсчет растений в каждом ряду (включая Countdown)
local function countPlantsInRows(plot)
    local plants = plantsFolder(plot)
    local rowCounts = {}
    local totalPlants = 0
    local countdownPlants = 0
    
    -- Считаем выросшие растения по атрибуту Row
    if plants then
        for _, plant in pairs(plants:GetChildren()) do
            if plant:IsA("Model") then
                local row = plant:GetAttribute("Row")
                if row then
                    local rowNum = tostring(row)
                    if not rowCounts[rowNum] then
                        rowCounts[rowNum] = 0
                    end
                    rowCounts[rowNum] = rowCounts[rowNum] + 1
                    totalPlants = totalPlants + 1
                end
            end
        end
    end
    
    -- Считаем растения в состоянии Countdown по атрибуту Row
    local countdownPlantsList = getCountdownPlants()
    for _, countdownPlant in ipairs(countdownPlantsList) do
        if countdownPlant.model then
            local row = countdownPlant.model:GetAttribute("Row")
            if row then
                local rowNum = tostring(row)
        if not rowCounts[rowNum] then
            rowCounts[rowNum] = 0
        end
        rowCounts[rowNum] = rowCounts[rowNum] + 1
        totalPlants = totalPlants + 1
        countdownPlants = countdownPlants + 1
            end
        end
    end
    
    -- Добавляем общее количество растений
    rowCounts["TOTAL"] = totalPlants
    rowCounts["COUNTDOWN"] = countdownPlants
    
    return rowCounts
end

-- Получение всех ячеек с учетом ограничений по количеству растений
local function listAvailableCells(plot, maxPlantsPerRow)
    local rows = plot:FindFirstChild("Rows")
    if not rows then return {} end
    
    local rowCounts = countPlantsInRows(plot)
    local availableCells = {}
    local rKids = rows:GetChildren()
    
    if #rKids == 0 then return availableCells end
    numericSort(rKids)
    for _, row in ipairs(rKids) do
        local rowNum = row.Name
        local currentCount = rowCounts[rowNum] or 0
        local maxCount = maxPlantsPerRow or 5
        
        -- Если в ряду меньше максимального количества растений, добавляем ячейки
        if currentCount < maxCount then
            local cell = slot1CellOfRow(row)
            if cell then
                table.insert(availableCells, {
                    cell = cell,
                    row = rowNum,
                    currentCount = currentCount,
                    maxCount = maxCount
                })
            else
                -- Ячейка не найдена
            end
        else
            -- Ряд заполнен
                    end
                end
    
    return availableCells
end

-- Проверка, появилось ли растение рядом
local function spawnedNear(plot, base, timeout)
    local success, result = pcall(function()
        local pf = plantsFolder(plot)
        if not pf then 
            return true 
        end
        
        local t0 = tick()
        while tick()-t0 < (timeout or 1.0) do
            -- Проверяем папку Plants
            for _,m in ipairs(pf:GetChildren()) do
                if m:IsA("Model") then
                    local p = firstPart(m)
                    if p and (p.Position - base.Position).Magnitude < 4 then
                        return true
                    end
                end
            end
            
            -- Проверяем папку Countdowns (ростки)
            local scriptedMap = workspace:FindFirstChild("ScriptedMap")
            if scriptedMap then
                local countdowns = scriptedMap:FindFirstChild("Countdowns")
                if countdowns then
                    for _, countdown in pairs(countdowns:GetChildren()) do
                        if countdown:IsA("Model") then
                            local p = firstPart(countdown)
                            if p and (p.Position - base.Position).Magnitude < 4 then
                                return true
                            end
                        end
                    end
                end
            end
            
            RunService.Heartbeat:Wait()
        end
        
        return false
    end)
    
    if not success then
        logError("spawnedNear", result, "Ошибка проверки появления растения")
        return false
    end
    
    return result
end

-- Перемещение на ячейку
local function stepOnto(base)
    local character = LocalPlayer.Character
    if not character then return false end
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return false end
    
    local target = base.Position + Vector3.new(0, 2.6, 0)
    humanoidRootPart.CFrame = CFrame.new(target)
    for i=1,5 do 
        RunService.Heartbeat:Wait() 
    end
    return true
end

-- Тестирование первых ячеек в каждом ряду
local function testSlot1Cells()
    local success, error = pcall(function()
        -- Используем правильное определение плота
        local myPlot = getCurrentPlot()
        if not myPlot then 
            return 
        end
        
        -- Проверяем растения в Countdown
        local countdownPlants = getCountdownPlants()
        if #countdownPlants > 0 then
            for _, plant in ipairs(countdownPlants) do
                -- Логируем растение в Countdown
            end
        else
            -- Нет растений в Countdown
        end
        
        local rows = myPlot:FindFirstChild("Rows")
        if not rows then 
            return 
        end
        
        local rKids = rows:GetChildren()
        numericSort(rKids)
        for _, row in ipairs(rKids) do
            local mowerPart = findRowMower(row)
            if mowerPart then
                local firstCell = slot1CellOfRow(row)
                if firstCell then
                    local base = getBase(firstCell)
                    if base then
                        -- Логируем расстояние до Lawn Mower
                        
                        -- Телепортируемся к ячейке для проверки
                        stepOnto(base)
                        wait()
                    else
                        -- Базовая часть не найдена
            end
        else
                    -- Первая ячейка не найдена
                end
            else
                local firstCell = slot1CellOfRow(row)
                if firstCell then
                    local base = getBase(firstCell)
                    if base then
                        stepOnto(base)
                        wait()
                    end
                end
            end
        end
        
    end)
    if not success then
        -- Ошибка
    end
end

-- Посадка на ячейку (чистый API)
local function plantOnCell(plot, cell, tool)
    local success, result = pcall(function()
        -- Проверяем лимит растений перед посадкой
        local totalPlants = 0
        local plants = plantsFolder(plot)
        if plants then
            for _, plant in pairs(plants:GetChildren()) do
                if plant:IsA("Model") then
                    totalPlants = totalPlants + 1
                end
            end
        end
        
        local countdownPlants = getCountdownPlants()
        totalPlants = totalPlants + #countdownPlants
        
        -- Если достигнут лимит (35 растений), не сажаем
        if totalPlants >= 35 then
            return false -- Лимит достигнут
        end
        
        local base = getBase(cell)
        if not base then 
            logError("plantOnCell", "не найдена базовая часть ячейки", "Ячейка: " .. tostring(cell))
            return false 
        end
        
        if not ensureHolding(tool) then 
            logError("plantOnCell", "не удалось взять инструмент в руку", "Инструмент: " .. (tool and tool.Name or "nil"))
            return false 
        end
        
        stepOnto(base)
        local seedName = seedDisplayName(tool)
        local stackCount = stackCount(tool)
        local rowNumber = getRowNumberFromCell(cell)
        
        local payload = {
            ID      = uidOf(tool) or game:GetService("HttpService"):GenerateGUID(false),
            CFrame  = base.CFrame,
            Item    = seedName,
            Floor   = cell,
        }
        local args = {payload}
        
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("PlaceItem"):FireServer(unpack(args))
        
        if spawnedNear(plot, base, 0.9) then 
            return true 
        end
        
        -- Повторная попытка
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("PlaceItem"):FireServer(unpack(args))
        local success = spawnedNear(plot, base, 0.9)
        if not success then
            logError("plantOnCell", "посадка не удалась после двух попыток", "Семя: " .. seedName .. ", Ряд: " .. (rowNumber or "неизвестный"))
        end
        
        return success
    end)
    
    if not success then
        logError("plantOnCell", result, "Общая ошибка посадки")
        return false
    end
    
    return result
end

-- Полив растения
local function waterPlant(plantPosition)
    local character = LocalPlayer.Character
    if not character then
        return false
    end
    
    -- Ищем Water Bucket в инвентаре
    local waterBucket = nil
    for _, tool in pairs(character:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:match("Water Bucket") then
            waterBucket = tool
            break
        end
    end
    
    if not waterBucket then
        -- Ищем в рюкзаке
        local backpack = LocalPlayer:WaitForChild("Backpack")
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:match("Water Bucket") then
                waterBucket = tool
                break
            end
        end
    end
    
    if not waterBucket then
        return false
    end
    
    -- Берем ведро в руку
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid:EquipTool(waterBucket)
        wait()
    end
    
    -- Поливаем растение
    local args = {
        {
            Toggle = true,
            Tool = waterBucket,
            Pos = plantPosition
        }
    }
    useItemRemote:FireServer(unpack(args))
    
    if CONFIG.DEBUG_PLANTING then
        -- Логируем полив растения
    end
    
    return true
end

-- Умная система размещения растений с проверкой коллизий
local function smartPlantPlacement(plot, seedName, maxAttempts)
    maxAttempts = maxAttempts or 3

    local success, error = pcall(function()
        local rows = plot:FindFirstChild("Rows")
        if not rows then
            return false
        end
        
        -- Ищем лучшую доступную ячейку
        local bestCell = nil
        local bestScore = -1
        local availableRows = 0
        local totalRows = 0
        
        for _, row in pairs(rows:GetChildren()) do
            totalRows = totalRows + 1
            local rowNumber = tonumber(row.Name)
            -- ПРОВЕРЯЕМ: ряд должен быть доступен (Enabled = true) И не заполнен (меньше 5 растений)
            if rowNumber and row:GetAttribute("Enabled") then
                availableRows = availableRows + 1
                local plantsInRow = countPlantsInRow(plot, rowNumber)
                if plantsInRow and plantsInRow < 5 then -- Максимум 5 растений в ряду
                    local grass = row:FindFirstChild("Grass")
                    if grass then
                        local cells = grass:GetChildren()
                        -- Сортируем ячейки по позиции (к началу ряда)
                        table.sort(cells, function(a, b)
                            return a.Position.Z < b.Position.Z
                        end)
                        
                        for _, cell in ipairs(cells) do
                            if cell:IsA("BasePart") and cell:GetAttribute("CanPlace") then
                                -- Проверяем, не занята ли ячейка
                                local isOccupied = false
                                local plants = plot:FindFirstChild("Plants")
                                if plants then
                                    for _, plant in pairs(plants:GetChildren()) do
                                        if plant:IsA("Model") and plant:GetAttribute("Floor") == cell then
                                            isOccupied = true
                                            break
                                        end
                                    end
                                end
                                
                                if not isOccupied then
                                    -- Вычисляем "оценку" ячейки
                                    local score = 0
                                    
                                    -- Предпочитаем ячейки в начале рядов (по Z-координате)
                                    local cellPosition = cell.Position
                                    score = score + (1000 - cellPosition.Z) -- Меньше Z = выше оценка (к началу ряда)
                                    
                                    -- Предпочитаем ряды с меньшим количеством растений
                                    score = score + (5 - plantsInRow) * 10
                                    
                                    -- Предпочитаем более низкие номера рядов
                                    score = score + (10 - rowNumber)
                                    if score > bestScore then
                                        bestScore = score
                                        bestCell = {
                                            cell = cell,
                                            row = rowNumber,
                                            score = score
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        if not bestCell then
            if availableRows == 0 then
                -- Нет доступных рядов
            else
                -- Нет доступных ячеек
            end
            return false
        end
        -- Находим семя в инвентаре
        local seedTool = nil
        for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:find("Seed") then
                local toolSeedName = tool.Name:gsub(" Seed", "")
                if toolSeedName == seedName then
                    seedTool = tool
                    break
                end
            end
        end
        
        if not seedTool then
            return false
        end
        
        -- Пытаемся посадить растение
        for attempt = 1, maxAttempts do
            local plantID = game:GetService("HttpService"):GenerateGUID(false)
            local placeData = {
                ID = plantID,
                CFrame = bestCell.cell.CFrame,
                Item = seedName,
                Floor = bestCell.cell
            }
            
            -- Отправляем запрос на посадку
            local args = {placeData}
            game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("PlaceItem"):FireServer(unpack(args))
            
            -- Проверяем, успешно ли посадили
            wait(0.2) -- Даем время на обработку
            
            local plants = plot:FindFirstChild("Plants")
            if plants then
                for _, plant in pairs(plants:GetChildren()) do
                    if plant:IsA("Model") and plant:GetAttribute("Floor") == bestCell.cell then
                        -- Логируем посадку
                        return true
            end
        end
            end
            
            if attempt < maxAttempts then
                wait()
            end
        end
        
        return false
        
    end)
    if not success then
        return false
    end
    
    return false
end

-- Улучшенная авто-посадка семян с использованием PlaceItem RemoteEvent
local function autoPlantSeeds()
    local success, error = pcall(function()
        if not CONFIG.AUTO_PLANT_SEEDS then
            return
        end
        
        -- Получаем текущий плот игрока
        local myPlot = getCurrentPlot()
        if not myPlot then 
            return
        end
        
        -- Получаем доступные семена из инвентаря
        local availableSeeds = {}
        for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:find("Seed") then
                local seedName = tool.Name:gsub(" Seed", "")
                local stackCount = stackCount(tool)
                if stackCount > 0 then
                    table.insert(availableSeeds, {
                        tool = tool,
                        name = seedName,
                        count = stackCount,
                        priority = SEED_PRIORITY[seedName] or 0
                    })
                end
            end
        end
        
        if #availableSeeds == 0 then
            return
        end
        
        -- Сортируем семена по приоритету (лучшие сначала - меньшее число = лучше)
        table.sort(availableSeeds, function(a, b)
            return a.priority < b.priority
        end)
        for i, seed in ipairs(availableSeeds) do
            -- Логируем доступное семя
        end
        
        -- Получаем статистику по растениям
        local rowCounts = countPlantsInRows(myPlot)
        local totalPlants = rowCounts["TOTAL"] or 0
        local maxPlants = 35 -- Максимальное количество растений
        
        -- Проверяем лимит растений
        if totalPlants >= maxPlants then
            return
        end
        
        -- Находим доступные ячейки для посадки
        local availableCells = {}
        local rows = myPlot:FindFirstChild("Rows")
        local availableRows = 0
        local totalRows = 0
        
        if rows then
            for _, row in pairs(rows:GetChildren()) do
                totalRows = totalRows + 1
                local rowNumber = tonumber(row.Name)
                -- ПРОВЕРЯЕМ: ряд должен быть доступен (Enabled = true) И не заполнен (меньше 5 растений)
                if rowNumber and row:GetAttribute("Enabled") then
                    availableRows = availableRows + 1
                    local plantsInRow = countPlantsInRow(myPlot, rowNumber)
                    if plantsInRow and plantsInRow < 5 then -- Максимум 5 растений в ряду
                        local grass = row:FindFirstChild("Grass")
                        if grass then
                            for _, cell in pairs(grass:GetChildren()) do
                                if cell:IsA("BasePart") and cell:GetAttribute("CanPlace") then
                                    -- Проверяем, не занята ли ячейка
                                    local isOccupied = false
                                    local plants = myPlot:FindFirstChild("Plants")
                                    if plants then
                                        for _, plant in pairs(plants:GetChildren()) do
                                            if plant:IsA("Model") and plant:GetAttribute("Floor") == cell then
                                                isOccupied = true
                                                break
                                            end
                                        end
                                    end
                                    
                                    if not isOccupied then
                                        table.insert(availableCells, {
                                            cell = cell,
                                            row = rowNumber,
                                            position = cell.Position
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        if #availableCells == 0 then
            if availableRows == 0 then
                -- Нет доступных рядов
            else
                -- Нет доступных ячеек
            end
            return
        end
        
        -- Сортируем ячейки по рядам для лучшего распределения (к началу рядов)
        table.sort(availableCells, function(a, b)
            if a.row == b.row then
                return a.position.Z < b.position.Z -- По позиции в ряду (к началу)
            end
            return a.row < b.row -- По номеру ряда
        end)
        local planted = 0
        local maxPlantings = math.min(CONFIG.MAX_PLANTS_PER_CYCLE, #availableCells, #availableSeeds)
        -- Используем умную систему посадки если включена
        if CONFIG.SMART_PLANTING then
            for i = 1, maxPlantings do
                local seed = availableSeeds[1] -- Берем лучшее семя
                
                if not seed or seed.count <= 0 then
                    break
                end
                
                -- Используем умную систему размещения
                local success = smartPlantPlacement(myPlot, seed.name, CONFIG.PLANTING_RETRY_ATTEMPTS)
                if success then
                    planted = planted + 1
                    
                    -- Обновляем счетчик семян
                    seed.count = seed.count - 1
                    if seed.count <= 0 then
                        table.remove(availableSeeds, 1)
                    end
                else
                    -- Переходим к следующему типу семени
                    table.remove(availableSeeds, 1)
                end
                
                -- Небольшая задержка между посадками
                wait()
            end
        else
            -- Обычная система посадки
            for i = 1, maxPlantings do
                local cell = availableCells[i]
                local seed = availableSeeds[1] -- Берем лучшее семя
                
                if not seed or seed.count <= 0 then
                    break
                end
                
                -- Создаем уникальный ID для растения
                local plantID = game:GetService("HttpService"):GenerateGUID(false)
                -- Подготавливаем данные для PlaceItem
                local placeData = {
                    ID = plantID,
                    CFrame = cell.cell.CFrame,
                    Item = seed.name,
                    Floor = cell.cell
                }
                
                -- Отправляем запрос на посадку
                local args = {placeData}
                game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("PlaceItem"):FireServer(unpack(args))
                
                planted = planted + 1
                -- Обновляем счетчик семян
                seed.count = seed.count - 1
                if seed.count <= 0 then
                    table.remove(availableSeeds, 1)
                end
                
                -- Логируем посадку
                -- Небольшая задержка между посадками
                wait()
            end
        end
        
        if planted > 0 then
            -- Логируем количество посаженных растений
        else
            -- Нет растений для посадки
        end
        
    end)
    if not success then
        -- Ошибка
    end
end

-- Авто-полив растений
local function autoWaterPlants()
    local success, error = pcall(function()
        if not CONFIG.AUTO_WATER_PLANTS then
            return
        end
        
        if not currentPlot then
            currentPlot = getCurrentPlot()
            if not currentPlot then
                return
            end
        end
        
        local plants = currentPlot:FindFirstChild("Plants")
        if not plants then
            return
        end
        
        local wateredCount = 0
        
        -- Поливаем только недавно посаженные растения
        for plantId, seedData in pairs(plantedSeeds) do
            if seedData.needsWatering then
                -- Проверяем, существует ли растение
                local plant = nil
                for _, p in pairs(plants:GetChildren()) do
                    if p:GetAttribute("ID") == plantId then
                        plant = p
                        break
                    end
                end
                
                if plant then
                    -- Получаем позицию растения
                    local hitboxes = currentPlot:FindFirstChild("Hitboxes")
                    if hitboxes then
                        local hitbox = hitboxes:FindFirstChild(plantId)
                        if hitbox then
                            local watered = waterPlant(hitbox.Position)
                            if watered then
                                wateredCount = wateredCount + 1
                                if CONFIG.DEBUG_PLANTING then
                                    -- Логируем полив растения
                                end
                            end
                        end
                    end
                    
                    -- Проверяем, выросло ли растение (через 30 секунд считаем выросшим)
                    if os.time() - seedData.timestamp > 30 then
                        seedData.needsWatering = false
                    end
                else
                    -- Растение не найдено, убираем из списка
                    plantedSeeds[plantId] = nil
                end
            end
        end
        
        if wateredCount > 0 and CONFIG.DEBUG_PLANTING then
            -- Логируем количество политых растений
        end
    end)
    if not success then
        -- Ошибка
    end
end

-- Копирование логов в буфер обмена
local function copyLogsToClipboard()
    if #logs == 0 then
        return
    end
    
    local logText = "=== АВТО ПЕТ СЕЛЛЕР ЛОГИ ===\n\n"
    
    for i, log in pairs(logs) do
        local timeStr = os.date("%H:%M:%S", log.timestamp)
        if log.action == "PLANT_DEBUG" or log.action == "PLATFORM_DEBUG" then
            -- Для отладочных сообщений используем message
            logText = logText .. string.format("[%s] %s: %s\n", 
                timeStr, log.action, log.message or "Нет сообщения")
        else
            -- Для обычных логов используем item и reason
            logText = logText .. string.format("[%s] %s: %s - %s\n", 
                timeStr, log.action, log.item or "Нет предмета", log.reason or "Нет причины")
        end
    end
    
    logText = logText .. "\nВсего записей: " .. #logs
    
    -- Пробуем разные способы копирования
    local success = false
    
    -- Метод 0: Простой setclipboard (самый надежный)
        pcall(function()
            setclipboard(logText)
            success = true
        end)
    -- Метод 1: setclipboard через _G (для эксплойтеров)
    if not success and _G.setclipboard then
        pcall(function()
            _G.setclipboard(logText)
            success = true
        end)
    end
    
    -- Метод 3: game:GetService("TextService") (если доступен)
    if not success then
        pcall(function()
            local TextService = game:GetService("TextService")
            if TextService then
                -- Создаем временный GUI для копирования
                local tempGui = Instance.new("ScreenGui")
                tempGui.Name = "TempClipboard"
                tempGui.Parent = PlayerGui
                
                local textBox = Instance.new("TextBox")
                textBox.Size = UDim2.new(0, 1, 0, 1)
                textBox.Position = UDim2.new(0, -1000, 0, -1000) -- Скрываем за экраном
                textBox.Text = logText
                textBox.Parent = tempGui
                
                -- Выделяем и копируем
                textBox:CaptureFocus()
                wait()
                textBox:SelectAll()
                wait()
                -- Симулируем Ctrl+C
                local userInputService = game:GetService("UserInputService")
                userInputService:InputBegan(Enum.KeyCode.LeftControl, false)
                wait()
                userInputService:InputBegan(Enum.KeyCode.C, false)
                wait()
                userInputService:InputEnded(Enum.KeyCode.C, false)
                wait()
                userInputService:InputEnded(Enum.KeyCode.LeftControl, false)
                wait()
                tempGui:Destroy()
                success = true
            end
        end)
    end
    
    -- Метод 4: TextBox с выделением (видимый)
    if not success then
        pcall(function()
            local tempGui = Instance.new("ScreenGui")
            tempGui.Name = "TempClipboard"
            tempGui.Parent = PlayerGui
            
            local textBox = Instance.new("TextBox")
            textBox.Size = UDim2.new(0, 400, 0, 300)
            textBox.Position = UDim2.new(0.5, -200, 0.5, -150)
            textBox.Text = logText
            textBox.TextWrapped = true
            textBox.TextScaled = true
            textBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
            textBox.BorderSizePixel = 2
            textBox.BorderColor3 = Color3.fromRGB(100, 100, 100)
            textBox.Parent = tempGui
            
            -- Выделяем весь текст
            textBox:CaptureFocus()
            wait()
            textBox:SelectAll()
            wait()
            -- Ждем 3 секунды, чтобы пользователь мог скопировать вручную
            wait(3)
            tempGui:Destroy()
            success = true
        end)
    end
    
    -- Метод 5: Просто выводим в консоль
    if not success then
        print("Не удалось скопировать логи в буфер обмена")
    end
    
end

-- Функция для удаления дублирующихся записей в логах
local function removeDuplicateLogs()
    local uniqueLogs = {}
    local seen = {}
    
    for _, log in ipairs(logs) do
        local key = log.action .. "|" .. (log.item or "") .. "|" .. (log.message or "") .. "|" .. (log.reason or "")
        if not seen[key] then
            seen[key] = true
            table.insert(uniqueLogs, log)
        end
    end
    
    logs = uniqueLogs
end

-- Получение всех растений с их позициями и приоритетами
local function getAllPlantsWithInfo(plot)
    local plantsInfo = {}
    
    -- Собираем выросшие растения по атрибуту Row
    local plants = plantsFolder(plot)
    if plants then
        for _, plant in pairs(plants:GetChildren()) do
            if plant:IsA("Model") then
                local plantRow = plant:GetAttribute("Row")
                    if plantRow then
                        local plantName = plant.Name
                        local priority = SEED_PRIORITY[plantName] or 999
                        local plantID = getAnyIDFromInstance(plant)
                    local plantPart = firstPart(plant)
                        local rowNum = tonumber(plantRow)
                        if rowNum then
                            table.insert(plantsInfo, {
                                id = plantID,
                                name = plantName,
                                priority = priority,
                            row = rowNum,
                            position = plantPart and plantPart.Position or Vector3.new(0, 0, 0),
                                model = plant,
                                isCountdown = false
                            })
                        end
                end
            end
        end
    end
    
    -- Собираем ростки по атрибуту Row
    local countdownPlants = getCountdownPlants()
    for _, countdownPlant in ipairs(countdownPlants) do
        if countdownPlant.model then
            local plantRow = countdownPlant.model:GetAttribute("Row")
                if plantRow then
                    local plantName = countdownPlant.name
                    local priority = SEED_PRIORITY[plantName] or 999
                local plantPart = firstPart(countdownPlant.model)
                    local rowNum = tonumber(plantRow)
                    if rowNum then
                        table.insert(plantsInfo, {
                            id = countdownPlant.id,
                            name = plantName,
                            priority = priority,
                        row = rowNum,
                        position = plantPart and plantPart.Position or Vector3.new(0, 0, 0),
                            model = countdownPlant.model,
                            isCountdown = true
                        })
                    end
            end
        end
    end
    
    return plantsInfo
end

-- Получение статистики по рядам
local function getRowStatistics(plot)
    local plantsInfo = getAllPlantsWithInfo(plot)
    local rowStats = {}
    
    for _, plant in ipairs(plantsInfo) do
        local rowNum = plant.row
        if not rowStats[rowNum] then
            rowStats[rowNum] = {
                total = 0,
                count = 0,  -- Добавляем поле count для совместимости
                grown = 0,
                seedlings = 0,
                plants = {}
            }
        end
        
        rowStats[rowNum].total = rowStats[rowNum].total + 1
        rowStats[rowNum].count = rowStats[rowNum].count + 1  -- Синхронизируем с total
        if plant.isCountdown then
            rowStats[rowNum].seedlings = rowStats[rowNum].seedlings + 1
        else
            rowStats[rowNum].grown = rowStats[rowNum].grown + 1
        end
        
        table.insert(rowStats[rowNum].plants, plant)
    end
    
    return rowStats
end

-- Умное удаление растений
local function smartRemovePlants(plot)
    local rowStats = getRowStatistics(plot)
    local removedCount = 0
    
    -- Сначала удаляем избыточные растения (больше 5 в ряду)
    for rowNum, stats in pairs(rowStats) do
        if stats and stats.total and stats.total > 5 then
            local excessCount = stats.total - 5
            -- Сортируем растения по приоритету (худшие первыми)
            table.sort(stats.plants, function(a, b)
                return a.priority > b.priority
            end)
            for i = 1, excessCount do
                local plant = stats.plants[i]
                if plant and plant.id then
                    if removePlantByID(plant.id, plant.name, "Избыточное растение в ряду " .. rowNum .. " (было " .. stats.total .. "/5)") then
                        removedCount = removedCount + 1
                        task.wait()
                    end
                end
            end
        end
    end
    
    -- НЕ удаляем растения для замены на лучшие семена, чтобы избежать зацикливания
    -- Логика замены будет работать только при посадке новых семян
    
    return removedCount
end

-- Умная посадка растений с равномерным распределением
local function smartPlantSeeds(plot)
    local success, result = pcall(function()
        local plantedCount = 0
        local seedGroups = groupSeedsByName()
        
        -- Проверяем лимит растений перед посадкой
        local totalPlants = 0
        local plants = plantsFolder(plot)
        if plants then
            for _, plant in pairs(plants:GetChildren()) do
                if plant:IsA("Model") then
                    totalPlants = totalPlants + 1
                end
            end
        end
        
        local countdownPlants = getCountdownPlants()
        totalPlants = totalPlants + #countdownPlants
        
        -- Если достигнут лимит (35 растений), не сажаем
        if totalPlants >= 35 then
            return 0 -- Лимит достигнут
        end
        
        -- Проверяем, есть ли семена
        local hasSeeds = false
        for _, group in ipairs(seedGroups) do
            local items = refreshUsable(group.items)
            if #items > 0 then
                hasSeeds = true
                break
            end
        end
        
        if not hasSeeds then
            return 0 -- Нет семян для посадки
        end
    
    -- Сортируем семена по приоритету (лучшие сначала)
    table.sort(seedGroups, function(a, b)
        return (a.priority or 999) < (b.priority or 999)
    end)
    
    -- Получаем статистику по рядам
    local rowStats = {}
    local rows = plot:FindFirstChild("Rows")
    if rows then
        for _, row in pairs(rows:GetChildren()) do
            local rowNumber = tonumber(row.Name)
            -- ПРОВЕРЯЕМ: ряд должен быть доступен (Enabled = true)
            if rowNumber and row:GetAttribute("Enabled") then
                local plantsInRow = countPlantsInRow(plot, rowNumber)
                rowStats[rowNumber] = {
                    count = plantsInRow or 0,
                    available = (plantsInRow or 0) < 5,
                    row = row
                }
            end
        end
    end
    
    -- Сортируем ряды по количеству растений (сначала менее заполненные)
    local sortedRows = {}
        for rowNum, stats in pairs(rowStats) do
        -- Добавляем все ряды (и заполненные, и не заполненные)
        table.insert(sortedRows, {rowNum = rowNum, stats = stats})
    end
    table.sort(sortedRows, function(a, b)
        local countA = (a.stats and a.stats.count) or 0
        local countB = (b.stats and b.stats.count) or 0
        return countA < countB
    end)
    
    -- Сажаем семена равномерно по рядам
    for _, rowData in ipairs(sortedRows) do
        local rowNumber = rowData.rowNum
        local row = rowData.stats.row
        
        -- Проверяем, есть ли еще место в ряду или можно заменить худшие растения
        local currentCount = countPlantsInRow(plot, rowNumber)
        local canPlant = currentCount and currentCount < 5
        local canReplace = false
        
        -- Если ряд заполнен, проверяем, можно ли заменить худшие растения
        if currentCount and currentCount >= 5 then
            local worstPlant = findWorstPlantInRow(plot, rowNumber)
            if worstPlant then
                -- Ищем лучшее доступное семя
                local bestSeed = nil
                local bestSeedPriority = 999
                for _, group in ipairs(seedGroups) do
                    local items = refreshUsable(group.items)
                    if #items > 0 then
                        bestSeed = items[1]
                        bestSeedPriority = group.priority or 999
                        break
                        end
                    end
                
                -- Если есть семя лучше худшего растения, можно заменить
                if bestSeed and worstPlant.priority > bestSeedPriority then
                    canReplace = true
            end
        end
    end
    
        if canPlant or canReplace then
            -- Ищем доступные ячейки в этом ряду (сортируем по позиции - к началу ряда)
            local grass = row:FindFirstChild("Grass")
            if grass then
                local cells = grass:GetChildren()
                -- Сортируем ячейки по позиции (к началу ряда)
                table.sort(cells, function(a, b)
                    return a.Position.Z < b.Position.Z
                end)
                
                for _, cell in ipairs(cells) do
                    if cell:IsA("BasePart") and cell:GetAttribute("CanPlace") then
                        -- Проверяем, не занята ли ячейка
                        local isOccupied = false
                        local plants = plot:FindFirstChild("Plants")
                        if plants then
                            for _, plant in pairs(plants:GetChildren()) do
                                if plant:IsA("Model") and plant:GetAttribute("Floor") == cell then
                                    isOccupied = true
                                    break
                                end
                            end
                        end
                        
                        if not isOccupied then
                            -- Ищем лучшее доступное семя
                            local bestSeed = nil
                            local bestSeedPriority = 999
    for _, group in ipairs(seedGroups) do
        local items = refreshUsable(group.items)
                                if #items > 0 then
                                    bestSeed = items[1]
                                    bestSeedPriority = group.priority or 999
                                    -- Удаляем использованное семя
                                    table.remove(items, 1)
                                    break
                                end
                            end
                            
                            if bestSeed then
                                -- Проверяем, есть ли худшие растения в ряду для замены
                                local worstPlant = findWorstPlantInRow(plot, rowNumber)
                                local shouldReplace = false
                                
                                if worstPlant and worstPlant.priority > bestSeedPriority then
                                    -- Есть худшее растение, которое можно заменить
                                    shouldReplace = true
                                end
                                
                                if shouldReplace then
                                    -- Удаляем худшее растение
                                    if removePlantByID(worstPlant.id, worstPlant.name, "Замена на лучшее семя (приоритет " .. bestSeedPriority .. " > " .. worstPlant.priority .. ")") then
                                        task.wait(0.5) -- Ждем удаления
                                    end
                                end
                                
                                -- Сажаем новое семя
                                print("[SmartPlantSeeds] Попытка посадки " .. bestSeed.Name .. " в ряд " .. rowNumber)
                                if plantOnCell(plot, cell, bestSeed) then
                                    plantedCount = plantedCount + 1
                                    print("[SmartPlantSeeds] Успешно посажено! Всего: " .. plantedCount)
                                    task.wait()
                                    
                                    -- Проверяем, не заполнился ли ряд
                                    currentCount = countPlantsInRow(plot, rowNumber)
                                    if currentCount and currentCount >= 5 then
                                        print("[SmartPlantSeeds] Ряд " .. rowNumber .. " заполнен, переходим к следующему")
                                        break -- Переходим к следующему ряду
                                    end
                                else
                                    print("[SmartPlantSeeds] Ошибка посадки " .. bestSeed.Name)
                                end
                            else
                                -- Нет семян для посадки
                                break
            end
        end
                    end
                end
            end
        end
    end
    
        return plantedCount
    end)
    
    if not success then
        logError("smartPlantSeeds", result, "Ошибка умной посадки семян")
        return 0
    end
    
    return result
end

-- Главная функция умной системы посадки
local function smartPlantingSystem()
    local success, result = pcall(function()
        local plots = findPlotsRoot()
        if not plots then
            logError("smartPlantingSystem", "не найдено workspace.Plots", "Plots не найдены")
            return false
        end
        
        local myPlot = pickMyPlot(plots)
        if not myPlot then
            logError("smartPlantingSystem", "не удалось выбрать plot", "Plot не выбран")
            return false
        end
        
        -- Проверяем лимит растений (35/35)
        local totalPlants = 0
        local plants = plantsFolder(myPlot)
        if plants then
            for _, plant in pairs(plants:GetChildren()) do
                if plant:IsA("Model") then
                    totalPlants = totalPlants + 1
                end
            end
        end
        
        -- Проверяем ростки
        local countdownPlants = getCountdownPlants()
        totalPlants = totalPlants + #countdownPlants
        
        -- Если достигнут лимит (35 растений), не пытаемся сажать
        if totalPlants >= 35 then
            return false -- Лимит достигнут, посадка невозможна
        end
    
        -- Получаем статистику по рядам
        local rowStats = getRowStatistics(myPlot)
        
        -- Умное удаление растений
        local removedCount = smartRemovePlants(myPlot)
        
        -- Проверяем, есть ли семена для посадки или замены
        local seedGroups = groupSeedsByName()
        local hasSeeds = false
        local bestSeedPriority = 999
        
        for _, group in ipairs(seedGroups) do
            local items = refreshUsable(group.items)
            if #items > 0 then
                local priority = group.priority or 999
                if priority < bestSeedPriority then
                    bestSeedPriority = priority
                end
                hasSeeds = true
            end
        end
        
        -- Проверяем, есть ли свободные места для посадки или замены
        local hasFreeSpace = false
        local canReplace = false
        
        for rowNum, stats in pairs(rowStats) do
            local count = (stats and stats.count) or 0
            if count < 5 then
                hasFreeSpace = true
                break
            else
                -- Проверяем, можно ли заменить худшие растения в заполненных рядах
                local worstPlant = findWorstPlantInRow(myPlot, rowNum)
                if worstPlant and worstPlant.priority and bestSeedPriority < worstPlant.priority then
                    canReplace = true
                    break
                end
            end
        end
        
        -- Если есть семена И (есть свободные места ИЛИ можно заменить худшие растения)
        if hasSeeds and (hasFreeSpace or canReplace) then
            local plantedCount = smartPlantSeeds(myPlot)
        end
        
        return true
    end)
    
    if not success then
        logError("smartPlantingSystem", result, "Ошибка системы посадки")
        return false
    end
    
    return result
end

-- Функция диагностики рядов
local function diagnoseRows()
    local success, result = pcall(function()
        local plots = findPlotsRoot()
        if not plots then 
            logError("diagnoseRows", "не найдено workspace.Plots", "Plots не найдены")
            return false
        end
        
        local myPlot = pickMyPlot(plots)
        if not myPlot then 
            logError("diagnoseRows", "не удалось выбрать plot", "Plot не выбран")
            return false
        end
    
        local rows = myPlot:FindFirstChild("Rows")
        if rows then
            local rKids = rows:GetChildren()
            numericSort(rKids)
            for _, row in ipairs(rKids) do
                local rowNum = tonumber(row.Name)
                local plantCount = countPlantsInRow(myPlot, rowNum)
                -- Проверяем растения без логирования
                local plants = plantsFolder(myPlot)
                if plants then
                    for _, plant in pairs(plants:GetChildren()) do
                        if plant:IsA("Model") then
                            local plantPart = firstPart(plant)
                            if plantPart then
                                local plantRow = getPlantRowByPosition(myPlot, plantPart.Position)
                                -- Проверка без логирования
                            end
                        end
                    end
                end
                
                -- Проверяем ростки без логирования
                local countdownPlants = getCountdownPlants()
                for _, countdownPlant in ipairs(countdownPlants) do
                    if countdownPlant.model then
                        local plantPart = firstPart(countdownPlant.model)
                        if plantPart then
                            local plantRow = getPlantRowByPosition(myPlot, plantPart.Position)
                            -- Проверка без логирования
                        end
                    end
                end
            end
        end
        
        return true
    end)
    
    if not success then
        logError("diagnoseRows", result, "Ошибка диагностики рядов")
    end
end

-- Основная функция
local function main()
    -- Инициализация
    initialize()
    
    -- Запускаем диагностику один раз при старте
    diagnoseRows()
    
    -- Основной цикл авто-продажи
    spawn(function()
        while true do
            autoSellPets()
            wait(1) -- Пауза между циклами
        end
    end)
    -- Основной цикл авто-покупки
    spawn(function()
        while true do
            if CONFIG.AUTO_BUY_SEEDS then
                autoBuySeeds()
            end
            if CONFIG.AUTO_BUY_GEAR then
                autoBuyGear()
            end
            wait(CONFIG.BUY_INTERVAL)
        end
    end)
    -- Основной цикл авто-сбора монет и замены брейнротов
    spawn(function()
        while true do
            if CONFIG.AUTO_COLLECT_COINS or CONFIG.AUTO_REPLACE_BRAINROTS then
                autoCollectCoinsAndReplaceBrainrots()
            end
            wait(CONFIG.COLLECT_INTERVAL)
        end
    end)
    -- Основной цикл авто-посадки семян
    spawn(function()
        wait(CONFIG.PLANT_INTERVAL)
        while true do
            if CONFIG.AUTO_PLANT_SEEDS then
                smartPlantingSystem()
            end
            wait(CONFIG.PLANT_INTERVAL)
        end
    end)
    -- Основной цикл авто-полива растений
    spawn(function()
        while true do
            if CONFIG.AUTO_WATER_PLANTS then
                autoWaterPlants()
            end
            wait(CONFIG.WATER_INTERVAL)
        end
    end)
    -- Основной цикл авто-покупки платформ
    spawn(function()
        while true do
            if CONFIG.AUTO_BUY_PLATFORMS then
                autoBuyPlatforms()
            end
            wait(CONFIG.PLATFORM_BUY_INTERVAL)
        end
    end)
    -- Основной цикл авто-покупки рядов
    spawn(function()
        while true do
            if CONFIG.AUTO_BUY_ROWS then
                autoBuyRows()
            end
            wait(CONFIG.ROW_BUY_INTERVAL)
        end
    end)
    
    -- Основной цикл анти-АФК (дополнительная защита)
    spawn(function()
        while true do
            if CONFIG.ANTI_AFK then
                performAntiAFK()
            end
            wait(CONFIG.ANTI_AFK_INTERVAL)
        end
    end)
    
    -- Основной цикл проверки реджойна
    spawn(function()
        while true do
            if CONFIG.AUTO_REEXECUTE then
                checkForRejoin()
            end
            wait(10) -- Проверяем каждые 10 секунд
        end
    end)
    
    -- Обработчик реджойна через PlayerAdded
    if CONFIG.AUTO_REEXECUTE then
        game:GetService("Players").PlayerAdded:Connect(function(player)
            if player == LocalPlayer then
                print("[Авто-перезапуск] Игрок реджойнул, перезапускаем скрипт...")
                wait(3)
                loadstring(game:HttpGet("https://raw.githubusercontent.com/your-repo/AutoPetSeller.lua/main/AutoPetSeller.lua"))()
            end
        end)
    end
    
    -- Периодическое сохранение состояния
    spawn(function()
        while true do
            wait(60) -- Сохраняем каждую минуту
            saveScriptState()
        end
    end)
end

-- Функция для удобного изменения настроек
local function updateConfig(key, value)
    if getgenv().AutoPetSellerConfig[key] ~= nil then
        getgenv().AutoPetSellerConfig[key] = value
    else
        warn("Настройка " .. tostring(key) .. " не найдена")
    end
end

-- Экспортируем функцию в глобальную область для удобства
getgenv().updateAutoPetConfig = updateConfig

-- Запуск скрипта
main()

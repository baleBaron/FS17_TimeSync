--
-- Time synchronization
-- 
-- By: baron (mve.karlsson@gmail.com)
--

-- From: https://gist.github.com/socantre/c9dfcc5bd106a601d395
function days_from_civil(y, m, d)
    if m <= 2 then -- adjust so that leap days are at the end of leap years
      y = y - 1
      m = m + 9
    else
      m = m - 3
    end
    local era = math.floor(y / 400)
    local yoe = y - era * 400                                           -- [0, 399]
    local doy = math.modf((153*m + 2)/5) + d-1                          -- [0, 365]
    local doe = yoe * 365 + math.modf(yoe/4) - math.modf(yoe/100) + doy -- [0, 146096]
    return era * 146097 + doe - 719468
end

local TIMESYNC_DAY_FACTOR = 2400
local TIMESYNC_HOUR_FACTOR = 120
local TIMESYNC_MINUTE_FACTOR = 30

TimeSync = {}
addModEventListener(TimeSync);

function TimeSync:loadMap(name)
local saveYear, saveMonth, saveDay = g_currentMission.missionInfo.saveDate:match("(%d+)-(%d+)-(%d+)")
local currentYear, currentMonth, currentDay = getDate("%Y-%m-%d"):match("(%d+)-(%d+)-(%d+)")

    self.minuteCounter = g_currentMission.environment.currentMinute
    self.hasSynchronized = false
    self.daysToSync = g_currentMission.missionInfo.isValid and days_from_civil(tonumber(currentYear),tonumber(currentMonth),tonumber(currentDay)) - days_from_civil(tonumber(saveYear),tonumber(saveMonth),tonumber(saveDay)) or 0
       
    print("TimeSync: Savegame is "..self.daysToSync.." days behind.  ")
    
    g_currentMission.environment:addMinuteChangeListener(TimeSync)
    g_currentMission.environment:addHourChangeListener(TimeSync)
    g_currentMission.environment:addDayChangeListener(TimeSync)
end

function TimeSync:deleteMap()
end

function TimeSync:mouseEvent(posX, posY, isDown, isUp, button)
end

function TimeSync:keyEvent(unicode, sym, modifier, isDown)
end

function TimeSync:update(dt)
    if not self.hasSynchronized and g_currentMission:getIsServer() then
        local currentHour = tonumber(getDate("%H"))
        local currentMinute = tonumber(getDate("%M"))
        local gameHour = g_currentMission.environment.currentHour
        local gameMinute = g_currentMission.environment.currentMinute
        
        if self.daysToSync > 0 or currentHour > gameHour+1 then
            -- at least one hour until synchronized
            g_currentMission:setTimeScale(TIMESYNC_DAY_FACTOR) 
        elseif currentHour > gameHour then
            -- less than one hour until synchronized
            g_currentMission:setTimeScale(TIMESYNC_HOUR_FACTOR) 
        elseif currentHour == gameHour and currentMinute > gameMinute then
            -- hour is synchronized, find minute
            g_currentMission:setTimeScale(TIMESYNC_MINUTE_FACTOR) 
        else
            -- we are synchronized
            g_currentMission:setTimeScale(1) 
            self.hasSynchronized = true
        end
    end
end

function TimeSync:draw() 
end

-- repair lost minuteChanged() calls due to too fast FFWD
function TimeSync:minuteChanged()
    self.minuteCounter = self.minuteCounter + 1
end

function TimeSync:hourChanged()
local minutesLost = 60 - self.minuteCounter

    for i=1,minutesLost,1 do
        for _, listener in pairs(g_currentMission.environment.minuteChangeListeners) do
            listener:minuteChanged()
        end
    end
    
    self.minuteCounter = 0;
    g_currentMission:setTimeScale(1)
end

function TimeSync:dayChanged()
    if not self.hasSynchronized then
        self.daysToSync = self.daysToSync - 1
    end
end

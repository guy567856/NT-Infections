NTI = {}
NTI.Name = "Infections"
NTI.Version = "0.9.8"
NTI.VersionNum = 00090008
NTI.Path=table.pack(...)[1]
Timer.Wait(function() if NTC ~= nil and NTC.RegisterExpansion ~= nil then NTC.RegisterExpansion(NTI) end end,1)

if (Game.IsMultiplayer and SERVER) or not Game.IsMultiplayer then
    Timer.Wait(function()
        if NTC == nil then
            print("Error loading NT Infections: It appears Neurotrauma isn't loaded!")
            return
        end

        dofile(NTI.Path.."/Lua/Scripts/humanupdate.lua")
        dofile(NTI.Path.."/Lua/Scripts/items.lua")
        dofile(NTI.Path.."/Lua/Scripts/helperfunctions.lua")
    end,1)
end
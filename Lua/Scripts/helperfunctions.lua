local limbtypes = {
    LimbType.Torso,
    LimbType.Head,
    LimbType.LeftArm,
    LimbType.RightArm,
    LimbType.LeftLeg,
    LimbType.RightLeg,
}

NTI.anti_strep = {
    {"afantibiotics", 4},
    {"afimipenem", 4},
    {"afampicillin", 8},
    {"afcotrim", 8},
    {"afaugmentin", 16},
    {"afvancomycin", 16},
}

NTI.anti_staph = {
    {"afantibiotics", 2},
    {"afgentamicin", 2},
    {"afimipenem", 4},
    {"afampicillin", 4},
    {"afaugmentin", 12},
    {"afcotrim", 12},
    {"afvancomycin", 16},
}

NTI.anti_mrsa = {
    {"afcotrim", 4},
    {"afvancomycin", 16},
}

NTI.anti_pseudo = {
    {"afimipenem", 5},
    {"afgentamicin", 16},
}

NTI.anti_provo = {
    {"afimipenem", 3},
    {"afaugmentin", 5},
    {"afgentamicin", 16},
}

NTI.VirusTable = {
    "europancough"
}

--list of infections including their limb and blood tags as well as other various information (look below)
NTI.InfInfo = { --{limbname, bloodname, probability, speed, antibiotics[name, level], sample, vaccine}
    {"limbstaph", "bloodstaph", 4, 0.35, NTI.anti_staph, "staphtubeunk", "afstaphvac"},
    {"limbstrep", "bloodstrep", 3, 0.35, NTI.anti_strep, "streptubeunk", "afstrepvac"},
    {"limbmrsa", "bloodmrsa", 2, 0.35, NTI.anti_mrsa, "mrsatubeunk", "afstaphvac"},
    {"limbprovo", "bloodprovo", 3, 0.35, NTI.anti_provo, "provotubeunk", "afprovovac"},
    {"limbpseudo", "bloodpseudo", 1, 0.35, NTI.anti_pseudo, "pseudotubeunk", "afpseudovac"},
}

--[[
limbname - the initial infection that is limb specific, will progress to blood infection at higher levels
bloodname - the blood infection version on the infection
probability - the "number of names put into the hat" that will have the chance to be pulled from the list of random infections
speed - speed at which the infection progresses calculated as: initial_speed + (infection_severity / 5) clamped to a max of 1.05
antibiotics - a list of antibiotics that have an effect on said disease. the number provided is the denominator, so antibiotics are calculated as: infection_speed * (1 / antibiotic_value)...
sample - the item that is returned when using a culture sampler
vaccine - the vaccine affliction name that will have an effect on this disease
]]--

NTI.InfTable = {} --list of infection names
NTI.InfPicker = {} --list of infection names that will be picked from at random

--fill in the two previous tables
for i = 1, #NTI.InfInfo do
    local infection = NTI.InfInfo[i]
    table.insert(NTI.InfTable, 1, infection[1])
    for j = 1, infection[3] do
        table.insert(NTI.InfPicker, 1, infection[1])
    end
end

--helper functions

--return a boolean if a limb is not the head (or torso if specified)
function NTI.NotHead(limb, torso_included)
    return limb ~= LimbType.Head or (torso_included and limb ~= LimbType.Torso)
end

--return a boolean if a character's blood is currently infected
function NTI.BloodIsInfected(character)
    for i = 1, #NTI.InfInfo do
        local infection = NTI.InfInfo[i]
        if HF.GetAfflictionStrength(character, infection[2], 0) > 0 then
            return true
        end
    end

    return false
end

--return the level of blood infection for all infections
function NTI.BloodInfectionLevel(character)
    local result = 0

    for i = 1, #NTI.InfInfo do
        local infection = NTI.InfInfo[i]
        result = result + HF.GetAfflictionStrength(character, infection[2], 0)
    end

    return result
end

--return the infection level of a limb
function NTI.LimbInfectionLevel(character, limb)
    return HF.GetAfflictionStrengthLimb(character, limb, "infectionlevel", 0)
end

--return the tag of the infection in a limb
function NTI.LimbInfectionName(character, limb)
    if not NTI.LimbIsInfected(character, limb) then
        return nil
    end

    for i = 1, #NTI.InfTable do
        if HF.GetAfflictionStrengthLimb(character, limb, NTI.InfTable[i], 0) > 0 then
            return NTI.InfTable[i]
        end
    end

    return nil
end

--return the infection level of a limb from a list of infections
function NTI.LimbInfectionLevelList(character, limb, list)
    for i = 1, #list do
        if HF.HasAfflictionLimb(character, list[i], limb, 0) then
            return NTI.LimbInfectionLevel(character, limb)
        end
    end

    return 0
end

--return a boolean if a limb is currently infected
function NTI.LimbIsInfected(character, limb)
    return NTI.LimbInfectionLevel(character, limb) > 0
end

--return the info of the infection at the limb
function NTI.GetInfectionInfoLimb(character, limb)
    for i = 1, #NTI.InfInfo do
        local inf = NTI.InfInfo[i]
        if HF.GetAfflictionStrengthLimb(character, limb, inf[1], 0) > 0 then
            return inf
        end
    end

    return nil
end

--return the info of a random blood infection in a character
function NTI.GetInfectionInfoBloodRandom(character)
    local pool = {}

    for i = 1, #NTI.InfInfo do
        local inf = NTI.InfInfo[i]
        local val = HF.GetAfflictionStrength(character, inf[2], 0)
        if val > 0 then
            table.insert(pool, 1, inf)
        end
    end

    return pool[math.random(#pool)]
end

--return the total antibiotic value from a list
function NTI.GetAntibioticValue(character, list)
    local value = 1
    
    for i = 1, #list do
        local ab = list[i]

        if HF.GetAfflictionStrength(character, ab[1], 0) > 0 then
            value = value * (1 / ab[2])
        end
    end

    return value
end

--return full body necrotizing fasciitis level
function NTI.GetTotalNecValue(character)
    local value = 0

    for limb in limbtypes do
        value = value + HF.GetAfflictionStrengthLimb(character, limb, "necfasc", 0)
    end

    return value
end

--NTI override for surgery plus stuff
function NTI.TriggerUnsterilityEvent(character)
    local type = NTI.DetermineDirtiestLimb(character)

    if type ~= nil then
        NTI.InfectCharacterRandom(character, type)
    end
end

--kind of a dumb solution, but i didnt want to go out of my way to override a lot of the code from ntsp and ntspu as they do not specify which limb is unsterile
function NTI.DetermineDirtiestLimb(character)
    local choice = nil

    for limb in limbtypes do
        if not NTI.LimbIsInfected(character, limb) and HF.HasAfflictionLimb(character, "surgeryincision", limb) then
            if not HF.HasAfflictionLimb(character, "ointmented", limb) then
                return limb
            end

            choice = limb
        end
    end

    return choice
end

--infect the character with a random infection and severity
function NTI.InfectCharacterRandom(character, limb)
    if NTI.LimbIsInfected(character, limb) then
        return
    end

    local randomval = math.random(5)
    HF.SetAfflictionLimb(character, NTI.InfPicker[math.random(#NTI.InfPicker)], limb, 2)
    HF.SetAfflictionLimb(character, "infectionseverity", limb, randomval)
    HF.SetAfflictionLimb(character, "infectionlevel", limb, 1)
end

--infect viral infection with random severity
function NTI.InfectCharacterViral(character, virus, level)
    local randomval = math.random(5)
    HF.SetAffliction(character, "viralseverity", randomval)
    HF.SetAffliction(character, virus, level)
end

--return boolean if character has a virus
function NTI.HasViralInfection(character)
    for i = 1, #NTI.VirusTable do
        if HF.HasAffliction(character, NTI.VirusTable[i]) then
            return true
        end
    end

    return false
end

--decomposing the blood updating shit
function NTI.BloodInfUpdate(character, antibiotic_list, vaccine)
    local immune_level = HF.GetAfflictionStrength(character, "immunity", 0) / 100
    local response = HF.GetAfflictionStrength(character, "systemicresponse", 0) / 200
    local ab = NTI.GetAntibioticValue(character, antibiotic_list)
    return 0.75 * ab - response - ((HF.GetAfflictionStrength(character, vaccine, 0) / 2400) * immune_level)
end

function NTI.WearingNeededHead(character, tagval)
    local result = 0

    for i = 1, #tagval do
        local tag = tagval[i]
        if (HF.ItemHasTag(HF.GetHeadWear(character),tag[1])) then
            result = result + tag[2]
        end
    end

    return result
end

function NTI.WearingNeededOuter(character, tagval)
    local result = 0

    for i = 1, #tagval do
        local tag = tagval[i]
        if (HF.ItemHasTag(HF.GetOuterWear(character),tag[1])) then
            result = result + tag[2]
        end
    end

    return result
end

function NTI.BotViralStarter(character)
    local val = math.random(40)
    NTI.InfectCharacterViral(character, "europancough", val)
    HF.SetAffliction(character, "systemicresponse", val / 2)
end

Hook.Add("characterCreated", "NTI.StartWithInfection", function(createdCharacter)
    Timer.Wait(function()
        if (createdCharacter.IsHuman and not createdCharacter.IsDead and not createdCharacter.IsPlayer) then
            if math.random() < 0.02 then
                NTI.BotViralStarter(createdCharacter)
            end
        end
    end, 2000)
end)
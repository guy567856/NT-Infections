local limbtypes = {
    LimbType.Torso,
    LimbType.Head,
    LimbType.LeftArm,
    LimbType.RightArm,
    LimbType.LeftLeg,
    LimbType.RightLeg,
}

NTI.anti_strep = {
    {"afceftazidime", 3},
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
    {"afceftazidime", 8},
    {"afgentamicin", 16},
}

NTI.anti_provo = {
    {"afimipenem", 3},
    {"afaugmentin", 5},
    {"afceftazidime", 6},
    {"afgentamicin", 16},
}

NTI.anti_europan = {
    {"afremdesivir", 8}
}

NTI.med_europan = {
    {"afdextromethorphan", 100},
    {"analgesia", 50},
    {"afzincsupplement", 50}
}

NTI.head_protection = {
    {"sterile", 7}, 
    {"diving", 7}
}

NTI.outer_protection = {
    {"diving", 14},
    {"divinghelmet", 14}
}

--list of viruses
NTI.VirusInfo = { --{name, probability (1 / #), speed, antivirals[name, level], medicine[name, level], slowdown, virulence, sample}
    {"europancough", 120, 0.4, NTI.anti_europan, NTI.med_europan, 0.6, 1, "europanviralunk"},
    {"influenza", 100, 0.35, {{"afzincsupplement", 2}}, NTI.med_europan, 0.4, 0.9, "fluviralunk"},
    {"commoncold", 80, 0.3, {{"afzincsupplement", 3}}, NTI.med_europan, 0.2, 0.8, "coldviralunk"}
}

--[[
name - affliction name of the virus
probability - the odds of a bot spawning with the infection
speed - the base speed the infection will increase at calculated as:
antivirals - list of drugs that will decrease the speed of the virus
medicine - list of drugs that will alleviate symptoms of the virus
slowdown - speed multiplier to show down a character
virulence - multiplier for infection spread chance, cannot be 0 or less
]]--

--list of infections including their limb and blood tags as well as other various information (look below)
NTI.InfInfo = { --{limbname, bloodname, probability, speed, antibiotics[name, level], sample, vaccine}
    {"limbstaph", "bloodstaph", 4, 0.30, NTI.anti_staph, "staphtubeunk", "afstaphvac"},
    {"limbstrep", "bloodstrep", 3, 0.30, NTI.anti_strep, "streptubeunk", "afstrepvac"},
    {"limbmrsa", "bloodmrsa", 2, 0.30, NTI.anti_mrsa, "mrsatubeunk", "afstaphvac"},
    {"limbprovo", "bloodprovo", 3, 0.30, NTI.anti_provo, "provotubeunk", "afprovovac"},
    {"limbpseudo", "bloodpseudo", 1, 0.30, NTI.anti_pseudo, "pseudotubeunk", "afpseudovac"},
}

--[[
limbname - the initial infection that is limb specific, will progress to blood infection at higher levels
bloodname - the blood infection version on the infection
probability - the "number of names put into the hat" that will have the chance to be pulled from the list of random infections
speed - speed at which the infection progresses calculated as: initial_speed + (infection_severity * 0.075) clamped to a max of 1.05
antibiotics - a list of antibiotics that have an effect on said disease. the number provided is the denominator, so antibiotics are calculated as: infection_speed * (1 / antibiotic_value)...
sample - the item that is returned when using a culture sampler
vaccine - the vaccine affliction name that will have an effect on this disease
]]--

NTI.InfTable = {} --list of infection names
NTI.VirusTable = {} --list of virus names

--fill in the two previous tables
for i = 1, #NTI.InfInfo do
    local infection = NTI.InfInfo[i]
    table.insert(NTI.InfTable, 1, infection[1])
end

for i = 1, #NTI.VirusInfo do
    local virus = NTI.VirusInfo[i]
    table.insert(NTI.VirusTable, 1, virus[1])
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

--return the info of the current viral infection
function NTI.GetVirusInfo(character)
    for i = 1, #NTI.VirusInfo do
        local virus = NTI.VirusInfo[i]
        if HF.GetAfflictionStrength(character, virus[1], 0) > 0 then
            return virus
        end
    end

    return nil
end

--infect viral infection with random severity
function NTI.InfectCharacterViral(character, virus, level)
    local sev = math.random(10)
    HF.SetAffliction(character, virus, sev)
    HF.SetAffliction(character, "virallevel", level)
end

--return the total medicine value from a list
function NTI.GetTotalMedValue(character, list)
    local value = 0

    for i = 1, #list do
        local med = list[i]

        if HF.GetAfflictionStrength(character, med[1], 0) > 0 then
            value = value + med[2]
        end
    end

    return value
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

--symptom dealing
function NTI.CheckSymptom(character, symptom, level, threshold, chance)
    if (level < threshold) then return end

    if (NTC.GetSymptom(character, symptom) or HF.Chance(chance)) then
        NTC.SetSymptomTrue(character, symptom, 4)
    end
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

    local inflst = NTI.InfPickerForm(character)
    local randomval = math.random(10)
    HF.SetAfflictionLimb(character, inflst[math.random(#inflst)], limb, randomval)
    HF.SetAfflictionLimb(character, "infectionlevel", limb, 1)
end

--make a list for the probability of which infection is picked (already gotten infections will be more likely)
function NTI.InfPickerForm(character)
    local lst = {}

    for i = 1, #NTI.InfInfo do
        local infection = NTI.InfInfo[i]
        local scalar = 1

        if NTI.CheckAllLimbsFor(character, infection[1]) then
            scalar = 3
        end

        for j = 1, (infection[3] * scalar) do
            table.insert(lst, 1, infection[1])
        end
    end

    return lst
end

--return a boolean if the body has a certain limb affliction yet
function NTI.CheckAllLimbsFor(character, tag)
    for limb in limbtypes do
        if HF.GetAfflictionStrengthLimb(character, limb, tag, 0) > 0 then
            return true
        end
    end

    return false
end

--decomposing the blood updating shit
function NTI.BloodInfUpdate(character, antibiotic_list, vaccine)
    local immune_level = HF.GetAfflictionStrength(character, "immunity", 0) / 100
    local response = HF.GetAfflictionStrength(character, "systemicresponse", 0) / 160
    local ab = NTI.GetAntibioticValue(character, antibiotic_list)
    return 0.75 * ab - response - ((HF.GetAfflictionStrength(character, vaccine, 0) / 2000) * immune_level)
end

--decomposing the wound calculating stuff
function NTI.HasWound(c, limbaff, type)
    local wound = limbaff.burn.strength +
    limbaff.lacerations.strength +
    limbaff.gunshotwound.strength +
    limbaff.bitewounds.strength +
    limbaff.explosiondamage.strength +
    HF.GetAfflictionStrengthLimb(c.character, type, "suturedw", 0) +
    HF.GetAfflictionStrengthLimb(c.character, type, "surgeryincision", 0)

    return wound > 0
end

--check if a character is wearing a specific tag from a list on their head
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

--ibidem but for outer wear
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

--for when a new ai npc spawns, give a chance to randomly infect them
function NTI.BotViralStarter(character, virus)
    local val = math.random(40)
    NTI.InfectCharacterViral(character, virus, val)
    HF.SetAffliction(character, "systemicresponse", val / 2)
end

Hook.Add("characterCreated", "NTI.StartWithInfection", function(createdCharacter)
    Timer.Wait(function()
        if (createdCharacter.IsHuman and not createdCharacter.IsDead and not createdCharacter.IsPlayer and not createdCharacter.IsOnPlayerTeam) then
            for i = 1, #NTI.VirusInfo do
                local virus = NTI.VirusInfo[i]
                if (HF.Chance(1 / virus[2])) then
                    NTI.BotViralStarter(createdCharacter, virus[1])
                    break
                end
            end
        end
    end, 2000)
end)
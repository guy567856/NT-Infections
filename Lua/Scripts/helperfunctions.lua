local limbtypes = {
    LimbType.Torso,
    LimbType.Head,
    LimbType.LeftArm,
    LimbType.RightArm,
    LimbType.LeftLeg,
    LimbType.RightLeg,
}

NTI.anti_strep = {
    afceftazidime = 3,
    afantibiotics = 4,
    afimipenem = 4,
    afampicillin = 8,
    afcotrim = 8,
    afaugmentin = 16,
    afvancomycin = 16,
}

NTI.anti_staph = {
    afantibiotics = 2,
    afgentamicin = 2,
    afimipenem = 4,
    afampicillin = 4,
    afaugmentin = 12,
    afcotrim = 12,
    afvancomycin = 16,
}

NTI.anti_mrsa = {
    afcotrim = 4,
    afvancomycin = 16,
}

NTI.anti_pseudo = {
    afimipenem = 5,
    afceftazidime = 8,
    afgentamicin = 16,
}

NTI.anti_provo = {
    afimipenem = 3,
    afaugmentin = 5,
    afceftazidime = 6,
    afgentamicin = 16,
}

NTI.med_viral = {
    afdextromethorphan = 100,
    analgesia = 50,
    afzincsupplement = 50,
}

NTI.head_protection = {
    sterile = 7,
    diving = 6,
}

NTI.outer_protection = {
    diving = 14,
    divinghelmet = 14,
}

function NTI.VirusInfo(_probability, _basespeed, _antivirals, _medicine, _slowdown, _virulence, _samplename)
    return { probability = _probability, basespeed = _basespeed, antivirals = _antivirals, medicine = _medicine, slowdown = _slowdown, virulence = _virulence, samplename = _samplename }
end

--[[
    probability - the odds of a bot spawning with the infection
    basespeed - the base speed the infection will increase
    antivirals - list of drugs that will decrease the speed of the virus
    medicine - list of drugs that will alleviate symptoms of the virus
    slowdown - speed multiplier to show down a character
    virulence - multiplier for infection spread chance, cannot be 0 or less
    samplename = sample to be returned when analyzing virus
]]--

function NTI.BacteriaInfo(_bloodname, _prevalence, _basespeed, _severityspeed, _antibiotics, _samplename, _vaccine)
    return { bloodname = _bloodname, prevalence = _prevalence, basespeed = _basespeed, severityspeed = _severityspeed, antibiotics = _antibiotics, samplename = _samplename, vaccine = _vaccine }
end

--[[
    bloodname - the blood infection version on the infection
    prevalence - the "number of names put into the hat" that will have the chance to be pulled from the list of random infections. change in config
    basespeed - basespeed at which the infection progresses
    severityspeed - increase depending on severity level. severity level ranges from 2-10, so totalspeed = basespeed + (severity_level * severityspeed)
    antibiotics - a list of antibiotics that have an effect on said disease. the number provided is the denominator, so antibiotics are calculated as: infection_speed * (1 / antibiotic_value)...
    samplename - the item that is returned when using a sample collector
    vaccine - the vaccine affliction name that will have an effect on this disease
]]--

Timer.Wait(function()
    NTI.Viruses = {
        europancough = NTI.VirusInfo("NTI_europanChance", 0.4, {afremdesivir = 8}, NTI.med_viral, 0.6, 1, "europanviralunk"),
        influenza = NTI.VirusInfo("NTI_influenzaChance", 0.35, {afzincsupplement = 2}, NTI.med_viral, 0.4, 0.9, "fluviralunk"),
        commoncold = NTI.VirusInfo("NTI_coldChance", 0.3, {afzincsupplement = 3}, NTI.med_viral, 0.2, 0.8, "coldviralunk"),
    }

    NTI.Bacterias = {
        limbstaph = NTI.BacteriaInfo("bloodstaph", "NTI_staphPrevalence", 0.5, 0.05, NTI.anti_staph, "staphtubeunk", "afstaphvac"),
        limbstrep = NTI.BacteriaInfo("bloodstrep", "NTI_strepPrevalence", 0.5, 0.05, NTI.anti_strep, "streptubeunk", "afstrepvac"),
        limbmrsa = NTI.BacteriaInfo("bloodmrsa", "NTI_mrsaPrevalence", 0.5, 0.05, NTI.anti_mrsa, "mrsatubeunk", "afstaphvac"),
        limbprovo = NTI.BacteriaInfo("bloodprovo", "NTI_provoPrevalence", 0.5, 0.05, NTI.anti_provo, "provotubeunk", "afprovovac"),
        limbpseudo = NTI.BacteriaInfo("bloodpseudo", "NTI_pseudoPrevalence", 0.5, 0.05, NTI.anti_pseudo, "pseudotubeunk", "afpseudovac"),
    }
end,1)


---- HELPER FUNCTIONS ----
--return a boolean if the body has a certain limb affliction yet
function NTI.CheckAllLimbsFor(character, tag)
    for limb in limbtypes do
        if HF.GetAfflictionStrengthLimb(character, limb, tag, 0) > 0 then
            return true
        end
    end

    return false
end

--symptom dealing
function NTI.CheckSymptom(character, symptom, level, threshold, chance)
    if (level < threshold) then return end

    if (NTC.GetSymptom(character, symptom) or HF.Chance(chance)) then
        NTC.SetSymptomTrue(character, symptom, 4)
    end
end

--return the total antibiotic value from a list
function NTI.GetAntibioticValue(character, list)
    local result = 1
    
    for key, value in pairs(list) do
        if HF.GetAfflictionStrength(character, key, 0) > 0 then
            result = result * (1 / value)
        end
    end

    return result
end

--return full body necrotizing fasciitis level
function NTI.GetTotalNecValue(character)
    local value = 0

    for limb in limbtypes do
        value = value + HF.GetAfflictionStrengthLimb(character, limb, "necfasc", 0)
    end

    return value
end

--return a boolean if there is sepsis
function NTI.HasSepsis(character)
    return HF.GetAfflictionStrength(character, "sepsis", 0) > 0
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

--return a boolean if a limb is not the head (or torso if specified)
function NTI.NotHead(limb, torso_included)
    return limb ~= LimbType.Head or (torso_included and limb ~= LimbType.Torso)
end



---- BACTERIAL INFECTIONS ----
--return a boolean if a character's blood is currently infected
function NTI.BloodIsInfected(character)
    return HF.GetAfflictionStrength(character, "bloodinfectionlevel", 0) > 0
end

--make a list for the probability of which infection is picked
function NTI.FormBacteriaList(character)
    local list = {}

    for key, info in pairs(NTI.Bacterias) do
        for i = 1, (NTConfig.Get(info.prevalence, 1)) do
            table.insert(list, 1, key)
        end
    end

    return list
end

--return current bacteria infection name on limb
function NTI.GetCurrentBacteria(character, limb)
    for key, _ in pairs(NTI.Bacterias) do
        if HF.GetAfflictionStrengthLimb(character, limb, key, 0) > 0 then return key end
    end

    return nil
end

--return current blood bacteria infection name
function NTI.GetCurrentBacteriaBlood(character)
    for key, info in pairs(NTI.Bacterias) do
        if HF.GetAfflictionStrength(character, info.bloodname, 0) > 0 then return key end
    end

    return nil
end

--return sepsis increase from limb infections
function NTI.GetLimbIncreaseSepsis(character)
    return NTI.LimbTotalInfectionLevel(character) / 1000
end

--infect character's blood with a specific bacteria
function NTI.InfectBlood(character, bacteria, severity)
    if bacteria == nil then return end
    if NTI.BloodIsInfected(character) then return end

    HF.SetAffliction(character, bacteria, severity)
    HF.SetAffliction(character, "bloodinfectionlevel", 1)

    print("blood infection occurred on " .. character.Name .. " with severity of " .. severity)
end

--infect character with a specific bacteria on a limb
function NTI.InfectCharacterBacteria(character, limb, bacteria, severity)
    if bacteria == nil then return end
    if NTI.LimbIsInfected(character, limb) then return end

    HF.SetAfflictionLimb(character, bacteria, limb, severity)
    HF.SetAfflictionLimb(character, "infectionlevel", limb, 1)

    print("infection occurred on " .. limb .. " from " .. character.Name .. " with severity of " .. severity)
end

--infect the character with a random infection and severity on a limb
function NTI.InfectCharacterRandom(character, limb)
    local randomval = math.random(5) + math.random(5)
    local list = NTI.FormBacteriaList(character)
    NTI.InfectCharacterBacteria(character, limb, list[math.random(#list)], randomval)
end

--return the infection level of a limb from a list of infections
function NTI.LimbInfectionLevelList(character, limb, list)
    for i = 1, #list do
        if HF.HasAfflictionLimb(character, list[i], limb, 0) then
            return HF.GetAfflictionStrengthLimb(character, limb, "infectionlevel", 0)
        end
    end

    return 0
end

--return a boolean if a limb is currently infected
function NTI.LimbIsInfected(character, limb)
    return HF.GetAfflictionStrengthLimb(character, limb, "infectionlevel", 0) > 0
end

--return total limb infection across the whole body
function NTI.LimbTotalInfectionLevel(character)
    local result = 0

    for limb in limbtypes do
        result = result + HF.GetAfflictionStrengthLimb(character, limb, "infectionlevel", 0)
    end

    return result
end

--spread a limb infection to another limb
function NTI.SpreadToNextLimb(character, limb, bacteria)
    local possible_limbs = {}
    
    if limb == LimbType.Torso then
        possible_limbs = {LimbType.Head, LimbType.LeftArm, LimbType.RightArm, LimbType.LeftLeg, LimbType.RightLeg}
    else
        possible_limbs = {LimbType.Torso}
    end

    local next_limb = possible_limbs[math.random(#possible_limbs)]
    local severity = math.min(math.random(5) + math.random(5), HF.GetAfflictionStrengthLimb(character, limb, bacteria, 0))
    print("limb to limb from " .. limb .. " to " .. next_limb .. " with severity " .. severity)
    NTI.InfectCharacterBacteria(character, next_limb, bacteria, severity)
end

--NTI override for surgery plus stuff
function NTI.TriggerUnsterilityEvent(character)
    local type = NTI.DetermineDirtiestLimb(character)

    if type ~= nil then
        print("surgical infection occurred")
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



---- VIRAL INFECTIONS ----
--for when a new ai npc spawns, give a chance to randomly infect them
function NTI.BotViralStarter(character, virus)
    local val = math.random(40)
    NTI.InfectCharacterViral(character, virus, val)
    HF.SetAffliction(character, "systemicresponse", val / 2)
end

--get the name of the current virus of a character
function NTI.GetCurrentVirus(character)
    for key, _ in pairs(NTI.Viruses) do
        if HF.GetAfflictionStrength(character, key, 0) > 0 then return key end
    end

    return nil
end

--return the total medicine value from a list
function NTI.GetTotalMedValue(character, list)
    local result = 0

    for key, value in pairs(list) do
        if HF.GetAfflictionStrength(character, key, 0) > 0 then
            result = result + value
        end
    end

    return result
end

--infect viral infection with random severity
function NTI.InfectCharacterViral(character, virus, level)
    local sev = math.random(5) + math.random(5)
    HF.SetAffliction(character, virus, sev)
    HF.SetAffliction(character, "virallevel", level)
end

--check if a character is wearing a specific tag from a list on their head
function NTI.WearingNeededHead(character, tagval)
    local result = 0

    for key, value in pairs(tagval) do
        if HF.ItemHasTag(HF.GetHeadWear(character), key) then
            result = result + value
        end
    end

    return result
end

--ibidem but for outer wear
function NTI.WearingNeededOuter(character, tagval)
    local result = 0

    for key, value in pairs(tagval) do
        if HF.ItemHasTag(HF.GetOuterWear(character), key) then
            result = result + value
        end
    end

    return result
end

Hook.Add("characterCreated", "NTI.StartWithInfection", function(createdCharacter)
    Timer.Wait(function()
        if (createdCharacter.IsHuman and not createdCharacter.IsDead and not createdCharacter.IsPlayer and not createdCharacter.IsOnPlayerTeam) then
            for key, info in pairs(NTI.Viruses) do
                if HF.Chance(1 / NTConfig.Get(info.probability, 1)) then
                    NTI.BotViralStarter(createdCharacter, key)
                    break
                end
            end
        end
    end, 2000)
end)
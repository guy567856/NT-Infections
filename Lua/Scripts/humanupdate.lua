local limbtypes = {
    LimbType.Torso,
    LimbType.Head,
    LimbType.LeftArm,
    LimbType.RightArm,
    LimbType.LeftLeg,
    LimbType.RightLeg,
}

Timer.Wait(function()
--affliction overrides
--override the bloodpressure affliction to allow sepsis to lower bloodpressure
    NT.Afflictions.bloodpressure={min=5,max=200,default=100,update=function(c,i)
        -- fix people not having a blood pressure
        if not HF.HasAffliction(c.character,i) then HF.SetAffliction(c.character,i,100) end

        if c.stats.stasis then return end
        -- calculate new blood pressure
        local desiredbloodpressure =
            (c.stats.bloodamount
            - c.afflictions.tamponade.strength/2                            -- -50 if full tamponade
            - HF.Clamp(c.afflictions.afpressuredrug.strength*5,0,45)        -- -45 if blood pressure medication
            - HF.Clamp(c.afflictions.anesthesia.strength,0,15)              -- -15 if propofol (fuck propofol)
            - c.afflictions.sepsis.strength --sepsis will lower bloodpressure
            + HF.Clamp(c.afflictions.afadrenaline.strength*10,0,30)         -- +30 if adrenaline
            + HF.Clamp(c.afflictions.afsaline.strength*5,0,30)              -- +30 if saline
            + HF.Clamp(c.afflictions.afringerssolution.strength*5,0,30)     -- +30 if ringers
            ) * 
            (1+0.5*((c.afflictions.liverdamage.strength/100)^2)) *              -- elevated if full liver damage
            (1+0.5*((c.afflictions.kidneydamage.strength/100)^2)) *             -- elevated if full kidney damage
            (1 + c.afflictions.alcoholwithdrawal.strength/200 ) *               -- elevated if alcohol withdrawal
            HF.Clamp((100-c.afflictions.traumaticshock.strength*2)/100,0,1) *   -- none if half or more traumatic shock
            ((100-c.afflictions.fibrillation.strength)/100) *                   -- lowered if fibrillated
            (1-math.min(1,c.afflictions.cardiacarrest.strength)) *              -- none if cardiac arrest
            NTC.GetMultiplier(c.character,"bloodpressure")
            
        local bloodpressurelerp = 0.2
        -- adjust three times slower to heightened blood pressure
        if(desiredbloodpressure>c.afflictions.bloodpressure.strength) then bloodpressurelerp = bloodpressurelerp/3 end
        c.afflictions.bloodpressure.strength = HF.Clamp(HF.Round(
            HF.Lerp(c.afflictions.bloodpressure.strength,desiredbloodpressure,bloodpressurelerp),2)
            ,5,200)
    end}

--override for sepsis to increase by nti infections and no longer affected by antibiotics directly
    NT.Afflictions.sepsis={update=function(c,i)
        if c.stats.stasis then return end
        if c.afflictions[i].strength > 20 and c.afflictions.sym_unconsciousness.strength<=0 and not c.stats.sedated then NTC.SetSymptomTrue(c.character, "pain_abdominal", 2) end
        if c.afflictions[i].strength > 10 and c.afflictions.sym_unconsciousness.strength<=0 and not c.stats.sedated then NTC.SetSymptomTrue(c.character, "sym_confusion", 2) end

        if c.afflictions[i].strength > 0 then
            local increase = (HF.GetAfflictionStrength(c.character, "bloodinfectionlevel", 0) / 250) + NTI.GetLimbIncreaseSepsis(c.character)
            if not (increase > 0.003) then increase = -NT.Deltatime end

            c.afflictions[i].strength = c.afflictions[i].strength + increase
        end
    end}

--override to change how infections are received (no longer directly to sepsis)
    NT.LimbAfflictions.foreignbody={update=function(c,limbaff,i,type)
        if(limbaff[i].strength < 15) then limbaff[i].strength = limbaff[i].strength-0.05*c.stats.healingrate*NT.Deltatime end

        -- check for arterial cut triggers and foreign body sepsis
        local foreignbodycutchance = ((HF.Minimum(limbaff[i].strength,20)/100)^6)*0.5
        if (limbaff.bleeding.strength > 80 or HF.Chance(foreignbodycutchance)) then
            NT.ArteryCutLimb(c.character,type)
        end

        -- infection chance
        local infchance = HF.Minimum(limbaff.gangrene.strength,15,0) / 400 + HF.Minimum(limbaff.infectedwound.strength,20) / 1000 + foreignbodycutchance
        if(HF.Chance(infchance)) then
            NTI.InfectCharacterRandom(c.character, type)
        end
    end}

--override to how inflammation accumulates
    NT.LimbAfflictions.inflammation={update=function(c,limbaff,i,type)
        limbaff[i].strength = HF.BoolToNum(NTI.LimbIsInfected(c.character, type), 0.5) + (1.5 * (HF.GetAfflictionStrengthLimb(c.character, type, "infectionlevel", 0) / 100))
        
        if limbaff.foreignbody.strength > 15 then
            limbaff[i].strength = 2
        end
    end}

--fasciitis causes pain
    local pain_ext_temp = NT.LimbAfflictions.pain_extremity.update
    NT.LimbAfflictions.pain_extremity={max=10,update=function(c,limbaff,i,type)
        pain_ext_temp(c, limbaff, i, type)

        if c.afflictions.sym_unconsciousness.strength>0 then limbaff[i].strength = 0 return end
        limbaff[i].strength = limbaff[i].strength + (HF.BoolToNum(c.afflictions.sepsis.strength > 50 or HF.HasAfflictionLimb(c.character, "necfasc", type, 10), 2) - HF.BoolToNum(c.stats.sedated,100)) * NT.Deltatime
    end}

--europan cough to cause lung damage
    local lungdam_temp = NT.Afflictions.lungdamage.update
    NT.Afflictions.lungdamage={update=function(c,i)
        lungdam_temp(c, i)
        if c.stats.stasis then return end

        c.afflictions[i].strength = NT.organDamageCalc(c,c.afflictions.lungdamage.strength + NTC.GetMultiplier(c.character,"lungdamagegain")*(math.max(c.afflictions.europancough.strength-75,0)/200*NT.Deltatime))
    end}


--nti afflictions
--dextromethorphan
    NT.Afflictions.afdextromethorphan={update=function(c,i)
        if c.afflictions[i].strength > 0 then NTC.SetSymptomFalse(c.character, "sym_cough", 2) end
        if c.afflictions[i].strength > 80 then NTC.SetSymptomTrue(c.character, "sym_nausea", 2) end
        if c.afflictions[i].strength > 90 then HF.AddAffliction(c.character,"psychosis",1) end
    end}

--zinc supplement
    NT.Afflictions.afzincsupplement={update=function(c,i)
        if c.afflictions[i].strength > 80 then NTC.SetSymptomTrue(c.character, "sym_nausea", 2) end
        if c.afflictions[i].strength > 90 then NTC.SetSymptomTrue(c.character, "sym_vomiting", 2) end
    end}

--immunocompromised affliction
    NT.Afflictions.immunodeficiency={update=function(c,i)
        if (c.afflictions.radiationsickness.strength > 50) then
            c.afflictions[i].strength = 100;
        else
            c.afflictions[i].strength = 0;
        end
    end}


--viral infection stuff
    NT.Afflictions.afremdesivir={update=function(c,i)
        if c.afflictions[i].strength > 70 then NTC.SetSymptomTrue(c.character, "sym_nausea", 2) end
        if c.afflictions[i].strength > 75 then NTC.SetSymptomTrue(c.character, "sym_jaundice", 2) end
        if c.afflictions[i].strength > 80 and c.afflictions.sym_unconsciousness.strength<=0 and not c.stats.sedated then NTC.SetSymptomTrue(c.character, "sym_headache", 2) end
    end}

    NT.Afflictions.europancough={update=function(c,i)
        local level = HF.GetAfflictionStrength(c.character, "virallevel", 0)

        if (level <= 0) then
            c.afflictions[i].strength = 0
            return
        end

        if (c.afflictions[i].strength <= 0) then return end

        NTI.CheckSymptom(c.character, "sym_cough", level, 10, 0.2)
        NTI.CheckSymptom(c.character, "fever", level, 30, 0.1)
        NTI.CheckSymptom(c.character, "sym_weakness", level, 50, 0.01)
        NTI.CheckSymptom(c.character, "dyspnea", level, 60, 0.01)
        NTI.CheckSymptom(c.character, "sym_nausea", level, 70, 0.02)
        if c.afflictions.respiratoryarrest.strength <= 0 then
            NTI.CheckSymptom(c.character, "sym_wheezing", level, 70, 0.01)
        end
        if c.afflictions.sym_unconsciousness.strength<=0 and not c.stats.sedated then
            NTI.CheckSymptom(c.character, "sym_headache", level, 75, 0.02)
            NTI.CheckSymptom(c.character, "pain_chest", level, 90, 0.02)
        end
    end}

    NT.Afflictions.influenza={update=function(c,i)
        local level = HF.GetAfflictionStrength(c.character, "virallevel", 0)

        if (level <= 0) then
            c.afflictions[i].strength = 0
            return
        end

        if (c.afflictions[i].strength <= 0) then return end

        NTI.CheckSymptom(c.character, "sym_cough", level, 15, 0.2)
        NTI.CheckSymptom(c.character, "fever", level, 30, 0.1)
        NTI.CheckSymptom(c.character, "sym_nausea", level, 50, 0.02)
        if c.afflictions.sym_unconsciousness.strength<=0 and not c.stats.sedated then
            NTI.CheckSymptom(c.character, "sym_headache", level, 80, 0.02)
        end
    end}

    NT.Afflictions.commoncold={update=function(c,i)
        local level = HF.GetAfflictionStrength(c.character, "virallevel", 0)

        if (level <= 0) then
            c.afflictions[i].strength = 0
            return
        end

        if (c.afflictions[i].strength <= 0) then return end

        NTI.CheckSymptom(c.character, "sym_cough", level, 10, 0.2)
        if c.afflictions.sym_unconsciousness.strength<=0 and not c.stats.sedated then
            NTI.CheckSymptom(c.character, "sym_headache", level, 60, 0.05)
        end
        NTI.CheckSymptom(c.character, "fever", level, 80, 0.02)
    end}


--infection functionality
--the immune response to a limb infection
    NT.LimbAfflictions.immuneresponse={update=function(c,limbaff,i,type)
        if c.stats.stasis then return end

        if NTI.LimbIsInfected(c.character, type) then
            limbaff[i].strength = limbaff[i].strength + ((c.afflictions.immunity.strength - 50) / 100)
        else
            limbaff[i].strength = limbaff[i].strength - 1
        end
    end}

--immune response for the whole body (in response to blood infection)
    NT.Afflictions.systemicresponse={update=function(c,i)
        if c.stats.stasis then return end

        if NTI.BloodIsInfected(c.character) then
            c.afflictions[i].strength = c.afflictions[i].strength + ((c.afflictions.immunity.strength - 50) / 100)
        else
            c.afflictions[i].strength = c.afflictions[i].strength - 1
        end
    end}

--immune response for viral infections
    NT.Afflictions.viralantibodies={update=function(c,i)
        if c.stats.stasis then return end

        if HF.HasAffliction(c.character, "virallevel") then
            c.afflictions[i].strength = c.afflictions[i].strength + ((c.afflictions.immunity.strength - 50) / 100)
        else
            c.afflictions[i].strength = c.afflictions[i].strength - 0.02
        end
    end}

--current progress of a viral infection
    NT.Afflictions.virallevel={update=function(c,i)
        if c.stats.stasis then return end

        if c.afflictions[i].strength > 0 then
            local name = NTI.GetCurrentVirus(c.character)

            if name == nil then
                c.afflictions[i].strength = 0
                return
            end

            local virus = NTI.Viruses[name]

            local meds = NTI.GetTotalMedValue(c.character, virus.medicine)
            local gain = (virus.basespeed + HF.GetAfflictionStrength(c.character, name, 0) / 20) * NTI.GetAntibioticValue(c.character, virus.antivirals)
            local defense = (gain + 0.1 + HF.BoolToNum(HF.HasAffliction(c.character, "viralantibodies", 0), 0.5)) * (HF.GetAfflictionStrength(c.character, "systemicresponse", 0) / 100)

            c.stats.speedmultiplier = c.stats.speedmultiplier * (1 - virus.slowdown * (c.afflictions[i].strength / (100 + meds)))

            NTI.SpreadViralInfection(c.character, NTConfig.Get("NTI_viralSpreadChance", true), virus, meds, c.afflictions[i].strength, name)

            c.afflictions[i].strength = c.afflictions[i].strength + gain - defense
        end
    end}

--the current progress of the infection
    NT.LimbAfflictions.infectionlevel={update=function(c,limbaff,i,type)
        if c.stats.stasis then return end

        if limbaff[i].strength > 0 then
            local name = NTI.GetCurrentBacteria(c.character, type)

            if name == nil then limbaff[i].strength = 0 return end

            local info = NTI.Bacterias[name]
            local antibiotic = NTI.GetAntibioticValue(c.character, info.antibiotics)
            local increase = math.min(info.basespeed + HF.GetAfflictionStrengthLimb(c.character, type, name, 1) * info.severityspeed, 0.99) * antibiotic
                            - (HF.GetAfflictionStrengthLimb(c.character, type, "immuneresponse", 0) / 100)
                            - ((HF.GetAfflictionStrength(c.character, info.vaccine, 0) / 2000) * (c.afflictions.immunity.strength / 100))

            limbaff[i].strength = limbaff[i].strength + increase

            if limbaff[i].strength > 50 and not NTI.BloodIsInfected(c.character) then
                local base_chance = HF.Chance(((limbaff[i].strength - 50) / 150)^3)
                local nec_chance = HF.Chance(HF.GetAfflictionStrengthLimb(c.character, type, "necfasc", 0) / 1000)

                if base_chance or nec_chance then
                    NTI.InfectBlood(c.character, info.bloodname, math.random(5))
                end
            end

            if NTConfig.Get("NTI_canSpreadNextLimb", true) and limbaff[i].strength > 75 then
                local num = limbaff[i].strength - 75
                local den = 300 - (HF.GetAfflictionStrengthLimb(c.character, type, "cellulitis", 0) * 2) - (HF.GetAfflictionStrengthLimb(c.character, type, "necfasc", 0) * 2.5)
                local chance = HF.Chance(((num / den)^2) * antibiotic * (1 - HF.BoolToNum(type == LimbType.Torso, 0.5)))
                
                if chance then NTI.SpreadToNextLimb(c.character, type, name) end
            end

            if limbaff[i].strength > 75 and HF.Chance(((limbaff[i].strength - 75) / 100)^3) and not NTI.HasSepsis(c.character) then HF.SetAffliction(c.character, "sepsis", 1) end
        end
    end}

--progress of blood infection
    NT.Afflictions.bloodinfectionlevel={update=function(c,i)
        if c.stats.stasis then return end

        if c.afflictions[i].strength > 0 then
            local name = NTI.GetCurrentBacteriaBlood(c.character)

            if name == nil then c.afflictions[i].strength = 0 return end

            local info = NTI.Bacterias[name]
            local antibiotic = NTI.GetAntibioticValue(c.character, info.antibiotics)
            local increase = math.min(0.75 + HF.GetAfflictionStrength(c.character, info.bloodname, 1) * 0.05, 0.99) * antibiotic
                            - (HF.GetAfflictionStrength(c.character, "systemicresponse", 1) / 100)
                            - ((HF.GetAfflictionStrength(c.character, info.vaccine, 0) / 2000) * (c.afflictions.immunity.strength / 100))
            print("+"..increase)

            c.afflictions[i].strength = c.afflictions[i].strength + increase
            print("end "..c.afflictions[i].strength)

            if HF.Chance((c.afflictions[i].strength / 150)^3) and not NTI.HasSepsis(c.character) then HF.SetAffliction(c.character, "sepsis", 1) end
        end
    end}
    

--bacterial infections
--streptococcal infection
    NT.LimbAfflictions.limbstrep={update=function(c,limbaff,i,type)
        if not NTI.LimbIsInfected(c.character, type) then limbaff[i].strength = 0 end
    end}

    NT.Afflictions.bloodstrep={update=function(c,i)
        if not NTI.BloodIsInfected(c.character) then c.afflictions[i].strength = 0 end
    end}

--staphylococcal infection
    NT.LimbAfflictions.limbstaph={update=function(c,limbaff,i,type)
        if not NTI.LimbIsInfected(c.character, type) then limbaff[i].strength = 0 end
    end}

    NT.Afflictions.bloodstaph={update=function(c,i)
        if not NTI.BloodIsInfected(c.character) then c.afflictions[i].strength = 0 end
    end}

--mrsa infection
    NT.LimbAfflictions.limbmrsa={update=function(c,limbaff,i,type)
        if not NTI.LimbIsInfected(c.character, type) then limbaff[i].strength = 0 end
    end}

    NT.Afflictions.bloodmrsa={update=function(c,i)
        if not NTI.BloodIsInfected(c.character) then c.afflictions[i].strength = 0 end
    end}

--pseudomonas infection
    NT.LimbAfflictions.limbpseudo={update=function(c,limbaff,i,type)
        if not NTI.LimbIsInfected(c.character, type) then limbaff[i].strength = 0 end
    end}

    NT.Afflictions.bloodpseudo={update=function(c,i)
        if not NTI.BloodIsInfected(c.character) then c.afflictions[i].strength = 0 end
    end}

--provobacter infection
    NT.LimbAfflictions.limbprovo={update=function(c,limbaff,i,type)
        if not NTI.LimbIsInfected(c.character, type) then limbaff[i].strength = 0 end
    end}

    NT.Afflictions.bloodprovo={update=function(c,i)
        if not NTI.BloodIsInfected(c.character) then c.afflictions[i].strength = 0 end
    end}


--symptoms
    local abscesscauses = {"limbstrep", "limbstaph", "limbmrsa", "limbpseudo", "limbprovo"}

    NT.LimbAfflictions.abscess={update=function(c,limbaff,i,type)
        local inflev = NTI.LimbInfectionLevelList(c.character, type, abscesscauses)

        if inflev > 25 and not NTI.HasWound(c, limbaff, type) then
            if limbaff[i].strength <= 0 then
                limbaff[i].strength = HF.BoolToNum(HF.Chance((inflev/400)^2), 2)
            end
        else
            limbaff[i].strength = 0
        end
    end}

    local pusyellowcauses = {"limbstrep", "limbstaph", "limbmrsa", "limbprovo"}

    NT.LimbAfflictions.pusyellow={update=function(c,limbaff,i,type)
        local inflev = NTI.LimbInfectionLevelList(c.character, type, pusyellowcauses)

        if inflev > 25 and NTI.HasWound(c, limbaff, type) then
            if limbaff[i].strength <= 0 then
                limbaff[i].strength = HF.BoolToNum(HF.Chance((inflev/400)^2), 2)
            end
        else
            limbaff[i].strength = 0
        end
    end}

    local pusgreencauses = {"limbpseudo"}

    NT.LimbAfflictions.pusgreen={update=function(c,limbaff,i,type)
        local inflev = NTI.LimbInfectionLevelList(c.character, type, pusgreencauses)

        if inflev > 25 and NTI.HasWound(c, limbaff, type) then
            if limbaff[i].strength <= 0 then
                limbaff[i].strength = HF.BoolToNum(HF.Chance((inflev/400)^2), 2)
            end
        else
            limbaff[i].strength = 0
        end
    end}


--diseases
    NT.LimbAfflictions.cellulitis={update=function(c,limbaff,i,type)
        if NT.LimbIsAmputated(c.character, type) or HF.GetAfflictionStrengthLimb(c.character, type, "necfasc", 0) > 0 or not NTI.LimbIsInfected(c.character, type) then
            limbaff[i].strength=0
            return
        end

        if c.stats.stasis then return end

        local inf = HF.GetAfflictionStrengthLimb(c.character, type, "infectionlevel", 0)

        if limbaff[i].strength <= 0 then
            if HF.Chance(inf / (600 + c.afflictions.immunity.strength * 2)) then
                limbaff[i].strength = 1
            end
        else 
            local name = NTI.GetCurrentBacteria(c.character, type)
            local antibiotic = 1
            if name ~= nil then
                local info = NTI.Bacterias[name]
                antibiotic = NTI.GetAntibioticValue(c.character, info.antibiotics)
            end

            limbaff[i].strength = limbaff[i].strength + (-(HF.GetAfflictionStrengthLimb(c.character, type, "immuneresponse", 0) / 200) + HF.Clamp(inf / 100, 0, 1) * antibiotic)
        end
    end}

    NT.LimbAfflictions.necfasc={update=function(c,limbaff,i,type)
        if NT.LimbIsAmputated(c.character, type) or not NTI.NotHead(type, false) then
            limbaff[i].strength=0
            return
        end

        if c.stats.stasis then return end

        local inf = HF.GetAfflictionStrengthLimb(c.character, type, "infectionlevel", 0)

        if limbaff[i].strength <= 0 then
            if HF.Chance((inf / 1500) * ((100 - c.afflictions.immunity.strength) / 1500)) then
                limbaff[i].strength = 1
                HF.SetAfflictionLimb(c.character, "cellulitis", type, 0)
            end
        else
            local name = NTI.GetCurrentBacteria(c.character, type)
            local antibiotic = 1
            if name ~= nil then
                local info = NTI.Bacterias[name]
                antibiotic = NTI.GetAntibioticValue(c.character, info.antibiotics)
            end

            limbaff[i].strength = limbaff[i].strength + HF.Clamp(inf / 100, 0.05, 1) * antibiotic

            local infchance = limbaff[i].strength / 1000
            if(HF.Chance(infchance)) then
                NTI.InfectCharacterRandom(c.character, type)
            end
        end
    end}

    NT.Afflictions.pneumonia={update=function(c,i)
        if c.stats.stasis then return end

        local bil = HF.GetAfflictionStrength(c.character, "bloodinfectionlevel", 0)
        local vir = HF.GetAfflictionStrength(c.character, "virallevel", 0)

        if c.afflictions[i].strength <= 0 then
            if not (bil > 0 or vir > 75) then return end

            if HF.Chance(1 / (300 + c.afflictions.immunity.strength - bil - (vir / 2))) then
                c.afflictions[i].strength = 1
                return
            end
        else
            NTI.CheckSymptom(c.character, "sym_cough", c.afflictions[i].strength, 5, 0.2)
            NTI.CheckSymptom(c.character, "dyspnea", c.afflictions[i].strength, 10, 0.1)
            if c.afflictions.sym_unconsciousness.strength<=0 and not c.stats.sedated then 
                NTI.CheckSymptom(c.character, "pain_chest", c.afflictions[i].strength, 40, 0.1)
            end
            NTI.CheckSymptom(c.character, "triggersym_respiratoryarrest", c.afflictions[i].strength, 80, 0.1)
            c.afflictions[i].strength = c.afflictions[i].strength + (-(c.afflictions.immunity.strength / 500) + HF.Clamp((bil / 100) + (vir / 200), 0, 1))
        end
    end}


--overriding other mods stuff
    if (NTSP ~= nil) then
        NTSP.TriggerUnsterilityEvent=function(character)
            NTI.TriggerUnsterilityEvent(character)
        end
    end

    if (NTSPU ~= nil) then
        NTSPU.TriggerUnsterilityEvent=function(character)
            NTI.TriggerUnsterilityEvent(character)
        end
    end
end,1)
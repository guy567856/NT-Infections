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
        local bloodinf = NTI.BloodInfectionLevel(c.character)
        if bloodinf > 0 then
            c.afflictions[i].strength = c.afflictions[i].strength + HF.Clamp(bloodinf / 200, 0, 1) + (NTI.GetTotalNecValue(c.character) / 400)
            return
        end
        c.afflictions[i].strength = c.afflictions[i].strength - NT.Deltatime
    end}

--override for fever to be caused by other shit
    local fever_temp = NT.Afflictions.fever.update
    NT.Afflictions.fever={update=function(c,i) 
        fever_temp(c, i)
        c.afflictions[i].strength = c.afflictions[i].strength + HF.BoolToNum(HF.GetAfflictionStrength(c.character, "europancough", 0) > 25, 2)
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
        limbaff[i].strength = HF.BoolToNum(NTI.LimbIsInfected(c.character, type), 0.5) + (1.5 * (NTI.LimbInfectionLevel(c.character, type) / 100))
        
        if limbaff.foreignbody.strength > 15 then
            limbaff[i].strength = 2
        end
    end}

--remdesivir causes jaundice
    local jaundice_temp = NT.Afflictions.sym_jaundice.update
    NT.Afflictions.sym_jaundice={update=function(c,i)
        jaundice_temp(c, i)
        c.afflictions[i].strength = c.afflictions[i].strength + HF.BoolToNum(HF.GetAfflictionStrength(c.character, "afremdesivir", 0) > 70, 2)
    end}

--europan cough symptoms
    local headache_temp = NT.Afflictions.sym_headache.update
    NT.Afflictions.sym_headache={update=function(c,i)
        headache_temp(c, i)
        c.afflictions[i].strength = c.afflictions[i].strength + HF.BoolToNum(c.afflictions.sym_unconsciousness.strength<=0 and not c.stats.sedated and (c.afflictions.europancough.strength > 80 or HF.GetAfflictionStrength(c.character, "afremdesivir", 0) > 80), 2)
    end}

    local weakness_temp = NT.Afflictions.sym_weakness.update
    NT.Afflictions.sym_weakness={update=function(c,i)
        weakness_temp(c, i)
        c.afflictions[i].strength = c.afflictions[i].strength + HF.BoolToNum(c.afflictions.europancough.strength > 60, 2)
    end}

    local wheeze_temp = NT.Afflictions.sym_wheezing.update
    NT.Afflictions.sym_wheezing={update=function(c,i)
        wheeze_temp(c, i)
        c.afflictions[i].strength = c.afflictions[i].strength + HF.BoolToNum(c.afflictions.europancough.strength > 50 and c.afflictions.respiratoryarrest.strength<=0, 2)
    end}

    local naus_temp = NT.Afflictions.sym_nausea.update
    NT.Afflictions.sym_nausea={update=function(c,i)
        naus_temp(c, i)
        c.afflictions[i].strength = c.afflictions[i].strength + HF.BoolToNum(c.afflictions.europancough.strength > 70 or HF.GetAfflictionStrength(c.character, "afdextromethorphan", 0) > 80 or HF.GetAfflictionStrength(c.character, "afremdesivir", 0) > 75, 2)
    end}

--sepsis, fasciitis, and pneumonia causes pain
    local pain_abd_temp = NT.Afflictions.pain_abdominal.update
    NT.Afflictions.pain_abdominal={update=function(c,i)
        pain_abd_temp(c, i)
        c.afflictions[i].strength = c.afflictions[i].strength + HF.BoolToNum(c.afflictions.sym_unconsciousness.strength<=0 and not c.stats.sedated and c.afflictions.sepsis.strength > 20,2)
    end}

    local pain_chest_temp = NT.Afflictions.pain_chest.update
    NT.Afflictions.pain_chest={update=function(c,i) 
        pain_chest_temp(c, i)
        c.afflictions[i].strength = c.afflictions[i].strength + HF.BoolToNum(c.afflictions.sym_unconsciousness.strength<=0 and (c.afflictions.pneumonia.strength > 40 or c.afflictions.europancough.strength > 80),2)
    end}

    local pain_ext_temp = NT.LimbAfflictions.pain_extremity.update
    NT.LimbAfflictions.pain_extremity={max=10,update=function(c,limbaff,i,type)
        pain_ext_temp(c, limbaff, i, type)

        if c.afflictions.sym_unconsciousness.strength>0 then limbaff[i].strength = 0 return end
        limbaff[i].strength = limbaff[i].strength + (HF.BoolToNum(c.afflictions.sepsis.strength > 50 or HF.HasAfflictionLimb(c.character, "necfasc", type, 10), 2) - HF.BoolToNum(c.stats.sedated,100)) * NT.Deltatime
    end}

--pneumonia causing a cough
    local cough_temp = NT.Afflictions.sym_cough.update
    NT.Afflictions.sym_cough={update=function(c,i)
        cough_temp(c, i)
        c.afflictions[i].strength = c.afflictions[i].strength + HF.BoolToNum(c.afflictions.pneumonia.strength > 5 or c.afflictions.europancough.strength > 15, 2)
        if HF.HasAffliction(c.character, "afdextromethorphan") then
            c.afflictions[i].strength = 0
        end
    end}

--pneumonia causing shortness of breath
    local dyspnea_temp = NT.Afflictions.dyspnea.update
    NT.Afflictions.dyspnea={update=function(c,i)
        dyspnea_temp(c, i)

        c.afflictions[i].strength = c.afflictions[i].strength + HF.BoolToNum(c.afflictions.pneumonia.strength > 10 or c.afflictions.europancough.strength > 40, 2)
    end}

--pneumonia and europan cough causing hypoxemia
    NT.Afflictions.hypoxemia={update=function(c,i)
        if c.stats.stasis then return end
        -- completely cancel out hypoxemia regeneration if penumothorax is full as well as pneumonia and europan cough
        c.stats.availableoxygen = math.min(c.stats.availableoxygen,100-c.afflictions.pneumothorax.strength/2,100-c.afflictions.pneumonia.strength/2, 100-c.afflictions.europancough.strength/3)

        local hypoxemiagain = NTC.GetMultiplier(c.character,"hypoxemiagain")
        local regularHypoxemiaChange = (-c.stats.availableoxygen+50) / 8
        if regularHypoxemiaChange > 0 then
            -- not enough oxygen, increase hypoxemia
            regularHypoxemiaChange = regularHypoxemiaChange * hypoxemiagain
        else
            -- enough oxygen, decrease hypoxemia
            regularHypoxemiaChange = HF.Lerp(regularHypoxemiaChange * 2,0,HF.Clamp((50-c.stats.bloodamount)/50,0,1))
        end
        c.afflictions.hypoxemia.strength = HF.Clamp(c.afflictions.hypoxemia.strength + (
            - math.min(0,(c.afflictions.bloodpressure.strength-70) / 7) * hypoxemiagain    -- loss because of low blood pressure (+10 at 0 bp)
            - math.min(0,(c.stats.bloodamount-60) / 4) * hypoxemiagain      -- loss because of low blood amount (+15 at 0 blood)
            + regularHypoxemiaChange                                -- change because of oxygen in lungs (+6.25 <> -12.5)
        )* NT.Deltatime,0,100)
    end}

--pneumonia causing respiratory arrest
    local resp_temp = NT.Afflictions.respiratoryarrest.update
    NT.Afflictions.respiratoryarrest={update=function(c,i)
        resp_temp(c, i)

        if c.afflictions.europancough.strength > 95 or c.afflictions.pneumonia.strength > 90 then
            c.afflictions[i].strength = c.afflictions[i].strength + 10
        end
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
        if c.afflictions[i].strength > 90 then
            HF.AddAffliction(c.character,"psychosis",1)
        end
    end}

--immunocompromised affliction
    NT.Afflictions.immunodeficiency={update=function(c,i)
        if (c.afflictions.radiationsickness.strength > 50) then
            c.afflictions[i].strength = 100;
        else
            c.afflictions[i].strength = 0;
        end
    end}

--the immune response to a limb infection
    NT.LimbAfflictions.immuneresponse={update=function(c,limbaff,i,type)
        if c.stats.stasis then return end

        local inf_level = NTI.LimbInfectionLevel(c.character, type)

        if inf_level > 0 then
            limbaff[i].strength = limbaff[i].strength + ((c.afflictions.immunity.strength - 50) / 100)
        else
            limbaff[i].strength = limbaff[i].strength - 1
        end
    end}

--immune response for the whole body (in response to blood infection or viruses)
    NT.Afflictions.systemicresponse={update=function(c,i)
        if c.stats.stasis then return end

        if (NTI.BloodIsInfected(c.character) or HF.HasAffliction(c.character, "europancough")) then
            c.afflictions[i].strength = c.afflictions[i].strength + ((c.afflictions.immunity.strength - 50) / 100)
        else
            c.afflictions[i].strength = c.afflictions[i].strength - 1
        end
    end}

--viral infection severity for viral infection stuff
    NT.Afflictions.viralseverity={update=function(c,i)
        if c.afflictions[i].strength > 0 then
            if (not NTI.HasViralInfection(c.character)) then
                c.afflictions[i].strength = 0
            end
        end
    end}

--europan cough test
    NT.Afflictions.europancough={update=function(c,i)
        if c.stats.stasis then return end

        if (c.afflictions[i].strength > 0) then
            local coughmed = HF.BoolToNum(HF.HasAffliction(c.character, "afdextromethorphan"), 50) + HF.BoolToNum(HF.HasAffliction(c.character, "analgesia"), 50)
            c.stats.speedmultiplier = c.stats.speedmultiplier*(1 - (c.afflictions[i].strength / (150 + coughmed)))

            local gain = (0.4 + (HF.GetAfflictionStrength(c.character, "viralseverity", 0) / 10)) * (1 - HF.BoolToNum(HF.HasAffliction(c.character, "afremdesivir"), 0.75))
            c.afflictions[i].strength = c.afflictions[i].strength + gain - (gain + (0.1 + HF.BoolToNum(HF.HasAffliction(c.character, "viralantibodies", 0), 0.3))) * (HF.GetAfflictionStrength(c.character, "systemicresponse", 0) / 100)

            if (HF.Chance(0.05)) then
                for _, targetcharacter in pairs(Character.CharacterList) do
                    local distance = HF.CharacterDistance(c.character,targetcharacter)
                    if targetcharacter ~= c.character and targetcharacter.IsHuman and distance < 300 and not HF.HasAffliction(targetcharacter, "europancough") then
                        local head = NTI.WearingNeededHead(targetcharacter, {{"sterile", 7}, {"diving", 3}}) + NTI.WearingNeededHead(c.character, {{"sterile", 7}, {"diving", 3}})
                        local outer = NTI.WearingNeededOuter(targetcharacter, {{"diving", 3}, {"divinghelmet", 3}}) + NTI.WearingNeededOuter(c.character, {{"diving", 3}, {"divinghelmet", 3}})
                        local anticough = HF.BoolToNum(HF.HasAffliction(c.character, "afdextromethorphan"), 5)

                        local chance = HF.Clamp(((distance / 3) + HF.GetAfflictionStrength(targetcharacter, "immunity", 0)) / 10, 1, 20) + head + outer + anticough
                         + HF.Clamp(20 - HF.GetAfflictionStrength(c.character, "europancough", 0), 0, 20) + HF.BoolToNum(not targetcharacter.IsOnPlayerTeam and not targetcharacter.IsPlayer, 20)

                        if (HF.Chance(1 / chance)) then
                            NTI.InfectCharacterViral(targetcharacter, "europancough", 1)
                        end
                    end
                end
            end

            if (c.afflictions[i].strength <= 0) then
                HF.SetAffliction(c.character, "viralantibodies", 100)
            end
        end
    end}

--determines how fast an infection will progress
    NT.LimbAfflictions.infectionseverity={update=function(c,limbaff,i,type)
        if not NTI.LimbIsInfected(c.character, type) then
            limbaff[i].strength = 0
        end
    end}

--the current progress of the infection
    NT.LimbAfflictions.infectionlevel={update=function(c,limbaff,i,type)
        if c.stats.stasis then return end

        if limbaff[i].strength > 0 then
            local inf_info = NTI.GetInfectionInfoLimb(c.character, type) --{limbname, bloodname, probability, speed, antibiotics[name, level], sample, vaccine}
            local ab = NTI.GetAntibioticValue(c.character, inf_info[5])
            local inc = HF.Clamp(inf_info[4] + (HF.GetAfflictionStrengthLimb(c.character, type, "infectionseverity", 1) / 5), 0, 1.05) * ab
            - (HF.GetAfflictionStrengthLimb(c.character, type, "immuneresponse", 0) / 100)
            - ((HF.GetAfflictionStrength(c.character, inf_info[7], 0) / 2400) * (c.afflictions.immunity.strength / 100))

            limbaff[i].strength = limbaff[i].strength + inc

            if limbaff[i].strength > 50 and (HF.Chance(((limbaff[i].strength - 50) / 50)^5) or HF.Chance(HF.GetAfflictionStrengthLimb(c.character, type, "necfasc", 0) / 1000)) and HF.GetAfflictionStrength(c.character, inf_info[2], 0) <= 0 then
                HF.SetAffliction(c.character, inf_info[2], 1)
            end
        end
    end}

--streptococcal infection
    NT.LimbAfflictions.limbstrep={update=function(c,limbaff,i,type)
        if not NTI.LimbIsInfected(c.character, type) then
            limbaff[i].strength = 0
        end
    end}

    NT.Afflictions.bloodstrep={update=function(c,i)
        if c.stats.stasis then return end

        if (c.afflictions[i].strength > 0) then
            c.afflictions[i].strength = c.afflictions[i].strength + NTI.BloodInfUpdate(c.character, NTI.anti_strep, "afstrepvac")
        end
    end}

--staphylococcal infection
    NT.LimbAfflictions.limbstaph={update=function(c,limbaff,i,type)
        if not NTI.LimbIsInfected(c.character, type) then
            limbaff[i].strength = 0
        end
    end}

    NT.Afflictions.bloodstaph={update=function(c,i)
        if c.stats.stasis then return end

        if (c.afflictions[i].strength > 0) then
            c.afflictions[i].strength = c.afflictions[i].strength + NTI.BloodInfUpdate(c.character, NTI.anti_staph, "afstaphvac")
        end
    end}

--mrsa infection
    NT.LimbAfflictions.limbmrsa={update=function(c,limbaff,i,type)
        if not NTI.LimbIsInfected(c.character, type) then
            limbaff[i].strength = 0
        end
    end}

    NT.Afflictions.bloodmrsa={update=function(c,i)
        if c.stats.stasis then return end

        if (c.afflictions[i].strength > 0) then
            c.afflictions[i].strength = c.afflictions[i].strength + NTI.BloodInfUpdate(c.character, NTI.anti_mrsa, "afstaphvac")
        end
    end}

--pseudomonas infection
    NT.LimbAfflictions.limbpseudo={update=function(c,limbaff,i,type)
        if not NTI.LimbIsInfected(c.character, type) then
            limbaff[i].strength = 0
        end
    end}

    NT.Afflictions.bloodpseudo={update=function(c,i)
        if c.stats.stasis then return end

        if (c.afflictions[i].strength > 0) then
            c.afflictions[i].strength = c.afflictions[i].strength + NTI.BloodInfUpdate(c.character, NTI.anti_pseudo, "afpseudovac")
        end
    end}

--provobacter infection
    NT.LimbAfflictions.limbprovo={update=function(c,limbaff,i,type)
        if not NTI.LimbIsInfected(c.character, type) then
            limbaff[i].strength = 0
        end
    end}

    NT.Afflictions.bloodprovo={update=function(c,i)
        if c.stats.stasis then return end

        if (c.afflictions[i].strength > 0) then
            c.afflictions[i].strength = c.afflictions[i].strength + NTI.BloodInfUpdate(c.character, NTI.anti_provo, "afprovovac")
        end
    end}

--symptoms
    local pusyellowcauses = {
        "limbstrep", "limbstaph", "limbmrsa", "limbprovo"
    }

    NT.LimbAfflictions.pusyellow={update=function(c,limbaff,i,type)
        local inflev = NTI.LimbInfectionLevelList(c.character, type, pusyellowcauses)
        local wound = limbaff.burn.strength
        + limbaff.lacerations.strength
        + limbaff.gunshotwound.strength
        + limbaff.bitewounds.strength
        + limbaff.explosiondamage.strength
        + HF.GetAfflictionStrengthLimb(c.character, type, "suturedw", 0)
        + HF.GetAfflictionStrengthLimb(c.character, type, "surgeryincision", 0)

        if wound > 0 and inflev > 25 then
            if limbaff[i].strength <= 0 then
                limbaff[i].strength = HF.BoolToNum(HF.Chance((inflev/400)^2), 2)
            end
        else
            limbaff[i].strength = 0
        end
    end}

    local pusgreencauses = {
        "limbpseudo"
    }

    NT.LimbAfflictions.pusgreen={update=function(c,limbaff,i,type)
        local inflev = NTI.LimbInfectionLevelList(c.character, type, pusgreencauses)
        local wound = limbaff.burn.strength
        + limbaff.lacerations.strength
        + limbaff.gunshotwound.strength
        + limbaff.bitewounds.strength
        + limbaff.explosiondamage.strength
        + HF.GetAfflictionStrengthLimb(c.character, type, "suturedw", 0)
        + HF.GetAfflictionStrengthLimb(c.character, type, "surgeryincision", 0)

        if wound > 0 and inflev > 25 then
            if limbaff[i].strength <= 0 then
                limbaff[i].strength = HF.BoolToNum(HF.Chance((inflev/400)^2), 2)
            end
        else
            limbaff[i].strength = 0
        end
    end}

    local abscesscauses = {
        "limbstrep", "limbstaph", "limbmrsa", "limbpseudo", "limbprovo"
    }

    NT.LimbAfflictions.abscess={update=function(c,limbaff,i,type)
        local inflev = NTI.LimbInfectionLevelList(c.character, type, abscesscauses)
        local wound = limbaff.burn.strength
        + limbaff.lacerations.strength
        + limbaff.gunshotwound.strength
        + limbaff.bitewounds.strength
        + limbaff.explosiondamage.strength
        + HF.GetAfflictionStrengthLimb(c.character, type, "suturedw", 0)
        + HF.GetAfflictionStrengthLimb(c.character, type, "surgeryincision", 0)

        if wound <= 0 and inflev > 25 then
            if limbaff[i].strength <= 0 then
                limbaff[i].strength = HF.BoolToNum(HF.Chance((inflev/400)^2), 2)
            end
        else
            limbaff[i].strength = 0
        end
    end}

--diseases
    NT.Afflictions.pneumonia={update=function(c,i)
        if c.stats.stasis then return end

        local bil = NTI.BloodInfectionLevel(c.character)

        if c.afflictions[i].strength <= 0 then
            if HF.Chance(1 / (250 + c.afflictions.immunity.strength)) and bil > 0 then
                c.afflictions[i].strength = 1
                return
            end
        else
            c.afflictions[i].strength = c.afflictions[i].strength + (-(c.afflictions.immunity.strength / 500) + HF.Clamp(bil / 100, 0, 1))
        end
    end}

    NT.LimbAfflictions.necfasc={update=function(c,limbaff,i,type)
        if(NT.LimbIsSurgicallyAmputated(c.character,type) or not NTI.NotHead(type, false)) then
            limbaff[i].strength=0
            return
        end

        if c.stats.stasis then return end

        local inf = NTI.LimbInfectionLevel(c.character, type)

        if limbaff[i].strength <= 0 then
            if HF.Chance((inf / 1500) * ((100 - c.afflictions.immunity.strength) / 1500)) then
                local start = HF.GetAfflictionStrengthLimb(c.character, type, "cellulitis", 0) * 0.1
                limbaff[i].strength = start
                HF.SetAfflictionLimb(c.character, "cellulitis", type, 0)
            end
        else
            local inf_info = NTI.GetInfectionInfoLimb(c.character, type) --{limbname, bloodname, probability, speed, antibiotics[name, level]}
            local ab = NTI.GetAntibioticValue(c.character, inf_info[5])
            limbaff[i].strength = limbaff[i].strength + HF.Clamp(inf / 100, 0.05, 1) * ab

            local infchance = limbaff[i].strength / 1000
            if(HF.Chance(infchance)) then
                NTI.InfectCharacterRandom(c.character, type)
            end
        end
    end}

    NT.LimbAfflictions.cellulitis={update=function(c,limbaff,i,type)
        if(NT.LimbIsSurgicallyAmputated(c.character,type) or HF.GetAfflictionStrengthLimb(c.character, type, "necfasc", 0) > 0 or not NTI.LimbIsInfected(c.character, type)) then
            limbaff[i].strength=0
            return
        end

        if c.stats.stasis then return end

        local inf = NTI.LimbInfectionLevel(c.character, type)

        if limbaff[i].strength <= 0 then
            if HF.Chance(inf / (500 + (c.afflictions.immunity.strength * 2))) then
                limbaff[i].strength = 1
            end
        else 
            local inf_info = NTI.GetInfectionInfoLimb(c.character, type) --{limbname, bloodname, probability, speed, antibiotics[name, level]}
            local ab = NTI.GetAntibioticValue(c.character, inf_info[5])
            limbaff[i].strength = limbaff[i].strength + (-(c.afflictions.immunity.strength / 400) + HF.Clamp(inf / 100, 0, 1) * ab) --(-0.2 + HF.Clamp(inf / 100, 0, 1))
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
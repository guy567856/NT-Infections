Timer.Wait(function()
    --additional hematology tags
    NTI.MoreHematologyDetectable = {
        "afampicillin",
        "afaugmentin",
        "afvancomycin",
        "afgentamicin",
        "afcotrim",
        "afimipenem",
        "afdextromethorphan",
        "afremdesivir",
        "afzincsupplement",
        "afceftazidime",
        "afcorticosteroids",
        "bloodinfectionlevel",
    }

    --add the new hematology tags into the nt hematology list
    for i = 1, #NTI.MoreHematologyDetectable do
        NTC.AddHematologyAffliction(NTI.MoreHematologyDetectable[i])
    end

    --the sampler tool item
    NT.ItemMethods.cultureanalyzer = function(item, usingCharacter, targetCharacter, limb)
        local containedItem = item.OwnInventory.GetItemAt(0)

        if containedItem ~= nil then
            local function postSpawnFunc(args)
                args.item.Condition = args.condition
            end

            if containedItem.HasTag("viraltest") then
                local params = {condition=100}
                local name = NTI.GetCurrentVirus(targetCharacter)

                if name ~= nil then
                    local info = NTI.Viruses[name]
                    HF.GiveItemPlusFunction(info.samplename,postSpawnFunc,params,usingCharacter)
                else
                    HF.GiveItemPlusFunction("emptyviralunk",postSpawnFunc,params,usingCharacter)
                end

                HF.DMClient(HF.CharacterToClient(usingCharacter),"Sampler tool\n\nSwab sample found.",Color(127,255,127,255))
            else
                local params = {condition=100}
                local name = nil
                local pus = HF.GetAfflictionStrengthLimb(targetCharacter, limb.type, "pusyellow", 0) + HF.GetAfflictionStrengthLimb(targetCharacter, limb.type, "pusgreen", 0)

                if pus > 0 then
                    name = NTI.GetCurrentBacteria(targetCharacter, limb.type)
                    HF.DMClient(HF.CharacterToClient(usingCharacter),"Sampler tool\n\nPus sample found.",Color(127,255,127,255))
                elseif HF.HasAfflictionLimb(targetCharacter, "abscess", limb.type, 0) then
                    name = NTI.GetCurrentBacteria(targetCharacter, limb.type)
                    HF.AddAfflictionLimb(targetCharacter,"lacerations",limb.type,4,usingCharacter)
                    HF.DMClient(HF.CharacterToClient(usingCharacter),"Sampler tool\n\nPus sample found.",Color(127,255,127,255))
                elseif HF.HasAfflictionLimb(targetCharacter, "retractedskin", limb.type, 0) then
                    name = NTI.GetCurrentBacteria(targetCharacter, limb.type)
                    HF.AddAfflictionLimb(targetCharacter,"lacerations",limb.type,8,usingCharacter)
                    HF.DMClient(HF.CharacterToClient(usingCharacter),"Sampler tool\n\nTissue sample found.",Color(127,255,127,255))
                else
                    name = NTI.GetCurrentBacteriaBloodRandom(targetCharacter)
                    HF.DMClient(HF.CharacterToClient(usingCharacter),"Sampler tool\n\nBlood sample found.",Color(127,255,127,255))
                end

                if name ~= nil then
                    local info = NTI.Bacterias[name]
                    HF.GiveItemPlusFunction(info.samplename,postSpawnFunc,params,usingCharacter)
                else
                    HF.GiveItemPlusFunction("emptytubeunk",postSpawnFunc,params,usingCharacter)
                end
            end

            HF.RemoveItem(containedItem)
        else
            local string = "Sampler tool\nBloodwork readout:\n"
            local total = 0
            local infections = {}

            for key, info in pairs(NTI.Bacterias) do
                local strength = HF.GetAfflictionStrength(targetCharacter, info.bloodname, 0)

                if strength > 0 then
                    infections[key] = strength
                    total = total + strength
                end
            end

            if total <= 0 then
                string = string .. "\nNo bacterial presence in blood."
            else
                local bacteremia = targetCharacter.CharacterHealth.GetAffliction("bloodinfectionlevel")
                local bil = HF.GetAfflictionStrength(targetCharacter, "bloodinfectionlevel", 0)
                if bacteremia ~= nil then string = string .. bacteremia.Prefab.Name.Value .. ": " .. HF.Round(bil) .. "%" .. "\n" end
                for key, value in pairs(infections) do
                    local affliction = targetCharacter.CharacterHealth.GetAffliction(NTI.Bacterias[key].bloodname)
                    string = string .. "\n" .. affliction.Prefab.Name.Value .. ": " .. HF.Round((value / total) * 100) .. "%"
                end
            end

            HF.DMClient(HF.CharacterToClient(usingCharacter),string,Color(127,255,127,255))
        end
    end

    --override suture function and add it so that a necrotized limb is not dropped during amputation
    local tempSutureFunction = NT.ItemMethods.suture
    NT.ItemMethods.suture = function(item, usingCharacter, targetCharacter, limb)
        if(HF.GetSkillRequirementMet(usingCharacter,"medical",30)) then
            local limbtype = HF.NormalizeLimbType(limb.type)

            if HF.HasAfflictionLimb(targetCharacter,"bonecut",limbtype,1) then
                local previtem = HF.GetHeadWear(targetCharacter)
                if previtem ~= nil and limbtype == LimbType.Head then
                    previtem.Drop(usingCharacter, true)
                end
                local droplimb =
                    not NT.LimbIsAmputated(targetCharacter,limbtype)
                    and not HF.HasAfflictionLimb(targetCharacter,"gangrene",limbtype,15)
                    and not HF.HasAfflictionLimb(targetCharacter,"infectionlevel",limbtype,20)
                    and not HF.HasAfflictionLimb(targetCharacter,"necfasc",limbtype,1)
                NT.SurgicallyAmputateLimb(targetCharacter,limbtype)
                if (droplimb) then
                    local limbtoitem = {}
                    limbtoitem[LimbType.RightLeg] = "rleg"
                    limbtoitem[LimbType.LeftLeg] = "lleg"
                    limbtoitem[LimbType.RightArm] = "rarm"
                    limbtoitem[LimbType.LeftArm] = "larm"
                    limbtoitem[LimbType.Head] = "headsa"
                    if limbtoitem[limbtype] ~= nil then
                        HF.GiveItem(usingCharacter, limbtoitem[limbtype])
                        HF.GiveSurgerySkill(usingCharacter, 0.5)
                    end
                end
            end
        end

        tempSutureFunction(item, usingCharacter, targetCharacter, limb)
    end

    --override scalpel function and add it so that it can debride necrotic tissue
    local tempScalpelFunction = NT.ItemMethods.advscalpel
    NT.ItemMethods.advscalpel = function(item, usingCharacter, targetCharacter, limb) 
        tempScalpelFunction(item,usingCharacter,targetCharacter,limb)
        local limbtype = HF.NormalizeLimbType(limb.type)

        if(HF.HasAffliction(targetCharacter,"stasis",0.1)) then return end

        if not HF.HasAfflictionLimb(targetCharacter, "necfasc", limbtype, 0) or not HF.HasAfflictionLimb(targetCharacter,"retractedskin",limbtype,0.1) then
            return
        else
            local function healAfflictionGiveSkill(identifier,healamount,skillgain) 
                local affAmount = HF.GetAfflictionStrengthLimb(targetCharacter,limbtype,identifier)
                local healedamount = math.min(affAmount,healamount)
                HF.AddAfflictionLimb(targetCharacter,identifier,limbtype,-healamount,usingCharacter)
                
                if NTSP ~= nil and NTConfig.Get("NTSP_enableSurgerySkill",true) then 
                    HF.GiveSkillScaled(usingCharacter,"surgery",healedamount*skillgain)
                else 
                    HF.GiveSkillScaled(usingCharacter,"medical",healedamount*skillgain/2)
                end
            end

            if HF.GetSkillRequirementMet(usingCharacter,"medical",50) then
                healAfflictionGiveSkill("necfasc", 5, 20)
                HF.AddAfflictionLimb(targetCharacter,"lacerations",limbtype,8,usingCharacter)
            else
                healAfflictionGiveSkill("necfasc", 5, 20)
                HF.AddAfflictionLimb(targetCharacter,"bleeding",limbtype,5,usingCharacter)
                HF.AddAfflictionLimb(targetCharacter,"lacerations",limbtype,10,usingCharacter)
            end
            
            HF.GiveItem(targetCharacter,"ntsfx_slash")
        end
    end
end,1)
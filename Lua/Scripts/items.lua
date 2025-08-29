Timer.Wait(function()
    --additional hematology tags
    NTI.MoreHematologyDetectable = {
        "afampicillin", "afaugmentin", "afvancomycin", "afgentamicin","afcotrim","afimipenem","afstrepvac","afstaphvac","afpseudovac","afprovovac","afdextromethorphan","afremdesivir","afzincsupplement","afceftazidime"
    }

    --add all disease's bloodtags to the hematology analyzer
    for _, info in pairs(NTI.Bacterias) do
        NTC.AddHematologyAffliction(info.bloodname)
    end

    --add the new hematology tags into the nt hematology list
    for i = 1, #NTI.MoreHematologyDetectable do
        NTC.AddHematologyAffliction(NTI.MoreHematologyDetectable[i])
    end

    --culture analyzer item
    NT.ItemMethods.cultureanalyzer = function(item, usingCharacter, targetCharacter, limb)
        local containedItem = item.OwnInventory.GetItemAt(0)

        if containedItem ~= nil then
            local function postSpawnFunc(args)
                args.item.Condition = args.condition
            end

            if containedItem.HasTag("viraltest") then
                HF.RemoveItem(containedItem)
                local params = {condition=100}
                local name = NTI.GetCurrentVirus(targetCharacter)

                HF.DMClient(HF.CharacterToClient(usingCharacter),"Sample Collector\n\nSwab sample found.",Color(127,255,127,255))

                if name ~= nil then
                    local info = NTI.Viruses[name]
                    HF.GiveItemPlusFunction(info.sample,postSpawnFunc,params,usingCharacter)
                else
                    HF.GiveItemPlusFunction("emptyviralunk",postSpawnFunc,params,usingCharacter)
                end
            else
                HF.RemoveItem(containedItem)
                local params = {condition=0}
                local name = nil

                local puspresent = HF.GetAfflictionStrengthLimb(targetCharacter, limb.type, "pusyellow", 0)
                                + HF.GetAfflictionStrengthLimb(targetCharacter, limb.type, "pusgreen", 0)
                                + HF.GetAfflictionStrengthLimb(targetCharacter, limb.type, "abscess", 0)

                if puspresent > 0 then
                    HF.DMClient(HF.CharacterToClient(usingCharacter),"Sample Collector\n\nPus sample found.",Color(127,255,127,255))

                    name = NTI.GetCurrentBacteria(targetCharacter, limb.type)

                    if HF.HasAfflictionLimb(targetCharacter, "abscess", limb.type, 0) then
                        HF.AddAfflictionLimb(targetCharacter,"lacerations",limb.type,4,usingCharacter)
                        HF.SetAfflictionLimb(targetCharacter, "abscess", limb.type, 0)

                        if HF.GetAfflictionStrengthLimb(targetCharacter, limb.type, "limbpseudo", 0) > 0 then
                            HF.AddAfflictionLimb(targetCharacter,"pusgreen",limb.type,2,usingCharacter)
                        else
                            HF.AddAfflictionLimb(targetCharacter,"pusyellow",limb.type,2,usingCharacter)
                        end
                    end
                elseif HF.HasAfflictionLimb(targetCharacter, "retractedskin", limb.type, 0) then
                    HF.DMClient(HF.CharacterToClient(usingCharacter),"Sample Collector\n\nTissue sample found.",Color(127,255,127,255))

                    name = NTI.GetCurrentBacteria(targetCharacter, limb.type)

                    HF.AddAfflictionLimb(targetCharacter,"lacerations",limb.type,8,usingCharacter)
                else
                    HF.DMClient(HF.CharacterToClient(usingCharacter),"Sample Collector\n\nBlood sample found.",Color(127,255,127,255))

                    name = NTI.GetRandomWeightedBloodBacteria(targetCharacter)
                end

                if name ~= nil then
                    local info = NTI.Bacterias[name]
                    HF.GiveItemPlusFunction(info.samplename,postSpawnFunc,params,usingCharacter)
                else
                    HF.GiveItemPlusFunction("emptytubeunk",postSpawnFunc,params,usingCharacter)
                end
            end
        else
            HF.DMClient(HF.CharacterToClient(usingCharacter),"Sample Collector\n\nERROR\nNo sample medium provided.",Color(127,255,127,255))
        end
    end

    --override suture function and add it so that a necrotized limb is not dropped during amputation
    local tempSutureFunction = NT.ItemMethods.suture
    NT.ItemMethods.suture = function(item, usingCharacter, targetCharacter, limb)
        local limbtype = HF.NormalizeLimbType(limb.type)

        if(HF.GetSkillRequirementMet(usingCharacter,"medical",30)) then
            if HF.HasAfflictionLimb(targetCharacter,"bonecut",limbtype,1) then
                local droplimb =
                    not NT.LimbIsAmputated(targetCharacter,limbtype)
                    and not HF.HasAfflictionLimb(targetCharacter,"gangrene",limbtype,15)
                    and not HF.HasAfflictionLimb(targetCharacter,"necfasc",limbtype,1)
                NT.SurgicallyAmputateLimb(targetCharacter,limbtype)
                if (droplimb) then
                    local limbtoitem = {}
                    limbtoitem[LimbType.RightLeg] = "rleg"
                    limbtoitem[LimbType.LeftLeg] = "lleg"
                    limbtoitem[LimbType.RightArm] = "rarm"
                    limbtoitem[LimbType.LeftArm] = "larm"
                    if limbtoitem[limbtype] ~= nil then
                        HF.GiveItem(usingCharacter,limbtoitem[limbtype])
                        if NTSP ~= nil and NTConfig.Get("NTSP_enableSurgerySkill",true) then HF.GiveSkill(usingCharacter,"surgery",0.5) end
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

        if HF.HasAfflictionLimb(targetCharacter, "abscess", limbtype, 0) then
            HF.SetAfflictionLimb(targetCharacter, "abscess", limbtype, 0)

            if HF.HasAfflictionLimb(targetCharacter, "limbpseudo", limbtype, 0) then
                HF.SetAfflictionLimb(targetCharacter, "pusgreen", limbtype, 2)
            else
                HF.SetAfflictionLimb(targetCharacter, "pusyellow", limbtype, 2)
            end
        end

        if not HF.HasAfflictionLimb(targetCharacter, "necfasc", limbtype, 0) or not HF.HasAfflictionLimb(targetCharacter,"retractedskin",limbtype,0.1) then
            return
        else
            local function healAfflictionGiveSkill(identifier,healamount,skillgain) 
                local affAmount = HF.GetAfflictionStrengthLimb(targetCharacter,limbtype,identifier)
                local healedamount = math.min(affAmount,healamount)
                HF.AddAfflictionLimb(targetCharacter,identifier,limbtype,-healamount,usingCharacter)
                
                if NTSP ~= nil and usecase=="surgery" and NTConfig.Get("NTSP_enableSurgerySkill",true) then 
                    HF.GiveSkillScaled(usingCharacter,"surgery",healedamount*skillgain)
                else 
                    HF.GiveSkillScaled(usingCharacter,"medical",healedamount*skillgain/2)
                end
            end

            if(HF.GetSkillRequirementMet(usingCharacter,"medical",50)) then
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
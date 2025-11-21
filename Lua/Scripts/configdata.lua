NTI.ConfigData = {
    NTI_header1 = {name=NTI.Name,type="category"},

    NTI_strepPrevalence = {
		name = "Streptococcal Prevalence",
		default = 4,
		range = { 0, 100 },
		type = "float",
        description = "The 'number of names in the hat' for strep infections to be picked randomly. The higher the number, the more common it is. Should be an integer value.",
	},
    NTI_staphPrevalence = {
		name = "Staphylococcal Prevalence",
		default = 6,
		range = { 0, 100 },
		type = "float",
        description = "The 'number of names in the hat' for staph infections to be picked randomly. The higher the number, the more common it is. Should be an integer value.",
	},
    NTI_pseudoPrevalence = {
		name = "Pseudomonas Prevalence",
		default = 1,
		range = { 0, 100 },
		type = "float",
        description = "The 'number of names in the hat' for pseudomonas infections to be picked randomly. The higher the number, the more common it is. Should be an integer value.",
	},
    NTI_provoPrevalence = {
		name = "Provobacter Prevalence",
		default = 4,
		range = { 0, 100 },
		type = "float",
        description = "The 'number of names in the hat' for provobacter infections to be picked randomly. The higher the number, the more common it is. Should be an integer value.",
	},
	NTI_aeroPrevalence = {
		name = "Aeroganella Prevalence",
		default = 2,
		range = { 0, 100 },
		type = "float",
        description = "The 'number of names in the hat' for aeroganella infections to be picked randomly. The higher the number, the more common it is. Should be an integer value.",
	},
	NTI_mrsaChance = {
		name = "Base MRSA Chance",
		default = 0.3,
		range = { 0, 1 },
		type = "float",
        description = "The base percentage change for staph to become MRSA given antimicrobial resistance risk.",
	},

	NTI_viralSpreadChance = {
		name = "Viral Spread Chance",
		default = 0.1,
		range = { 0, 1 },
		type = "float",
        description = "The chance every NT tick that an infection spread occurs. The higher the more likely viruses will spread. Also expect worse server performance.",
	},
    NTI_europanChance = {
		name = "Europan Cough Chance Denominator",
		default = 120,
		range = { 1, 999 },
		type = "float",
        description = "The denominator for the chance a non-team member bot spawns with Europan cough, calculated as 1 / denominator. The bigger the number, the less likely it is.",
	},
    NTI_influenzaChance = {
		name = "Influenza Chance Denominator",
		default = 100,
		range = { 1, 999 },
		type = "float",
        description = "The denominator for the chance a non-team member bot spawns with influenza, calculated as 1 / denominator. The bigger the number, the less likely it is.",
	},
    NTI_coldChance = {
		name = "Common Cold Chance Denominator",
		default = 80,
		range = { 1, 999 },
		type = "float",
        description = "The denominator for the chance a non-team member bot spawns with a cold, calculated as 1 / denominator. The bigger the number, the less likely it is.",
	},

    NTI_canSpreadNextLimb = {
        name = "Bacterial Infections Can Spread",
		default = true,
		type = "bool",
        description = "Bacterial infections can spread to nearby limbs",
    },
}
NTConfig.AddConfigOptions(NTI)
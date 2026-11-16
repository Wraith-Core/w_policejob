PoliceCarryEvents = {
    begin = 'police:server:KidnapPlayer',
    release = 'police:server:ReleaseCarry',
    target = 'police:client:GetKidnappedTarget',
    carrier = 'police:client:GetKidnappedDragger',
}

-- RDR2 carryconfigdata.meta: INJURED_CARRIABLE_HUMAN_PED_CARRIED_BY_HUMAN_DATA_SET.
PoliceCarryFoot = {
    dict = 'mech_carry_ped@injured@carried@human',
    carried = 'carriedbyhuman_exp',
    grip = 'grip_lt_arm',
    bone = 'PH_L_CarriableShoulder',
}

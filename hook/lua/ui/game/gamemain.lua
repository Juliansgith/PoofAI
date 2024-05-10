local OldOnFirstUpdate = OnFirstUpdate
function OnFirstUpdate()
    OldOnFirstUpdate()
    ConExecute("WLD_GameSpeed 20")
end
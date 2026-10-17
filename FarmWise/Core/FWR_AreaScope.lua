local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

-- Where the player is, as far as the sub-zone goes. In the open world the name of the sub-zone is used (so the
-- Advisor can tell one place from the next). Inside something that is entered through a portal and left when it is
-- done - a dungeon, a raid, a delve and the other scenarios, a battleground, an arena - the sub-zone is left out:
-- there one cannot choose a part of it, the whole place is one area, and what is looted is counted for all of it.
function FWR:IsInWholeAreaInstance()
    if type(IsInInstance) ~= "function" then
        return false
    end
    local inInstance, kind = IsInInstance()
    return inInstance == true and kind ~= nil and kind ~= "none"
end

function FWR:GetAreaSubZoneText()
    if self:IsInWholeAreaInstance() then
        return ""
    end
    return type(GetSubZoneText) == "function" and GetSubZoneText() or ""
end

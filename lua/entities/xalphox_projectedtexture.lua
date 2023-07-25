AddCSLuaFile()

ENT.Type = "point"
ENT.Base = "base_entity"

ENT.PrintName = "env_projectedtexture2"
ENT.Author = "Xalphox"
ENT.Contact = ""
ENT.Purpose = ""
ENT.Instructions = ""
ENT.Editable = true

ENT.Spawnable = false
ENT.AdminSpawnable = false




local is_enabled
local max_projected
local scale_farz

if CLIENT then        
    is_enabled = CreateClientConVar("r_drawprojectedtextures", "1"):GetInt()
    max_projected = CreateClientConVar("r_maxprojectedtextures", "1"):GetInt()
    scale_farz = CreateClientConVar("r_projectedtexture_scalefarz", "1"):GetFloat()
    cvars.AddChangeCallback("r_drawprojectedtextures", function (cv, old, new)
        is_enabled = tonumber(new) or 1
        print("boop")
    end, "xalphox_projectedtexture")

    cvars.AddChangeCallback("r_maxprojectedtextures", function (cv, old, new)
        max_projected = tonumber(new) or 1
    end, "xalphox_projectedtexture")

    cvars.AddChangeCallback("r_projectedtexture_scalefarz", function (cv, old, new)
        scale_farz = tonumber(new) or 1
        
        PrintTable(ents.FindByClass("xalphox_projectedtexture"))
        for k, v in pairs(ents.FindByClass("xalphox_projectedtexture")) do
            print("scale_farz")
            v:Update()
        end
    end, "xalphox_projectedtexture")
end


function ENT:Initialize()
    self:SetStatic(true)
    self.PixVis = util.GetPixelVisibleHandle()
end

local KeyValues = {
    texturename = "TextureName",
    target = "Target",
    enableshadows = "EnableShadows",
    lightonlytarget = "LightOnlyTarget",
    lightworld = "LightWorld",
    static = "Static",
    farz = "FarZ",
    nearz = "NearZ",
    lightfov = "LightFOV",
    shadowquality = "ShadowQuality",
}
local NumProjectedTextures = 0

function ENT:SetupDataTables()

    self:NetworkVar("String", 0, "TextureName", { KeyName = "texturename", Edit = { type = "Generic", waitforenter = true } })
    self:NetworkVar("String", 1, "Target", { KeyName = "target", Edit = { type = "Generic", waitforenter = true } })
    self:NetworkVar("Bool", 1, "EnableShadows", { KeyName = "enableshadows", Edit = { type = "Boolean" } })
    self:NetworkVar("Bool", 2, "LightOnlyTarget", { KeyName = "lightonlytarget", Edit = { type = "Boolean" } })
    self:NetworkVar("Bool", 3, "LightWorld", { KeyName = "lightworld", Edit = { type = "Boolean" } })
    self:NetworkVar("Bool", 4, "Static", { KeyName = "static", Edit = { type = "Boolean" } })
    self:NetworkVar("Float", 0, "FarZ", { KeyName = "farz", Edit = { type = "Float", min = 0, max = 32568 } })
    self:NetworkVar("Float", 1, "NearZ", { KeyName = "nearz", Edit = { type = "Float", min = 0, max = 32568 } })
    self:NetworkVar("Float", 2, "LightFOV", { KeyName = "lightfov", Edit = { type = "Float", min = 0, max = 120 } })
    self:NetworkVar("Float", 3, "Brightness", { KeyName = "lightbrightness", Edit = { type = "Float", min = 0, max = 32568 } })
    self:NetworkVar("Int", 0, "ShadowQuality", { KeyName = "shadowquality", Edit = { type = "Int", min = 0, max = 1 } })
    self:NetworkVar("Vector", 0, "LightColor", { KeyName = "lightcolor", Edit = { type = "VectorColor" } })

    self:NetworkVarNotify("TextureName", self.Update)
    self:NetworkVarNotify("Target", self.Update)
    self:NetworkVarNotify("EnableShadows", self.Update)
    self:NetworkVarNotify("LightOnlyTarget", self.Update)
    self:NetworkVarNotify("LightWorld", self.Update)
    self:NetworkVarNotify("Static", self.Update)
    self:NetworkVarNotify("FarZ", self.Update)
    self:NetworkVarNotify("NearZ", self.Update)
    self:NetworkVarNotify("LightFOV", self.Update)
    self:NetworkVarNotify("Brightness", self.Update)
    self:NetworkVarNotify("ShadowQuality", self.Update)
    self:NetworkVarNotify("LightColor", self.Update)
end

function ENT:KeyValue(key, value)
    if key == "lightcolor" then
        local split = string.Split(value, " ")
        self:SetLightColor(Vector(tonumber(split[1]), tonumber(split[2]), tonumber(split[3])))
        self:SetBrightness(tonumber(split[4])/255)
    elseif KeyValues[key] then
        self["Set" .. KeyValues[key]](self, value)
    end

end 


if CLIENT then

    function ENT:Update()
        print("Update 1")

        if not IsValid(self.proj) then
            return
        end

        self.proj:SetPos(self:GetPos() + self:GetUp() * 32)
        self.proj:SetAngles(self:GetAngles())
        
        self.proj:SetTexture(self:GetTextureName())

        self.proj:SetEnableShadows(self:GetEnableShadows())
        self.proj:SetLightWorld(self:GetLightWorld())
        self.proj:SetFarZ(self:GetFarZ() * math.Clamp(scale_farz, 0.0, 1))
        self.proj:SetNearZ(self:GetNearZ())        
        self.proj:SetFOV(self:GetLightFOV())

        self.proj:SetQuadraticAttenuation(0)
        self.proj:SetConstantAttenuation(0)
        self.proj:SetLinearAttenuation(100)

        self.proj:SetColor(self:GetLightColor():ToColor())
        self.proj:SetBrightness(self:GetBrightness())

        self.proj:Update()
    end

    function ENT:IsHidden()
        if self:IsDormant() or is_enabled == 0 then
            return true
        end

        -- If we're not projected, and we've already exceeded our maximum number of projections,
        -- then don't show.
        if not self.proj and NumProjectedTextures >= max_projected then
            return true
        end

        -- Pixvis will return 0 when we're in its bounds, but if we're in its bounds, it almost
        -- certainly is lighting our scene.
        local farz = self:GetFarZ()
        if LocalPlayer():GetPos():DistToSqr(self:GetPos()) < (farz + 8) ^2 then
            return false
        end

        -- Otherwise, use pixvis.
        local pixvis = util.PixelVisible(self:GetPos(), self:GetFarZ(), self.PixVis)
        if pixvis == 0 then
            return true
        end
    end

    function ENT:Think()
        -- Hide it when we're out of PVS!
        local pixvis = util.PixelVisible(self:GetPos(), self:GetFarZ(), self.PixVis)

        if self:IsHidden() then
            if self.proj and IsValid(self.proj) then
                self.proj:Remove()
                self.proj = nil
                NumProjectedTextures = NumProjectedTextures - 1
            end
        else
            if not IsValid(self.proj) then
                self.proj = ProjectedTexture()
                NumProjectedTextures = NumProjectedTextures + 1
                self:Update()
            elseif not self:GetStatic() then
                self:Update()
            end
        end
    end

    function ENT:OnRemove()
        if IsValid(self.proj) then
            self.proj:Remove()
        end
    end
end

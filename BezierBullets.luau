--//FOR TESTING IN GAME:
--//F is slow
--//G IS SPEED
--//Z IS SHRINK
--//X IS GROW
--//C Resets the position of all bullets
--//H toggles the bullets! (if they're moving or not)

--//E IS TO FIRE A BULLET!

--// this code is SERVERSIDE, WITH ONE PLAYER SERVERS.

--Define services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module table
local BezierBullets = {}
BezierBullets.__index = BezierBullets

--//Stores all active bullets to make iteration processess easier.
local ActiveBullets = {}

--The calculation for the path of the bezier curve.
--Start is the characters humanoidrootpart, and target is the hit position of the mouse.
--// alpha indicates where in the bezier curve the part should be. (1 is complete, 0 is start)
--// Using Lerp ensures smooth interpolation along the curve. Each frame, the part moves to the exact position dictated by the Bezier formula.
local function QuadraticBezier(Start, Control, Target, Alpha)
	local StartToControl = Start:Lerp(Control, Alpha)
	local ControlToTarget = Control:Lerp(Target, Alpha)
	return StartToControl:Lerp(ControlToTarget, Alpha)
end

-- Creates a new bullet, and sets the data. 
--// the client side code is very minimal, so most of these values end up being the default values. 
--//having them allows the client to have more customization if the need arises. (this is just a showcase, so there is no need for sanity checks)
function BezierBullets.new(Data)
	local self = setmetatable({}, BezierBullets)--set the metatable 

	-- Core properties
	self.Start = Data.Start
	self.End = Data.End
	self.LifeTime = Data.LifeTime or 1
	self.Speed = Data.Speed or 1
	self.CurveAmount = Data.CurveAmount or 25
	self.ProjectileSize = Data.ProjectileSize or Vector3.new(1,1,1)

	self.Elapsed = 0
	self.IsActive = false
	self.IsStopped = false

	-- Create control point if not provided (control point is just the "curve point")
	if Data.Control then
		self.Control = Data.Control
	else
		local Mid = (self.Start + self.End) / 2 -- we use the midpoint formula to gather what the middle of the path is 

		local Offset = Vector3.new( -- this is the offset from the midpoint to the control point, self.CurveAmount effects the offset (in return effecting the entire curve)
			(math.random() - 0.5) * self.CurveAmount * 2,
			(math.random() - 0.5) * self.CurveAmount * 2,
			(math.random() - 0.5) * self.CurveAmount * 2
		)
		self.Control = Mid + Offset--set the control to the sum of the Middle + Offset. This allows for the path to actually be curved instead of being straight
	end

	-- Create the physical bullet part
	local Part = Data.Part --we give the client an oppourtunity to pass a part, however for this showcase there isnt a possiblilty this happens so we just create one on the server
	if not Part then
		Part = Instance.new("Part")
		Part.Size = self.ProjectileSize
		Part.Anchored = true
		Part.CanCollide = false
		Part.Shape = Enum.PartType.Ball
		Part.Material = Enum.Material.Neon
		Part.Color = Color3.fromRGB(255, 150, 50)
		Part.Parent = workspace
	end
	self.Part = Part

	table.insert(ActiveBullets, self)--we add it into active bullets. ACTIVE BULLETS is just all the rendered bullets at one given time
	return self--OOP
end



function BezierBullets:SetSpeed(Value)--sets speed
	self.Speed = Value
end

function BezierBullets:SetCurve(Value)--sets Curve value, (this effects how big the curve is, however this SHOULDNT be changed while the bezier bullet is firing.)
	self.CurveAmount = Value
end

function BezierBullets:SetProjectileSize(Multiplier)--this sets the projectile size
	self.ProjectileSize *= Multiplier
	if self.Part then
		self.Part.Size = self.ProjectileSize
	end
end

-- Fire the bullet
function BezierBullets:Fire()-- This FIRES the bullet, which enables itsself to isActive. there is a loop furtherdown in the code that will detect this, and in return start rendering the movement of the bullet
	self.IsActive = true
	self.IsStopped = false
end

-- Stop the bullet temporarily
function BezierBullets:Toggle()--this function will stop and unstop the bullet when H is pressed.
	if self.IsStopped then
		self.IsStopped = false
	else
		self.IsStopped = true
	end
end

-- Slow effect
function BezierBullets:SlowEffect()
	self.Speed = self.Speed / 2 -- cut the speed in half to slow the bullet, this stacks so if you press it a lot the bullet will be pretty slow
	if self.Part then
		self.Part.Color = Color3.fromRGB(61, 43, 255)--makes the part color blue to add more effect
	end
end

-- Speed effect
function BezierBullets:SpeedEffect() --complete opposite of previous function
	self.Speed = self.Speed * 2--doubles the speed of the bullet
	if self.Part then
		self.Part.Color = Color3.fromRGB(255, 0, 4)-- a reddish color
	end
end



-- Reset bullet
function BezierBullets:Reset()-- this resets the bullets properties to default, and is done when you press C
	self.Elapsed = 0
	self.IsActive = false
	self.IsStopped = false
	
	self:Fire()
end

function BezierBullets:Destroy()--destroy bullet
	self.IsActive = false--no longer active
	if self.Part then
		self.Part:Destroy()--removes the part
		self.Part = nil
	end

	for i = #ActiveBullets, 1, -1 do
		if ActiveBullets[i] == self then--checks every single bullet, and detects itsself
			table.remove(ActiveBullets, i)--when it detects itsself, it removes itsself, deleting it from existance
			break
		end
	end
end

-- Update bullet each frame
function BezierBullets:Update(Dt)
	if not self.IsActive or self.IsStopped then return end--if the bullet isnt active or is supposed to be stopped, the script wont update the bullet

	self.Elapsed += Dt * self.Speed-- the delta is multiplied by the speed which visually makes the parts look faster
	local Alpha = math.clamp(self.Elapsed / self.LifeTime, 0, 1)--// clamps value between 0-1. (lifetime is defaulted to 1), this will be used to get the position of the projectile

	local Position = QuadraticBezier(self.Start, self.Control, self.End, Alpha)--// uses the earlier function to get the position of the part

	-- Update part
	if self.Part then--//always make sure the part exists
		local LookDir = (Position - self.Part.Position).Unit--calculate the look direction of the part
		self.Part.CFrame = CFrame.lookAt(Position, Position + LookDir)--change the CFrame of the part to the updated one
	end

	if Alpha >= 1 then-- if the time >=1 then the bullet will be destroyed. (this means the bullet has traveled the distance)
		self:Destroy()--destroy the bullet
	end
end

-- Destroy bullet


-- Heartbeat loop for updating bullets
RunService.Heartbeat:Connect(function(Dt)
	for i = #ActiveBullets, 1, -1 do--iterate through every bullet
		local Bullet = ActiveBullets[i]--get the bullet table from OOP
		if Bullet then--make sure it exists
			Bullet:Update(Dt)--uses the previous update function
		end
	end
end)

-- Initiate client communication
local ClientCommunicationEvent = ReplicatedStorage.ClientCommunication

function BezierBullets:Initiate()--//This is called once by a "main script" to initiate the entier model
	
	ClientCommunicationEvent.OnServerEvent:Connect(function(Player, Request, Data) --client signal to detect what action the player wants
		if Request == "BezierBullet" then
			local Bullet = BezierBullets.new(Data)--creates a new bullet instance
			Bullet:Fire()

		elseif Request == "Slow" then
			for _, Bullet in ipairs(ActiveBullets) do--does the slow effect to every bullet
				Bullet:SlowEffect()
			end

		elseif Request == "Speed" then
			for _, Bullet in ipairs(ActiveBullets) do--does the speed effect to every bullet
				Bullet:SpeedEffect()
			end

		elseif Request == "ResetSpeed" then--resets the speed back to normal for every bullet
			for _, Bullet in ipairs(ActiveBullets) do
				Bullet:ResetSpeed()
			end

		elseif Request == "Grow" then--makes every bullet grow in size by 2x
			for _, Bullet in ipairs(ActiveBullets) do
				Bullet:SetProjectileSize(2)
			end

		elseif Request == "Shrink" then--shrinks every bullet by 0.2
			for _, Bullet in ipairs(ActiveBullets) do
				Bullet:SetProjectileSize(0.5)
			end
		elseif Request == "Toggle" then--//toggles if the bullets are moving or not
			for _, Bullet in ipairs(ActiveBullets) do
				Bullet:Toggle()
			end
		elseif Request == "Reset" then --resets the bullets positions
			for _, Bullet in ipairs(ActiveBullets) do
				Bullet:Reset()
			end
		end
	end)
end

return BezierBullets

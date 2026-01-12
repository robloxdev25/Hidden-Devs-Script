--//FOR TESTING IN GAME:
--//F is slow
--//G IS SPEED
--//Z IS SHRINK
--//X IS GROW
--//C Resets the position of all bullets
--//H toggles the bullets! (if they're moving or not)

--//E IS TO FIRE A BULLET

--// this code is SERVERSIDE, WITH ONE PLAYER SERVERS.


--//Bezier Bullets, V2, V1 was rejected for lack of script lines, so In this version I added raycasting for hit detection, aswell as increased VFX.
--//I know that VFX client side is considered better, however since applying two scripts isnt allowed, I wanted to combine everything into one script to showcase it more thoroughly.

-- Grab the services we need
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

-- The main module for our bullet system
local BezierBullets = {}
BezierBullets.__index = BezierBullets

--//This table keeps track of all the bullets that are currently flying around
local ActiveBullets = {}

--This is the math that makes the bullet follow a curved path
--Start is where the bullet begins, Target is where it's going, and Control is the point that creates the curve
--// Alpha is basically how far along the path the part is. (0 = just started, 1 = arrived at endpoint)
--// Using Lerp makes the movement smooth instead of jumpy
local function QuadraticBezier(Start, Control, Target, Alpha)
	local StartToControl = Start:Lerp(Control, Alpha)
	local ControlToTarget = Control:Lerp(Target, Alpha)
	return StartToControl:Lerp(ControlToTarget, Alpha)
end

local function CreateExplosion(Position)
	local Explosion = Instance.new("Explosion") -- make a explosion using the roblox explosion instance
	Explosion.Position = Position	
	Explosion.BlastRadius = 2
	Explosion.BlastPressure = 0
	Explosion.DestroyJointRadiusPercent = 0
	Explosion.ExplosionType = Enum.ExplosionType.NoCraters
	Explosion.Parent = workspace
	Debris:AddItem(Explosion, 1)--automatically cleans up after 1 second

end

-- This creates a brand new bullet with all its settings
--// Most of the time we're just using default values since the client doesn't send much data
--// But having these options here means we could easily customize stuff later if we want
function BezierBullets.new(Data, Player)
	local self = setmetatable({}, BezierBullets) -- standard OOP setup

	--//Grab all the settings for this bullet
	--//If the client didn't specify something, we fall back to reasonable defaults
	self.Start = Data.Start
	self.End = Data.End
	self.LifeTime = Data.LifeTime or 1 --How long the bullet takes to reach its destination
	self.Speed = Data.Speed or 1
	self.OriginalSpeed = self.Speed -- remember the starting speed so we can reset it later
	self.CurveAmount = Data.CurveAmount or 25
	self.ProjectileSize = Data.ProjectileSize or Vector3.new(1,1,1)

	self.Elapsed = 0
	self.IsActive = false
	self.IsStopped = false
	self.Owner = Player

	-- Figure out the curve point if we weren't given one
	if Data.Curve then
		self.Curve = Data.Curve
	else
		local Mid = (self.Start + self.End) / 2 -- find the halfway point between start and end

		local Offset = Vector3.new( --// add some randomness so each bullet takes a unique path
			(math.random() - 0.5) * self.CurveAmount * 2,
			(math.random() - 0.5) * self.CurveAmount * 2,
			(math.random() - 0.5) * self.CurveAmount * 2
		)
		self.Curve = Mid + Offset -- combine the midpoint with the random offset to get our curve point
	end

	-- Make the actual visible bullet part
	local Part = Data.Part -- the client could send us a part, but that's not happening in this demo
	if not Part then--So we just make our own glowing sphere
		Part = Instance.new("Part")
		Part.Size = self.ProjectileSize
		Part.Anchored = true
		Part.CanCollide = false
		Part.Shape = Enum.PartType.Ball
		Part.Material = Enum.Material.Neon
		Part.Color = Color3.fromRGB(255, 150, 50) -- nice orange glow
		Part.Parent = workspace
	end
	self.Part = Part

	--This code just creates a trail that follows the bullet, purely for VFX purposes
	local AttachmentA = Instance.new("Attachment")
	local AttachmentB = Instance.new("Attachment")
	AttachmentA.Parent = self.Part
	AttachmentB.Parent = self.Part
	AttachmentB.Position = Vector3.new(0, -0.5 * self.ProjectileSize.Y, 0) -- offset the trail a bit
	local Trail = Instance.new("Trail")
	Trail.Attachment0 = AttachmentA
	Trail.Attachment1 = AttachmentB	
	Trail.Color = ColorSequence.new(Color3.fromRGB(255, 200, 0), Color3.fromRGB(255, 0, 0))
	Trail.Transparency = NumberSequence.new(0.2)
	Trail.Lifetime = 0.3
	Trail.FaceCamera = true
	Trail.Parent = self.Part

	-- Add a light so the bullet glows
	local Light = Instance.new("PointLight")
	Light.Color = self.Part.Color
	Light.Range = 10
	Light.Brightness = 2
	Light.Parent = self.Part

	table.insert(ActiveBullets, self) -- add this bullet to our list of active ones
	return self 
end

function BezierBullets:SetSpeed(Value) -- change how fast this bullet moves
	self.Speed = Value
end

function BezierBullets:SetCurve(Value) -- adjust how curvy the path is (don't do this while it's flying though!)
	self.CurveAmount = Value
end

function BezierBullets:SetProjectileSize(Multiplier) -- make the bullet bigger or smaller
	self.ProjectileSize *= Multiplier
	if self.Part then
		self.Part.Size = self.ProjectileSize
	end
end

-- Bring the bullet back to its original speed and color
function BezierBullets:ResetSpeed()
	self.Speed = self.OriginalSpeed or self.Speed
	if self.Part then
		self.Part.Color = Color3.fromRGB(255, 150, 50) -- back to orange
	end
end

-- Launch the bullet
function BezierBullets:Fire() -- this gets the bullet moving. The main loop will pick it up and start updating its position
	self.IsActive = true
	self.IsStopped = false
end

function BezierBullets:Toggle() -- pause or unpause the bullet (used when H is pressed)
	if self.IsStopped then
		self.IsStopped = false
	else
		self.IsStopped = true
	end
end

-- Make the bullet move slower
function BezierBullets:SlowEffect()
	self.Speed = self.Speed / 2 -- cut speed in half (this stacks if you spam it)
	if self.Part then
		self.Part.Color = Color3.fromRGB(61, 43, 255) -- turn it blue to show it's slowed
	end
end

-- Make the bullet move faster
function BezierBullets:SpeedEffect() -- opposite of slow
	self.Speed = self.Speed * 2 -- double the speed
	if self.Part then
		self.Part.Color = Color3.fromRGB(255, 0, 4) -- turn it red to show it's speeding
	end
end

-- Send the bullet back to its starting position
function BezierBullets:Reset() -- happens when you press C
	self.Elapsed = 0
	self.IsActive = false
	self.IsStopped = false

	self:Fire()
end

function BezierBullets:Destroy() -- get rid of the bullet completely
	self.IsActive = false -- stop tracking it, and removes it from the loop
	if self.Part then
		-- make a little explosion where it disappeared for visual flair
		CreateExplosion(self.Part.Position)
		self.Part:Destroy() -- delete the visual part
		self.Part = nil
	end

	for i = #ActiveBullets, 1, -1 do
		if ActiveBullets[i] == self then -- find this bullet in the list
			table.remove(ActiveBullets, i) -- remove it
			break
		end
	end
end

-- This runs every frame to move the bullet and check for hits
function BezierBullets:Update(Delta)
	if not self.IsActive or self.IsStopped then return end -- don't update if the bullet isn't supposed to be moving

	self.Elapsed += Delta * self.Speed -- track how long the bullet has been traveling
	local Alpha = math.clamp(self.Elapsed / self.LifeTime, 0, 1) --// figure out how far along the path we are (0 to 1)

	local Position = QuadraticBezier(self.Start, self.Curve, self.End, Alpha) --// calculate where the bullet should be right now

	-- Move the bullet and check if it hit anything
	if self.Part then --// make sure the bullet still exists
		-- Cast a ray from where we were to where we're going to detect hits
		local origin = self.Part.Position
		local direction = Position - origin
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude --ignore certain things

		raycastParams.FilterDescendantsInstances = {self.Part}

		if self.Owner then--make sure we don't hit the person who fired the bullet
			raycastParams.FilterDescendantsInstances = {self.Part, self.Owner.Character}
		end
		local ray = workspace:Raycast(origin, direction, raycastParams)--check for a hit

		if ray then
			local hitPart = ray.Instance
			local character = hitPart and hitPart:FindFirstAncestorWhichIsA("Model")
			local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
			if humanoid then
				humanoid:TakeDamage(20) -- deal 20 damage
			end
			-- Blow up where we hit
			CreateExplosion(ray.Position)

			self:Destroy() -- bullet explodes on impact
			return -- stop updating this bullet
		end

		-- Nothing was hit: just move the bullet normally
		local LookDir = (Position - self.Part.Position).Unit -- figure out which way the bullet should face
		self.Part.CFrame = CFrame.lookAt(Position, Position + LookDir) -- update position and rotation
	end

	if Alpha >= 1 then -- if we've reached the end of the path
		self:Destroy() -- bullet disappears
	end
end




--Instantly blow up the bullet wherever it is
function BezierBullets:Explode()
	if self.Part then
		CreateExplosion(self.Part.Position)
		self:Destroy()
	end
end



-- Set up communication with the client
local ClientCommunicationEvent = ReplicatedStorage.ClientCommunication

function BezierBullets:Initiate() --// Call this once at the start to get everything running
	ClientCommunicationEvent.OnServerEvent:Connect(function(Player, Request, Data) -- listen for what the player wants to do
		if Request == "BezierBullet" then
			local Bullet = BezierBullets.new(Data, Player) -- make a new bullet
			Bullet:Fire()

		elseif Request == "Slow" then
			for _, Bullet in ipairs(ActiveBullets) do -- slow down every bullet
				Bullet:SlowEffect()
			end

		elseif Request == "Speed" then
			for _, Bullet in ipairs(ActiveBullets) do -- speed up every bullet
				Bullet:SpeedEffect()
			end

		elseif Request == "ResetSpeed" then -- bring all bullets back to normal speed
			for _, Bullet in ipairs(ActiveBullets) do
				Bullet:ResetSpeed()
			end

		elseif Request == "Grow" then -- make all bullets bigger
			for _, Bullet in ipairs(ActiveBullets) do
				Bullet:SetProjectileSize(2)
			end

		elseif Request == "Shrink" then -- make all bullets smaller
			for _, Bullet in ipairs(ActiveBullets) do
				Bullet:SetProjectileSize(0.5)
			end

		elseif Request == "Toggle" then --// pause or unpause all bullets
			for _, Bullet in ipairs(ActiveBullets) do
				Bullet:Toggle()
			end

		elseif Request == "Reset" then -- send all bullets back to their starting positions
			for _, Bullet in ipairs(ActiveBullets) do
				Bullet:Reset()
			end

		elseif Request == "SuperFire" then -- fire a bunch of bullets at once
			-- Launch 5 bullets that all go to the same place but take different paths
			for i = 1, 5 do
				local Bullet = BezierBullets.new(Data, Player)
				Bullet:Fire()
				-- Give each one a slightly different curve so they spread out
				Bullet.Curve = Bullet.Curve + Vector3.new(
					(math.random() - 0.5) * 10,
					(math.random() - 0.5) * 10,
					(math.random() - 0.5) * 10
				)
			end
			-- After they all hit, make a big explosion at the target
			task.spawn(function()
				local delayTime = Data.LifeTime or 1
				wait(delayTime)
				CreateExplosion(Data.End)
			end)
		end
	end)

	RunService.Heartbeat:Connect(function(Delta)
		for i = #ActiveBullets, 1, -1 do -- go through every bullet that's flying
			local Bullet = ActiveBullets[i] -- grab the bullet
			if Bullet then -- make sure it exists
				Bullet:Update(Delta) -- update its position
			end
		end
	end)
end



return BezierBullets

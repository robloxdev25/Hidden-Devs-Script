--//FOR TESTING IN GAME:
--//F is slow
--//G IS SPEED
--//Z IS SHRINK
--//X IS GROW
--//C Resets the position of all bullets
--//H toggles the bullets! (if they're moving or not)

--//E IS TO FIRE A BULLET!

--// this code is SERVERSIDE, WITH ONE PLAYER SERVERS.


--//Bezier Bullets, V2.
-- Define services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

-- Module table
local BezierBullets = {}
BezierBullets.__index = BezierBullets

--//Stores all active bullets to make iteration processes easier.
local ActiveBullets = {}

--The calculation for the path of the bezier curve.
--Start is the character's HumanoidRootPart, and Target is the hit position of the mouse.
--// alpha indicates where in the bezier curve the part should be. (1 is complete, 0 is start)
--// Using Lerp ensures smooth interpolation along the curve. Each frame, the part moves to the exact position dictated by the Bezier formula.
local function QuadraticBezier(Start, Control, Target, Alpha)
	local StartToControl = Start:Lerp(Control, Alpha)
	local ControlToTarget = Control:Lerp(Target, Alpha)
	return StartToControl:Lerp(ControlToTarget, Alpha)
end

local function CreateExplosion(Position)
	local explosion = Instance.new("Explosion") -- we create an explosion instance and edit its properties for this specific effect
	explosion.Position = Position	
	explosion.BlastRadius = 2
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.ExplosionType = Enum.ExplosionType.NoCraters
	explosion.Parent = workspace
	Debris:AddItem(explosion, 1)--add to debris which is effective at removing parts

end

-- Creates a new bullet and sets the data.
--// The client-side code is very minimal, so most of these values end up being the default values.
--// Having them allows the client to have more customization if the need arises. (This is just a showcase, so there is no need for sanity checks.)
function BezierBullets.new(Data,Player)
	local self = setmetatable({}, BezierBullets) -- set the metatable 

	-- Core properties
	self.Start = Data.Start
	self.End = Data.End
	self.LifeTime = Data.LifeTime or 1 --Lifetime goes with speed to create calculations
	self.Speed = Data.Speed or 1
	self.OriginalSpeed = self.Speed -- store original speed for resetting
	self.CurveAmount = Data.CurveAmount or 25
	self.ProjectileSize = Data.ProjectileSize or Vector3.new(1,1,1)

	self.Elapsed = 0
	self.IsActive = false
	self.IsStopped = false
	self.Owner = Player
	-- Create control point if not provided (control point is just the "curve point")
	if Data.Control then
		self.Control = Data.Control
	else
		local Mid = (self.Start + self.End) / 2 -- we use the midpoint formula to gather what the middle of the path is 

		local Offset = Vector3.new( -- this is the offset from the midpoint to the control point, self.CurveAmount affects the offset (in turn affecting the entire curve)
			(math.random() - 0.5) * self.CurveAmount * 2,
			(math.random() - 0.5) * self.CurveAmount * 2,
			(math.random() - 0.5) * self.CurveAmount * 2
		)
		self.Control = Mid + Offset -- set the control to the sum of the Mid + Offset. This allows for the path to actually be curved instead of being straight.
	end

	-- Create the physical bullet part
	local Part = Data.Part -- we give the client an opportunity to pass a part; however, for this showcase there isn't a possibility this happens so we just create one on the server
	if not Part then--I create a part using code to visualize it better.
		Part = Instance.new("Part")
		Part.Size = self.ProjectileSize
		Part.Anchored = true
		Part.CanCollide = false
		Part.Shape = Enum.PartType.Ball
		Part.Material = Enum.Material.Neon
		Part.Color = Color3.fromRGB(255, 150, 50) -- orange color for the bullet
		Part.Parent = workspace
	end
	self.Part = Part

	-- Add a trail effect to the bullet for visual flair
	local attachmentA = Instance.new("Attachment")
	attachmentA.Parent = self.Part
	local attachmentB = Instance.new("Attachment")
	attachmentB.Parent = self.Part
	attachmentB.Position = Vector3.new(0, -0.5 * self.ProjectileSize.Y, 0) -- offset for trail effect
	local trail = Instance.new("Trail")
	trail.Attachment0 = attachmentA
	trail.Attachment1 = attachmentB
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 200, 0), Color3.fromRGB(255, 0, 0))
	trail.Transparency = NumberSequence.new(0.2)
	trail.Lifetime = 0.3
	trail.FaceCamera = true
	trail.Parent = self.Part

	-- Add a light to make the bullet glow
	local light = Instance.new("PointLight")
	light.Color = self.Part.Color
	light.Range = 10
	light.Brightness = 2
	light.Parent = self.Part

	table.insert(ActiveBullets, self) -- we add it into ActiveBullets. ACTIVE BULLETS is just all the rendered bullets at one given time.
	return self -- OOP
end

function BezierBullets:SetSpeed(Value) -- sets speed
	self.Speed = Value
end

function BezierBullets:SetCurve(Value) -- sets Curve value (this affects how big the curve is; however this SHOULDNT be changed while the bezier bullet is firing.)
	self.CurveAmount = Value
end

function BezierBullets:SetProjectileSize(Multiplier) -- this sets the projectile size
	self.ProjectileSize *= Multiplier
	if self.Part then
		self.Part.Size = self.ProjectileSize
	end
end

-- Reset speed effect (returns bullet speed to original and resets color)
function BezierBullets:ResetSpeed()
	self.Speed = self.OriginalSpeed or self.Speed
	if self.Part then
		self.Part.Color = Color3.fromRGB(255, 150, 50) -- resets to original orange color
	end
end

-- Fire the bullet
function BezierBullets:Fire() -- this FIRES the bullet, which enables it to be active. There is a loop further down in the code that will detect this, and in return start rendering the movement of the bullet.
	self.IsActive = true
	self.IsStopped = false
end

-- Stop the bullet temporarily
function BezierBullets:Toggle() -- this function will stop and unstop the bullet when H is pressed.
	if self.IsStopped then
		self.IsStopped = false
	else
		self.IsStopped = true
	end
end

-- Slow effect
function BezierBullets:SlowEffect()
	self.Speed = self.Speed / 2 -- cut the speed in half to slow the bullet. This stacks, so if you press it a lot the bullet will be pretty slow.
	if self.Part then
		self.Part.Color = Color3.fromRGB(61, 43, 255) -- makes the part color blue to add more effect
	end
end

-- Speed effect
function BezierBullets:SpeedEffect() -- complete opposite of previous function
	self.Speed = self.Speed * 2 -- doubles the speed of the bullet
	if self.Part then
		self.Part.Color = Color3.fromRGB(255, 0, 4) -- a reddish color
	end
end

-- Reset bullet
function BezierBullets:Reset() -- this resets the bullet properties to default, and is done when you press C
	self.Elapsed = 0
	self.IsActive = false
	self.IsStopped = false

	self:Fire()
end

function BezierBullets:Destroy() -- destroy bullet
	self.IsActive = false -- no longer active
	if self.Part then
		-- Optionally create a small explosion effect upon bullet destruction for flair
		CreateExplosion(self.Part.Position)
		self.Part:Destroy() -- removes the part
		self.Part = nil
	end

	for i = #ActiveBullets, 1, -1 do
		if ActiveBullets[i] == self then -- checks every single bullet, and detects itself
			table.remove(ActiveBullets, i) -- when it detects itself, it removes itself, deleting it from existence
			break
		end
	end
end

-- Update bullet each frame
function BezierBullets:Update(Dt)
	if not self.IsActive or self.IsStopped then return end -- if the bullet isn't active or is supposed to be stopped, the script won't update the bullet

	self.Elapsed += Dt * self.Speed -- the delta is multiplied by the speed which visually makes the parts look faster
	local Alpha = math.clamp(self.Elapsed / self.LifeTime, 0, 1) --// clamps value between 0-1. (LifeTime is defaulted to 1), this will be used to get the position of the projectile

	local Position = QuadraticBezier(self.Start, self.Control, self.End, Alpha) --// uses the earlier function to get the position of the part

	-- Update part with collision detection
	if self.Part then --// always make sure the part exists
		-- Raycast from previous position to new position to check for collisions
		local origin = self.Part.Position
		local direction = Position - origin
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude --exclude so every part is considered except the part itsself and the character
		
		raycastParams.FilterDescendantsInstances = {self.Part}

		if self.Owner then--some parts may not have owners, so this is to insure its safe.
		raycastParams.FilterDescendantsInstances = {self.Part,self.Owner.Character}
		end
		local ray = workspace:Raycast(origin, direction, raycastParams)--Raycast for hit detection
		
		if ray then
			local hitPart = ray.Instance
			-- If a humanoid is hit, apply damage
			local character = hitPart and hitPart:FindFirstAncestorWhichIsA("Model")
			local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
			if humanoid then
				humanoid:TakeDamage(20) -- deal 20 damage
			end
			-- Create explosion effect at hit location
			CreateExplosion(ray.Position)

			self:Destroy() -- destroy the bullet on impact
			return -- exit update after collision
		end

		-- No collision: update bullet position and orientation
		local LookDir = (Position - self.Part.Position).Unit -- calculate the look direction of the part
		self.Part.CFrame = CFrame.lookAt(Position, Position + LookDir) -- change the CFrame of the part to the updated one
	end

	if Alpha >= 1 then -- if Alpha >= 1 then the bullet will be destroyed (this means the bullet has traveled the distance)
		self:Destroy() -- destroy the bullet
	end
end





-- Explode this bullet immediately
function BezierBullets:Explode()
	if self.Part then
		CreateExplosion(self.Part.Position)
		self:Destroy()
	end
end



-- Heartbeat loop for updating bullets
RunService.Heartbeat:Connect(function(Dt)
	for i = #ActiveBullets, 1, -1 do -- iterate through every bullet
		local Bullet = ActiveBullets[i] -- get the bullet table from OOP
		if Bullet then -- make sure it exists
			Bullet:Update(Dt) -- uses the previous update function
		end
	end
end)

-- Initiate client communication
local ClientCommunicationEvent = ReplicatedStorage.ClientCommunication

function BezierBullets:Initiate() --// This is called once by a "main script" to initiate the entire model
	ClientCommunicationEvent.OnServerEvent:Connect(function(Player, Request, Data) -- client signal to detect what action the player wants
		if Request == "BezierBullet" then
			local Bullet = BezierBullets.new(Data,Player) -- creates a new bullet instance
			Bullet:Fire()

		elseif Request == "Slow" then
			for _, Bullet in ipairs(ActiveBullets) do -- does the slow effect to every bullet
				Bullet:SlowEffect()
			end

		elseif Request == "Speed" then
			for _, Bullet in ipairs(ActiveBullets) do -- does the speed effect to every bullet
				Bullet:SpeedEffect()
			end

		elseif Request == "ResetSpeed" then -- resets the speed back to normal for every bullet
			for _, Bullet in ipairs(ActiveBullets) do
				Bullet:ResetSpeed()
			end

		elseif Request == "Grow" then -- makes every bullet grow in size by 2x
			for _, Bullet in ipairs(ActiveBullets) do
				Bullet:SetProjectileSize(2)
			end

		elseif Request == "Shrink" then -- shrinks every bullet by 0.2
			for _, Bullet in ipairs(ActiveBullets) do
				Bullet:SetProjectileSize(0.5)
			end

		elseif Request == "Toggle" then --// toggles if the bullets are moving or not
			for _, Bullet in ipairs(ActiveBullets) do
				Bullet:Toggle()
			end

		elseif Request == "Reset" then -- resets the bullets positions
			for _, Bullet in ipairs(ActiveBullets) do
				Bullet:Reset()
			end

		elseif Request == "SuperFire" then -- fires multiple bullets with a burst effect
			-- Fire 5 bullets with unique trajectories to the same target
			for i = 1, 5 do
				local Bullet = BezierBullets.new(Data)
				Bullet:Fire()
				-- Add a bit of random variation to each control point for unique paths
				Bullet.Control = Bullet.Control + Vector3.new(
					(math.random() - 0.5) * 10,
					(math.random() - 0.5) * 10,
					(math.random() - 0.5) * 10
				)
			end
			-- Create an explosion effect at the target after bullets are expected to hit
			task.spawn(function()
				local delayTime = Data.LifeTime or 1
				wait(delayTime)
				CreateExplosion(Data.End)
			end)
		end
	end)
end

return BezierBullets

--[[This is the main game loop I created for a commission about a repetitve elevator game, playtesting may not work as desired with only one person as it is a multiplayer game]]
--[[
MAIN GAME IDEA:
 
players will have a short time to go into 1 out of 4 elevators. The outcomes are this:
 
One elevator is entirelly safe.
One elevator will instantly kill you.
 
in the other two elevators, you will play challenges to determine if you continue or not.
 
 
Last person standing wins.
 
 
 
VERY IMPORTANT: The person I commissioned asked for me to not kill the player when they are supposed to die, as they wanted to do their own thing. (they were an beginner/intermediate scripter). I want to show only the code I provided them, so after death the game will keep you alive and you won't enter spectate mode. (I had created it so if you died you would spectate)
 
 
I hope this script can show my growth as a scripter in the 1.5 years that has passed since my last submission. If you have any questions, please let me know.
]]
 
--/-/-/-/-/- PLEASE READ!
 --//! This script is similar to the one I submitted, however task.spawn was changed for task.defer. I find the difference negligible, however one of either method is nessesary to allow the script to do multiple things at once
--// (task.defer runs a little later in the frame.)

 
 
--//Declare Services I will need later for simplicity and better readability
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptStorage = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local TeamService = game:GetService("Teams")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
--//
 
 
local Map = workspace.Map -- Main map of the game
local Elevators = Map.Elevators -- There are four elevators. they are all the same so I iterate through the elevators table whenever I want to make an adjustment to all of them
 
--// Main remotes I will need. The Message Remote displays a message on a Text Label to all or one player. Toggle Death Screen basically allows the player to respawn /spectate and let them know they have died.
local MessageRemote = ReplicatedStorage.Remotes.DisplayMessage
local ToggleDeathScreen = ReplicatedStorage.Remotes.ToggleDeathScreen
local LeaveRoom = ReplicatedStorage.Remotes.LeaveRoom
local ZonePlus = require(ReplicatedStorage.Zone)--Popular module used for detecting player hitboxes when doing challenges and inside the elevator
 
 
--//MAIN VARIABLES:
local GamePlaying = false --This is the main variable that determines if the game is running or not. A lot of logic in the game is determined by the value of this. (such as making sure only one loop is running)
local ElevatorOpen = false -- This is a variable that determines if the elevator is open or closed. It is used to prevent players from entering the elevator while it is open, and allows for a cleaner to read, and more efficient way to move on from the main select an elevator phase to the minigame phase
local Intermission = 15 -- low for testing, this is the amount of times players are in the intermission phase
local ChallengesCompleted = 0 --This variable is very important to insure the game runs properly and efficiently during the "challenge" phase. Later on, I have a script a script that detects when all players in one challenge have finished their challenge. When this is detected, I increase the value by this variable by one. there are only two challenges happening at the same time, so if this variable is two, I know to move on and not waste extra time on nothing
 
 
local function Shuffle(Elevators) -- we  shuffle the elevators functions, This will make more sense later on in the code.
    for i = #Elevators, 2, -1 do --I use a Fisher Yates shuffle to insure each elevator has equal probablity.
        local j = math.random(i)
        Elevators[i], Elevators[j] = Elevators[j], Elevators[i]
    end
end
local function GetPlayersInChallenge(PlayerTable) --We use this function to get the amount of players actively participaating in a challenge. A player is considered actually participating in a challenge if they havent completed it, and are alive within the given amount of time.
    local PlayersInChallenge = 0 -- we use a simple number value to detect how many players are in the challenge with the "InChallenge" attribute set to true
    for _,Player in PlayerTable do --Iterate through table
        if Player:GetAttribute("InChallenge") then --Check to make sure
            PlayersInChallenge += 1 --Increase value
        end
    end
    return PlayersInChallenge --Return the value to the function
end
 
function Obby1Challenge(ChallengePlayers) -- This is one of the challenges that are in the game.
    local Obby1 = workspace.ChallengeMaps.Obby1 -- Map for obby, create a variable for easily readability.
    local Time = 45--Time to complete the obby.
 
    TweenService:Create(Obby1.LeftDoor,TweenInfo.new(1),{Position = Obby1.LeftDoor.CFrame * Vector3.new(0,0,7)}):Play() -- This opens the specific Obbys doors using a smooth tween to seven studs. This is the LeftDoor.
    TweenService:Create(Obby1.RightDoor,TweenInfo.new(1),{Position = Obby1.RightDoor.CFrame * Vector3.new(0,0,-7)}):Play()-- This opens the specific Obbys doors using a smooth tween to seven studs. This is the RightDoor
 
    for _,Player in ChallengePlayers do -- Challenge players is a table that is passed on from the main script consisting of all players in this specific challenge. We iterate through all of them to teleport them to the specific challenge
        local Character = Player.Character
        if Character then--we  insure they have a character instance so no errors will occur.
            Character.HumanoidRootPart.Position = Obby1.Spawn.Position -- Teleport them to spawn.
            LeaveRoom:FireClient(Player,false) --Alters the state of some GUIS in player view, like removing the "leave room option.""
            Player:SetAttribute("InChallenge",true) -- we set the players "InChallenge" attribute to true for global communication to indicate that the player is in a challenge. Many other scripts use this to determine if the actions they hold should fire or not. 
        end
    end
 
 
 
    for i = Time,1,-1 do --Main loop for the challenge itsself. I is a simple number value that is used to count down the time.
        if GetPlayersInChallenge(ChallengePlayers) > 0 then--Every second we detect how many players are still challenging. If none are left, we are done with this challenge. I created this job on the same loop as the countdown because it isnt a task that needs a very fast loop to update, this makes the script more optimized
            for _,Player in ChallengePlayers do --iterate through all the current Challenge Players.
                if Players:FindFirstChild(Player.Name) and Player:GetAttribute("InChallenge") then--We make sure the Player hasnt left the game yet, because some players will. we also make sure they are InChallenge 
                    MessageRemote:FireClient(Player,i,true)--This is basically a message to the Client saying, "Hey, the player is still in the challenge, continue doing everything on the client for the challenge" (Timer, Effects, UI, etc.)
                end
            end
        else
            break --if there are no more players doing the challenge, we just break the loop to maintain a fast game pace.
        end
        task.wait(1)--we give a little buffer, this is more for dramatic effect/ visual purposes than anything script wise.
    end
 
    TweenService:Create(Obby1.LeftDoor,TweenInfo.new(1),{Position = Obby1.LeftDoor.CFrame * Vector3.new(0,0,-7)}):Play() --we close the left door
    TweenService:Create(Obby1.RightDoor,TweenInfo.new(1),{Position = Obby1.RightDoor.CFrame * Vector3.new(0,0,7)}):Play() -- we close the right door
    task.wait(1) -- another small buffer as we wait for the tweens to play
 
    for _,Player in ChallengePlayers do -- we iterate through all Challenge Players that still have the "InChallenge" attribute to them. This tells us everything who HASNT completed the challenge
        if Players:FindFirstChild(Player.Name) and Player:GetAttribute("InChallenge") then 
            Player.Team = TeamService.Spectating--Other scripts will pickup that the Players Team has changed, and send them to lobby, enable spectating, etc
            LeaveRoom:FireClient(Player,false) 
            ToggleDeathScreen:FireClient(Player) -- We Toggle the deathscreen to the player, This sets up the ability to revive both on the client and server.
            MessageRemote:FireClient(Player,"You took too long to complete the obby!")--we just let them know the reason why they have failed the challenge
        end
    end
    ChallengesCompleted +=1 -- This is 1/2 of what we need. when challenges completed reaches two we know both challenges were compelted so we reset to 0.
end
 
 
 
 
 
 
 
 
 
 
 
 
 
 
function RedLightGreenLightChallenge(ChallengePlayers)--THIS CHALLENGE ISNT MUCH DIFFERENT STRUCTURALLY, TO NOT REPEAT COMMENTS I WILL SCRIPT ANY OTHER CHALLENGE AND FOCUS MORE ON THE MAIN LOOP.
    local Map = workspace.ChallengeMaps.RedLightGreenLight
 
    --TweenService:Create(Obby1.LeftDoor,TweenInfo.new(1),{Position = Obby1.LeftDoor.CFrame * Vector3.new(0,0,-7)}):Play()
    --  TweenService:Create(Obby1.RightDoor,TweenInfo.new(1),{Position = Obby1.RightDoor.CFrame * Vector3.new(0,0,7)}):Play()
 
    for _,Player in ChallengePlayers do--loop through every player in challenging
        local Character = Player.Character--define character
        if not Character then return end--this is to insure the player is fully loaded into the game so nothing errors.
            Character.HumanoidRootPart.Position = Map.Spawn.Position--teleport the character into the spawn
            LeaveRoom:FireClient(Player,false)--this is to disable ui on client
            MessageRemote:FireClient(Player,"Get ready...",true)--this is to change UI text on the client to let the player know to get ready
            Player:SetAttribute("InChallenge",true)--this controls some of the logic of parts in the game in different scripts, and makes sure that every script knows that the player is currently in the challenge
            Character.Humanoid.WalkSpeed = 0--these two scripts disable the players ability to move, and disable the ability to jump
            Character.Humanoid.JumpPower = 0
        
    end
 
 
 
    TweenService:Create(Map.LeftDoor,TweenInfo.new(1),{Position = Map.LeftDoor.CFrame * Vector3.new(0,0,-7)}):Play()--these two tweens are simply the door tweens
    TweenService:Create(Map.RightDoor,TweenInfo.new(1),{Position = Map.RightDoor.CFrame * Vector3.new(0,0,7)}):Play()
    task.wait(5)
 
 
    local TimeAllowed = 45--how much time is allowed to finish
    local GameOngoing = true--this bool is used for the while loop
    local GreenLight = true--this is to detect when the player can more or not
 
    for _,Player in ChallengePlayers do---this section of code will just make the code start as green light so the players can move, and give them back their moving abilities
        MessageRemote:FireClient(Player,"GREEN LIGHT!")--lets the players know that they can start moving and allows them to move
        Player.Character.Humanoid.WalkSpeed = 16
        Player.Character.Humanoid.JumpPower = 50
    end
 
 
 
 
    local Connection--this uses a connection to insure there is no memory leaks
    Connection = RunService.Heartbeat:Connect(function() --! THIS LOOP JUST MAKES SURE THAT IF A PLAYER MOVES ON RED LIGHT THEY ARE BROUGHT BACK TO THE LOBBY!
        for _, Player in ChallengePlayers do--// gets all players
            local Humanoid = Player.Character and Player.Character:FindFirstChild("Humanoid")--// get the humanoid in a safe way to make sure the code doesnt error
            if Humanoid and Humanoid.MoveDirection.Magnitude > 0 and Player.Team == TeamService.Playing and Player:GetAttribute("InChallenge") and not GreenLight then--checks to make sure the player is eligible to be moved back to the lobby
                SoundService.LoseSound:Play()
                ToggleDeathScreen:FireClient(Player)--death screen
                Player.Team = TeamService.Spectating--put them on spectating team
                MessageRemote:FireClient(Player,"You moved on a red light!")
                Player:SetAttribute("InChallenge",false)
                MessageRemote:FireClient(Player,"Spectating...",true)--actually just make it so this happens when u join spectate team
            end
        end
    end)
 
    task.defer(function()
        for i = TimeAllowed,1,-1 do
            if GetPlayersInChallenge(ChallengePlayers) > 0 then
                for _,Player in ChallengePlayers do
                    if Players:FindFirstChild(Player.Name) and Player:GetAttribute("InChallenge") then
                        print('ts work')
                        MessageRemote:FireClient(Player,i,true)
                    end
                end
 
            else
                print('everyone done!')
                GameOngoing = false
                Connection:Disconnect()
                break
            end
            task.wait(1)
        end
        GameOngoing = false
        Connection:Disconnect()
    end)
 
 
    while GameOngoing do
 
        local TimeDelay = math.random(2,7)
        task.wait(TimeDelay)
        for _,Player in ChallengePlayers do
            if Player:GetAttribute("InChallenge") then
                if GreenLight then
                    MessageRemote:FireClient(Player,"Red Light!")
                else
                    MessageRemote:FireClient(Player,"Green Light!")
                end
            end
        end
 
        if GreenLight then
            task.wait(0.4)
        end
        GreenLight = not GreenLight
    end
    --Time Ran Out
 
    TweenService:Create(Map.LeftDoor,TweenInfo.new(1),{Position = Map.LeftDoor.CFrame * Vector3.new(0,0,-7)}):Play()
    TweenService:Create(Map.RightDoor,TweenInfo.new(1),{Position = Map.RightDoor.CFrame * Vector3.new(0,0,7)}):Play()
    task.wait(1)
 
    for _,Player in ChallengePlayers do
        if Players:FindFirstChild(Player.Name) and Player:GetAttribute("InChallenge") then
            Player.Team = TeamService.Spectating
            SoundService.LoseSound:Play()
            ToggleDeathScreen:FireClient(Player)
            LeaveRoom:FireClient(Player,false)
            MessageRemote:FireClient(Player,"You took too long to get to the end!")
        end
    end
    ChallengesCompleted +=1
end
 
 
 
local ChallengesTable = { --We put all the ongoing challenges in a table to be able to call them by index. This helps simplicity of the code and helps the code not be bias to one function. no "if Challenge == Obby then elseif Obby2 then"
    Obby1Challenge,
    RedLightGreenLightChallenge
 
}
 
 
 
 
local function TweenElevators(Open) -- function to open/close the doors. we didnt use one earlier because the condition was more specific. This is universal to all elevator doors.
    local MoveAmount = Open and -7 or 7 --we use a ternary condition to make the readability easier and not have to repeat code with only one value changed
 
    for _, Elevator in Elevators:GetChildren() do--This allows us to access all the elevators in the game.
        local LeftDoor = Elevator.Elevator.LeftDoor --LeftDoor
        local RightDoor = Elevator.Elevator.RightDoor -- RightDoor
 
        TweenService:Create(LeftDoor, TweenInfo.new(1), {Position = (LeftDoor.CFrame * Vector3.new(0, 0, MoveAmount))}):Play() -- we tween by move amount since the elevator is either going to the left, or to the right in one direction.
        TweenService:Create(RightDoor, TweenInfo.new(1), {Position = (RightDoor.CFrame * Vector3.new(0, 0, -MoveAmount))}):Play()-- we tween by move amount since the elevator is either going to the left, or to the right in one direction.
    end
end
 
local function InitiateGame() --Main function to start game loop
    GamePlaying = true -- Set gameloop to true; this controls a lot of logic 
 
    local PlayersInGame = Players:GetPlayers()--anyone in the game when the loop starts is considering a active participator.
 
    for _,Player in  PlayersInGame do --we set up the player to play, and reset values that could effect the game if not reset.
        Player.Team = TeamService.Playing
        Player:SetAttribute("ElevatorDoor",nil)
    end
 
    local NoWinner = true -- The main condition that controls the while true loop is if there's a winner or not. A winner is just detected by being the only person still playing. just naming this "NoWinner" allows anyone reading to know exactly what this function is used for.
 
    while NoWinner do -- Start loop
        if #TeamService.Playing:GetPlayers() < 1 then --check if theres only one OR less players. This is important because this loop isnt constantly firing which is better for optimization; something may happen between the time the player is the last standing to the time this loop fires again
            NoWinner = false --stops this loop from firing until new data and players are given
            GamePlaying = false --allows other logic to happen
 
            break--we break the loop so nothing else happens
        end
 
        for _,Player in  TeamService.Playing:GetPlayers() do -- we iterate through every player still playing
            LeaveRoom:FireClient(Player,false)
            Player:SetAttribute("ElevatorDoor",nil)--just double check that values are reset
 
 
            --//// SPAWN PLAYER IN RANDOM POSITION LOGIC
            local Size = workspace.SpawnPositioning.Size --size of spawn positioning
            local Pos = workspace.SpawnPositioning.Position --Position of spawn positioning
 
            local RandomOffset = Vector3.new( -- random offset in every direction. 
                math.random() * Size.X - Size.X/2,
                math.random() * Size.Y - Size.Y/2,
                math.random() * Size.Z - Size.Z/2
            )
 
            local RandomPosition = Pos + workspace.SpawnPositioning.CFrame:VectorToWorldSpace(RandomOffset)-- we get the random position
            Player.Character.HumanoidRootPart.Position = RandomPosition -- set the players position to the random position
            --//// END OF SPAWN PLAYER IN RANDOM POSITION LOGIC, the actual change is minor (few studs) but it makes the game loop feel way cleaner as players arent clustered up in the same spot
        end
 
        local Elevators = Elevators:GetChildren() -- we create a new table of elevators that we will use in order to randomize each elevators event. 
 
 
 
        Shuffle(Elevators)--we call the shuffle funciton to actually change the elevators
 
        --//ELEVATOR LOGIC: to keep everything simple and to avoid excessive if then statements, I simply allowed the effect of the elevator to be based on its index after shuffle. the one and two elevators are challenges, 3 being good, and 4 being bad
        local ChallengeElevator1 = Elevators[1]
        local ChallengeElevator2 = Elevators[2]
        local GoodElevator = Elevators[3]
        local BadElevator = Elevators[4]
 
        task.wait(1) -- little buffer
        TweenElevators(true)--we tween the elevators open
 
        local Countdown = 10-- we give them 10 seconds to get into an elevator
 
        ElevatorOpen = true--let other parts of the script know that the elevators are currently open and players can get in them
        for Time =  Countdown,1,-1 do -- counts down time
            MessageRemote:FireAllClients(Time,true) --sets a timer for the client
            task.wait(1)
        end
        ElevatorOpen = false -- lets other parts of the script know that players should no longer be able to get in
        TweenElevators(false) --tween them close
        MessageRemote:FireAllClients("Checking in..." ,true)--let players know they are "Checking in", which basically means they are about to see what fate they get
 
        local Challenge1Players = {} --table for challenge 1
        local Challenge2Players = {} --table for chalenge two
 
        for _,Player in TeamService.Playing:GetPlayers() do--iterate through all playing players
            local ChosenDoor = Player:GetAttribute("ElevatorDoor")--see what door they chose, from 1-4
 
            local CorrespondingElevator = Elevators[ChosenDoor]--see what elevator they got
 
 
            --// I use a series of logic statements to see and operate  from what event the player got ill explain one and ignore the rest because its repetitive
            if CorrespondingElevator == ChallengeElevator1 then -- just detect if they correspond
                table.insert(Challenge1Players,Player)-- since this is a challege elevator I add the player to the challenge
                task.defer(function() --we create this function in a different thread, Personally I wouldn't delay this task but the person who I was scripter for wanted this logic.
                    task.wait(1.5)
 
                    MessageRemote:FireClient(Player,"Get ready...!")
                end)
            elseif CorrespondingElevator == ChallengeElevator2 then--// this process is repeated for both challenge elevators, as two elevators are challenges
                table.insert(Challenge2Players,Player)
                task.defer(function()
                    task.wait(1.5)
 
                    MessageRemote:FireClient(Player,"Get ready...!")
                end)
 
            elseif CorrespondingElevator == GoodElevator then--if the player is in the safe elevator, nothing happens!
                task.defer(function()   
                    task.wait(1.5)
                    MessageRemote:FireClient(Player,"You're safe!")
                end)
 
            elseif CorrespondingElevator == BadElevator then --this will kill the player
                task.defer(function()--spawn in a different thread so nothing yields as every player is iterated against
 
                    MessageRemote:FireClient(Player,"Uh-oh...")--updates UI to let player know they are about to die
                    task.wait(1.5)--little pause for suspense
                    PlayersInGame[Player] = nil
                    SoundService.LoseSound:Play()
                    Player.Team = TeamService.Spectating--removes them from the playing team, which is important because the people on this team is used to determine winner (when 1 player remains the game knows they won)
                    SoundService.LoseSound:Play()
                    ToggleDeathScreen:FireClient(Player)--// enable the death screen onto the player
                end)
            else--// THIS IS IF THE PLAYER DOES NOT FIND AN ELEVATOR, this could be due to afk reasons, etc, so it is important we remove them from the game
                PlayersInGame[Player] = nil-- just remove them from the playersingame so no errors occur
                Player.Team = TeamService.Spectating
                SoundService.LoseSound:Play()
 
                MessageRemote:FireClient(Player,"Get in an elevator next time!")--// 
            end
        end
        LeaveRoom:FireAllClients(false)
        task.wait(1.5)-- we give a little buffer
 
 
 
        local Challenges = workspace.ChallengeMaps:GetChildren() --we shuffle the challenges the same way we did the elevators.
        Shuffle(Challenges)
 
        local Challenge1 = Challenges[1]--declare challenge 1
        local Challenge2 = Challenges[2] --declare challenge 2
 
        task.defer(function()-- we spawn both these functions in different threads to make sure they dont yield over one another so every part of the script can run in harmony.
            ChallengesTable[Challenge1:GetAttribute("ChallengeID")](Challenge1Players)
        end)
 
        task.defer(function()
            print(ChallengesTable[1],Challenge2:GetAttribute("ChallengeID"))
            ChallengesTable[Challenge2:GetAttribute("ChallengeID")](Challenge2Players)
        end)
 
 
        repeat task.wait(0.5) until ChallengesCompleted == 2--we have a very casual wait time of 0.5 to detected when both challenges are completed by all players. This is because there isn't a reason to make this loop incredibly fast because precision shouldn't be over optimization here.
        ChallengesCompleted = 0
    end
end
 
local Elevators = {--// this is just all the elevators in the map for simplicity 
    workspace.Map.Elevators.Elevator1,
    workspace.Map.Elevators.Elevator2,
    workspace.Map.Elevators.Elevator3,
    workspace.Map.Elevators.Elevator4
}
 
for ElevatorNumber,Elevator in Elevators do-- this iteration is to set up the touch events for the elevators
    local TriggerPart = Elevator.TriggerPart--this is the trigger part that detects the events
 
    TriggerPart.Touched:Connect(function(Hit)
        if Hit.Parent:FindFirstChild("Humanoid") then--// make sure the players touches the part
            local Player = Players:GetPlayerFromCharacter(Hit.Parent)--// extra checks to make sure the player is in the game
            if GamePlaying and ElevatorOpen then--// make sure the game is playing and the elevator is open, this is to make sure there is no accidental touches
                Player:SetAttribute("ElevatorDoor",ElevatorNumber)--//this is used in the main loop logic to see what fate the player gets
                Player.Character.HumanoidRootPart.Position = Elevator.InsidePos.Position--//teleport the player
                LeaveRoom:FireClient(Player,true)--// this makes it so the player can no longer use leave room (disables the UI, there is also a sanity check)
            else
                warn("Player isn't supposed to be here")
            end
        end
    end)
 
 
end
 
LeaveRoom.OnServerEvent:Connect(function(Player)--// this controls the leave room logic which comes from a UI button on the client, and lets them change their elevator
    if Player:GetAttribute("ElevatorDoor") ~= nil then
        Player:SetAttribute("ElevatorDoor",nil)
        Player.Character.HumanoidRootPart.Position = workspace.SpawnPositioning.Position--puts them back in the spawn so they can choose another elevator
    end
end)
 
game.Players.PlayerAdded:Connect(function(Player)--// this script makes it so if the player joins while the game is starting, they dont just get added into the game
    Player.CharacterAdded:Connect(function(Character)
        if GamePlaying then
            Player.Team = TeamService.Spectating
            Character.HumanoidRootPart.Position = workspace.SpectatingPlayers.Position
            ReplicatedStorage.Remotes.SpectateRemote:FireClient(Player,true)
        end
    end)
end)
 
TeamService.Playing.PlayerAdded:Connect(function(Player)--// this makes sure they cant spectate when they play
    ReplicatedStorage.Remotes.SpectateRemote:FireClient(Player,false)
end)
TeamService.Spectating.PlayerAdded:Connect(function(Player)--// enables spectating mode
    ReplicatedStorage.Remotes.SpectateRemote:FireClient(Player,true)
end)
while true do -- game loop
    if not GamePlaying then
        local AllPlayers = Players:GetPlayers()--//gets all the players
 
        if #AllPlayers >= 1 then--checks if there is more than one player, and if there is continues the loop
            local Success = false--this is for an intermission to check if the game status changed, if there is less then 2 players then this stay false and the loop wont fire
 
            for i = Intermission,1,-1 do -- countdown
                local PlayersInGame = Players:GetPlayers()
                MessageRemote:FireAllClients("Intermission: " .. i,true)
 
                if #PlayersInGame < 1 then
                    MessageRemote:FireAllClients("Waiting For Players...",true)
                    break
                end
 
                task.wait(1)
                if i == 1 then
                    Success = true--// if the game has been able to count down and there is more than one player then the game starts.
                end
            end
 
            if Success then
                InitiateGame()--starts the game loop!
            end
        else
            print('Need more players')
        end
    end
    task.wait(4)
end
 
--//thanks for reading my code~!

-- Runs the driving lessons and the driving test (PRD-006, requirements 2 to 8).
-- The client asks to start or stop a lesson through the BendiLesson remote event. The server checks the lesson is
-- open, moves the player's car to its start, and follows the car through the checkpoints. Stars and tips from the
-- rules are counted on the way, and at the end the result is saved and sent back.
-- Messages to the client, all through BendiLesson:
-- - "progress", data: the player's saved progress
-- - "lesson", id: a lesson started
-- - "status", checkpoint, stars: the next checkpoint, and the stars earned so far
-- - "finished", id, stars, passed, nextId: a lesson ended, and the lesson it opened, if any
-- - "stopped": the player went back to free driving
-- - "license", date: the player just earned their license

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LessonRun = require(ReplicatedStorage.Core.LessonRun)
local Lessons = require(ReplicatedStorage.Core.Lessons)
local Progress = require(ReplicatedStorage.Core.Progress)
local RuleKit = require(ReplicatedStorage.Core.RuleKit)

local CarSpawner = require(script.Parent.CarSpawner)
local PlayerProgress = require(script.Parent.PlayerProgress)

local LessonRunner = {}

local CAR_WAIT = 20 -- seconds to wait for a new player's car before the first lesson
local REQUEST_COOLDOWN = 1 -- seconds between a player's start and stop requests

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local lessonEvent = remotes:WaitForChild("BendiLesson") :: RemoteEvent
local tipEvent = remotes:WaitForChild("BendiTip") :: RemoteEvent

local runs: { [Player]: LessonRun.Run } = {}
local lastRequest: { [Player]: number } = {}

local function sendProgress(player: Player)
	local data = PlayerProgress.get(player)
	if data then
		lessonEvent:FireClient(player, "progress", data)
	end
end

-- Puts the car upright at `pose`, standing still, the same way Reset car does.
local function moveCar(player: Player, pose: { x: number, z: number, dirX: number, dirZ: number }): boolean
	local car = CarSpawner.getCar(player)
	local base = car and car.PrimaryPart
	if not base then
		return false
	end
	local position = Vector3.new(pose.x, 0, pose.z)
	base.CFrame = CFrame.lookAt(position, position + Vector3.new(pose.dirX, 0, pose.dirZ)) * CFrame.new(0, 1, 0)
	base.AssemblyLinearVelocity = Vector3.zero
	base.AssemblyAngularVelocity = Vector3.zero
	return true
end

local function startLesson(player: Player, id: string)
	local lesson = Lessons.get(id)
	local data = PlayerProgress.get(player)
	if not lesson or not data or not Progress.isUnlocked(data, id) then
		return
	end
	local run = LessonRun.new(lesson)
	if not moveCar(player, run.route.start) then
		return
	end
	runs[player] = run
	lessonEvent:FireClient(player, "lesson", id)
	lessonEvent:FireClient(player, "status", run.checkpoint, run.stars)
	tipEvent:FireClient(player, lesson.intro)
end

local function stopLesson(player: Player)
	if runs[player] then
		runs[player] = nil
		lessonEvent:FireClient(player, "stopped")
	end
end

local function finish(player: Player, run: LessonRun.Run)
	runs[player] = nil
	local lesson = run.lesson
	local passed = LessonRun.passed(run)
	local data = PlayerProgress.get(player)
	local nextId: string? = nil
	local newLicense = false
	if data then
		nextId = Progress.record(data, lesson.id, run.stars, passed)
		if passed and lesson.isTest and not data.license then
			Progress.grantLicense(data, os.date("!%Y-%m-%d") :: string)
			newLicense = true
		end
		PlayerProgress.changed(player)
	end

	lessonEvent:FireClient(player, "finished", lesson.id, run.stars, passed, nextId)
	local values = { stars = run.stars, need = Lessons.PASS_STARS }
	if lesson.isTest then
		tipEvent:FireClient(player, if passed then "testPassed" else "testFailed")
	else
		tipEvent:FireClient(player, if passed then "lessonPassed" else "lessonTryAgain", values)
	end
	if nextId then
		tipEvent:FireClient(player, if nextId == "test" then "testUnlocked" else "lessonUnlocked")
	end
	if newLicense and data then
		lessonEvent:FireClient(player, "license", data.license)
	end
end

-- Counts a star given or a tip shown to the player, if they're in a lesson.
function LessonRunner.onEvent(player: Player, event: RuleKit.Event)
	local run = runs[player]
	if not run then
		return
	end
	local before = run.stars
	LessonRun.onEvent(run, event)
	if run.stars ~= before then
		lessonEvent:FireClient(player, "status", run.checkpoint, run.stars)
	end
end

-- Starts the first lesson for a brand-new player, once their car is ready (requirement 4). In Studio, DataStores
-- usually can't be reached, so a player whose save didn't load gets the first lesson too.
local function onReady(player: Player, status: PlayerProgress.Status)
	sendProgress(player)
	if status ~= "new" and not (status == "failed" and RunService:IsStudio()) then
		return
	end
	local waited = 0
	while not CarSpawner.getCar(player) and waited < CAR_WAIT do
		waited += task.wait(0.5)
	end
	if player.Parent and not runs[player] then
		startLesson(player, Lessons.LIST[1].id)
	end
end

local function onRequest(player: Player, action: any, id: any)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
		return
	end
	lastRequest[player] = now
	if action == "start" and type(id) == "string" then
		startLesson(player, id)
	elseif action == "stop" then
		stopLesson(player)
	elseif action == "progress" then
		sendProgress(player)
	end
end

function LessonRunner.start()
	PlayerProgress.onReady(onReady)
	PlayerProgress.onChanged(sendProgress)
	lessonEvent.OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(player)
		runs[player] = nil
		lastRequest[player] = nil
	end)

	RunService.Heartbeat:Connect(function()
		for player, run in runs do
			local car = CarSpawner.getCar(player)
			local base = car and car.PrimaryPart
			if base and LessonRun.update(run, base.Position.X, base.Position.Z) then
				if run.finished then
					finish(player, run)
				else
					lessonEvent:FireClient(player, "status", run.checkpoint, run.stars)
				end
			end
		end
	end)
end

return LessonRunner

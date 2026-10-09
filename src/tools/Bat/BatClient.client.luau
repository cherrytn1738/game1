local RunService = game:GetService("RunService")
local Tool = script.Parent
local Player = game:GetService("Players").LocalPlayer
local BattingRemote = game:GetService("ReplicatedStorage"):WaitForChild("BattingTiming")

-- Phase 1 only. Targets are relative to HumanoidRootPart.
local LOAD_TIME, DRIVE_TIME, CONTACT_TIME = 0.10, 0.10, 0.08
local FOLLOW_TIME, HOLD_TIME, RETURN_TIME = 0.16, 0.12, 0.28
local HAND_SPACING = 0.38
local function batFrame(position, barrel)
	local up = barrel.Unit
	local right = Vector3.zAxis:Cross(up).Unit
	return CFrame.fromMatrix(position, right, up)
end
-- The hands lead a single bat arc: right shoulder -> forward -> left shoulder.
local READY = {bat = batFrame(Vector3.new(0.65, 1.05, -0.45), Vector3.new(0.25, 0.94, 0.3)), turn = -12}
local LOAD = {bat = batFrame(Vector3.new(0.8, 1.15, -0.25), Vector3.new(0.35, 0.85, 0.5)), turn = -20}
local DRIVE = {bat = batFrame(Vector3.new(0.45, 0.65, -1.1), Vector3.new(0.95, 0.22, 0.2)), turn = -4}
local CONTACT = {bat = batFrame(Vector3.new(-0.05, 0.65, -1.25), Vector3.new(0.55, 0.08, -0.83)), turn = 12}
local FOLLOW = {bat = batFrame(Vector3.new(-0.8, 1.05, -0.6), Vector3.new(-0.65, 0.65, 0.4)), turn = 30}

local equipped, swinging = false, false
local generation = 0
local current = READY
local transition
local connections = {}
local temporary = {}
local torsoJoints = {}
local root, rightTarget, leftTarget, palm
local originalGrip

local function cleanup()
	equipped = false
	generation += 1
	transition = nil
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	for _, object in temporary do object:Destroy() end
	table.clear(temporary)
	for _, entry in torsoJoints do
		if entry.joint.Parent then
			if entry.attachment then entry.attachment.CFrame = entry.base
			else entry.joint.C0 = entry.base end
			entry.joint.Transform = entry.transform
		end
	end
	table.clear(torsoJoints)
	if originalGrip then Tool.Grip = originalGrip end
	swinging = false
end

local function makeTarget(name, frame)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.CFrame = frame
	attachment.Parent = root
	table.insert(temporary, attachment)
	return attachment
end

local function makeArm(character, humanoid, side, target, pole)
	local hand = character:FindFirstChild(side .. "Hand")
	local upperArm = character:FindFirstChild(side .. "UpperArm")
	local palm = hand and hand:FindFirstChild(side .. "GripAttachment")
	if not palm or not upperArm then return false end
	local ik = Instance.new("IKControl")
	ik.Name = "Bat" .. side .. "ArmIK"
	ik.Type = Enum.IKControlType.Position
	ik.ChainRoot = upperArm
	ik.EndEffector = palm
	ik.Target = target
	ik.Pole = pole
	ik.SmoothTime = 0
	ik.Weight = 1
	ik.Priority = 10
	ik.Parent = humanoid
	table.insert(temporary, ik)
	return true
end

local function updateTargets()
	if transition then
		local alpha = math.clamp((os.clock() - transition.start) / transition.duration, 0, 1)
		-- Continuous bat frame interpolation; no separate wrist twirl.
		local smooth = alpha * alpha * (3 - 2 * alpha)
		current = {
			bat = transition.from.bat:Lerp(transition.to.bat, smooth),
			turn = transition.from.turn + (transition.to.turn - transition.from.turn) * smooth,
		}
	end
	rightTarget.CFrame = current.bat
	leftTarget.CFrame = current.bat * CFrame.new(0, -HAND_SPACING, 0) 
end

local function stage(target, duration, token)
	if not equipped or token ~= generation then return false end
	transition = {from = current, to = target, duration = duration, start = os.clock()}
	task.wait(duration)
	if not equipped or token ~= generation then return false end
	current = target
	transition = nil
	return true
end

local function equip()
	cleanup()
	if not Player:GetAttribute("BattingActive") or Tool.Parent ~= Player.Character then return end
	local character = Tool.Parent
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return end
	originalGrip = Tool.Grip
	palm = character.RightHand.RightGripAttachment
	current = READY
	rightTarget = makeTarget("BatRightPalmTarget", READY.bat)
	leftTarget = makeTarget("BatLeftPalmTarget", READY.bat * CFrame.new(0, -HAND_SPACING, 0))
	local rightPole = makeTarget("BatRightElbowPole", CFrame.new(2, 0.5, 0.5))
	local leftPole = makeTarget("BatLeftElbowPole", CFrame.new(-2, 0.3, -0.8))
	if not makeArm(character, humanoid, "Right", rightTarget, rightPole)
		or not makeArm(character, humanoid, "Left", leftTarget, leftPole) then
		warn("Basic swing requires an R15 avatar with hand grip attachments.")
		cleanup()
		return
	end
	for _, joint in character:GetDescendants() do
		if (joint.Name == "Waist" or joint.Name == "Root")
			and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			local attachment = joint:IsA("AnimationConstraint") and joint.Attachment0
			table.insert(torsoJoints, {
				joint = joint, attachment = attachment,
				base = attachment and attachment.CFrame or joint.C0,
				transform = joint.Transform,
				weight = joint.Name == "Waist" and 0.7 or 0.3,
			})
		end
	end
	equipped = true
	Tool.Grip = CFrame.identity
	updateTargets()
	table.insert(connections, RunService.PreAnimation:Connect(updateTargets))
	table.insert(connections, RunService.PreSimulation:Connect(function()
		-- The bat orientation follows the shared arc, while its pivot stays at the actual palm.
		local desired = root.CFrame * current.bat
		local palmFrame = palm.WorldCFrame
		desired = CFrame.new(palmFrame.Position) * desired.Rotation
		Tool.Grip = desired:Inverse() * palmFrame
		-- Leave arms to IK and legs to normal locomotion; add a modest torso turn.
		for _, entry in torsoJoints do
			local base = entry.base
			local frame = CFrame.new(base.Position)
				* CFrame.Angles(0, math.rad(current.turn * entry.weight), 0) * base.Rotation
			if entry.attachment then entry.attachment.CFrame = frame
			else entry.joint.C0 = frame end
		end
	end))
end

Tool.Equipped:Connect(equip)
Player:GetAttributeChangedSignal("BattingActive"):Connect(function()
 if Player:GetAttribute("BattingActive") then
  if Tool.Parent == Player.Character then equip() end
 else
  cleanup()
 end
end)

Tool.Unequipped:Connect(cleanup)
Tool.Destroying:Connect(cleanup)
Tool.Activated:Connect(function()
	if not equipped or swinging or Player:GetAttribute("HitActive") or not Player:GetAttribute("BattingActive") or Tool:GetAttribute("ExitPending") then return end
	local now = workspace:GetServerTimeNow()
	local session = Tool:GetAttribute("BattingSession")
	local nextSwing = game:GetService("Players").LocalPlayer:GetAttribute("BatNextSwingTime") or 0
	if not session or now < nextSwing then return end
	swinging = true
	-- Animation is local; the server validates this session and owns the launch.
	BattingRemote:FireServer(session)
	local token = generation
	if not stage(LOAD, LOAD_TIME, token) then return end
	if not stage(DRIVE, DRIVE_TIME, token) then return end
	if not stage(CONTACT, CONTACT_TIME, token) then return end
	if not stage(FOLLOW, FOLLOW_TIME, token) then return end
	task.wait(HOLD_TIME)
	if not stage(READY, RETURN_TIME, token) then return end
	if token == generation then swinging = false end
end)

local RunService = game:GetService("RunService")
local Storage = game:GetService("ReplicatedStorage")
local Tool = script.Parent
local Player = game:GetService("Players").LocalPlayer
local BattingRemote = Storage:WaitForChild("BattingTiming")
local Swing = require(Storage:WaitForChild("SwingConfig"))

local HAND_SPACING = 0.38
local function batFrame(position, barrel)
	local up = barrel.Unit
	-- A fixed reference away from the contact direction avoids a wrist flip there.
	local right = Vector3.xAxis:Cross(up).Unit
	return CFrame.fromMatrix(position, right, up)
end

-- Hand-authored key poses on the shared timeline. Local -Z faces the tee;
-- local -X is the lead side. Chest is RELATIVE to the hips, creating separation:
-- at Turn the hips are open while the shoulders and hands are still loaded.
-- Bat yaw unwraps through recovery, bringing it around the back, not back
-- through the contact point. Loft varies throughout the arc.
local poses = {
	Ready = {hands = Vector3.new(.75, .88, -.52), yaw = -45, loft = 62,
		hips = -6, chest = -10, weight = .02, crouch = -.14, lean = 4, sideBend = 0, lift = 0, pivot = 0, heel = 0},
	Load = {hands = Vector3.new(.88, .96, -.40), yaw = -55, loft = 56,
		hips = -15, chest = -18, weight = .13, crouch = -.19, lean = 5, sideBend = -2, lift = .10, pivot = 0, heel = 0},
	Plant = {hands = Vector3.new(.89, .95, -.42), yaw = -52, loft = 52,
		hips = -12, chest = -24, weight = .06, crouch = -.20, lean = 6, sideBend = -2, lift = 0, pivot = 0, heel = 0},
	Turn = {hands = Vector3.new(.71, .92, -.48), yaw = -32, loft = 40,
		hips = 12, chest = -25, weight = -.04, crouch = -.17, lean = 6, sideBend = 0, lift = 0, pivot = 9, heel = 6},
	Release = {hands = Vector3.new(.43, .62, -.94), yaw = 24, loft = 18,
		hips = 25, chest = -6, weight = -.12, crouch = -.14, lean = 5, sideBend = 2, lift = 0, pivot = 18, heel = 13},
	Contact = {hands = Vector3.new(-.03, .35, -1.25), yaw = 89, loft = 1,
		hips = 32, chest = 12, weight = -.17, crouch = -.10, lean = 4, sideBend = 3, lift = 0, pivot = 24, heel = 18},
	Extension = {hands = Vector3.new(-.63, .50, -1.22), yaw = 138, loft = 12,
		hips = 37, chest = 21, weight = -.20, crouch = -.08, lean = 3, sideBend = 3, lift = 0, pivot = 28, heel = 22},
	Follow = {hands = Vector3.new(-.91, 1.12, -.48), yaw = 214, loft = 44,
		hips = 42, chest = 24, weight = -.19, crouch = -.07, lean = 1, sideBend = 2, lift = 0, pivot = 30, heel = 23},
	Settle = {hands = Vector3.new(-.73, 1.02, -.82), yaw = 246, loft = 66,
		hips = 36, chest = 16, weight = -.14, crouch = -.10, lean = 2, sideBend = 1, lift = 0, pivot = 25, heel = 17},
}
poses.Recover = table.clone(poses.Ready)
poses.Recover.yaw = 315 -- Same orientation as Ready, continuous recovery around the shoulder.

-- Nonuniform cubic interpolation preserves momentum across pose boundaries.
-- Zero tangents at extrema prevent overshoot, and both ends settle to rest.
local keys = {{time = 0, pose = poses.Ready}}
local phaseTime = 0
for _, phase in Swing.Phases do
	phaseTime += phase.duration
	table.insert(keys, {time = phaseTime, pose = poses[phase.name]})
end
local function tangent(index, field)
	if index == 1 or index == #keys then return keys[index].pose[field] * 0 end
	local a, b, c = keys[index - 1], keys[index], keys[index + 1]
	local incoming = (b.pose[field] - a.pose[field]) / (b.time - a.time)
	local outgoing = (c.pose[field] - b.pose[field]) / (c.time - b.time)
	if typeof(incoming) == "number" and incoming * outgoing <= 0 then return 0 end
	return (c.pose[field] - a.pose[field]) / (c.time - a.time)
end
for index, key in keys do
	key.tangents = {}
	for field in key.pose do key.tangents[field] = tangent(index, field) end
end

local jointNames = {
	Root = true, RootJoint = true, Waist = true, Neck = true,
	LeftHip = true, RightHip = true, LeftKnee = true, RightKnee = true,
	LeftAnkle = true, RightAnkle = true, LeftShoulder = true, RightShoulder = true,
	LeftElbow = true, RightElbow = true, LeftWrist = true, RightWrist = true,
}
local poseConnections, lifetimeConnections, temporary, joints = {}, {}, {}, {}
local character, humanoid, root, palm, rightTarget, leftTarget
local leftFootTarget, rightFootTarget, leftFootFrame, rightFootFrame, rearToe
local rightPole, leftPole
local gripJoint, savedGrip, swingStarted
local contactFired = false
-- Local procedural-animation marker; never sends a launch/reward request.
local marker = Instance.new("BindableEvent")
marker.Name, marker.Parent = "SwingMarkerReached", Tool
local presentationReady, destroyed, warned = false, false, false
local nextInputTime = 0
local current = poses.Ready

local function cleanup()
	presentationReady, swingStarted = false, nil
	for _, connection in poseConnections do connection:Disconnect() end
	table.clear(poseConnections)
	for _, object in temporary do object:Destroy() end
	table.clear(temporary)
	for _, entry in joints do
		if entry.joint.Parent then
			if entry.attachment and entry.attachment.Parent then entry.attachment.CFrame = entry.base
			elseif entry.joint:IsA("Motor6D") then entry.joint.C0 = entry.base end
			entry.joint.Transform = entry.transform
		end
	end
	table.clear(joints)
	if gripJoint and gripJoint.Parent and savedGrip then
		gripJoint.C0 = savedGrip.c0
		if savedGrip.transform then gripJoint.Transform = savedGrip.transform end
	end
	gripJoint, savedGrip = nil, nil
	current = poses.Ready
end

local function presentationFailure(message)
	cleanup()
	if not warned then
		warn("Bat swing presentation unavailable; batting input remains enabled: " .. tostring(message))
		warned = true
	end
end

local function makeTarget(name, frame)
	local attachment = Instance.new("Attachment")
	attachment.Name, attachment.CFrame, attachment.Parent = name, frame, root
	table.insert(temporary, attachment)
	return attachment
end

local function makeArm(side, target, pole)
	local hand = character:FindFirstChild(side .. "Hand")
	local upperArm = character:FindFirstChild(side .. "UpperArm")
	local grip = hand and hand:FindFirstChild(side .. "GripAttachment")
	assert(grip and upperArm, "The procedural stance requires R15 hand grip attachments.")
	local ik = Instance.new("IKControl")
	table.insert(temporary, ik)
	ik.Name = "Bat" .. side .. "ArmIK"
	ik.Type = Enum.IKControlType.Position
	ik.ChainRoot, ik.EndEffector, ik.Target, ik.Pole = upperArm, grip, target, pole
	ik.SmoothTime, ik.Weight, ik.Priority = 0, 1, 10
	ik.Parent = humanoid
end

local function makeLeg(side)
	local foot = character:FindFirstChild(side .. "Foot")
	local upperLeg = character:FindFirstChild(side .. "UpperLeg")
	assert(foot and upperLeg, "The batting stance requires R15 legs.")
	-- Use the rig's rest joints, not the last walking-animation frame on entry.
	local frame = CFrame.identity
	for _, name in {"Root", side .. "Hip", side .. "Knee", side .. "Ankle"} do
		local joint = character:FindFirstChild(name, true)
		if not joint and name == "Root" then joint = character:FindFirstChild("RootJoint", true) end
		assert(joint, "Missing leg joint " .. name)
		if joint:IsA("AnimationConstraint") then
			frame *= joint.Attachment0.CFrame * joint.Attachment1.CFrame:Inverse()
		else
			frame *= joint.C0 * joint.C1:Inverse()
		end
	end
	-- A modestly wider base, preserving this avatar's floor height and foot size.
	frame = CFrame.new(side == "Left" and -.16 or .16, 0, 0) * frame
	local target = makeTarget("Bat" .. side .. "FootTarget", frame)
	local pole = makeTarget("Bat" .. side .. "KneePole", CFrame.new(side == "Left" and -1 or 1, -1, -3))
	local ik = Instance.new("IKControl")
	table.insert(temporary, ik)
	ik.Name, ik.Type = "Bat" .. side .. "LegIK", Enum.IKControlType.Transform
	ik.ChainRoot, ik.EndEffector, ik.Target, ik.Pole = upperLeg, foot, target, pole
	ik.SmoothTime, ik.Weight, ik.Priority = 0, 1, 10
	ik.Parent = humanoid
	return target, frame, foot
end

local function sampleSwing()
	if not swingStarted then return poses.Ready end
	local elapsed = os.clock() - swingStarted
	if not contactFired and elapsed >= Swing.Markers.Contact then
		contactFired = true
		marker:Fire("Contact")
	end
	for index = 2, #keys do
		local a, b = keys[index - 1], keys[index]
		if elapsed >= b.time then continue end
		local duration = b.time - a.time
		local t = math.clamp((elapsed - a.time) / duration, 0, 1)
		local t2, t3 = t * t, t * t * t
		local pose = {}
		for field, value in a.pose do
			pose[field] = (2*t3 - 3*t2 + 1)*value + (t3 - 2*t2 + t)*duration*a.tangents[field]
				+ (-2*t3 + 3*t2)*b.pose[field] + (t3 - t2)*duration*b.tangents[field]
		end
		if b.pose == poses.Recover then
			-- Keep the barrel above the head while the hands circle back to Ready.
			pose.loft += 35 * math.sin(math.pi * t)
		end
		return pose
	end
	swingStarted = nil
	return poses.Ready
end

local function angles(x, y, z)
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

local function jointOffset(name)
	if name == "Root" or name == "RootJoint" then
		return CFrame.new(current.weight, current.crouch, 0) * angles(0, current.hips, 0)
	elseif name == "Waist" then
		return angles(current.lean, current.chest, current.sideBend)
	elseif name == "Neck" then
		-- Counter-rotate most of the torso turn so the head stays near contact.
		return angles(-current.lean, -(current.hips + current.chest) * .8, -current.sideBend)
	end
end

local function currentBatFrame()
	local yaw, loft = math.rad(current.yaw), math.rad(current.loft)
	return batFrame(current.hands, Vector3.new(math.cos(yaw)*math.cos(loft), math.sin(loft), -math.sin(yaw)*math.cos(loft)))
end

local function updateTargets()
	if not root.Parent or not palm.Parent or humanoid.Health <= 0 then cleanup() return end
	current = sampleSwing()
	-- Set the body pose before Animator solves the arms against their targets.
	for _, entry in joints do
		local offset = jointOffset(entry.name)
		if offset then
			local frame = CFrame.new(entry.base.Position) * offset * entry.base.Rotation
			if entry.attachment then entry.attachment.CFrame = frame else entry.joint.C0 = frame end
		end
	end
	local bat = currentBatFrame()
	rightTarget.CFrame = bat
	leftTarget.CFrame = bat * CFrame.new(0, -HAND_SPACING, 0)
	local shoulders = angles(0, (current.hips + current.chest) * .55, 0)
	rightPole.CFrame = shoulders * CFrame.new(2, .2, .3)
	leftPole.CFrame = shoulders * CFrame.new(-2, -.1, -.9)
	leftFootTarget.CFrame = CFrame.new(0, current.lift, 0) * leftFootFrame
	-- Turn on the rear toe; the planted lead foot does not rotate with the pelvis.
	rightFootTarget.CFrame = rightFootFrame * CFrame.new(rearToe)
		* angles(-current.heel, current.pivot, 0) * CFrame.new(-rearToe)
end

local function updateGrip()
	-- Keep Roblox's native hand-to-Tool connection intact. Changing Part0 during
	-- equip can leave the server without a RightGrip, letting the real Bat fall.
	-- After IK resolves the hand, express the same root-relative arc in its frame.
	gripJoint.C0 = gripJoint.Part0.CFrame:ToObjectSpace(root.CFrame * currentBatFrame()) * gripJoint.C1
end

local function guardedUpdate(callback)
	local ok, message = pcall(callback)
	if not ok then presentationFailure(message) end
end

local function setupPresentation()
	character = Tool.Parent
	humanoid = character:FindFirstChildOfClass("Humanoid")
	root = character:FindFirstChild("HumanoidRootPart")
	local hand = character:FindFirstChild("RightHand")
	palm = hand and hand:FindFirstChild("RightGripAttachment")
	assert(humanoid and root and palm, "The procedural stance requires an R15 avatar.")
	gripJoint = hand:FindFirstChild("RightGrip")
	assert(gripJoint and (gripJoint:IsA("Weld") or gripJoint:IsA("Motor6D")), "Missing Tool grip joint.")
	savedGrip = {c0 = gripJoint.C0,
		transform = gripJoint:IsA("Motor6D") and gripJoint.Transform or nil}
	if savedGrip.transform then gripJoint.Transform = CFrame.identity end
	local bat = currentBatFrame()
	rightTarget = makeTarget("BatRightPalmTarget", bat)
	leftTarget = makeTarget("BatLeftPalmTarget", bat * CFrame.new(0, -HAND_SPACING, 0))
	rightPole = makeTarget("BatRightElbowPole", CFrame.new(2, .2, .3))
	leftPole = makeTarget("BatLeftElbowPole", CFrame.new(-2, -.1, -.9))
	makeArm("Right", rightTarget, rightPole)
	makeArm("Left", leftTarget, leftPole)
	leftFootTarget, leftFootFrame = makeLeg("Left")
	local foot
	rightFootTarget, rightFootFrame, foot = makeLeg("Right")
	rearToe = Vector3.new(0, -foot.Size.Y/2, -foot.Size.Z/2)
	for _, joint in character:GetDescendants() do
		if jointNames[joint.Name] and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			local attachment = joint:IsA("AnimationConstraint") and joint.Attachment0
			if joint:IsA("Motor6D") or attachment then
				table.insert(joints, {joint = joint, name = joint.Name, attachment = attachment,
					base = attachment and attachment.CFrame or joint.C0, transform = joint.Transform})
			end
		end
	end
	presentationReady = true
	updateTargets()
	table.insert(poseConnections, RunService.PreAnimation:Connect(function() guardedUpdate(updateTargets) end))
	table.insert(poseConnections, RunService.PreSimulation:Connect(function() guardedUpdate(updateGrip) end))
	table.insert(poseConnections, humanoid.Died:Connect(cleanup))
end

local function updateMode()
	if destroyed then return end
	local active = Player:GetAttribute("BattingActive") or Player:GetAttribute("TrainingActive")
	if not active or Tool.Parent ~= Player.Character then cleanup() return end
	if presentationReady then return end
	cleanup()
	guardedUpdate(setupPresentation)
end

local function playSwing()
	if presentationReady and not swingStarted then
		contactFired = false
		swingStarted = os.clock()
	end
end

table.insert(lifetimeConnections, Tool.Activated:Connect(function()
	-- Presentation failure/unsupported rigs cannot disable an otherwise valid request.
	if Tool.Parent ~= Player.Character or os.clock() < nextInputTime
		or Player:GetAttribute("TrainingActive") or Player:GetAttribute("HitActive")
		or not Player:GetAttribute("BattingActive") or Tool:GetAttribute("ExitPending") then return end
	local session = Tool:GetAttribute("BattingSession")
	if not session or workspace:GetServerTimeNow() < (Player:GetAttribute("BatNextSwingTime") or 0) then return end
	nextInputTime = os.clock() + Swing.Duration
	BattingRemote:FireServer(session)
	playSwing()
end))

-- Client-local presentation only; it never sends a real swing or grants Power.
local practice = Instance.new("BindableEvent")
practice.Name, practice.Parent = "PracticeSwing", Tool
table.insert(lifetimeConnections, practice.Event:Connect(function()
	if Player:GetAttribute("TrainingActive") then playSwing() end
end))
table.insert(lifetimeConnections, Tool.Equipped:Connect(updateMode))
table.insert(lifetimeConnections, Tool.Unequipped:Connect(cleanup))
table.insert(lifetimeConnections, Player:GetAttributeChangedSignal("BattingActive"):Connect(updateMode))
table.insert(lifetimeConnections, Player:GetAttributeChangedSignal("TrainingActive"):Connect(updateMode))
table.insert(lifetimeConnections, Player.CharacterRemoving:Connect(cleanup))

local function destroy()
	if destroyed then return end
	destroyed = true
	cleanup()
	for _, connection in lifetimeConnections do connection:Disconnect() end
	table.clear(lifetimeConnections)
	practice:Destroy()
	marker:Destroy()
end
table.insert(lifetimeConnections, Tool.Destroying:Connect(destroy))
table.insert(lifetimeConnections, script.Destroying:Connect(destroy))
updateMode()

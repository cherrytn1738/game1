local Field = {
 Width = 6600, GroundTop = 0.02, GroundThickness = 8, MaximumPartSize = 2000,
 MarkerInterval = 100, DistantMarkerInterval = 500, DenseMarkersUntil = 1000,
 StopLinearSpeed = 1, StopSurfaceSpeed = 2, StopHoldSeconds = 0.75,
 RollingDeceleration = 12, MaximumFlightSeconds = 120,
 -- The whole hit plays at this steady time scale from launch (velocity x s, gravity and
 -- rolling friction x s^2): it takes 1/s of the time with no visible change of speed. (A
 -- roll-only fast-forward was replaced: switching speed after landing looked like the ball
 -- suddenly accelerating.)
 HitTimeScale = 1.6,
 -- 2x ball flight is disabled: switching speed changed final distance in playtests.
 FlightSpeedUpEnabled = false,
}
function Field.GetWidth(world)
 return world.runway and world.runway.width or Field.Width
end
function Field.GetSection(distance, world)
 if distance < 0 or distance > world.endDistance + world.runoutDistance then return nil end
 for index, section in world.sections do
  if distance >= section.startDistance
   and (distance < section.endDistance or index == #world.sections) then return section end
 end
 return nil
end
function Field.GetById(id, world)
 for _, section in world.sections do if section.id == id then return section end end
 return nil
end
function Field.GetForwardDistance(position, origin, forward)
 return math.max(0, (position - origin):Dot(forward))
end
function Field.GetSectionAtPosition(position, origin, forward, world)
 local displacement = position - origin
 if math.abs(displacement:Dot(forward:Cross(Vector3.yAxis))) > Field.GetWidth(world) / 2 then return nil end
 return Field.GetSection(displacement:Dot(forward), world)
end
function Field.GetRewardSection(distance, world)
 return Field.GetSection(distance, world)
end
return Field

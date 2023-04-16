-- Data about the map, such as position knowledge, to allow for map-specific bot behavior


-- The map data itself, initialized near the start of the game
map_data = {}


-- Initializes the map data
-- Should be called before the first round
function LoadMapData()
  -- Load hunt point positions (used by the bots when searching for the enemy)
  local hunt_points = {}

  for _, entity in pairs(Entities:FindAllByName("bot_hunt_point")) do
    -- Add each marker entity's ground position
    local point = GetGroundPosition(entity:GetAbsOrigin(), nil)
    table.insert(hunt_points, point)
  end

  -- Find the highest point
  local compare = function(a, b)
    return (not a) or (b.z > a.z)
  end
  local max_height = MaxBy(hunt_points, compare).z

  -- Also find all hunt points on the highground for easier searching later
  local highground_hunt_points = {}

  for _, point in pairs(hunt_points) do
    if point.z == max_height then
      table.insert(highground_hunt_points, point)
    end
  end

  map_data.hunt_points = hunt_points
  map_data.highground_hunt_points = highground_hunt_points
end


-- An iterator over randomly ordered hunt points
RandomHuntPoints = {}
RandomHuntPoints.__index = RandomHuntPoints


-- Returns a new iterator over randomly ordered hunt points
-- Only returns points on the highground if `only_highground` is true
-- Only returns points for which `filter` returns true if specified
function RandomHuntPoints:New(only_highground, filter)
  local iterator = {}
  setmetatable(iterator, RandomHuntPoints)

  -- Applies `filter` to `points` and returns them
  local filter_points = function(points)
    local filtered = {}

    for _, point in pairs(points) do
      if (not filter) or filter(point) then
        table.insert(filtered, point)
      end
    end

    return filtered
  end

  local points = {}

  -- Get all points of the specified type and apply the filter to them
  if only_highground then
    points = filter_points(map_data.highground_hunt_points)
  else
    points = filter_points(map_data.hunt_points)
  end

  -- Randomize their order
  iterator.points = RandomizeList(points)
  iterator.index = 1
  iterator.only_highground = only_highground
  iterator.filter = filter

  return iterator
end


-- Returns the next hunt point in the iterator
-- Restarts the iterator with a new random order if no more points are available
function RandomHuntPoints:Next()
  local point = self.points[self.index]

  -- Increment the index for the next call
  self.index = self.index + 1

  -- Re-randomize the points if all points have been returned
  if self.index > #self.points then
    self.points = RandomizeList(self.points)
    self.index = 1
  end

  return point
end

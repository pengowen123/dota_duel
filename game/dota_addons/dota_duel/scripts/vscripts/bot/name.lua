-- Logic for selecting bots' names


names = {
  "Agnes",
  "Buster",
  "Chad",
  "Chai",
  "Chester",
  "Chuck",
  "Cookie",
  "Edith",
  "Finn",
  "Flo",
  "Gob",
  "Gobber",
  "Gus",
  "Hank",
  "Harold",
  "Juan",
  "Kai",
  "Lacie",
  "Lionel",
  "Lucille",
  "Luna",
  "Lupe",
  "Maeby",
  "Miko",
  "Mischa",
  "Max",
  "Oreo",
  "Sam",
  "Scooter",
  "Sneed",
  "Tobias",
  "Tony",
  "Walter",
}


-- Returns a random name for a bot
function PickBotName()
  local index = RandomInt(1, #names)
  local name = names[index] .. " Bot"

  -- Prevent multiple bots from sharing the same name
  table.remove(names, index)

  return name
end
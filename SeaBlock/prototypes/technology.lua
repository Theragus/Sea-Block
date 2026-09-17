-- The three sb-*-tool items exist only to put a recognisable cost on the
-- tutorial technologies in the tech tree; control.lua completes those
-- technologies outright. Their icons are copied from the real prototypes in
-- data-final-fixes, so the ones here are base game placeholders: pointing
-- straight at another mod's file means a silent break every time that mod
-- moves or resizes it, and Sea Block does not depend on the graphics mods
-- those files actually live in.
data:extend({
  {
    type = "item",
    name = "sb-angelsore3-tool",
    localised_name = { "item-name.angels-ore3-crushed" },
    icon = "__base__/graphics/icons/iron-ore.png",
    icon_size = 64,
    hidden = true,
    stack_size = 100,
  },
  {
    type = "item",
    name = "sb-basic-circuit-board-tool",
    localised_name = { "item-name.basic-circuit-board" },
    icon = "__base__/graphics/icons/electronic-circuit.png",
    icon_size = 64,
    hidden = true,
    stack_size = 100,
  },
  {
    type = "item",
    name = "sb-lab-tool",
    localised_name = { "item-name.lab" },
    icon = "__base__/graphics/icons/lab.png",
    icon_size = 64,
    hidden = true,
    stack_size = 100,
  },
  {
    type = "technology",
    name = "sb-startup1",
    icon = "__SeaBlock__/graphics/technology/ore.png",
    icon_size = 128,
    effects = {
      { type = "unlock-recipe", recipe = "iron-plate" },
      { type = "unlock-recipe", recipe = "copper-plate" },
      { type = "unlock-recipe", recipe = "copper-cable" },
    },
    unit = {
      count = 1,
      ingredients = { { "sb-angelsore3-tool", 1 } },
      time = 1,
    },
  },
  {
    type = "technology",
    name = "sb-startup3",
    icon = "__SeaBlock__/graphics/technology/basic-circuit-board.png",
    icon_size = 128,
    effects = {
      { type = "unlock-recipe", recipe = "inserter" },
      { type = "unlock-recipe", recipe = "pipe" },
      { type = "unlock-recipe", recipe = "pipe-to-ground" },
      { type = "unlock-recipe", recipe = "bob-copper-pipe" },
      { type = "unlock-recipe", recipe = "bob-copper-pipe-to-ground" },
      { type = "unlock-recipe", recipe = "iron-stick" },
      { type = "unlock-recipe", recipe = "iron-gear-wheel" },
      { type = "unlock-recipe", recipe = "burner-inserter" },
      { type = "unlock-recipe", recipe = "iron-chest" },
    },
    prerequisites = { "angels-bio-wood-processing" },
    unit = {
      count = 1,
      ingredients = { { "sb-basic-circuit-board-tool", 1 } },
      time = 1,
    },
  },
  {
    type = "technology",
    name = "sb-startup4",
    icon = "__SeaBlock__/graphics/technology/lab.png",
    icon_size = 128,
    effects = {
      { type = "unlock-recipe", recipe = "automation-science-pack" },
    },
    prerequisites = { "sb-startup3" },
    unit = {
      count = 1,
      ingredients = { { "sb-lab-tool", 1 } },
      time = 1,
    },
  },
  {
    type = "technology",
    name = "sb-bio-processing-advanced",
    localised_name = { "technology-name.angels-bio-processing-green" },
    localised_description = { "technology-description.angels-bio-processing-green" },
    icon = "__angelsbioprocessinggraphics__/graphics/technology/algae-farm-tech.png",
    icon_size = 128,
    order = "c-a",
    prerequisites = {
      "angels-bio-processing-red",
      "advanced-circuit",
      "angels-stone-smelting-2",
      "bob-zinc-processing",
      "chemical-science-pack",
    },
    effects = {
      {
        type = "unlock-recipe",
        recipe = "angels-algae-farm-4",
      },
    },
    unit = {
      count = 50,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
        { "angels-token-bio", 1 },
        { "chemical-science-pack", 1 },
      },
      time = 30,
    },
  },
  {
    type = "technology",
    name = "steam-power",
    icon = "__base__/graphics/icons/fluid/steam.png",
    icon_size = 64,
    prerequisites = {},
    effects = {
      {
        type = "unlock-recipe",
        recipe = "boiler",
      },
      {
        type = "unlock-recipe",
        recipe = "steam-engine",
      },
    },
    unit = {
      count = 10,
      ingredients = {
        { "automation-science-pack", 1 },
      },
      time = 10,
    },
    order = "a-a",
  },
})

bobmods.lib.recipe.enabled("boiler", false)
bobmods.lib.recipe.enabled("steam-engine", false)
bobmods.lib.recipe.enabled("bob-copper-pipe-to-ground", false)
bobmods.lib.recipe.enabled("bob-basic-circuit-board", false)
bobmods.lib.recipe.enabled("automation-science-pack", false)
if data.raw.recipe["bob-basic-transport-belt"] then
  bobmods.lib.tech.add_recipe_unlock("sb-startup3", "bob-basic-transport-belt")
else
  bobmods.lib.tech.add_recipe_unlock("sb-startup3", "transport-belt")
end

if mods["bobwarfare"] then
  data:extend({
    {
      type = "technology",
      name = "sb-sniper-rifle",
      localised_name = { "item-name.bob-sniper-rifle" },
      icon_size = 256,
      icon = "__base__/graphics/technology/military.png",
      effects = {
        {
          type = "unlock-recipe",
          recipe = "bob-sniper-rifle",
        },
      },
      prerequisites = { "military-science-pack" },
      unit = {
        count = 200,
        ingredients = {
          { "automation-science-pack", 1 },
          { "logistic-science-pack", 1 },
          { "military-science-pack", 1 },
        },
        time = 15,
      },
    },
  })
end

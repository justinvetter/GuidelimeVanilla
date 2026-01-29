# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GuideLime Vanilla is a World of Warcraft Classic (1.12) addon that provides an enhanced guide system with automatic quest tracking, autonomous navigation, and smart UI management. It's a port of the Guidelime addon adapted for Vanilla WoW (TurtleWoW private server).

## Development Environment

- **Target**: WoW Classic 1.12 (Turtle WoW)
- **Language**: Lua 5.0 (no modern Lua features like `#` operator, use `table.getn()`)
- **Testing**: Load addon in WoW, use `/reload` to test changes
- **Debug Mode**: Set `GLV.Debug = true` in Core.lua for verbose logging

## Architecture

### Core Module System

The addon uses LibStub for module registration and Ace2 libraries for core functionality:

```
GLV = LibStub("GuidelimeVanilla")  -- Main addon object, accessible everywhere
GLV.Addon = AceAddon instance     -- Ace2 addon with events, hooks, console, DB
```

Key global objects:
- `GLV.Settings` - Settings manager with nested key access
- `GLV.Parser` - Guide text parser
- `GLV.QuestTracker` - Quest event tracking
- `GLV.CharacterTracker` - XP/level tracking
- `GLV.TaxiTracker` - Flight path tracking
- `GLV.GossipTracker` - Gossip dialog tracking
- `GLV.GuideNavigation` - Arrow navigation and guide transitions (arrow display, next guide button)
- `GLV.CurrentGuide` - Currently loaded guide data (includes `.clickToNext` and `.next` for guide chaining)
- `GLV.CurrentDisplaySteps` - Filtered/displayed steps array

### Data Flow

1. **Guide Registration**: `GLV:RegisterGuide(text, group)` parses and stores guides
2. **Guide Loading**: `GLV:LoadGuide(group, id)` parses guide, creates UI steps
3. **Event Tracking**: Hooks on quest accept/complete trigger `QuestTracker:HandleQuestAction()`
4. **UI Updates**: `GLV:RefreshGuide()` redraws steps, `updateStepColors()` handles highlighting

### Settings System

Access settings via nested key arrays:
```lua
GLV.Settings:GetOption({"Guide", "Guides", guideId, "StepState"})
GLV.Settings:SetOption(value, {"Guide", "CurrentGuide"})
```

### Database (VGDB)

Quest/NPC/Item data from ShaguDB stored in `db/` folder:
- `VGDB.quests[locale][id]` - Quest data with `.T` (title), `.start`, `.end`, `.obj`
- `VGDB.units.data[id]` - NPC coords in `.coords[n] = {x, y, zoneId}`
- `VGDB.items.data[id]` - Item coords and drop sources (`.U`, `.O`)
- `VGDB.zones[locale][id]` - Zone name translations

### Navigation System

The navigation frame displays different modes based on current step:
- **Arrow Mode** (default): Shows directional arrow to waypoint with distance/objective
- **Equip Item Mode**: Shows item icon with "Equip" instruction when step contains equip action
- **Next Guide Mode**: Shows clickable "Next Guide" button when on last step with `[NX]` tag

Key methods:
- `GuideNavigation:ShowNextGuide(nextGuideName)` - Display next guide button and parse/load guide on click
- `GuideNavigation:HideNextGuide()` - Return to arrow mode
- `GuideNavigation:ShowEquipItem(itemId)` - Display equip item icon
- `GuideNavigation:HideEquipItem()` - Return to arrow mode

## Guide Syntax

Guides use tagged format parsed by `GuideParser.lua`:

| Tag | Meaning | Example |
|-----|---------|---------|
| `[N x-y Name]` | Guide name and level range | `[N 1-11 Elwynn Forest]` |
| `[GA faction]` | Alliance/Horde filter | `[GA Alliance]` |
| `[QA id]` | Accept quest | `[QA783]` |
| `[QC id]` | Complete quest | `[QC33]` |
| `[QT id]` | Turn in quest | `[QT783]` |
| `[TAR id]` | NPC/target reference | `[TAR823]` |
| `[A class]` | Class-specific step | `[A Mage] [QA3104]` |
| `[XP level]` | XP requirement | `[XP4-290]` |
| `[OC]` | Optional, completes with next | `[OC]Grind north` |
| `[NX x-y Name]` | Link to next guide (shows clickable button on last step) | `[NX 11-13 Westfall]` |
| `[P name]` | Get flight path | `[P Stormwind]` |
| `[H]` | Use hearthstone | `[H] to Stormwind` |

## Key Files

- `Core.lua` - Addon initialization, character loading, quest sync
- `Core/GuideParser.lua` - Tag parsing, step extraction
- `Core/GuideLibrary.lua` - Guide registration, dropdown, loading
- `Core/GuideWriter.lua` - UI creation, checkbox handling, highlighting
- `Core/GuideNavigation.lua` - Arrow navigation using Astrolabe, next guide button for guide transitions
- `Core/Events/Quests.lua` - Quest hooks and state tracking
- `Helpers/DBTools.lua` - Database query functions (quest/NPC/item lookups)

## Lua 5.0 Compatibility Notes

```lua
-- Use these patterns for Vanilla WoW compatibility:
table.getn(t)           -- NOT #t
string.gfind(s, pat)    -- NOT string.gmatch
string.find(s, pat)     -- NOT string.match (use captures with string.find)
getglobal("name")       -- For dynamic frame access
this                    -- Inside XML event handlers, NOT self
```

## WoW 1.12 UI Limitations

- **No inline textures in text**: The `|Tpath:size|t` escape sequence does NOT work in WoW 1.12. To show icons inline with text, you must create separate Texture/Button frames and position them manually, or use colored text characters as substitutes.
- **Limited escape sequences**: Only `|cAARRGGBB` (color) and `|r` (reset) work reliably in FontStrings.

## Adding New Guides

1. Create `.lua` file in `Guides/` subdirectory
2. Register with: `GLV:RegisterGuide([[guide text]], "Group Name")`
3. Add to `Guides/guides.xml`: `<Script file="SubDir\Guide_Name.lua"/>`

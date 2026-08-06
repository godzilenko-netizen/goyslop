# Changelog

## [Unreleased]
### Fixed
- Inventory is now functional: 60 storage slots support stacking, drag-and-drop, sorting, equipment validation, consumable use, starter items, gold, and state serialization.
- Player movement and combat input are locked while the inventory is open.
- Troll now has exactly one collision shape, properly disables it while dead, and respawns exactly 10 seconds after death.
- Troll enters Aggro when the player comes within `aggro_range`, as described.
- Knockback keeps player controls locked until the character actually lands before playing Getting Up.
- Overlapping freeze and burn effects no longer leave the Troll permanently slowed.
- Removed duplicate HUD tooltip construction and corrected scene `load_steps` metadata so UI nodes are no longer skipped during instantiation.
- Windows Compatibility rendering is pinned to OpenGL 3 to avoid Vulkan surface errors.
- Replaced smoke-only scripts with asserting scene, HUD, physics, inventory, Troll-state, and knockdown tests.
- Removed temporary repository patch scripts.
- Removed the unused duplicate `Trollo.obj`, which referenced a missing material library and broke clean imports.

### Added
- **Troll Mob**: Added a new enemy "Troll" with customized logic and behaviors.
  - Implemented 3 states: Circling, Aggro (chasing), and Attacking.
  - Troll dynamically targets the player and circles around them until provoked or if the player gets too close.
  - Dynamic AnimationPlayer creation to support custom FBX animations (Capoeira for movement, Baseball Hit for attacks, Dying).
  - Health bar UI dynamically floating above the Troll.
  - Troll respawns automatically 10 seconds after dying with full HP.
- **Player Knockback Physics**: Added a physics-driven knockback system when hit by heavy attacks.
  - The Troll's bat attack physically launches the player backwards and slightly into the air.
  - Control is completely disabled while the player is flying backwards.
- **Player Reaction Animations**: 
  - Added `Falling Back` animation (plays while the player is launched in the air).
  - Added `Getting Up` animation (plays automatically after landing).
  - Both animations are scaled to 1.5x speed to keep combat fast and snappy.
- **Death States**:
  - Player now has an `is_dead` state. Reaching 0 HP triggers the `Death` animation and permanently locks controls.
- **Visual Status Effects**: 
  - Troll now shows visual overlays when hit by spells (Blue ice for Ice Arrow, Orange fire/emissions for Fireball).

### Changed
- Increased Troll attack damage from 20 to 40.
- Troll now pauses for exactly 0.5 seconds **only** after a successful attack on the player, preventing permanent stunlocking.
- Increased Fireball and Ice Arrow casting animation speeds (1.5x) for smoother combat flow.
- Projectile spawn timings adjusted to match the new faster cast speeds perfectly (releasing at 40-50% of the animation).

# Changelog

## [Unreleased]
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

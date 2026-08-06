# Project architecture

This project uses Godot scene composition, typed resources, small state-owning components, and signals between gameplay and UI.

## Dependency direction

Gameplay data must not depend on UI. UI reads data or subscribes to signals and never writes actor fields directly.

```text
SkillData / InventoryModel
          ↓
PlayerStats / HealthComponent / Player combat
          ↓ signals
       HUD / InventoryUI
```

## Current modules

- `data/skills/*.tres` is the single source of truth for skill damage, mana cost, cooldown, range, projectile behavior, and status effects.
- `scripts/components/player_stats.gd` owns player health, energy, experience, and level progression.
- `scripts/components/health_component.gd` is reusable enemy health and death state.
- `scripts/data/inventory_model.gd` owns storage, equipment, stacking, sorting, gold, and serialization. Inventory UI only presents that model.
- `scripts/player.gd` coordinates input, movement, animation, and combat using the components and resources above.
- `scripts/projectile.gd` receives a `SkillData` resource before entering the scene tree.
- `scripts/hud.gd` subscribes to player-stat signals and builds skill cards from `SkillData`.

## Rules for new gameplay code

1. Add tunable content as a `.tres` resource instead of copying constants into scripts or UI.
2. A component is the only owner of its state. Other nodes call methods and listen to signals.
3. Use enums for finite states; do not use state-name strings.
4. UI must not call `set()` on gameplay properties or update gameplay state directly.
5. Scene scripts may coordinate components but should not recreate shared data for every instance.
6. Every new system needs at least one headless test for its state transitions or serialization.

## Adding a skill

1. Create a `SkillData` resource in `data/skills/`.
2. Assign it to a player/hotbar slot.
3. Reuse an existing projectile effect, or add a dedicated projectile behavior if the mechanic is genuinely different.
4. Do not hardcode its numbers in HUD text; HUD reads the resource.

## Adding an enemy

1. Compose a scene from a body, collision, `HealthComponent`, visuals, and an AI controller.
2. Keep health/status logic out of the AI state machine.
3. Cache or prebuild animation libraries; do not rebuild imported FBX animation data for every instance.

## Planned extraction points

- Split projectile visuals/impact presentation from projectile flight when a third production skill is added.
- Add `ItemData` resources when real loot definitions are introduced; saved inventory should continue to store stable item IDs and quantities.
- Add a versioned `SaveService` before persistent world progress is enabled.
- Convert imported player and enemy animation sets into editor-built reusable libraries to remove first-load runtime assembly.

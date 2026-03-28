# Ship Customization System Implementation

## Summary

Implemented a comprehensive ship customization system that adds 8 new gameplay-affecting stats to ships and a visual ship selection UI.

## New Ship Stats

Each ship now has the following customizable attributes:

1. **Inventory Size** (Small/Medium/Large) - 0.5×/1.0×/2.0× multiplier on bullet slider
2. **Fire Rate** (Slow/Medium/Fast) - 2.0×/1.0×/0.5× fire interval
3. **Flight Speed** (Slow/Medium/Fast) - 0.9×/1.0×/1.1× max speed
4. **Hit Points** (Low/Medium/High) - 1.0×/1.5×/2.0× base HP
5. **Bullet Power** (Low/Medium/High) - 0.5/1.0/1.5 damage per hit
6. **Shield Type** (None/Back) - None = uniform HP, Back = 75% rear/25% front
7. **Turn Rate** (Slow/Medium/Fast) - 0.7×/1.0×/1.3× turning speed
8. **Notes** - Text description displayed in ship selection UI

## Key Changes

### ShipProfiles.swift

- Added 7 new enums for ship stats (InventorySize, FireRate, FlightSpeed, HitPoints, BulletPower, ShieldType, TurnRate)
- Converted physics properties to `base*` values with computed properties that apply multipliers
- Added `notes` field for ship descriptions
- Updated `ShipProfile.needle` and `ShipProfile.dart` with differentiated stats:
  - **Needle**: Balanced all-around, no shield
  - **Wedge**: Slower fire rate, higher HP, rear shield
- Added `ShipProfile.allShips` array for iteration
- Added hit point tracking to `Ship` class:
  - `currentHitPoints`, `frontHitPoints`, `rearHitPoints`
  - `takeDamage(_:fromRear:)` method with shield-aware damage
  - `resetHitPoints()` for respawning

### GameScene.swift

- Updated collision system to apply damage instead of instant-kill
- Bullet damage determined by firing ship's `bulletPower`
- Hit direction calculated from bullet angle vs ship facing
- Ships can now survive multiple hits before exploding
- Hit points restored on respawn
- Updated `bulletsForSelection(_:ship:)` to apply inventory multiplier
- Updated `bulletLabelText(_:ship:)` to use ship-specific values
- Added ship wheel touch handling in `touchesBegan`

### GameScene+Options.swift

- Replaced "Coming Soon" placeholder with ship selection UI
- Updated bullet counter labels to use ship-specific multipliers

### GameScene+ShipSelection.swift (NEW)

- Implemented pseudo-3D ship selection wheels
- Shows previous/current/next ship with scaling and opacity
- Touch zones for scrolling up/down through ships
- Prevents selecting same ship on both wheels
- Displays all ship stats below wheel (except shield, which is in notes)
- Dynamically updates ship profiles when selection changes
- Recreates Ship instances with new profiles

## Ship Selection UI Design

- Two vertical wheels (left = Player 1/Needle, right = Player 2/Wedge)
- Each wheel shows 3 ships:
  - **Current** (center): full size, 100% opacity
  - **Previous** (above): 60% scale, 40% opacity
  - **Next** (below): 60% scale, 40% opacity
- Click above current ship → scroll to previous
- Click below current ship → scroll to next
- Wraparound: list loops seamlessly
- Selected ship on one wheel is grayed out and unselectable on the other

## Stat Display Format

Below each wheel:
```
[Ship Name]
Inventory: Small/Medium/Large
Fire Rate: Slow/Medium/Fast
Speed: Slow/Medium/Fast
HP: Low/Medium/High
Bullet Power: Low/Medium/High
Turn Rate: Slow/Medium/Fast

[Notes text - word wrapped]
```

## Gameplay Impact

- **Inventory**: Player with "Small" gets 50% fewer bullets (5 instead of 10, 25 instead of 50)
- **Fire Rate**: "Slow" ships must wait 2× longer between shots
- **Flight Speed**: "Fast" ships move 10% faster
- **Hit Points**: "Medium" HP ship takes 50% more hits to destroy
- **Bullet Power**: "Low" power bullets do half damage (need 2 hits to kill Low HP ship)
- **Shield**: "Back" shield ships are harder to kill from behind (75% of HP allocated to rear)
- **Turn Rate**: "Slow" ships turn 30% slower

## Testing Notes

- Bullet speed automatically scales above ship max speed (enforced in computed property)
- Hit direction uses ±45° rear quadrant for shield calculation
- Ship-vs-ship collision still instant-kills both ships
- Sun collision still instant-kills
- Hit points restore on respawn
- Ship profile changes require new Ship instance (handled automatically in wheel UI)

## Future Enhancements

- Add more ship types with different stat combinations
- Health bar UI (currently no visual HP indicator)
- Visual damage effects (ship color change, sparks, etc.)
- Ship unlocking/progression system
- Save/load ship preferences

# Debug Logging Added

## Issues Being Investigated

1. **15-second respawn delay** (sometimes)
2. **Wedge not exploding into wreckage** (fades away instead)
3. **Wedge killing Maa'gaa with one bullet from behind** (should take 2)

## Debug Logs Added

### 1. Damage System Logging (`ShipProfiles.swift` - `Ship.takeDamage`)

Every time a ship takes damage, you'll see console output like:

```
💥 Maa'gaa taking 1.0 damage from REAR
   Shield: .back | Front HP: 0.375 | Rear HP: 1.125
   → Rear HP after hit: 0.125
   ✓ Survived | Total HP: 0.5
```

This logs:
- Ship name and damage amount
- Whether hit is from front or rear
- Current HP pools (if shield is active)
- HP after damage
- Whether ship survived or was destroyed

### 2. Hit Detection Logging (`GameScene.swift` - bullet collision)

When a bullet hits a ship:

```
🎯 Wedge bullet hit Maa'gaa
   Ship forward angle: 45.0°
   Hit angle: 225.0°
   Angle diff: 180.0°
   From rear: true
```

This logs:
- Which ship fired the bullet
- Which ship was hit
- The ship's forward-facing angle
- The angle of the hit
- Whether it was classified as a rear hit

### 3. Explosion System Logging (`GameScene.swift` - `explodeShip`)

When a ship explodes:

```
💥 explodeShip called for Wedge at position (800.0, 400.0)
   🔧 Created 5 debris pieces
   ✓ Explosion complete, 5 pieces added to scene
```

This logs:
- Which ship is exploding
- Position of explosion
- How many debris pieces were created
- Confirmation that pieces were added to the scene

## Expected Behavior

### Maa'gaa Rear HP Calculation:
- Base HP: 1.0
- HP multiplier (`.high`): 1.5x = **1.5 total HP**
- Shield (`.back`): 75% rear, 25% front
- **Rear HP: 1.125**
- **Front HP: 0.375**

### Wedge Damage:
- Bullet power (`.medium`): **1.0 damage per shot**

### Expected Shots to Kill Maa'gaa from Behind:
- 1st shot: 1.125 - 1.0 = **0.125 HP remaining**
- 2nd shot: 0.125 - 1.0 = **destroyed** ✓

**Wedge should need 2 shots to destroy Maa'gaa from behind.**

## How to Test

1. Run the game with the console visible
2. Fire at Maa'gaa from different angles
3. Watch for the debug output in the console
4. Compare actual behavior with expected calculations

## Fix for Respawn Delay

**FIXED**: The respawn system now intelligently handles proximity conflicts:

1. **Multiple attempts**: When respawn is triggered, the system tries up to 5 different random positions
2. **Immediate retry on conflict**: If all 5 positions are too close to other ships, the system schedules a retry in only **0.5 seconds** (not the full bulletLifeSeconds delay)
3. **Consistent separation**: Both `safeRandomPosition` and `respawnShip` now use the same 300-pixel minimum separation distance
4. **Fresh positions on retry**: The cached respawn target is cleared when blocked, ensuring new positions are tried on the next attempt

### How It Works:

```swift
// Try 5 random positions immediately
for attempt in 0..<5 {
    let candidatePos = /* find a position */
    if isSafe(candidatePos) {
        respawn(at: candidatePos)
        return  // Success!
    }
}

// If all 5 failed, retry in 0.5 seconds (not 15 seconds)
scheduleRetry(in: 0.5)
```

This ensures ships never wait more than ~2.5 seconds total (5 attempts × 0.5 second intervals) to respawn, even in crowded situations.

## Next Steps

Once you run the game and see the debug output, we can:
1. Verify if wedge is creating debris (check for "Created X debris pieces" log)
2. Verify rear-hit detection is working (check angle calculations)
3. Verify damage calculations match expectations
4. Fix any discrepancies found

---

**Note**: These debug logs are verbose. Remove them once issues are resolved for better performance.

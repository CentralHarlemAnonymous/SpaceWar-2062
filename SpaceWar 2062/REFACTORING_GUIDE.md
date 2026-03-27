# Refactoring Guide: Generalizing the Update Loop

## Current State (Hardcoded for 2 Ships)

The current `update(_:)` method has separate code blocks for needle and dart:

```swift
// MARK: Rotation (Needle)
if !needle.node.isHidden {
    if needleAIEnabled {
        // ... needle-specific AI code ...
        rotateShip(needle, toward: aimTarget, dt: dt)
        isThrustingNeedle = computeThrust(...)
        if computeFire(...) {
            fireMissile(from: needle, ...)
        }
    } else if let p = aimPoint {
        rotateShip(needle, toward: p, dt: dt)
    }
}

// MARK: Rotation (Dart/Wedge)
if !dart.node.isHidden {
    if wedgeAIEnabled {
        // ... dart-specific AI code ...
        rotateShip(dart, toward: aimTarget, dt: dt)
        isThrustingDart = computeThrust(...)
        if computeFire(...) {
            fireMissile(from: dart, ...)
        }
    } else if let p = aimPoint {
        rotateShip(dart, toward: p, dt: dt)
    }
}

// Thrust application
if isThrustingDart {
    dart.applyThrust(dt: CGFloat(dt))
    dart.flame.alpha = 1
} else {
    dart.flame.alpha = 0
}

if isThrustingNeedle {
    needle.applyThrust(dt: CGFloat(dt))
    needle.flame.alpha = 1
} else {
    needle.flame.alpha = 0
}
```

## Target State (Generalized Loop)

Replace the entire section with a single loop:

```swift
// MARK: Ship AI, Rotation & Thrust
for ship in ships where ship.isVisible {
    updateShip(ship, currentTime: currentTime, dt: dt)
}
```

## Step-by-Step Migration

### Step 1: Move AI State to ShipState

Replace these instance variables:
```swift
// OLD - Remove these:
var needleAIEnabled: Bool
var needleAIIntelligence: Int
var needleAINextThrustToggle: TimeInterval
var needleAINextFireTime: TimeInterval
var needleAICertainFireCooldown: TimeInterval
var wedgeAIEnabled: Bool
// ... etc

// NEW - Use ShipState instead:
let needleState = state(for: needle)
needleState.aiEnabled = true
needleState.aiIntelligence = 2
```

### Step 2: Update all references

Find/replace pattern:
```swift
// Before:
if needleAIEnabled { ... }

// After:
if needleState.aiEnabled { ... }

// Or in generic context:
let st = state(for: ship)
if st.aiEnabled { ... }
```

### Step 3: Replace hardcoded blocks with generic function

The file `GameScene+ShipUpdate.swift` now provides `updateShip(_:currentTime:dt:)` which consolidates all the logic. To use it:

1. **Add the file to your project** (already created)
2. **Replace the hardcoded needle/dart blocks** in `update()` with:
   ```swift
   for ship in ships where ship.isVisible {
       updateShip(ship, currentTime: currentTime, dt: dt)
   }
   ```
3. **Sync legacy variables** (for backward compatibility during migration):
   ```swift
   // After the loop, sync legacy vars if other code still uses them:
   isThrustingNeedle = needleState.aiThrustOn || needleState.isThrustingByPlayer
   isThrustingDart = dartState.aiThrustOn || dartState.isThrustingByPlayer
   needleAIEnabled = needleState.aiEnabled
   wedgeAIEnabled = dartState.aiEnabled
   ```

### Step 4: Update Bullet Tracking

Replace:
```swift
// OLD:
var needleBulletsRemaining: Int
var dartBulletsRemaining: Int

// NEW in ShipState:
state(for: needle).bulletsRemaining
state(for: dart).bulletsRemaining
```

Update `fireMissile(from:muzzleOffset:)`:
```swift
private func fireMissile(from ship: Ship, muzzleOffset: CGPoint) {
    guard ship.isVisible else { return }
    
    let st = state(for: ship)
    if st.bulletsRemaining == 0 { return }
    
    // ... create missile ...
    
    if st.bulletsRemaining != Int.max {
        st.bulletsRemaining = max(0, st.bulletsRemaining - 1)
    }
    
    refreshBulletCounters()
    endGameIfNoBullets()
}
```

### Step 5: Update Respawn System

Replace:
```swift
// OLD:
var needleRespawnScheduled: Bool
var needleDestroyTime: TimeInterval
var needleRespawnTarget: CGPoint

// NEW in ShipState:
state(for: needle).respawnScheduled
state(for: needle).destroyTime
state(for: needle).respawnTarget
```

Generalized respawn check:
```swift
// In update():
for ship in ships {
    let st = state(for: ship)
    if st.respawnScheduled && ship.node.isHidden {
        if currentTime - st.destroyTime >= bulletLifeSeconds {
            st.respawnScheduled = false
            respawnShip(ship)
            st.visibleSince = currentTime
        }
    }
}
```

### Step 6: Test Each Phase

After each migration step, verify:
- ✅ Game plays identically to before
- ✅ AI behavior unchanged
- ✅ Bullet counts work
- ✅ Respawn works
- ✅ No crashes or missing references

## Benefits of Generalization

### Before (Hardcoded):
- ❌ Adding a 3rd ship requires copying 500+ lines
- ❌ AI changes need 2+ edits (needle + dart)
- ❌ Bug fixes need duplication
- ❌ Can't easily add/remove ships dynamically

### After (Generalized):
- ✅ Adding ships: append to `ships` array, done
- ✅ AI changes: edit one `updateShip()` method
- ✅ Bug fixes: single location
- ✅ Dynamic ship management ready for network play

## Example: Adding a 3rd Ship

Once generalized, adding a new ship is simple:

```swift
// In sceneDidLoad():
let cruiser = Ship(
    profile: .cruiser,  // Define new profile
    flame: ShipProfile.cruiser.createFlameNode(),
    spawn: CGPoint(x: size.width/2, y: size.height/2)
)
ships.append(cruiser)
addChild(cruiser.node)

// Initialize state
let cruiserState = state(for: cruiser)
cruiserState.aiEnabled = true
cruiserState.aiIntelligence = 1
cruiserState.bulletLimitSelection = 1
cruiserState.visibleSince = CACurrentMediaTime()

// That's it! Update loop handles the rest automatically.
```

## Migration Checklist

- [x] **Phase 1**: Infrastructure (DONE)
  - [x] `ShipState` class defined
  - [x] `shipStates` dictionary
  - [x] `state(for:)` helper
  - [x] Velocity tracking generalized
  - [x] AI prediction uses `state(for:).smoothedAcceleration`

- [ ] **Phase 2**: AI State Migration
  - [ ] Move `needleAIEnabled` → `needleState.aiEnabled`
  - [ ] Move `wedgeAIEnabled` → `dartState.aiEnabled`
  - [ ] Move `needleAIIntelligence` → `needleState.aiIntelligence`
  - [ ] Move all other AI state vars to `ShipState`
  - [ ] Update all references throughout codebase

- [ ] **Phase 3**: Update Loop Refactor
  - [ ] Add `GameScene+ShipUpdate.swift` to project
  - [ ] Test `updateShip()` with needle
  - [ ] Test `updateShip()` with dart
  - [ ] Replace hardcoded blocks with loop
  - [ ] Verify game plays identically

- [ ] **Phase 4**: Bullet & Respawn System
  - [ ] Move bullet counts to `ShipState`
  - [ ] Update `fireMissile()`
  - [ ] Move respawn tracking to `ShipState`
  - [ ] Generalize respawn checks

- [ ] **Phase 5**: Control & UI System
  - [ ] Move button references to `ShipState`
  - [ ] Store bullet counters in `ShipState`
  - [ ] Store direction arrows in `ShipState`
  - [ ] Generalize touch handling

- [ ] **Phase 6**: Cleanup & Documentation
  - [ ] Remove old instance variables
  - [ ] Update comments
  - [ ] Add documentation for ship creation
  - [ ] Performance test with 3-4 ships

## Notes

- Keep the migration **incremental** - test after each step
- Maintain **backward compatibility** during transition (sync legacy vars)
- The generalized system is **ready** - just needs old code migrated to use it
- Priority: Get update loop working first, then UI, then cleanup

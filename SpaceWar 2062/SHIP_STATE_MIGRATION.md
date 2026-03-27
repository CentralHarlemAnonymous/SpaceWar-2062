# Ship State Migration Guide

## Overview

You're absolutely right — all ship-specific state should live in `ShipState`, not as separate variables in `GameScene`. The good news is that `ShipState` already has most of these properties defined! We just need to migrate the code to **use** them consistently.

## Variables to Migrate

### ✅ Already in ShipState (just need to use them)

These properties exist in `ShipState` but the old GameScene variables are still being used:

| GameScene Variable | ShipState Property | Status |
|-------------------|-------------------|--------|
| `needleAIEnabled` | `.aiEnabled` | ✅ Partially migrated |
| `needleAIIntelligence` | `.aiIntelligence` | ✅ Partially migrated |
| `aiNextThrustToggle` | `.aiNextThrustToggle` | ✅ Partially migrated |
| `aiThrustOn` | `.aiThrustOn` | ✅ Partially migrated |
| `aiNextFireTime` | `.aiNextFireTime` | ✅ Partially migrated |
| `aiCertainFireCooldown` | `.aiCertainFireCooldown` | ✅ Partially migrated |
| `wedgeAIEnabled` | `.aiEnabled` | ✅ Partially migrated |
| `wedgeAIIntelligence` | `.aiIntelligence` | ✅ Partially migrated |
| `wedgeAINextThrustToggle` | `.aiNextThrustToggle` | ✅ Partially migrated |
| `wedgeAIThrustOn` | `.aiThrustOn` | ✅ Partially migrated |
| `wedgeAINextFireTime` | `.aiNextFireTime` | ✅ Partially migrated |
| `wedgeCertainFireCooldown` | `.aiCertainFireCooldown` | ✅ Partially migrated |
| `dartPreviousVelocity` | `.previousVelocity` | ✅ Used in update loop |
| `needlePreviousVelocity` | `.previousVelocity` | ✅ Used in update loop |
| `dartObservedAcceleration` | `.observedAcceleration` | ✅ Used in update loop |
| `needleObservedAcceleration` | `.observedAcceleration` | ✅ Used in update loop |
| `dartSmoothedAcceleration` | `.smoothedAcceleration` | ✅ Used in AI |
| `needleSmoothedAcceleration` | `.smoothedAcceleration` | ✅ Used in AI |
| `needleVisibleSince` | `.visibleSince` | ✅ Initialized |
| `dartVisibleSince` | `.visibleSince` | ✅ Initialized |
| `needleDestroyTime` | `.destroyTime` | ❌ Still using old vars |
| `dartDestroyTime` | `.destroyTime` | ❌ Still using old vars |
| `needleRespawnScheduled` | `.respawnScheduled` | ❌ Still using old vars |
| `dartRespawnScheduled` | `.respawnScheduled` | ❌ Still using old vars |
| `needleRespawnTarget` | `.respawnTarget` | ❌ Still using old vars |
| `dartRespawnTarget` | `.respawnTarget` | ❌ Still using old vars |
| `cameraPanToNeedleAfter` | `.cameraPanAfter` | ❌ Still using old vars |
| `cameraPanToDartAfter` | `.cameraPanAfter` | ❌ Still using old vars |
| `needleBulletLimitSelection` | `.bulletLimitSelection` | ✅ Initialized |
| `dartBulletLimitSelection` | `.bulletLimitSelection` | ✅ Initialized |
| `needleBulletsRemaining` | `.bulletsRemaining` | ❌ Still using old vars |
| `dartBulletsRemaining` | `.bulletsRemaining` | ❌ Still using old vars |
| `needleBulletCounterNode` | `.bulletCounterNode` | ❌ Still using old vars |
| `dartBulletCounterNode` | `.bulletCounterNode` | ❌ Still using old vars |

### 🆕 Newly Added to ShipState

| New Property | Purpose |
|--------------|---------|
| `.neuralAI: NeuralAIController?` | Per-ship neural AI instance (optional) |

## Migration Strategy

### Phase 1: High-Impact (Breaks Multi-Ship Support) ⚠️

These need to be migrated first for multi-ship support:

#### 1A. Bullet Counts
**Problem**: Hardcoded checks throughout the code
```swift
// OLD (scattered everywhere)
if needleBulletsRemaining == 0 { return }
if dartBulletsRemaining != Int.max { ... }

// NEW (generalized)
let st = state(for: ship)
if st.bulletsRemaining == 0 { return }
if st.bulletsRemaining != Int.max { ... }
```

**Files to Update**:
- `fireMissile(from:muzzleOffset:)` 
- `endGameIfNoBullets()`
- `resetBulletCountsFromSelections()`
- `refreshBulletCounters()`
- All AI code that checks bullet counts

#### 1B. Respawn Tracking
**Problem**: Hardcoded ship checks in update loop
```swift
// OLD
if needleRespawnScheduled && needle.node.isHidden {
    if currentTime - needleDestroyTime >= respawnBulletLife {
        needleRespawnScheduled = false
        respawnShip(needle)
    }
}

// NEW (loop over all ships)
for ship in ships {
    let st = state(for: ship)
    if st.respawnScheduled && ship.node.isHidden {
        if currentTime - st.destroyTime >= respawnBulletLife {
            st.respawnScheduled = false
            respawnShip(ship)
        }
    }
}
```

**Files to Update**:
- `update()` - respawn check section
- `explodeShip(ship:)`
- `respawnShip(_:)`
- Camera pan logic in `updateCamera()`

### Phase 2: Medium-Impact (Code Clarity) 📝

#### 2A. AI State Variables
**Status**: Most are **already used** through `state(for:)` in the new `updateShipAI()` method!

**Remaining Work**:
- Options UI still toggles old variables (`needleAIEnabled`, `wedgeAIEnabled`)
- Game-over mode still reads/writes old variables
- Need bidirectional sync during transition period

**Strategy**: Keep syncing for now:
```swift
// After AI update
needleAIEnabled = needleState.aiEnabled
wedgeAIEnabled = dartState.aiEnabled
```

#### 2B. Bullet Counter Nodes
```swift
// OLD
dartBulletCounterNode?.position = ...
needleBulletCounterNode?.position = ...

// NEW
dartState.bulletCounterNode?.position = ...
needleState.bulletCounterNode?.position = ...
```

### Phase 3: Low-Impact (Legacy Cleanup) 🧹

Once all code uses `ShipState`, remove the old variables:

```swift
// DELETE these from GameScene:
var needleAIEnabled: Bool = false
var needleAIIntelligence: Int = 0
// ... all the needle/dart specific vars
```

## Step-by-Step Migration

### Step 1: Bullet Counts (High Priority)

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
    
    // Sync legacy vars for backward compatibility
    if ship === needle { needleBulletsRemaining = st.bulletsRemaining }
    if ship === dart { dartBulletsRemaining = st.bulletsRemaining }
    
    refreshBulletCounters()
    endGameIfNoBullets()
}
```

Update `resetBulletCountsFromSelections()`:
```swift
func resetBulletCountsFromSelections() {
    for ship in ships {
        let st = state(for: ship)
        st.bulletsRemaining = bulletsForSelection(st.bulletLimitSelection) ?? Int.max
    }
    
    // Sync legacy vars
    needleBulletsRemaining = needleState.bulletsRemaining
    dartBulletsRemaining = dartState.bulletsRemaining
    
    refreshBulletCounters()
}
```

Update `refreshBulletCounters()`:
```swift
private func refreshBulletCounters() {
    let bulletScale: CGFloat = 0.85
    let bulletSpacing: CGFloat = 3
    
    func setCounter(_ node: SKNode?, count: Int) {
        guard let node else { return }
        // ... existing display logic ...
    }
    
    // Use ShipState
    setCounter(dartState.bulletCounterNode, count: dartState.bulletsRemaining)
    #if DEBUG
    setCounter(needleState.bulletCounterNode, count: needleState.bulletsRemaining)
    #endif
}
```

### Step 2: Respawn Tracking

Update `explodeShip(ship:)`:
```swift
private func explodeShip(ship: Ship) {
    guard ship.isVisible else { return }
    enableRandomRespawn = true
    let originalVelocity = ship.velocity
    
    let now = CACurrentMediaTime()
    let st = state(for: ship)
    st.destroyTime = now  // ✅ Use ShipState
    
    let respawnPos = (enableRandomRespawn ? safeRandomPosition(avoiding: ship) : nil)
                     ?? ship.spawnPosition
    let panDelay: TimeInterval = virtualScreenMode != .off ? 2.0 : 1.0
    
    st.respawnTarget = respawnPos  // ✅ Use ShipState
    st.cameraPanAfter = now + panDelay  // ✅ Use ShipState
    
    // Sync legacy vars for backward compatibility
    if ship === needle {
        needleDestroyTime = now
        needleRespawnTarget = respawnPos
        cameraPanToNeedleAfter = now + panDelay
    } else if ship === dart {
        dartDestroyTime = now
        dartRespawnTarget = respawnPos
        cameraPanToDartAfter = now + panDelay
    }
    
    ship.hide()
    // ... rest of explosion logic ...
}
```

Update respawn check in `update()`:
```swift
// NEW: Generalized respawn check
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

// OLD: Can be removed after testing
// if needleRespawnScheduled && needle.node.isHidden { ... }
// if dartRespawnScheduled && dart.node.isHidden { ... }
```

### Step 3: Bullet Counter Node References

Update `sceneDidLoad()`:
```swift
let dartCounter = SKNode()
dartCounter.position = CGPoint(x: fireThrustButton.position.x, y: fireThrustButton.position.y + buttonRadius + 20)
dartCounter.zPosition = 12
addChild(dartCounter)
dartState.bulletCounterNode = dartCounter  // ✅ Store in state
self.dartBulletCounterNode = dartCounter   // Keep for backward compat

#if DEBUG
let needleCounter = SKNode()
needleCounter.position = CGPoint(x: leftFireButton.position.x, y: leftFireButton.position.y + leftButtonRadius + 20)
needleCounter.zPosition = 12
addChild(needleCounter)
needleState.bulletCounterNode = needleCounter  // ✅ Store in state
self.needleBulletCounterNode = needleCounter   // Keep for backward compat
#endif
```

### Step 4: Camera Pan Logic

Update `updateCamera()`:
```swift
let target: CGPoint
if !followed.node.isHidden {
    target = followed.node.position
} else {
    let st = state(for: followed)
    target = (currentTime >= st.cameraPanAfter && st.cameraPanAfter > 0) 
        ? st.respawnTarget 
        : cameraCenter
}
```

## Testing Checklist

After each phase:

- [ ] Both ships can fire and run out of bullets
- [ ] Bullet counts display correctly
- [ ] Ships respawn after being destroyed
- [ ] Respawn delay works (waits for bullets to expire)
- [ ] Camera pans to respawn location in virtual mode
- [ ] AI behavior unchanged
- [ ] Game over mode works
- [ ] Options UI still toggles AI correctly

## Benefits After Migration

### Before (Hardcoded)
```swift
var needleBulletsRemaining: Int = 0
var dartBulletsRemaining: Int = 0
var needleRespawnScheduled: Bool = false
var dartRespawnScheduled: Bool = false
// ... 50+ duplicate variables
```

### After (Generalized)
```swift
var shipStates: [ObjectIdentifier: ShipState] = [:]

let st = state(for: ship)
st.bulletsRemaining
st.respawnScheduled
// ... all state in one place
```

**Result**: 
- ✅ Ready for 3+ ships
- ✅ Single source of truth
- ✅ Less code duplication
- ✅ Easier to maintain
- ✅ Easier to test

## Current Progress

| Component | Status | Notes |
|-----------|--------|-------|
| ShipState definition | ✅ Complete | Has all needed properties |
| Velocity tracking | ✅ Complete | Using `state(for:)` in update loop |
| AI prediction | ✅ Complete | Uses `state(for: target).smoothedAcceleration` |
| AI update method | ✅ Complete | `updateShipAI()` uses ShipState |
| Bullet counts | ❌ TODO | High priority for multi-ship |
| Respawn tracking | ❌ TODO | High priority for multi-ship |
| UI node references | ❌ TODO | Medium priority |
| Legacy variable removal | ❌ TODO | Low priority (cleanup) |

## Next Steps

1. **Start with bullet counts** - highest impact for multi-ship support
2. **Then respawn tracking** - second highest impact
3. **Keep legacy variables synced** during transition
4. **Remove legacy variables** once all code migrated
5. **Test thoroughly** after each phase

See `REFACTORING_GUIDE.md` for the broader multi-ship generalization plan.

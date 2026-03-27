# Ship System Generalization Progress

## Completed ✅

### 1. Moved Ship Design to ShipProfile
- **Change**: Moved `createFlameNode()` from `GameScene` to `ShipProfile.createFlameNode()`
- **Impact**: All ship visual components now defined in the profile system
- **Files Modified**: `ShipProfiles.swift`, `GameScene.swift`

### 2. Added Ship State Dictionary
- **Change**: Added `shipStates: [ObjectIdentifier: ShipState]` dictionary
- **Impact**: Can now track per-ship runtime state for unlimited number of ships
- **Helper Methods**: 
  - `state(for: Ship) -> ShipState` - gets or creates state
  - `needleState` / `dartState` - legacy accessors for backward compatibility

### 3. Generalized Collision Detection
- **Change**: Already present in code - uses `ships` array and `ObjectIdentifier` keys
- **Impact**: Works with variable number of ships
- **Location**: `GameScene.swift` collision detection in `update()`

### 4. Generalized Score Tracking
- **Change**: `shipScores` and `shipKillTimes` dictionaries use `ObjectIdentifier` keys
- **Impact**: Supports unlimited ships
- **Methods**: `incrementScore(for:)`, `recordKillTime(for:at:)`, `getKillTime(for:)`

### 5. Generalized Velocity & Acceleration Tracking
- **Change**: Moved from individual vars (`dartPreviousVelocity`, etc.) to `ShipState` properties
- **Impact**: AI prediction now works through `state(for:).smoothedAcceleration`
- **Files Modified**: `GameScene.swift`, `GameScene+AI.swift`
- **Legacy Support**: Old variables synced for backward compatibility

## Remaining Work 🚧

### High Priority (Breaks Multi-Ship Support)

#### A. Bullet Count System
**Current**: Hardcoded `needleBulletsRemaining`, `dartBulletsRemaining`  
**Needed**: Use `ShipState.bulletsRemaining` throughout  
**Locations to Update**:
- `fireMissile(from:muzzleOffset:)` - check state(for: ship).bulletsRemaining
- `endGameIfNoBullets()` - iterate over all ships
- `resetBulletCountsFromSelections()` - iterate over all ships
- Touch handlers that modify bullet counts

#### B. AI State Management
**Current**: Hardcoded AI variables per ship  
```swift
var needleAIEnabled: Bool
var needleAIIntelligence: Int
var needleAINextThrustToggle: TimeInterval
// ... and wedge equivalents
```
**Needed**: Use `ShipState.aiEnabled`, `.aiIntelligence`, `.aiNextThrustToggle`, etc.  
**Impact**: Would allow each ship to have independent AI configuration

#### C. Update Loop - Ship AI & Movement
**Current**: Hardcoded blocks for needle and dart AI/rotation/thrust  
**Needed**: Single loop over `ships` array:
```swift
for ship in ships where ship.isVisible {
    let st = state(for: ship)
    if st.aiEnabled {
        // Generalized AI path
        let opponent = ships.first { $0 !== ship && $0.isVisible }
        // ... compute aim, thrust, fire
    } else if let aimPt = aimPoint {
        rotateShip(ship, toward: aimPt, dt: dt)
    }
    
    if st.isThrustingByPlayer || st.aiThrustOn {
        ship.applyThrust(dt: CGFloat(dt))
        ship.flame.alpha = 1
    } else {
        ship.flame.alpha = 0
    }
}
```

#### D. Respawn System
**Current**: Separate `needleRespawnScheduled`, `dartRespawnScheduled`, etc.  
**Needed**: Use `ShipState.respawnScheduled`, `.respawnTarget`, `.destroyTime`  
**Locations**:
- Respawn check logic in `update()`
- `explodeShip()` - already sets some state
- Camera pan logic

#### E. Control Buttons & UI
**Current**: Hardcoded button references per ship  
**Needed**: Store in `ShipState.fireButton`, `.thrustButton`, `.bulletCounterNode`, etc.  
**Impact**: Could support 2+ human players with dynamic button allocation

### Medium Priority (Legacy Code Cleanup)

#### F. Remove Legacy Instance Variables
Once all code uses `ShipState`, can remove:
```swift
var needleAIEnabled, wedgeAIEnabled
var needleAIIntelligence, wedgeAIIntelligence
var needleBulletsRemaining, dartBulletsRemaining
var dartPreviousVelocity, needlePreviousVelocity
// etc.
```

#### G. Refactor Touch Handling
**Current**: Separate code paths for left/right controls  
**Needed**: Generic ship lookup from touch location → find which ship's controls were touched

#### H. Generalize UI Indicators
**Current**: `needleTargetIndicator`, `dartTargetIndicator`, `needleDirectionArrow`, etc.  
**Needed**: Store in `ShipState` and create dynamically based on active ships

### Low Priority (Polish & Future-Proofing)

#### I. Multi-Ship Game Logic
- Generalize victory condition (last ship standing? team-based?)
- Support more than 2 ships
- Dynamic spawn positions for 3+ ships

#### J. Ship Selection System
- Already has placeholder UI (`shipSelectionTabButton`)
- Would need to populate `ships` array from selection

#### K. Network Support
- Already has placeholder UI (`networkTabButton`)
- Ship state is now ready for serialization/sync

## Testing Checklist

When generalizing code, verify:
- [ ] 2-ship gameplay works identically to before
- [ ] AI behavior unchanged (uses `state(for:)` correctly)
- [ ] Bullet counts tracked per-ship
- [ ] Collision detection handles all ships
- [ ] Respawn works for each ship independently
- [ ] Camera follows correct ship in virtual mode
- [ ] Direction arrows show for off-screen ships
- [ ] Score tracking works
- [ ] Game over logic correct
- [ ] Touch controls don't interfere between ships

## Migration Strategy

1. **Phase 1** (Current): Core infrastructure in place
   - ✅ Ship state dictionary
   - ✅ Collision detection generalized
   - ✅ Velocity tracking generalized

2. **Phase 2**: AI & Update Loop
   - Move AI state to `ShipState`
   - Create `updateShip(_:opponent:currentTime:dt:)` method
   - Replace hardcoded blocks with loop over `ships`

3. **Phase 3**: Controls & UI
   - Move button references to `ShipState`
   - Generalize touch handling
   - Dynamic UI creation per ship

4. **Phase 4**: Cleanup
   - Remove legacy variables
   - Add 3+ ship support
   - Document new ship creation API

## Notes

- Keep backward compatibility during migration (sync legacy vars)
- Use `needle` and `dart` as convenience accessors where needed
- The `ships` array is already the source of truth for iteration
- `ObjectIdentifier(ship.node)` is the consistent key for all dictionaries

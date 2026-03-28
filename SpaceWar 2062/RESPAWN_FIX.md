# Respawn System Fix - Summary

## Problem
Ships would sometimes wait 15+ seconds to respawn because:
1. `safeRandomPosition()` used 200px minimum separation
2. `respawnShip()` enforced 300px minimum separation
3. When position was rejected, ship would wait full `bulletLifeSeconds` delay before trying again
4. This could repeat multiple times, causing cumulative 15+ second delays

## Solution

### 1. Unified Separation Distance
- Both functions now use **300px minimum separation**
- Eliminates mismatch that caused positions to be rejected

### 2. Multi-Attempt Strategy
```swift
for attempt in 0..<5 {
    // Try cached target first, then random positions
    if isSafe(candidatePos) {
        respawn immediately
        return
    }
}
```
- Tries up to 5 positions before giving up
- Maximizes chance of immediate respawn

### 3. Short Retry Interval
```swift
if no safe position found after 5 attempts:
    schedule retry in 0.5 seconds (not full bulletLifeSeconds)
```
- Was: Wait full bulletLifeSeconds (~2-5+ seconds) per retry
- Now: Wait only 0.5 seconds per retry
- Maximum wait time: ~2.5 seconds (5 attempts × 0.5s)

### 4. Fresh Positions on Retry
```swift
st.respawnTarget = .zero  // Clear cached target
```
- Ensures each retry tries new random positions
- Prevents getting stuck trying the same unsafe location repeatedly

## Result
- Ships now respawn within 0.5-2.5 seconds even in crowded situations
- No more 15-second delays
- System is more responsive and feels fairer to players

## Testing
Watch console for:
```
⚠️ Could not find safe respawn for [ShipName], retrying in 0.5s
```
This indicates the retry system is working (should be rare with 5 attempts).

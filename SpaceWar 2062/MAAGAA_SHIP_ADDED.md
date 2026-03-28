# Maa'gaa Ship - New Addition

## Overview

Added a third ship type: **Maa'gaa** - a baseball cap-shaped vessel viewed from above.

## Visual Design

```
         ▲ FRONT
         │
    ╭────●────╮      ● = Muzzle (fires here)
    │  BILL   │
    │         │
    ╰────┬────╯
         │
    ┌────┴────┐
   ╱ ╲  │  ╱ ╲      ← Crown with 6 panel seams
  │  ╲  │  ╱  │
  │───●─────  │      ● = Center button
  │  ╱  │  ╲  │
   ╲          ╱
    └─────────┘
         │
         ▼ BACK
      🔥🔥🔥 Flame
```

## Ship Characteristics

### Visual
- **Shape:** Baseball cap from top-down view
- **Color:** Red indicator (0.9, 0.2, 0.2)
- **Details:** 6 panel seam lines radiating from center
- **Muzzle:** Center front of bill (y: 16)
- **Flame:** Back of crown (y: -20)

### Stats (Tank/Defensive Build)
- **Inventory:** Large (2.0× bullets)
- **Fire Rate:** Fast (0.5× interval - shoots often!)
- **Flight Speed:** Slow (0.9× max speed)
- **Hit Points:** Medium (1.5×)
- **Bullet Power:** Low (0.5 damage)
- **Shield:** Rear (75% HP in back, 25% front)
- **Turn Rate:** Slow (0.7× turn speed)

### Gameplay Strategy
**Notes:** "Slow but strong, best attacked head-on."

**Strengths:**
- Large ammunition capacity
- Fast rate of fire (spray and pray)
- Rear shield protects from behind
- Decent durability (medium HP + shield)

**Weaknesses:**
- Slow movement (hard to dodge)
- Slow turning (can't react quickly)
- Weak bullets (low damage per hit)
- Vulnerable from the front (only 25% HP)

**Best Used:**
- Defensive positions
- Suppressive fire with high ammo count
- Protecting flanks (shield blocks rear attacks)
- Choke points where mobility isn't needed

**Counters:**
- Fast ships can circle-strafe it
- Head-on attacks exploit weak frontal armor
- High-damage ships can burn through HP quickly

## Technical Implementation

### Files Modified

**ShipProfiles.swift:**
- Added `maagaa` static property with complete ShipProfile
- Updated `allShips` array to include all three ships: `[needle, dart, maagaa]`

### Vector Path Design

**Main Shape:**
- Crown: Semicircular back (14-unit radius)
- Bill: Curved brim extending forward to y: 16
- Smooth quad curves connect crown to bill edges

**Details:**
- 5 panel seam lines radiating from center
- Center button at crown center
- Indicator silhouette at 70% scale for edge arrows

### Integration

The ship is now automatically available in:
- ✅ Ship selection wheels (both left and right)
- ✅ All ship stat displays
- ✅ Game spawning system
- ✅ AI can use it

No additional code changes needed - the generalized ship system handles everything!

## Testing Checklist

- [ ] Ship renders correctly in game
- [ ] Panel seam lines visible
- [ ] Fires from bill tip
- [ ] Flame appears at crown back
- [ ] Turns slowly (0.7× rate)
- [ ] Moves slowly (0.9× speed)
- [ ] Large ammo capacity (2× normal)
- [ ] Fast fire rate (0.5× interval)
- [ ] Low bullet damage (0.5×)
- [ ] Rear shield active (75%/25% split)
- [ ] Red indicator color on edges
- [ ] Appears in ship selection wheels
- [ ] Can be selected for Ship 1 or Ship 2
- [ ] Stats display correctly

## Design Notes

The Maa'gaa creates interesting strategic diversity:

**Ship Comparison:**
```
Needle:  Balanced - all medium stats, no shield
Wedge:   Balanced - all medium stats, no shield  
Maa'gaa: Tank - high ammo, fast fire, slow, weak bullets, rear shield
```

The third ship makes the selection wheel meaningful - players can now choose different playstyles rather than two identical ships.

**Future Ships Could Add:**
- Fast interceptor (high speed, low HP)
- Heavy gunship (slow, high damage, low fire rate)
- Stealth ship (small, fast turning, medium everything else)

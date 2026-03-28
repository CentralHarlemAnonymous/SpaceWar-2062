# Ship Stat Reference

Quick reference for all ship stat multipliers and their gameplay effects.

## Inventory Size
Controls bullet capacity from slider

| Setting | Multiplier | 10 Bullets Slider | 50 Bullets Slider |
|---------|------------|-------------------|-------------------|
| Small   | 0.5×       | 5 bullets         | 25 bullets        |
| Medium  | 1.0×       | 10 bullets        | 50 bullets        |
| Large   | 2.0×       | 20 bullets        | 100 bullets       |

## Fire Rate (Time Between Shots)
Base interval: 0.15 seconds

| Setting | Multiplier | Interval | Shots/Second |
|---------|------------|----------|--------------|
| Slow    | 2.0×       | 0.30s    | 3.3          |
| Medium  | 1.0×       | 0.15s    | 6.7          |
| Fast    | 0.5×       | 0.075s   | 13.3         |

## Flight Speed
Base max speed: 400 points/second

| Setting | Multiplier | Max Speed |
|---------|------------|-----------|
| Slow    | 0.9×       | 360 pts/s |
| Medium  | 1.0×       | 400 pts/s |
| Fast    | 1.1×       | 440 pts/s |

## Hit Points
Base HP: 1.0

| Setting | Multiplier | Total HP | Hits to Kill (vs Medium Bullets) |
|---------|------------|----------|-----------------------------------|
| Low     | 1.0×       | 1.0      | 1 hit                             |
| Medium  | 1.5×       | 1.5      | 2 hits                            |
| High    | 2.0×       | 2.0      | 2 hits                            |

## Bullet Power
Damage per hit

| Setting | Damage | Hits to Kill Low HP | Hits to Kill Medium HP | Hits to Kill High HP |
|---------|--------|---------------------|------------------------|----------------------|
| Low     | 0.5    | 2                   | 3                      | 4                    |
| Medium  | 1.0    | 1                   | 2                      | 2                    |
| High    | 1.5    | 1                   | 1                      | 2                    |

## Shield Type

| Type | Effect                                                      |
|------|-------------------------------------------------------------|
| None | All damage treated equally (single HP pool)                 |
| Back | 75% HP in rear, 25% HP in front (rear is harder to destroy) |

**Shield Zones:**
- **Front**: ±135° arc from nose (all hits except rear quadrant)
- **Rear**: ±45° arc from tail (back 25% of ship)

## Turn Rate
Base turn speed: 2π radians/second (1 full rotation/second)

| Setting | Multiplier | Turn Speed   | Full Rotation Time |
|---------|------------|--------------|--------------------|
| Slow    | 0.7×       | 1.4π rad/s   | 1.43 seconds       |
| Medium  | 1.0×       | 2.0π rad/s   | 1.00 second        |
| Fast    | 1.3×       | 2.6π rad/s   | 0.77 seconds       |

## Default Ship Configurations

### Needle
- Inventory: Medium (1.0×)
- Fire Rate: Medium (0.15s)
- Flight Speed: Medium (400 pts/s)
- Hit Points: Low (1.0)
- Bullet Power: Medium (1.0 damage)
- Shield: None
- Turn Rate: Medium (2π rad/s)
- **Notes**: "Balanced fighter with medium specs across the board."

### Wedge (Dart)
- Inventory: Medium (1.0×)
- Fire Rate: **Slow** (0.30s)
- Flight Speed: Medium (400 pts/s)
- Hit Points: **Medium** (1.5)
- Bullet Power: Medium (1.0 damage)
- Shield: **Back** (75% rear, 25% front)
- Turn Rate: Medium (2π rad/s)
- **Notes**: "Heavily armored with rear shield. Slower fire rate but durable."

## Combat Examples

### Example 1: Needle (Medium bullets) vs Wedge (Medium HP, Back shield)
- **Front hit**: Wedge takes 1.0 damage to front HP pool (0.375 total HP)
  - Wedge survives (needs 1 more front hit or 2 rear hits)
- **Rear hit**: Wedge takes 1.0 damage to rear HP pool (1.125 total HP)
  - Wedge survives (needs 2 more rear hits or 1 front hit)

### Example 2: Wedge (Medium bullets) vs Needle (Low HP, No shield)
- **Any hit**: Needle takes 1.0 damage (1.0 total HP)
  - Needle destroyed (instant kill)

### Example 3: Custom ship (Low bullets) vs Custom ship (High HP)
- Attacker bullets: 0.5 damage each
- Defender HP: 2.0
- **Hits to kill**: 4 hits (2.0 ÷ 0.5 = 4)

## Special Cases

1. **Bullet Speed**: Always enforced to be ≥ ship max speed × 1.2
   - Fast ship (440 pts/s) fires bullets at ≥ 528 pts/s
   
2. **Ship-vs-Ship Collision**: Instant kill (ignores HP)

3. **Sun Collision**: Instant kill (ignores HP)

4. **Respawn**: Full HP restoration

5. **Grace Period**: 1 second immunity from own bullets after firing (prevents self-damage)

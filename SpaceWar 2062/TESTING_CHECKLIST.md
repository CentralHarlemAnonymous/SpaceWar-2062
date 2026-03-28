# Ship Customization System - Testing Checklist

## Build & Launch
- [ ] Project compiles without errors
- [ ] Project compiles without warnings
- [ ] Game launches successfully
- [ ] No crashes on startup

## Ship Selection UI
- [ ] Options panel → "Ships" tab shows ship selection wheels
- [ ] Left wheel starts with Needle selected
- [ ] Right wheel starts with Wedge selected
- [ ] Both wheels show 3 ships (previous/current/next)
- [ ] Current ship is full size, others are smaller/faded
- [ ] Ship stats display below each wheel
- [ ] Stats show: Name, Inventory, Fire Rate, Speed, HP, Bullet Power, Turn Rate
- [ ] Notes text displays below stats (word-wrapped)

## Wheel Interaction
- [ ] Clicking above current ship scrolls to previous
- [ ] Clicking below current ship scrolls to next
- [ ] Wheel wraps around (last → first, first → last)
- [ ] Cannot select same ship on both wheels
- [ ] When attempting duplicate selection, skips to next ship
- [ ] Wheel animates/updates smoothly

## Ship Profile Changes
- [ ] Changing left wheel updates needle ship
- [ ] Changing right wheel updates wedge ship
- [ ] Ship visual changes to new profile
- [ ] Ship indicator color changes
- [ ] Button colors update to match new ship
- [ ] Cluster title updates (e.g., "NEEDLE" → "WEDGE")
- [ ] AI settings preserved after ship change
- [ ] Bullet count selection preserved after ship change
- [ ] Score preserved after ship change

## Gameplay - Hit Points
- [ ] Ships with Low HP die in 1 hit (from Medium bullets)
- [ ] Ships with Medium HP survive 1 hit, die on 2nd
- [ ] Ships with High HP survive 2 hits, die on 3rd
- [ ] Hit points restore on respawn
- [ ] Ship explodes when HP reaches 0
- [ ] Hit points tracked separately for front/rear (shield ships)

## Gameplay - Shield System
- [ ] Ships with "None" shield: all hits treated equally
- [ ] Ships with "Back" shield: rear takes more hits to kill
- [ ] Rear hits detected correctly (back 25% of ship)
- [ ] Front hits detected correctly (front 75% of ship)
- [ ] Shield info displayed in notes, not as separate stat

## Gameplay - Bullet Power
- [ ] Low power bullets (0.5 damage) require 2 hits to kill Low HP ship
- [ ] Medium power bullets (1.0 damage) kill Low HP ship in 1 hit
- [ ] High power bullets (1.5 damage) kill Low HP ship in 1 hit
- [ ] Bullet damage determined by firing ship's profile

## Gameplay - Fire Rate
- [ ] Slow fire rate: noticeable delay between shots
- [ ] Medium fire rate: baseline delay
- [ ] Fast fire rate: rapid fire (half the delay)
- [ ] Fire rate doesn't allow shooting faster than allowed
- [ ] AI respects fire rate when enabled

## Gameplay - Flight Speed
- [ ] Slow ships move noticeably slower
- [ ] Fast ships move noticeably faster
- [ ] Speed affects maneuverability in combat
- [ ] Bullet speed always exceeds ship speed

## Gameplay - Turn Rate
- [ ] Slow turn ships rotate more slowly
- [ ] Fast turn ships rotate more quickly
- [ ] Turn rate affects aiming difficulty
- [ ] AI respects turn rate

## Gameplay - Inventory Size
- [ ] Small inventory: bullet slider shows 5 / 25 / ∞
- [ ] Medium inventory: bullet slider shows 10 / 50 / ∞
- [ ] Large inventory: bullet slider shows 20 / 100 / ∞
- [ ] Bullet counter displays correct count
- [ ] Game ends correctly when all bullets exhausted

## Edge Cases
- [ ] Ship-vs-ship collision still instant-kills both
- [ ] Sun collision still instant-kills ship
- [ ] Wreck pieces behave correctly
- [ ] Respawn timing works with new HP system
- [ ] Countdown timer still works
- [ ] Game over screen still works
- [ ] New Match resets HP correctly
- [ ] Virtual screen mode still works
- [ ] Camera follows correct ship
- [ ] Direction arrows show correct ship indicators

## AI Behavior
- [ ] AI ships fire at correct rate
- [ ] AI ships turn at correct speed
- [ ] AI ships move at correct speed
- [ ] AI intelligence levels still work
- [ ] Neural AI (level 3) still functions

## Visual Polish
- [ ] No visual glitches in ship selection UI
- [ ] Text is readable and properly aligned
- [ ] Wheels don't overlap or clip
- [ ] Stats display fits within panel
- [ ] Notes text doesn't overflow
- [ ] Ship previews render correctly
- [ ] Head dots appear on appropriate ships

## Regression Testing
- [ ] Existing controls still work
- [ ] Existing options still work
- [ ] Bullet sliders still work
- [ ] AI toggles still work
- [ ] Gravity slider still works
- [ ] Virtual screen toggle still works
- [ ] Edge behavior toggle still works
- [ ] Aim persist toggle still works

## Performance
- [ ] No frame rate drops with new system
- [ ] Ship switching is instant
- [ ] Wheel scrolling is smooth
- [ ] No memory leaks when switching ships
- [ ] Game runs smoothly with new collision system

## Data Validation
- [ ] All stat multipliers are correct (see SHIP_STAT_REFERENCE.md)
- [ ] Default ships have correct stats
- [ ] Computed properties return expected values
- [ ] Hit point math is correct
- [ ] Shield split is 75%/25%

## Documentation
- [ ] SHIP_CUSTOMIZATION_SYSTEM.md is accurate
- [ ] SHIP_STAT_REFERENCE.md is accurate
- [ ] Code comments are clear
- [ ] Stat descriptions match implementation

## Future Additions
When adding new ships, verify:
- [ ] Ship appears in both wheels
- [ ] Stats display correctly
- [ ] All multipliers apply correctly
- [ ] Ship can't be selected on both sides simultaneously
- [ ] Ship visual renders correctly at all scales

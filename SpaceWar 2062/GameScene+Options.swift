//
//  GameScene+Options.swift
//  SpaceWar 2062
//
//  Created by Michael Stern on 3/15/26.
//


// GameScene+Options.swift

import SpriteKit

extension GameScene {

    // MARK: - Options Overlay

    func setupOptionsOverlay() {
        print("  📋 setupOptionsOverlay START")
        let overlay = SKNode()
        overlay.zPosition = 200
        overlay.name = "optionsOverlay"
        overlay.position = CGPoint(x: size.width/2, y: size.height/2)
        print("  ✅ Overlay node created")

        let w: CGFloat = min(380, size.width - 40)
        let h: CGFloat = 492   // +32 to accommodate second tab row

        let bgPath = CGPath(roundedRect: CGRect(x: -w/2, y: -h/2, width: w, height: h),
                            cornerWidth: 14, cornerHeight: 14, transform: nil)
        let bg = SKShapeNode(path: bgPath)
        bg.fillColor = SKColor(white: 0.08, alpha: 1.0)
        bg.strokeColor = .white; bg.lineWidth = 2; bg.zPosition = 201; bg.name = "options_bg"
        overlay.addChild(bg)

        // Dimmer sits directly behind the panel — same rect, lower zPosition
        if let dimmer = optionsDimmer {
            dimmer.path = bgPath
            dimmer.position = .zero
            dimmer.zPosition = 200
            if dimmer.parent == nil { overlay.addChild(dimmer) }
        }

        func makeLabel(_ text: String, y: CGFloat, name: String) -> SKLabelNode {
            let label = SKLabelNode(text: text)
            label.name = name; label.fontName = "AvenirNext-Bold"; label.fontSize = 16
            label.fontColor = .white; label.position = CGPoint(x: 0, y: y); label.zPosition = 202
            return label
        }

        let tabWidth: CGFloat = (w - 40) / 4
        let tabHeight: CGFloat = 28
        let topPadding: CGFloat = 12
        let tabY = h/2 - topPadding - tabHeight/2

        func makeTab(_ title: String, x: CGFloat, name: String) -> SKShapeNode {
            let tab = SKShapeNode(rectOf: CGSize(width: tabWidth, height: tabHeight), cornerRadius: 6)
            tab.name = name; tab.position = CGPoint(x: x, y: tabY)
            tab.fillColor = SKColor(white: 0.2, alpha: 0.6); tab.strokeColor = .white
            tab.lineWidth = 2; tab.zPosition = 210
            let label = SKLabelNode(text: title)
            label.fontName = "AvenirNext-Bold"; label.fontSize = 14
            label.verticalAlignmentMode = .center; label.horizontalAlignmentMode = .center
            label.position = .zero; label.zPosition = 211; tab.addChild(label)
            overlay.addChild(tab); return tab
        }

        let leftX = -w/2 + 20 + tabWidth/2
        gameTabButton    = makeTab("Gameplay",    x: leftX + 0 * tabWidth, name: "tab_game")
        optionsTabButton = makeTab("Physics",     x: leftX + 1 * tabWidth, name: "tab_environment")
        shipsTabButton   = makeTab("Controls",    x: leftX + 2 * tabWidth, name: "tab_ships")
        aboutTabButton   = makeTab("About",       x: leftX + 3 * tabWidth, name: "tab_about")

        // Row 2 — two expansion tabs centred under the four-tab row
        let tabRow2Y = tabY - tabHeight - 4
        shipSelectionTabButton = makeTab("Ships",    x: -tabWidth / 2, name: "tab_ship_selection")
        networkTabButton       = makeTab("Network",  x:  tabWidth / 2, name: "tab_network")
        // Override y to the second row (makeTab uses tabY by default)
        shipSelectionTabButton?.position.y = tabRow2Y
        networkTabButton?.position.y       = tabRow2Y

        // Ship Selection tab container
        let shipSelContainer = SKNode(); shipSelContainer.zPosition = 202; shipSelContainer.isHidden = true
        overlay.addChild(shipSelContainer); shipSelectionContainer = shipSelContainer
        
        // DON'T build ship selection UI during init - defer until user clicks tab
        print("  ⏭️ Skipping ship selection UI build (deferred until tab opened)")

        // "Coming Soon" placeholder for Network tab
        let netContainer = SKNode(); netContainer.zPosition = 202; netContainer.isHidden = true
        let netLabel = SKLabelNode(text: "Coming Soon")
        netLabel.fontName = "AvenirNext-Bold"; netLabel.fontSize = 22
        netLabel.fontColor = SKColor(white: 1.0, alpha: 0.4)
        netLabel.verticalAlignmentMode = .center; netLabel.horizontalAlignmentMode = .center
        netLabel.position = .zero
        netContainer.addChild(netLabel)
        overlay.addChild(netContainer); networkContainer = netContainer

        // MARK: Environment tab content
        let screenEdgeLabel = makeLabel("Screen Edge:", y: h/2 - 122, name: "env_label_screen_edge")
        overlay.addChild(screenEdgeLabel)

        let bounceBtn = SKShapeNode(rectOf: CGSize(width: 90, height: 28), cornerRadius: 6)
        bounceBtn.name = "opt_edge_bounce"; bounceBtn.position = CGPoint(x: -60, y: h/2 - 147)
        bounceBtn.strokeColor = .white; bounceBtn.lineWidth = 2; bounceBtn.zPosition = 202; overlay.addChild(bounceBtn)
        bounceBtn.addChild(makeTabInnerLabel("Bounce")); edgeBounceButton = bounceBtn

        let wrapBtn = SKShapeNode(rectOf: CGSize(width: 90, height: 28), cornerRadius: 6)
        wrapBtn.name = "opt_edge_wrap"; wrapBtn.position = CGPoint(x: 60, y: h/2 - 147)
        wrapBtn.strokeColor = .white; wrapBtn.lineWidth = 2; wrapBtn.zPosition = 202; overlay.addChild(wrapBtn)
        wrapBtn.addChild(makeTabInnerLabel("Wrap")); edgeWrapButton = wrapBtn

        let gravityHeading = makeLabel("Gravity", y: h/2 - 222, name: "env_label_gravity")
        overlay.addChild(gravityHeading)

        let gravTrackY: CGFloat = h/2 - 312
        let gravTrack = SKShapeNode(rectOf: CGSize(width: sliderTrackWidth, height: 4), cornerRadius: 2)
        gravTrack.strokeColor = .white; gravTrack.fillColor = .white
        gravTrack.position = CGPoint(x: 0, y: gravTrackY)
        gravTrack.name = "opt_grav_track"; gravTrack.zPosition = 202; overlay.addChild(gravTrack)
        gravitySliderTrack = gravTrack

        let gravTickLabels = ["0×", "2.5×", "5×"]
        for (i, tickLabel) in gravTickLabels.enumerated() {
            let frac = CGFloat(i) / CGFloat(gravTickLabels.count - 1)
            let tx = -sliderTrackHalfWidth + frac * sliderTrackWidth
            let tick = SKShapeNode(rectOf: CGSize(width: 2, height: 8))
            tick.fillColor = .white; tick.strokeColor = .clear
            tick.position = CGPoint(x: tx, y: gravTrackY)
            tick.name = "opt_grav_tick_\(i)"; tick.zPosition = 203; overlay.addChild(tick)
            let tl = SKLabelNode(text: tickLabel)
            tl.fontName = "AvenirNext-Medium"; tl.fontSize = 11; tl.fontColor = .white
            tl.verticalAlignmentMode = .top; tl.horizontalAlignmentMode = .center
            tl.position = CGPoint(x: tx, y: gravTrackY - 7); tl.zPosition = 203
            tl.name = "opt_grav_ticklabel_\(i)"; overlay.addChild(tl)
        }

        let gravKnob = SKShapeNode(circleOfRadius: 8)
        gravKnob.fillColor = .white; gravKnob.strokeColor = .white; gravKnob.lineWidth = 2
        let gravKnobX = -sliderTrackHalfWidth + CGFloat(gravitySliderSelection) * (sliderTrackWidth / CGFloat(gravitySliderSteps))
        gravKnob.position = CGPoint(x: gravKnobX, y: gravTrackY)
        gravKnob.name = "opt_grav_knob"; gravKnob.zPosition = 204; overlay.addChild(gravKnob)
        gravitySliderKnob = gravKnob

        let gravValLbl = SKLabelNode(text: gravityLabelText())
        gravValLbl.fontName = "AvenirNext-Medium"; gravValLbl.fontSize = 12; gravValLbl.fontColor = .white
        gravValLbl.verticalAlignmentMode = .bottom; gravValLbl.horizontalAlignmentMode = .center
        gravValLbl.position = CGPoint(x: 0, y: gravTrackY + 12); gravValLbl.zPosition = 203
        gravValLbl.name = "opt_grav_vallabel"; overlay.addChild(gravValLbl)
        gravityValueLabel = gravValLbl

        let gravityGroupRect = CGRect(x: -130, y: h/2 - 452, width: 260, height: 170)
        let gravityGroup = SKShapeNode(rect: gravityGroupRect, cornerRadius: 8)
        gravityGroup.name = "env_gravity_group"; gravityGroup.strokeColor = SKColor(white: 1.0, alpha: 0.6)
        gravityGroup.lineWidth = 1; gravityGroup.fillColor = .clear; gravityGroup.zPosition = 201.5
        overlay.addChild(gravityGroup)

        // MARK: Ships/Controls tab content
        // AI on/off toggles (moved from Gameplay tab)
        let aiToggleHeaderY: CGFloat = 110
        let needleAIToggleY: CGFloat = 83
        let wedgeAIToggleY:  CGFloat = 53

        let aiToggleHeader = makeLabel("AI On/Off", y: aiToggleHeaderY, name: "ships_label_ai_toggle_title")
        overlay.addChild(aiToggleHeader)

        let needleAIToggleLabel = SKLabelNode(text: "Ship 1")
        needleAIToggleLabel.fontName = "AvenirNext-Bold"; needleAIToggleLabel.fontSize = 16
        needleAIToggleLabel.fontColor = .white; needleAIToggleLabel.horizontalAlignmentMode = .left
        needleAIToggleLabel.verticalAlignmentMode = .center
        needleAIToggleLabel.position = CGPoint(x: -w/2 + 20, y: needleAIToggleY)
        needleAIToggleLabel.name = "ships_label_ai_toggle_needle"; needleAIToggleLabel.zPosition = 202
        overlay.addChild(needleAIToggleLabel)
        
        // Ship 1 type indicator (shows current ship name)
        let needleShipType = SKLabelNode(text: needle?.profile.typeName ?? "")
        needleShipType.fontName = "AvenirNext-Medium"; needleShipType.fontSize = 12
        needleShipType.fontColor = SKColor(white: 1.0, alpha: 0.6)
        needleShipType.horizontalAlignmentMode = .left
        needleShipType.verticalAlignmentMode = .center
        needleShipType.position = CGPoint(x: -w/2 + 80, y: needleAIToggleY)
        needleShipType.name = "ships_type_needle"; needleShipType.zPosition = 202
        overlay.addChild(needleShipType)

        let aiBtn = SKShapeNode(rectOf: CGSize(width: 40, height: 24), cornerRadius: 5)
        aiBtn.name = "game_ai_toggle"; aiBtn.position = CGPoint(x: 0, y: needleAIToggleY)
        aiBtn.strokeColor = .white; aiBtn.lineWidth = 2; aiBtn.zPosition = 202
        overlay.addChild(aiBtn); aiToggleButton = aiBtn

        let wedgeAIToggleLabel = SKLabelNode(text: "Ship 2")
        wedgeAIToggleLabel.fontName = "AvenirNext-Bold"; wedgeAIToggleLabel.fontSize = 16
        wedgeAIToggleLabel.fontColor = .white; wedgeAIToggleLabel.horizontalAlignmentMode = .left
        wedgeAIToggleLabel.verticalAlignmentMode = .center
        wedgeAIToggleLabel.position = CGPoint(x: -w/2 + 20, y: wedgeAIToggleY)
        wedgeAIToggleLabel.name = "ships_label_ai_toggle_wedge"; wedgeAIToggleLabel.zPosition = 202
        overlay.addChild(wedgeAIToggleLabel)
        
        // Ship 2 type indicator (shows current ship name)
        let wedgeShipType = SKLabelNode(text: dart?.profile.typeName ?? "")
        wedgeShipType.fontName = "AvenirNext-Medium"; wedgeShipType.fontSize = 12
        wedgeShipType.fontColor = SKColor(white: 1.0, alpha: 0.6)
        wedgeShipType.horizontalAlignmentMode = .left
        wedgeShipType.verticalAlignmentMode = .center
        wedgeShipType.position = CGPoint(x: -w/2 + 80, y: wedgeAIToggleY)
        wedgeShipType.name = "ships_type_wedge"; wedgeShipType.zPosition = 202
        overlay.addChild(wedgeShipType)

        let wedgeAIBtn = SKShapeNode(rectOf: CGSize(width: 40, height: 24), cornerRadius: 5)
        wedgeAIBtn.name = "game_wedge_ai_toggle"; wedgeAIBtn.position = CGPoint(x: 0, y: wedgeAIToggleY)
        wedgeAIBtn.strokeColor = .white; wedgeAIBtn.lineWidth = 2; wedgeAIBtn.zPosition = 202
        overlay.addChild(wedgeAIBtn); wedgeAIToggleButton = wedgeAIBtn

        let aiSectionHeaderY: CGFloat = -10 // started at 20
        let needleAITrackY:   CGFloat = -35
        let wedgeAITrackY:    CGFloat = -75
        let bulletsSectionY:  CGFloat = -130
        let bulletsY:         CGFloat = -155
        //let bulletLifeY:      CGFloat = -172
        //let bulletButtonsY:   CGFloat = -202

        let aiSectionTitle = makeLabel("AI Intelligence", y: aiSectionHeaderY, name: "ships_label_ai_intelligence_title")
        overlay.addChild(aiSectionTitle)

        func makeAISlider(trackY: CGFloat, namePrefix: String, isNeedle: Bool) {
            let track = SKShapeNode(rectOf: CGSize(width: aiIntelligenceTrackWidth, height: 4), cornerRadius: 2)
            track.strokeColor = .white; track.fillColor = .white; track.alpha = 1.0
            track.position = CGPoint(x: 0, y: trackY)
            track.name = namePrefix + "track"; track.zPosition = 202
            overlay.addChild(track)

            for i in 0...aiIntelligenceSteps {
                let x = -aiIntelligenceTrackHalfWidth + CGFloat(i) * (aiIntelligenceTrackWidth / CGFloat(aiIntelligenceSteps))
                let tick = SKShapeNode(circleOfRadius: 3)
                tick.position = CGPoint(x: x, y: trackY)
                tick.fillColor = .white; tick.strokeColor = .white; tick.alpha = 0.9
                tick.name = namePrefix + "tick_\(i)"; tick.zPosition = 203
                overlay.addChild(tick)
            }

            let knob = SKShapeNode(circleOfRadius: 8)
            knob.strokeColor = .white; knob.fillColor = SKColor(white: 0.2, alpha: 0.8)
            knob.lineWidth = 2; knob.position = CGPoint(x: -aiIntelligenceTrackHalfWidth, y: trackY)
            knob.name = namePrefix + "knob"; knob.zPosition = 204
            overlay.addChild(knob)

            if isNeedle { needleAISliderTrack = track; needleAISliderKnob = knob }
            else        { wedgeAISliderTrack  = track; wedgeAISliderKnob  = knob }
        }

        let needleAIRowLabel = SKLabelNode(text: "Ship 1")
        needleAIRowLabel.fontName = "AvenirNext-Bold"; needleAIRowLabel.fontSize = 16
        needleAIRowLabel.fontColor = .white; needleAIRowLabel.horizontalAlignmentMode = .left
        needleAIRowLabel.verticalAlignmentMode = .center
        needleAIRowLabel.position = CGPoint(x: -w/2 + 20, y: needleAITrackY)
        needleAIRowLabel.name = "ships_label_ai_row_needle"; needleAIRowLabel.zPosition = 202
        overlay.addChild(needleAIRowLabel)

        makeAISlider(trackY: needleAITrackY, namePrefix: "opt_needle_ai_", isNeedle: true)

        let needleAICountLabel = SKLabelNode(text: "basic")
        needleAICountLabel.fontName = "AvenirNext-Bold"; needleAICountLabel.fontSize = 16
        needleAICountLabel.fontColor = .white; needleAICountLabel.horizontalAlignmentMode = .left
        needleAICountLabel.verticalAlignmentMode = .center
        needleAICountLabel.position = CGPoint(x: aiIntelligenceTrackHalfWidth + 20, y: needleAITrackY)
        needleAICountLabel.name = "count_label_needle_ai"; needleAICountLabel.zPosition = 202
        overlay.addChild(needleAICountLabel)

        let wedgeAIRowLabel = SKLabelNode(text: "Ship 2")
        wedgeAIRowLabel.fontName = "AvenirNext-Bold"; wedgeAIRowLabel.fontSize = 16
        wedgeAIRowLabel.fontColor = .white; wedgeAIRowLabel.horizontalAlignmentMode = .left
        wedgeAIRowLabel.verticalAlignmentMode = .center
        wedgeAIRowLabel.position = CGPoint(x: -w/2 + 20, y: wedgeAITrackY)
        wedgeAIRowLabel.name = "ships_label_ai_row_wedge"; wedgeAIRowLabel.zPosition = 202
        overlay.addChild(wedgeAIRowLabel)

        makeAISlider(trackY: wedgeAITrackY, namePrefix: "opt_wedge_ai_", isNeedle: false)

        let wedgeAICountLabel = SKLabelNode(text: "basic")
        wedgeAICountLabel.fontName = "AvenirNext-Bold"; wedgeAICountLabel.fontSize = 16
        wedgeAICountLabel.fontColor = .white; wedgeAICountLabel.horizontalAlignmentMode = .left
        wedgeAICountLabel.verticalAlignmentMode = .center
        wedgeAICountLabel.position = CGPoint(x: aiIntelligenceTrackHalfWidth + 20, y: wedgeAITrackY)
        wedgeAICountLabel.name = "count_label_wedge_ai"; wedgeAICountLabel.zPosition = 202
        overlay.addChild(wedgeAICountLabel)

        let bulletsTitle = makeLabel("Number of Bullets", y: bulletsSectionY, name: "ships_label_bullets")
        overlay.addChild(bulletsTitle)

        func makeSlider(trackY: CGFloat, namePrefix: String) {
            let track = SKShapeNode(rectOf: CGSize(width: sliderTrackWidth, height: 4), cornerRadius: 2)
            track.strokeColor = .white; track.fillColor = .white; track.alpha = 1.0
            track.position = CGPoint(x: 0, y: trackY)
            track.name = namePrefix + "track"; track.zPosition = 202
            overlay.addChild(track)

            for i in 0...bulletSliderSteps {
                let x = -sliderTrackHalfWidth + CGFloat(i) * (sliderTrackWidth / CGFloat(bulletSliderSteps))
                let tick = SKShapeNode(circleOfRadius: 3)
                tick.position = CGPoint(x: x, y: trackY)
                tick.fillColor = .white; tick.strokeColor = .white; tick.alpha = 0.9
                tick.name = namePrefix + "tick_\(i)"; tick.zPosition = 203
                overlay.addChild(tick)
            }

            let knob = SKShapeNode(circleOfRadius: 8)
            knob.strokeColor = .white; knob.fillColor = SKColor(white: 0.2, alpha: 0.8)
            knob.lineWidth = 2; knob.position = CGPoint(x: -sliderTrackHalfWidth, y: trackY)
            knob.name = namePrefix + "knob"; knob.zPosition = 204
            overlay.addChild(knob)

            if namePrefix.contains("needle") { needleBulletSliderTrack = track; needleBulletSliderKnob = knob }
            else                             { dartBulletSliderTrack   = track; dartBulletSliderKnob   = knob }
        }

        makeSlider(trackY: bulletsY,      namePrefix: "opt_bullets_needle_")
        makeSlider(trackY: bulletsY - 40, namePrefix: "opt_bullets_dart_")

        let needleSliderLabel = SKLabelNode(text: "Ship 1")
        needleSliderLabel.fontName = "AvenirNext-Bold"; needleSliderLabel.fontSize = 16
        needleSliderLabel.fontColor = .white; needleSliderLabel.horizontalAlignmentMode = .left
        needleSliderLabel.verticalAlignmentMode = .center
        needleSliderLabel.position = CGPoint(x: -w/2 + 20, y: bulletsY)
        needleSliderLabel.name = "ships_label_row_needle"; needleSliderLabel.zPosition = 202
        overlay.addChild(needleSliderLabel)

        let needleCountLabel = SKLabelNode(text: "")
        needleCountLabel.fontName = "AvenirNext-Bold"; needleCountLabel.fontSize = 16
        needleCountLabel.fontColor = .white; needleCountLabel.horizontalAlignmentMode = .left
        needleCountLabel.verticalAlignmentMode = .center
        needleCountLabel.position = CGPoint(x: sliderTrackHalfWidth + 20, y: bulletsY)
        needleCountLabel.name = "count_label_row_needle"
        if let n = needle {
            needleCountLabel.text = bulletLabelText(needleBulletLimitSelection, for: n)
        }
        needleCountLabel.zPosition = 202; overlay.addChild(needleCountLabel)

        let wedgeSliderLabel = SKLabelNode(text: "Ship 2")
        wedgeSliderLabel.fontName = "AvenirNext-Bold"; wedgeSliderLabel.fontSize = 16
        wedgeSliderLabel.fontColor = .white; wedgeSliderLabel.horizontalAlignmentMode = .left
        wedgeSliderLabel.verticalAlignmentMode = .center
        wedgeSliderLabel.position = CGPoint(x: -w/2 + 20, y: bulletsY - 40)
        wedgeSliderLabel.name = "ships_label_row_wedge"; wedgeSliderLabel.zPosition = 202
        overlay.addChild(wedgeSliderLabel)

        let wedgeCountLabel = SKLabelNode(text: "")
        wedgeCountLabel.fontName = "AvenirNext-Bold"; wedgeCountLabel.fontSize = 16
        wedgeCountLabel.fontColor = .white; wedgeCountLabel.horizontalAlignmentMode = .left
        wedgeCountLabel.verticalAlignmentMode = .center
        wedgeCountLabel.position = CGPoint(x: sliderTrackHalfWidth + 20, y: bulletsY - 40)
        wedgeCountLabel.name = "count_label_row_wedge"
        if let d = dart {
            wedgeCountLabel.text = bulletLabelText(dartBulletLimitSelection, for: d)
        }
        wedgeCountLabel.zPosition = 202; overlay.addChild(wedgeCountLabel)

        // MARK: Gameplay tab content
        let newMatchBtn = SKShapeNode(rectOf: CGSize(width: 140, height: 36), cornerRadius: 8)
        newMatchBtn.name = "game_new_match"; newMatchBtn.position = CGPoint(x: 0, y: h/2 - 162) // more negative means farther down
        newMatchBtn.fillColor = .clear; newMatchBtn.strokeColor = .white; newMatchBtn.lineWidth = 2
        newMatchBtn.zPosition = 202; overlay.addChild(newMatchBtn)
        newMatchBtn.addChild(makeTabInnerLabel("New Match", fontSize: 16))

        let aimLabel = makeLabel("Aim Persists:", y: h/2 - 235, name: "game_label_aim_persist")
        overlay.addChild(aimLabel)

        let aimBtn = SKShapeNode(rectOf: CGSize(width: 40, height: 24), cornerRadius: 5)
        aimBtn.name = "game_aim_persist_toggle"; aimBtn.position = CGPoint(x: 0, y: h/2 - 260)
        aimBtn.strokeColor = .white; aimBtn.lineWidth = 2; aimBtn.zPosition = 202
        overlay.addChild(aimBtn); aimPersistToggleButton = aimBtn

        let vsLabel = makeLabel("Virtual Screen:", y: h/2 - 320, name: "game_label_virtual_screen")
        overlay.addChild(vsLabel)

        let vsTrackY: CGFloat = h/2 - 342
        let vsTrack = SKShapeNode(rectOf: CGSize(width: sliderTrackWidth, height: 4), cornerRadius: 2)
        vsTrack.strokeColor = .white; vsTrack.fillColor = .white; vsTrack.alpha = 1.0
        vsTrack.position = CGPoint(x: 0, y: vsTrackY)
        vsTrack.name = "game_vs_track"; vsTrack.zPosition = 202; overlay.addChild(vsTrack)
        virtualScreenSliderTrack = vsTrack

        let vsLabels = ["off", "3000"]
        for i in 0...virtualScreenSteps {
            let x = -sliderTrackHalfWidth + CGFloat(i) * (sliderTrackWidth / CGFloat(virtualScreenSteps))
            let tick = SKShapeNode(circleOfRadius: 3)
            tick.position = CGPoint(x: x, y: vsTrackY)
            tick.fillColor = .white; tick.strokeColor = .white
            tick.name = "game_vs_tick_\(i)"; tick.zPosition = 203; overlay.addChild(tick)
            let tl = SKLabelNode(text: vsLabels[i])
            tl.fontName = "AvenirNext-Bold"; tl.fontSize = 11; tl.fontColor = .white
            tl.verticalAlignmentMode = .top; tl.horizontalAlignmentMode = .center
            tl.position = CGPoint(x: x, y: vsTrackY - 8); tl.zPosition = 203
            tl.name = "game_vs_ticklabel_\(i)"; overlay.addChild(tl)
        }
        let vsKnob = SKShapeNode(circleOfRadius: 8)
        vsKnob.fillColor = .white; vsKnob.strokeColor = .white; vsKnob.lineWidth = 2
        vsKnob.position = CGPoint(x: -sliderTrackHalfWidth, y: vsTrackY)
        vsKnob.name = "game_vs_knob"; vsKnob.zPosition = 204; overlay.addChild(vsKnob)
        virtualScreenSliderKnob = vsKnob

        // MARK: About tab content
        let about = SKNode(); about.zPosition = 202; about.isHidden = true

        let title = SKLabelNode(text: "SpaceWar 2062")
        title.fontName = "AvenirNext-Bold"; title.fontSize = 22; title.fontColor = .white
        title.position = CGPoint(x: 0, y: 40); about.addChild(title)

        let copy = SKLabelNode(text: "© 2026 Michael Stern")
        copy.fontName = "AvenirNext-Medium"; copy.fontSize = 12; copy.fontColor = .white
        copy.position = CGPoint(x: 0, y: -h/2 + 20); about.addChild(copy)

        overlay.addChild(about); aboutContainer = about
        optionsOverlay = overlay; addChild(overlay)

        print("  🔄 Initial refreshOptionsUI...")
        refreshOptionsUI()
        print("  📑 Setting initial tab to environment...")
        setOptionsTab(.environment)
        print("  📋 setupOptionsOverlay COMPLETE")
    }

    func makeTabInnerLabel(_ text: String, fontSize: CGFloat = 14) -> SKLabelNode {
        let lbl = SKLabelNode(text: text)
        lbl.fontName = "AvenirNext-Bold"; lbl.fontSize = fontSize; lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center; lbl.horizontalAlignmentMode = .center
        lbl.position = .zero; lbl.zPosition = 203
        return lbl
    }

    func sliderIndexForOverlayX(_ x: CGFloat) -> Int {
        let step = sliderTrackWidth / CGFloat(bulletSliderSteps)
        let idx = Int(round((x + sliderTrackHalfWidth) / step))
        return max(0, min(bulletSliderSteps, idx))
    }

    func gravityLabelText() -> String {
        if gravitySliderSelection == 0 { return "Off" }
        let val = gravityMultiplier / 8.0
        return String(format: "%.1f×", val)
    }

    func bulletLifeLabelText() -> String {
        return String(format: "%.1f s", bulletLifeSeconds)
    }

    func aiSliderIndexForOverlayX(_ x: CGFloat) -> Int {
        let step = aiIntelligenceTrackWidth / CGFloat(aiIntelligenceSteps)
        let idx = Int(round((x + aiIntelligenceTrackHalfWidth) / step))
        return max(0, min(aiIntelligenceSteps, idx))
    }

    func touchIsOnSlider(track: SKShapeNode?, locInOverlay: CGPoint) -> Bool {
        guard let track else { return false }
        let ty = track.position.y
        let inX = locInOverlay.x >= (-sliderTrackHalfWidth - 20) && locInOverlay.x <= (sliderTrackHalfWidth + 20)
        let inY = abs(locInOverlay.y - ty) <= 20
        return inX && inY
    }

    func refreshOptionsUI() {
        let selFill = SKColor.white
        let offFill = SKColor.clear
        let selText = SKColor.black
        let offText = SKColor.white

        func styleBtn(_ b: SKShapeNode?, selected: Bool) {
            guard let b else { return }
            b.fillColor   = selected ? selFill : offFill
            b.strokeColor = SKColor.white
            b.lineWidth   = 2
            b.glowWidth   = 0
            if let lbl = b.children.compactMap({ $0 as? SKLabelNode }).first {
                lbl.fontColor = selected ? selText : offText
            }
        }

        let gamePrefixes  = ["game_"]
        // AI toggle buttons live in Controls tab despite having game_ prefix
        let gameExclusions = ["game_ai_toggle", "game_wedge_ai_toggle"]
        let envPrefixes   = ["opt_edge_", "opt_sun_toggle", "opt_bullet_grav_toggle",
                             "opt_grav_", "env_label_", "env_gravity_group"]
        let shipsPrefixes = ["ships_label_", "ships_type_",
                             "opt_bullets_", "count_label_", "opt_needle_ai_", "opt_wedge_ai_",
                             "game_ai_toggle", "game_wedge_ai_toggle"]

        optionsOverlay?.children.forEach { node in
            if node.name == "options_bg" { return }
            if node === gameTabButton || node === optionsTabButton ||
               node === shipsTabButton || node === aboutTabButton ||
               node === shipSelectionTabButton || node === networkTabButton ||
               node === aboutContainer || node === shipSelectionContainer || node === networkContainer { return }
            let name = node.name ?? ""
            switch currentOptionsTab {
            case .environment:   node.isHidden = !envPrefixes.contains(where: { name.hasPrefix($0) })
            case .ships:         node.isHidden = !shipsPrefixes.contains(where: { name.hasPrefix($0) })
            case .game:          node.isHidden = gameExclusions.contains(name) || !gamePrefixes.contains(where: { name.hasPrefix($0) })
            case .about, .shipSelection, .network: node.isHidden = true
            }
        }

        aboutContainer?.isHidden          = (currentOptionsTab != .about)
        shipSelectionContainer?.isHidden   = (currentOptionsTab != .shipSelection)
        networkContainer?.isHidden         = (currentOptionsTab != .network)

        func setTab(_ tabNode: SKShapeNode?, selected: Bool) {
            guard let tabNode, let lbl = tabNode.children.compactMap({ $0 as? SKLabelNode }).first else { return }
            tabNode.fillColor   = selected ? selFill : offFill
            tabNode.strokeColor = SKColor.white
            tabNode.lineWidth   = 2
            tabNode.glowWidth   = 0
            lbl.fontColor       = selected ? selText : offText
        }
        setTab(gameTabButton,          selected: currentOptionsTab == .game)
        setTab(optionsTabButton,       selected: currentOptionsTab == .environment)
        setTab(shipsTabButton,         selected: currentOptionsTab == .ships)
        setTab(aboutTabButton,         selected: currentOptionsTab == .about)
        setTab(shipSelectionTabButton, selected: currentOptionsTab == .shipSelection)
        setTab(networkTabButton,       selected: currentOptionsTab == .network)

        styleBtn(edgeBounceButton,   selected: edgeBehavior == .bounce)
        styleBtn(edgeWrapButton,     selected: edgeBehavior == .wrap)

        aiToggleButton?.fillColor      = needleAIEnabled ? selFill : offFill
        wedgeAIToggleButton?.fillColor = wedgeAIEnabled  ? selFill : offFill
        aimPersistToggleButton?.fillColor = aimPersistsAfterLift ? selFill : offFill

        if let knob = gravitySliderKnob, let track = gravitySliderTrack {
            let x = -sliderTrackHalfWidth + CGFloat(gravitySliderSelection) * (sliderTrackWidth / CGFloat(gravitySliderSteps))
            knob.position = CGPoint(x: x, y: track.position.y)
        }
        gravityValueLabel?.text = gravityLabelText()

        if let knob = virtualScreenSliderKnob, let track = virtualScreenSliderTrack {
            let x = -sliderTrackHalfWidth + CGFloat(savedVirtualScreenSelection) * (sliderTrackWidth / CGFloat(virtualScreenSteps))
            knob.position = CGPoint(x: x, y: track.position.y)
        }
        if let knob = needleBulletSliderKnob, let track = needleBulletSliderTrack {
            let x = -sliderTrackHalfWidth + CGFloat(needleBulletLimitSelection) * (sliderTrackWidth / CGFloat(bulletSliderSteps))
            knob.position = CGPoint(x: x, y: track.position.y)
        }
        if let knob = dartBulletSliderKnob, let track = dartBulletSliderTrack {
            let x = -sliderTrackHalfWidth + CGFloat(dartBulletLimitSelection) * (sliderTrackWidth / CGFloat(bulletSliderSteps))
            knob.position = CGPoint(x: x, y: track.position.y)
        }

        if let label = optionsOverlay?.childNode(withName: "count_label_row_wedge") as? SKLabelNode, let d = dart {
            label.text = bulletLabelText(dartBulletLimitSelection, for: d)
        }
        if let label = optionsOverlay?.childNode(withName: "count_label_row_needle") as? SKLabelNode, let n = needle {
            label.text = bulletLabelText(needleBulletLimitSelection, for: n)
        }

        let aiLevelNames = ["basic", "smart", "expert"]

        let needleAIOn = needleAIEnabled
        needleAISliderTrack?.alpha = needleAIOn ? 1.0 : 0.4
        if let knob = needleAISliderKnob, let track = needleAISliderTrack {
            knob.alpha = needleAIOn ? 1.0 : 0.4
            let x = -aiIntelligenceTrackHalfWidth + CGFloat(needleAIIntelligence) * (aiIntelligenceTrackWidth / CGFloat(aiIntelligenceSteps))
            knob.position = CGPoint(x: x, y: track.position.y)
        }
        if let label = optionsOverlay?.childNode(withName: "count_label_needle_ai") as? SKLabelNode {
            label.alpha = needleAIOn ? 1.0 : 0.4
            label.text = aiLevelNames[min(needleAIIntelligence, aiLevelNames.count - 1)]
        }
        optionsOverlay?.enumerateChildNodes(withName: "opt_needle_ai_tick_*") { node, _ in
            node.alpha = needleAIOn ? 0.9 : 0.4
        }
        if let label = optionsOverlay?.childNode(withName: "ships_label_ai_row_needle") {
            label.alpha = needleAIOn ? 1.0 : 0.4
        }

        let wedgeAIOn = wedgeAIEnabled
        wedgeAISliderTrack?.alpha = wedgeAIOn ? 1.0 : 0.4
        if let knob = wedgeAISliderKnob, let track = wedgeAISliderTrack {
            knob.alpha = wedgeAIOn ? 1.0 : 0.4
            let x = -aiIntelligenceTrackHalfWidth + CGFloat(wedgeAIIntelligence) * (aiIntelligenceTrackWidth / CGFloat(aiIntelligenceSteps))
            knob.position = CGPoint(x: x, y: track.position.y)
        }
        if let label = optionsOverlay?.childNode(withName: "count_label_wedge_ai") as? SKLabelNode {
            label.alpha = wedgeAIOn ? 1.0 : 0.4
            label.text = aiLevelNames[min(wedgeAIIntelligence, aiLevelNames.count - 1)]
        }
        optionsOverlay?.enumerateChildNodes(withName: "opt_wedge_ai_tick_*") { node, _ in
            node.alpha = wedgeAIOn ? 0.9 : 0.4
        }
        if let label = optionsOverlay?.childNode(withName: "ships_label_ai_row_wedge") {
            label.alpha = wedgeAIOn ? 1.0 : 0.4
        }
        
        // Update ship type indicators to show current ship names
        if let typeLabel = optionsOverlay?.childNode(withName: "ships_type_needle") as? SKLabelNode {
            typeLabel.text = needle?.profile.typeName ?? ""
        }
        if let typeLabel = optionsOverlay?.childNode(withName: "ships_type_wedge") as? SKLabelNode {
            typeLabel.text = dart?.profile.typeName ?? ""
        }
    }

    func setOptionsTab(_ tab: OptionsTab) {
        currentOptionsTab = tab
        
        // Build ship selection UI if switching to that tab and it hasn't been built yet
        if tab == .shipSelection, let container = shipSelectionContainer, container.children.isEmpty {
            if let overlay = optionsOverlay {
                let w = min(380, size.width - 40)
                let h: CGFloat = 492
                setupShipSelectionUI(in: overlay, panelWidth: w, panelHeight: h)
            }
        }
        
        refreshOptionsUI()
    }

}

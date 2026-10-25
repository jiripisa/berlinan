import SwiftUI

/// Berlinan design system — studio-dark with a tangerine primary accent.
/// Source of truth: design_language.md (this file must match it token for
/// token). Structure follows Sampio's DesignTokens.swift; hex values kept in
/// comments for traceability.
enum AppColor {

  // MARK: Surfaces (design_language.md §2.1 — adopted from Sampio)

  static let bgRoom    = Color(red: 0x0b/255.0, green: 0x0d/255.0, blue: 0x10/255.0)  // #0b0d10 — outermost
  static let bgWindow  = Color(red: 0x13/255.0, green: 0x14/255.0, blue: 0x18/255.0)  // #131418 — window body
  static let bgPanel   = Color(red: 0x1a/255.0, green: 0x1c/255.0, blue: 0x21/255.0)  // #1a1c21 — toolbars, inspector
  static let bgPanel2  = Color(red: 0x15/255.0, green: 0x17/255.0, blue: 0x1b/255.0)  // #15171b — pattern strips
  static let bgPanel3  = Color(red: 0x0f/255.0, green: 0x11/255.0, blue: 0x15/255.0)  // #0f1115 — timeline / status bar

  /// Transport-bar chrome.
  static let toolbarGradient = LinearGradient(
    colors: [
      Color(red: 0x16/255.0, green: 0x19/255.0, blue: 0x1f/255.0),  // #16191f
      Color(red: 0x12/255.0, green: 0x14/255.0, blue: 0x1a/255.0),  // #12141a
    ],
    startPoint: .top, endPoint: .bottom
  )

  /// Pattern-strip interior fill.
  static let laneGradient = LinearGradient(
    colors: [
      Color(red: 0x16/255.0, green: 0x19/255.0, blue: 0x20/255.0),  // #161920
      Color(red: 0x0e/255.0, green: 0x10/255.0, blue: 0x14/255.0),  // #0e1014
    ],
    startPoint: .top, endPoint: .bottom
  )

  // MARK: Hairlines (§2.2)

  static let line       = Color(red: 0x24/255.0, green: 0x27/255.0, blue: 0x2d/255.0)  // #24272d
  static let lineSoft   = Color(red: 0x1d/255.0, green: 0x1f/255.0, blue: 0x24/255.0)  // #1d1f24
  static let lineStrong = Color(red: 0x2c/255.0, green: 0x30/255.0, blue: 0x37/255.0)  // #2c3037

  // MARK: Text — ink scale (§2.3)

  static let ink   = Color(red: 0xe7/255.0, green: 0xec/255.0, blue: 0xf2/255.0)  // #e7ecf2 — primary
  static let ink2  = Color(red: 0xaa/255.0, green: 0xb2/255.0, blue: 0xbd/255.0)  // #aab2bd — secondary
  // Contrast floor (§2.3): ink3 ≥ 4.5:1 on every panel — labels and hints are
  // ink3, never darker; ink4 ≥ 3:1, for disabled / ghosted states only.
  static let ink3  = Color(red: 0x7e/255.0, green: 0x86/255.0, blue: 0x92/255.0)  // #7e8692 — tertiary, labels
  static let ink4  = Color(red: 0x60/255.0, green: 0x69/255.0, blue: 0x73/255.0)  // #606973 — disabled

  // MARK: Accent — tangerine (primary, §2.4)

  static let tangerine     = Color(red: 0xff/255.0, green: 0x9e/255.0, blue: 0x4a/255.0)  // #FF9E4A
  static let tangerineSoft = Color(red: 0xe8/255.0, green: 0x87/255.0, blue: 0x3a/255.0)  // #E8873A
  static let tangerineDeep = Color(red: 0xa8/255.0, green: 0x5c/255.0, blue: 0x1f/255.0)  // #A85C1F
  static let tangerineGlow = Color(red: 0xff/255.0, green: 0x9e/255.0, blue: 0x4a/255.0).opacity(0.18)
  static let tangerineLine = Color(red: 0xff/255.0, green: 0x9e/255.0, blue: 0x4a/255.0).opacity(0.45)

  // MARK: Accent — cyan (secondary/informational: phasing, sync; §2.4)

  static let cyan     = Color(red: 0x4f/255.0, green: 0xd9/255.0, blue: 0xf2/255.0)  // #4FD9F2
  static let cyanGlow = Color(red: 0x4f/255.0, green: 0xd9/255.0, blue: 0xf2/255.0).opacity(0.18)
  static let cyanLine = Color(red: 0x4f/255.0, green: 0xd9/255.0, blue: 0xf2/255.0).opacity(0.45)

  // MARK: Functional (§2.5)

  static let rec     = Color(red: 0xff/255.0, green: 0x6a/255.0, blue: 0x4f/255.0)  // #FF6A4F
  static let recGlow = Color(red: 0xff/255.0, green: 0x6a/255.0, blue: 0x4f/255.0).opacity(0.20)
  static let recLine = Color(red: 0xff/255.0, green: 0x6a/255.0, blue: 0x4f/255.0).opacity(0.45)
  static let amber   = Color(red: 0xf6/255.0, green: 0xc1/255.0, blue: 0x6b/255.0)  // #F6C16B — warnings
  static let green   = Color(red: 0x7b/255.0, green: 0xd8/255.0, blue: 0x8f/255.0)  // #7BD88F — activity/positive
}

/// Voice identity colors (design_language.md §2.6). Active notes render at
/// full hue, idle at 55% opacity, muted lanes tint with AppColor.ink4.
enum VoiceColor {
  static let bedPluck1 = Color(red: 0x5f/255.0, green: 0xb8/255.0, blue: 0xc9/255.0)  // #5FB8C9 dusty cyan
  static let bedPluck2 = Color(red: 0x5f/255.0, green: 0x9e/255.0, blue: 0xc9/255.0)  // #5F9EC9 dusty blue
  static let bass      = Color(red: 0xc9/255.0, green: 0x97/255.0, blue: 0x5f/255.0)  // #C9975F dusty amber
  static let pad       = Color(red: 0x9b/255.0, green: 0x7f/255.0, blue: 0xc9/255.0)  // #9B7FC9 dusty violet
  static let lead      = Color(red: 0xd9/255.0, green: 0xdd/255.0, blue: 0xe3/255.0)  // #D9DDE3 near-ink
  static let drone     = Color(red: 0x5f/255.0, green: 0x6f/255.0, blue: 0xa8/255.0)  // #5F6FA8 deep slate blue
  static let rhythm    = Color(red: 0xc9/255.0, green: 0x6f/255.0, blue: 0x6f/255.0)  // #C96F6F dusty red
}

/// Typography roles (design_language.md §3). System fonts only.
enum AppFont {

  // Sans (UI labels)
  static func sansRegular(_ size: CGFloat) -> Font { .system(size: size, weight: .regular) }
  static func sansMedium(_ size: CGFloat)  -> Font { .system(size: size, weight: .medium) }
  static func sansBold(_ size: CGFloat)    -> Font { .system(size: size, weight: .bold) }

  // Mono (all data the producer reads: bars, BPM, degrees, LCM, CC values)
  static func monoRegular(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .monospaced) }
  static func monoMedium(_ size: CGFloat)  -> Font { .system(size: size, weight: .medium, design: .monospaced) }
  static func monoBold(_ size: CGFloat)    -> Font { .system(size: size, weight: .bold, design: .monospaced) }

  // Named roles
  static let sectionLabel  = sansBold(9.5)      // "VOICES", "HARMONY", "PHASING"
  static let fieldLabel    = monoMedium(9)      // "BPM", "KEY", "LCM", "DEG"
  static let monoCaption   = monoRegular(10)    // readouts, status bar, hints
  static let timecodeBig   = monoMedium(18)     // bar:beat position, BPM display
  static let degreeDisplay = monoBold(24)       // current transposition degree
  static let body          = sansRegular(11)    // buttons, menus, inspector
}

/// Tracking presets in points (design_language.md §3).
enum AppTracking {
  static let label: CGFloat   = 1.6   // uppercase section labels
  static let field: CGFloat   = 1.3   // mono field labels
  static let caption: CGFloat = 0.6   // mono captions
  static let body: CGFloat    = 0.2   // UI button labels
}

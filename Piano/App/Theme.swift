import CoreText
import SwiftUI
import UIKit

/// The app's palette: an old upright piano rather than a digital one.
///
/// Warm walnut for the case, aged ivory for the naturals, ebony-brown for the
/// accidentals, and a little tarnished brass for the one piece of hardware.
/// Fixed, not system-derived: an instrument should look the same every time you
/// pick it up.
enum Theme {

    private static func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> UIColor {
        UIColor(red: r, green: g, blue: b, alpha: a)
    }

    // MARK: - Lettering    /// The face the whole instrument is lettered in: New York, the serif that
    /// ships as part of the system, so nothing is bundled and no font licence
    /// has to travel with the app. Asked for by design rather than by name,
    /// which is how the system serif is meant to be reached, and falls back to
    /// the plain system face if the design is ever unavailable.
    static func lettering(_ size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: .regular)
        guard let serif = base.fontDescriptor.withDesign(.serif) else { return base }
        return UIFont(descriptor: serif, size: size)
    }

    static func letteringFont(_ size: CGFloat) -> Font {
        Font(lettering(size) as CTFont)
    }
    /// How far to nudge a piece of lettering down so its ink, rather than its
    /// line box, sits centred.
    ///
    /// A layout centres the line box, which runs from the ascender to the
    /// descender. Short strings reach neither, and how far they miss by depends
    /// on the characters: capitals sit high in the box, guillemets low. Both
    /// looked off centre by eye until this measured each string against the
    /// font instead of assuming a capital.
    static func letteringVerticalCorrection(of text: String, size: CGFloat) -> CGFloat {
        let font = lettering(size)
        let ctFont = font as CTFont
        var characters = Array(text.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        guard !characters.isEmpty,
              CTFontGetGlyphsForCharacters(ctFont, &characters, &glyphs, characters.count)
        else { return 0 }

        // Core Text measures up from the baseline, and every glyph here shares
        // one, so the union of their rects gives the ink the string occupies.
        let ink = CTFontGetBoundingRectsForGlyphs(ctFont, .default, glyphs, nil, glyphs.count)
        guard !ink.isNull, ink.height > 0 else { return 0 }

        let boxCentre = (font.ascender + font.descender) / 2   // descender is negative
        return ink.midY - boxCentre
    }

    // MARK: - Case

    /// The wood of the case, top to bottom. Three tones rather than two so the
    /// panel turns slightly rather than fading flatly.
    static let woodLight = rgb(0.365, 0.259, 0.180)
    static let woodMid = rgb(0.278, 0.192, 0.129)
    static let woodDark = rgb(0.157, 0.106, 0.071)

    /// Vertical banding at very low contrast, overlaid to suggest grain. It has
    /// to stay near-invisible: the moment it reads as a wood photograph it stops
    /// looking like a well-kept instrument.
    static let woodGrain: [Color] = [
        Color.white.opacity(0.030), Color.black.opacity(0.048), Color.clear,
        Color.white.opacity(0.022), Color.black.opacity(0.062), Color.white.opacity(0.014),
        Color.clear, Color.black.opacity(0.038), Color.white.opacity(0.034),
        Color.black.opacity(0.054), Color.clear, Color.white.opacity(0.018),
        Color.black.opacity(0.070), Color.white.opacity(0.026), Color.clear,
        Color.black.opacity(0.042), Color.white.opacity(0.032), Color.black.opacity(0.058),
        Color.clear, Color.white.opacity(0.020), Color.black.opacity(0.050),
        Color.white.opacity(0.028), Color.clear, Color.black.opacity(0.040),
    ]

    /// The bead of light along the top edge of the routed keybed.
    static let caseHighlight = rgb(0.596, 0.463, 0.318, 0.45)
    /// The case casting down into the keybed.
    static let keybedShadow = rgb(0.043, 0.024, 0.012, 0.75)

    /// The dark recess the keys sit in, which also shows through as the seam
    /// between neighbouring naturals.
    static let keybed = rgb(0.094, 0.063, 0.043)

    static let primaryText = rgb(0.906, 0.855, 0.769)
    static let secondaryText = rgb(0.596, 0.518, 0.420)

    /// Warm, never neutral: a grey shadow on warm wood reads as dirt.
    static let shadow = rgb(0.075, 0.043, 0.024)

    // MARK: - Naturals

    /// Front to back. Aged ivory, clean rather than yellowed and stained.
    static let whiteKey = [
        rgb(0.984, 0.965, 0.925).cgColor,
        rgb(0.965, 0.937, 0.878).cgColor,
        rgb(0.925, 0.886, 0.804).cgColor,
        rgb(0.855, 0.804, 0.706).cgColor,
    ]

    static let whiteKeyPressed = [
        rgb(0.882, 0.847, 0.769).cgColor,
        rgb(0.855, 0.812, 0.718).cgColor,
        rgb(0.812, 0.761, 0.655).cgColor,
        rgb(0.729, 0.671, 0.557).cgColor,
    ]

    // MARK: - Accidentals

    /// Very dark brown rather than flat black, so they sit in the same world as
    /// the case instead of punching holes in it.
    static let blackKey = [
        rgb(0.243, 0.184, 0.141).cgColor,
        rgb(0.196, 0.145, 0.106).cgColor,
        rgb(0.129, 0.090, 0.063).cgColor,
        rgb(0.067, 0.043, 0.028).cgColor,
    ]

    /// Flatter than the resting ramp, not merely brighter than it.
    ///
    /// The gradient runs brightest at the struck end, and that end is under
    /// the finger the moment the key sounds. What you can actually see while
    /// playing is the back of the key, which the resting ramp leaves nearly
    /// black across its last half. So the back lifts furthest here and the
    /// front barely moves: a pressed key is tipped toward you and catches
    /// light along its whole length, which is both what the eye needs and
    /// what the thing itself would do.
    static let blackKeyPressed = [
        rgb(0.412, 0.313, 0.240).cgColor,
        rgb(0.360, 0.270, 0.200).cgColor,
        rgb(0.310, 0.228, 0.166).cgColor,
        rgb(0.250, 0.180, 0.128).cgColor,
    ]

    /// Where the gradient stops sit along a key, front to back. The first pair
    /// is tight, so the front lip catches the light the way a real key does.
    static let keyGradientStops: [NSNumber] = [0.0, 0.10, 0.55, 1.0]

    /// The lit edge along the top of each key.
    static let naturalBevel = rgb(1.0, 0.988, 0.949, 0.55)
    static let accidentalBevel = rgb(0.831, 0.729, 0.573, 0.20)

    /// Muted brass, dark enough to stay legible against aged ivory.
    static let keyLabel = rgb(0.478, 0.388, 0.239)
    static let keyLabelPressed = rgb(0.365, 0.290, 0.169)

    /// Every natural except C, lightened so the Cs still read as the landmarks
    /// when seven labels share a row.
    static let keyLabelSecondary = rgb(0.612, 0.533, 0.400)
    static let keyLabelSecondaryPressed = rgb(0.494, 0.427, 0.318)

    /// The same brass, lifted for the dark keybed the range bar sits on.
    static let brassText = rgb(0.706, 0.612, 0.435)
    static let brassTextColor = Color(rgb(0.706, 0.612, 0.435))

    // MARK: - Hardware

    /// Tarnished brass, lit from above.
    static let brassHighlight = Color(rgb(0.639, 0.553, 0.400))
    static let brassMid = Color(rgb(0.502, 0.424, 0.290))
    static let brassShadow = Color(rgb(0.333, 0.271, 0.176))
    static let brassEdge = Color(rgb(0.176, 0.137, 0.086))

    /// The routed channel the thumb runs in.
    static let trackTop = Color(rgb(0.086, 0.055, 0.035))
    static let trackBottom = Color(rgb(0.157, 0.110, 0.078))
    static let trackRim = Color(rgb(0.400, 0.310, 0.212, 0.55))

    // MARK: - Recessed controls

    /// The controls are cut into the rail rather than sitting on it. Darker
    /// than the keybed around them, so the eye reads a hollow rather than a
    /// button, and the brass mark inside is the only thing that carries weight.
    static let controlRecess = Color(rgb(0.055, 0.035, 0.022))

    /// Barely there: the light along the lip of a routed edge, not an outline.
    static let controlRim = Color(rgb(0.400, 0.310, 0.212, 0.22))

    /// Brass, thin, and only on the things you press. The groove the slider
    /// runs in keeps the fainter rim above: it is a channel, not a control, and
    /// outlining it too would put every edge on the rail at the same weight.
    static let controlEdge = Color(rgb(0.706, 0.612, 0.435, 0.38))

    /// The catch is the one control you press rather than drag, so it stands
    /// proud instead of sinking in. Barely: the top of its face is a shade
    /// lighter than the keybed and the bottom a shade darker, which is enough
    /// for the eye to read a cap without anything looking moulded.
    static let capFaceTop = Color(rgb(0.152, 0.112, 0.078))
    static let capFaceBottom = Color(rgb(0.096, 0.066, 0.045))

    /// The cap is outlined the whole way round, brighter along the top lip
    /// than the bottom. Fading one side to nothing left the shape with no
    /// lower edge, so the eye could not tell where the button stopped.
    static let capEdgeTop = Color(rgb(0.706, 0.612, 0.435, 0.60))
    static let capEdgeBottom = Color(rgb(0.706, 0.612, 0.435, 0.34))

    // MARK: - SwiftUI

    static let woodLightColor = Color(woodLight)
    static let woodMidColor = Color(woodMid)
    static let woodDarkColor = Color(woodDark)
    static let caseHighlightColor = Color(caseHighlight)
    static let keybedShadowColor = Color(keybedShadow)
    static let keybedColor = Color(keybed)
    static let primaryTextColor = Color(primaryText)
    static let secondaryTextColor = Color(secondaryText)
}

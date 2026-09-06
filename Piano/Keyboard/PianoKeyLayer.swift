import CoreText
import QuartzCore
import UIKit

/// Which way a key faces.
enum KeyOrientation {
    /// The piano turned a quarter turn clockwise: the struck end of the key is
    /// on the left, accidentals reach in from the right.
    case frontLeft
    /// A conventional keyboard: the struck end is at the bottom, accidentals
    /// reach down from the top.
    case frontBottom
}

/// One piano key.
///
/// A `CALayer` rather than a `UIView`: individual keys do not handle their own
/// touches (the keyboard tracks every finger itself, so that sliding between
/// keys works), and layers are cheaper to lay out and repaint.
///
/// A key can be reassigned to a different note or turned to face a different
/// way, so changing arrangement costs a reconfigure rather than a rebuild.
final class PianoKeyLayer: CALayer {

    /// How long the key takes to fade back to its resting colour. Pressing is
    /// instant; only the release is eased, and only barely.
    private static let releaseDuration: CFTimeInterval = 0.055

    /// The same face the range carries, so the instrument is lettered in one
    /// hand throughout.
    private static let serif = Theme.lettering(34)

    var note: PianoNote {
        didSet {
            guard note != oldValue else { return }
            configure()
            setNeedsLayout()
        }
    }

    var orientation: KeyOrientation {
        didSet {
            guard orientation != oldValue else { return }
            configure()
            setNeedsLayout()
        }
    }

    private let body = CAGradientLayer()
    private let bevel = CALayer()
    private let label = CATextLayer()

    var isPressed: Bool = false {
        didSet {
            guard isPressed != oldValue else { return }
            applyColors(animated: !isPressed)
        }
    }

    init(note: PianoNote, orientation: KeyOrientation) {
        self.note = note
        self.orientation = orientation
        super.init()
        masksToBounds = false
        setUpSublayers()
        configure()
    }

    /// Core Animation copies layers through this initialiser while animating.
    override init(layer: Any) {
        let source = layer as? PianoKeyLayer
        note = source?.note ?? PianoNote(midi: 60)
        orientation = source?.orientation ?? .frontLeft
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setUpSublayers() {
        body.locations = Theme.keyGradientStops
        body.shadowColor = Theme.shadow.cgColor
        addSublayer(body)

        // A hairline along the lit long edge.
        addSublayer(bevel)

        label.truncationMode = .none
        label.isWrapped = false
        // Handed over as a font rather than looked up by name: the system
        // serif has no public name to look up.
        label.font = Self.serif as CTFont
        label.fontSize = Self.serif.pointSize
        addSublayer(label)
    }

    /// Everything that depends on which note this is and which way it faces.
    private func configure() {
        switch orientation {
        case .frontLeft:
            // Shading runs front to back, so the lit end is the left-hand one.
            body.startPoint = CGPoint(x: 0, y: 0.5)
            body.endPoint = CGPoint(x: 1, y: 0.5)
            body.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
            label.alignmentMode = .center
            // Accidentals stand proud and cast forwards; naturals sit in the
            // keybed and shadow their neighbour across the pitch axis.
            body.shadowOffset = note.isBlack ? CGSize(width: -3, height: 0)
                                             : CGSize(width: 0, height: 1.5)
        case .frontBottom:
            body.startPoint = CGPoint(x: 0.5, y: 1)
            body.endPoint = CGPoint(x: 0.5, y: 0)
            body.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            label.alignmentMode = .center
            body.shadowOffset = note.isBlack ? CGSize(width: 0, height: 3)
                                             : CGSize(width: 1.5, height: 0)
        }

        if note.isBlack {
            body.shadowOpacity = 0.5
            body.shadowRadius = 4
            bevel.backgroundColor = Theme.accidentalBevel.cgColor
        } else {
            body.shadowOpacity = 0.3
            body.shadowRadius = 2.5
            bevel.backgroundColor = Theme.naturalBevel.cgColor
        }

        // Every natural is named; accidentals are too narrow to letter in a
        // script face without it turning to squiggle.
        label.isHidden = note.isBlack
        label.string = note.name

        applyColors(animated: false)
    }

    // MARK: - Geometry

    /// Called after `frame` changes. Sublayer geometry is never animated.
    func updateGeometry(displayScale: CGFloat) {
        // Naturals are inset along the pitch axis so the keybed shows through as
        // the seam between neighbours. Accidentals already stand clear.
        let inset: CGFloat = note.isBlack ? 0 : 1
        let hairline = 2 / max(displayScale, 1)

        switch orientation {
        case .frontLeft:
            body.frame = bounds.insetBy(dx: 0, dy: inset)
            body.cornerRadius = cornerRadius(across: bounds.height)
        case .frontBottom:
            body.frame = bounds.insetBy(dx: inset, dy: 0)
            body.cornerRadius = cornerRadius(across: bounds.width)
        }
        body.contentsScale = displayScale
        body.shadowPath = CGPath(roundedRect: body.bounds,
                                 cornerWidth: body.cornerRadius,
                                 cornerHeight: body.cornerRadius,
                                 transform: nil)

        // Start the bevel past the rounded corner so it does not float free of
        // the key's front edge.
        let bevelInset = body.cornerRadius * 0.7
        switch orientation {
        case .frontLeft:
            bevel.frame = CGRect(x: body.frame.minX + bevelInset,
                                 y: body.frame.minY,
                                 width: max(0, body.frame.width - bevelInset),
                                 height: hairline)
        case .frontBottom:
            bevel.frame = CGRect(x: body.frame.minX,
                                 y: body.frame.minY,
                                 width: hairline,
                                 height: max(0, body.frame.height - bevelInset))
        }
        bevel.contentsScale = displayScale

        let across = orientation == .frontLeft ? bounds.height : bounds.width
        let fontSize = max(10, min(15, across * 0.32))
        label.fontSize = fontSize
        label.contentsScale = displayScale
        let height = fontSize * 1.3

        switch orientation {
        case .frontLeft:
            // The instrument is turned a quarter turn clockwise, so its
            // lettering turns with it: the name reads down the screen, set
            // across the key's thickness rather than along its length, and
            // sits near the front edge, which is the left-hand end.
            let margin = max(10, bounds.width * 0.03)
            label.transform = CATransform3DIdentity
            label.bounds = CGRect(x: 0, y: 0, width: bounds.height, height: height)
            label.position = CGPoint(x: margin + height / 2, y: bounds.height / 2)
            label.transform = CATransform3DMakeRotation(.pi / 2, 0, 0, 1)
        case .frontBottom:
            // Near the front edge of the key, which is the bottom.
            let margin = max(10, bounds.height * 0.03)
            label.transform = CATransform3DIdentity
            label.frame = CGRect(x: 0,
                                 y: bounds.height - height - margin,
                                 width: bounds.width,
                                 height: height)
        }
    }

    private func cornerRadius(across extent: CGFloat) -> CGFloat {
        note.isBlack ? min(5, extent * 0.18) : min(7, extent * 0.14)
    }

    // MARK: - Appearance

    private func applyColors(animated: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        if animated {
            CATransaction.setAnimationDuration(Self.releaseDuration)
        }
        body.colors = currentGradient
        label.foregroundColor = currentLabelColor.cgColor
        bevel.opacity = isPressed ? 0.35 : 1
        CATransaction.commit()
    }

    /// The Cs stay the strongest so they still act as landmarks; every other
    /// natural is held back a shade.
    private var currentLabelColor: UIColor {
        switch (note.pitchClass == 0, isPressed) {
        case (true, false):  return Theme.keyLabel
        case (true, true):   return Theme.keyLabelPressed
        case (false, false): return Theme.keyLabelSecondary
        case (false, true):  return Theme.keyLabelSecondaryPressed
        }
    }

    private var currentGradient: [CGColor] {
        switch (note.isBlack, isPressed) {
        case (false, false): return Theme.whiteKey
        case (false, true):  return Theme.whiteKeyPressed
        case (true, false):  return Theme.blackKey
        case (true, true):   return Theme.blackKeyPressed
        }
    }
}

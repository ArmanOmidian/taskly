import SwiftUI
import CoreText

/// Plus Jakarta Sans (SIL Open Font License, see Fonts/OFL.txt).
enum FontLoader {
    static let files = [
        "PlusJakartaSans-Regular",
        "PlusJakartaSans-Medium",
        "PlusJakartaSans-SemiBold",
        "PlusJakartaSans-Bold",
    ]

    static func register() {
        for name in files {
            // Installed app: Contents/Resources/Fonts. Running from Xcode: the package resource bundle.
            let url = Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                ?? Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
            if let url {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}

extension Font {
    /// The app's text font. Use `.jakarta(13)` or `.jakarta(13, .semibold)`.
    static func jakarta(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "PlusJakartaSans-Bold"
        case .semibold: name = "PlusJakartaSans-SemiBold"
        case .medium: name = "PlusJakartaSans-Medium"
        default: name = "PlusJakartaSans-Regular"
        }
        return .custom(name, size: size)
    }
}

/// Що входить у збірку. Магазин - окремий дослідний стенд, у збірку для App Store він не потрапляє.
enum Build {
    #if DEBUG
    static let shop = true
    #else
    static let shop = false
    #endif
}

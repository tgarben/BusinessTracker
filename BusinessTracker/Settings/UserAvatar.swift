import SwiftUI

/// The account-holder's avatar — their uploaded photo, or an indigo-gradient
/// circle with their initials as a fallback. Distinct from `ClientAvatar`
/// (teal) so the user's own identity reads differently from a client's.
///
/// Backed by the `user_avatar` `@AppStorage`/iCloud key. Used in the Settings
/// profile header and onboarding.
struct UserAvatar: View {
    let imageData: Data?
    let name: String
    var size: CGFloat = 76

    private var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }
        let words = trimmed.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(trimmed.prefix(2)).uppercased()
    }

    var body: some View {
        Group {
            if let data = imageData, !data.isEmpty, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(.indigo.gradient)
                    Text(initials)
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// The label for the top-left profile/Settings toolbar button on every tab:
/// the user's avatar when they've set one, otherwise the `person.fill` glyph.
struct ProfileToolbarLabel: View {
    @AppStorage("user_avatar") private var avatarData: Data = Data()

    var body: some View {
        if !avatarData.isEmpty, let image = UIImage(data: avatarData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.quaternary, lineWidth: 0.5))
        } else {
            Image(systemName: "person.fill")
        }
    }
}

/// Helpers for preparing a picked photo for storage as the user avatar.
///
/// Avatars sync via `NSUbiquitousKeyValueStore` (see `CloudKeyValueSync`),
/// which has a small per-store quota, so we downscale and JPEG-compress the
/// picked image to a thumbnail before persisting it.
enum UserAvatarImage {
    /// Downscale so the longest edge is at most `maxDimension`, then JPEG-encode.
    /// Returns nil if the data isn't a decodable image.
    static func processed(_ data: Data, maxDimension: CGFloat = 256, quality: CGFloat = 0.7) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    /// Like `processed`, but for a business logo: a larger max edge and **PNG**
    /// output so transparency is preserved (logos sit on the white invoice header).
    static func processedLogo(_ data: Data, maxDimension: CGFloat = 480) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false   // preserve transparency
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.pngData()
    }
}

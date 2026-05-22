import UIKit

extension UIImage {
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        guard size.width > 0, size.height > 0 else {
            return self
        }

        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else {
            return self
        }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    func preparedForAIIntake(maxDimension: CGFloat = 1280) -> UIImage {
        resized(toMaxDimension: maxDimension)
    }

    func preparedForAppStorage(maxDimension: CGFloat = 900) -> UIImage {
        resized(toMaxDimension: maxDimension)
    }
}

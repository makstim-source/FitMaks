import Foundation
import UIKit
import CryptoKit

// MARK: - Image Cache Keys

extension GeminiService {
    func foodImageCacheKey(images: [UIImage]) -> String? {
        let fingerprints = images.compactMap { perceptualFingerprint(for: $0) }

        guard !fingerprints.isEmpty else {
            return nil
        }

        let combined = fingerprints.joined(separator: "|")

        return SHA256.hash(data: Data(combined.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    func normalizedFoodTextCacheKey(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

// MARK: - Perceptual Fingerprinting

extension GeminiService {
    private func perceptualFingerprint(for image: UIImage) -> String? {
        let size = CGSize(width: 16, height: 16)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }

        guard let cgImage = resized.cgImage else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var brightness: [Double] = []
        brightness.reserveCapacity(width * height)

        for pixel in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let red = Double(pixels[pixel])
            let green = Double(pixels[pixel + 1])
            let blue = Double(pixels[pixel + 2])
            brightness.append((red * 0.299) + (green * 0.587) + (blue * 0.114))
        }

        guard !brightness.isEmpty else {
            return nil
        }

        let average = brightness.reduce(0, +) / Double(brightness.count)
        return brightness.map { $0 >= average ? "1" : "0" }.joined()
    }
}

// MARK: - LRU Cache Operations

extension GeminiService {
    func cachedFoodImageEstimate(for key: String) -> FoodResult? {
        foodCacheQueue.sync {
            foodImageEstimateCache[key]
        }
    }

    func cacheFoodImageEstimate(_ result: FoodResult, for key: String) {
        foodCacheQueue.async {
            if self.foodImageEstimateCache[key] == nil {
                self.foodImageEstimateKeys.append(key)
            }
            self.foodImageEstimateCache[key] = result
            while self.foodImageEstimateCache.count > self.maxCacheSize, let oldest = self.foodImageEstimateKeys.first {
                self.foodImageEstimateKeys.removeFirst()
                self.foodImageEstimateCache.removeValue(forKey: oldest)
            }
        }
    }

    func cachedFoodImageItems(for key: String) -> [FoodResult]? {
        foodCacheQueue.sync {
            foodImageItemsCache[key]
        }
    }

    func cacheFoodImageItems(_ result: [FoodResult], for key: String) {
        foodCacheQueue.async {
            if self.foodImageItemsCache[key] == nil {
                self.foodImageItemsKeys.append(key)
            }
            self.foodImageItemsCache[key] = result
            while self.foodImageItemsCache.count > self.maxCacheSize, let oldest = self.foodImageItemsKeys.first {
                self.foodImageItemsKeys.removeFirst()
                self.foodImageItemsCache.removeValue(forKey: oldest)
            }
        }
    }

    func cachedFoodTextEstimate(for key: String) -> FoodResult? {
        foodCacheQueue.sync {
            foodTextEstimateCache[key]
        }
    }

    func cacheFoodTextEstimate(_ result: FoodResult, for key: String) {
        foodCacheQueue.async {
            if self.foodTextEstimateCache[key] == nil {
                self.foodTextEstimateKeys.append(key)
            }
            self.foodTextEstimateCache[key] = result
            while self.foodTextEstimateCache.count > self.maxCacheSize, let oldest = self.foodTextEstimateKeys.first {
                self.foodTextEstimateKeys.removeFirst()
                self.foodTextEstimateCache.removeValue(forKey: oldest)
            }
        }
    }
}

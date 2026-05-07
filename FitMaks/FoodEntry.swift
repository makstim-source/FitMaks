import Foundation
import SwiftData
import UIKit

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024
    }

    func image(for key: String, data: Data) -> UIImage? {
        let nsKey = key as NSString
        if let cached = cache.object(forKey: nsKey) { return cached }
        guard let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: nsKey, cost: data.count)
        return image
    }

    func invalidate(for key: String) {
        cache.removeObject(forKey: key as NSString)
    }
}

@Model
final class FoodEntry {
    var id: UUID = UUID()
    var createdAt: Date?

    @Attribute(.externalStorage)
    var imageData: Data = Data()

    var name: String = ""
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var ingredients: String = ""
    var date: Date = Date()
    var location: String = "fridge"

    init(
        image: UIImage,
        name: String,
        calories: Double,
        protein: Double,
        carbs: Double = 0,
        fat: Double = 0,
        ingredients: String,
        date: Date,
        location: String = "fridge"
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.imageData = image.preparedForAppStorage().jpegData(compressionQuality: 0.72) ?? Data()
        self.name = name.isEmpty ? "Food" : name
        self.calories = max(0, calories)
        self.protein = max(0, protein)
        self.carbs = max(0, carbs)
        self.fat = max(0, fat)
        self.ingredients = ingredients
        self.date = date
        self.location = location
    }

    var uiImage: UIImage? {
        ImageCache.shared.image(for: id.uuidString, data: imageData)
    }
}

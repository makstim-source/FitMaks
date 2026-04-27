import Foundation
import SwiftData
import UIKit

@Model
final class FoodEntry {
    var id: UUID
    var createdAt: Date?

    @Attribute(.externalStorage)
    var imageData: Data

    var name: String
    var calories: Double
    var protein: Double
    var ingredients: String
    var date: Date
    var location: String // "fridge" или "meal"
    
    init(image: UIImage, name: String, calories: Double, protein: Double, ingredients: String, date: Date, location: String = "fridge") {
        self.id = UUID()
        self.createdAt = Date()
        self.imageData = image.preparedForAppStorage().jpegData(compressionQuality: 0.72) ?? Data()
        self.name = name.isEmpty ? "Food" : name
        self.calories = max(0, calories)
        self.protein = max(0, protein)
        self.ingredients = ingredients
        self.date = date
        self.location = location
    }
    
    var uiImage: UIImage? {
        UIImage(data: imageData)
    }
}

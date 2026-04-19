import Foundation
import SwiftData
import UIKit

@Model
final class FoodEntry {
    var id: UUID
    var imageData: Data
    var name: String
    var calories: Double
    var protein: Double
    var ingredients: String
    var date: Date
    var location: String // "fridge" или "meal"
    
    init(image: UIImage, name: String, calories: Double, protein: Double, ingredients: String, date: Date, location: String = "fridge") {
        self.id = UUID()
        self.imageData = image.jpegData(compressionQuality: 0.5) ?? Data()
        self.name = name
        self.calories = calories
        self.protein = protein
        self.ingredients = ingredients
        self.date = date
        self.location = location
    }
    
    var uiImage: UIImage? {
        UIImage(data: imageData)
    }
}

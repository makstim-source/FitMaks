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
    
    init(image: UIImage, name: String, calories: Double, protein: Double, ingredients: String, date: Date) {
        self.id = UUID()
        self.imageData = image.jpegData(compressionQuality: 0.5) ?? Data()
        self.name = name
        self.calories = calories
        self.protein = protein
        self.ingredients = ingredients
        self.date = date
    }
    
    var uiImage: UIImage? {
        UIImage(data: imageData)
    }
}

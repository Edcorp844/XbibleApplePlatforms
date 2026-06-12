
import Foundation
import SwiftData

@Model
class StudyPageState{
    var timestamp: Date
    var moduleName: String
    var selectedBook: String
    var chapter: Int 

    init(timestamp: Date, moduleName: String, selectedBook: String, chapter: Int){
         self.timestamp = timestamp
         self.moduleName = moduleName
         self.selectedBook = selectedBook
         self.chapter = chapter
    }
}
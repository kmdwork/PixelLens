import SwiftUI

@main
struct PixelLensApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("PixelLens") {
            ContentView(model: model)
        }
        .windowResizability(.contentSize)
    }
}

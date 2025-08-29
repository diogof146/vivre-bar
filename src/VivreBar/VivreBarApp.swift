import AppKit

class VivreBarApp: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var frames: [NSImage] = []
    var currentFrameIndex = 0
    var animationTimer: Timer?

    func applicationDidFinishLaunching(_: Notification) {
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            if let bundle = Bundle.main.path(forResource: "vivre-bar_VivreBar", ofType: "bundle"),

               let resourceBundle = Bundle(path: bundle),

               let gifPath = resourceBundle.path(forResource: "vivre", ofType: "gif")
            {
                let gifURL = URL(fileURLWithPath: gifPath)

                if let imageSource = CGImageSourceCreateWithURL(gifURL as CFURL, nil) {
                    let frameCount = CGImageSourceGetCount(imageSource)

                    for i in 0 ..< frameCount {
                        if let CGImage = CGImageSourceCreateImageAtIndex(imageSource, i, nil) {
                            let nsImage = NSImage(
                                cgImage: CGImage, size: NSSize(width: 22, height: 22)
                            )
                            frames.append(nsImage)
                        }
                    }

                    print("Loaded \(frames.count)")

                    button.image = frames[0]
                }

                if !frames.isEmpty {
                    button.image = frames[0]

                    // Start animation timer
                    animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) {
                        _ in
                        self.currentFrameIndex = (self.currentFrameIndex + 1) % self.frames.count
                        self.statusItem.button?.image = self.frames[self.currentFrameIndex]
                    }
                }

            } else {
                // Just a fallback in case loading fails
                button.title = "🏴‍☠️"
            }
        }

        // Hide dock icon (menu bar only app)
        NSApp.setActivationPolicy(.accessory)
    }
}

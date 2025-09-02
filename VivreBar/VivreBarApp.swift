import AppKit

class VivreBarApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var frames: [NSImage] = []
    private var currentFrameIndex = 0
    private let ciContext: CIContext
    private let settingsMenu = SettingsMenu()
    private var animationTimer: Timer?

    enum ColorMode {
        case original
        case system
        case custom(NSColor)
    }

    override init() {
        ciContext = CIContext()
        super.init()
    }

    private func processFrame(_ cgImage: CGImage) -> NSImage {
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: 23, height: 23))

        switch getColorMode() {
        case .original:
            return nsImage

        case .system:
            nsImage.isTemplate = true
            return nsImage

        case let .custom(customColor):
            // Converting to CIImage
            let ciImage = CIImage(cgImage: cgImage)
            // Color replacement filter
            let processedCIImage = applyColorReplacement(to: ciImage, with: customColor)

            // Converting back to CGImage, then NSImage
            guard
                let outputCGImage = ciContext.createCGImage(
                    processedCIImage, from: processedCIImage.extent
                )
            else {
                // Fallback to original
                return nsImage
            }
            return NSImage(cgImage: outputCGImage, size: NSSize(width: 23, height: 23))
        }
    }

    private func applyColorReplacement(to image: CIImage, with color: NSColor) -> CIImage {
        // Converting NSColor to CIColor
        guard let ciColor = CIColor(color: color) else {
            return image  // Fallback
        }

        // Extract the alpha channel to use as mask
        let alphaChannel = image.applyingFilter(
            "CIColorMatrix",
            parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1),  // Red = alpha
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),  // Green = alpha
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1),  // Blue = alpha
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),  // Alpha = alpha
            ]
        )

        // Creating a solid color image the same size as the input
        let colorImage = CIImage(color: ciColor).cropped(to: image.extent)

        // Apply the mask
        let maskedColor = colorImage.applyingFilter(
            "CIBlendWithMask", parameters: [kCIInputMaskImageKey: alphaChannel]
        )

        return maskedColor
    }

    private func loadGif(_ statusItem: NSStatusItem) {
        if let button = statusItem.button {
            if let gifPath = Bundle.main.path(forResource: "nika", ofType: "gif") {
                let gifURL = URL(fileURLWithPath: gifPath)

                if let imageSource = CGImageSourceCreateWithURL(gifURL as CFURL, nil) {
                    let frameCount = CGImageSourceGetCount(imageSource)

                    for i in 0..<frameCount {
                        if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, i, nil) {
                            frames.append(processFrame(cgImage))
                        }
                    }

                    if !frames.isEmpty {
                        button.image = frames[0]
                    }

                    // Start animation timer
                    animationTimer = Timer.scheduledTimer(
                        withTimeInterval: getAnimationSpeed(), repeats: true
                    ) {
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
    }

    // Get the color mode from User defaults
    private func getColorMode() -> ColorMode {
        // todo
        return .system
    }

    // Get the animation speed from User Defaults
    private func getAnimationSpeed() -> TimeInterval {
        let speed = UserDefaults.standard.double(forKey: "animationSpeed")
        return speed == 0 ? 0.05 : speed  // Default to 0.05 if not set
    }

    // Opens the menu on click
    @objc private func statusItemClicked() {
        settingsMenu.show(from: statusItem)
    }

    // Restarts the timer for the animation speed
    private func restartTimer() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: getAnimationSpeed(), repeats: true)
        { _ in
            self.currentFrameIndex = (self.currentFrameIndex + 1) % self.frames.count
            self.statusItem.button?.image = self.frames[self.currentFrameIndex]
        }
    }

    func applicationDidFinishLaunching(_: Notification) {
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        loadGif(statusItem)

        // Hide dock icon (menu bar only app)
        NSApp.setActivationPolicy(.accessory)

        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)

        settingsMenu.onSpeedChanged = { [weak self] _ in
            self?.restartTimer()
        }
    }
}

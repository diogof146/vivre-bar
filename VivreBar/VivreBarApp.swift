import AppKit

enum ColorMode {
    case original
    case system
    case tint(NSColor)
    case fill(NSColor)
}

enum VisualEffect: String, CaseIterable {
    case none
    case glow
    case blur
    case sepia
    case pixelated
    case vignette
    case pinch
    case bulge
    case twirl
    case crystallize
    var displayName: String {
        switch self {
        case .none: return "No Effect"
        case .glow: return "Glow"
        case .blur: return "Blur"
        case .sepia: return "Sepia"
        case .pixelated: return "Pixelated"
        case .vignette: return "Vignette"
        case .pinch: return "Pinch"
        case .bulge: return "Bulge"
        case .twirl: return "Twirl"
        case .crystallize: return "Crystallize"
        }
    }
}

class VivreBarApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var frames: [NSImage] = []
    private var currentFrameIndex = 0
    private let ciContext: CIContext
    private let settingsMenu = SettingsMenu()
    private var animationTimer: Timer?

    override init() {
        ciContext = CIContext()
        super.init()
    }

    private func processFrame(_ cgImage: CGImage) -> NSImage {
        // Read UserDefaults once and calculate size
        let width = UserDefaults.standard.double(forKey: "iconWidth")
        let height = UserDefaults.standard.double(forKey: "iconHeight")
        let size = NSSize(width: width == 0 ? 22 : width, height: height == 0 ? 22 : height)

        var nsImage = NSImage(cgImage: cgImage, size: size)

        switch getColorMode() {
        case .original:
            break

        case .system:
            nsImage.isTemplate = true

        case let .fill(customColor):
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
                break
            }
            nsImage = NSImage(cgImage: outputCGImage, size: size)

        case let .tint(customColor):
            // Convert to CIImage
            let ciImage = CIImage(cgImage: cgImage)
            // Apply color tint using CIColorMonochrome filter
            let tintedImage = ciImage.applyingFilter(
                "CIColorMonochrome",
                parameters: [
                    kCIInputColorKey: CIColor(color: customColor) ?? CIColor.white,
                    kCIInputIntensityKey: 0.7,  // for tint strength
                ]
            )
            // Convert back to NSImage
            guard let outputCGImage = ciContext.createCGImage(tintedImage, from: tintedImage.extent)
            else {
                break
            }
            nsImage = NSImage(cgImage: outputCGImage, size: size)
        }
        let finalImage = applyVisualEffect(to: nsImage, cgImage: cgImage, size: size)
        return finalImage
    }

    private func applyVisualEffect(to processedImage: NSImage, cgImage _: CGImage, size: NSSize)
        -> NSImage
    {
        let effectString = UserDefaults.standard.string(forKey: "visualEffect") ?? "none"
        let currentEffect = VisualEffect(rawValue: effectString) ?? .none

        switch currentEffect {
        case .none:
            return processedImage

        case .glow:
            // Convert NSImage back to CIImage for effect processing
            guard let ciImage = CIImage(data: processedImage.tiffRepresentation!) else {
                return processedImage
            }

            // Create a larger blur for the aura
            let aura = ciImage.applyingFilter(
                "CIGaussianBlur",
                parameters: [
                    kCIInputRadiusKey: 8.0  // Aura spread distance
                ]
            )

            // Make the aura more vibrant/colorful
            let coloredAura = aura.applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 2.0,  // More saturated colors
                    kCIInputBrightnessKey: 0.3,  // Slightly brighter
                ]
            )

            // Extend the canvas to fit the aura
            let extendedSize = CGRect(
                x: ciImage.extent.minX - 15,
                y: ciImage.extent.minY - 15,
                width: ciImage.extent.width + 30,
                height: ciImage.extent.height + 30
            )

            // Composite: aura behind, original on top
            let finalImage = coloredAura.applyingFilter(
                "CISourceOverCompositing",
                parameters: [
                    kCIInputBackgroundImageKey: ciImage
                ]
            ).cropped(to: extendedSize)

            // Convert back to NSImage
            guard let outputCGImage = ciContext.createCGImage(finalImage, from: finalImage.extent)
            else {
                return processedImage
            }
            return NSImage(cgImage: outputCGImage, size: size)

        case .blur:
            guard let ciImage = CIImage(data: processedImage.tiffRepresentation!) else {
                return processedImage
            }
            let blurred = ciImage.applyingFilter(
                "CIGaussianBlur",
                parameters: [
                    kCIInputRadiusKey: 10.0
                ]
            )
            guard let outputCGImage = ciContext.createCGImage(blurred, from: blurred.extent) else {
                return processedImage
            }
            return NSImage(cgImage: outputCGImage, size: size)

        case .sepia:
            guard let ciImage = CIImage(data: processedImage.tiffRepresentation!) else {
                return processedImage
            }
            let sepia = ciImage.applyingFilter(
                "CISepiaTone",
                parameters: [
                    kCIInputIntensityKey: 0.8
                ]
            )
            guard let outputCGImage = ciContext.createCGImage(sepia, from: sepia.extent) else {
                return processedImage
            }
            return NSImage(cgImage: outputCGImage, size: size)

        case .pixelated:
            guard let ciImage = CIImage(data: processedImage.tiffRepresentation!) else {
                return processedImage
            }
            let pixelated = ciImage.applyingFilter(
                "CIPixellate",
                parameters: [
                    kCIInputScaleKey: 8.0  // Pixel size
                ]
            )
            guard let outputCGImage = ciContext.createCGImage(pixelated, from: pixelated.extent)
            else {
                return processedImage
            }
            return NSImage(cgImage: outputCGImage, size: size)

        case .vignette:
            guard let ciImage = CIImage(data: processedImage.tiffRepresentation!) else {
                return processedImage
            }
            let vignette = ciImage.applyingFilter(
                "CIVignette",
                parameters: [
                    kCIInputRadiusKey: 1.5,
                    kCIInputIntensityKey: 1.0,
                ]
            )
            guard let outputCGImage = ciContext.createCGImage(vignette, from: vignette.extent)
            else {
                return processedImage
            }
            return NSImage(cgImage: outputCGImage, size: size)

        case .pinch:
            guard let ciImage = CIImage(data: processedImage.tiffRepresentation!) else {
                return processedImage
            }
            let pinched = ciImage.applyingFilter(
                "CIPinchDistortion",
                parameters: [
                    kCIInputRadiusKey: 150.0,
                    kCIInputScaleKey: 0.5,
                    kCIInputCenterKey: CIVector(x: ciImage.extent.midX, y: ciImage.extent.midY),
                ]
            )
            guard let outputCGImage = ciContext.createCGImage(pinched, from: pinched.extent) else {
                return processedImage
            }
            return NSImage(cgImage: outputCGImage, size: size)

        case .bulge:
            guard let ciImage = CIImage(data: processedImage.tiffRepresentation!) else {
                return processedImage
            }
            let bulged = ciImage.applyingFilter(
                "CIBulgeDistortion",
                parameters: [
                    kCIInputRadiusKey: 150.0,
                    kCIInputScaleKey: 0.5,
                    kCIInputCenterKey: CIVector(x: ciImage.extent.midX, y: ciImage.extent.midY),
                ]
            )
            guard let outputCGImage = ciContext.createCGImage(bulged, from: bulged.extent) else {
                return processedImage
            }
            return NSImage(cgImage: outputCGImage, size: size)

        case .twirl:
            guard let ciImage = CIImage(data: processedImage.tiffRepresentation!) else {
                return processedImage
            }
            let twirled = ciImage.applyingFilter(
                "CITwirlDistortion",
                parameters: [
                    kCIInputRadiusKey: 150.0,
                    kCIInputAngleKey: 3.14,
                    kCIInputCenterKey: CIVector(x: ciImage.extent.midX, y: ciImage.extent.midY),
                ]
            )
            guard let outputCGImage = ciContext.createCGImage(twirled, from: twirled.extent) else {
                return processedImage
            }
            return NSImage(cgImage: outputCGImage, size: size)

        case .crystallize:
            guard let ciImage = CIImage(data: processedImage.tiffRepresentation!) else {
                return processedImage
            }
            let crystalized = ciImage.applyingFilter(
                "CICrystallize",
                parameters: [
                    kCIInputRadiusKey: 20.0,
                    kCIInputCenterKey: CIVector(x: ciImage.extent.midX, y: ciImage.extent.midY),
                ]
            )
            guard let outputCGImage = ciContext.createCGImage(crystalized, from: crystalized.extent)
            else {
                return processedImage
            }
            return NSImage(cgImage: outputCGImage, size: size)
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
            if let gifURL = GifManager.shared.currentGifURL {
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
        let mode = UserDefaults.standard.string(forKey: "colorMode") ?? "system"

        switch mode {
        case "original":
            return .original
        case "system":
            return .system
        case "tint":
            if let colorData = UserDefaults.standard.data(forKey: "tintColor"),
                let color = try? NSKeyedUnarchiver.unarchivedObject(
                    ofClass: NSColor.self, from: colorData
                )
            {
                return .tint(color)
            }
            return .system  // fallback
        case "fill":
            if let colorData = UserDefaults.standard.data(forKey: "fillColor"),
                let color = try? NSKeyedUnarchiver.unarchivedObject(
                    ofClass: NSColor.self, from: colorData
                )
            {
                return .fill(color)
            }
            return .system  // fallback
        default:
            return .system
        }
    }

    // Get the animation speed from User Defaults
    private func getAnimationSpeed() -> TimeInterval {
        return UserDefaults.standard.double(forKey: "animationSpeed")
    }

    // Opens the menu on click
    @objc private func statusItemClicked() {
        settingsMenu.show(from: statusItem)
    }

    // Restarts the timer for the animation speed
    private func restartTimer() {
        animationTimer?.invalidate()

        let interval = getAnimationSpeed()

        if interval == 0 {
            return
        }

        animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.currentFrameIndex = (self.currentFrameIndex + 1) % self.frames.count
            self.statusItem.button?.image = self.frames[self.currentFrameIndex]
        }
    }

    private func restartAnimation() {
        // Clear existing frames and reload with new color processing
        animationTimer?.invalidate()
        frames.removeAll()
        currentFrameIndex = 0
        loadGif(statusItem)
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

        settingsMenu.onColorModeChanged = { [weak self] in
            self?.restartAnimation()
        }

        settingsMenu.onSizeChanged = { [weak self] in
            self?.restartAnimation()
        }

        settingsMenu.onGifChanged = { [weak self] in
            self?.restartAnimation()
        }

        settingsMenu.onEffectChanged = { [weak self] in
            self?.restartAnimation()
        }
    }
}

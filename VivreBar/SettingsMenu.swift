import AppKit

class SettingsMenu: NSObject {
    private var popover: NSPopover?

    var onSpeedChanged: ((TimeInterval) -> Void)?
    var onColorModeChanged: (() -> Void)?
    var onSizeChanged: (() -> Void)?
    var onGifChanged: (() -> Void)?
    var onEffectChanged: (() -> Void)?

    private let colorMode = "colorMode"
    private let tintColor = "tintColor"
    private let fillColor = "fillColor"

    private var originalRadio: NSButton!
    private var systemRadio: NSButton!
    private var tintRadio: NSButton!
    private var fillRadio: NSButton!
    private var tintColorWell: NSColorWell!
    private var fillColorWell: NSColorWell!

    private let iconWidth = "iconWidth"
    private let iconHeight = "iconHeight"
    private let aspectRatioLocked = "aspectRatioLocked"

    private var widthField: NSTextField!
    private var heightField: NSTextField!
    private var widthStepper: NSStepper!
    private var heightStepper: NSStepper!
    private var aspectLockCheckbox: NSButton!

    private var gifDropdown: NSPopUpButton!

    private var effectsDropdown: NSPopUpButton!

    func show(from statusItem: NSStatusItem) {
        // Creating the popover
        if popover == nil {
            createPopover()
        }

        if let button = statusItem.button {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func createPopover() {
        popover = NSPopover()
        popover?.behavior = .transient

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 380))
        let viewController = NSViewController()
        viewController.view = contentView
        popover?.contentViewController = viewController

        // Animation speed slider
        let speedSlider = NSSlider(
            value: 1, minValue: 0,
            maxValue: 2, target: self,
            action: #selector(speedChanged(_:))
        )
        // Load the actual speed multiplier for the slider
        let currentInterval = UserDefaults.standard.double(forKey: "animationSpeed")
        if currentInterval > 0 {
            speedSlider.doubleValue = 0.05 / currentInterval  // Convert interval back to multiplier
        }
        let speedLabel = NSTextField(labelWithString: "Animation Speed:")
        speedSlider.numberOfTickMarks = 5
        contentView.addSubview(speedLabel)
        contentView.addSubview(speedSlider)
        speedLabel.frame = NSRect(x: 10, y: 55, width: 180, height: 20)
        speedSlider.frame = NSRect(x: 10, y: 30, width: 180, height: 20)
        speedSlider.isContinuous = true
        DispatchQueue.main.async {
            self.sliderTics(to: contentView, slider: speedSlider)
        }

        // Radio Buttons
        let colorLabel = NSTextField(labelWithString: "Color Mode:")
        colorLabel.frame = NSRect(x: 10, y: 290, width: 80, height: 20)
        contentView.addSubview(colorLabel)

        originalRadio = createRadioButton(title: "Original")
        systemRadio = createRadioButton(title: "System")
        tintRadio = createRadioButton(title: "Tint:")
        fillRadio = createRadioButton(title: "Fill:")
        contentView.addSubview(originalRadio)
        contentView.addSubview(systemRadio)
        contentView.addSubview(tintRadio)
        contentView.addSubview(fillRadio)
        originalRadio.frame = NSRect(x: 10, y: 270, width: 80, height: 20)
        systemRadio.frame = NSRect(x: 10, y: 250, width: 80, height: 20)
        tintRadio.frame = NSRect(x: 10, y: 230, width: 50, height: 20)
        fillRadio.frame = NSRect(x: 10, y: 210, width: 50, height: 20)

        // Color Wells
        tintColorWell = NSColorWell()
        fillColorWell = NSColorWell()
        tintColorWell.target = self
        tintColorWell.action = #selector(colorWellChanged(_:))
        fillColorWell.target = self
        fillColorWell.action = #selector(colorWellChanged(_:))
        tintColorWell.frame = NSRect(x: 70, y: 230, width: 40, height: 20)
        fillColorWell.frame = NSRect(x: 70, y: 210, width: 40, height: 20)
        contentView.addSubview(tintColorWell)
        contentView.addSubview(fillColorWell)
        tintColorWell.isEnabled = false
        fillColorWell.isEnabled = false

        // Load the current state
        let savedMode = UserDefaults.standard.string(forKey: colorMode)
        switch savedMode {
        case "original": colorModeChanged(originalRadio)
        case "system": colorModeChanged(systemRadio)
        case "tint": colorModeChanged(tintRadio)
        case "fill": colorModeChanged(fillRadio)
        default: colorModeChanged(originalRadio)
        }
        if let tintData = UserDefaults.standard.data(forKey: tintColor),
            let tintColor = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSColor.self, from: tintData
            )
        {
            tintColorWell.color = tintColor
        }

        if let fillData = UserDefaults.standard.data(forKey: fillColor),
            let fillColor = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSColor.self, from: fillData
            )
        {
            fillColorWell.color = fillColor
        }

        // Sizing
        // Size controls section
        let sizeLabel = NSTextField(labelWithString: "Icon Size:")

        // Create formatter for 16-40 range
        let sizeFormatter = NumberFormatter()
        sizeFormatter.minimum = 1
        sizeFormatter.maximum = 200
        sizeFormatter.numberStyle = .none

        // Width controls
        let widthLabel = NSTextField(labelWithString: "Width:")
        widthField = NSTextField()
        widthField.formatter = sizeFormatter
        widthStepper = NSStepper()
        widthStepper.minValue = 1
        widthStepper.maxValue = 200
        widthStepper.increment = 1

        // Height controls
        let heightLabel = NSTextField(labelWithString: "Height:")
        heightField = NSTextField()
        heightField.formatter = sizeFormatter
        heightStepper = NSStepper()
        heightStepper.minValue = 16
        heightStepper.maxValue = 40
        heightStepper.increment = 1

        // Aspect ratio checkbox
        aspectLockCheckbox = NSButton(
            checkboxWithTitle: "Aspect Ratio", target: self,
            action: #selector(aspectLockToggled(_:))
        )

        // Load saved values
        let savedWidth = UserDefaults.standard.double(forKey: iconWidth)
        let savedHeight = UserDefaults.standard.double(forKey: iconHeight)
        let width = savedWidth == 0 ? 22 : Int(savedWidth)
        let height = savedHeight == 0 ? 22 : Int(savedHeight)

        widthField.integerValue = width
        heightField.integerValue = height
        widthStepper.integerValue = width
        heightStepper.integerValue = height
        aspectLockCheckbox.state =
            UserDefaults.standard.bool(forKey: aspectRatioLocked) ? .on : .off

        // Set up targets and actions
        widthField.target = self
        widthField.action = #selector(sizeFieldChanged(_:))
        heightField.target = self
        heightField.action = #selector(sizeFieldChanged(_:))
        widthStepper.target = self
        widthStepper.action = #selector(sizeStepperChanged(_:))
        heightStepper.target = self
        heightStepper.action = #selector(sizeStepperChanged(_:))

        // Position controls
        sizeLabel.frame = NSRect(x: 10, y: 180, width: 100, height: 20)
        widthLabel.frame = NSRect(x: 10, y: 160, width: 50, height: 20)
        widthField.frame = NSRect(x: 65, y: 160, width: 40, height: 20)
        widthStepper.frame = NSRect(x: 110, y: 160, width: 20, height: 20)
        heightLabel.frame = NSRect(x: 10, y: 140, width: 50, height: 20)
        heightField.frame = NSRect(x: 65, y: 140, width: 40, height: 20)
        heightStepper.frame = NSRect(x: 110, y: 140, width: 20, height: 20)
        aspectLockCheckbox.frame = NSRect(x: 140, y: 150, width: 100, height: 20)

        // Add to content view
        contentView.addSubview(sizeLabel)
        contentView.addSubview(widthLabel)
        contentView.addSubview(widthField)
        contentView.addSubview(widthStepper)
        contentView.addSubview(heightLabel)
        contentView.addSubview(heightField)
        contentView.addSubview(heightStepper)
        contentView.addSubview(aspectLockCheckbox)

        // GIF Selection
        let gifLabel = NSTextField(labelWithString: "Choose GIF:")
        gifDropdown = NSPopUpButton()
        gifDropdown.target = self
        gifDropdown.action = #selector(gifSelectionChanged(_:))

        // Populate dropdown with available GIFs
        refreshGifDropdown()

        // Position the controls (adjust other positions as needed)
        gifLabel.frame = NSRect(x: 10, y: 350, width: 100, height: 20)
        gifDropdown.frame = NSRect(x: 10, y: 325, width: 180, height: 25)

        contentView.addSubview(gifLabel)
        contentView.addSubview(gifDropdown)

        // Visual Effects
        let effectLabel = NSTextField(labelWithString: "Effect:")
        effectsDropdown = NSPopUpButton()
        effectsDropdown.target = self
        effectsDropdown.action = #selector(effectChanged(_:))

        // Populate dropdown
        let effectTitles = VisualEffect.allCases.map { $0.displayName }
        effectsDropdown.addItems(withTitles: effectTitles)

        // Set current selection
        let currentEffect = UserDefaults.standard.string(forKey: "visualEffect") ?? "none"
        if let effectIndex = VisualEffect.allCases.firstIndex(where: {
            $0.rawValue == currentEffect
        }) {
            effectsDropdown.selectItem(at: effectIndex)
        }

        // Position controls
        effectLabel.frame = NSRect(x: 10, y: 110, width: 100, height: 20)
        effectsDropdown.frame = NSRect(x: 10, y: 85, width: 180, height: 25)

        contentView.addSubview(effectLabel)
        contentView.addSubview(effectsDropdown)
    }

    private func refreshGifDropdown() {
        gifDropdown.removeAllItems()

        let availableGifs = GifManager.shared.availableGifs()
        let currentURL = GifManager.shared.currentGifURL

        var selectedIndex = 0

        for (index, gif) in availableGifs.enumerated() {
            let title = gif.displayName
            gifDropdown.addItem(withTitle: title)

            if gif.url == currentURL {
                selectedIndex = index
            }
        }

        gifDropdown.selectItem(at: selectedIndex)

        // Add "Browse..." at the end
        gifDropdown.menu?.addItem(NSMenuItem.separator())
        let browseItem = NSMenuItem(
            title: "Browse for GIF...", action: #selector(browseForGif), keyEquivalent: ""
        )
        browseItem.target = self
        gifDropdown.menu?.addItem(browseItem)
    }

    // Generates tic labels
    private func sliderTics(to contentView: NSView, slider: NSSlider) {
        let midIndex = slider.numberOfTickMarks / 2
        let toShow = [0, midIndex, slider.numberOfTickMarks - 1]

        for i in toShow {
            let tickRect = slider.rectOfTickMark(at: i)
            let tickCenter = NSPoint(
                x: tickRect.midX + slider.frame.origin.x,
                y: slider.frame.origin.y - 15
            )

            let value =
                slider.minValue + (Double(i) / Double(slider.numberOfTickMarks - 1))
                * (slider.maxValue - slider.minValue)

            let label = NSTextField(labelWithString: String(format: "%.0fx", value))
            label.alignment = .center
            label.frame = NSRect(
                x: tickCenter.x - 15,
                y: tickCenter.y - 2,
                width: 30,
                height: 16
            )

            contentView.addSubview(label)
        }
    }

    private func createRadioButton(title: String) -> NSButton {
        let button = NSButton()
        button.setButtonType(.radio)
        button.title = title
        button.target = self
        button.action = #selector(colorModeChanged(_:))
        return button
    }

    private func saveSize() {
        UserDefaults.standard.set(Double(widthField.integerValue), forKey: iconWidth)
        UserDefaults.standard.set(Double(heightField.integerValue), forKey: iconHeight)
        onSizeChanged?()
    }

    @objc private func speedChanged(_ slider: NSSlider) {
        let speedMultiplier = slider.doubleValue
        if speedMultiplier == 0 {
            UserDefaults.standard.set(0, forKey: "animationSpeed")
            onSpeedChanged?(0)
            return
        }
        let timerInterval = 0.05 / speedMultiplier
        UserDefaults.standard.set(timerInterval, forKey: "animationSpeed")
        onSpeedChanged?(speedMultiplier)
    }

    @objc private func colorModeChanged(_ sender: NSButton) {
        // Deselect all radio buttons first
        originalRadio.state = .off
        systemRadio.state = .off
        tintRadio.state = .off
        fillRadio.state = .off

        // Select the clicked button
        sender.state = .on

        // Save to UserDefaults and enable/disable color wells
        if sender == originalRadio {
            UserDefaults.standard.set("original", forKey: colorMode)
            tintColorWell.isEnabled = false
            fillColorWell.isEnabled = false
        } else if sender == systemRadio {
            UserDefaults.standard.set("system", forKey: colorMode)
            tintColorWell.isEnabled = false
            fillColorWell.isEnabled = false
        } else if sender == tintRadio {
            UserDefaults.standard.set("tint", forKey: colorMode)
            tintColorWell.isEnabled = true
            fillColorWell.isEnabled = false
        } else if sender == fillRadio {
            UserDefaults.standard.set("fill", forKey: colorMode)
            tintColorWell.isEnabled = false
            fillColorWell.isEnabled = true
        }

        // Notify VivreBarApp that color mode changed
        onColorModeChanged?()
    }

    @objc private func colorWellChanged(_ sender: NSColorWell) {
        if sender == tintColorWell {
            // Save tint color to UserDefaults
            let colorData = try? NSKeyedArchiver.archivedData(
                withRootObject: sender.color, requiringSecureCoding: false
            )
            UserDefaults.standard.set(colorData, forKey: tintColor)
        } else if sender == fillColorWell {
            // Save fill color to UserDefaults
            let colorData = try? NSKeyedArchiver.archivedData(
                withRootObject: sender.color, requiringSecureCoding: false
            )
            UserDefaults.standard.set(colorData, forKey: fillColor)
        }
        onColorModeChanged?()
    }

    @objc private func sizeStepperChanged(_ sender: NSStepper) {
        // Sync field with stepper
        if sender == widthStepper {
            widthField.integerValue = sender.integerValue
            if aspectLockCheckbox.state == .on {
                heightField.integerValue = sender.integerValue
                heightStepper.integerValue = sender.integerValue
            }
        } else if sender == heightStepper {
            heightField.integerValue = sender.integerValue
            if aspectLockCheckbox.state == .on {
                widthField.integerValue = sender.integerValue
                widthStepper.integerValue = sender.integerValue
            }
        }
        saveSize()
    }

    @objc private func aspectLockToggled(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: aspectRatioLocked)

        if sender.state == .on {
            // When locking, make both dimensions match the height
            let currentHeight = heightField.integerValue
            widthField.integerValue = currentHeight
            widthStepper.integerValue = currentHeight
            saveSize()
        }
    }

    @objc private func sizeFieldChanged(_ sender: NSTextField) {
        // Sync stepper with field
        if sender == widthField {
            widthStepper.integerValue = sender.integerValue
            if aspectLockCheckbox.state == .on {
                // Lock aspect ratio
                heightField.integerValue = sender.integerValue
                heightStepper.integerValue = sender.integerValue
            }
        } else if sender == heightField {
            heightStepper.integerValue = sender.integerValue
            if aspectLockCheckbox.state == .on {
                // Lock aspect ratio
                widthField.integerValue = sender.integerValue
                widthStepper.integerValue = sender.integerValue
            }
        }
        saveSize()
    }

    @objc private func gifSelectionChanged(_ sender: NSPopUpButton) {
        let selectedIndex = sender.indexOfSelectedItem
        let availableGifs = GifManager.shared.availableGifs()

        guard selectedIndex >= 0, selectedIndex < availableGifs.count else { return }

        let selectedGif = availableGifs[selectedIndex]
        GifManager.shared.setCurrentGif(url: selectedGif.url)
        onGifChanged?()
    }

    @objc private func browseForGif() {
        GifManager.shared.selectUserGif { [weak self] url in
            DispatchQueue.main.async {
                if url != nil {
                    // Refresh dropdown to show the new GIF
                    self?.refreshGifDropdown()
                    self?.onGifChanged?()
                }
            }
        }
    }

    @objc private func effectChanged(_ sender: NSPopUpButton) {
        let selectedIndex = sender.indexOfSelectedItem
        guard selectedIndex >= 0, selectedIndex < VisualEffect.allCases.count else { return }

        let selectedEffect = VisualEffect.allCases[selectedIndex]
        UserDefaults.standard.set(selectedEffect.rawValue, forKey: "visualEffect")
        onEffectChanged?()
    }
}

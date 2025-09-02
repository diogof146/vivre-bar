import AppKit

class SettingsMenu: NSObject {
    private var popover: NSPopover?
    var onSpeedChanged: ((TimeInterval) -> Void)?

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

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        let viewController = NSViewController()
        viewController.view = contentView
        popover?.contentViewController = viewController

        // Animation speed slider
        let speedSlider = NSSlider(
            value: 1, minValue: 0.5,
            maxValue: 1.5, target: self,
            action: #selector(speedChanged(_:))
        )
        // Load the actual speed multiplier for the slider
        let currentInterval = UserDefaults.standard.double(forKey: "animationSpeed")
        if currentInterval > 0 {
            speedSlider.doubleValue = 0.05 / currentInterval  // Convert interval back to multiplier
        }
        let speedLabel = NSTextField(labelWithString: "Animation Speed")
        speedSlider.numberOfTickMarks = 5
        contentView.addSubview(speedLabel)
        contentView.addSubview(speedSlider)
        speedLabel.frame = NSRect(x: 10, y: 60, width: 180, height: 20)
        speedSlider.frame = NSRect(x: 10, y: 40, width: 180, height: 20)
        speedSlider.isContinuous = true
        DispatchQueue.main.async {
            self.sliderTics(to: contentView, slider: speedSlider)
        }
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

            let label = NSTextField(labelWithString: String(format: "%.1fx", value))
            label.alignment = .center
            label.frame = NSRect(
                x: tickCenter.x - 15,
                y: tickCenter.y - 5,
                width: 30,
                height: 16
            )

            contentView.addSubview(label)
        }
    }

    @objc private func speedChanged(_ slider: NSSlider) {
        let speedMultiplier = slider.doubleValue
        let timerInterval = 0.05 / speedMultiplier
        UserDefaults.standard.set(timerInterval, forKey: "animationSpeed")
        onSpeedChanged?(slider.doubleValue)
    }
}

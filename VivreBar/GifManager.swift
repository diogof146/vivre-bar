import AppKit
import UniformTypeIdentifiers

struct GifItem {
    let name: String
    let url: URL
    let isBuiltIn: Bool
    var displayName: String {
        return name.replacingOccurrences(of: ".gif", with: "").capitalized
    }
}

class GifManager {
    static let shared = GifManager()

    var currentGifURL: URL? {
        if let path = UserDefaults.standard.string(forKey: "selectedGifPath") {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return getBuiltInGifs().first?.url
    }

    // This creates the folder where user GIFs will live
    private lazy var userGifsDirectory: URL = {
        // Get ~/Library/Application Support/
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        // Create ~/Library/Application Support/VivreBar/GIFs/
        let vivreBarDir = appSupport.appendingPathComponent("VivreBar")
        let gifsDir = vivreBarDir.appendingPathComponent("GIFs")

        // Create the folder if it doesn't exist
        try? FileManager.default.createDirectory(
            at: gifsDir,
            withIntermediateDirectories: true
        )
        return gifsDir
    }()

    private init() {
        // Ensures only one instance exists
    }

    private func getUserGifs() -> [GifItem] {
        var gifs: [GifItem] = []

        do {
            let userFiles = try FileManager.default.contentsOfDirectory(
                at: userGifsDirectory,
                includingPropertiesForKeys: nil
            )
            for fileURL in userFiles {
                if fileURL.pathExtension.lowercased() == "gif" {
                    let gifItem = GifItem(
                        name: fileURL.lastPathComponent, url: fileURL, isBuiltIn: false
                    )
                    gifs.append(gifItem)
                }
            }
        } catch {
            print("Couldn't read user GIFs folder: \(error)")
        }

        return gifs
    }

    private func getBuiltInGifs() -> [GifItem] {
        var gifs: [GifItem] = []

        guard let resourcePath = Bundle.main.resourcePath else { return gifs }

        do {
            // List all files in Resources
            let allFiles = try FileManager.default.contentsOfDirectory(atPath: resourcePath)

            // Filter for .gif files only
            for fileName in allFiles {
                if fileName.lowercased().hasSuffix(".gif") {
                    let gifURL = URL(fileURLWithPath: resourcePath).appendingPathComponent(fileName)
                    let gifItem = GifItem(name: fileName, url: gifURL, isBuiltIn: true)
                    gifs.append(gifItem)
                }
            }
        } catch {
            print("Couldn't read app bundle: \(error)")
        }

        return gifs
    }

    func availableGifs() -> [GifItem] {
        let builtIn = getBuiltInGifs()
        let user = getUserGifs()
        return builtIn + user
    }

    func selectUserGif(completion: @escaping (URL?) -> Void) {
        let openPanel = NSOpenPanel()

        // Configure the file picker window
        openPanel.title = "Choose a GIF"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [UTType.gif, UTType.folder]

        // Start in user's Pictures folder
        openPanel.directoryURL =
            FileManager.default.urls(
                for: .picturesDirectory,
                in: .userDomainMask
            ).first
        // Show the picker (asynchronous!)
        openPanel.begin { response in
            if response == .OK, let selectedURL = openPanel.url {
                // User picked a file - copy it to our folder
                if selectedURL.pathExtension.lowercased() == "gif" {
                    self.copyGifToUserDirectory(from: selectedURL, completion: completion)
                }
            } else {
                // User cancelled
                completion(nil)
            }
        }
    }

    private func copyGifToUserDirectory(from sourceURL: URL, completion: @escaping (URL?) -> Void) {
        let fileName = sourceURL.lastPathComponent
        let destinationURL = userGifsDirectory.appendingPathComponent(fileName)

        do {
            // Copy the file to ~/Library/Application Support/VivreBar/GIFs/
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            completion(destinationURL)  // Success!
        } catch {
            print("Failed to copy GIF: \(error)")
            completion(nil)  // Failed
        }
    }

    func setCurrentGif(url: URL) {
        UserDefaults.standard.set(url.path, forKey: "selectedGifPath")
    }
}

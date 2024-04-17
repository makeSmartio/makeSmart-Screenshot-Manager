import SwiftUI
import Vision

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct ContentView: View {
    @State private var selectedFolderURL: URL?
    @AppStorage("lastSelectedFolderURL") var lastSelectedFolderURL: URL?
    @State private var images: [URL] = []
    @State private var selectedImage: URL?
    @AppStorage("isDarkModeEnabled") var isDarkModeEnabled: Bool = true
    @State private var numberOfCols = 4
    @State private var searchText = ""
    @State private var isProcessing = false
    @State private var shouldCancel = false
    @State private var totalFiles = 0
    @State private var currentFileNumber = 0
    @State private var showTextPopup = false
    @State private var imageText = ""
    @State private var fileName = ""
    
    var body: some View {
        VStack {//vstack1
            VStack {//vstack2
                HStack {
                    Text("Search:")
                    Image(systemName: "magnifyingglass")
                    TextField("Search by file name or comments", text: $searchText)
                        .frame(height: 10)
                        .frame(maxWidth: .infinity / 2)
                    //Toggle("Dark Mode", isOn: $isDarkModeEnabled)
                    if isProcessing {
                        Button("Cancel") {
                            self.shouldCancel = true
                        }
                        Text("Processing \(currentFileNumber) of \(totalFiles) files")
                        ProgressView(value: Float(currentFileNumber), total: Float(totalFiles))
                            .padding()
                    } else {
                        Button("Choose Folder") {
                            let panel = NSOpenPanel()
                            panel.allowsMultipleSelection = false
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            if let lastFolderURL = lastSelectedFolderURL {
                                panel.directoryURL = lastFolderURL
                            }
                            if panel.runModal() == .OK {
                                selectedFolderURL = panel.url
                                lastSelectedFolderURL = panel.url
                                fetchImagesFromFolder()
                            }
                        }
                        Button("Process Images") {
                           processImages()
                        }
                        //.disabled(images.isEmpty) // Disable the button if there are no images or processing
                    }
                    Stepper("Number of Columns: \(numberOfCols)", value: $numberOfCols, in: 1...20)
                }
                
            }//vstack2
            .padding(.top, 20)//add padding to top of view
            .padding(.horizontal, 60)

//This list helps debugging
//            List(images.filter
//                 { image in
//                getFinderComment(url: image.absoluteURL) == nil
//            }, id: \.self) { image in
//            List(images, id: \.self)
//                { image in
//                HStack {
//                    if let nsImage = NSImage(contentsOf: image) {
//                        Image(nsImage: nsImage)
//                            .resizable()
//                            .frame(width: 100, height: 100)
//                    }
//                    VStack(alignment: .leading) {
//                        Text(image.lastPathComponent)
//                        if let creationDate = try? image.resourceValues(forKeys: [.creationDateKey]).creationDate {
//                            Text("Created: \(creationDate, formatter: dateFormatter)")
//                                .font(.caption)
//                        }
//                        if let modifiedDate = try? image.resourceValues(forKeys: [.attributeModificationDateKey]).attributeModificationDate {
//                            Text("Modified: \(modifiedDate, formatter: dateFormatter)")
//                                .font(.caption)
//                        }
//                    }
//                    if let finderComment = getFinderComment(url: image.absoluteURL) {
//                        Text(finderComment)
//                    } else {
//                        Text("No Finder Comment")
//                    }
//                }
//            }
//            .padding()
            
            if images.isEmpty {
                Text("No images found in the selected folder.")
            } else {
                GeometryReader { geometry in
                    ScrollView {
                        LazyVGrid(columns: getGridColumns(width: geometry.size.width), spacing: 20) {
                            ForEach(images.filter(filterImage).sorted(by: { url1, url2 in
                                // Sorting logic here
                                if let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate,
                                   let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate {
                                    return date1 > date2 // Sort by creation date, newest first
                                } else {
                                    // Handle cases where creation date is unavailable (e.g., return false to keep original order)
                                    return false
                                }
                            }), id: \.self) { imageURL in
                                VStack {
                                    AsyncImageView(url: imageURL)
                                        .aspectRatio(contentMode: .fit)
                                        .cornerRadius(10)
                                        .overlay(
                                            selectedImage == imageURL ?
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.blue, lineWidth: 4)
                                            : nil
                                        )
                                        .onTapGesture(count: 2) {
                                            openImageInDefaultApp(url: imageURL)
                                        }
                                    Text(imageURL.lastPathComponent)
                                        .font(.caption)
                                        .lineLimit(2)
                                        .truncationMode(.middle)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .onTapGesture {
                                    selectedImage = imageURL
                                }
                                .contextMenu {
                                    Text("Action Menu")
                                    Divider()
                                    Button("View Image Text") {
                                        imageText = getFinderComment(url: imageURL)
                                        fileName = imageURL.lastPathComponent
                                        print("File: \(imageURL), Finder Comment: \(imageText)")
                                        showTextPopup = true
                                    }
                                    Button("Copy Image") {
                                        guard let imageData = try? Data(contentsOf: imageURL),
                                              let nsImage = NSImage(data: imageData) else {
                                            // Handle the case where the image data cannot be converted to NSImage
                                            return
                                        }
                                        let pasteboard = NSPasteboard.general
                                        pasteboard.clearContents()
                                        pasteboard.writeObjects([nsImage])
                                    }
                                    Button("Copy file name") {
                                        let filename = imageURL.lastPathComponent
                                        let pasteboard = NSPasteboard.general
                                        pasteboard.clearContents()
                                        pasteboard.setString(filename, forType: .string)
                                    }
                                    Button("Show in Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([imageURL])
                                    }
                                    Button("Send to Trash") {
                                        trashImage(url: imageURL)
                                    }
                                }
                            }
                        }
                        .sheet(isPresented: $showTextPopup) {
                            TextPopupView(imageText: $imageText, fileName: $fileName)
                        }
                    }
                }
            }//images
            Spacer()
            
            Text("Number of images: \(images.filter(filterImage).count)")
                .font(.caption)
                .padding(.bottom,5)
        }//vstack1
        .onAppear {
            fetchImagesFromFolder() // Add this line
        }
        .background(VisualEffect().ignoresSafeArea())
        //.preferredColorScheme(isDarkModeEnabled ? .dark : .light)
    }//view
    
    struct TextPopupView: View {
        @Binding var imageText: String
        @Binding var fileName: String
        @Environment(\.presentationMode) var presentationMode
        
        var body: some View {
            VStack {
                Text(fileName)
                    .font(.headline)
                    .padding()
                TextEditor(text: $imageText)
                    .padding()
                    .frame(minHeight: 200)
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
            }
            .frame(minWidth: 300, minHeight: 200)
        }
    }
    struct VisualEffect: NSViewRepresentable {
        func makeNSView(context: Self.Context) -> NSView { return NSVisualEffectView() }
        func updateNSView(_ nsView: NSView, context: Context) { }
    }
    struct AsyncImageView: View {
        let url: URL
        
        var body: some View {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure(let error):
                    // Display an error message or a custom error view
                    Text("Error loading image: \(error.localizedDescription)")
                        .foregroundColor(.red)
                case .empty:
                    // Display a progress view while the image is loading
                    ProgressView()
                @unknown default:
                    // Handle any unknown cases
                    EmptyView()
                }
            }
        }
    }
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    private func fetchImagesFromFolder() {
        print(lastSelectedFolderURL ?? "nil lastSelectedFolderURL")
        guard let folderURL = selectedFolderURL ?? lastSelectedFolderURL else {
            print("No folder selected.")
            images = []
            return
        }
        let fileManager = FileManager.default
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            let extensions: Set<String> = ["png", "jpg", "jpeg", "heic"]
            images = fileURLs.filter { extensions.contains($0.pathExtension.lowercased()) }
        } catch {
            print("Error while enumerating files: \(folderURL) \(error.localizedDescription)")
            lastSelectedFolderURL = nil
            images = []
        }
    }

    private func processImages() {
        self.shouldCancel = false
        self.isProcessing = true
        self.totalFiles = self.images.count
        self.currentFileNumber = 0
        
        DispatchQueue.global(qos: .userInitiated).async {
            for (index, imageURL) in self.images.enumerated() {
                if self.shouldCancel {
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        print("Processing was cancelled.")
                    }
                    return
                }
                let existingComment = getFinderComment(url: imageURL)
                //if existingComment.isEmpty { //fix
                if existingComment == "No comment found" { //fix
                    self.extractText(from: imageURL) { extractedText in
                        print("Extracted Text from: \(imageURL.lastPathComponent):")
                        print(extractedText)
                        if !self.saveFinderComment(fileURL: imageURL, comment: extractedText) {
                            print("Error saving comment")
                        }
                    }
                    //sleep(1)
                } else {
                    //print(existingComment)
                    print("Already set")
                }
                
                DispatchQueue.main.async {
                    self.currentFileNumber = index + 1
                }
            }
            
            DispatchQueue.main.async {
                self.isProcessing = false
                if !self.shouldCancel {
                    print("Processing completed.")
                }
            }
        }
    }
    
    private func trashImage(url: URL) {
        let fileManager = FileManager.default
        do {
            let trashURL = try fileManager.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let uniqueFileName = UUID().uuidString + "." + url.pathExtension
            let resultingURL = trashURL.appendingPathComponent(uniqueFileName)
            print(resultingURL)
            var resultingNSURL: NSURL?
            try fileManager.trashItem(at: url, resultingItemURL: &resultingNSURL)
            images.removeAll { $0 == url } // Remove image from list
            print("Successfully moved file to:", resultingNSURL?.absoluteString ?? "nil")
        } catch {
            print("Error moving image to recycle bin:", error.localizedDescription)
        }
    }
    private func getGridColumns(width: CGFloat) -> [GridItem] {
        let itemWidth = (width - (CGFloat(numberOfCols + 1) * 20)) / CGFloat(numberOfCols) // Adjust spacing accordingly
        return Array(repeating: GridItem(.flexible(minimum: itemWidth, maximum: itemWidth)), count: numberOfCols)
    }
    private func filterImage(url: URL) -> Bool {
        let filename = url.lastPathComponent.lowercased()
        let fileComments = getFinderComment(url: url).lowercased()
        //let searchTerm = searchText.lowercased()
        //return fileComments.contains(searchTerm)
        //return searchText.isEmpty || filename.contains(searchTerm) || fileComments.contains(searchTerm)
        let searchTerms = searchText.trimmingCharacters(in: .whitespaces).lowercased().components(separatedBy: " ")
        return searchTerms.allSatisfy { searchText.isEmpty || filename.contains($0) || fileComments.contains($0) }
    }
    private func openImageInDefaultApp(url: URL) {
        NSWorkspace.shared.open(url)
    }
    func getFinderComment(url: URL) -> String {
        let XAFinderComment = "com.apple.metadata:kMDItemFinderComment"

        let data = url.withUnsafeFileSystemRepresentation { fileSystemPath -> Data? in
            // Determine attribute size:
            let length = getxattr(fileSystemPath, XAFinderComment, nil, 0, 0, 0)
            guard length >= 0 else { return nil }

            // Create buffer with required size:
            var data = Data(count: length)

            // Retrieve attribute:
            let result = data.withUnsafeMutableBytes { [count = data.count] in
                getxattr(fileSystemPath, XAFinderComment, $0.baseAddress, count, 0, 0)
            }
            guard result >= 0 else { return nil }
            return data
        }

        if let data = data, let comment = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? String, !comment.isEmpty  {
            return comment
        } else {
            return "No comment found" // Return placeholder if comment is nil, empty, or invalid
        }
    }
    private func extractText(from imageURL: URL, completion: @escaping (String) -> Void) {
        // Create a request handler
        guard let image = CIImage(contentsOf: imageURL) else {
            print("Could not load image \(imageURL)")
            return
        }
        let requestHandler = VNImageRequestHandler(ciImage: image, options: [:])
        
        // Create a text recognition request
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("\(imageURL) Text recognition error: \(error.localizedDescription)")
                completion("")
                return
            }
            // Process the results
            let textObservations = request.results as? [VNRecognizedTextObservation] ?? []
            let extractedText = textObservations.compactMap { observation in
                // Return the top candidate's string
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            completion(extractedText)
        }
        
        // Perform the text recognition request
        do {
            try requestHandler.perform([request])
        } catch {
            print("Failed to perform text recognition request: \(error)")
            completion("")
        }
    }

    func saveFinderComment(fileURL: URL, comment: String) -> Bool {
        do {
            let plistData = try PropertyListSerialization.data(fromPropertyList: comment, format: .binary, options: 0)
            try fileURL.setExtendedAttribute(data: plistData, forName: "com.apple.metadata:kMDItemFinderComment")
        } catch {
            print("Error saving Finder comment: \(error)")
            return false
        }
        return true
    }
}
extension URL {
    
    /// Get extended attribute.
    func extendedAttribute(forName name: String) throws -> Data  {
        
        let data = try self.withUnsafeFileSystemRepresentation { fileSystemPath -> Data in
            
            // Determine attribute size:
            let length = getxattr(fileSystemPath, name, nil, 0, 0, 0)
            guard length >= 0 else { throw URL.posixError(errno) }
            
            // Create buffer with required size:
            var data = Data(count: length)
            
            // Retrieve attribute:
            let result =  data.withUnsafeMutableBytes { [count = data.count] in
                getxattr(fileSystemPath, name, $0.baseAddress, count, 0, 0)
            }
            guard result >= 0 else { throw URL.posixError(errno) }
            return data
        }
        return data
    }
    
    /// Set extended attribute.
    func setExtendedAttribute(data: Data, forName name: String) throws {
        
        try self.withUnsafeFileSystemRepresentation { fileSystemPath in
            let result = data.withUnsafeBytes {
                setxattr(fileSystemPath, name, $0.baseAddress, data.count, 0, 0)
            }
            guard result >= 0 else { throw URL.posixError(errno) }
        }
    }
    
    /// Remove extended attribute.
    func removeExtendedAttribute(forName name: String) throws {
        
        try self.withUnsafeFileSystemRepresentation { fileSystemPath in
            let result = removexattr(fileSystemPath, name, 0)
            guard result >= 0 else { throw URL.posixError(errno) }
        }
    }
    
    /// Get list of all extended attributes.
    func listExtendedAttributes() throws -> [String] {
        
        let list = try self.withUnsafeFileSystemRepresentation { fileSystemPath -> [String] in
            let length = listxattr(fileSystemPath, nil, 0, 0)
            guard length >= 0 else { throw URL.posixError(errno) }
            
            // Create buffer with required size:
            var namebuf = Array<CChar>(repeating: 0, count: length)
            
            // Retrieve attribute list:
            let result = listxattr(fileSystemPath, &namebuf, namebuf.count, 0)
            guard result >= 0 else { throw URL.posixError(errno) }
            
            // Extract attribute names:
            let list = namebuf.split(separator: 0).compactMap {
                $0.withUnsafeBufferPointer {
                    $0.withMemoryRebound(to: UInt8.self) {
                        String(bytes: $0, encoding: .utf8)
                    }
                }
            }
            return list
        }
        return list
    }
    /// Helper function to create an NSError from a Unix errno.
    private static func posixError(_ err: Int32) -> NSError {
        return NSError(domain: NSPOSIXErrorDomain, code: Int(err),
                       userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(err))])
    }
}

import Foundation

public struct FileDto: Codable {
    public let id: String
    public let fileName: String
    public let size: UInt64
    public let fileType: String
    public let sha256: String?
    public let preview: String?
    public let metadata: FileMetadata?
    
    public init(id: String, fileName: String, size: UInt64, fileType: String, sha256: String? = nil, preview: String? = nil, metadata: FileMetadata? = nil) {
        self.id = id
        self.fileName = fileName
        self.size = size
        self.fileType = fileType
        self.sha256 = sha256
        self.preview = preview
        self.metadata = metadata
    }
}

public struct FileMetadata: Codable {
    public let modified: String?
    public let accessed: String?
    
    public init(modified: String? = nil, accessed: String? = nil) {
        self.modified = modified
        self.accessed = accessed
    }
}

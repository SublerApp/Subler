//
//  FilePromiseProvider.swift
//  Subler
//
//  Created by Damiano Galassi on 28/06/24.
//

import Cocoa
import UniformTypeIdentifiers

class FilePromiseProvider: NSFilePromiseProvider {

    struct UserInfoKeys {
        static let indexPathKey = "indexPath"
        static let extensionKey = "extension"
        static let urlKey = "url"
    }

    /** Required:
        Return an array of UTI strings of data types the receiver can write to the pasteboard.
        By default, data for the first returned type is put onto the pasteboard immediately, with the remaining types being promised.
        To change the default behavior, implement -writingOptionsForType:pasteboard: and return
        NSPasteboardWritingPromised to lazily provided data for types, return no option to provide the data for that type immediately.

        Use the pasteboard argument to provide different types based on the pasteboard name, if desired.
        Do not perform other pasteboard operations in the function implementation.
    */
    override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        var types = super.writableTypes(for: pasteboard)
        types.append(.artworkDragType) // Add our own internal drag type (row drag and drop reordering).
        var type: NSPasteboard.PasteboardType
        if #available(macOS 11.0, *) {
            type = NSPasteboard.PasteboardType(UTType.image.identifier)
        } else {
            type = (kUTTypeImage as NSPasteboard.PasteboardType)
        }
        types.append(type)
        return types
    }

    /** Required:
        Return the appropriate property list object for the provided type.
        This will commonly be the NSData for that data type.  However, if this function returns either a string, or any other property-list type,
        the pasteboard will automatically convert these items to the correct NSData format required for the pasteboard.
    */
    override func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        guard let userInfoDict = userInfo as? [String: Any] else { return nil }
        switch type {
        case .fileURL:
            // Incoming type is "public.file-url", return (from our userInfo) the item's URL.
            if let url = userInfoDict[FilePromiseProvider.UserInfoKeys.urlKey] as? NSURL {
                return url.pasteboardPropertyList(forType: type)
            }
        case .artworkDragType:
            // Incoming type is "com.mycompany.mydragdrop", return (from our userInfo) the item's indexPath.
            let indexPathData = userInfoDict[FilePromiseProvider.UserInfoKeys.indexPathKey]
            return indexPathData
        default:
            break
        }
        return super.pasteboardPropertyList(forType: type)
    }

    /** Optional:
        Returns options for writing data of a type to a pasteboard.
        Use the pasteboard argument to provide different options based on the pasteboard name, if desired.
        Do not perform other pasteboard operations in the function implementation.
     */
    public override func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard)
        -> NSPasteboard.WritingOptions {
        return super.writingOptions(forType: type, pasteboard: pasteboard)
    }

}

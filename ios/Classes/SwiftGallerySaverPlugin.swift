import Flutter
import UIKit
import Photos

enum MediaType: Int {
    case image
    case video
}

public class SwiftGallerySaverPlugin: NSObject, FlutterPlugin {
    let path = "path"
    let albumName = "albumName"
    let fileName = "fileName"
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "gallery_saver", binaryMessenger: registrar.messenger())
        let instance = SwiftGallerySaverPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "saveImage" {
            self.saveMedia(call, .image, result)
        } else if call.method == "saveVideo" {
            self.saveMedia(call, .video, result)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    /// Tries to save image to the photos app.
    /// If user hasn't already permitted saving to the photos, it will be requested
    /// to do so.
    ///
    /// - Parameters:
    ///   - call: method object with params for saving media
    ///   - mediaType: media type
    ///   - result: flutter result that gets sent back to the dart code
    ///
    func saveMedia(_ call: FlutterMethodCall, _ mediaType: MediaType, _ result: @escaping FlutterResult) {
        let args = call.arguments as? Dictionary<String, Any>
        let path = args![self.path] as! String
        let albumName = args![self.albumName] as? String
        let customFileName = args?[self.fileName] as? String
        
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization({status in
                if status == .authorized{
                    self._saveMediaToAlbum(path, mediaType, albumName, customFileName, result)
                } else {
                    result(false);
                }
            })
        } else if status == .authorized {
            self._saveMediaToAlbum(path, mediaType, albumName, customFileName, result)
        } else {
            result(false);
        }
    }
    
    private func _saveMediaToAlbum(_ imagePath: String, _ mediaType: MediaType, _ albumName: String?,
                                   _ fileName: String?, _ flutterResult: @escaping FlutterResult) {
        if (albumName == nil) {
            self.saveFile(imagePath, mediaType, nil, fileName, flutterResult)
        } else if let album = fetchAssetCollectionForAlbum(albumName!) {
            self.saveFile(imagePath, mediaType, album, fileName, flutterResult)
        } else {
            // create photos album
            createAppPhotosAlbum(albumName: albumName!) { (error) in
                guard error == nil else {
                    flutterResult(false)
                    return
                }
                if let album = self.fetchAssetCollectionForAlbum(albumName!) {
                    self.saveFile(imagePath, mediaType, album, fileName, flutterResult)
                } else {
                    flutterResult(false)
                }
            }
        }
    }
    
    private func saveFile(_ filePath: String, _ mediaType: MediaType, _ album: PHAssetCollection?,
                          _ fileName: String?, _ flutterResult: @escaping FlutterResult) {
        let url = URL(fileURLWithPath: filePath)
        PHPhotoLibrary.shared().performChanges({
            var placeholder: PHObjectPlaceholder?
            
            switch mediaType {
            case .image:
                if let changeRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url) {
                    placeholder = changeRequest.placeholderForCreatedAsset
                }
            case .video:
                if let name = fileName, !name.isEmpty {
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    let options = PHAssetResourceCreationOptions()
                    options.originalFilename = name
                    creationRequest.addResource(with: .video, fileURL: url, options: options)
                    placeholder = creationRequest.placeholderForCreatedAsset
                } else {
                    if let changeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url) {
                        placeholder = changeRequest.placeholderForCreatedAsset
                    }
                }
            }
            
            if let album = album,
               let assetCollectionChangeRequest = PHAssetCollectionChangeRequest(for: album),
               let createdAssetPlaceholder = placeholder {
                assetCollectionChangeRequest.addAssets(NSArray(array: [createdAssetPlaceholder]))
            }
        }) { (success, error) in
            if success {
                flutterResult(true)
            } else {
                flutterResult(false)
            }
        }
    }
   
    private func fetchAssetCollectionForAlbum(_ albumName: String) -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        if let _: AnyObject = collection.firstObject {
            return collection.firstObject
        }
        return nil
    }
    
    private func createAppPhotosAlbum(albumName: String, completion: @escaping (Error?) -> ()) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
        }) { (_, error) in
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }
}

//
//  StorageManager.swift
//  Messenger
//
//  Created by zjp on 2021/11/17.
//

import Foundation
import FirebaseStorage

final class StorageManager{
    
    
    static let  shared = StorageManager()
    
    private let storage = Storage.storage().reference()
    
    
    public typealias UploadPictureComplaion = (Result<String, Error>)-> Void
    
    
    public func uploadProfilePicture(with data:Data,fileName:String,completion : @escaping UploadPictureComplaion){
        
        storage.child("images/\(fileName)").putData(data, metadata: nil, completion: { metadata,error in
            guard error == nil else{
                print("failed to upload data to firebase for profile picture")
                completion(.failure(StorageError.faildToUpload))
                return
            }
            
            self.storage.child("images/\(fileName)").downloadURL(completion: { url,error in
                guard let url = url else{
                    print("failed to get download url")
                    return
                }
                let urlString = url.absoluteString
                print("download url return :\(urlString)")
                completion(.success(urlString))
            })
        })
        
    }
    
    
    public func uploadMessagePhoto(with data:Data,fileName:String,completion : @escaping UploadPictureComplaion){
        
        storage.child("message_images/\(fileName)").putData(data, metadata: nil, completion: { [weak self] metadata,error in
            guard error == nil else{
                print("failed to upload data to firebase for profile picture")
                completion(.failure(StorageError.faildToUpload))
                return
            }
            
            self?.storage.child("message_images/\(fileName)").downloadURL(completion: { url,error in
                guard let url = url else{
                    print("failed to get download url")
                    return
                }
                let urlString = url.absoluteString
                print("download url return :\(urlString)")
                completion(.success(urlString))
            })
        })
        
    }
    
    
    
    public func uploadMessageVideo(with fileUrl:URL,fileName:String,completion : @escaping UploadPictureComplaion){
        
        storage.child("message_videos/\(fileName)").putFile(from: fileUrl, metadata: nil, completion: {[weak self] metadata,error in
            guard error == nil else{
                print("failed to upload data to firebase for message video:\(error)")
                completion(.failure(StorageError.faildToUpload))
                return
            }
            
            self?.storage.child("message_videos/\(fileName)").downloadURL(completion: { url,error in
                guard let url = url else{
                    print("failed to get video download url")
                    return
                }
                let urlString = url.absoluteString
                print("download url return :\(urlString)")
                completion(.success(urlString))
            })
        })
        
    }
    
    
    public enum StorageError: Error{
        case faildToUpload
        case failedToGetDownloadUrl
    }
    
    
    public func downloadUrl(for path:String,completion : @escaping(Result<URL,Error>) -> Void){
        let refernce = storage.child(path)
        
        refernce.downloadURL(completion: { url,error in
            
            guard let url = url ,error == nil else{
                completion(.failure(StorageError.failedToGetDownloadUrl))
                return
            }
            completion(.success(url))
        })
    }
    
}

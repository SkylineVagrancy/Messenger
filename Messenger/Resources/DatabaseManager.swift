//
//  DatabaseManager.swift
//  Messenger
//
//  Created by zjp on 2021/11/16.
//

import Foundation
import FirebaseDatabase
import MessageKit

final class DatabaseManager{
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    static func safeEmail(email:String) -> String{
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
}


extension DatabaseManager{
    
    public func createNewConversation(with otherUserEmail :String ,name:String,firstMessage:Message,completion: @escaping (Bool) -> Void){
        guard let currentEmial = UserDefaults.standard.value(forKey: "email") as? String,
              let currentName = UserDefaults.standard.value(forKey: "name") as? String else{
                  return
              }
        
        let safeEmail = DatabaseManager.safeEmail(email: currentEmial)
        let ref = database.child("\(safeEmail)")
        
        
        ref.observeSingleEvent(of: .value, with: {[weak self] snap in
            guard var userNode = snap.value as? [String:Any] else{
                completion(false)
                print("user not found")
                return
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewViewController.dateFormat.string(from: messageDate)
            
            
            var message = ""
            switch firstMessage.kind{
                
            case .text(let text):
                message = text
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let conversationID = "conversation_\(firstMessage.messageId)"
            
            let newConversationData: [String:Any] = [
                "id":conversationID,
                "other_user_email":otherUserEmail,
                "name":name,
                "latest_message":[
                    "date":dateString,
                    "message":message,
                    "is_read": false,
                ]
            ]
            
            
            let recipient_newConversationData: [String:Any] = [
                "id":conversationID,
                "other_user_email":safeEmail,
                "name":currentName,
                "latest_message":[
                    "date":dateString,
                    "message":message,
                    "is_read": false,
                ]
            ]
            
            
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: {sanphost in
                if var conversations = sanphost.value as? [[String:Any]]{
                    conversations.append(recipient_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                }else{
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationData])
                }
            })
            
            if var conversations = userNode["conversations"] as? [[String: Any]]{
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                ref.setValue(userNode,withCompletionBlock: {[weak self] error,_ in
                    guard error == nil else{
                        completion(false)
                        return
                    }
                    
                    self?.finishCreatingConversation(name:name, conversationID: conversationID,  firstMessage: firstMessage,  completion: completion)
                    
                })
            }else{
                userNode["conversations"] = [
                    newConversationData
                ]
                ref.setValue(userNode,withCompletionBlock: {[weak self]error,_ in
                    guard error == nil else{
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name:name, conversationID: conversationID,  firstMessage: firstMessage,  completion: completion)
                })
                
            }
            
        })
        
    }
    
    private func finishCreatingConversation(name:String,conversationID:String,firstMessage:Message,completion: @escaping (Bool) -> Void){
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewViewController.dateFormat.string(from: messageDate)
        var message = ""
        switch firstMessage.kind{
            
        case .text(let text):
            message = text
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        guard var currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else{
            completion(false)
            return
        }
         currentUserEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        
        let collectionMessage : [String:Any] = [
            "id":conversationID,
            "type": firstMessage.kind.messageKitString,
            "content": message,
            "date":dateString,
            "sender_email":currentUserEmail,
            "name":name,
            "is_read":false
        ]
        
        let value : [String:Any] = [
            "messages": [collectionMessage]
        ]
        
        database.child("\(conversationID)").setValue(value, withCompletionBlock: { error,_ in
            guard error == nil else{
                completion(false)
                return
            }
            completion(true)
            
        })
        
    }
    
    public func  getAllConversation(for email:String,completion: @escaping (Result<[Conversation],Error>) -> Void){
        print("observe path:\(email)/conversations")
        database.child("\(email)/conversations").observe(.value, with: { sanpshot in
            guard let value = sanpshot.value as? [[String:Any]] else{
                completion(.failure(DatabaseError.failerToFeatch))
                print("snapshot is empty")
                return
            }
            print("snap:\(sanpshot)")
            
            let conversations:[Conversation] = value.compactMap({ dictionary in
                guard let conversationID = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String:Any],
                      let date = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else{
                          return nil
                      }
                
                let  latestMessageObject = LatesMessage(date: date, message: message, isRead: isRead)
                return Conversation(id: conversationID, name: name, otherUserEmail: otherUserEmail, lastMessage: latestMessageObject)
            })
            print("conversation count:\(conversations.count)")
            completion(.success(conversations))
            
        })
    }
    
    public func getAllMessageForConversation(with id:String,completion: @escaping (Result<[Message],Error>) -> Void){
        print("\(id)/messages")
        database.child("\(id)/messages").observe(.value, with: { sanpshot in
            print("snaphost:\(sanpshot)")
            guard let value = sanpshot.value as? [[String:Any]] else{
                completion(.failure(DatabaseError.failerToFeatch))
                print("failed to get all message for conversation")
                return
            }
            
            let messages:[Message] = value.compactMap({ dictionary in
                guard let name = dictionary["name"] as? String,
                      let messageId = dictionary["id"] as? String,
                      let content = dictionary["content"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let type = dictionary["type"] as? String,
                      let date = ChatViewViewController.dateFormat.date(from: dateString) else{
                          return nil
                      }
                var kind:MessageKind?
                if type == "photo"{
                    guard let imageUrl = URL(string: content),
                          let placeHolder = UIImage(systemName: "plus") else{
                              return nil
                          }
                    let media = Media(url: imageUrl, image: nil, placeholderImage: placeHolder, size: CGSize(width: 300, height: 300))
                    kind = .photo(media)
                    
                }else if type == "video"{
                    guard let videoUrl = URL(string: content),
                          let placeHolder = UIImage(named: "video_fill_light") else{
                              return nil
                          }
                    let media = Media(url: videoUrl, image: nil, placeholderImage: placeHolder, size: CGSize(width: 300, height: 300))
                    kind = .video(media)
                    
                }
                else{
                    kind = .text(content)
                }
                
                guard let finalkind = kind else{
                    return nil
                }
                
                let sender = Sender(photoURL: "", senderId: senderEmail, displayName: name)
                return Message(sender: sender, messageId: messageId, sentDate: date, kind: finalkind)
            })
            completion(.success(messages))
        })
    }
    
    
    public func sendMessage(to conversation:String,otherUserEmai:String,name:String,newMessage:Message,completion: @escaping (Bool) -> Void){
       
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else{
            completion(false)
            return
        }
        
        let currentEmail = DatabaseManager.safeEmail(email: myEmail)
        
        
        self.database.child("\(conversation)/messages").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let strongSelf = self else{
                return
            }
            guard var currentMessage = snapshot.value as? [[String:Any]] else{
                completion(false)
                return
            }
            
            let messageDate = newMessage.sentDate
            let dateString = ChatViewViewController.dateFormat.string(from: messageDate)
            
            
            var message = ""
            switch newMessage.kind{
            case .text(let text):
                message = text
            case .attributedText(_):
                break
            case .photo(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString {
                    message = targetUrlString
                }
                break
            case .video(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString {
                    message = targetUrlString
                }
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let newMessageEntry : [String:Any] = [
                "id":newMessage.messageId,
                "type": newMessage.kind.messageKitString,
                "content": message,
                "date":dateString,
                "sender_email":  currentEmail,
                "name":name,
                "is_read":false
            ]
            
            currentMessage.append(newMessageEntry)
            
            strongSelf.database.child("\(conversation)/messages").setValue(currentMessage){ error ,_ in
                
                
                guard error == nil else{
                    completion(false)
                    return
                }
                self?.database.child("\(currentEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                    guard var currentUserConversations = snapshot.value as? [[String:Any]] else{
                        completion(false)
                        return
                    }
                    
                    let updateValue : [String:Any] = [
                        "date":dateString,
                        "is_read":false,
                        "message":message
                    ]
                    
                    var targetConversation:[String:Any]?
                    var position = 0
                    for conversationDictionary in currentUserConversations{
                        if let currentId = conversationDictionary["id"] as? String,
                           currentId == conversation {
                            targetConversation = conversationDictionary
                            break
                        }
                        position += 1
                        
                    }
                    
                    targetConversation?["latest_message"] = updateValue
                    guard let finalConversation = targetConversation else{
                        completion(false)
                        return
                    }
                    currentUserConversations[position] = finalConversation
                    strongSelf.database.child("\(currentEmail)/conversations").setValue(currentUserConversations,withCompletionBlock: { error,_ in
                        guard error == nil else{
                            completion(false)
                            return
                        }
                        self?.database.child("\(otherUserEmai)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                            guard var otherUserConversations = snapshot.value as? [[String:Any]] else{
                                completion(false)
                                return
                            }
                            
                            let updateValue : [String:Any] = [
                                "date":dateString,
                                "is_read":false,
                                "message":message
                            ]
                            
                            var targetConversation:[String:Any]?
                            var position = 0
                            for conversationDictionary in otherUserConversations{
                                if let currentId = conversationDictionary["id"] as? String,
                                   currentId == conversation {
                                    targetConversation = conversationDictionary
                                    break
                                }
                                position += 1
                                
                            }
                            
                            targetConversation?["latest_message"] = updateValue
                            guard let finalConversation = targetConversation else{
                                completion(false)
                                return
                            }
                            otherUserConversations[position] = finalConversation
                            strongSelf.database.child("\(otherUserEmai)/conversations").setValue(otherUserConversations,withCompletionBlock: { error,_ in
                                guard error == nil else{
                                    completion(false)
                                    return
                                }
                                completion(true)
                            })
                        })
                    })
                })
                
                
            }
            
        })
    }
}



extension DatabaseManager{
    public func getDataFor(path:String,completion: @escaping (Result<Any,Error>) -> Void){
        database.child("\(path)").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value else{
                completion(.failure(DatabaseError.failerToFeatch))
                return
            }
            completion(.success(value))
        }
    }
}


extension DatabaseManager{
    
    public func userExists(with email:String,
                           completion: @escaping ((Bool) -> Void)){
        
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        
        print("safeEmail = \(safeEmail)")
        
        database.child(safeEmail).observeSingleEvent(of: .value, with: { snap in
            guard snap.value as? [String:Any]  != nil else{
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool)-> Void){
        database.child(user.safeEmail).setValue(
            [
                "first_name":user.firstName,
                "last_name":user.lastName,
                
            ],withCompletionBlock: { error,_ in
                guard error == nil else{
                    print("failer to write database")
                    completion(false)
                    return
                }
                
                self.database.child("users").observeSingleEvent(of: .value, with: {snap in
                    if var userCollection = snap.value as? [[String:String]] {
                        
                        let newElement :[String:String] =
                        [
                            "name":user.firstName+" "+user.lastName,
                            "email":user.safeEmail
                        ]
                        
                        userCollection.append(newElement)
                        self.database.child("users").setValue(userCollection,withCompletionBlock: {error, _ in
                            guard error == nil else{
                                completion(false)
                                return
                            }
                            completion(true)
                        })
                        
                    }else{
                        let newCell :[[String:String]] =  [
                            [
                                "name":user.firstName+" "+user.lastName,
                                "email":user.safeEmail
                            ]
                        ]
                        self.database.child("users").setValue(newCell,withCompletionBlock: {error, _ in
                            guard error == nil else{
                                completion(false)
                                return
                            }
                            completion(true)
                        })
                    }
                })
            })
    }
    
    
    
    
    func getAllUser(completion: @escaping ((Result<[[String:String]],Error>) -> Void)) -> Void{
        database.child("users").observeSingleEvent(of: .value, with: { snap  in
            guard let value = snap.value as? [[String:String]] else{
                completion(.failure(DatabaseError.failerToFeatch))
                return
            }
            completion(.success(value))
            
        })
    }
    
    public enum DatabaseError : Error{
        case failerToFeatch
    }
}

struct ChatAppUser{
    let firstName:String
    let lastName:String
    let emailAddress:String
    //    let profilePictureUrl String
    
    var safeEmail:String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    var profilePictureFileName:String {
        return "\(safeEmail)_profile_picture.png"
    }
}



//
//  ChatViewViewController.swift
//  Messenger
//
//  Created by zjp on 2021/11/17.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit

struct Message : MessageType  {
    var sender: SenderType
    
    var messageId: String
    
    var sentDate: Date
    
    var kind: MessageKind
    
    
}

struct Media : MediaItem{
    var url: URL?
    
    var image: UIImage?
    
    var placeholderImage: UIImage
    
    var size: CGSize
    
    
}

extension MessageKind{
    var messageKitString:String {
        switch self{
        case .text(_):
            return "text"
        case .attributedText(_):
            return "attributed_text"
        case .photo(_):
            return "photo"
        case .video(_):
            return "video"
        case .location(_):
            return "location"
        case .emoji(_):
            return "emoji"
        case .audio(_):
            return "audio"
        case .contact(_):
            return "contact"
        case .linkPreview(_):
            return "link_preview"
        case .custom(_):
            return "custom"
        }
    }
}

struct Sender : SenderType{
    var photoURL :String
    
    var senderId: String
    
    var displayName: String
}

class ChatViewViewController: MessagesViewController {
    
    private var currentUserImageUrl :URL?
    private var otherUserImageUrl :URL?
    
    
    private let otherUserEmail:String
    private var conversationId:String?
    public var isNewConversation = true
    
    private var messages = [Message]()
    
    public static let dateFormat :DateFormatter = {
        let format = DateFormatter()
        format.dateStyle = .medium
        format.timeStyle = .long
        format.locale = .current
        return format
    }()
    
    private var selfSender:Sender?{
        
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            print("failed to get email from  UserDefault")
            return nil
        }
        let salfEmail = DatabaseManager.safeEmail(email: email)
        return  Sender(photoURL: "",
                       senderId: salfEmail,
                       displayName: "Me")
    }
    
    init(with email:String,id:String?){
        self.otherUserEmail = email
        self.conversationId = id
        super.init(nibName: nil, bundle: nil)
        if conversationId != nil {
            isNewConversation = false
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .red
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate  = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        
        setUpInputButton()
        
    }
    
    func setUpInputButton(){
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: true)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.onTouchUpInside({[weak self] _ in
            self?.presentInputActionSheet()
        })
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
    }
    
    
    func presentInputActionSheet(){
        let actionSheet = UIAlertController(title: "Attach Media",
                                            message: "what would you like ",
                                            preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Photo", style: .default, handler: {[weak self]_ in
            self?.presentPhotoInputSheet()
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Video", style: .default, handler: {[weak self]_ in
            self?.presentVideoInputSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "audio", style: .default, handler: {[weak self] _ in
            
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancle", style: .cancel, handler: nil))
        present(actionSheet, animated: false, completion: nil)
    }
    
    func presentPhotoInputSheet(){
        let actionSheet = UIAlertController(title: "Attach photo",
                                            message: "where would you like ",
                                            preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: {[weak self]_ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: false, completion: nil)
        }))
        actionSheet.addAction(UIAlertAction(title: "Photo", style: .default, handler: {[weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: false, completion: nil)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancle", style: .cancel, handler: nil))
        present(actionSheet, animated: false, completion: nil)
    }
    
    func presentVideoInputSheet(){
        let actionSheet = UIAlertController(title: "Attach video",
                                            message: "where would you like ",
                                            preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: {[weak self]_ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker, animated: false, completion: nil)
        }))
        actionSheet.addAction(UIAlertAction(title: "Photo", style: .default, handler: {[weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            self?.present(picker, animated: false, completion: nil)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancle", style: .cancel, handler: nil))
        present(actionSheet, animated: false, completion: nil)
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let conversationId = conversationId {
            listenForMessages(id: conversationId,shouldScrollToBottom: true)
            
        }
    }
    
    func listenForMessages (id:String,shouldScrollToBottom:Bool){
        DatabaseManager.shared.getAllMessageForConversation(with: id, completion: {[weak self]result in
            switch result{
            case .success(let messages):
                guard !messages.isEmpty else{
                    print("message is empty")
                    return
                }
                self?.messages = messages
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                    if(shouldScrollToBottom){
                        self?.messagesCollectionView.scrollToLastItem()
                    }
                }
                
            case .failure(let error):
                print("failed to get conversation for id:\(id),\(error)")
            }
            
        })
    }
}


extension ChatViewViewController : MessageCellDelegate{
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else{
            return
        }
        let message = messages[indexPath.section]
        switch message.kind{
        case .photo(let mediaItem):
            guard let url = mediaItem.url else{
                return
            }
            let vc = PhotoViewerViewController(with: url)
            self.navigationController?.pushViewController(vc, animated: true)
            break
        case .video(let mediaItem):
            guard let url = mediaItem.url else{
                return
            }
            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url: url)
           present(vc,animated: true)
            break
        default:
            break
        }
    }
}



extension ChatViewViewController : UIImagePickerControllerDelegate,UINavigationControllerDelegate{
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard  let messageId = createMessageId(),
               let conversationId = conversationId ,
               let name = title ,
               let selfSender = selfSender else{
                   return
               }
        
        
        if let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage,
           let imageData = image.pngData() {
            
            let fileName = "photo_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".png"
            
            
            StorageManager.shared.uploadMessagePhoto(with: imageData, fileName: fileName, completion: {[weak self]result in
                
                guard let  strongSelf = self else{
                    return
                }
                
                switch result{
                case .success(let urlString):
                    
                    guard let url = URL(string: urlString),
                          let placeHolder = UIImage(systemName: "plus") else{
                              return
                          }
                    
                    let media = Media(url: url,
                                      image: nil,
                                      placeholderImage: placeHolder,
                                      size: .zero)
                    
                    let message = Message(sender: selfSender,
                                          messageId: messageId,
                                          sentDate: Date(),
                                          kind: .photo(media))
                    
                    DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmai: strongSelf.otherUserEmail, name: name, newMessage: message) { success in
                        if(success){
                            print("send message photo")
                        }else{
                            print("failed to send message photo")
                        }
                    }
                    break
                case .failure(let error):
                    print("failed to upload message image:\(error)")
                }
                
            })
            
        }else if let videoUrl = info[.mediaURL] as? URL{
            
            let fileName = "photo_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".mov"
            print("videoUrl:\(videoUrl)")
            
    
            StorageManager.shared.uploadMessageVideo(with: videoUrl, fileName: fileName, completion: {[weak self]result in
                
                guard let  strongSelf = self else{
                    return
                }
                
                switch result{
                case .success(let urlString):
                    
                    guard let url = URL(string: urlString),
                          let placeHolder = UIImage(systemName: "plus") else{
                              return
                          }
                    
                    let media = Media(url: url,
                                      image: nil,
                                      placeholderImage: placeHolder,
                                      size: .zero)
                    
                    let message = Message(sender: selfSender,
                                          messageId: messageId,
                                          sentDate: Date(),
                                          kind: .video(media))
                    
                    DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmai: strongSelf.otherUserEmail, name: name, newMessage: message) { success in
                        if(success){
                            print("send message photo")
                        }else{
                            print("failed to send message photo")
                        }
                    }
                    break
                case .failure(let error):
                    print("failed to upload message video:\(error)")
                }
                
            })
            
            
        }
        
    }
    
}





extension ChatViewViewController : InputBarAccessoryViewDelegate{
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        print("send button press")
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
              let selfSender = self.selfSender,
              let messageId = createMessageId() else{
                  return
              }
        print("message text:\(text)")
        let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .text(text))
        if(isNewConversation){
            DatabaseManager.shared.createNewConversation(with: otherUserEmail,name: self.title ?? "User", firstMessage: message, completion: { [weak self] success in
                if(success){
                    self?.isNewConversation = false
                    print("message send success")
                    let newConversationId = "conversation_\(message.messageId)"
                    self?.conversationId = newConversationId
                    self?.listenForMessages(id: newConversationId, shouldScrollToBottom: true)
                    self?.messageInputBar.inputTextView.text = nil
                    
                }else{
                    print("message send failer")
                }
                
            })
            
        }else{
            guard let conversationId = conversationId,
                  let name = self.title else{
                      return
                  }
            DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmai: otherUserEmail,name: name,newMessage: message, completion: {[weak self] success in
                if(success){
                    self?.messageInputBar.inputTextView.text = nil
                    print("message has send success")
                }else{
                    print("failed to send message")
                }
            })
            
        }
    }
    
    
    func createMessageId() -> String?{
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else{
            return nil
        }
        
        let safeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        
        let dateString = Self.dateFormat.string(from: Date())
        let newIdentifier = "\(otherUserEmail)_\(safeEmail)_\(dateString)"
        
        print("current messageid = \(newIdentifier)")
        
        return newIdentifier
    }
}


extension ChatViewViewController : MessagesDataSource,MessagesLayoutDelegate,MessagesDisplayDelegate{
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    
    func currentSender() -> SenderType {
        
        if let sender = selfSender {
            return sender
        }
        fatalError("self sender is nil,email should be cache")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else{
            return
        }
        switch message.kind{
        case .photo(let mediaItem):
            guard let imageUrl = mediaItem.url else{
                return
            }
            imageView.sd_setImage(with: imageUrl, completed: nil)
            break
        default:
            break
        }
    }
    
    
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        if self.selfSender?.senderId == message.sender.senderId {
            return .link
        }else{
            return .secondarySystemFill
        }
    }
    
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        let sender = message.sender
        
        if sender.senderId == selfSender?.senderId{
            if let currentUserImageUrl = self.currentUserImageUrl {
                avatarView.sd_setImage(with: currentUserImageUrl, completed: nil)
            }
            
            guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
                return
            }
           
            let safeEmail = DatabaseManager.safeEmail(email: email)
            let path = "images/\(safeEmail)_profile_picture.png"
            
            StorageManager.shared.downloadUrl(for: path, completion: { [weak self]  result in
                switch result{
                case .success(let url):
                    self?.currentUserImageUrl = url
                    DispatchQueue.main.async {
                        avatarView.sd_setImage(with: url, completed: nil)
                    }
                case .failure(let error):
                    print("failed to get user image url:\(error) ")
                }
                
            })
        }else{
            if let otherUserImageUrl = self.otherUserImageUrl {
                avatarView.sd_setImage(with: otherUserImageUrl, completed: nil)
            }
            let safeEmail = DatabaseManager.safeEmail(email: otherUserEmail)
            let path = "images/\(safeEmail)_profile_picture.png"
            StorageManager.shared.downloadUrl(for: path, completion: {[weak self] result in
                switch result{
                case .success(let url):
                    self?.otherUserImageUrl = url
                    DispatchQueue.main.async {
                        avatarView.sd_setImage(with: url, completed: nil)
                    }
                case .failure(let error):
                    print("failed to get user image url:\(error) ")
                }
                
            })
        }
        
        
    }
    
    
}

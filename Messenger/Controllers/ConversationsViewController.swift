//
//  ViewController.swift
//  Messenger
//
//  Created by zjp on 2021/11/16.
//

import UIKit
import FirebaseAuth
import JGProgressHUD
import SwiftUI


struct Conversation{
    let id:String
    let name:String
    let otherUserEmail:String
    let lastMessage:LatesMessage
    
}

struct LatesMessage{
    let date:String
    let message:String
    let isRead:Bool
    
}

class ConversationsViewController: UIViewController {
    
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private var conversations = [Conversation]()
    
    private var loginObserver : NSObjectProtocol?
    
    private let tableView : UITableView = {
        let table = UITableView()
        table.register(ConversationTableViewCell.self, forCellReuseIdentifier: ConversationTableViewCell.identifire)
        table.isHidden = true
        return table
    }()
    
    private let noConversationLabel : UILabel = {
        let lable = UILabel()
        lable.text = "No Conversation!"
        lable.textAlignment = .center
        lable.textColor = .gray
        lable.font = .systemFont(ofSize: 21,weight:.medium)
        lable.isHidden = true
        return lable;
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(didTapCompose))
        view.addSubview(tableView)
        view.addSubview(noConversationLabel)
        setUpTableView()
        startListeningForConversations()
        loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNotification, object: nil, queue: .main, using: {
            [weak self] _ in
            guard let strongSelf = self else{
                return
            }
            strongSelf.startListeningForConversations()
        })
    }
    
     func startListeningForConversations(){
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            print("user email is empty")
            return
        }
        
        print("start listening conversation")
        
        if let observer = loginObserver{
            NotificationCenter.default.removeObserver(observer)
        }
        
        let safeEmail = DatabaseManager.safeEmail(email: email)
        DatabaseManager.shared.getAllConversation(for: safeEmail, completion: { [weak self]result in
            switch result {
            case .success(let conversations):
                guard !conversations.isEmpty else{
                    self?.tableView.isHidden = true
                    self?.noConversationLabel.isHidden = false
                    print("faile to get all conversation")
                    return
                }
                self?.tableView.isHidden = false
                self?.noConversationLabel.isHidden = true
                self?.conversations = conversations
                DispatchQueue.main.async{
                    self?.tableView.reloadData()
                }
            case .failure(let error):
                self?.tableView.isHidden = true
                self?.noConversationLabel.isHidden = false
                print("failed to get all conversation:\(error)")
            }
            
        })
    }
    
    
    @objc func didTapCompose(){
        let vc  = NewConversationViewController()
        vc.completion = { [weak self] result in
            print("\(result) ")
            self?.createNewConversation(result: result)
        }
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: false, completion: nil)
    }
    
    
    func createNewConversation(result :[String:String]){
        guard let name = result["name"],
              let email = result["email"] else{
                  return
              }
        let vc = ChatViewViewController(with: email,id:nil)
        vc.title = name
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(vc, animated: false)
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        vailidateAuth()
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noConversationLabel.frame = CGRect(x: 10, y: (view.height - 100)/2, width: view.width - 20, height: 100)
    }
    
    func fetchConversations(){
        tableView.isHidden = false
    }
    
    
    func setUpTableView(){
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    private func vailidateAuth(){        
        if FirebaseAuth.Auth.auth().currentUser == nil {
            let vc = LoginViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true, completion: nil)
        }
    }
    
}

extension ConversationsViewController : UITableViewDelegate , UITableViewDataSource{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConversationTableViewCell.identifire, for: indexPath) as! ConversationTableViewCell
        let model = conversations[indexPath.row]
        cell.configure(with:model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let model = conversations[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: false)
        let vc = ChatViewViewController(with: model.otherUserEmail, id: model.id)
        vc.title = model.name
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(vc, animated: false)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    
}


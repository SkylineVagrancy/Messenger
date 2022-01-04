//
//  ProfileViewController.swift
//  Messenger
//
//  Created by zjp on 2021/11/16.
//

import UIKit
import FirebaseAuth
import SwiftUI
import SDWebImage

enum ProfileViewModelType{
    case info,logout
}

struct ProfileViewModel{
    let viewModelType : ProfileViewModelType
    let title:String
    let handler: (()->Void)?
    
}

class ProfileViewController: UIViewController {
    
    @IBOutlet var tableView:UITableView!
    
    var data = [ProfileViewModel]()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(ProfileTableViewCell.self, forCellReuseIdentifier: ProfileTableViewCell.identifier)
        data.append(ProfileViewModel(viewModelType: .info, title: "name:\(UserDefaults.standard.value(forKey: "name") as? String ?? "No Name")", handler: nil))
       
        data.append(ProfileViewModel(viewModelType: .info, title: "email:\(UserDefaults.standard.value(forKey: "email") as? String ?? "No Email")", handler: nil))
        
        data.append(ProfileViewModel(viewModelType: .logout, title: "Log Out", handler: {[weak self] in
            guard let strongSelf = self else{
                return
            }
            
            UserDefaults.standard.setValue(nil, forKey: "email")
            UserDefaults.standard.setValue(nil, forKey: "name")
            
            let actionSheet = UIAlertController(title: "are you sure login out?", message: "", preferredStyle: .actionSheet)
            
            actionSheet.addAction(UIAlertAction(title: "Login out", style: .destructive, handler: {[weak self] _ in
                guard let strongSelf = self else{
                    return
                }
                do{
                    try FirebaseAuth.Auth.auth().signOut()
                    let vc = LoginViewController()
                    let nav = UINavigationController(rootViewController: vc)
                    nav.modalPresentationStyle = .fullScreen
                    strongSelf.present(nav, animated: true, completion: nil)
                
                }catch{
                    print("fail to login out")
                }
            }))
            
            actionSheet.addAction(UIAlertAction(title: "Cancle", style: .cancel, handler: nil))
            
            strongSelf.present(actionSheet, animated: true, completion: nil)
            
        }))
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = createTableHeadee()
        
        
       
    }
    
    func createTableHeadee() ->UIView?{
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            return nil
        }
        
        let safeEmail = DatabaseManager.safeEmail(email: email)
        let fileName = "\(safeEmail)_profile_picture.png"
        
        let path = "images/\(fileName)"
       
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.width, height: 300))
        headerView.backgroundColor = .link
        let imageView = UIImageView(frame: CGRect(x: (headerView.width-150)/2, y: 75, width: 150, height: 150))
        imageView.backgroundColor = .white
        imageView.contentMode = .scaleAspectFill
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.layer.borderWidth = 3
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = imageView.width/2
        headerView.addSubview(imageView)
        
        StorageManager.shared.downloadUrl(for: path, completion: {[weak self]result in
            switch result {
            case .success(let url):
               
                imageView.sd_setImage(with: url, completed: nil)
            case .failure(let error):
                print("failed to get download url:\(error)")
            }
         
        })

        return headerView
        
        
    }
    
    
    func downloadImage(imageview:UIImageView,url:URL){
        URLSession.shared.dataTask(with: url, completionHandler: {data, _, error in
            guard let data = data, error == nil else{
                return
            }
            DispatchQueue.main.async {
                let image = UIImage(data: data)
                imageview.image = image
            }
        }).resume()
    }
    

}

extension ProfileViewController : UITableViewDelegate,UITableViewDataSource{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = data[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier, for: indexPath) as! ProfileTableViewCell
        cell.setUp(with: viewModel)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true )
        let viewModel = data[indexPath.row]
        viewModel.handler?()
    }
    
}

class ProfileTableViewCell : UITableViewCell{
    static let identifier = "ProfileTableViewCell"
    public func setUp(with viewModel:ProfileViewModel){
        self.textLabel?.text = viewModel.title
        switch viewModel.viewModelType{
        case .info:
            self.textLabel?.textAlignment = .left
            self.selectionStyle = .none
        case .logout:
            self.textLabel?.textAlignment = .center
            self.textLabel?.textColor = .red
            
        }
    }
}



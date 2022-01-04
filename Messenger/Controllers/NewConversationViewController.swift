//
//  NewConversationViewController.swift
//  Messenger
//
//  Created by zjp on 2021/11/16.
//

import UIKit
import JGProgressHUD

class NewConversationViewController: UIViewController {
    
    
    public var completion: (([String:String]) -> (Void))?
    private let spinner = JGProgressHUD(style: .dark)
    
    private var users = [[String: String]]()
    private var hasFetched = false
    private var results = [[String: String]]()
    
    
    private let searchBar :UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search User"
        return searchBar
    }()
    
    
    private let tableView :UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return table
        
    }()
    
    private let noResultLabel : UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20,weight: .medium)
        label.textColor = .red
        label.textAlignment = .center
        label.text = "No Result"
        label.isHidden = true
        return label
    }()
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        view.addSubview(tableView)
        view.addSubview(noResultLabel)
        
        tableView.delegate = self
        tableView.dataSource = self
    
        searchBar.delegate = self
        navigationController?.navigationBar.topItem?.titleView = searchBar
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancle",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(dismissSelf))
        
        searchBar.becomeFirstResponder()
    }
    
    
    override func viewDidLayoutSubviews() {
        tableView.frame = view.bounds
        noResultLabel.frame = CGRect(x: view.width/4,
                                     y: (view.height - 200)/2,
                                     width: view.width/2,
                                     height: 200)
    }
    
    @objc func dismissSelf(){
        dismiss(animated: true, completion: nil)
    }
    
}



extension NewConversationViewController : UISearchBarDelegate{
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        print("searchBarSearchButtonClicked")
        guard let text = searchBar.text , !text.replacingOccurrences(of: " ", with: "").isEmpty else{
            print("text is empty")
            return
        }
        searchBar.resignFirstResponder()
        results.removeAll()
        spinner.show(in: view)
        self.searchUser(query: text)
    }
    
    

    
    func searchUser(query:String){
        if hasFetched{
            filterUser(with: query)
        }else{
            DatabaseManager.shared.getAllUser(completion: { [weak self]result in
                switch result{
                case .success(let userCollection):
                    self?.hasFetched = true
                    self?.users = userCollection
                    self?.filterUser(with: query)
                case .failure(let error):
                    print("failed to get all users:\(error)")
                }
                
            })
        }
    }
    
    func filterUser(with term :String){
        guard hasFetched ,
        let currentUserEmai = UserDefaults.standard.value(forKey: "email") as? String else{
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: currentUserEmai)
        self.spinner.dismiss(animated: true)
        let  results = self.users.filter({
            guard let email = $0["email"],email != safeEmail else{
                return false
            }
            
            guard let name = $0["name"]?.lowercased() else{
                return false
            }
            return name.hasPrefix(term.lowercased())
        })
        self.results = results
        updateUI()
    }
    
    func updateUI(){
        print("updateui result isEmpty:\(results.isEmpty)")
        if(results.isEmpty){
            noResultLabel.isHidden = false
            tableView.isHidden = true
        }else{
            noResultLabel.isHidden = true
            tableView.isHidden = false
            tableView.reloadData()
        }
    }
    
}


extension NewConversationViewController : UITableViewDelegate,UITableViewDataSource{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = results[indexPath.row]["name"]
        return cell;
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let targetUserData = results[indexPath.row]
        dismiss(animated: true, completion: {[weak self] in
            self?.completion?(targetUserData)
        })
    }
}

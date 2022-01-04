//
//  LoginViewController.swift
//  Messenger
//
//  Created by zjp on 2021/11/16.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

class LoginViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private let imageView : UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "logo")
        
        return imageView
        
    }()
    
    
    
    private let scrollView : UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        
        return scrollView
    }()
    
    

    
    
    private let emailField : UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Email address..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        return field
        
    }()
    
    private let passwordField : UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Password..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        field.isSecureTextEntry = true
        return field
        
    }()
    
    private let loginButton : UIButton = {
        let loginBtn = UIButton()
        
        loginBtn.setTitle("Login", for: .normal)
        loginBtn.backgroundColor = .link
        loginBtn.setTitleColor(.white, for: .normal)
        loginBtn.layer.cornerRadius = 12
        loginBtn.layer.masksToBounds  = true
        loginBtn.titleLabel?.font = .systemFont(ofSize: 20 , weight : .bold)
        
        return loginBtn
        
    }()
    

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Login In"
        view.backgroundColor = .systemBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "register", style: .done, target: self, action: #selector(didTapregister))

        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(loginButton)
        loginButton.addTarget(self, action: #selector(loginButtonTap), for: .touchUpInside)
        
        emailField.delegate = self
        passwordField.delegate = self
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        let size = scrollView.frame.width / 3
        imageView.frame = CGRect(x: (scrollView.frame.width - size)/2,
                                 y: 20,
                                 width: size,
                                 height: size)
        
        emailField.frame = CGRect(x: 30,
                                  y: imageView.bottom + 10 ,
                                  width: scrollView.width - 60,
                                  height: 52)
        passwordField.frame = CGRect(x: 30,
                                     y: emailField.bottom + 10 ,
                                     width: scrollView.width - 60,
                                     height: 52)
        loginButton.frame = CGRect(x: 30,
                                   y: passwordField.bottom + 10,
                                   width: scrollView.width - 60,
                                   height: 52)
        
       
        
    }
    
    
    
    @objc private func loginButtonTap(){
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
        
        guard let email = emailField.text ,let pwd = passwordField.text,
              !email.isEmpty ,!pwd.isEmpty,pwd.count >= 6 else{
                  alertUserLoginErroe()
                   return
              }
        //Firebase Login in
        
        spinner.show(in:view)
        
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: pwd, completion: {[weak self] authResult,error in
            guard let strongSelf = self else{
                return
            }
            DispatchQueue.main.async {
                strongSelf.spinner.dismiss()
            }
            
            guard let result = authResult, error == nil else{
                print("login with email failed, email =\(email)")
                return
            }
             
            let user = result.user
            
            let safeEmail = DatabaseManager.safeEmail(email: email)
            
            DatabaseManager.shared.getDataFor(path: safeEmail, completion: {result in
                switch result{
                case .success(let data):
                    guard let userData = data as? [String:Any],
                          let first_name = userData["first_name"] as? String,
                          let last_name = userData["last_name"] as? String else{
                              return
                          }
                    UserDefaults.standard.set("\(first_name) \(last_name)", forKey: "name")
                case .failure(let error):
                    print("failed to get data :\(error)")
                }
            })
            
            UserDefaults.standard.set(email, forKey: "email")
            print("login in user =\(user)")
            strongSelf.navigationController?.dismiss(animated: true)
        })
    }
    func alertUserLoginErroe(){
        let alert = UIAlertController(title: "woop", message: "Please enter all infomation to login in", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "dismiss", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func didTapregister(){
        let vc = RegisterViewController()
        vc.title = "Create Account"
        navigationController?.pushViewController(vc, animated: true)
    }
    

}

extension LoginViewController : UITextFieldDelegate{
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if(textField == emailField){
            passwordField.becomeFirstResponder()
        }else if(textField == passwordField){
            loginButtonTap()
        }
        
        return true
    }
}

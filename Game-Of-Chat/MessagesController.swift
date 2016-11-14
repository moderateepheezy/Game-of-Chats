//
//  ViewController.swift
//  Game-Of-Chat
//
//  Created by SimpuMind on 11/9/16.
//  Copyright © 2016 SimpuMind. All rights reserved.
//

import UIKit
import Firebase

class MessagesController: UITableViewController {
    
    let cellId = "cellId"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Log Out", style: .plain, target: self, action: #selector(handleLogout))
        
        let image = UIImage(named: "new_message_icon")
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(handleNewMessage))
        
        checkIfUserIsLogin()
        
        tableView.register(UserCell.self, forCellReuseIdentifier: cellId)
        
        tableView.allowsMultipleSelectionDuringEditing = true
    }
    
    var messages = [Message]()
    var messageDictionary = [String: Message]()
    
    func obeserveUserMessages(){
        
        guard let uid = FIRAuth.auth()?.currentUser?.uid else{
            return
        }
        
        let ref = FIRDatabase.database().reference().child("user-messages").child(uid)
        ref.observe(.childAdded, with: { (snapshot) in
            
            let userId = snapshot.key
            FIRDatabase.database().reference().child("user-messages").child(uid).child(userId).observe(.childAdded, with: { (snapshot) in
                
                let messageId = snapshot.key
                
                self.fetchMessageWith(messageId: messageId)
                
            }, withCancel: nil)
            
        }, withCancel: nil)
        
        ref.observe(.childRemoved, with: {(snapshot) in
            
            self.messageDictionary.removeValue(forKey: snapshot.key)
            self.attemptReloadOfTable()
            
        }, withCancel: nil)
    }
    
    fileprivate func fetchMessageWith(messageId: String){
        let messageRef = FIRDatabase.database().reference().child("messages").child(messageId)
        messageRef.observeSingleEvent(of: .value, with: { (snapshot) in
            
            if let dictionary = snapshot.value as? [String: AnyObject]{
                let message = Message()
                message.setValuesForKeys(dictionary)
                self.messages.append(message)
                
                if let chatPatnerId = message.checkPartnerId(){
                    self.messageDictionary[chatPatnerId] = message
                    
                }
                
                self.attemptReloadOfTable()
            }
            
        }, withCancel: nil)
    }
    
    var timer: Timer?
    
    func handleReload(){
        
        self.messages = Array(self.messageDictionary.values)
        self.messages.sort(by: { (message1, message2) -> Bool in
            return message1.timestamp!.intValue > message2.timestamp!.intValue
            
        })
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    fileprivate func attemptReloadOfTable(){
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.handleReload), userInfo: nil, repeats: false)
    }
    
    func obeserveMessages(){
        let ref = FIRDatabase.database().reference().child("messages")
        
        ref.observe(.childAdded, with: { (snapshot) in
            
            if let dictionary = snapshot.value as? [String: AnyObject]{
                let message = Message()
                message.setValuesForKeys(dictionary)
                self.messages.append(message)
                
                if let messgeToId = message.toId{
                    self.messageDictionary[messgeToId] = message
                    
                    self.messages = Array(self.messageDictionary.values)
                    self.messages.sort(by: { (message1, message2) -> Bool in
                        return message1.timestamp!.intValue > message2.timestamp!.intValue
                        
                    })
                }
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
            
        }, withCancel: nil)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return messages.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! UserCell
        
        cell.message = messages[indexPath.row]

        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
            let message = self.messages[indexPath.row]
            
            guard let partnerId = message.checkPartnerId() else {
                return
            }
            
            let ref = FIRDatabase.database().reference().child("users").child(partnerId)
            ref.observeSingleEvent(of: .value, with: { (snapshot) in
                
                guard let dictionary = snapshot.value as? [String: AnyObject] else {
                    return
                }
                
                let user = User()
                user.setValuesForKeys(dictionary)
                user.id = partnerId
                self.showChatControllerFor(user: user)
                
            }, withCancel: nil)
        
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        
        let message = self.messages[indexPath.row]
        
        guard let uid = FIRAuth.auth()?.currentUser?.uid, let chatPartnerId = message.checkPartnerId() else {
            return
        }
        
        FIRDatabase.database().reference().child("user-messages").child(uid).child(chatPartnerId).removeValue { (error, ref) in
            
            if error != nil{
                print("Failed to delete message \(error)")
                return
            }
            
            self.messageDictionary.removeValue(forKey: chatPartnerId)
            self.attemptReloadOfTable()
            
            //self.messages.remove(at: indexPath.row)
            //self.tableView.deleteRows(at: [indexPath], with: .automatic )
        }
        
    }
    
    func checkIfUserIsLogin(){
        if FIRAuth.auth()?.currentUser?.uid == nil {
            perform(#selector(handleLogout), with: nil, afterDelay: 0)
        }else{
            fetchUserAndSetupNavbarItemTitle()
        }
    }
    
    func fetchUserAndSetupNavbarItemTitle(){
        
        guard let uid = FIRAuth.auth()?.currentUser?.uid else{
            return
        }
        FIRDatabase.database().reference().child("users").child(uid).observeSingleEvent(of: .value, with: { (snapshot) in
            
            if let dictionary = snapshot.value as? [String: AnyObject]{
                
                let user = User()
                user.id = snapshot.key
                user.setValuesForKeys(dictionary)
                
                self.setupNavBarWithUser(user: user)
            }
            
            
        }, withCancel: nil)
    }
    
    func setupNavBarWithUser(user: User){
        
        messages.removeAll()
        messageDictionary.removeAll()
        tableView.reloadData()
        
        obeserveUserMessages()
        
        let titleView = UIView()
        titleView.frame = CGRect(x: 0, y: 0, width: 100, height: 40)
        
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        titleView.addSubview(containerView)
        
        containerView.centerXAnchor.constraint(equalTo: titleView.centerXAnchor).isActive = true
        containerView.centerYAnchor.constraint(equalTo: titleView.centerYAnchor).isActive = true
        
        
        let profileImageView = UIImageView()
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.layer.cornerRadius = 20
        profileImageView.clipsToBounds = true
        if let profileImageUrl = user.profileImageUrl{
            profileImageView.loadImageWithCache(urlString: profileImageUrl)
        }
        
        containerView.addSubview(profileImageView)
        
        profileImageView.leftAnchor.constraint(equalTo: containerView.leftAnchor).isActive = true
        profileImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        profileImageView.widthAnchor.constraint(equalToConstant: 40).isActive = true
        profileImageView.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        let titleNameLabel = UILabel()
        titleNameLabel.text = user.name
        titleNameLabel.translatesAutoresizingMaskIntoConstraints = false
        titleNameLabel.font = UIFont.boldSystemFont(ofSize: 16)
        
        containerView.addSubview(titleNameLabel)
        titleNameLabel.leftAnchor.constraint(equalTo: profileImageView.rightAnchor, constant: 8).isActive = true
        titleNameLabel.centerYAnchor.constraint(equalTo: profileImageView.centerYAnchor).isActive = true
        titleNameLabel.rightAnchor.constraint(equalTo: containerView.rightAnchor).isActive = true
        titleNameLabel.heightAnchor.constraint(equalTo: profileImageView.heightAnchor).isActive = true
        
        self.navigationItem.titleView = titleView
    }
    
    @objc  func showChatControllerFor(user: User){
        let layout = UICollectionViewFlowLayout()
        let chatLogController = ChatLogController(collectionViewLayout: layout)
        chatLogController.user = user
        navigationController?.pushViewController(chatLogController, animated: true)
    }
    
    @objc fileprivate func handleNewMessage(){
        let newMessageController = NewMessageController()
        newMessageController.messagesController = self
        let navController = UINavigationController(rootViewController: newMessageController)
        present(navController, animated: true, completion: nil)
        
    }
    
    @objc fileprivate func handleLogout(){
    
        do{
            try FIRAuth.auth()?.signOut()
        }catch let err{
            print(err)
        }
        let loginController = LoginController()
        loginController.messagesController = self
        
        present(loginController, animated: true, completion: nil)
    }

}


//
//  ChatLogController.swift
//  Game-Of-Chat
//
//  Created by SimpuMind on 11/10/16.
//  Copyright © 2016 SimpuMind. All rights reserved.
//

import UIKit
import Firebase

class ChatLogController: UICollectionViewController,
            UITextFieldDelegate, UICollectionViewDelegateFlowLayout, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    let cellId = "cellId"
    
    var containerViewButtomAnchor: NSLayoutConstraint?
    
    var user: User?{
        didSet{
            navigationItem.title = user?.name
            
            observeMessages()
        }
    }
    
    var messages = [Message]()
    
    func observeMessages(){
        
        guard let uid = FIRAuth.auth()?.currentUser?.uid, let toId = user?.id else {
            return
        }
        
        let userMessagesRef = FIRDatabase.database().reference().child("user-messages").child(uid).child(toId)
        userMessagesRef.observe(.childAdded, with: { (snapshot) in
            
            let messageId = snapshot.key
            let messagesRef = FIRDatabase.database().reference().child("messages").child(messageId)
            messagesRef.observeSingleEvent(of: .value, with: { (snapshot) in
                
                guard let dictionary = snapshot.value as? [String: AnyObject] else {
                    return
                }
                
                let message = Message()
                //potential of crashing if keys don't match
                message.setValuesForKeys(dictionary)
                
                self.messages.append(message)
                DispatchQueue.main.async {
                    self.collectionView?.reloadData()
                }
                
            }, withCancel: nil)
            
        }, withCancel: nil)
        
    }
    
    let messageInputContainerView: UIView = {
        let view = UIView()
        view.backgroundColor =  .white
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    lazy var inputTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "Enter message..."
        textField.delegate = self
        return textField
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView?.backgroundColor = .white
        collectionView?.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        collectionView?.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        collectionView?.keyboardDismissMode = .interactive
        collectionView?.alwaysBounceVertical = true
        collectionView?.register(ChatMessageCell.self, forCellWithReuseIdentifier: cellId)
        
        //setupInputComponents()
        setupKeyboardObserver()
    }
    
    lazy var inputContainerView: UIView = {
        
        let containerView = UIView()
        containerView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 50)
        containerView.backgroundColor = .white
        
        let uploadImageView = UIImageView()
        uploadImageView.image = UIImage(named: "upload_image_icon")
        uploadImageView.isUserInteractionEnabled = true
        uploadImageView.translatesAutoresizingMaskIntoConstraints = false
        uploadImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleImageUpload)))
        containerView.addSubview(uploadImageView)
        
        uploadImageView.leftAnchor.constraint(equalTo: containerView.leftAnchor).isActive = true
        uploadImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        uploadImageView.widthAnchor.constraint(equalToConstant: 44).isActive = true
        uploadImageView.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
            let sendButton = UIButton(type: .system)
            sendButton.setTitle("Send", for: .normal)
            let titleColor = UIColor(colorLiteralRed: 0, green: 137/255, blue: 249/255, alpha: 1)
            sendButton.setTitleColor(titleColor, for: .normal)
            sendButton.translatesAutoresizingMaskIntoConstraints = false
            sendButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
            sendButton.addTarget(self, action: #selector(handleSend), for: .touchUpInside)
            containerView.addSubview(sendButton)
        
        
        let topBorderView = UIView()
        topBorderView.backgroundColor = UIColor(white: 0.5, alpha: 0.5)
        topBorderView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(self.inputTextField)
        
        containerView.addSubview(topBorderView)
        
        
        topBorderView.leftAnchor.constraint(equalTo: containerView.leftAnchor).isActive = true
        topBorderView.widthAnchor.constraint(equalTo: containerView.widthAnchor).isActive = true
        topBorderView.bottomAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
        topBorderView.heightAnchor.constraint(equalToConstant: 1).isActive = true
        
        sendButton.rightAnchor.constraint(equalTo: containerView.rightAnchor).isActive = true
        sendButton.heightAnchor.constraint(equalTo: containerView.heightAnchor).isActive = true
        sendButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        sendButton.widthAnchor.constraint(equalToConstant: 60).isActive = true
        
        self.inputTextField.leftAnchor.constraint(equalTo: uploadImageView.rightAnchor, constant: 8).isActive = true
        self.inputTextField.heightAnchor.constraint(equalTo: containerView.heightAnchor).isActive = true
        self.inputTextField.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        self.inputTextField.rightAnchor.constraint(equalTo: sendButton.leftAnchor).isActive = true
        
        return containerView

    }()
    
    @objc fileprivate func handleSend(){
        
                let ref = FIRDatabase.database().reference().child("messages")
                let childRef = ref.childByAutoId()
        
                if let text = inputTextField.text, let toId = user?.id{
                    if text != ""{
                    let toId = toId
                    let fromId = FIRAuth.auth()!.currentUser!.uid
                    let timeStamp = NSDate().timeIntervalSince1970
                 let value = ["text": text, "toId": toId, "fromId": fromId, "timestamp": timeStamp] as [String : Any]
                    childRef.updateChildValues(value)
        
                    childRef.updateChildValues(value, withCompletionBlock: { (error, ref) in
                        if error != nil {
                            print("\(error)")
                        }
                        self.inputTextField.text = nil
        
                        let userMessageRef = FIRDatabase.database().reference().child("user-messages").child(fromId).child(toId)
                        let messageId = childRef.key
                        userMessageRef.updateChildValues([messageId: 1])
        
                        let recipientUserMessagesRef = FIRDatabase.database().reference().child("user-messages").child(toId).child(fromId)
                        
                        recipientUserMessagesRef.updateChildValues([messageId: 1])
                    })
                    }
                }
            }

    @objc fileprivate func handleImageUpload(){
        
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        present(imagePickerController, animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        
        
    }
    
    override var inputAccessoryView: UIView? {
        get{
            return inputContainerView
        }
    }
    
    override var canBecomeFirstResponder: Bool{
        return true
    }
    
    func setupKeyboardObserver(){
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    func handleKeyboardWillShow(notification: Notification){
        let keyboardFrame = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as AnyObject).cgRectValue
        let keyboardDuration = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as AnyObject).doubleValue
        
        containerViewButtomAnchor?.constant = -keyboardFrame!.height
        
        UIView.animate(withDuration: keyboardDuration!, animations: {() in
            self.loadViewIfNeeded()
        })
        
    }
    
    func handleKeyboardWillHide(notification: Notification) {
        let keyboardDuration = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as AnyObject).doubleValue
        
        containerViewButtomAnchor?.constant = 0
        
        UIView.animate(withDuration: keyboardDuration!, animations: {() in
            self.loadViewIfNeeded()
        })
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as! ChatMessageCell
        
        let message = messages[indexPath.item]
        cell.message = message
        
        setupCellBubble(cell: cell, message: message)
        
        return cell
    }
    
    fileprivate func setupCellBubble(cell: ChatMessageCell, message: Message){
        
        if let profileImageUrl = self.user?.profileImageUrl{
            cell.profileImageView.loadImageWithCache(urlString: profileImageUrl)
        }
        
        if message.fromId == FIRAuth.auth()?.currentUser?.uid{
            cell.textBubbleView.backgroundColor = ChatMessageCell.blueColor
            cell.messageTextView.textColor = .white
            cell.bubbleViewRightAnchor?.isActive = true
            cell.bubbleViewLeftAnchor?.isActive = false
            cell.profileImageView.isHidden = true
        }else{
            cell.textBubbleView.backgroundColor = ChatMessageCell.grayColor
            cell.messageTextView.textColor = .black
            cell.bubbleViewRightAnchor?.isActive = false
            cell.bubbleViewLeftAnchor?.isActive = true
            cell.profileImageView.isHidden = false
        }
        
        cell.bubbleWidthAnchor?.constant = estimatedFrameForText(text: message.text!).width + 32
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        var height: CGFloat = 80
        if let text = messages[indexPath.item].text{
            height = estimatedFrameForText(text: text).height + 20
        }
        
        let width = UIScreen.main.bounds.width
        
        return CGSize(width: width, height: height)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        collectionView?.collectionViewLayout.invalidateLayout()
    }
    
    fileprivate func estimatedFrameForText(text: String) -> CGRect{
        
        let size = CGSize(width: 200, height: 1000)
        let options = NSStringDrawingOptions.usesFontLeading.union(NSStringDrawingOptions.usesLineFragmentOrigin)
        
        return NSString(string: text).boundingRect(with: size, options: options, attributes: [NSFontAttributeName: UIFont.systemFont(ofSize: 16)], context: nil)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
         handleSend()
        return true
    }
}

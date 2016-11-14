//
//  ChatLogController.swift
//  Game-Of-Chat
//
//  Created by SimpuMind on 11/10/16.
//  Copyright © 2016 SimpuMind. All rights reserved.
//

import UIKit
import Firebase
import MobileCoreServices
import AVFoundation

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
                    
                    if self.messages.count > 0{
                        let indexPath = NSIndexPath(item: self.messages.count - 1, section: 0)
                        
                        self.collectionView?.scrollToItem(at: indexPath as IndexPath, at: .bottom, animated: true)
                    }
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
    
    lazy var inputContainerView: ChatInputContainerView = {
        
        let frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 50)
        let chatInputContainerView = ChatInputContainerView(frame: frame)
        chatInputContainerView.chatLogController = self
        return chatInputContainerView
    }()
    
    @objc func handleSend(){
       
        if let text = inputContainerView.inputTextField.text{
            if text != ""{
                let properties = ["text": text as AnyObject] as [String : AnyObject]
                sendMessageWith(properties: properties)
            }
        }
    }
    
    private func sendMessageWith(properties: [String: AnyObject]){
        let ref = FIRDatabase.database().reference().child("messages")
        let childRef = ref.childByAutoId()
        
        let toId = user!.id!
        let fromId = FIRAuth.auth()!.currentUser!.uid
        let timeStamp = NSDate().timeIntervalSince1970
        
        var values: [String: AnyObject] = ["toId": toId as AnyObject, "fromId": fromId as AnyObject, "timestamp": timeStamp as AnyObject] as [String : AnyObject]
        
        properties.forEach({values[$0] = $1})
        
        childRef.updateChildValues(values, withCompletionBlock: { (error, ref) in
            if error != nil {
                print("\(error)")
            }
            self.inputContainerView.inputTextField.text = nil
            
            let userMessageRef = FIRDatabase.database().reference().child("user-messages").child(fromId).child(toId)
            let messageId = childRef.key
            userMessageRef.updateChildValues([messageId: 1])
            
            let recipientUserMessagesRef = FIRDatabase.database().reference().child("user-messages").child(toId).child(fromId)
            
            recipientUserMessagesRef.updateChildValues([messageId: 1])
        })
    }

    @objc func handleImageUpload(){
        
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.allowsEditing = true
        imagePickerController.mediaTypes = [kUTTypeImage as String, kUTTypeMovie as String]
        present(imagePickerController, animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        if let videoUrl = info[UIImagePickerControllerMediaURL] as? NSURL {
            handleSelectedVideoFor(url: videoUrl)
            
        }else{
            handleImageSelectedFor(info: info as [String : AnyObject])
        }
        
        
        dismiss(animated: true, completion: nil)
        
    }
    
    private func handleSelectedVideoFor(url: NSURL){
        
        let fileName = NSUUID().uuidString + ".mov"
        let uploadTask = FIRStorage.storage().reference().child("message_movies").child(fileName).putFile(url as URL, metadata: nil, completion: { (metadata, error) in
            
            if error != nil{
                print("\(error)")
                return
            }
            
            if let videoUrl = metadata?.downloadURL()?.absoluteString{
                
                if let thumbNailImage = self.thumbNailForImageurlFor(fileUrl: url){
                    
                    self.uploadToFirebaseStorageUsingImage(selectedImage: thumbNailImage, completetion: { (imageUrl) in
                        
                        let properties: [String : AnyObject] = ["imageUrl": imageUrl as AnyObject, "imageWidth" : thumbNailImage.size.width as AnyObject, "imageHeight": thumbNailImage.size.height as AnyObject, "videoUrl": videoUrl as AnyObject]
                        
                        self.sendMessageWith(properties: properties)
                        
                    })
                }
            }
            
        })
        
        uploadTask.observe(.progress, handler: { (snapshot) in
            
            if let completedUnitCount = snapshot.progress?.completedUnitCount{
                self.navigationItem.title = String(completedUnitCount)
            }
            
        })
        
        uploadTask.observe(.success, handler: {(snapshot) in
            
            self.navigationItem.title = self.user?.name
            
        })
        
    }
    
    private func thumbNailForImageurlFor(fileUrl: NSURL) -> UIImage? {
        let asset = AVAsset(url: fileUrl as URL)
        let assestImageGenerator = AVAssetImageGenerator(asset: asset)
        
        do{
            
            let thumbNailCGImage = try assestImageGenerator.copyCGImage(at: CMTimeMake(1, 60), actualTime: nil)
            return UIImage(cgImage: thumbNailCGImage)
        }catch let err {
            print(String(describing: err))
        }
        
        return nil
    }
    
    private func handleImageSelectedFor(info: [String: AnyObject]){
        var selectedImageFromPicker: UIImage?
        
        if let editedImage = info["UIImagePickerControllerEditedImage"] as? UIImage{
            
            selectedImageFromPicker = editedImage
            
        }else if let originalImage = info["UIImagePickerControllerOriginalImage"] as? UIImage {
            selectedImageFromPicker = originalImage
        }
        
        if let selectedImage = selectedImageFromPicker {
            //    profileImageView.image = selectedImage
            uploadToFirebaseStorageUsingImage(selectedImage: selectedImage, completetion: { (imageUrl) in
                self.sendMessageWith(imageUrl: imageUrl, image: selectedImage)
            })
        }

    }
    
    
    fileprivate func uploadToFirebaseStorageUsingImage(selectedImage: UIImage, completetion: @escaping (_ imageUrl: String) -> ()){
        
        let imageName = NSUUID().uuidString
        let ref = FIRStorage.storage().reference().child("message_images").child("\(imageName).jpg")
        if let uploadData = UIImageJPEGRepresentation(selectedImage, 0.2){
            ref.put(uploadData, metadata: nil, completion: { (metadata, error) in
                
                if error != nil{
                    print("Failed to upload image")
                    return
                }
                
                if let imageUrl = metadata?.downloadURL()?.absoluteString{
                    completetion(imageUrl)
                }
                
                print(metadata?.downloadURL()?.absoluteString ?? "notting to do")
            })
        }
        
    }
    
    fileprivate func sendMessageWith(imageUrl: String, image: UIImage){
     
        let properties: [String : AnyObject] = ["imageUrl": imageUrl as AnyObject, "imageWidth" : image.size.width as AnyObject, "imageHeight": image.size.height as AnyObject]
        
        sendMessageWith(properties: properties)
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardDidShow), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    func handleKeyboardDidShow(){
//        if messages.count > 0 {
//            let indexPath = NSIndexPath(item: messages.count - 1, section: 0)
//            
//            collectionView?.scrollToItem(at: indexPath as IndexPath, at: .bottom, animated: true)
//        }
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
        
         cell.chatLogController = self
        
        
        let message = messages[indexPath.item]
        
        cell.message = message
        
        cell.messageTextView.text = message.text
        
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
        
        if let messageImageUrl = message.imageUrl{
            cell.messageImageView.loadImageWithCache(urlString: messageImageUrl)
            cell.messageImageView.isHidden = false
            cell.messageTextView.textColor = .clear
            cell.textBubbleView.backgroundColor = .clear
        }else{
            cell.messageImageView.isHidden = true
        }
        
        if let text = message.text{
            cell.messageTextView.isHidden = false
            cell.bubbleWidthAnchor?.constant = estimatedFrameForText(text: text).width + 32
        }else if message.imageUrl != nil{
            cell.bubbleWidthAnchor?.constant = 200
            cell.messageTextView.isHidden = true
        }
        
        cell.playButton.isHidden = message.videoUrl == nil
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        var height: CGFloat = 80
        
        let message = messages[indexPath.item]
        
        if let text = message.text{
            height = estimatedFrameForText(text: text).height + 20
        }else if let imageWith = message.imageWidth?.floatValue, let imageHeight = message.imageHeight?.floatValue{
            
            //h1 / w1 = h2/ w2
            //solve for h1
            //h1 = h2 / w2 * w1
            height = CGFloat(imageHeight / imageWith * 200)
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
    
    
    var startingFrame: CGRect?
    var blackBackground: UIView?
    var startingImageView: UIImageView?
    
    // zooming logic
    func performZoomfor(startingImageView: UIImageView){
        
        self.startingImageView = startingImageView
        self.startingImageView?.isHidden = true
        
         startingFrame = startingImageView.superview?.convert(startingImageView.frame, to: nil)
        
        let zoomingImageView = UIImageView(frame: startingFrame!)
        zoomingImageView.backgroundColor = .red
        zoomingImageView.image = startingImageView.image
        zoomingImageView.isUserInteractionEnabled = true
        zoomingImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleZoomOut)))
        
        if let keyWindow = UIApplication.shared.keyWindow{
            
            
            blackBackground = UIView(frame: keyWindow.frame)
            blackBackground?.alpha = 0
            blackBackground?.backgroundColor = .black
            
            keyWindow.addSubview(blackBackground!)
            keyWindow.addSubview(zoomingImageView)
            
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
                
                self.blackBackground?.alpha = 1
                self.inputContainerView.alpha = 0
                
                //math?
                // h2 / w1 = h2 / w2
                //hw = h1 / w1 * w1
                
                let height = self.startingFrame!.height / self.startingFrame!.width * keyWindow.frame.width
                
                zoomingImageView.frame = CGRect(x: 0, y: 0, width: keyWindow.frame.width, height: height)
                
                zoomingImageView.center = keyWindow.center
                
            }, completion: nil)
        }
        
    }
    
    func handleZoomOut(tapGesture: UIGestureRecognizer){
        if let zoomOutImageView = tapGesture.view{
            
            zoomOutImageView.layer.cornerRadius = 16
            zoomOutImageView.clipsToBounds = true
            
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: { 
                
                zoomOutImageView.frame = self.startingFrame!
                self.blackBackground?.alpha = 0
                self.inputContainerView.alpha = 1
                
            }, completion: { (completed: Bool) in
                self.startingImageView?.isHidden = false
                zoomOutImageView.removeFromSuperview()
                self.blackBackground?.removeFromSuperview()
            })
        }
    }
}

//
//  LoginController+handlers.swift
//  Game-Of-Chat
//
//  Created by SimpuMind on 11/10/16.
//  Copyright © 2016 SimpuMind. All rights reserved.
//

import UIKit
import Firebase

extension LoginController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func handleSelectProfileImageView(){
        
        let picker = UIImagePickerController()
        
        picker.delegate = self
        picker.allowsEditing = true
        
        present(picker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        var selectedImageFromPicker: UIImage?
        
        if let editedImage = info["UIImagePickerControllerEditedImage"] as? UIImage{
            
            selectedImageFromPicker = editedImage
            
        }else if let originalImage = info["UIImagePickerControllerOriginalImage"] as? UIImage {
            selectedImageFromPicker = originalImage
        }
        
        if let selectedImage = selectedImageFromPicker {
            profileImageView.image = selectedImage
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func handleRegister(){
        
        guard let email = emailTextField.text, let password = passwordTextField.text, let name = nameTextField.text else{
            return
        }
        
        FIRAuth.auth()?.createUser(withEmail: email, password: password, completion: { (user, error) in
            
            if error != nil{
                print("\(error)")
                return
            }
            
            
            guard let uid = user?.uid else{
                return
            }
            
            let imageName = NSUUID().uuidString
            
            let storageRef = FIRStorage.storage().reference().child("profile_images").child("\(imageName).jpg")
            
            if let profileImage = self.profileImageView.image, let uploadData = UIImageJPEGRepresentation(profileImage, 0.1){
                storageRef.put(uploadData, metadata: nil, completion: { (metadata, error) in
                    
                    if error != nil{
                        print("\(error)")
                        return
                    }
                    
                    if let profileImage = metadata?.downloadURL()?.absoluteString{
                        let values = ["name": name, "email": email, "profileImageUrl": profileImage]
                        
                        self.registerUserIntoDbWith(uid: uid, values: values as [String : AnyObject])
                    }
                    
                    
                })
            }
            
            
        })
    }
    
    fileprivate func registerUserIntoDbWith(uid: String, values: [String: AnyObject]){
        
        let ref = FIRDatabase.database().reference()
        
        let userRef = ref.child("users").child(uid)
        
        userRef.updateChildValues(values, withCompletionBlock: { (err, ref) in
            
            if err != nil{
                print("\(err)")
                return
            }
            
            let  user = User()
            user.setValuesForKeys(values)
            self.messagesController?.setupNavBarWithUser(user: user)
            self.dismiss(animated: true, completion: nil)
            
            print("Save user successfully in the Firebase db.")
        })
    }

}

//
//  Extensions.swift
//  Game-Of-Chat
//
//  Created by SimpuMind on 11/10/16.
//  Copyright © 2016 SimpuMind. All rights reserved.
//

import UIKit

let imageCache = NSCache<AnyObject, AnyObject>()

extension UIImageView{
    
    func loadImageWithCache(urlString: String){
        
        self.image = nil
        
        if let cacheImage = imageCache.object(forKey: urlString as AnyObject) as? UIImage{
            self.image = cacheImage
        }else{
            let url = NSURL(string: urlString)
            
            URLSession.shared.dataTask(with: url! as URL, completionHandler: { (data, response, error) in
                
                if error != nil{
                    print("\(error)")
                    return
                }
                DispatchQueue.main.async {
                    
                    if let imageDownload =  UIImage(data: data!){
                        imageCache.setObject(imageDownload, forKey: urlString as AnyObject)
                        self.image = imageDownload
                    }
                }
                
            }).resume()
        }
    }
}

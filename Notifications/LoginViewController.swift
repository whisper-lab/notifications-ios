//
//  LoginViewController.swift
//  Notifications
//
//  Created by Alexey Pustobaev on 24/02/15.
//  Copyright (c) 2015 WhisperLab. All rights reserved.
//

import UIKit

class LoginViewController: UIViewController {

    @IBOutlet weak var txtEmail: UITextField!
    
    @IBOutlet weak var txtPassword: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func signinTapped(sender: UIButton) {
        var email:NSString = txtEmail.text
        var password:NSString = txtPassword.text
        
        if ( email.isEqualToString("") || password.isEqualToString("") ) {
            
            var alertView:UIAlertView = UIAlertView()
            alertView.title = "Sign in Failed!"
            alertView.message = "Please enter Email and Password"
            alertView.delegate = self
            alertView.addButtonWithTitle("OK")
            alertView.show()
        } else {
            
            var params = ["email":email, "password":password]
            println("PostData: \(params)")
            
            // Correct url and username/password
            self.post(params, withTokenStr: GlobalConstants.API_MASTER_KEY, url: GlobalConstants.LOGIN_URL) { (succeeded: Bool, msg: String, json: NSDictionary?) -> () in
                var alert = UIAlertView(title: "Success!", message: msg, delegate: nil, cancelButtonTitle: "OK")
                // Move to the UI thread
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    if(succeeded) {
                        println("SUCCESS");
                        var api_key = msg
                        
                        var prefs:NSUserDefaults = NSUserDefaults.standardUserDefaults()
                        prefs.setObject(email, forKey: "EMAIL")
                        prefs.setInteger(1, forKey: "ISLOGGEDIN")
                        prefs.setObject(api_key, forKey: "API_KEY")
                        prefs.synchronize()
                        
                        self.dismissViewControllerAnimated(true, completion: nil)
                    }
                    else {
                        alert.title = "Sign in Failed!"
                        alert.message = msg
                        // Show the alert
                        alert.show()
                    }
                })
            }
        }
    }
    
    func post(params : Dictionary<String, AnyObject>, withTokenStr tokenStr : String? = nil, url : String, postCompleted : (succeeded: Bool, msg: String, json: NSDictionary?) -> ()) {
        var request = NSMutableURLRequest(URL: NSURL(string: url)!)
        var session = NSURLSession.sharedSession()
        
        var err: NSError?
        var postData:NSData? = NSJSONSerialization.dataWithJSONObject(params, options: nil, error: &err)
        var postLength:NSString = String( postData!.length )
        
        request.HTTPMethod = "POST"
        request.HTTPBody = postData
        request.setValue(postLength, forHTTPHeaderField: "Content-Length")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        if let token = tokenStr {
            request.addValue("Token token=\"\(token)\"", forHTTPHeaderField: "Authorization")
        }
        
        var task = session.dataTaskWithRequest(request, completionHandler: {data, response, error -> Void in
            println("Response: \(response)")
            
            let res = response as NSHTTPURLResponse!
            if (res != nil) {
                NSLog("Response code: %ld", res.statusCode)
            }
            
            if (error == nil /*&& res.statusCode >= 200 && res.statusCode < 300*/) {
                var strData = NSString(data: data, encoding: NSUTF8StringEncoding)
                println("Body: \(strData)")
                var err: NSError?
                var json = NSJSONSerialization.JSONObjectWithData(data, options: .MutableLeaves, error: &err) as? NSDictionary
                
                var msg = "No message"
                
                // Did the JSONObjectWithData constructor return an error? If so, log the error to the console
                if(err != nil) {
                    println(err!.localizedDescription)
                    let jsonStr = NSString(data: data, encoding: NSUTF8StringEncoding)
                    var message = ""
                    if let str = jsonStr {
                      message = str
                    }
                    println("Error could not parse JSON: '\(jsonStr)'")
                    postCompleted(succeeded: false, msg: message, json: nil)
                }
                else {
                    // The JSONObjectWithData constructor didn't return an error. But, we should still
                    // check and make sure that json has a value using optional binding.
                    if let parseJSON = json {
                        // Okay, the parsedJSON is here, let's get the value for 'success' out of it
                        //                        if let success = parseJSON["success"] as? Bool {
                        if (res.statusCode >= 200 && res.statusCode < 300) {
                            var api_key:String = ""
                            if let key = parseJSON["api_key"] as? String {
                                api_key = key
                            }
                            if !api_key.isEmpty {
                                println("Succes")
                                postCompleted(succeeded: true, msg: api_key, json: parseJSON)
                            }
                            else {
                                postCompleted(succeeded: false, msg: "Error", json: nil)
                            }
                        }
                        else {
                            var message = "Connection Failure"
                            for (key, value) in parseJSON {
                                if let val = value as? Array<String> {
                                    if (!val.isEmpty) {
                                        message = "\(key): \(val[0])"
                                    }
                                }
                            }
                            postCompleted(succeeded: false, msg: message, json: nil)
                        }
                        return
                    }
                    else {
                        // Woa, okay the json object was nil, something went worng. Maybe the server isn't running?
                        let jsonStr = NSString(data: data, encoding: NSUTF8StringEncoding)
                        println("Error could not parse JSON: \(jsonStr)")
                        postCompleted(succeeded: false, msg: "Error", json: nil)
                    }
                }
            }
            else {
                var message = "Connection Failure"
                if let err = error {
                    message = (err.localizedDescription)
                }
                println(message)
                postCompleted(succeeded: false, msg: "Error", json: nil)
            }
            
            
        })
        
        task.resume()
    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

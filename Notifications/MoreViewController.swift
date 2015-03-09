//
//  MoreViewController.swift
//  Notifications
//
//  Created by Alexey Pustobaev on 24/02/15.
//  Copyright (c) 2015 WhisperLab. All rights reserved.
//

import UIKit

class MoreViewController: UIViewController {

    @IBOutlet weak var nameLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(true)
        let prefs:NSUserDefaults = NSUserDefaults.standardUserDefaults()
        let isLoggedIn:Int = prefs.integerForKey("ISLOGGEDIN") as Int
        if (isLoggedIn == 1) {
            var str = ""
            if let name = prefs.stringForKey("NAME") {
                str += name
                str += "\nemail: "
            }
            if let email = prefs.stringForKey("EMAIL") {
                str += email
            }
            self.nameLabel.text = str
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func logoutTapped(sender: UIButton) {
        let prefs:NSUserDefaults = NSUserDefaults.standardUserDefaults()
        var logoutPending:Array? = prefs.arrayForKey("LOGOUT_PENDING")
        if logoutPending == nil {
            logoutPending = []
        }
        
        let isDeviceRegistered:Int = prefs.integerForKey("IS_DEVICE_REGISTERED") as Int
        if isDeviceRegistered == 1 {
            let id = prefs.integerForKey("ID")
            let deviceId = prefs.integerForKey("DEVICE_ID")
            let deviceToken = prefs.stringForKey("DEVICE_TOKEN")!
            let email = prefs.stringForKey("EMAIL")!
            let api_key = prefs.stringForKey("API_KEY")!
            let item = ["ID": id, "DEVICE_ID": deviceId, "DEVICE_TOKEN": deviceToken, "EMAIL": email, "API_KEY": api_key]
            logoutPending!.append(item)
        }
        
        let appDomain = NSBundle.mainBundle().bundleIdentifier
        NSUserDefaults.standardUserDefaults().removePersistentDomainForName(appDomain!)
        
        prefs.setObject(logoutPending!, forKey: "LOGOUT_PENDING")
        prefs.synchronize()
        
        let delegate = UIApplication.sharedApplication().delegate as AppDelegate
        let tabBarViewController = delegate.window!.rootViewController as UITabBarController
        
        NSNotificationCenter.defaultCenter().postNotificationName(GlobalConstants.LoginStateDidChangeNotification, object: self)
        
        tabBarViewController.performSegueWithIdentifier("goto_login", sender: self)
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

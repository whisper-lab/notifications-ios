//
//  TabBarController.swift
//  Notifications
//
//  Created by Alexey Pustobaev on 25/02/15.
//  Copyright (c) 2015 WhisperLab. All rights reserved.
//

import UIKit

class TabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(true)
        
        let prefs:NSUserDefaults = NSUserDefaults.standardUserDefaults()
        let isLoggedIn:Int = prefs.integerForKey("ISLOGGEDIN") as Int
        if (isLoggedIn != 1) {
            let delegate = UIApplication.sharedApplication().delegate as AppDelegate
            let tabBarViewController = delegate.window!.rootViewController as UITabBarController
            tabBarViewController.performSegueWithIdentifier("goto_login", sender: self)
        } else {
            //            self.nameLabel.text = prefs.valueForKey("USERNAME") as NSString
        }
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

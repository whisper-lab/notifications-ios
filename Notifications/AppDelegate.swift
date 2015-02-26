//
//  AppDelegate.swift
//  Notifications
//
//  Created by Alexey Pustobaev on 16/02/15.
//  Copyright (c) 2015 WhisperLab. All rights reserved.
//

import UIKit
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    var window: UIWindow?
    var loginStateDidChangeObserver:NSObjectProtocol?
    var deviceToken: NSData?


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        let tabBarViewController = self.window!.rootViewController as UITabBarController
        let splitViewController = tabBarViewController.viewControllers![0] as UISplitViewController
        let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as UINavigationController
        navigationController.topViewController.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem()
        splitViewController.delegate = self

        let masterNavigationController = splitViewController.viewControllers[0] as UINavigationController
        let controller = masterNavigationController.topViewController as MasterViewController
        controller.managedObjectContext = self.managedObjectContext
        
        
        //registering for sending user various kinds of notifications
        application.registerUserNotificationSettings(UIUserNotificationSettings(
            forTypes: UIUserNotificationType.Sound|UIUserNotificationType.Alert|UIUserNotificationType.Badge,
            categories: nil))
        
        var localNotification:UILocalNotification = UILocalNotification()
        localNotification.alertAction = "Testing notifications on iOS8"
        localNotification.alertBody = "Woww it works!!"
        localNotification.fireDate = NSDate(timeIntervalSinceNow: 30)
        UIApplication.sharedApplication().scheduleLocalNotification(localNotification)
        
//        UIApplication.sharedApplication().registerUserNotificationSettings(UIRemoteNotificationType.Alert|UIRemoteNotificationType.Badge|UIRemoteNotificationType.Sound)
        UIApplication.sharedApplication().registerForRemoteNotifications()
        
        loginStateDidChangeObserver = NSNotificationCenter.defaultCenter().addObserverForName(GlobalConstants.LoginStateDidChangeNotification, object: nil, queue: nil) { (note:NSNotification!) -> Void in
            let prefs:NSUserDefaults = NSUserDefaults.standardUserDefaults()
            let isLoggedIn:Int = prefs.integerForKey("ISLOGGEDIN") as Int
            if (isLoggedIn == 1) {
                self.registerDeviceForUser()
            }
            else {
                self.unregisterDeviceForUser()
            }
        }
        
        
        return true
    }
    
    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        self.deviceToken = deviceToken
        
        //        NSLog(@"Got device token: %@", [devToken description]);
        let devToken = deviceToken.description.stringByReplacingOccurrencesOfString("<", withString: "")
                                              .stringByReplacingOccurrencesOfString(">", withString: "")
                                              .stringByReplacingOccurrencesOfString(" ", withString: "")
        println("Got device token: \(deviceToken.description)")
        println("--")
        println("\(devToken)")
        var tokenString = deviceTokenString(deviceToken)
        println(tokenString)
        println("--")
        
        let prefs:NSUserDefaults = NSUserDefaults.standardUserDefaults()
        let isLoggedIn:Int = prefs.integerForKey("ISLOGGEDIN") as Int
        if (isLoggedIn == 1) {
            self.registerDeviceForUser(); // custom method; e.g., send to a web service and store
        }
    }
    
    func deviceTokenString(devToken:NSData) -> String {
        var tokenChars = UnsafePointer<CChar>(devToken.bytes)
        var tokenString = ""
        for var i = 0; i < devToken.length; i++ {
            tokenString += String(format: "%02.2hhx", arguments: [tokenChars[i]])
        }
        return tokenString
    }
    
    func sendProviderDeviceToken() {
        if let devToken = deviceToken {
            var tokenString = deviceTokenString(devToken)
            println(tokenString)
        }
    }
    
    func registerDeviceForUser() {
        if let devToken = deviceToken {
            println("register")
            var tokenString = deviceTokenString(devToken)
            
            let prefs:NSUserDefaults = NSUserDefaults.standardUserDefaults()
            let api_key = prefs.stringForKey("API_KEY")!
            let email = prefs.stringForKey("EMAIL")!
            let id = 2
    
            var params = ["user": ["device_attributes": ["token":tokenString, "platform":"ios"]]]
            println("PatchData: \(params)")
            
            // Correct url and username/password
            self.patch(params, withTokenStr: "\(email):\(api_key)", url: GlobalConstants.USERS_URL+"/\(id)") { (succeeded: Bool, msg: String, data: NSDictionary?) -> () in
                
                // Move to the UI thread
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    if(succeeded) {
                        println("register SUCCESS");
                        if let d = data {
                            println(d)
                        }
                    }
                    else {
                        println("register failed");
                        if let d = data {
                            println(d)
                        }
                    }
                })
            }
        }
        else {
            println("register: failed - divece token == nil")
        }
    }
    
    func unregisterDeviceForUser() {
        println("unregister")
    }
    
    func patch(params : Dictionary<String, AnyObject>, withTokenStr tokenStr : String? = nil, url : String, postCompleted : (succeeded: Bool, msg: String, json: NSDictionary?) -> ()) {
        var request = NSMutableURLRequest(URL: NSURL(string: url)!)
        var session = NSURLSession.sharedSession()
        
        var err: NSError?
        var postData:NSData? = NSJSONSerialization.dataWithJSONObject(params, options: nil, error: &err)
        var postLength:NSString = String( postData!.length )
        
        request.HTTPMethod = "PATCH"
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
                    println("Error could not parse JSON: '\(jsonStr)'")
                    postCompleted(succeeded: false, msg: "Error", json: nil)
                }
                else {
                    // The JSONObjectWithData constructor didn't return an error. But, we should still
                    // check and make sure that json has a value using optional binding.
                    if let parseJSON = json {
                        // Okay, the parsedJSON is here, let's get the value for 'success' out of it
                        //                        if let success = parseJSON["success"] as? Bool {
                        if (res.statusCode >= 200 && res.statusCode < 300) {
                            println("Succes")
                            postCompleted(succeeded: true, msg: "Updated", json: parseJSON)
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

    
    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        println("Error in registration. Error: \(error)")
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }

    // MARK: - Split view

    func splitViewController(splitViewController: UISplitViewController, collapseSecondaryViewController secondaryViewController:UIViewController!, ontoPrimaryViewController primaryViewController:UIViewController!) -> Bool {
        if let secondaryAsNavController = secondaryViewController as? UINavigationController {
            if let topAsDetailController = secondaryAsNavController.topViewController as? DetailViewController {
                if topAsDetailController.detailItem == nil {
                    // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
                    return true
                }
            }
        }
        return false
    }
    // MARK: - Core Data stack

    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.whisperlab.Notifications" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1] as NSURL
    }()

    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle.mainBundle().URLForResource("Notifications", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
    }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("Notifications.sqlite")
        var error: NSError? = nil
        var failureReason = "There was an error creating or loading the application's saved data."
        if coordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil, error: &error) == nil {
            coordinator = nil
            // Report any error we got.
            let dict = NSMutableDictionary()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            dict[NSUnderlyingErrorKey] = error
            error = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(error), \(error!.userInfo)")
            abort()
        }
        
        return coordinator
    }()

    lazy var managedObjectContext: NSManagedObjectContext? = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        var managedObjectContext = NSManagedObjectContext()
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        if let moc = self.managedObjectContext {
            var error: NSError? = nil
            if moc.hasChanges && !moc.save(&error) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog("Unresolved error \(error), \(error!.userInfo)")
                abort()
            }
        }
    }

}


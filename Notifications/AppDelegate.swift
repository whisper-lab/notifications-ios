//
//  AppDelegate.swift
//  Notifications
//
//  Created by Alexey Pustobaev on 16/02/15.
//  Copyright (c) 2015 WhisperLab. All rights reserved.
//

import UIKit
import CoreData

var reachability: Reachability?

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    var window: UIWindow?
    var loginStateDidChangeObserver:NSObjectProtocol?
    var reachabilityDidChangeObserver:NSObjectProtocol?
    var deviceToken: NSData?
    var internetReach: Reachability?


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
        
        reachabilityDidChangeObserver = NSNotificationCenter.defaultCenter().addObserverForName(kReachabilityChangedNotification, object: nil, queue: nil) { (note:NSNotification!) -> Void in
            println("Reachability Status Changed...")
            reachability = note.object as? Reachability
            self.statusChangedWithReachability(reachability!)
        }

        internetReach = Reachability.reachabilityForInternetConnection()
        internetReach?.startNotifier()
        if internetReach != nil {
            self.statusChangedWithReachability(internetReach!)
        }
        
        return true
    }
    
    func statusChangedWithReachability(currentReachabilityStatus: Reachability) {
        var networkStatus: NetworkStatus = currentReachabilityStatus.currentReachabilityStatus()
        var statusString: String = ""
        println("StatusValue: \(networkStatus.value)")
        if networkStatus.value != NotReachable.value {
            let prefs:NSUserDefaults = NSUserDefaults.standardUserDefaults()
            let isLoggedIn:Int = prefs.integerForKey("ISLOGGEDIN") as Int
            if (isLoggedIn == 1) {
                self.registerDeviceForUser()
            }
            else {
            }
            self.unregisterDeviceForUser()
        }
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
    
    func registerDeviceForUser(retryCounter:Int = 4) {
        if let devToken = deviceToken {
            println("register")
            var token = deviceTokenString(devToken)
            
            registerDeviceWithRetryCounter(retryCounter+1, deviceTokenString: token)
        }
        else {
            println("register: failed - divece token == nil")
        }
    }
    
    func registerDeviceWithRetryCounter(var counter:Int, deviceTokenString token: String) {
        if (counter == 0) {
            return;
        }
        counter--
        
        let prefs:NSUserDefaults = NSUserDefaults.standardUserDefaults()
        let api_key = prefs.stringForKey("API_KEY")!
        let email = prefs.stringForKey("EMAIL")!
        let id = prefs.integerForKey("ID")
        
        var params = ["user": ["device_attributes": ["token":token, "platform":"ios"]]]
        println("PatchData: \(params)")
        
        // Correct url and username/password
        self.patch(params, withTokenStr: "\(email):\(api_key)", url: GlobalConstants.USERS_URL+"/\(id)") { [weak self] (succeeded: Bool, msg: String, json: [String : AnyObject]?) -> () in
            
            // Move to the UI thread
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                if(succeeded) {
                    println("register SUCCESS");
                    if let d = json {
                        println(d)
                    }
                }
                else {
                    println("register failed");
                    if let d = json {
                        println(d)
                    }
                }
            })
            if succeeded {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    var prefs:NSUserDefaults = NSUserDefaults.standardUserDefaults()
                    let name = json!["name"]! as String
                    prefs.setObject(name, forKey: "NAME")
                    if let device = json!["device"] as? [String : AnyObject] {
                        // safe to use user
                        let deviceId = device["id"]! as Int
                        let deviceReceivedToken = device["token"]! as String
                        let devicePlatform = device["platform"]! as String
                        prefs.setInteger(deviceId, forKey: "DEVICE_ID")
                        prefs.setInteger(1, forKey: "IS_DEVICE_REGISTERED")
                        prefs.setObject(deviceReceivedToken, forKey: "DEVICE_TOKEN")
                        prefs.setObject(devicePlatform, forKey: "DEVICE_PLATFORM")
                    }
                    else {
                        println("...with no device info")
                    }
                    prefs.synchronize()
                })
            }
            else {
                let delayInSeconds = 5.0
                println("second retry after.. \(delayInSeconds) s")
                println("retries left: \(counter)");
                let delayInNanoSeconds = dispatch_time(DISPATCH_TIME_NOW, Int64(delayInSeconds * Double(NSEC_PER_SEC)))
                let concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
                dispatch_after(delayInNanoSeconds, concurrentQueue, {
                    /* Perform your operations here */
                    println("Retry...");
                    self?.registerDeviceWithRetryCounter(counter, deviceTokenString: token)
                })
            }
        }

    }
    
    func unregisterDeviceForUser() {
        let prefs:NSUserDefaults = NSUserDefaults.standardUserDefaults()
        if let logoutPending = prefs.arrayForKey("LOGOUT_PENDING") as Array? {
            println("unregister")
            println("\(logoutPending)")
            
            for item in logoutPending {
                if let logoutItem = item as? Dictionary<String, AnyObject> {
                    unregisterLogoutPendingItemWithRetryCounter(5, logoutPendingItem: logoutItem)
                }
            }
        }
        else {
            println("nothing to unregister")
        }
    }
    
    func unregisterLogoutPendingItemWithRetryCounter(var counter:Int, logoutPendingItem item:Dictionary<String, AnyObject>) {
        if (counter == 0) {
            return
        }
        counter--
        
        let id = item["ID"] as Int
        let deviceId = item["DEVICE_ID"] as Int
        let deviceToken = item["DEVICE_TOKEN"] as String
        let email = item["EMAIL"] as String
        let api_key = item["API_KEY"] as String
        
        var params = ["device": ["token":deviceToken]]
        println("DeleteData: \(params)")
        
        // Correct url and username/password
        self.delete(params, withTokenStr: "\(email):\(api_key)", url: GlobalConstants.USERS_URL+"/\(id)/devices/\(deviceId)") { [weak self] (succeeded: Bool, msg: String, json: [String : AnyObject]?) -> () in
            if(succeeded) {
                println("pending unregister SUCCESS");
                if let d = json {
                    println(d)
                }
                self?.removeLogoutPendingItemWith(id: id, deviceId: deviceId)
            }
            else {
                println("pending unregister failed");
                var q = false
                if let d = json {
                    println(d)
                    if d["message"] as String == "Forbidden" {
                        self?.removeLogoutPendingItemWith(id: id, deviceId: deviceId)
                        q = true
                    }
                }
                if !q {
                    let delayInSeconds = 5.0
                    println("second retry after.. \(delayInSeconds) s")
                    println("retries left: \(counter)");
                    let delayInNanoSeconds = dispatch_time(DISPATCH_TIME_NOW, Int64(delayInSeconds * Double(NSEC_PER_SEC)))
                    let concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
                    dispatch_after(delayInNanoSeconds, concurrentQueue, {
                        /* Perform your operations here */
                        println("Retry...");
                        self?.unregisterLogoutPendingItemWithRetryCounter(counter, logoutPendingItem: item)
                    })
                }
            }
        }
    }
    
    func removeLogoutPendingItemWith(#id:Int, deviceId:Int) {
        // Move to the UI thread
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            let prefs:NSUserDefaults = NSUserDefaults.standardUserDefaults()
            if let logoutPending = prefs.arrayForKey("LOGOUT_PENDING") as Array? {
                let arr = logoutPending.filter() { (item:AnyObject) -> Bool in
                    if let itemDict = item as? Dictionary<String, AnyObject> {
                        return itemDict["ID"] as Int != id || itemDict["DEVICE_ID"] as Int != deviceId
                    }
                    return false
                }
                prefs.setObject(arr, forKey: "LOGOUT_PENDING")
            }
            prefs.synchronize()
        })
    }
    
    func get(params : Dictionary<String, AnyObject>, withTokenStr tokenStr : String? = nil, url : String, postCompleted : (succeeded: Bool, msg: String, json: [String : AnyObject]?) -> ()) {
        httpRequestWithMethod("GET", params: params, withTokenStr: tokenStr, url: url, postCompleted: postCompleted);
    }
    
    func post(params : Dictionary<String, AnyObject>, withTokenStr tokenStr : String? = nil, url : String, postCompleted : (succeeded: Bool, msg: String, json: [String : AnyObject]?) -> ()) {
        httpRequestWithMethod("POST", params: params, withTokenStr: tokenStr, url: url, postCompleted: postCompleted);
    }
    
    func patch(params : Dictionary<String, AnyObject>, withTokenStr tokenStr : String? = nil, url : String, postCompleted : (succeeded: Bool, msg: String, json: [String : AnyObject]?) -> ()) {
        httpRequestWithMethod("PATCH", params: params, withTokenStr: tokenStr, url: url, postCompleted: postCompleted);
    }
    
    func put(params : Dictionary<String, AnyObject>, withTokenStr tokenStr : String? = nil, url : String, postCompleted : (succeeded: Bool, msg: String, json: [String : AnyObject]?) -> ()) {
        httpRequestWithMethod("PUT", params: params, withTokenStr: tokenStr, url: url, postCompleted: postCompleted);
    }
    
    func delete(params : Dictionary<String, AnyObject>, withTokenStr tokenStr : String? = nil, url : String, postCompleted : (succeeded: Bool, msg: String, json: [String : AnyObject]?) -> ()) {
        httpRequestWithMethod("DELETE", params: params, withTokenStr: tokenStr, url: url, postCompleted: postCompleted);
    }
    
    func httpRequestWithMethod(method:String, params : Dictionary<String, AnyObject>, withTokenStr tokenStr : String? = nil, url : String, postCompleted : (succeeded: Bool, msg: String, json: [String : AnyObject]?) -> ()) {
        var request = NSMutableURLRequest(URL: NSURL(string: url)!)
        var session = NSURLSession.sharedSession()
        
        var err: NSError?
        var postData:NSData? = NSJSONSerialization.dataWithJSONObject(params, options: nil, error: &err)
        var postLength:NSString = String( postData!.length )
        
        request.HTTPMethod = method
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
                var json = NSJSONSerialization.JSONObjectWithData(data, options: .MutableLeaves, error: &err) as? [String : AnyObject]
                
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
                            println("Success")
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
                            postCompleted(succeeded: false, msg: message, json: parseJSON)
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
        NSNotificationCenter.defaultCenter().removeObserver(self.loginStateDidChangeObserver!)
        NSNotificationCenter.defaultCenter().removeObserver(self.reachabilityDidChangeObserver!)
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


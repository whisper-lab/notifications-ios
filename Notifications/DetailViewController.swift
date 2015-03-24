//
//  DetailViewController.swift
//  Notifications
//
//  Created by Alexey Pustobaev on 16/02/15.
//  Copyright (c) 2015 WhisperLab. All rights reserved.
//

import UIKit
import CoreData

class DetailViewController: UIViewController {

    @IBOutlet weak var messagesTextView: UITextView!

    var detailItem: AnyObject? {
        didSet {
            // Update the view.
            self.configureView()
        }
    }

    func configureView() {
        // Update the user interface for the detail item.
        if let detail = self.detailItem as? NSManagedObject {
            if let label = self.messagesTextView {
                let id = detail.valueForKey("id") as Int
                let name = detail.valueForKey("name") as String
                self.title = "\(id): \(name)"
                
                let enumerator = detail.mutableOrderedSetValueForKey("messages").reverseObjectEnumerator()

                var text = ""
                while let message = enumerator.nextObject() as? NSManagedObject {
                    let message_id = message.valueForKey("id") as Int
                    let message_body = message.valueForKey("body") as String
                    let message_date = message.valueForKey("date") as NSDate
                    text += "\n#\(message_id)\n"
                    text += message_body + "\n"
                    text += message_date.description + "\n----------------------------\n"
                }
                label.text = text
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.configureView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}


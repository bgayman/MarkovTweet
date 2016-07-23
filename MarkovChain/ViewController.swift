//
//  ViewController.swift
//  MarkovChain
//
//  Created by Brad G. on 7/21/16.
//  Copyright © 2016 Brad G. All rights reserved.
//

import UIKit
import GameplayKit
import ObjectiveC
import Social
import Accounts

class ViewController: UITableViewController
{

    @IBOutlet weak var textField: UITextField!
    
    var profileImage: UIImage?
    var fakeTweets = [String]()
    
    let trailingPunctuation = [".", "?", "!", "\\"]
    
    private var texts: MarkovChainMachine!
    {
        didSet
        {
            let text = self.text()
            self.fakeTweets.insert(text, atIndex: 0)
            dispatch_async(dispatch_get_main_queue()){
                self.refreshControl?.endRefreshing()
                self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow:0, inSection: 0)], withRowAnimation: .Automatic)
            }
        }
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.beginRefreshing()
        self.tableView.estimatedRowHeight = 55.0
        self.tableView.rowHeight = UITableViewAutomaticDimension
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0))
        {
            self.generateRecipesForTwitterUser()
        }
    }
    
    private func generateRecipesForTwitterUser(twitterUser:String = "dril")
    {
        self.fetchStatusesOfTwitterUser(twitterUser)
    }
    
    private func fetchStatusesOfTwitterUser(twitterUser: String = "dril")
    {
        let store = ACAccountStore()
        let type = store.accountTypeWithAccountTypeIdentifier(ACAccountTypeIdentifierTwitter)
        store.requestAccessToAccountsWithType(type, options: nil)
        { success, error in
            if success, let accounts = store.accountsWithAccountType(type), twitterAccount = accounts.first as? ACAccount
            {
                if let properties = twitterAccount.valueForKey("properties") as? [String: String], _ = properties["user_id"]
                {
                    let requestURL = NSURL(string: "https://api.twitter.com/1.1/statuses/user_timeline.json?screen_name=\(twitterUser)&count=150")
                    let getRequest = SLRequest(forServiceType: SLServiceTypeTwitter, requestMethod: SLRequestMethod.GET, URL: requestURL, parameters: [:])
                    getRequest.account = twitterAccount
                    getRequest.performRequestWithHandler{responseData, urlResponse, error in
                        let json:[[String:AnyObject]] = try! NSJSONSerialization.JSONObjectWithData(responseData, options: NSJSONReadingOptions.MutableContainers) as! [[String : AnyObject]]
                        var statusBlob: String = ""
                        for dict in json
                        {
                            if let status = dict["text"] as? String
                            {
                                statusBlob += status + " "
                            }
                            
                        }
                        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
                            if let dict = json.first, let profileImageURL = dict["user"]!["profile_image_url_https"] as? String
                            {
                                if let data = NSData(contentsOfURL: NSURL(string: profileImageURL)!)
                                {
                                    dispatch_async(dispatch_get_main_queue()){
                                        self.profileImage = UIImage(data: data)
                                    }
                                }
                            }
                        }
                        self.markov(twitterStatuses: statusBlob.stringByDecodingHTMLEntities)
                    }
                }
            }
        }
    }
    
    func markov(twitterStatuses string: String?, lookbehind: Int = 1)
    {
        if let string = string
        {
            let outcomes = MarkovGenerator.processText(string, lookbehind: lookbehind, splitBy: .ByWords)
            let random = arc4random_uniform(UInt32(outcomes.keys.count))
            let index = outcomes.keys.startIndex.advancedBy(Int(random))
            let initialState = outcomes.keys[index] as! [GKState]
            self.texts = MarkovChainMachine(initialStates: initialState, mapping: outcomes)
        }
        else
        {
            print("Something went wrong")
            self.texts = nil
        }
    }
    
    private func markov(named filename: String, splitBy: Split, lookbehind: Int) -> MarkovChainMachine
    {
        let source = try! String(contentsOfURL: NSBundle.mainBundle().URLForResource(filename, withExtension: "txt")!)
        let outcomes = MarkovGenerator.processText(source, lookbehind: lookbehind, splitBy: splitBy)
        let random = arc4random_uniform(UInt32(outcomes.keys.count))
        let index = outcomes.keys.startIndex.advancedBy(Int(random))
        let initialState = outcomes.keys[index] as! [GKState]
        return MarkovChainMachine(initialStates: initialState, mapping: outcomes)
    }

    
    @IBAction func newTextPressed(sender: UIBarButtonItem)
    {
        self.refreshControl?.beginRefreshing()
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0))
        {
            let text = self.text()
            dispatch_async(dispatch_get_main_queue())
            {
                self.refreshControl?.endRefreshing()
                self.fakeTweets.insert(text, atIndex: 0)
                self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: .Top)
            }
        }
    }
    
    private func text() -> String
    {
        if self.texts == nil { return "" }
        self.texts.reset()
        var text = self.texts.stateBuffer.reduce(""){ $0 + ($1 as! StringState).string + " " }
        let characterCount = Int(arc4random_uniform(UInt32(60))) + 80
        var sentenceCount = 0
        while true
        {
            let x = self.texts.enterNextState()
            if !x { break }
            let state = self.texts.currentState as! StringState
            if state.string.containsString("http") { continue }
            if state.string.containsString("@") { continue }
            let tempText = text + state.string
            if tempText.characters.count > characterCount
            {
                break
            }
            else if self.trailingPunctuation.contains(String(state.string.characters.last!))
            {
                sentenceCount += 1
                text = tempText + " "
                if sentenceCount == 2 { break }
            }
            else
            {
                text = tempText + " "
            }
        }
        let range = text.startIndex ..< text.startIndex.advancedBy(1)
        let firstChar = String(text.characters.first!)
        text.replaceRange(range, with: firstChar.capitalizedString)
        return text
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return self.fakeTweets.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.text = self.fakeTweets[indexPath.row]
        cell.imageView?.image = self.profileImage
        return cell
    }

}

extension ViewController: UITextFieldDelegate
{
    func textFieldShouldReturn(textField: UITextField) -> Bool
    {
        self.profileImage = nil
        let indexPaths = self.fakeTweets.enumerate().map{index, element in NSIndexPath(forRow:index, inSection:0)}
        self.fakeTweets = [String]()
        self.tableView.deleteRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
        self.refreshControl?.beginRefreshing()
        if let text = textField.text?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        {
            self.generateRecipesForTwitterUser(text)
        }
        else
        {
            self.generateRecipesForTwitterUser()
        }
        textField.resignFirstResponder()
        return true
    }
}

private let characterEntities : [ String : Character ] = [
    "&quot;"    : "\"",
    "&amp;"     : "&",
    "&apos;"    : "'",
    "&lt;"      : "<",
    "&gt;"      : ">",
    
    "&nbsp;"    : "\u{00a0}",
    "&diams;"   : "♦",
]

extension String
{
    var stringByDecodingHTMLEntities : String
    {
        func decodeNumeric(string : String, base : Int32) -> Character?
        {
            let code = UInt32(strtoul(string, nil, base))
            return Character(UnicodeScalar(code))
        }
        
        func decode(entity : String) -> Character? {
            
            if entity.hasPrefix("&#x") || entity.hasPrefix("&#X"){
                return decodeNumeric(entity.substringFromIndex(entity.startIndex.advancedBy(3)), base: 16)
            } else if entity.hasPrefix("&#") {
                return decodeNumeric(entity.substringFromIndex(entity.startIndex.advancedBy(2)), base: 10)
            } else {
                return characterEntities[entity]
            }
        }
        
        
        var result = ""
        var position = startIndex
        
        while let ampRange = self.rangeOfString("&", range: position ..< endIndex)
        {
            result.appendContentsOf(self[position ..< ampRange.startIndex])
            position = ampRange.startIndex
            
            if let semiRange = self.rangeOfString(";", range: position ..< endIndex)
            {
                let entity = self[position ..< semiRange.endIndex]
                position = semiRange.endIndex
                
                if let decoded = decode(entity)
                {
                    result.append(decoded)
                } else
                {
                    result.appendContentsOf(entity)
                }
            }
            else
            {
                break
            }
        }
        result.appendContentsOf(self[position ..< endIndex])
        return result
    }
}


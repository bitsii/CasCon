/*
 * Copyright (c) 2021-2023, Craig Welch.  All Rights Reserved.
 */

import UIKit

@UIApplicationMain

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var lastCx: String?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
    //UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.

        //let tvc = AppDelegate.topViewController() as! ViewController;
        //tvc.dropWebView();

        /*let tvc = AppDelegate.topViewController() as! ViewController;
        //tvc.webView.stopLoading()

        let url = Bundle.main.url(forResource: "Blank", withExtension: "html", subdirectory: "App/CasCon")!
        tvc.webView.loadFileURL(url, allowingReadAccessTo: url)
        let request = URLRequest(url: url)
        tvc.webView.load(request)*/


    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

        let tvc = AppDelegate.topViewController() as! ViewController;
        if tvc.webView != nil {
            tvc.webView.evaluateJavaScript("callUI('gotAction');");
        }

        //let tvc = AppDelegate.topViewController() as! ViewController;
        //tvc.qReInitWebView();

        /*let tvc = AppDelegate.topViewController() as! ViewController;
        //tvc.webView.reload()

        let url = Bundle.main.url(forResource: "BAM", withExtension: "html", subdirectory: "App/CasCon")!
        tvc.webView.loadFileURL(url, allowingReadAccessTo: url)
        let request = URLRequest(url: url)
        tvc.webView.load(request)*/

    }

    public class func topViewController(_ base: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topViewController(selected)
            }
        }
        if let presented = base?.presentedViewController {
            return topViewController(presented)
        }
        return base
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func getLastCx() -> String {
      if let cx = lastCx as? String {
          lastCx = "";
          return(cx);
        }
       return("")
    }

    func application(_ application: UIApplication,
                 open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:] ) -> Bool {

            print("OPENED FROM URL")

            //did and sp (ondeviceid and spass)


            // Determine who sent the URL.
            let sendingAppID = options[.sourceApplication]
            print("source application = \(sendingAppID ?? "Unknown")")


            // Process the URL.
            guard let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true),
                //let albumPath = components.path,
                let params = components.queryItems else {
                    print("missing params")
                    return false
            }


            if let cx = params.first(where: { $0.name == "cx" })?.value {
                print("cx = \(cx)")
                lastCx = cx;
            } else {
                print("cx missing")
                return false
            }

            return true
        }


}

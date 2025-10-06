/*
 * Copyright (c) 2015-2023, the Brace App Authors.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Licensed under the BSD 2-Clause License (the "License").
 * See the LICENSE file in the project root for more information.
 *
 */

import UIKit
import WebKit
import JavaScriptCore
import Foundation
import Network
import CryptoKit
import CoreBluetooth

extension Digest {
    var bytes: [UInt8] { Array(makeIterator()) }
    var data: Data { Data(bytes) }

    var hexStr: String {
        bytes.map { String(format: "%02X", $0) }.joined()
    }
}

class AdCommander {

    var scmds: String?
    var lastCres: String = ""
    let connection: NWConnection
    let cmds: String
    let kdaddr: String
    
    init(adcmds: String) {
        let kcl = adcmds.split(separator: ":", maxSplits: 1)
        kdaddr = String(kcl[0])
        cmds = String(kcl[1])

        print("kadddr")
        print(kdaddr)
        print("cmds")
        print(cmds)
        let host = NWEndpoint.Host(kdaddr)
        let port = NWEndpoint.Port(6420)
        self.connection = NWConnection(host: host, port: port, using: .tcp)
    }
    
    func connect() {
        print("connecting")
        self.connection.stateUpdateHandler = self.didChange(state:)
        self.startReceive()
        self.connection.start(queue: .main)
    }
    
    func disconnect() {
        if self.connection.state != NWConnection.State.cancelled {
            self.connection.cancel()
            print("did stop")
        }
    }
    
    private func didChange(state: NWConnection.State) {
        switch state {
            case .setup:
                break
            case .waiting(let error):
                print("waiting: \(error)")
            case .preparing:
                break
            case .ready:
                break
            case .failed(let error):
                print("failed: \(error)")
                self.disconnect()
            case .cancelled:
                print("cancelled")
                self.disconnect()
            @unknown default:
                break
            }
    }
    
    func send() {
        let data = Data(cmds.utf8)
        self.connection.send(content: data, completion: NWConnection.SendCompletion.contentProcessed { error in
            if let error = error {
                print("Client(Error): \(error)")
                self.disconnect()
            } else {
                print("Client: sent")
            }
        })
    }

    func sendAdCmds() -> String {

        print("in sendAdCmds")
        connect()
        send()

        return("")
    }
    
    private func startReceive() {
            self.connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isDone, error in
                if let data = data, !data.isEmpty {
                    let line = String(decoding: data, as: UTF8.self)
                    self.receiveBuffered(content: line)
                }
                if let error = error {
                    print("Error: \(error)")
                    self.disconnect()
                    return
                }
                if isDone {
                    print("Server disconnected!")
                    self.disconnect()
                    return
                }
                self.startReceive()
            }
        }
        
        private func receiveBuffered(content: String) {
            print("received: \(content)")
            
            // first, add to buffer
            lastCres.append(content)
        }
        
}

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, CBCentralManagerDelegate, CBPeripheralDelegate {

    var adcmdr: AdCommander?

    //var lastCtr: Int = 0
    //var currCtr: Int = 0

    var centralManager: CBCentralManager!
    var discoveredPeripherals: [CBPeripheral] = []

    let serviceUUID = CBUUID(string: "6cbe56f2-1858-4ca7-87b3-618ae26a12d6")
    let readCharacteristicUUID = CBUUID(string: "6cbe56f2-3858-4ca7-87b3-618ae26a12d6")
    let writeCharacteristicUUID = CBUUID(string: "6cbe56f2-2858-4ca7-87b3-618ae26a12d6")

    var connectedPeripheral: CBPeripheral?
    var readCharacteristic: CBCharacteristic?
    var writeCharacteristic: CBCharacteristic?
    var isScanning = false
    var lastReadValue: String?  // Member variable to hold the last read value

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {

        //print("in prompt swift")
        //print(prompt)
        let res = nativeCallHandler(prompt)
        //print("res")
        //print(res)
        completionHandler(res)

    }

    //Begin Native Calls

    func nativeCallHandler(_ args: String) -> String {

            let argsl = args.split(separator: ":", maxSplits: 1)
            let call = argsl[0]
            if (call == "getDocumentsDirectory") {
              return(getDocumentsDirectory())
            } else if (call == "getWifiIPAddress") {
                return(getWifiIPAddress() ?? "")
            } else if (call == "getSha1Hex") {
              return(getSha1Hex(insec: String(argsl[1])))
            } else if (call == "fileExists") {
              return(fileExists(path: String(argsl[1])))
            } else if (call == "makeDirs") {
              return(makeDirs(path: String(argsl[1])))
            } else if (call == "fileContentsSet") {
                return(fileContentsSet(pscontents: String(argsl[1])))
            } else if (call == "fileContentsGet") {
                return(fileContentsGet(ps: String(argsl[1])))
            } else if (call == "listFiles") {
                return(listFiles(path: String(argsl[1])))
            } else if (call == "deleteFile") {
                return(deleteFile(path: String(argsl[1])))
            } else if (call == "getAddr") {
                return(getAddr(kdname: String(argsl[1])))
            } else if (call == "getBles") {
                return(getBles())
            } else if (call == "bleConn") {
                return(connectToDevice(named: String(argsl[1])))
            } else if (call == "bleWrite") {
                return(writeToCharacteristic(value: String(argsl[1])))
            } else if (call == "bleRead") {
                return(readFromCharacteristic())
            } else if (call == "sendAdCmds") {
                return(sendAdCmds(adcmds: String(argsl[1])))
            } else if (call == "getLastCres") {
                return(adcmdr?.lastCres ?? "")
            } else if (call == "httpSend") {
                return(httpSend(request: String(argsl[1])))
            } else if (call == "openToUrl") {
                return(openToUrl(request: String(argsl[1])))
            } else if (call == "runAsync") {
                return(runAsync(config: String(argsl[1])))
            } else if (call == "sleepMillis") {
                return(sleepMillis(milliss: String(argsl[1])))
            } else if (call == "logStuff") {
                return(logStuff(stuff: String(argsl[1])))
            } else if (call == "getLastCx") {
                return(getLastCx())
                //return(getLastCx(ctrs: String(argsl[1])))
            }

        return("")
    }

    func sendAdCmds(adcmds: String) -> String {
        adcmdr = AdCommander(adcmds: adcmds);
        return(adcmdr?.sendAdCmds())!;
    }

    func getDocumentsDirectory() -> String {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.path
    }

    func getWifiIPAddress() -> String? {
        var address : String?

        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }

        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee

            // Check for IPv4 or IPv6 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            //if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) { }
            if addrFamily == UInt8(AF_INET) {

                // Check interface name:
                // wifi = ["en0"]
                // wired = ["en2", "en3", "en4"]
                // cellular = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]

                //name == "en0" || name == "en2" || name == "en3" || name == "en4" || name == "pdp_ip0" || name == "pdp_ip1" || name == "pdp_ip2" || name == "pdp_ip3"

                let name = String(cString: interface.ifa_name)
                if  name == "en0" {

                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)

        return address
    }

    func getSha1Hex(insec: String) -> String {
        guard let data = insec.data(using: .utf8) else { return("") }
        let digest = Insecure.SHA1.hash(data: data)
        //print("getSha1Hex")
        //print(insec)
        //print(data)
        //print(digest.data)
        //print(digest.hexStr)
        return(digest.hexStr)
    }

    func fileExists(path: String) -> String {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: path) {
            return("true")
        }
        return("false")
    }

    func listFiles(path: String) -> String {
        //print("in listfiles " + path)
        var files: [String] = []
        let fileManager = FileManager.default
        do {
            let items = try fileManager.contentsOfDirectory(atPath: path)

            for item in items {
                //print("Found \(item)")
                files.append(item)
            }

        } catch {
            print(error.localizedDescription);
        }

        do {
            let jsonData: Data = try JSONSerialization.data(withJSONObject: files, options: [])
            if  let jsonString = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue) {
                //print("lfstr")
                //print(jsonString)
                return jsonString as String
            }

        } catch let error as NSError {
            print(error.localizedDescription);
        }

        return("")
    }

    func makeDirs(path: String) -> String {
        let dataPath = URL(string: path)!
        if !FileManager.default.fileExists(atPath: dataPath.absoluteString) {
            do {
                try FileManager.default.createDirectory(atPath: dataPath.absoluteString, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error.localizedDescription);
                return(error.localizedDescription);
            }
        }
        return("Done")
    }

    func deleteFile(path: String) -> String {
        let dataPath = URL(string: path)!
        if FileManager.default.fileExists(atPath: dataPath.absoluteString) {
            do {
                try FileManager.default.removeItem(atPath: dataPath.absoluteString)
            } catch {
                print(error.localizedDescription);
                return(error.localizedDescription);
            }
        }
        return("Done")
    }

    func getAddr(kdname: String) -> String {
        let host = CFHostCreateWithName(nil, kdname as CFString).takeRetainedValue()
        CFHostStartInfoResolution(host, .addresses, nil)
        var success: DarwinBoolean = false
        if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray?,
            let theAddress = addresses.firstObject as? NSData {
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(theAddress.bytes.assumingMemoryBound(to: sockaddr.self), socklen_t(theAddress.length),
                        &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                let numAddress = String(cString: hostname)
                print(numAddress)
                return(numAddress)
            }
        }
        return("")
    }



    func fileContentsSet(pscontents: String) -> String {

        let pscl = pscontents.split(separator: ":", maxSplits: 1)
        let path = String(pscl[0])
        var content:String.SubSequence = "";
        if (pscl.count > 1) {
            content = pscl[1]
        }
        let dataPath = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: dataPath.absoluteString) {
            do {
                try FileManager.default.removeItem(atPath: dataPath.absoluteString)
            } catch {
                print(error.localizedDescription);
                return(error.localizedDescription);
            }
        }
        do {
            try content.write(to: dataPath, atomically: false, encoding: .utf8)
        }
        catch {
            print("failed writing filecontents")
            print(error.localizedDescription);
            return(error.localizedDescription);
        }

        return("Done")
    }

    func fileContentsGet(ps: String) -> String {
        let dataPath = URL(fileURLWithPath: ps)
        var text = ""
        do {
            text = try String(contentsOf: dataPath, encoding: .utf8)
        }
        catch {
            print("failed reading filecontents")
            print(error.localizedDescription);
            return(error.localizedDescription);
        }

        return(text)
    }

    func runAsync(config: String) -> String {
        DispatchQueue.global(qos: .userInitiated).async {
            self.runAsyncInner(config: config)
        }

        //DispatchQueue.main.async {
        //}

        return("Done")
    }

    func runAsyncInner(config: String) {
        print("in runAsync Inner for " + config)

        let bkContext = JSContext()

        let appjspath = Bundle.main.path(forResource: "BEX_E", ofType: "js", inDirectory: "App/CasCon")!

         do {

         print("loading appjs")

         bkjs = try String(contentsOfFile: appjspath, encoding: String.Encoding.utf8)
         //print("appjs text")
         //print(appjs)
         _ = bkContext?.evaluateScript(bkjs)

         print("bkjs loaded, bk context initted")

         //need to inject swift object that can invoke nativeCallHandler
         //need to add prompt impl in js that calls that swift nativeCallHandler
        let prompt: @convention(block) (String) -> String = { input in
            return self.nativeCallHandler(input)
        }

            bkContext!.setObject(prompt,
                              forKeyedSubscript: "prompt" as NSString)

            //need to run a mtd on runasync with args (readAndRun)

            _ = bkContext?.evaluateScript("readAndRun('" + config + "');")

         } catch (let error) {
         print("Error while processing script file: \(error)")
         }

    }

    func httpSend(request: String) -> String {
        print("in httpSend for " + request)
        //Map reqjs = Maps.from("url", url, "verb", verb, "outputHeaders", outputHeaders, "payload", payload);
        //String reqjss = Json:Marshaller.marshall(reqjs);
        //String jspw = "httpSend:" + reqjss;

        let data: Data = request.data(using: .utf8)!
        let reqj = try? JSONSerialization.jsonObject(with: data, options: [])
        //print("start send loop")
        if let reqd = reqj as? [String: Any] {
            //print("in reqj")
            if let url = reqd["url"] as? String {
                //print("in url")
                if let payload = reqd["payload"] as? String {
                    //print("in payload")
                    let request = NSMutableURLRequest(url: NSURL(string: url)! as URL)
                    request.httpMethod = "POST" //use verb
                    //gotta do output headers
                    //print("doing headers")
                    if let outputHeaders = reqd["outputHeaders"] as? [String: Any] {
                        //print("headers d")
                        // access nested dictionary values by key
                        for (hkey, hvalue) in outputHeaders {
                            //print("doing a header")
                            // access all key / value pairs in dictionary
                            request.addValue(hvalue as! String, forHTTPHeaderField: hkey)
                        }
                    }
                    let payloadd: Data = payload.data(using: .utf8)!
                    print(payload)
                    request.httpBody = payloadd

                    //var response: URLResponse?

                    //print("entering do")
                    /*do {
                        let urlData = try NSURLConnection.sendSynchronousRequest(request as URLRequest, returning: &response)
                        //print("after sendsync")
                        let ress = String(decoding: urlData, as: UTF8.self)
                        print(ress)
                        return(ress)
                    } catch {
                        print(error.localizedDescription);
                    }*/

                }
            }
        }
        //print("late return")
        return("")
    }

    func openToUrl(request: String) -> String {
        print("in openToUrl for " + request)
        let data: Data = request.data(using: .utf8)!
        let reqj = try? JSONSerialization.jsonObject(with: data, options: [])
        //print("start send loop")
        if let reqd = reqj as? [String: Any] {
            //print("in reqj")
            if let url = reqd["url"] as? String {
                //print("in url")
                guard let url = URL(string: url) else { return("") }
                UIApplication.shared.open(url)
            }

        }
        return("")
    }
    
    func sleepMillis(milliss: String) -> String {
      //print("milliss in " + milliss);
      let millis = Int(milliss) ?? 0
      let usl = millis * 1000
      //print("Sleeping " + String(usl));
      usleep(useconds_t(usl))
      return("Done")

    }

    func logStuff(stuff: String) -> String {
      print(stuff);
      return("")
    }

    //func getLastCx(ctrs: String) -> String {}
    func getLastCx() -> String {
       //let ctr = Int(ctrs) ?? 0
       //currCtr = ctr;
       guard let delegate = UIApplication.shared.delegate as? AppDelegate else {
            return("")
        }
       return(delegate.getLastCx())
    }

    //End Native Calls

    var webView: WKWebView!
    var bkjs: String!
    var timer: Timer!

    override func loadView() {
        super.loadView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        centralManager = CBCentralManager(delegate: self, queue: nil)

        qReInitWebView()

        // Every 3 seconds, check if the webview is dead. If it is, reload it.
        //self.timer = Timer.scheduledTimer(timeInterval: 5,
        //target: self, selector: #selector(checkForDeadWebViews),
        //userInfo: nil, repeats: true);

    }

    func dropWebView() {
       if (webView != nil) {
         webView.removeFromSuperview()
         webView = nil;
       }
    }

    func qReInitWebView() {
        if (webView == nil) {
            webView = WKWebView()

            webView.translatesAutoresizingMaskIntoConstraints = false

            webView.navigationDelegate = self
            webView.uiDelegate = self

            self.view.addSubview(webView)

            let url = Bundle.main.url(forResource: "BAM", withExtension: "html", subdirectory: "App/CasCon")!
            webView.loadFileURL(url, allowingReadAccessTo: url)
            let request = URLRequest(url: url)
            webView.load(request)
            //self.view = webView

            NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.rightAnchor.constraint(equalTo: view.rightAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)])

            //capturing logs
            let source = "function captureLog(msg) { window.webkit.messageHandlers.logHandler.postMessage(msg); } window.console.log = captureLog;"
            let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
            webView.configuration.userContentController.addUserScript(script)
            // register the bridge script that listens for the output
            webView.configuration.userContentController.add(self, name: "logHandler")
        }
    }

    @objc(userContentController:didReceiveScriptMessage:) func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "logHandler" {
            print("JSCONSOLE: \(message.body)")
        }
    }

    //@objc func checkForDeadWebViews() {
        // TODO: There needs to be synchronization logic here: we don't want
        // webViewWebContentProcessDidTerminate firing twice!
        //if (lastCtr == currCtr) {
        //  self.webViewWebContentProcessDidTerminate(self.webView);
        //}
        //lastCtr = currCtr
    //}

    //func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    //    webView.reload()
    //}

        // Function to start scanning
    func startScanning() {
        guard !isScanning else { return }
        guard centralManager.state == .poweredOn else {
            print("Bluetooth is not powered on. Cannot start scanning.")
            return
        }

        isScanning = true
        discoveredPeripherals.removeAll()  // Clear previous discoveries
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        print("Started scanning for devices.")
    }

    // Function to stop scanning
    func stopScanning() {
        guard isScanning else { return }
        isScanning = false
        centralManager.stopScan()
        print("Stopped scanning for devices.")
    }

    func getBles() -> String {
        // Start scanning if not already scanning
        if !isScanning {
            startScanning()
        }

        // Create a comma-separated list of names for discovered peripherals
        let deviceNames = discoveredPeripherals.compactMap { $0.name }.joined(separator: ", ")

        return deviceNames
    }

    func connectToDevice(named name: String) -> String {
        for peripheral in discoveredPeripherals {
            if peripheral.name == name {
                connectedPeripheral = peripheral
                stopScanning()  // Stop scanning when connecting
                centralManager.connect(peripheral, options: nil)
                break
            }
        }
        return "connecting"
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // No start/stop scanning here; just check Bluetooth state
        if central.state == .poweredOn {
            print("Bluetooth is powered on.")
        } else {
            print("Bluetooth is not available. State: \(central.state)")
            stopScanning()  // Optional: stop scanning if not powered on
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(peripheral) {
            discoveredPeripherals.append(peripheral)
            print("Found device: \(peripheral.name ?? "Unknown")")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics([readCharacteristicUUID, writeCharacteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == readCharacteristicUUID {
                readCharacteristic = characteristic
            } else if characteristic.uuid == writeCharacteristicUUID {
                writeCharacteristic = characteristic
            }
        }
    }

    func readFromCharacteristic() -> String {
        // Capture the current value of lastReadValue at the start
        let capturedValue = lastReadValue ?? ""

        // Request a new read if conditions are met
        guard let peripheral = connectedPeripheral, let characteristic = readCharacteristic else {
            // Return the captured value if the characteristic is not available
            return capturedValue
        }

        lastReadValue = nil  // Set to nil before making the read request
        peripheral.readValue(for: characteristic)  // Request read
        print("Requested a read from characteristic.")

        // Return the captured value, which will be either the last read value or an empty string
        return capturedValue
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == readCharacteristicUUID, let data = characteristic.value {
            lastReadValue = String(data: data, encoding: .utf8)  // Store latest value
            print("Read value: \(lastReadValue ?? "Error reading value")")
        }
    }

    func writeToCharacteristic(value: String) -> String {
        // Handle the case when there is no connected peripheral or write characteristic
        guard let peripheral = connectedPeripheral, let characteristic = writeCharacteristic else {
            print("Cannot write: Peripheral or characteristic not available.")
            return ""  // Always return an empty string
        }

        let dataToSend = value.data(using: .utf8)  // Convert string to Data
        peripheral.writeValue(dataToSend!, for: characteristic, type: .withResponse)  // Write data without throwing exceptions
        print("Requested write to characteristic with value: \(value)")

        return ""  // Always return an empty string
    }

}


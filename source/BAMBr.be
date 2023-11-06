/*
 * Copyright (c) 2021-2023, the Casnic Control Authors.
 *
 * SPDX-License-Identifier: MPL-2.0
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 */

use System:Exception as Exc;
use IO:File:Path;
use IO:File;
use System:Random;

use UI:HtmlDom:Document as HD;
use UI:HtmlDom:Element as HE;
use UI:HtmlDom:Call as HC;

use class IUHub:Eui {

  new() self {
        fields {
          IO:Log log = IO:Logs.get(self);
          List callbacks = Lists.from(self); //plugins
          HC hc = HC.new(callbacks);
          Bool authless = true;
          //ifEmit(bnbr) {
          //  authless = false;
          //}
          log.log("authless " + authless);
        }
    }
    
    handleCallOut(Map arg) {
      hc.call(arg);
    }
    
    main() {    
    }
    
   startup() {
      IO:Logs.turnOnAll();
      log.log("in startup");
      fields {
        String pageName = HD.getElementById("pageName").value;
      }
      if (authless) {
        log.log("doing loggedin b/c authless");
        loggedInResponse(Map.new());
      } else {
        log.log("getting pagetoken");
        HD.getEle("loginButton").display = "block";
        Map arg = Map.new();
        arg["action"] = "pageTokenRequest";
        handleCallOut(arg);
      }
      HC.pollUI(List.new().addValue("checkCx"), 1500);
      HC.pollUI(List.new().addValue("checkNexts"), 1000);
      HC.pollApp(List.new().addValue("manageStateUpdatesRequest"), 250);
   }

   checkCx() {
     slots {
       String lastCx;
     }
     ifEmit(apwk) {
      String jspw = "getLastCx:";
      emit(js) {
      """
      var jsres = prompt(bevl_jspw.bems_toJsString());
      bevl_jspw = new be_$class/Text:String$().bems_new(jsres);
      """
      }
      if (TS.notEmpty(jspw)) {
        lastCx = jspw;
        log.log("got lastCx");
        log.log(lastCx);
      }
      }
      ifEmit(jvad) {
        //log.log("calling checkCxRequest");
        HC.callApp(Lists.from("checkCxRequest"));
      }
   }

   checkCxResponse(String cx) {
     if (TS.notEmpty(cx)) {
       log.log("gotCxResponse " + cx);
       lastCx = cx;
     }
   }

   clearCx() {
     lastCx = "";
     HC.callApp(Lists.from("clearCxRequest"));
   }

   pageTokenResponse(Map arg) {
      hc.pageToken = arg["pageToken"];
      unless (authless) {
        Map carg = Map.new();
        carg["action"] = "checkLoggedInRequest";
        log.log("href at startup " + HD.href);
        handleCallOut(carg);
      }
      //toLoginResponse();
   }
   
   logoutResponse() {
    //toLoginResponse();
    //HD.reload();
    //startup();
    log.log("in logout response");
    //HD.getEle("loginButton").click();
    //HD.reload();
   }
   
   toLoginResponse() {
      //hideNShowResponse(Sets.from("loginDiv"));
      //hideNShowMenuResponse(Sets.from("loginMe"));
      //HC.callApp(Lists.from("checkAccountsRequest"));
      HD.getEle("loginButton").click();
   }

   togglePwnet() {
     if (HD.getElementById("pwsnetname").type == "text") {
      HD.getElementById("pwsnetname").type = "password";
     } else {
      HD.getElementById("pwsnetname").type = "text";
     }
   }
   
   loggedInResponse(Map arg) {
     log.log("logged in res is fl");
     HC.callApp(Lists.from("getDevicesRequest"));
   }

   toggleDevDetails() {
     any da = HD.getEle("divDevDetails");
     if (da.display == "block") {
       da.display = "none";
     } else {
       da.display = "block";
     }
   }

   toggleAdvanced() {
     any da = HD.getEle("divAdvanced");
     if (da.display == "block") {
       da.display = "none";
     } else {
       da.display = "block";
     }
   }
   
   checkToggled(String dname, String pos) {
     log.log("checkToggled " + dname + " " + pos);
     Bool statet = HD.getEle("hat" + dname + "-" + pos).checked;
     log.log("toggleState " + statet);
     if (statet) {
       String state = "on";
     } else {
       state = "off";
     }
     HC.callApp(Lists.from("setDeviceSwRequest", dname, pos, state));
   }

   checkSlid(String dname, String pos) {
     log.log("checkSlid " + dname + " " + pos);
     Int statet = HD.getEle("sli" + dname + "-" + pos).value;
     log.log("slidState " + statet);
     HD.getEle("hat" + dname + "-" + pos).checked = true;
     //slvls.put(dname + "-" + pos, statet.toString());
     //HC.callApp(Lists.from("setDeviceLvlRequest", kv.key, kv.value));
     HC.callApp(Lists.from("setDeviceLvlRequest", dname + "-" + pos, statet.toString()));
   }

   openPicker(String dname, String pos) {
     slots {
       String pickerDname = dname;
       String pickerPos = pos;
     }
     String chex = HD.getEle("coli" + pickerDname + "-" + pickerPos).value;
     HD.getEle("hadsList").display = "none";
     HD.getEle("cpickercon").display = "block";
           emit(js) {
        """
        if (this.picker == null) {
        this.picker = new ColorPickerControl({
            container: cpicker,
            theme: 'dark'
        });
        this.picker.on('change', (color) => {
            console.log('Event: "change"', color.toHEX());
            callUI('pickerChanged', color.toHEX());
        });
        }
        this.picker.color.fromHEX(bevl_chex.bems_toJsString());
        """
      }
   }

   pickerChanged(hxcol) {
     log.log("in pickerchanged");
     //set the native html color picker.  It's the .value as a hex string 6 char preceeded by #
     if (TS.notEmpty(pickerDname) && TS.notEmpty(pickerPos) && TS.notEmpty(hxcol)) {
       HD.getEle("coli" + pickerDname + "-" + pickerPos).value = hxcol;
       checkColor(pickerDname, pickerPos);
     } else {
       if (TS.isEmpty(hxcol)) { log.log("hxcol empty"); }
       log.log("picker dname or pos or hxcol empty");
     }
   }

   closePicker() {
     HD.getEle("hadsList").display = "block";
     HD.getEle("cpickercon").display = "none";
     pickerDname = null;
     pickerPos = null;
   }

   checkColor(String dname, String pos) {

     log.log("checkColor " + dname + " " + pos);
     //String val = HD.getElementById("colorpicker").value;
     String val = HD.getEle("coli" + dname + "-" + pos).value;
     log.log("checkColor val " + val);

     String rh = val.substring(1,3);
     log.log("rh " + rh);
     Int rhi = Int.hexNew(rh);

     String gh = val.substring(3,5);
     log.log("gh " + gh);
     Int ghi = Int.hexNew(gh);

     String bh = val.substring(5,7);
     log.log("bh " + bh);
     Int bhi = Int.hexNew(bh);

     String rgb = rhi.toString() + "," + ghi.toString() + "," + bhi.toString();
     log.log("checkColor r,g,b " + rgb);

     HC.callApp(Lists.from("setDeviceRgbRequest", dname + "-" + pos, rgb));

   }

   checkBrt(String dname, String pos) {
     log.log("checkBrt " + dname + " " + pos);
     Int statet = HD.getEle("brt" + dname + "-" + pos).value;
     log.log("slidState " + statet);
     //HD.getEle("hat" + dname + "-" + pos).checked = true;
     //slvls.put(dname + "-" + pos, statet.toString());
     //HC.callApp(Lists.from("setDeviceLvlRequest", kv.key, kv.value));
     HC.callApp(Lists.from("setDeviceRgbcwRequest", dname + "-" + pos, "brt", statet.toString()));
   }

   checkTemp(String dname, String pos) {
     log.log("checkTemp " + dname + " " + pos);
     Int statet = HD.getEle("temp" + dname + "-" + pos).value;
     log.log("slidState " + statet);
     //HD.getEle("hat" + dname + "-" + pos).checked = true;
     //slvls.put(dname + "-" + pos, statet.toString());
     //HC.callApp(Lists.from("setDeviceLvlRequest", kv.key, kv.value));
     HC.callApp(Lists.from("setDeviceRgbcwRequest", dname + "-" + pos, "temp", statet.toString()));
   }

   checkNexts() {

    slots {
      Int discoCounts;
    }

    auto imd = HD.getEle("informMessageDiv");
    if (imd.exists && TS.notEmpty(mustInform)) {
      HD.getElementById("informMessageDiv").innerHTML = mustInform;
    }

     //log.log("in checkNexts");
     //showDeviceButton disDevPin
     auto sde = HD.getEle("showDeviceButton");
     auto ddtf = HD.getEle("disDevTypeFriendly");
     unless (sde.exists && ddtf.exists) {
       inDeviceSetup = false;
     }
     if (def(inDeviceSetup) && inDeviceSetup) {
       log.log("in devsetup");
       auto wfd = HD.getEle("wifisholder");
       auto wgb = HD.getEle("wifiGivenButton");
       if (wfd.exists && wgb.exists) {
         if (def(visnets)  && visnets.notEmpty && TS.isEmpty(wfd.innerHTML)) {
           auto ehvs = Encode:Hex.new();
           String netch = "<fieldset><legend>Select a network:</legend>";
           for (auto kv in visnets) {
             String kvv = kv.value;
             String kvve = ehvs.encode(kvv);
             netch += "<div><input type=\"radio\" id=\"pswi" += kvve += "\" name=\"drone\" value=\"huey\"/><label for=\"pswi" += kvve += "\">" += kvv += "</label></div>";
           }
           netch += "</fieldset>";
           wfd.innerHTML = netch;
         }
       }
       return(self);
    }
     if (sde.exists && ddtf.exists) {
       if (TS.notEmpty(lastCx)) {
         HD.getElementById("disBackButton").click();
       } else {
        if (TS.isEmpty(ddtf.value)) {
          if (undef(discoCounts) || discoCounts > 3000) {
            discoCounts = 0;
          } else {
            discoCounts++=;
          }
        if (discoCounts % 7 == 0) {
            log.log("in checkNexts hitting findNewDevices");
            HC.callApp(List.addValue("findNewDevicesRequest"));
          } else {
            log.log("checkNexts gonna click discovery");
            sde.click();
          }
          ifEmit(apwk) {
            HD.getEle("foundiTxt").display = "none";
            HD.getEle("discoTxt").display = "block";
          }
          ifEmit(jvad) {
            HD.getEle("foundaTxt").display = "none";
            HD.getEle("siscoTxt").display = "block";
          }
        } else {
          ifEmit(apwk) {
            HD.getEle("discoTxt").display = "none";
            HD.getEle("foundiTxt").display = "block";
          }
          ifEmit(jvad) {
            HD.getEle("siscoTxt").display = "none";
            //acshewly, depending on if the pin is empty or not
            HD.getEle("foundaTxt").display = "block";
          }
        }
       }
     }

     //devId nextDevButton
     auto ndb = HD.getEle("nextDevButton");
     auto ddf = HD.getEle("devId");
     if (ndb.exists && ddf.exists) {
       if (TS.notEmpty(lastCx)) {
         HD.getElementById("shBlob").value = lastCx;
         HD.getElementById("adsButton").click();
       } elseIf (TS.isEmpty(ddf.value)) {
        //HD.getEle("mqttSetup").display = "block";
        log.log("checkNexts gonna click next device");
        ndb.click();
       }
     }

     unless (ndb.exists || sde.exists) {
       if (TS.notEmpty(lastCx)) {
         HD.getEle("openSettings").click();
       }
     }

   }
   
   //devSendCmd devSeeRes
   sendDeviceCommand() {
     String devId = HD.getElementById("devId").value;
     HC.callApp(Lists.from("sendDeviceCommandRequest", devId, HD.getEle("devSendCmd").value));
   }

   seeDeviceCommandResponse(String res) {
     HD.getEle("devSeeRes").value = res;
   }

   showDeviceConfig() {
     fields {
       String lastDeviceId;
     }
     HC.callApp(Lists.from("showDeviceConfigRequest", lastDeviceId));
   }

   discover() {
    HD.getEle("openDiscover").click();
   }

   getDiscoveredDeviceResponse() {
     slots {
       String lastDiscoveredDevice;
     }
   }

   settleWifiResponse(Map _visnets, String ssid, String sec) {
     fields {
       Map visnets = _visnets;
     }

     HD.getEle("settleWifiButton").click();
   }

   //wifiSsid wifiSec
   saveWifi() {
     String wifiSsid = HD.getElementById("wifiSsid").value;
     String wifiSec = HD.getElementById("wifiSec").value;
     HC.callApp(Lists.from("saveWifiRequest", wifiSsid, wifiSec, true));
   }

   wifiGiven() {
     String chssid;
     String chsec;
     chsec = HD.getElementById("pwsnetname").value;
     auto ehvs = Encode:Hex.new();
     for (auto kv in visnets) {
        String kvv = kv.value;
        String kvve = ehvs.encode(kvv);
        //netch += "<div><input type=\"radio\" id=\"pswi" += kvve += "\" name=\"drone\" value=\"huey\"/><label for=\"pswi" += kvve += "\">" += kvv += "</label></div>";
        if (HD.getEle("pswi" + kvve).checked) {
          chssid = kvv;
        }
     }
     if (TS.notEmpty(chssid)) {
       log.log("got chssid " + chssid);
     } else {
       log.log("chssid empty");
     }
     if (TS.notEmpty(chsec)) {
       log.log("got chsec " + chsec);
     } else {
       log.log("chsec empty");
     }
     if (TS.notEmpty(chssid) && TS.notEmpty(chsec)) {
       HD.getEle("giveWifiTxt").display = "none";
       HD.getEle("wifiGivenClose").click();
       HC.callApp(Lists.from("saveWifiRequest", chssid, chsec, false));
       HC.callAppLater(Lists.from("getDevWifisRequest", 1, false), 1000);
     } else {
       HD.getEle("giveWifiTxt").display = "block";
     }
   }

   saveMqtt() {
     String mqttBroker = HD.getElementById("mqttBroker").value;
     String mqttUser = HD.getElementById("mqttUser").value;
     String mqttPass = HD.getElementById("mqttPass").value;
     HC.callApp(Lists.from("saveMqttRequest", mqttBroker, mqttUser, mqttPass));
   }

   saveDevice() {
     String devType = HD.getElementById("devType").value;
     String devId = HD.getElementById("devId").value;
     String onDevId = HD.getElementById("onDevId").value;
     String devName = HD.getElementById("devName").value;
     String devPass = HD.getElementById("devPass").value;
     String devSpass = HD.getElementById("devSpass").value;
     Map conf = Map.new();
     conf["type"] = devType;
     conf["id"] = devId;
     conf["ondid"] = onDevId;
     conf["name"] = devName;
     conf["pass"] = devPass;
     conf["spass"] = devSpass;
     String confs = Json:Marshaller.marshall(conf);
     HC.callApp(Lists.from("saveDeviceRequest", devId, confs));
   }

   clearQrShare() {
     log.log("clearQrShare");
     HD.getEle("qrsharediv").innerHTML = "";
     HD.getEle("qrerr").display = "none";
   }

   showQrShare(Bool admin) {
     genDeviceShare(admin);
     clearQrShare();
     if (TS.notEmpty(HD.getElementById("shBlob").value)) {
      String qrsh = "cascon://?cx=" + HD.getElementById("shBlob").value;
      emit(js) {
        """
        new QRCode("qrsharediv", bevl_qrsh.bems_toJsString());
        """
      }
     } else {
       HD.getEle("qrerr").display = "block";
     }
   }

   genDeviceShare(Bool admin) {
     String devType = HD.getElementById("devType").value;
     String devId = HD.getElementById("devId").value;
     String onDevId = HD.getElementById("onDevId").value;
     String devName = HD.getElementById("devName").value;
     String devPass = HD.getElementById("devPass").value;
     String devSpass = HD.getElementById("devSpass").value;
     if (TS.isEmpty(onDevId) || TS.isEmpty(devSpass)) {
      HD.getElementById("shBlob").value = "";
      return(null);
     }
     Map conf = Map.new();
     conf["type"] = devType;
     //conf["id"] = devId;
     conf["ondid"] = onDevId;
     conf["name"] = devName;
     if (admin && TS.notEmpty(devPass)) {
       conf["pass"] = devPass;
     }
     conf["spass"] = devSpass;
     if (TS.notEmpty(devId) def(devCtls) && devCtls.has(devId)) {
       String controlDef = devCtls.get(devId);
       if (TS.notEmpty(controlDef)) {
         conf["controlDef"] = controlDef;
       }
     }
     String confs = Json:Marshaller.marshall(conf);
     log.log("sharing confs " + confs);
     //HC.callApp(Lists.from("saveDeviceRequest", devId, confs));
     String cx = Encode:Hex.encode(confs);
     log.log("cx next");
     log.log(cx);
     HD.getElementById("shBlob").value = cx;
   }

   acceptShare() {
     log.log("in acceptShare");
     String cx = HD.getElementById("shBlob").value;
     log.log("got blob");
     HC.callApp(Lists.from("acceptShareRequest", cx));
     lastCx = "";
   }

   startDeviceReset() {
     slots {
       Bool reallyResetting = true;
     }
     startDeviceROS();
   }

   startDeviceSetup() {
     reallyResetting = false;
     startDeviceROS();
   }

   startDeviceROS() {
     slots {
       String disDevName;
       String disDevType;
       String disDevPin;
       String disDevSsid;
       String disDevPass;
       String disDevSpass;
       String disDevId;
       String disDevDid;
       Bool inDeviceSetup;
     }
     if (def(inDeviceSetup) && inDeviceSetup) { return(self); }
     inDeviceSetup = true;

     disDevName = HD.getElementById("disDevName").value;
     disDevType = HD.getElementById("disDevType").value;
     disDevPin = HD.getElementById("disDevPin").value;
     disDevSsid = HD.getElementById("disDevSsid").value;
     if (TS.isEmpty(disDevPin)) {
       inform("No device detected yet, cannot begin setup.  Verify that an unconfigured device is powered on and that this client is connecting to it's wifi network");
       return(self);
     } elseIf (disDevPin.size == 8) {
       disDevPin = disDevPin + disDevPin;
     }
     disDevPin = disDevPin.lowerValue();
     if (TS.isEmpty(disDevName)) {
       disDevName = HD.getElementById("disDevTypeFriendly") + " ";
       disDevName += System:Random.getIntMax(99).toString();
     }
     disDevId = System:Random.getString(11);

     HD.getEle("discoTxt").display = "none";
     HD.getEle("siscoTxt").display = "none";
     HD.getEle("foundaTxt").display = "none";
     HD.getEle("foundiTxt").display = "none";
     HD.getEle("doingSetup").display = "block";
     HD.getEle("doingSetupSpin").display = "block";

     HC.callApp(Lists.from("getOnWifiRequest", 0, disDevPin, disDevSsid));
   }

   getOnWifiResponse(Int count, Int tries, Int wait) {
     if (count < tries) {
       count++=;
       HC.callAppLater(Lists.from("getOnWifiRequest", count, disDevPin, disDevSsid), wait);
     } else {
       count.setValue(0);
       if (reallyResetting) {
        HC.callAppLater(Lists.from("resetByPinRequest", count, disDevPin), 3000);
       } else {
         HC.callAppLater(Lists.from("getDevWifisRequest", count, true), 3000);
       }
     }
   }

   getDevWifisResponse(Int count, Int tries, Int wait) {
     if (count < tries) {
       count++=;
       HC.callAppLater(Lists.from("getDevWifisRequest", count, false), wait);
     } else {
       count.setValue(0);
       HC.callAppLater(Lists.from("allsetRequest", count, disDevName, disDevType, disDevPin, disDevSsid, disDevId, "", "", "", "", ""), 1000);
     }
   }

   allsetResponse(Int count, Int tries, Int wait, _disDevPass, _disDevSpass, _disDevDid, devSsid, devSec, _disDevId, _devName) {
     if (count < tries) {
       count++=;
       disDevPass = _disDevPass;
       disDevSpass = _disDevSpass;
       disDevDid = _disDevDid;
       disDevId = _disDevId;
       disDevName = _devName;
       HC.callAppLater(Lists.from("allsetRequest", count, disDevName, disDevType, disDevPin, disDevSsid, disDevId, disDevPass, disDevSpass, disDevDid, devSsid, devSec), wait);
     }
   }

   deleteDevice() {
     String devId = HD.getElementById("devId").value;
     HC.callApp(Lists.from("deleteDeviceRequest", devId));
   }

   clearOldData() {
     HC.callApp(Lists.from("clearOldDataRequest"));
   }

   rectlDevice() {
     String devId = HD.getElementById("devId").value;
     HC.callApp(Lists.from("rectlDeviceRequest", devId));
   }

   resetDevice() {
     String devId = HD.getElementById("devId").value;
     HC.callApp(Lists.from("resetDeviceRequest", devId));
   }
   
   showDeviceConfigResponse(String confs, String ip) {
     Map conf = Json:Unmarshaller.unmarshall(confs);
     HD.getEle("devType").value = conf["type"];
     HD.getEle("devTypeFriendly").value = conf["typeFriendly"];
     HD.getEle("devId").value = conf["id"];
     HD.getEle("onDevId").value = conf["ondid"];
     HD.getEle("devName").value = conf["name"];
     if (TS.notEmpty(conf["pass"])) {
       HD.getEle("devPass").value = conf["pass"];
     }
     HD.getEle("devSpass").value = conf["spass"];
     if (TS.notEmpty(ip)) {
       HD.getEle("devIp").value = ip;
     } else {
       HD.getEle("devIp").value = "";
     }
     String did = conf["id"];
     if (TS.notEmpty(lastDeviceId) && lastDeviceId == did) {
       lastDeviceId = null;
     } else {
       lastDeviceId = did;
     }
   }

   displayNextDeviceResponse(String typeFriendly, String type, String pino, String ssid) {
     HD.getEle("disDevTypeFriendly").value = typeFriendly;
     HD.getEle("disDevType").value = type;
     if (TS.notEmpty(pino) && pino.size == 16) {
       pino = pino.substring(0, 8);
     } elseIf (pino == "UU") {
       pino = "";
     }
     HD.getEle("disDevPin").value = pino;
     HD.getEle("disDevSsid").value = ssid;
     if (TS.notEmpty(typeFriendly)) {
      String disDevName = typeFriendly + " " + System:Random.getIntMax(99).toString();
      HD.getEle("disDevName").value = disDevName;
     }
   }
   
   getDevicesResponse(Map devices, Map ctls, Map states, Map levels, Map rgbs) {
     log.log("in getDevicesResponse");
     slots {
       Map devCtls = ctls;
     }
     HD.getEle("hider").display = "none";
     if (def(devices) && devices.size > 0) {
     Encode:Hex eh = Encode:Hex.new();

       String li = '''
       <li class="item-content">
         <div class="item-inner">
           <div class="item-title">NAMEOFDEVICE</div>
           DIMMERSLIDE
           <div class="item-after" TOGSTYLE>
             <label class="toggle">
               <input type="checkbox" onclick="callUI('checkToggled', 'IDOFDEVICE', 'POSOFDEVICE');return true;" id="hatIDOFDEVICE-POSOFDEVICE" DEVICESTATETOG/>
               <span class="toggle-icon"></span>
             </label>
           </div>
         </div>
       </li>
       ''';

       String dli = '''
       <div class="item-after">
                      <div class="slider">
<input type="range" min="RANGEMIN" max="RANGEMAX" oninput="callUI('checkSlid', 'IDOFDEVICE', 'POSOFDEVICE');return true;" id="sliIDOFDEVICE-POSOFDEVICE" DIMLVL>
</div>
           </div>


       ''';
     
       String ih = '''
           <div class="list">
        <ul>
        ''';

//<input type="color" id="coliIDOFDEVICE-POSOFDEVICE" value="#HEXCOLOR" oninput="callUI('checkColor', 'IDOFDEVICE', 'POSOFDEVICE');return true;"></input>
//<input type="color" id="coliIDOFDEVICE-POSOFDEVICE" value="#HEXCOLOR" onclick="callUI('openPicker', 'IDOFDEVICE', 'POSOFDEVICE');return false;"></input>

      ifEmit(apwk) {
      String coli = '''
       <li class="item-content">
         <div class="item-inner">
           <div class="item-title">NAMEOFDEVICE</div>
           <div class="item-after">
             <label for="coliIDOFDEVICE-POSOFDEVICE">Color</label>&nbsp;&nbsp;
               <input type="color" id="coliIDOFDEVICE-POSOFDEVICE" value="#HEXCOLOR" oninput="callUI('checkColor', 'IDOFDEVICE', 'POSOFDEVICE');return true;"></input>
           </div>
            <div class="item-after">
             <label class="toggle">
               <input type="checkbox" onclick="callUI('checkToggled', 'IDOFDEVICE', 'POSOFDEVICE');return true;" id="hatIDOFDEVICE-POSOFDEVICE" DEVICESTATETOG/>
               <span class="toggle-icon"></span>
             </label>
           </div>

                      </div>
       </li>
       ''';
       }

       ifNotEmit(apwk) {
       String coli = '''
       <li class="item-content">
         <div class="item-inner">
           <div class="item-title">NAMEOFDEVICE</div>
           <div class="item-after">
             <label for="coliIDOFDEVICE-POSOFDEVICE">Color</label>&nbsp;&nbsp;
               <input type="color" id="coliIDOFDEVICE-POSOFDEVICE" value="#HEXCOLOR" onclick="callUI('openPicker', 'IDOFDEVICE', 'POSOFDEVICE');return false;"></input>
           </div>
            <div class="item-after">
             <label class="toggle">
               <input type="checkbox" onclick="callUI('checkToggled', 'IDOFDEVICE', 'POSOFDEVICE');return true;" id="hatIDOFDEVICE-POSOFDEVICE" DEVICESTATETOG/>
               <span class="toggle-icon"></span>
             </label>
           </div>

                      </div>
       </li>
       ''';
       }

       String wcli = '''
       <li class="item-content">
         <div class="item-inner">

           <div class="item-after"><label for="brtIDOFDEVICE-POSOFDEVICE">Cool White</label>&nbsp;<div class="slider"><input type="range" min="1" max="255" oninput="callUI('checkBrt', 'IDOFDEVICE', 'POSOFDEVICE');return true;" id="brtIDOFDEVICE-POSOFDEVICE">
</div></div>



           </div>
       </li>

       <li class="item-content">
         <div class="item-inner">

           <div class="item-after"><label for="brtIDOFDEVICE-POSOFDEVICE">Warm White</label>&nbsp;<div class="slider"><input type="range" min="0" max="255" oninput="callUI('checkTemp', 'IDOFDEVICE', 'POSOFDEVICE');return true;" id="tempIDOFDEVICE-POSOFDEVICE">
</div></div>

         </div>
       </li>
       ''';

       for (any ds in devices) {

         String ctl = ctls.get(ds.key);
         if (TS.notEmpty(ctl)) {
         auto ctll = ctl.split(",");
         log.log("got ctl " + ctl);
         for (Int i = 1;i < ctll.size;i++=) {
           String itype = ctll.get(i);
           log.log("got itype " + itype);
            log.log("got dev " + ds.key + " " + ds.value);
            Map conf = Json:Unmarshaller.unmarshall(ds.value);

            if (itype == "pwm" || itype == "dim" || itype == "sw") {
              String lin = li.swap("NAMEOFDEVICE", conf["name"]);
              lin = lin.swap("IDOFDEVICE", conf["id"]);
              lin = lin.swap("POSOFDEVICE", i.toString());
              String st = states.get(ds.key + "-" + i);
              if (TS.notEmpty(st) && st == "on") {
                lin = lin.swap("DEVICESTATETOG", "checked");
              } else {
                lin = lin.swap("DEVICESTATETOG", "");
              }
              if (itype == "pwm" || itype == "dim") {
                String dlig = dli.swap("IDOFDEVICE", conf["id"]);
                dlig = dlig.swap("POSOFDEVICE", i.toString());
                if (itype == "dim") {
                  dlig = dlig.swap("RANGEMIN", "1");
                  dlig = dlig.swap("RANGEMAX", "255");
                  lin = lin.swap("TOGSTYLE", "");
                } else {
                  dlig = dlig.swap("RANGEMIN", "0");
                  dlig = dlig.swap("RANGEMAX", "255");
                  lin = lin.swap("TOGSTYLE", "style=\"display: none;\"");
                }
                if (levels.has(conf["id"] + "-" + i)) {
                  dlig = dlig.swap("DIMLVL", "value=\"" + levels.get(conf["id"] + "-" + i) + "\"");
                } else {
                  dlig = dlig.swap("DIMLVL", "");
                }
                lin = lin.swap("DIMMERSLIDE", dlig);
              } else {
                lin = lin.swap("DIMMERSLIDE", "");
                lin = lin.swap("TOGSTYLE", "");
              }
              ih += lin;
            } elseIf (itype == "rgb") {
              lin = coli.swap("NAMEOFDEVICE", conf["name"]);
              lin = lin.swap("IDOFDEVICE", conf["id"]);
              lin = lin.swap("POSOFDEVICE", i.toString());
              if (rgbs.has(conf["id"] + "-" + i)) {
                log.log("rgbs had rgb");
                String cs = rgbs.get(conf["id"] + "-" + i);
                log.log("rgb " + cs);
                List csl = cs.split(",");
                String rhx = Int.new(csl[0]).toHexString();
                String ghx = Int.new(csl[1]).toHexString();
                String bhx = Int.new(csl[2]).toHexString();
                hexcol = rhx + ghx + bhx;
                log.log("hexcol " + hexcol);
              } else {
                log.log("rgbs nohad rgb");
                String hexcol = "ffffff";
              }
              lin = lin.swap("HEXCOLOR", hexcol);
              st = states.get(ds.key + "-" + i);
              if (TS.notEmpty(st) && st == "on") {
                lin = lin.swap("DEVICESTATETOG", "checked");
              } else {
                lin = lin.swap("DEVICESTATETOG", "");
              }
              ih += lin;
            }
         }
       }

       }
       
       ih += '''
         </ul>
       </div>
       ''';
       HD.getElementById("hadsList").innerHTML = ih;
     }
   }
   
   hideSaveBusy() {
     HD.getElementById("saveBusy").display = "none";
   }
   
   openAbout() {
     ifEmit(bnbr) {
     emit(js) {
     """
     var win = window.open('https://gitlab.com/bitsii/CasCon/-/wikis/Casnic', '_blank');
     win.focus();
     """
     }
     }
     ifNotEmit(bnbr) {
       HC.callApp(Lists.from("openAboutRequest"));
     }
   }
   
   login() {
      Map arg = Map.new();
      arg["action"] = "loginRequest";
      arg["accountName"] = HD.getElementById("accountName").value;
      arg["accountPass"] = HD.getElementById("accountPass").value;
      arg["sessionName"] = HD.getElementById("sessionName").value;
      //arg["sessionLength"] = HD.getElementById("sessionLength").value;
      
      List sli = HD.getElementsByName("stayLoggedIn");
      log.log("sli length " + sli.length);
      
      if (sli.length > 0 && sli.get(0).checked) {
        arg["sessionLength"] = "-1";
        log.log("set sel neg");
      } else {
         arg["sessionLength"] = "1200";
         log.log("set sel neg not");
      }
      HD.getElementById("accountName").value = "";
      HD.getElementById("accountPass").value = "";
      HD.getElementById("sessionName").value = "";
      handleCallOut(arg);
   }
   
   logout() {
      Map arg = Map.new();
      arg["action"] = "logoutRequest";
      handleCallOut(arg);
   }
   
   informResponse(String info) {
    inform(info);
   }
   
   inform(String r) {
     if (TS.notEmpty(r)) {
      //HD.getElementById("informMessageDiv").innerHTML = r;
      //HD.getElementById("informDiv").display = "block";
      // log.log("can't inform");
       fields {
         String mustInform;
       }
       mustInform = r;
       HD.getEle("openInform").click();
       if (def(r)) {
         log.log(r);
       }
     }
   }
   
   hideInform() {
     HD.getElementById("informDiv").display = "none";
   }
   
}

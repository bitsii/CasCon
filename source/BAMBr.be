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

use Time:Interval;

emit(js) {
  """
  if (typeof(window) !== 'undefined') {
  window.addEventListener('touchstart', function() {
  callUI('gotAction');
});
  }
  """
}

use class IUHub:Eui {

  new() self {
        fields {
          IO:Log log = IO:Logs.get(self);
          List callbacks = Lists.from(self); //plugins
          HC hc = HC.new(callbacks);
          loggedIn = false;
          Bool authless = true;
          ifEmit(bnbr) {
            authless = false;
          }
          log.log("authless " + authless);
        }
    }

    gotAction() {
      //log.log("got some action");
      ifEmit(apwk) {
        lastAction = Time:Interval.now().seconds;
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
      HC.pollUI(List.new().addValue("checkCx"), 1500);
      HC.pollUI(List.new().addValue("checkNexts"), 1000);
      HC.pollUI(List.new().addValue("manageStateUpdates"), 250);
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
   }

   manageStateUpdates() {
     ifEmit(apwk) {
      slots {
        Int lastAction;
      }
      if (undef(lastAction)) {
        lastAction = Time:Interval.now().seconds;
      }
      Int ns = Time:Interval.now().seconds;
      if (ns - lastAction > 30) {
        //log.log("lastAction a while ago skipping manageStateUpdatesRequest");
        return(self);
      }
     }
     unless (loggedIn) { return(self); }
     HC.callApp(Lists.from("manageStateUpdatesRequest"));
   }

   checkCx() {
     unless (loggedIn) { return(self); }
     slots {
       String lastCx;
       //Int lctr;
     }
     /*if (undef(lctr)) {
       lctr = 1;
     } else {
       lctr = lctr++;
       if (lctr > 20000) {
         lctr = 1;
       }
     }*/
     ifEmit(apwk) {
      //String jspw = "getLastCx:" + lctr;
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
      loggedIn = false;
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
     slots {
       Bool loggedIn = true;
     }
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
     any dma = HD.getEle("divMqttAdvanced");
     if (da.display == "block") {
       da.display = "none";
     } else {
       da.display = "block";
     }
     ifEmit(wajv) {
      if (dma.display == "block") {
        dma.display = "none";
      } else {
        dma.display = "block";
      }
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
     HD.getEle("devErr").display = "none";
     HC.callApp(Lists.from("setDeviceSwRequest", dname, pos, state));
   }

   checkBrt(String dname, String pos) {
     log.log("checkBrt " + dname + " " + pos);
     Int statet = HD.getEle("brt" + dname + "-" + pos).value;
     log.log("slidState " + statet);
     HD.getEle("devErr").display = "none";
     HC.callApp(Lists.from("setDeviceRgbcwRequest", dname + "-" + pos, "brt", statet.toString()));
   }

   checkTemp(String dname, String pos) {
     log.log("checkTemp " + dname + " " + pos);
     Int statet = HD.getEle("temp" + dname + "-" + pos).value;
     log.log("slidState " + statet);
     HD.getEle("devErr").display = "none";
     HC.callApp(Lists.from("setDeviceRgbcwRequest", dname + "-" + pos, "temp", statet.toString()));
   }

   checkNexts() {
    unless (loggedIn) { return(self); }
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
         } elseIf (def(visnets)  && visnets.isEmpty && TS.isEmpty(wfd.innerHTML)) {
           //inform("Device cannot find any suitable Wifi networks.  Make sure a 2.4Ghz Wifi Network access point is in range of the device");
           HD.getEle("noWifiTxt").display = "block";
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
       } elseIf (TS.notEmpty(wantSettingsFor)) {
          log.log("have wantsettingsfor, doing that");
          String lwsf = wantSettingsFor;
          wantSettingsFor = null;
          HC.callApp(Lists.from("showDeviceConfigRequest", lwsf));
          return(self);
       } elseIf (TS.isEmpty(ddf.value)) {
        log.log("checkNexts gonna click next device");
        ndb.click();
       }
     }

     auto bs = HD.getEle("setBrightSlide");
     if (bs.exists) {
       if (def(setCurrLvl) && setCurrLvl && def(currLvl)) {
         log.log("setting currLvl");
         setCurrLvl = false;
         Int crli = currLvl;
         emit(js) {
           """
           /*-attr- -noreplace-*/
           //console.log(vapp);
           //console.log(vapp.$f7);
           //var range = vapp.$f7.range.get('.range-slider');
           var range = vapp.$f7.range.get('#bsideRange');
           //console.log("rv");
           //console.log(range.value);
           //console.log(range.setValue(5));
           //console.log(range.getValue());
           range.setValue(bevl_crli.bevi_int);
           """
         }
       }
     }

     auto ts = HD.getEle("setTempSlide");
     if (ts.exists) {
       if (def(setCurrTemp) && setCurrTemp && def(currTemp)) {
         log.log("setting currTemp");
         setCurrTemp = false;
         Int tmli = currTemp;
         emit(js) {
           """
           /*-attr- -noreplace-*/
           //console.log(vapp);
           //console.log(vapp.$f7);
           //var range = vapp.$f7.range.get('.range-slider');
           var range = vapp.$f7.range.get('#btempRange');
           //console.log("rv");
           //console.log(range.value);
           //console.log(range.setValue(5));
           //console.log(range.getValue());
           range.setValue(bevl_tmli.bevi_int);
           """
         }
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
     HC.callApp(Lists.from("showNextDeviceConfigRequest", lastDeviceId));
   }

   discover() {
     //inform("Hey there");
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

   startDeviceSetup() {
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
       HC.callAppLater(Lists.from("getDevWifisRequest", count, true), 3000);
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

   wantSettings(String did) {
     log.log("want settings for " + did);
     slots {
       String wantSettingsFor = did;
     }
   }

   /*checkSlid(String dname, String pos) {
     log.log("checkSlid " + dname + " " + pos);
     Int statet = HD.getEle("sli" + dname + "-" + pos).value;
     log.log("slidState " + statet);
     HD.getEle("hat" + dname + "-" + pos).checked = true;
     HD.getEle("devErr").display = "none";
     HC.callApp(Lists.from("setDeviceLvlRequest", dname + "-" + pos, statet.toString()));
   }*/

   tempChanged(Int value) {
     log.log("temp changed " + value);
     if (def(currTemp) && currTemp == value) {
       "not really is curr temp".print();
     } else {
       currTemp = value;
       HD.getEle("hat" + setTempDid + "-" + setTempPos).checked = true;
       HD.getEle("devErr").display = "none";
       HC.callApp(Lists.from("setDeviceTempRequest", setTempDid + "-" + setTempPos, currTemp.toString()));
     }
   }

   setForTemp(String did, String pos) {
     log.log("in setForTemp " + did + " " + pos);
     String cw = cws.get(did + "-" + pos);
     if (TS.notEmpty(cw)) {
       log.log("cw " + cw);
     } else {
       log.log("no cw");
       cw = "255,255";
     }
     slots {
        //Int currTemp = Int.new(cwsv);
        Int currTemp = 127;
        Bool setCurrTemp = true;
        String setTempDid = did;
        String setTempPos = pos;
     }
   }

   brightChanged(Int value) {
     log.log("bright changed " + value);
     if (def(currLvl) && currLvl == value) {
       "not really is curr lvl".print();
     } else {
       currLvl = value;
       HD.getEle("hat" + setBrightDid + "-" + setBrightPos).checked = true;
       HD.getEle("devErr").display = "none";
       HC.callApp(Lists.from("setDeviceLvlRequest", setBrightDid + "-" + setBrightPos, currLvl.toString()));
     }
   }

   setForDim(String did, String pos) {
     log.log("in setForDim " + did + " " + pos);
     String lvl = levels.get(did + "-" + pos);
     if (TS.notEmpty(lvl)) {
       log.log("lvl " + lvl);
     } else {
       log.log("no lvl");
       lvl = "255";
     }
     slots {
        Int currLvl = Int.new(lvl);
        Bool setCurrLvl = true;
        String setBrightDid = did;
        String setBrightPos = pos;
     }
   }

   colorChanged() {
     log.log("in colorChanged");
     String res;
     emit(js) {
      """
      if (self.bevi_colorWheelValue != null) {
         bevl_res = new be_$class/Text:String$().bems_new(self.bevi_colorWheelValue.hex);
      }
      """
     }
     if (TS.notEmpty(res) && TS.notEmpty(setColorDid) && TS.notEmpty(setColorPos)) {
       log.log("colorChanged to " + res);
       String rh = res.substring(1,3);
       log.log("rh " + rh);
       Int rhi = Int.hexNew(rh);

       String gh = res.substring(3,5);
       log.log("gh " + gh);
       Int ghi = Int.hexNew(gh);

       String bh = res.substring(5,7);
       log.log("bh " + bh);
       Int bhi = Int.hexNew(bh);

       String rgb = rhi.toString() + "," + ghi.toString() + "," + bhi.toString();

       unless (def(ignoreNextColorChange) && ignoreNextColorChange) {
        log.log("colorChanged r,g,b " + rgb);
        HD.getEle("devErr").display = "none";
        HD.getEle("hat" + setColorDid + "-" + setColorPos).checked = true;
        HC.callApp(Lists.from("setDeviceRgbRequest", setColorDid + "-" + setColorPos, rgb));
       } else {
        log.log("colorChanged first ignored " + rgb);
        ignoreNextColorChange = false;
       }
     } else {
       log.log("res null in colorChanged");
     }
   }

   setForColor(String did, String pos) {
     log.log("in setForColor " + did + " " + pos);

     String rgb = rgbs.get(did + "-" + pos);
     if (TS.notEmpty(rgb)) {
       log.log("rgb " + rgb);
     } else {
       log.log("no rgb");
       rgb = "255,255,255";
     }
     slots {
        String setColorDid = did;
        String setColorPos = pos;
        Bool wheelBeenMade;
        String setColorRgb = rgb;
        Bool ignoreNextColorChange = true;
     }
     unless (def(wheelBeenMade) && wheelBeenMade) {
     emit(js) {
       """
      /*-attr- -noreplace-*/
      var colorPickerWheel = vapp.$f7.colorPicker.create({
      inputEl: '#demo-color-picker-wheel',
      targetEl: '#demo-color-picker-wheel-value',
      targetElSetBackgroundColor: false,
      modules: ['palette', 'wheel'],
      on: {
        change(cp, value) {
          self.bevi_colorWheelValue = value;
          callUI('colorChanged');
        },
      },
      //openIn: 'popover',
      openIn: 'page',
      //openInPhone: 'popup',
      //openIn: 'popup',//ok, consistent with dim
      //openIn: 'sheet',//bad
      value: {
        hex: '#ffffff',
      },
      palette: [
    ['#FFEBEE', '#FFCDD2', '#EF9A9A', '#E57373', '#EF5350', '#F44336', '#E53935', '#D32F2F', '#C62828', '#B71C1C'],
    ['#F3E5F5', '#E1BEE7', '#CE93D8', '#BA68C8', '#AB47BC', '#9C27B0', '#8E24AA', '#7B1FA2', '#6A1B9A', '#4A148C'],
    ['#E8EAF6', '#C5CAE9', '#9FA8DA', '#7986CB', '#5C6BC0', '#3F51B5', '#3949AB', '#303F9F', '#283593', '#1A237E'],
    ['#E1F5FE', '#B3E5FC', '#81D4FA', '#4FC3F7', '#29B6F6', '#03A9F4', '#039BE5', '#0288D1', '#0277BD', '#01579B'],
    ['#E0F2F1', '#B2DFDB', '#80CBC4', '#4DB6AC', '#26A69A', '#009688', '#00897B', '#00796B', '#00695C', '#004D40'],
    ['#F1F8E9', '#DCEDC8', '#C5E1A5', '#AED581', '#9CCC65', '#8BC34A', '#7CB342', '#689F38', '#558B2F', '#33691E'],
    ['#FFFDE7', '#FFF9C4', '#FFF59D', '#FFF176', '#FFEE58', '#FFEB3B', '#FDD835', '#FBC02D', '#F9A825', '#F57F17'],
    ['#FFF3E0', '#FFE0B2', '#FFCC80', '#FFB74D', '#FFA726', '#FF9800', '#FB8C00', '#F57C00', '#EF6C00', '#E65100'],
  ],
  formatValue: function (value) {
    return value.hex;
  },
    });
      this.bevi_colorPickerWheel = colorPickerWheel;
       """
     }
     wheelBeenMade = true;
     }

     List csl = rgb.split(",");
     String rhx = Int.new(csl[0]).toHexString();
     String ghx = Int.new(csl[1]).toHexString();
     String bhx = Int.new(csl[2]).toHexString();
     String hexcol = "#" + rhx + ghx + bhx;

     emit(js) {
       """
       this.bevi_colorPickerWheel.setValue({ hex: bevl_hexcol.bems_toJsString() });
       this.bevi_colorPickerWheel.open();
       """
     }
   }
   
   getDevicesResponse(Map devices, Map ctls, Map states, Map _levels, Map _rgbs, Map _cws, Int nsecs) {
     log.log("in getDevicesResponse");
     slots {
       Map devCtls = ctls;
       Map levels = _levels;
       Map rgbs = _rgbs;
       Map cws = _cws;
     }
     if (nsecs > 0) {
       nextInform = Interval.new(nsecs, 0);
     }
     HD.getEle("hider").display = "none";
     if (def(devices) && devices.size > 0) {
     Encode:Hex eh = Encode:Hex.new();

       String li = '''
       <li class="item-content">
         <div class="item-inner">
           <div class="item-title" style="width:150px;"><a href="/settings/" onclick="callUI('wantSettings','IDOFDEVICE');return true;">NAMEOFDEVICE</a></div>
           FORCOL
           FORCW
           FORDIM
           <div class="item-after">
             <label class="toggle">
               <input type="checkbox" onclick="callUI('checkToggled', 'IDOFDEVICE', 'POSOFDEVICE');return true;" id="hatIDOFDEVICE-POSOFDEVICE" DEVICESTATETOG/>
               <span class="toggle-icon"></span>
             </label>
           </div>
         </div>
       </li>
       ''';

       String forcol = '''
           <div class="item-after">
           <a href="#" onclick="callUI('setForColor', 'IDOFDEVICE', 'POSOFDEVICE');return false;" class="col button"><i class="icon f7-icons">color_filter</i></a>
           </div>
       ''';

       String forcw = '''
           <div class="item-after">
           <a href="#" data-popup="#settemp" onclick="callUI('setForTemp', 'IDOFDEVICE', 'POSOFDEVICE');return true;" class="col button popup-open"><i class="icon f7-icons">fire</i></a>
           </div>
       ''';

      String fordim = '''
       <div class="item-after">
           <a href="#" data-popup="#setbright" onclick="callUI('setForDim', 'IDOFDEVICE', 'POSOFDEVICE');return true;" class="col button popup-open"><i class="icon f7-icons">bulb</i></a>
           </div>
      ''';

       String ih = '''
           <div class="list">
        <ul>
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
            if (itype == "dim" || itype == "gdim" || itype == "sw" || itype == "rgb" || itype == "rgbgdim" || itype == "rgbcwgd") {
              String lin = li.swap("NAMEOFDEVICE", conf["name"]);
              if (itype == "rgb" || itype == "rgbgdim" || itype == "rgbcwgd") {
                lin = lin.swap("FORCOL", forcol);
              } else {
                lin = lin.swap("FORCOL", "");
              }
              if (itype == "dim" || itype == "gdim" || itype == "rgbgdim" || itype == "rgbcwgd") {
                lin = lin.swap("FORDIM", fordim);
              } else {
                lin = lin.swap("FORDIM", "");
              }
              if (itype == "rgbcwgd") {
                lin = lin.swap("FORCW", forcw);
              } else {
                lin = lin.swap("FORCW", "");
              }
              lin = lin.swap("IDOFDEVICE", conf["id"]);
              lin = lin.swap("POSOFDEVICE", i.toString());
              String st = states.get(ds.key + "-" + i);
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
       try {
         HD.getElementById("hadsList").innerHTML = ih;
         HD.getEle("devErr").display = "none";
       } catch (any e) {
         log.log("got except writing  hadsList");
         HD.reload();
       }
     }
   }
   
   hideSaveBusy() {
     HD.getElementById("saveBusy").display = "none";
   }

   showDevErrorResponse() {
     HD.getEle("devErr").display = "block";
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
     slots {
       Time:Interval nextInform;
     }
     if (def(nextInform) && nextInform > Time:Interval.now()) {
       log.log("not been long enough on inform, not informing");
       return(null);
     }
     nextInform = Time:Interval.now().addSeconds(75); //comment to see all the informs
     if (TS.notEmpty(r)) {
      //HD.getElementById("informMessageDiv").innerHTML = r;
      //HD.getElementById("informDiv").display = "block";
      // log.log("can't inform");
       fields {
         String mustInform;
       }
       mustInform = r;
       //HD.getEle("lres").value = r;
       HD.getEle("openInform").click();
       if (def(r)) {
         log.log(r);
       }
     }
     HC.callApp(Lists.from("didInformRequest"));
   }
   
   hideInform() {
     HD.getElementById("informDiv").display = "none";
   }
   
}

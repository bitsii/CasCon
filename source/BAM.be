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

use IO:File:Path;
use IO:File;
use System:Random;
use UI:WebBrowser as WeBr;
use Test:Assertions as Assert;
use Db:KeyValue as KvDb;
use System:Thread:Lock;
use System:Thread:ContainerLocker as CLocker;
use System:Command as Com;
use Time:Sleep;
use Container:Pair;
use System:CurrentPlatform as Plat;

use Crypto:Symmetric as Crypt;

use App:Alert;
use App:Account;

use System:Exceptions as E;

use App:LocalWebApp;
use App:RemoteWebApp;
use App:WebApp;
use Text:String;
use App:CallBackUI;
use CasNic:CasProt;

use System:Thread:Lock;
use System:Thread:ObjectLocker as OLocker;

use System:Parameters;
use Encode:Hex as Hex;

use class BA:EDevPlugin {

     new() self {
       fields {
          any app;
          IO:Log log;
          Bool run = true;
        }
        super.new();
        log = IO:Logs.get(self);
        IO:Logs.turnOnAll();
     }
     
     appSet(any _app) {
       "in appset".print();
       app = _app;
     }
     
     
     start() {
     
      //if (Logic:Bools.fromString(app.configManager.get("logs.turnOnAll"))) {
        IO:Logs.turnOnAll();
      //}
      
      log.log("in edev start");
      
      app.configManager;
      
    }
    
    handleWeb(request) this {
      
      request.continueHandling = true;
    }
      
     nameGet() String {
       String name = "EDev";
       return(name);
     }
     
     dataNameGet() String {
       fields {
        String dataName;
       }
       if (undef(dataName)) {
         dataName = "CasCon";
         ifEmit(bnbr) {
          dataName = "KBridge";
         }
       }
       return(dataName);
     }
     
}

emit(jv) {
"""
import java.io.*;
import java.net.*;
import java.util.List;
import java.lang.reflect.Method;
"""
}

ifEmit(jvad) {
emit(jv) {
"""
import android.net.nsd.*;
import android.content.Context;
import android.net.wifi.WifiManager;
import android.net.wifi.WifiConfiguration;
import android.net.wifi.WifiInfo;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkRequest;
import android.net.wifi.WifiNetworkSpecifier;
import android.os.Build;

import casnic.control.MainActivity;

"""
}
}
use class BA:BamPlugin(App:AjaxPlugin) {

  ifEmit(jvad) {
  emit(jv) {
    """
    public NsdManager.DiscoveryListener discoveryListener;
    public static NsdManager nsdManager;
    //public WifiManager wifi;
    //WifiManager.MulticastLock multicastLock;
    public boolean gotOnDevNetwork = false;
    ConnectivityManager lastConnectivityManager;
    ConnectivityManager.NetworkCallback lastNetworkCallback;


    public static class InitializeResolveListener implements NsdManager.ResolveListener {

    public static java.util.Hashtable<String, String> knownDevices = new java.util.Hashtable<String, String>();
    public static java.util.Hashtable<String, String> knownAddresses = new java.util.Hashtable<String, String>();
    public static java.util.Hashtable<String, NsdServiceInfo> resolving = new java.util.Hashtable<String, NsdServiceInfo>();

    @Override
    public void onResolveFailed(NsdServiceInfo serviceInfo, int errorCode) {
      System.out.println("Resolve failed" + errorCode);
    }

    @Override
    public void onServiceResolved(NsdServiceInfo serviceInfo) {
      System.out.println("Resolve Succeeded. " + serviceInfo);

      int port = serviceInfo.getPort();
      InetAddress host = serviceInfo.getHost(); // getHost() will work now

      System.out.println("Host: " + host.getHostAddress());

      //String sname = serviceInfo.toString();
      //sname = sname.substring( 0, sname.indexOf(","));
      String sname = serviceInfo.getServiceName();

      String hip = host.getHostAddress().toString();

      System.out.println("sname |" + sname + "| hip |" + hip + "|");

      knownDevices.put(sname, hip);
      knownAddresses.put(hip, sname);
      resolving.remove(sname);
      if (!resolving.isEmpty()) {
        try {
          NsdServiceInfo[] rs = (NsdServiceInfo[]) resolving.values().toArray();
          int rnd = new java.util.Random().nextInt(rs.length);
          nsdManager.resolveService(rs[rnd], new InitializeResolveListener());
        } catch (ClassCastException cce) {
          System.out.println("class cast exception in resolving");
          resolving.clear();
        }
      }
    }
  };

    """
  }
  }

     new() self {
       fields {
          String homePage = "/App/" + self.name + "/BAM.html";
          any app;
          Map cmdQueues = Map.new();
          CasProt prot = CasProt.new();
        }
        super.new();
        log = IO:Logs.get(self);
        IO:Logs.turnOnAll();
     }
     
     appSet(any _app) {
       "in appset".print();
       app = _app;
       if (app.can("heightSet", 0)) {
         "can set height".print();
         app.height = 700;
       }
     }
     
     
     start() {
     
      //if (Logic:Bools.fromString(app.configManager.get("logs.turnOnAll"))) {
        IO:Logs.turnOnAll();
      //}
      
      log.log("in bam start");
      
      app.configManager;
      if (def(app.pluginsByName.get("Auth"))) {
        app.pluginsByName.get("Auth").authedUrlsConfigKey = "bridgeAuthedUrls";
      }

      initializeDiscoveryListener();

    }

    handleWeb(request) this {
      //log.log("request uri " + request.uri);
      //log.log("handle as jsonajax");
      Account a;
      ifEmit(platDroid) {
        a = Account.new();
        a.user = "Adrian";
        a.perms.put("admin");
        request.context.put("account", a);
      }
      ifEmit(apwk) {
        a = Account.new();
        a.user = "Adrian";
        a.perms.put("admin");
        request.context.put("account", a);
      }
      ifEmit(wajv) {
        a = Account.new();
        a.user = "Adrian";
        a.perms.put("admin");
        request.context.put("account", a);
      }
      super.handleWeb(request);
     }
      
     nameGet() String {
       String name = "CasCon";
       return(name);
     }
     
     dataNameGet() String {
       fields {
        String dataName;
       }
       if (undef(dataName)) {
         dataName = "CasCon";
         ifEmit(bnbr) {
          dataName = "KBridge";
         }
       }
       return(dataName);
     }
     
     openAboutRequest(request) {
      UI:ExternalBrowser.openToUrl("https://gitlab.com/bitsii/CasCon/-/wikis/Casnic");
     }
     
     handleCmd(Parameters params) Bool {
      String mode = params.getFirst("bamCmd");
      IO:Logs.turnOnAll();
      log.log("hi from handlecmd bam");
      if (TS.isEmpty(mode)) {
        return(false);
      }
      return(true);
    }
    
    showDeviceConfigRequest(String lastDid, request) Map {
      log.log("in showDeviceConfigRequest ");
      if (TS.notEmpty(lastDid)) {
        log.log("lastDid " + lastDid);
        Bool retnext = false;
      } else {
        log.log("lastDid empty");
        retnext = true;
      }
      Account account = request.context.get("account");
      auto uhex = Hex.encode(account.user);
      auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
      auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
      auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
      auto haowns = app.kvdbs.get("HAOWNS"); //haowns - prefix account hex to map of owned device ids
      
      
       for (any kv in haowns.getMap(uhex + ".")) {
         String did = kv.value;
         String confs = hadevs.get(did);
         if (retnext) {
           log.log("returning conf " + confs);
           return(CallBackUI.showDeviceConfigResponse(addFtype(confs), getCachedIp(confs)));
         }
         if (lastDid == did) {
           retnext = true;
         }
       }
       if (TS.notEmpty(confs)) {
         log.log("returning conf " + confs);
         return(CallBackUI.showDeviceConfigResponse(addFtype(confs), getCachedIp(confs)));
       }
       return(null);
    }

    getCachedIp(String confs) String {
     Map conf = Json:Unmarshaller.unmarshall(confs);
      //getting the name
     String kdname = "CasNic" + conf["ondid"];
     return(getCashedAddr(kdname));
    }

    addFtype(String confs) String {
     Map conf = Json:Unmarshaller.unmarshall(confs);
     //typeFriendly
     conf["typeFriendly"] = ftypeForType(conf.get("type"));
     confs = Json:Marshaller.marshall(conf);
     return(confs);
    }

    getIp(String confs) String {
     Map conf = Json:Unmarshaller.unmarshall(confs);
      //getting the name
     String kdname = "CasNic" + conf["ondid"];
     return(getAddr(kdname));
    }

    getCashedAddr(String kdname) {
      String kdaddr;
      if (def(knc) && knc.has(kdname)) {
          kdaddr = knc.get(kdname);
      } else {
        auto haknc = app.kvdbs.get("HAKNC"); //kdname to addr
        String tkda = haknc.get(kdname);
        if (TS.notEmpty(tkda)) {
          kdaddr = tkda;
        }
      }
      return(kdaddr);
    }

    getAddr(String kdname) {
      String kdaddr;

      slots {
        Map knc;
        Map kac;
      }
      if (undef(knc)) {
        knc = Map.new();
        kac = Map.new();
      }

     if (knc.has(kdname)) {
          kdaddr = knc.get(kdname);
     } else {
        auto haknc = app.kvdbs.get("HAKNC"); //kdname to addr
        String tkda = haknc.get(kdname);
        if (TS.notEmpty(tkda)) {
          kdaddr = tkda;
        } else {
          ifEmit(wajv) {
            emit(jv) {
              """
              try {
            InetAddress address = InetAddress.getByName(beva_kdname.bems_toJvString() + ".local");
            //System.out.println(address.getHostAddress());
            String wadr = address.getHostAddress();
            bevl_kdaddr =  new $class/Text:String$(wadr.getBytes("UTF-8"));
              } catch (Exception e) {

            }
            """
            }
          }
          ifEmit(jvad) {
          emit(jv) {
            """
            //new $class/Text:String$(fnames[i].getBytes("UTF-8"))
            String kdaddr = InitializeResolveListener.knownDevices.get(beva_kdname.bems_toJvString());
            if (kdaddr != null) {
              bevl_kdaddr =  new $class/Text:String$(kdaddr.getBytes("UTF-8"));
            }
            """
          }
          }
            ifEmit(apwk) {
               app.runAsync("CasCon", "goGetAddr", Lists.from(kdname));
            }
        }

      if (TS.notEmpty(kdaddr)) {
          knc.put(kdname, kdaddr);
          kac.put(kdaddr, kdname);
          haknc.put(kdname, kdaddr);
      }
     }
     if (TS.notEmpty(kdaddr)) { log.log("got kdaddr " + kdaddr + " for " + kdname); } else { log.log("got no kdaddr for " + kdname); }
      return(kdaddr);
    }

    goGetAddr(String kdname) {
      app.configManager;
      auto haknc = app.kvdbs.get("HAKNC"); //kdname to addr
      String tkda = haknc.get(kdname);
      if (TS.isEmpty(tkda)) {
        ifEmit(apwk) {
            String jspw = "getAddr:" + kdname + ".local";
            emit(js) {
            """
            var jsres = prompt(bevl_jspw.bems_toJsString());
            bevl_jspw = new be_$class/Text:String$().bems_new(jsres);
            """
            }
            if (TS.notEmpty(jspw)) {
              haknc.put(kdname, jspw);
            }
          }
        }
    }

    getAddrDis(String kdname) {
     log.log("kdname " + kdname);
     String kdaddr = getAddr(kdname);
     return(kdaddr);
    }
   
   checkPublicReadPath(Path pa, request) Bool {
      String pas = pa.toString();
      Path adz = Path.apNew("App/" + self.name).file.absPath;
      if (pas.begins(adz.toString()) && (pas.ends(".html") || pas.ends(".js") || pas.ends(".svg") || pas.ends(".txt") || pas.ends(".css") || pas.ends(".woff2") || pas.ends(".woff") || pas.ends(".ttf") || pas.ends(".map"))) {
        return(true);
      }
      return(false);
   }
   
   getLoginUri(request) String {
     String loginBookmark = "/App/" + self.name + "/BAM.html";
     return(loginBookmark);
   }

   acceptShareRequest(String cx, request) Map {
     log.log("in asr " + cx);
     clearCxRequest(request);
     String confs = Encode:Hex.decode(cx);
     Map conf = Json:Unmarshaller.unmarshall(confs);
     conf["id"] = System:Random.getString(11);
     String controlDef = conf["controlDef"];
     if (TS.notEmpty(controlDef)) {
       auto hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
       hactls.put(conf["id"], controlDef);
       conf.delete("controlDef");
     }
     confs = Json:Marshaller.marshall(conf);
     saveDeviceRequest(conf["id"], confs, request);
     //rectlDeviceRequest(conf["id"], request);
     return(CallBackUI.reloadResponse());
     //return(null);
   }

   clearOldDataRequest(request) Map {
     "in clearOldDataRequest()".print();

     Account account = request.context.get("account");
     auto uhex = Hex.encode(account.user);
     auto hapins = app.kvdbs.get("HAPINS"); //hapins - uh.pin to devpass
     auto hapinid = app.kvdbs.get("HAPINID"); //hapinid - uh.pin to id
     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config

     Set toKeep = Set.new();

     for (kv in hapinid.getMap(uhex + ".")) {
       if (hadevs.has(kv.value)) {
         ("not deleting hapinid " + kv.key).print();
         toKeep += kv.key;
       } else {
        ("deleting hapinid " + kv.key).print();
        hapinid.delete(kv.key);
       }
     }

     for (auto kv in hapins.getMap(uhex + ".")) {
       if (toKeep.has(kv.key)) {
         ("keeping hapins " + kv.key).print();
       } else {
        ("deleting hapins " + kv.key).print();
        hapins.delete(kv.key);
       }
     }

     return(null);
   }
   
   deleteDeviceRequest(String did, request) Map {
     log.log("in removeDeviceRequest " + did);
     
    Account account = request.context.get("account");
    auto uhex = Hex.encode(account.user);
    auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device aid to config
    auto hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
    auto hasw = app.kvdbs.get("HASW"); //hasw - device aid to switch state
    auto halv = app.kvdbs.get("HALV"); //halv - device aid to lvl
    auto haowns = app.kvdbs.get("HAOWNS"); //haowns - prefix account hex to map of owned device aids
    auto haknc = app.kvdbs.get("HAKNC"); //kdname to addr
    
    String confs = hadevs.get(did);
    if (TS.notEmpty(confs)) {
      Map conf = Json:Unmarshaller.unmarshall(confs);
      //getting the name
      if (TS.notEmpty(conf["ondid"])) {
        String kdname = "CasNic" + conf["ondid"];
        haknc.delete(kdname);
      }
    }

    haowns.delete(uhex + "." + did);
    hadevs.delete(did);

    String ctl = hactls.get(did);
    if (TS.notEmpty(ctl)) {
      auto ctll = ctl.split(",");
      log.log("got ctl " + ctl);
      for (Int i = 1;i < ctll.size;i++=) {
        hasw.delete(did + "-" + i);
        halv.delete(did + "-" + i);
      }
      hactls.delete(did);
    }
    return(CallBackUI.reloadResponse());
   }

   resetDeviceRequest(String did, request) Map {
     log.log("in resetDeviceRequest " + did);

     //not checking user rn
     Account account = request.context.get("account");
     auto uhex = Hex.encode(account.user);
     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     auto haowns = app.kvdbs.get("HAOWNS"); //haowns - prefix account hex to map of owned device ids

     String confs = hadevs.get(did);
     Map conf = Json:Unmarshaller.unmarshall(confs);

     //dostate eek setsw on e
     String cmds = "reset " + conf["pass"] + " e";
     log.log("cmds " + cmds);

     //getting the name
     String kdname = "CasNic" + conf["ondid"];
     String kdaddr = getAddrDis(kdname);

     //tcpjv edition

     //cmds += "\r\n";

     Map mcmd = Maps.from("cb", "resetDeviceCb", "did", did, "kdaddr", kdaddr, "pwt", 1, "pw", conf["pass"], "cmds", cmds);

     sendDeviceMcmd(mcmd);

     return(null);

   }

   resetDeviceCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     if (TS.isEmpty(cres)) {
       log.log("reset got no cres");
       throw(Alert.new("Device did not respond to reset request"));
     } else {
       if (cres.has("Device reset")) {
         log.log("reset worked");
         if (mcmd.has("did")) {
         log.log("will delete device");
          return(deleteDeviceRequest(mcmd["did"], request));
         }
       } else {
        log.log("reset failed");
        unless (mcmd.has("did")) {
         if (cres.has("resetbypin not enabled")) {
           throw(Alert.new("Device does not support unconfigured software reset, check device for physical reset option (possibly >30s long push of button, if present)"));
         }
        }
       }
     }
     unless (mcmd.has("did")) {
        return(CallBackUI.reloadResponse());
     }
     return(null);
   }

   sendDeviceCommandRequest(String did, String cmdline, request) Map {
     log.log("in sendDeviceCommandRequest " + did);

     if (TS.isEmpty(cmdline)) {
       return(CallBackUI.seeDeviceCommandResponse("EMPTY COMMAND"));
     }

     //not checking user rn
     Account account = request.context.get("account");
     auto uhex = Hex.encode(account.user);
     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     auto haowns = app.kvdbs.get("HAOWNS"); //haowns - prefix account hex to map of owned device ids

     String confs = hadevs.get(did);
     Map conf = Json:Unmarshaller.unmarshall(confs);

     auto cmdl = cmdline.split(" ");
     Int pt = 0;
     String tp = "";
     if (cmdl.size > 1) {
       Bool didpass = false;
       if (cmdl[1] == "pass") {
         cmdl[1] = conf["pass"];
         didpass = true;
         pt = 1;
         tp = conf["pass"];
       } elseIf (cmdl[1] == "spass") {
         cmdl[1] = conf["spass"];
         didpass = true;
         pt = 2;
         tp = conf["spass"];
       }
       if (didpass) {
         cmdline = Text:Strings.new().join(Text:Strings.new().space, cmdl);
       }
     }

     //dostate eek setsw on e
     String cmds = cmdline;
     log.log("cmds " + cmds);

     //getting the name
     String kdname = "CasNic" + conf["ondid"];
     String kdaddr = getAddrDis(kdname);

     //tcpjv edition

     //cmds += "\r\n";

     Map mcmd = Maps.from("cb", "sendDeviceCommandCb", "kdaddr", kdaddr, "pwt", pt, "pw", tp, "cmds", cmds);

     sendDeviceMcmd(mcmd);

     return(null);

   }

   sendDeviceCommandCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     if (TS.isEmpty(cres)) {
       cres = "GOT NO RES";
     }
     return(CallBackUI.seeDeviceCommandResponse(cres));
   }
   
   saveDeviceRequest(String did, String confs, request) Map {
     log.log("in addDeviceRequest " + confs);
     
     Account account = request.context.get("account");
     auto uhex = Hex.encode(account.user);
     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     //auto hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
     //auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     //auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     auto haowns = app.kvdbs.get("HAOWNS"); //haowns - prefix account hex to map of owned device ids
     
     //String did = System:Random.getString(16);
     


     hadevs.put(did, confs);
     haowns.put(uhex + "." + did, did);
     
     return(CallBackUI.reloadResponse());
   }

   loadWifiRequest(request) Map {
     Account account = request.context.get("account");
     auto uhex = Hex.encode(account.user);
     auto hawifi = app.kvdbs.get("HAWIFI"); //account hex to wifi network

     String ssid = hawifi.get(uhex + ".ssid.0");
     String sec = hawifi.get(uhex + ".sec.0");
     if (undef(ssid)) { ssid = ""; }
     if (undef(sec)) { sec = ""; }
     return(CallBackUI.setElementsValuesResponse(Maps.from("wifiSsid", ssid, "wifiSec" sec)));
   }

   loadMqttRequest(request) Map {

     String mqttBroker = app.configManager.get("mqtt.broker");
     String mqttUser = app.configManager.get("mqtt.user");
     String mqttPass = app.configManager.get("mqtt.pass");
     if (undef(mqttBroker)) { mqttBroker = ""; }
     if (undef(mqttUser)) { mqttUser = ""; }
     if (undef(mqttPass)) { mqttPass = ""; }

     return(CallBackUI.setElementsValuesResponse(Maps.from("mqttBroker", mqttBroker, "mqttUser" mqttUser, "mqttPass", mqttPass)));
   }

   saveWifiRequest(String ssid, String sec, Bool reloadAfter, request) Map {

     Account account = request.context.get("account");
     auto uhex = Hex.encode(account.user);
     auto hawifi = app.kvdbs.get("HAWIFI"); //account hex to wifi network

     if (TS.notEmpty(ssid) && TS.notEmpty(sec)) {
      hawifi.put(uhex + ".ssid.0", ssid);
      hawifi.put(uhex + ".sec.0", sec);
      log.log("saved " + ssid + " " + sec + " for wifi for user hex " + uhex);
     } elseIf (TS.isEmpty(ssid) && TS.isEmpty(sec)) {
      hawifi.delete(uhex + ".ssid.0");
      hawifi.delete(uhex + ".sec.0");
      log.log("cleared wifi");
     }

     if (reloadAfter) {
      return(CallBackUI.reloadResponse());
     }
     return(null);
   }

   saveMqttRequest(String mqttBroker, String mqttUser, String mqttPass, request) Map {

     if (TS.notEmpty(mqttBroker) && TS.notEmpty(mqttUser) && TS.notEmpty(mqttPass)) {
      app.configManager.put("mqtt.broker", mqttBroker);
      app.configManager.put("mqtt.user", mqttUser);
      app.configManager.put("mqtt.pass", mqttPass);
      log.log("saved mqtt");
     } else {
      app.configManager.delete("mqtt.broker");
      app.configManager.delete("mqtt.user");
      app.configManager.delete("mqtt.pass");
      log.log("cleared mqtt");
     }
     return(CallBackUI.reloadResponse());
   }
   
   getDevicesRequest(request) Map {
     log.log("in getDevicesRequest");
     slots {
       Bool stDiffed = false;
       Set pendingStateUpdates;
       Map lastDevices;
       Int howManyDevices;
     }
     if (undef(pendingStateUpdates)) {
       pendingStateUpdates = Set.new();
     }
     Account account = request.context.get("account");
     auto uhex = Hex.encode(account.user);
     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     auto hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     auto hargb = app.kvdbs.get("HARGB"); //hargb - device id to rgb
     auto haowns = app.kvdbs.get("HAOWNS"); //haowns - prefix account hex to map of owned device ids
     Map devices = Map.new();
     Map ctls = Map.new();
     Map states = Map.new();
     Map levels = Map.new();
     Map rgbs = Map.new();
     for (any kv in haowns.getMap(uhex + ".")) {
       String did = kv.value;
       String confs = hadevs.get(did);
       devices.put(did, confs);
       String ctl = hactls.get(did);
       if (TS.notEmpty(ctl)) {
         ctls.put(did, ctl);
        auto ctll = ctl.split(",");
        log.log("got ctl " + ctl);
        for (Int i = 1;i < ctll.size;i++=) {
          String itype = ctll.get(i);
          String psu = itype + "," + did + "," + i;
          //pendingStateUpdates += psu;
          String st = hasw.get(did + "-" + i);
          if (TS.notEmpty(st)) {
            states.put(did + "-" + i, st);
          }
          String lv = halv.get(did + "-" + i);
          if (TS.notEmpty(lv)) {
            //log.log("got lv " + lv);
            levels.put(did + "-" + i, lv);
          }
          log.log("getting rgb for " + did + "-" + i);
          String rgb = hargb.get(did + "-" + i);
          if (TS.notEmpty(rgb)) {
            log.log("got rgb " + rgb);
            rgbs.put(did + "-" + i, rgb);
          }
        }
       }
     }
     lastDevices = devices;
     howManyDevices = devices.size.copy();
     return(CallBackUI.getDevicesResponse(devices, ctls, states, levels, rgbs));
   }

   getLastEventsRequest(String did, request) {
     log.log("in getLastEventsRequest " + did);

     //not checking user rn
     Account account = request.context.get("account");
     auto uhex = Hex.encode(account.user);
     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     auto haowns = app.kvdbs.get("HAOWNS"); //haowns - prefix account hex to map of owned device ids

     String confs = hadevs.get(did);
     try {
     Map conf = Json:Unmarshaller.unmarshall(confs);
     } catch (any e) {
       log.elog("error in gle", e);
       return(null);
     }
     String cmds = "getlastevents e";
     log.log("cmds " + cmds);

     //getting the name
     String kdname = "CasNic" + conf["ondid"];
     String kdaddr = getAddrDis(kdname);
     //String kdaddr = getCashedAddr(kdname);

     //tcpjv edition

     //cmds += "\r\n";

     if (def(kdaddr)) {
       Map mcmd = Maps.from("cb", "getLastEventsCb", "did", did, "kdaddr", kdaddr, "pwt", 0, "pw", "", "cmds", cmds);

       sendDeviceMcmd(mcmd, 3);

     } else {
      log.log("getlastevents kdaddr empty");
     }

     return(null);
   }

   getLastEventsCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String leid = mcmd["did"];
     if (TS.notEmpty(cres)) {
        log.log("getlastevents cres |" + cres + "|");
        //for (Int ji = 0;ji < cres.size;ji++=) {
        //  log.log("gle ji " + cres.getCode(ji));
        //}
        if (TS.notEmpty(cres)) {
              String ores = currentEvents.get(leid);
              if (TS.notEmpty(ores)) {
                //log.log("ores ne comparing");
                if (cres != ores) {
                  //log.log("cres ores unequal");
                  auto ol = ores.split(";");
                  auto cl = cres.split(";");
                  if (ol.size == cl.size) {
                    for (Int i = 0;i < cl.size;i++=) {
                      String ci = cl.get(i);
                      String oi = ol.get(i);
                      if (TS.notEmpty(ci) && TS.notEmpty(oi) && ci != oi) {
                        log.log("found diffed events " + ci + " " + oi);
                        auto de = ci.split(",");
                        if (def(pendingStateUpdates)) {
                          Int pos = Int.new(de.get(1));
                          pos++=;
                          String psu = de.get(0) + "," + leid + "," + pos;
                          pendingStateUpdates += psu;
                        }
                      }
                    }
                  }
                }
              } else {
               log.log("not found in currentEvents, getting all states");
                cl = cres.split(";");
                for (i = 0;i < cl.size;i++=) {
                  ci = cl.get(i);
                  if (TS.notEmpty(ci)) {
                    log.log("found new events " + ci);
                    de = ci.split(",");
                    if (def(pendingStateUpdates)) {
                      pos = Int.new(de.get(1));
                      pos++=;
                      psu = de.get(0) + "," + leid + "," + pos;
                      pendingStateUpdates += psu;
                    }
                    //log.log("done with new events " + ci);
                  }
                }
              }
              currentEvents.put(leid, cres);
            } else {
              log.log("cres empty");
            }
      } else {
        log.log("getlastevents cres empty");
      }
     return(null);
   }

   updateSwStateRequest(String did, Int dp, String cname, request) {
     log.log("in updateSwStateRequest " + did + " " + dp);

     //not checking user rn
     Account account = request.context.get("account");
     auto uhex = Hex.encode(account.user);
     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     auto haowns = app.kvdbs.get("HAOWNS"); //haowns - prefix account hex to map of owned device ids

     String confs = hadevs.get(did);
     Map conf = Json:Unmarshaller.unmarshall(confs);

     //dostate eek setsw on e
     Int dpd = dp--;
     String cmds = "dostate " + conf["spass"] + " " + dpd + " getsw e";
     log.log("cmds " + cmds);

     //getting the name
     String kdname = "CasNic" + conf["ondid"];
     String kdaddr = getCashedAddr(kdname);

     //tcpjv edition

     //cmds += "\r\n";

     if (def(kdaddr)) {
       Map mcmd = Maps.from("cb", "updateSwStateCb", "did", did, "dp", dp, "kdaddr", kdaddr, "pwt", 2, "pw", conf["spass"], "cname", cname, "cmds", cmds);

       sendDeviceMcmd(mcmd, 2);

     } else {
      log.log("getsw kdaddr empty");
     }

     return(null);
   }

   updateSwStateCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String did = mcmd["did"];
     Int dp = mcmd["dp"];
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     if (TS.notEmpty(cres)) {
        log.log("got getsw " + cres);
        unless (cres.has("undefined")) {
          String cset = hasw.get(did + "-" + dp);
          if (TS.isEmpty(cset) || cset != cres) {
            hasw.put(did + "-" + dp, cres);
            stDiffed = true;
          }
        }
      }
      return(null);
   }

   updateRgbStateRequest(String did, Int dp, String cname, request) {
     log.log("in updateRgbStateRequest " + did + " " + dp);

     //not checking user rn
     Account account = request.context.get("account");
     auto uhex = Hex.encode(account.user);
     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     auto haowns = app.kvdbs.get("HAOWNS"); //haowns - prefix account hex to map of owned device ids

     String confs = hadevs.get(did);
     Map conf = Json:Unmarshaller.unmarshall(confs);

     //dostate eek setsw on e
     Int dpd = dp--;
     String cmds = "dostate " + conf["spass"] + " " + dpd + " getrgb e";
     log.log("cmds " + cmds);

     //getting the name
     String kdname = "CasNic" + conf["ondid"];
     String kdaddr = getCashedAddr(kdname);

     //tcpjv edition

     //cmds += "\r\n";

     if (def(kdaddr)) {
       Map mcmd = Maps.from("cb", "updateRgbStateCb", "did", did, "dp", dp, "kdaddr", kdaddr, "pwt", 2, "pw", conf["spass"], "cname", cname, "cmds", cmds);

       sendDeviceMcmd(mcmd, 1);

     } else {
      log.log("getlvl kdaddr empty");
     }

     return(null);
   }

   updateRgbStateCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String did = mcmd["did"];
     Int dp = mcmd["dp"];
     auto hargb = app.kvdbs.get("HARGB"); //hargb - device id to rgb
     if (TS.notEmpty(cres)) {
        log.log("got getrgb " + cres);
        unless (cres.has("undefined")) {
          if (cres.has(",")) {
            //log.log("saving rgb");
            hargb.put(did + "-" + dp, cres);
          }
        }
      }
      return(null);
   }

   updateLvlStateRequest(String did, Int dp, String cname, request) {
     log.log("in updateLvlStateRequest " + did + " " + dp);

     //not checking user rn
     Account account = request.context.get("account");
     auto uhex = Hex.encode(account.user);
     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     auto haowns = app.kvdbs.get("HAOWNS"); //haowns - prefix account hex to map of owned device ids

     String confs = hadevs.get(did);
     Map conf = Json:Unmarshaller.unmarshall(confs);

     //dostate eek setsw on e
     Int dpd = dp--;
     String cmds = "dostate " + conf["spass"] + " " + dpd + " getlvl e";
     log.log("cmds " + cmds);

     //getting the name
     String kdname = "CasNic" + conf["ondid"];
     String kdaddr = getCashedAddr(kdname);

     //tcpjv edition

     //cmds += "\r\n";

     if (def(kdaddr)) {
       Map mcmd = Maps.from("cb", "updateLvlStateCb", "did", did, "dp", dp, "kdaddr", kdaddr, "pwt", 2, "pw", conf["spass"], "cname", cname, "cmds", cmds);

       sendDeviceMcmd(mcmd, 1);

     } else {
      log.log("getlvl kdaddr empty");
     }

     return(null);
   }

   updateLvlStateCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String did = mcmd["did"];
     Int dp = mcmd["dp"];
     auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     if (TS.notEmpty(cres)) {
        log.log("got getlvl " + cres);
        unless (cres.has("undefined")) {
          String cset = halv.get(did + "-" + dp);
          Int cresi = Int.new(cres);
          if (mcmd["cname"] == "dim") {
            Int lmax = 255;
          } else {
            lmax = 255;
          }
          if (mcmd["cname"] == "dim") {
            cresi = lmax - cresi;
          }
          if (TS.notEmpty(cset)) {
            Int cseti = Int.new(cset);
            if (cseti != cresi) {
              halv.put(did + "-" + dp, cresi.toString());
              stDiffed = true;
            }
          } else {
            halv.put(did + "-" + dp, cresi.toString());
            stDiffed = true;
          }
        }
      }
      return(null);
   }

   manageStateUpdatesRequest(request) {

     fields {
       String lastError;
     }

     if (TS.notEmpty(lastError)) {
       String lastErrorL = lastError;
       lastError = null;
       throw(Alert.new(lastErrorL));
     }

     //checkfailed
     if (def(cmdsFailMcmd)) {
       Map mcmd = cmdsFailMcmd;
       cmdsFailMcmd = null;
       if (mcmd.has("cb")) {
        return(self.invoke(mcmd["cb"], Lists.from(mcmd, request)));
      }
     }
     //checkdiffed
     if (def(stDiffed) && stDiffed) {
       return(getDevicesRequest(request));
     }

     Map mres = processCmdsRequest(request);
     if (def(mres)) {
       return(mres);
     }

     slots {
       Int msuc;
       Map currentEvents;
       Set lastEventsToGet;
     }
     if (undef(msuc)) {
       msuc = 0;
     } elseIf (msuc > 9999) {
       msuc = 0;
     } else {
       msuc++=;
     }
     if (undef(currentEvents)) {
       currentEvents = Map.new();
     }

     //each dev per 5 sec le, 2 sec psu - 10/hmd 4/hmd, 10 sec 20, 16 for 8, 32 for 16, at 500ms per, at 250
     //1 dev = 10
     //2 dev = 5
     //3 dev = 3
     if (def(howManyDevices) && howManyDevices > 0) {
       Int lefreq = 64 / howManyDevices;
       Int psfreq = 8 / howManyDevices;
       if (lefreq < 4) { lefreq = 4; }
       if (psfreq < 4) { psfreq = 4; }
     } else {
       lefreq = 10;
       psfreq = 4;
     }

     if (msuc % psfreq == 0) {
      //updateStates
      Set toDel = Set.new();
      if (def(pendingStateUpdates)) {
        for (any k in pendingStateUpdates) {
            if (TS.notEmpty(k)) {
              try {
                log.log("doing updateXStateRequest for " + k);
                auto ks = k.split(",");
                if (ks[0] == "sw") {
                  updateSwStateRequest(ks[1], Int.new(ks[2]), ks[0], request);
                } elseIf (ks[0] == "dim") {
                  updateSwStateRequest(ks[1], Int.new(ks[2]), ks[0], request);
                  updateLvlStateRequest(ks[1], Int.new(ks[2]), ks[0], request);
                } elseIf (ks[0] == "pwm") {
                  updateLvlStateRequest(ks[1], Int.new(ks[2]), ks[0], request);
                } elseIf (ks[0] == "rgb") {
                  updateSwStateRequest(ks[1], Int.new(ks[2]), ks[0], request);
                  updateRgbStateRequest(ks[1], Int.new(ks[2]), ks[0], request);
                }
              } catch (any e) {
                log.elog("Error updating device states", e);
              }
              toDel += k;
              break;
            }
          }
        }
        for (k in toDel) {
          pendingStateUpdates.delete(k);
        }
        if (toDel.notEmpty) {
          return(null);
        }
     }

     //check for update event times and add to pendingstateupdates
     if (msuc % lefreq == 0) {
      //lastDevices
      //check against existing values, if present and different, update for the different ones by putting in
      //  involves parsing and checking values
      //pendingStateUpdates
      //log.log("!!! doing lastDevices");
      if (def(lastDevices)) {
        //log.log("lastDevices def");
        if (undef(lastEventsToGet) || lastEventsToGet.isEmpty) {
          lastEventsToGet = Set.new();
          for (auto kvld in lastDevices) {
            lastEventsToGet += kvld.key;
          }
        }
        for (auto leid in lastEventsToGet) {
            getLastEventsRequest(leid, request);
            break;
        }
        if (TS.notEmpty(leid)) {
            lastEventsToGet.delete(leid);
        }
      }
     }
     //log.log("done w manageStateUpdatesRequest");
     return(null);
   }

   initializeDiscoveryListener() {
     ifEmit(jvad) {
     emit(jv) {
       """
         //wifi = (WifiManager) be.BEC_3_2_4_10_UIJvAdWebBrowser.MainActivity.appContext.getSystemService(Context.WIFI_SERVICE);
         //multicastLock = wifi.createMulticastLock("multicastLock");
         //multicastLock.setReferenceCounted(true);

        // Instantiate a new DiscoveryListener
        discoveryListener = new NsdManager.DiscoveryListener() {

          // Called as soon as service discovery begins.
          @Override
          public void onDiscoveryStarted(String regType) {
              System.out.println("Service discovery started");
          }

          @Override
          public void onServiceFound(NsdServiceInfo service) {
              // A service was found! Do something with it.
              System.out.println("Service discovery success" + service);
              String sname = service.getServiceName();
              if (sname != null) {
                System.out.println("onServiceFound " + sname);
                if (!InitializeResolveListener.knownDevices.containsKey(sname)) {
                  if (InitializeResolveListener.resolving.isEmpty()) {
                    InitializeResolveListener.resolving.put(sname, service);
                    nsdManager.resolveService(service, new InitializeResolveListener());
                  } else {
                    InitializeResolveListener.resolving.put(sname, service);
                  }
                }
              }
          }

          @Override
          public void onServiceLost(NsdServiceInfo service) {
              // When the network service is no longer available.
              // Internal bookkeeping code goes here.
              System.out.println("service lost: " + service);
          }

          @Override
          public void onDiscoveryStopped(String serviceType) {
              System.out.println("Discovery stopped: " + serviceType);
          }

          @Override
          public void onStartDiscoveryFailed(String serviceType, int errorCode) {
              System.out.println("Discovery failed: Error code:" + errorCode);
              nsdManager.stopServiceDiscovery(this);
          }

          @Override
          public void onStopDiscoveryFailed(String serviceType, int errorCode) {
              System.out.println("Discovery failed: Error code:" + errorCode);
              nsdManager.stopServiceDiscovery(this);
          }
      };
      """
      }
     }
      pollDiscovery();
   }

   pollDiscovery() {
      System:Thread.new(System:Invocation.new(self, "pollDiscoveryInner", List.new())).start();
   }

   pollDiscoveryInner() {
    ifEmit(jvad) {
      pollDiscoveryInnerJvad();
    }
   }

   pollDiscoveryInnerJvad() {
     while(true) {
     log.log("start runDiscoveryInner");
     startDiscovery();
     log.log("started discovery");
     Time:Sleep.sleepSeconds(20);
     log.log("discovery sleep done");
     stopDiscovery();
     log.log("stopped discovery");
     Time:Sleep.sleepSeconds(10);
     }
   }

   startDiscovery() {
     ifEmit(jvad) {
     emit(jv) {
       """
       try {
        //multicastLock.acquire();
        InitializeResolveListener.resolving = new java.util.Hashtable<String, NsdServiceInfo>();
        nsdManager = (NsdManager) be.BEC_3_2_4_10_UIJvAdWebBrowser.MainActivity.appContext.getSystemService(Context.NSD_SERVICE);
        nsdManager.discoverServices(
        "_http._tcp.", NsdManager.PROTOCOL_DNS_SD, discoveryListener);
       //multicastLock.release();
       } catch (Exception e) { System.out.println("error in startdiscovery"); }
       """
     }
     }
   }

   stopDiscovery() {
     ifEmit(jvad) {
     emit(jv) {
       """
       try {
       //multicastLock.acquire();
       if (nsdManager != null) {
         nsdManager.stopServiceDiscovery(discoveryListener);
       }
       //multicastLock.release();
       } catch (Exception e) { }
       """
     }
     }
   }

   rectlDeviceRequest(String did, request) Map {
     log.log("in rectlDeviceRequest " + did);

     //not checking user rn
     Account account = request.context.get("account");
     auto uhex = Hex.encode(account.user);
     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     auto haowns = app.kvdbs.get("HAOWNS"); //haowns - prefix account hex to map of owned device ids

     String confs = hadevs.get(did);
     Map conf = Json:Unmarshaller.unmarshall(confs);

     //dostate eek setsw on e
     String cmds = "getcontroldef " + conf["spass"] + " e";
     log.log("cmds " + cmds);

     //getting the name
     String kdname = "CasNic" + conf["ondid"];
     String kdaddr = getAddrDis(kdname);

     //tcpjv edition

     //cmds += "\r\n";

     Map mcmd = Maps.from("cb", "rectlDeviceCb", "did", conf["id"], "kdaddr", kdaddr, "pwt", 2, "pw", conf["spass"], "cmds", cmds);
     sendDeviceMcmd(mcmd);

     return(null);
   }

   rectlDeviceCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String did = mcmd["did"];
     if (TS.notEmpty(cres) && cres.has("controldef")) {
        log.log("got controldef " + cres);
        String controlDef = cres;
      }

      if (TS.notEmpty(controlDef)) {
        auto hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
        hactls.put(did, controlDef);
      }

      return(CallBackUI.reloadResponse());
   }

   setDeviceSwRequest(String rhan, String rpos, String rstate, request) Map {
     log.log("in setDeviceSwRequest " + rhan + " " + rpos + " " + rstate);

     //not checking user rn
     Map mcmd = setDeviceSwMcmd(rhan, rpos, rstate);
     if (sendDeviceMcmd(mcmd)!) {
       if (def(request)) {
         return(getDevicesRequest(request));
         //return(CallBackUI.informResponse("Unable to reach device.  Is it powered on and is your phone on the same wifi network as the device?"));
       }
     }
     return(null);
   }

   setDeviceSwMcmd(String did, String iposs, String state) Map {
     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     auto hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef

     Int ipos = Int.new(iposs);

     String ctl = hactls.get(did);
     auto ctll = ctl.split(",");
     String itype = ctll.get(ipos);

     ipos--=;

     String confs = hadevs.get(did);
     Map conf = Json:Unmarshaller.unmarshall(confs);

     //dostate eek setsw on e
     String cmds = "dostate " + conf["spass"] + " " + ipos + " setsw " + state + " e";
     log.log("cmds " + cmds);

     //getting the name
     String kdname = "CasNic" + conf["ondid"];
     String kdaddr = getAddrDis(kdname);

     //tcpjv edition

     //cmds += "\r\n";

     Map mcmd = Maps.from("cb", "setDeviceSwCb", "rhan", did, "rpos", iposs, "rstate", state, "kdaddr", kdaddr, "pwt", 2, "pw", conf["spass"], "itype", itype, "cmds", cmds);
     return(mcmd);

   }

   setDeviceSwCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String rhan = mcmd["rhan"];
     String rpos = mcmd["rpos"];
     String rstate = mcmd["rstate"];
     String itype = mcmd["itype"];
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     if (TS.notEmpty(cres) && cres.has("ok")) {
       hasw.put(rhan + "-" + rpos, rstate);
     } //else {
       if (def(request)) {
        return(getDevicesRequest(request));
       }
     //}
     return(null);
   }

   setDeviceRgbRequest(String rhanpos, String rgb, request) Map {
     log.log("in setDeviceRgbRequest " + rhanpos);

     //not checking user rn
     Map mcmd = setDeviceRgbMcmd(rhanpos, rgb);
     if (sendDeviceMcmd(mcmd)!) {
       if (def(request)) {
         return(getDevicesRequest(request));
         //return(CallBackUI.informResponse("Unable to reach device.  Is it powered on and is your phone on the same wifi network as the device?"));
       }
     }

     return(null);
   }

   setDeviceRgbMcmd(String rhanpos, String rgb) Map {

     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     auto hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef

     auto rhp = rhanpos.split("-");
     String rhan = rhp.get(0);

     Int rpos = Int.new(rhp.get(1));

     String ctl = hactls.get(rhan);
     auto ctll = ctl.split(",");
     String itype = ctll.get(rpos);

     rpos--=;

     String confs = hadevs.get(rhan);
     Map conf = Json:Unmarshaller.unmarshall(confs);

     String cmds = "dostate " + conf["spass"] + " " + rpos.toString() + " setrgb " + rgb + " e";

     log.log("cmds " + cmds);

     //getting the name
     String kdname = "CasNic" + conf["ondid"];
     String kdaddr = getAddrDis(kdname);

     //tcpjv edition

     //cmds += "\r\n";

     Map mcmd = Maps.from("cb", "setDeviceRgbCb", "rhanpos", rhanpos, "rgb", rgb, "kdaddr", kdaddr, "pwt", 2, "pw", conf["spass"], "itype", itype, "cmds", cmds);

     return(mcmd);
   }

   setDeviceRgbCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String rhanpos = mcmd["rhanpos"];
     String rgb = mcmd["rgb"];
     String itype = mcmd["itype"];
     auto hargb = app.kvdbs.get("HARGB"); //hargb - device id to rgb
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     if (TS.notEmpty(cres) && cres.has("ok")) {
       log.log("hargb putting " + rhanpos + " " + rgb);
       hargb.put(rhanpos, rgb);
       hasw.put(rhanpos, "on");
     } else {
       if (def(request)) {
          return(CallBackUI.reloadResponse());
        }
     }
     if (def(request)) {
      return(getDevicesRequest(request));
     }
     return(null);
   }

   setDeviceLvlRequest(String rhanpos, String rstate, request) Map {
     log.log("in setDeviceLvlRequest " + rhanpos + " " + rstate);

     //not checking user rn
     Map mcmd = setDeviceLvlMcmd(rhanpos, rstate);
     if (sendDeviceMcmd(mcmd)!) {
       if (def(request)) {
         return(getDevicesRequest(request));
         //return(CallBackUI.informResponse("Unable to reach device.  Is it powered on and is your phone on the same wifi network as the device?"));
       }
     }
     return(null);
   }

   setDeviceLvlMcmd(String rhanpos, String rstate) Map {

     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     auto hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef

     auto rhp = rhanpos.split("-");
     String rhan = rhp.get(0);

     Int rpos = Int.new(rhp.get(1));

     String ctl = hactls.get(rhan);
     auto ctll = ctl.split(",");
     String itype = ctll.get(rpos);

     rpos--=;

     String confs = hadevs.get(rhan);
     Map conf = Json:Unmarshaller.unmarshall(confs);

     //dostate eek setrlvl 255 e
     if (itype == "dim") {
      String cmds = "dostate " + conf["spass"] + " " + rpos.toString() + " setrlvl " + rstate + " e";
     } else {
       cmds = "dostate " + conf["spass"] + " " + rpos.toString() + " setlvl " + rstate + " e";
     }
     log.log("cmds " + cmds);

     //getting the name
     String kdname = "CasNic" + conf["ondid"];
     String kdaddr = getAddrDis(kdname);

     //tcpjv edition

     //cmds += "\r\n";

     Map mcmd = Maps.from("cb", "setDeviceLvlCb", "rhanpos", rhanpos, "rstate", rstate, "kdaddr", kdaddr, "pwt", 2, "pw", conf["spass"], "itype", itype, "cmds", cmds);

     return(mcmd);
   }

   setDeviceLvlCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String rhanpos = mcmd["rhanpos"];
     String rstate = mcmd["rstate"];
     String itype = mcmd["itype"];
     auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     if (TS.notEmpty(cres) && cres.has("ok")) {
       halv.put(rhanpos, rstate);
       hasw.put(rhanpos, "on");
     } //else {
       if (def(request)) {
        return(getDevicesRequest(request));
       }
     //}
     return(null);
   }

   processCmdsRequest(request) Map {
     slots {
       String cmdsRes;
       Map currCmds;
       Int aptrs; //12 for 3s
     }
      if (undef(cmdsRes) && def(currCmds)) {
      if (undef(aptrs)) {
        aptrs = 1;
      } else {
        aptrs++=;
      }
      if (aptrs > 12) {
        //timed out
        aptrs = 1;
        processCmdsFail();
        return(null);
      }
        ifEmit(jv) {
           String jvadCmdsRes;
           emit(jv) {
             """
             synchronized(bevp_prot) {
               bevl_jvadCmdsRes = bevp_prot.bevp_jvadCmdsRes;
               bevp_prot.bevp_jvadCmdsRes = null;
             }
             """
           }
           if (TS.notEmpty(jvadCmdsRes)) {
             cmdsRes = jvadCmdsRes;
           }
        }
        ifEmit(apwk) {
          String jspw = "getLastCres:";
          emit(js) {
          """
          var jsres = prompt(bevl_jspw.bems_toJsString());
          bevl_jspw = new be_$class/Text:String$().bems_new(jsres);
          """
          }
          if (def(jspw)) {
            Int jic = Int.new();
            Bool gotone = false;
            for (Int ji = 0;ji < jspw.size;ji++=) {
              jspw.getCode(ji, jic);
              if (jic == 0 || jic == 13 || jic == 10) {
                //log.log("found first end at " + ji);
                gotone = true;
                break;
              }
            }
            if (gotone) {
              if (ji == 0) {
              jspw = "";
              } else {
              jspw = jspw.substring(0, ji);
              }
            }
          }
          if (TS.notEmpty(jspw)) {
            //("lastCres " + jspw).print();
            cmdsRes = jspw;
          } else {
            //"no getLastCres".print();
          }
        }
        }

     if (def(cmdsRes) && def(currCmds)) {
       //return currCmds callback
       mcmd = currCmds;
       mcmd["cres"] = cmdsRes;
       cmdsRes = null;
       currCmds = null;
       if (TS.notEmpty(mcmd["kdaddr"])) {
         if (def(addrsFailed) && addrsFailed.has(mcmd["kdaddr"])) {
           addrsFailed.delete(mcmd["kdaddr"]);
         }
       }
       if (mcmd.has("cb")) {
         return(self.invoke(mcmd["cb"], Lists.from(mcmd, request)));
       }
     } elseIf (undef(currCmds)) {
       for (Int i = 0;i < 4;i++=) {
         Container:LinkedList cmdQueue = cmdQueues.get(i);
         if (def(cmdQueue)) {
          Map mcmd = cmdQueue.get(0);
          if (def(mcmd)) {
            currCmds = mcmd;
            cmdsRes = null;
            aptrs = null;
            auto n = cmdQueue.getNode(0);
            n.delete();
            processDeviceMcmd(mcmd);
            break;
          }
        }
       }
     }
     //check for timeout and null / interrupt
     return(null);
   }

   processCmdsFail() {
     Map mcmd = currCmds;
     cmdsRes = null;
     currCmds = null;
     aptrs = null;
     slots {
       Map cmdsFailMcmd;
       Map addrsFailed;
     }
     if (undef(addrsFailed)) {
       addrsFailed = Map.new();
     }
     //?failre / timeout callback?
     String kdaddr = mcmd["kdaddr"];

     ifEmit(jvad) {
         emit(jv) {
          """
            if (bevl_kdaddr != null) {
          String kdn = InitializeResolveListener.knownAddresses.get(bevl_kdaddr.bems_toJvString());
          if (kdn != null) {
            String kda =  InitializeResolveListener.knownDevices.get(kdn);
            if (kda != null) {
              InitializeResolveListener.knownDevices.remove(kdn);
            }
            InitializeResolveListener.knownAddresses.remove(bevl_kdaddr.bems_toJvString());
          }
            }
            """
          }
        }

     if (mcmd.has("cb")) {
       cmdsFailMcmd = mcmd;
     }

     if (TS.notEmpty(kdaddr) && addrsFailed.has(kdaddr)) {
       Int fails = addrsFailed.get(kdaddr);
       if (fails < 3) {
         fails++=;
         return(null);
       } else {
         addrsFailed.delete(kdaddr); //enough fails, will now clear from cache
       }
     } elseIf (TS.notEmpty(kdaddr)) {
       addrsFailed.put(kdaddr, 1);
       return(null);
     }

     if (TS.notEmpty(kdaddr) && def(kac)) {
        String kdn = kac.get(kdaddr);
        if (TS.notEmpty(kdn)) {
          String kda = knc.get(kdn);
          if (TS.notEmpty(kda)) {
            knc.delete(kdn);
            auto haknc = app.kvdbs.get("HAKNC"); //kdname to addr
            haknc.delete(kdn);
          }
          kac.delete(kdaddr);
        }
      }
      startDiscovery();
   }

   sendDeviceMcmd(Map mcmd) Bool {
     return(sendDeviceMcmd(mcmd, 0));
   }

   sendDeviceMcmd(Map mcmd, Int priority) Bool {
      if (def(mcmd) && TS.notEmpty(mcmd["kdaddr"])) {
        Container:LinkedList cmdQueue = cmdQueues.get(priority);
        if (undef(cmdQueue)) {
          cmdQueue = Container:LinkedList.new();
          cmdQueues.put(priority, cmdQueue);
        }
        //log.log("adding to cmdQueue");
        //if (true) { throw(Alert.new("hi")); }
        Bool replaced = false;
        for (auto i = cmdQueue.iterator;i.hasNext;;) {
         Map mc = i.next;
         if (mc["kdaddr"] == mcmd["kdaddr"]) {
           i.current = mc;
           replaced = true;
           log.log("replaced in cmdQueue");
           return(true);
         }
        }
        unless (replaced) {
          cmdQueue += mcmd;
          log.log("added to cmdQueue");
          return(true);
        }
        /*if (cmdQueue.size < 10) {
          cmdQueue += mcmd;
        } else {
          throw(Alert.new("Not handling request, command queue is full.  Is device unavailable or offline?"));
        }*/
      }
      return(false);
   }

   /*
     //tcp edition
     auto client = App:TCPClient.new("CasNic" + conf["id"] + ".local", 6420);
     //auto client = App:TCPClient.new("192.168.1.243", 6420);
     client.open();
     client.write(cmds + "\r\n");
     String tres = client.checkGetPayload(512, "\n");
     client.close();
     if (TS.notEmpty(tres)) {
       log.log("tres " + tres);
     } else {
       log.log("tres empty");
     }
     */

     //web edition
     /*
     cmds = Encode:Url.encode(cmds);
     log.log("cmds enc " + cmds);
     String ucmd = "http://ym" + conf["id"] + ".local/?cmdform=cmdform&cmd=" + cmds;
     log.log("ucmd " + ucmd);
     auto client = Web:Client.new();
     client.url = ucmd;
     String res = client.openInput().readString();
     client.close();
     log.log("res was " + res);
     */

   processDeviceMcmd(Map mcmd) {
     //log.log("in processDeviceMcmd");

     String kdaddr = mcmd["kdaddr"];
     prot.processDeviceMcmd(mcmd);

      return(null);
   }

   checkCxRequest(request) Map {
     String cx;
     //log.log("in checkCxRequest");
     ifEmit(jvad) {
       emit(jv) {
         """
         System.out.println("ma.getLastCx()");
     casnic.control.MainActivity ma = (casnic.control.MainActivity) be.BEC_3_2_4_10_UIJvAdWebBrowser.MainActivity.mainActivity;
     String cx = ma.getLastCx();
     if (cx != null) {
      bevl_cx =  new $class/Text:String$(cx.getBytes("UTF-8"));
     }
        """
          }
    if (TS.notEmpty(cx)) {
       return(CallBackUI.checkCxResponse(cx));
    }

        }
        return(null);
   }

   clearCxRequest(request) {
     ifEmit(platDroid) {
       emit(jv) {
         """
     casnic.control.MainActivity ma = (casnic.control.MainActivity) be.BEC_3_2_4_10_UIJvAdWebBrowser.MainActivity.mainActivity;
     ma.clearLastCx();
        """
          }

        }
   }

   findNewDevicesRequest(request) Map {
       log.log("in find new devices");
       List ssids = List.new();
       String ssid;
       ifEmit(platDroid) {
        emit(jv) {
        """
        casnic.control.MainActivity ma = (casnic.control.MainActivity) be.BEC_3_2_4_10_UIJvAdWebBrowser.MainActivity.mainActivity;
        //String ddir = MainActivity.appContext.getApplicationInfo().dataDir;
        //bevl_toRet = new $class/Text:String$(ddir);

        //get the list, do the thing
        java.util.List<String> ssids = ma.ssids;
        if (ssids != null) {
          ma.ssids = new java.util.ArrayList<String>();
          for (String ssid : ssids) {
            bevl_ssid =  new $class/Text:String$(ssid.getBytes("UTF-8"));
            bevl_ssids.bem_addValue_1(bevl_ssid);
          }
        }

        //scan again
        ma.startScan();
        """
        }
        }
        log.log("find new devices startscan done");
        slots {
          List lastSsids = ssids;
        }
        //return(displayNextDeviceRequest("", request));
        return(null);
   }

   getDevWifisRequest(Int count, Bool starting, request) Map {
     slots {
       Map visnets; //set no marshall
       Bool visnetsDone;
       Int visnetsFails;
       Int visnetsPos;
     }
     if (starting) {
       visnets = Map.new();
       visnetsDone = false;
       visnetsFails = 0;
       visnetsPos = 0;
     }
     Int tries = 200;
     Int wait = 1000;

     Account account = request.context.get("account");
     auto uhex = Hex.encode(account.user);
     auto hawifi = app.kvdbs.get("HAWIFI"); //account hex to wifi network

     String ssid = hawifi.get(uhex + ".ssid.0");
     String sec = hawifi.get(uhex + ".sec.0");
     if (undef(ssid)) { ssid = ""; }
     if (undef(sec)) { sec = ""; }

     if (TS.notEmpty(ssid) && TS.notEmpty(sec) && visnets.has(ssid)) {
       log.log("have wifi setup and found my ssid, moving to allset");
       count.setValue(tries);
       return(CallBackUI.getDevWifisResponse(count, tries, wait));
     }

     if (count >= tries || visnetsFails > 15 || visnetsDone) {
       log.log("doing settle wifi");
       return(CallBackUI.settleWifiResponse(visnets, ssid, sec));
     }

     String cmds = "previsnets " + visnetsPos + " e";
     Map mcmd = Maps.from("cb", "previsnetsCb", "kdaddr", "192.168.4.1", "pwt", 0, "pw", "", "cmds", cmds);
     sendDeviceMcmd(mcmd);
     return(CallBackUI.getDevWifisResponse(count, tries, wait));
   }

   previsnetsCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     if (TS.notEmpty(cres)) {
       log.log("previsnetsCb cres " + cres);
     }
     if (TS.notEmpty(cres) && cres.has("ssids")) {
        if (cres.has(":")) {
           List ssp = cres.split(":");
           for (Int i = 1;i < ssp.size;i++=) {
             String vna = Encode:Hex.decode(ssp[i]);
             log.log("got vna " + vna);
             visnets.put(vna, vna);
             visnetsPos ++=;
           }
        } else {
          //done
          log.log("got no : ssids, previsnetsCb is done");
          visnetsDone = true;
        }
      } else {
        //failed
        log.log("got a fail in previsnetsCb");
        visnetsFails++=;
      }
      return(null);
   }

   getOnWifiRequest(Int count, String devPin, String devSsid, request) Map {
     Int tries = 200;
     Int wait = 1000;
     ifNotEmit(jvad) {
       if (true) {
        return(CallBackUI.getOnWifiResponse(tries, tries, wait));
       }
     }
     unless (devSsid.begins("OCasnic-")) {
       String sec = devPin.substring(8, 16);
     }

     log.log("in getOnWifiRequest " + devPin + " " + devSsid);

     stopDiscovery();
     lastSsids = List.new();
      ifEmit(platDroid) {
      emit(jv) {
        """
        casnic.control.MainActivity ma = (casnic.control.MainActivity) be.BEC_3_2_4_10_UIJvAdWebBrowser.MainActivity.mainActivity;
        ma.ssids = new java.util.ArrayList<String>();
        """
      }
      }

     ifEmit(platDroid) {
        emit(jv) {
          """
          //https://stackoverflow.com/questions/63124728/connect-to-wifi-in-android-q-programmatically

          if (beva_count.bevi_int == 0) {
            gotOnDevNetwork = false;
            String jssid = beva_devSsid.bems_toJvString();
            String jsec = null;
            if (bevl_sec != null) {
              jsec = bevl_sec.bems_toJvString();
            }

            WifiManager wifiManager = (WifiManager) MainActivity.appContext.getSystemService(Context.WIFI_SERVICE);

            WifiNetworkSpecifier wifiNetworkSpecifier = null;

            if (jsec != null) {
              wifiNetworkSpecifier = new WifiNetworkSpecifier.Builder()
                .setSsid( jssid )
                .setWpa2Passphrase(jsec)
                    .build();
            } else {
              wifiNetworkSpecifier = new WifiNetworkSpecifier.Builder()
                .setSsid( jssid )
                    .build();
            }

            NetworkRequest networkRequest = new NetworkRequest.Builder()
                    .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                    .setNetworkSpecifier(wifiNetworkSpecifier)
                    .build();

            final ConnectivityManager connectivityManager = (ConnectivityManager) MainActivity.appContext.getSystemService(Context.CONNECTIVITY_SERVICE);

            lastConnectivityManager = connectivityManager;


            ConnectivityManager.NetworkCallback networkCallback = new ConnectivityManager.NetworkCallback() {

              @Override
              public void onAvailable(Network network) {
                  super.onAvailable(network);
                  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    connectivityManager.bindProcessToNetwork(network);
                  } else {
                    connectivityManager.setProcessDefaultNetwork(network);
                  }
                  System.out.println("onAvailable");
                  gotOnDevNetwork = true;
              }

              @Override
              public void onLosing(Network network, int maxMsToLive) {
                  super.onLosing(network, maxMsToLive);
                  System.out.println("onLosing");
              }

              @Override
              public void onLost(Network network) {
                  super.onLost(network);
                  System.out.println("lost active connection");
              }

              @Override
              public void onUnavailable() {
                  super.onUnavailable();
                  System.out.println("onUnavailable");
              }
            };
            lastNetworkCallback = networkCallback;
            connectivityManager.requestNetwork(networkRequest,networkCallback);
          } else {
             if (gotOnDevNetwork) {
               System.out.println("did gotOnDevNetwork");
               beva_count.bem_setValue_1(bevl_tries);
             } else {
               System.out.println("not gotOnDevNetwork");
             }
          }
          """
        }
     }
     log.log("past wifi setup");
     return(CallBackUI.getOnWifiResponse(count, tries, wait));
     //return(null);
   }

   toAlphaNumSpace(String toCheck) String {
      Int ic = Int.new();
      Int size = toCheck.size;
      String ret = String.new(toCheck.size);
      for (Int j = 0;j < size;j++=;) {
        toCheck.getInt(j, ic);
        if ((ic > 47 && ic < 58) || (ic > 64 && ic < 91) || (ic > 96 && ic < 123) || ic == 32) {
            ret.size = ret.size++;
            ret.setInt(j, ic);
        }
      }
      return(ret);
   }

   resetByPinRequest(Int count, String devPin, request) {

    Int tries = 200;
    Int wait = 1000;
    count++=;

    String cmds = "resetbypin " + devPin + " e";
    Map mcmd = Maps.from("cb", "resetDeviceCb", "kdaddr", "192.168.4.1", "pwt", 0, "pw", "", "cmds", cmds);
    sendDeviceMcmd(mcmd);

   }

   allsetRequest(Int count, String devName, String devType, String devPin, String disDevSsid, String disDevId, String devPass, String devSpass, String devDid, String devSsid, String devSec, request) {
      Int tries = 200;
      Int wait = 1000;
      count++=;
      slots {
        String alStep;
      }

      Account account = request.context.get("account");
      auto uhex = Hex.encode(account.user);

      if (TS.isEmpty(devPass)) {
        auto hapins = app.kvdbs.get("HAPINS"); //hapins - prefix account hex to map of dev passwords
        devPass = hapins.get(uhex + "." + devPin);
        if (TS.isEmpty(devPass)) {
          Int dps = System:Random.getIntMax(4) + 16;
          devPass = System:Random.getString(dps);
          //devPass = "yo";
          hapins.put(uhex + "." + devPin, devPass);
        }
      }

      auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
      auto hapinid = app.kvdbs.get("HAPINID"); //hapinid - uh.pin to id

      String fid = hapinid.get(uhex + "." + devPin);
      if (TS.notEmpty(fid)) {
        String fconfs = hadevs.get(fid);
        if (TS.notEmpty(fconfs)) {
          Map fconf = Json:Unmarshaller.unmarshall(fconfs);
        }
      }

      if (TS.isEmpty(devSpass)) {
        if (def(fconf) && TS.notEmpty(fconf["spass"])) {
          devSpass = fconf["spass"];
        } else {
          dps = System:Random.getIntMax(4) + 16;
          devSpass = System:Random.getString(dps);
          //devSpass = "yaz";
        }
      }

      if (TS.isEmpty(devDid)) {
        if (def(fconf) && TS.notEmpty(fconf["ondid"])) {
          devDid = fconf["ondid"];
        } else {
          devDid = System:Random.getString(16);
          //devDid = "0123456701234567";
        }
      }

      if (def(fconf)) {
        if (TS.notEmpty(fconf["name"])) {
          devName = fconf["name"];
        }
        if (TS.notEmpty(fconf["id"])) {
          disDevId = fconf["id"];
        }
      }

      if (TS.isEmpty(devSsid)) {
        auto hawifi = app.kvdbs.get("HAWIFI"); //account hex to wifi network
        devSsid = Hex.encode(hawifi.get(uhex + ".ssid.0"));
        devSec = Hex.encode(hawifi.get(uhex + ".sec.0"));
      }

      devName = toAlphaNumSpace(devName);

      String cmds;
      Map mcmd;
      if (count > 1) {
        log.log("sending allset cmd");
        if (alStep == "allset") {
          cmds = "allset " + devPin + " " + devPass + " " + devSpass + " " + devDid + " e";
          mcmd = Maps.from("cb", "allsetCb", "disDevId", disDevId, "kdaddr", "192.168.4.1", "pwt", 0, "pw", "", "cmds", cmds);

          Map conf = Map.new();
          conf["type"] = devType;
          conf["id"] = disDevId;
          conf["ondid"] = devDid;
          conf["name"] = devName;
          conf["pass"] = devPass;
          conf["spass"] = devSpass;
          String confs = Json:Marshaller.marshall(conf);
          saveDeviceRequest(conf["id"], confs, request);
          hapinid.put(uhex + "." + devPin, conf["id"]);

          sendDeviceMcmd(mcmd);
        } elseIf (alStep == "getcontroldef") {
          cmds = "getcontroldef " + devSpass + " e";
          mcmd = Maps.from("cb", "allsetCb", "disDevId", disDevId, "kdaddr", "192.168.4.1", "pwt", 0, "pw", "", "cmds", cmds);
          sendDeviceMcmd(mcmd);
        } elseIf (alStep == "setname") {
          cmds = "putconfigs " + devPass + " vhex fc.dname " + Hex.encode(devName) + " e";
          mcmd = Maps.from("cb", "allsetCb", "disDevId", disDevId, "kdaddr", "192.168.4.1", "pwt", 0, "pw", "", "cmds", cmds);
          sendDeviceMcmd(mcmd);
        } elseIf (alStep == "setmqtt") {
          String mqttBroker = app.configManager.get("mqtt.broker");
          String mqttUser = app.configManager.get("mqtt.user");
          String mqttPass = app.configManager.get("mqtt.pass");
          cmds = "putconfigs " + devPass + " vhex fc.mqhost " + Hex.encode(mqttBroker) + " fc.mquser " + Hex.encode(mqttUser) + " fc.mqpass " + Hex.encode(mqttPass) + " e";
          mcmd = Maps.from("cb", "allsetCb", "disDevId", disDevId, "kdaddr", "192.168.4.1", "pwt", 0, "pw", "", "cmds", cmds);
          sendDeviceMcmd(mcmd);
        } elseIf (alStep == "setwifi") {
          cmds = "setwifi " + devPass + " hex " + devSsid + " " + devSec + " e";
          mcmd = Maps.from("cb", "allsetCb", "disDevId", disDevId, "kdaddr", "192.168.4.1", "pwt", 0, "pw", "", "cmds", cmds);
          sendDeviceMcmd(mcmd);
        } elseIf (alStep == "restart") {
          cmds = "restart " + devPass + " e";
          mcmd = Maps.from("cb", "allsetCb", "disDevId", disDevId, "kdaddr", "192.168.4.1", "pwt", 0, "pw", "", "cmds", cmds);
          lastSsids = List.new();
          ifEmit(platDroid) {
          emit(jv) {
            """
            casnic.control.MainActivity ma = (casnic.control.MainActivity) be.BEC_3_2_4_10_UIJvAdWebBrowser.MainActivity.mainActivity;
            ma.ssids = new java.util.ArrayList<String>();
            """
          }
          }
          sendDeviceMcmd(mcmd);
        }
      } else {
        alStep = "allset";
      }
     return(CallBackUI.allsetResponse(count, tries, wait, devPass, devSpass, devDid, devSsid, devSec, disDevId, devName));
    }

   //have timeout call the callback
   //get rid of the back and forth with ui just do it with callbacks
   allsetCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String disDevId = mcmd["disDevId"];
     if (alStep == "allset") {
       if (TS.notEmpty(cres) && cres.has("allset done")) {
          log.log("allset expected result");
          alStep = "getcontroldef";
       } elseIf (TS.notEmpty(cres) && cres.has("pass is incorrect")) {
          throw(Alert.new("Device is already configured, reset before setting up again."));
       }
     } elseIf (alStep == "getcontroldef") {
       if (TS.notEmpty(cres) && cres.has("controldef")) {
         log.log("got controldef " + cres);
         String controlDef = cres;
         auto hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
         hactls.put(disDevId, controlDef);
         alStep = "setname";
       }
     } elseIf (alStep == "setname") {
       if (TS.notEmpty(cres) && cres.has("configs set")) {
         log.log("setname worked");

         //String mqttBroker = app.configManager.get("mqtt.broker");
         //String mqttUser = app.configManager.get("mqtt.user");
         //String mqttPass = app.configManager.get("mqtt.pass");

         //if (TS.notEmpty(mqttBroker) && TS.notEmpty(mqttUser) && TS.notEmpty(mqttPass)) {
         //  alStep = "setmqtt";
         //} else {
          alStep = "setwifi";
         //}

       }
     //} elseIf (alStep == "setmqtt") {
      // if (TS.notEmpty(cres) && cres.has("configs set")) {
      //   log.log("setmqtt worked");
     //    alStep = "setwifi";
     //  }
     } elseIf (alStep == "setwifi") {
       if (TS.notEmpty(cres) && cres.has("Wifi Setup Written")) {
         log.log("wifi setup worked");
         alStep = "restart";
       }
     } elseIf (alStep == "restart") {
       if (TS.notEmpty(cres) && cres.has("Will restart")) {
          log.log("restart worked");
          ifEmit(platDroid) {
              emit(jv) {
                """
              if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                lastConnectivityManager.bindProcessToNetwork(null);
              } else {
                lastConnectivityManager.setProcessDefaultNetwork(null);
              }
              lastConnectivityManager.unregisterNetworkCallback(lastNetworkCallback);
                """
              }
          }
          return(CallBackUI.reloadResponse());
        }
     }
     return(null);
   }

   displayNextDeviceRequest(String ssidn, request) Map {
     ifEmit(apwk) {
       if (true) { return(displayNextDeviceCmdRequest(ssidn, request)); }
     }
     ifEmit(jvad) {
       if (true) { return(displayNextDeviceSsidRequest(ssidn, request)); }
     }
     ifEmit(wajv) {
       if (true) { return(displayNextDeviceCmdRequest(ssidn, request)); }
     }
     return(null);
   }

   displayNextDeviceCmdRequest(String ssidn, request) Map {
     //log.log("in displayNextDeviceCmdRequest");
    String cmds = "getapssid e";
    Map mcmd = Maps.from("cb", "displayNextDeviceCmdCb", "kdaddr", "192.168.4.1", "pwt", 0, "pw", "", "cmds", cmds);
    sendDeviceMcmd(mcmd);
    return(null);
   }

   displayNextDeviceCmdCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     if (TS.notEmpty(cres)) {
      log.log("got controldef " + cres);
      String controlDef = cres;
     }
     if (TS.notEmpty(controlDef)) {
      String ssid = controlDef;
      if (ssid.begins("ICasnic-") || ssid.begins("OCasnic-") || ssid.begins("UCasnic-")) {
        auto pts = ssid.split("-");
        if (pts.size == 4) {
          String type = pts[2];
          String pina = pts[1];
          log.log("found dev " + type + " " + pina);
          if (TS.notEmpty(pina)) {
            String pino = pina + pina;
          }
          //disDevType disDevPin
          if (TS.notEmpty(type) && TS.notEmpty(pino)) {
            return(CallBackUI.displayNextDeviceResponse(ftypeForType(type), type, pino, ssid));
            //return(CallBackUI.setElementsValuesResponse(Maps.from("disDevType", type, "disDevPin", pino, "disDevSsid", ssid)));
          }
        }
      }
    }
     return(null);
   }

   displayNextDeviceSsidRequest(String ssidn, request) Map {
     List ssids = lastSsids;
     Bool retNext = false;
     if (undef(ssids)) {
       log.log("ssids undefined");
       return(null);
     }
     for (String ssid in ssids.sort()) {
          if (TS.notEmpty(ssid)) {
            log.log("in fndr be ssid " + ssid);
            if (ssid.begins("ICasnic-") || ssid.begins("OCasnic-") || ssid.begins("UCasnic-")) {
              auto pts = ssid.split("-");
              if (pts.size == 4) {
                String type = pts[2];
                String pina = pts[1];
                log.log("found dev " + type + " " + pina);
                if (TS.notEmpty(pina)) {
                  String pino = pina + pina;
                }
                if (TS.isEmpty(ssidn) || retNext) {
                  //disDevType disDevPin
                  if (TS.notEmpty(type) && TS.notEmpty(pino)) {
                    return(CallBackUI.displayNextDeviceResponse(ftypeForType(type), type, pino, ssid));
                    //return(CallBackUI.setElementsValuesResponse(Maps.from("disDevType", type, "disDevPin", pino, "disDevSsid", ssid)));
                  }
                }
                if (ssidn == ssid) {
                  retNext = true;
                }
              }
            }
          }
        }
        return(CallBackUI.displayNextDeviceResponse("", "", "", ""));
        //return(CallBackUI.setElementsValuesResponse(Maps.from("disDevType", "", "disDevPin", "")));
   }

   ftypeForType(String type) String {
     if (TS.notEmpty(type)) {
      if (type.begins("WN")) {
        if (type == "WNN") {
          ftype = "NodeMCU";
        } elseIf (type == "WNAP2") {
          ftype = "Athom Plug V2";
        } elseIf (type == "WNABLB01") {
          ftype = "Athom LB01 7w Bulb";
        }
      }
     }
     if (TS.isEmpty(ftype)) {
       String ftype = type;
     }
     return(ftype);
   }
   
   okForPageToken(request) Bool {
     if (request.embedded) {
       return(true);
     }
     String ref = request.getInputHeader("referer");
     if (TS.isEmpty(ref)) {
      return(false);
     }
     Int pos = 0;
     for (Int i = 0;i < 3;i++=) {
       pos = ref.find("/", pos + 1);
     }
     ref = ref.substring(pos);
     log.log("okForPageToken " + ref);
     if (ref.has("?")) {
      ref = ref.substring(0, ref.find("?"));
     }
     log.log("okForPageToken second " + ref);
     String pref = "/App/" + self.name;
     if (ref == pref + "/BAM.html" || ref == pref + "/BAM.html") {
      log.log("ok for page token");
      return(true);
     }
     log.log("not ok");
     return(false);
   }
   
   runCmd(String cmd) {
	   System:Command.new(cmd).open().output.readDiscardClose();
   }

   iosAppStart() {
     "in iosappstart".print();
     App:AppStart.start(Parameters.new(Lists.from("--plugin", "BA:EDevPlugin", "--plugin", "BA:BamPlugin", "--plugin", "App:ConfigPlugin", "--appPlugin", "CasCon", "--appType", "browser", "--appName", "CasCon", "--sdbClass", "Db:MemFileStoreKeyValue", "--appKvPoolSize", "1")));
   }
   
}

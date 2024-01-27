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
use Math:Float;
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
use Time:Interval;

use App:Mqtt;


use BAM:BamAuthPlugin;

class BamAuthPlugin(App:AuthPlugin) {

  start() {
    super.start();
    if (def(app.pluginsByName.get("CasCon"))) {
      prot = app.pluginsByName.get("CasCon").prot;
      log.log("GOT PROT");
    }
    slots {
      CasProt prot;
    }
  }

  loginRequest(Map arg, request) {
    //Account a = self.accountManager.getAccount(arg["accountName"]);
    //a.checkPass(arg["accountPass"])
    //check pass against ha if present
    //set pass if it doesn't checkPass (it's changed), or if account missing
    Bool authOk = false;
    if (TS.notEmpty(prot.supTok) && TS.notEmpty(prot.supUrl) && prot.doSupAuth) {
        log.log("GOT supTok " + prot.supTok);
        Web:Client client = Web:Client.new();
        client.url = prot.supUrl + "/auth";
        client.outputContentType = "application/json";

        client.outputHeaders.put("X-Supervisor-Token", prot.supTok);
        //client.outputHeaders.put("X-Supervisor-Token", "blah");

        client.verb = "POST";
        String co = Json:Marshaller.marshall(Maps.from("username", arg["accountName"], "password", arg["accountPass"]));
        log.log("co " + co);
        client.contentsOut = co;
        try {
          String res = client.openInput().readString();
          log.log("res from auth call" + res);
          Map resm = Json:Unmarshaller.unmarshall(res);
          if (TS.notEmpty(resm["result"]) && resm["result"] == "ok") {
            authOk = true;
          }
        } catch (any e) {
          log.log("auth call excepted and failed");
        }
        if (authOk) {
          Account a = self.accountManager.getAccount(arg["accountName"]);
          if (def(a)) {
            log.log("got account");
            if (a.checkPass(arg["accountPass"])) {
              log.log("pass good");
            } else {
              log.log("pass needs update");
              a.pass = arg["accountPass"];
              self.accountManager.putAccount(a);
            }
          } else {
            log.log("no account yet");
            a = Account.new();
            a.user = arg["accountName"];
            a.pass = arg["accountPass"];
            a.perms.put("admin");
            request.context.put("account", a);
            self.accountManager.putAccount(a);
          }
        }
    } else {
      authOk = true;
    }
    if (authOk) {
      log.log("authOk proceeding");
      return(super.loginRequest(arg, request));
    }
    log.log("not authOk stopping");
    badLogin(request);
    return(logoutRequest(arg, request));
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
    public static java.util.Hashtable<String, NsdServiceInfo> resolving = new java.util.Hashtable<String, NsdServiceInfo>();
    public static volatile NsdServiceInfo nowResolving = null;

    public static void maybeResolve() {
       if (nowResolving == null && !resolving.isEmpty()) {
        try {
          java.util.Collection<NsdServiceInfo> rv = resolving.values();
          int rnd = new java.util.Random().nextInt(rv.size());
          java.util.Iterator<NsdServiceInfo> rvi = rv.iterator();
          NsdServiceInfo rs = null;
          for (int i = 0;i <= rnd;i++) {
            rs = rvi.next();
          }
          nowResolving = rs;
          nsdManager.resolveService(rs, new InitializeResolveListener());
        } catch (ClassCastException cce) {
          System.out.println("class cast exception in resolving");
          resolving.clear();
        }
      }
    }

    @Override
    public void onResolveFailed(NsdServiceInfo serviceInfo, int errorCode) {
      System.out.println("Resolve failed" + errorCode);
      String sname = serviceInfo.getServiceName();
      resolving.remove(sname);
      nowResolving = null;
      maybeResolve();
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
      resolving.remove(sname);
      nowResolving = null;
      maybeResolve();
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
          OLocker discoverNow = OLocker.new(true);
        }
        ifEmit(wajv) {
          fields {
            Mqtt mqtt;
            Bool backgroundPulseOnIdle = true;
            Bool backgroundPulse = backgroundPulseOnIdle;
          }
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

      ifEmit(wajv) {
        System:Thread.new(System:Invocation.new(self, "keepMqttUp", List.new())).start();
        //if (backgroundPulse) {
          System:Thread.new(System:Invocation.new(self, "runPulseDevices", List.new())).start();
        //}
        if (prot.doSupUpdate) {
          System:Thread.new(System:Invocation.new(self, "haDoUp", List.new())).start();
        }

      }

      initializeDiscoveryListener();

      ifEmit(wajv) {
        checkStartMqtt();
      }

    }

    haDoUp() {
      ifEmit(wajv) {
        //Int cnt = 0;
        while (true) {
          try {
            haDoUpInner();
          } catch (any e) {
            log.elog("except in haDoUp", e);
          }
          //if (cnt < 6) {
          //  Time:Sleep.sleepSeconds(20);
          //} else {
          //  cnt = 60;
          //  Time:Sleep.sleepSeconds(60);
          //}
          Time:Sleep.sleepSeconds(43200);// every 12 hrs
        }
      }
    }

    haDoUpInner() {
      log.log("checking for upver");
      Bool docu = false;

      if (TS.notEmpty(prot.supTok) && TS.notEmpty(prot.supUrl) && prot.doSupUpdate) {
        log.log("checking addonvers");
        Web:Client client = Web:Client.new();

        //client.url = prot.supUrl + "/addons";
        //client.outputContentType = "application/json";
        //client.outputHeaders.put("Authorization", "Bearer " + prot.supTok);

        client.url = "https://github.com/bitsii/beEmb/releases/download/Genned.30/CasConHaUp.json";
        client.verb = "GET";
        String res = client.openInput().readString();

        if (TS.notEmpty(res)) {
          log.log("res is " + res);
          Map resm = Json:Unmarshaller.unmarshall(res);
          Map data = resm.get("data");
          if (def(data)) {
            log.log("got data");
            List ads = data.get("addons");
            if (def(ads)) {
              log.log("got ads");
              for (Map ad in ads) {
                if (TS.notEmpty(ad["slug"]) && ad["slug"].has("casnic")) {
                  log.log("got casnic ad " + ad["slug"]);
                  String ver = ad["version"];
                  String verlat = ad["version_latest"];
                  if (TS.notEmpty(ver) && TS.notEmpty(verlat)) {
                    log.log("ver " + ver);
                    log.log("verlat " + verlat);
                    String verKnown = app.configManager.get("supUpdate.verk");
                    if (TS.isEmpty(verKnown)) {
                      log.log("docu, no verKnown");
                      docu = true;
                    } elseIf (verKnown != ver) {
                      log.log("docu, dif verKnown");
                      docu = true;
                    } elseIf (verKnown != verlat) {
                      log.log("docu, diff verlat");
                      docu = true;
                    }
                    app.configManager.put("supUpdate.verk", ver);
                    //docu = true;//just for dev
                  }
                }
              }
            }
          }
        } else {
          log.log("no res from casconhaup");
        }
      }

      if (docu) {
        log.log("docu true");
        Path sp = app.paths.appPath.copy();
        sp = sp.parent;
        sp.addStep("CasUpdate.sh");
        unless (sp.file.exists) {
          log.log("making casup");
          IO:Writer sw = sp.file.writer.open();
          sw.write("#!/bin/bash\n");
          //sw.write("rm -rf App/CasConOld\n");
          //sw.write("mv App/CasCon App/CasConOld\n");
	        sw.write("curl -L -s \"https://github.com/bitsii/beEmb/releases/download/Genned.30/CasCon." + verlat + ".tar.gz\" | tar -C /data/apprun/App -zxpf -\n");
          sw.write("\n");
          sw.close();
        } else {
          log.log("casup already exists");
        }
      }
    }

    keepMqttUp() {
      ifEmit(wajv) {
        while (true) {
          Time:Sleep.sleepSeconds(15);
          try {
            checkStartMqtt();
          } catch (any e) {
            log.elog("except in keepMqttUp", e);
          }
        }
      }
    }

    checkStartMqtt() {
      ifEmit(wajv) {
        if (undef(mqtt) || mqtt.isOpen!) {
          if (def(mqtt)) {
            log.log("closing mqtt");
            auto mqtt2 = mqtt;
            mqtt = null;
            mqtt2.close();
          }
          String mqttBroker = app.configManager.get("mqtt.broker");
          String mqttUser = app.configManager.get("mqtt.user");
          String mqttPass = app.configManager.get("mqtt.pass");
          if (TS.isEmpty(mqttBroker) || TS.isEmpty(mqttUser) || TS.isEmpty(mqttPass)) {
            if (TS.notEmpty(prot.supTok) && TS.notEmpty(prot.supUrl) && prot.doSupAuth) {
              log.log("GOT supTok " + prot.supTok);
              Web:Client client = Web:Client.new();
              client.url = prot.supUrl + "/services/mqtt";
              client.outputContentType = "application/json";

              client.outputHeaders.put("Authorization", "Bearer " + prot.supTok);

              client.verb = "GET";
              String res = client.openInput().readString();
              if (TS.notEmpty(res)) {
                log.log("mqtt ha get conn res " + res);
                Map resm = Json:Unmarshaller.unmarshall(res);
                Map data = resm.get("data");
                if (def(data)) {
                  log.log("got data");
                  mqttUser = data["username"];
                  mqttPass = data["password"];
                  mqttBroker = "tcp://" + data["host"] + ":" + data["port"];
                }
              } else {
                log.log("mqtt ha get conn res empty");
              }
            }
          }
          if (TS.notEmpty(mqttBroker) && TS.notEmpty(mqttUser) && TS.notEmpty(mqttPass)) {
            initializeMqtt(mqttBroker, mqttUser, mqttPass);
          }
        } else {
          mqtt.publish("casnic/ktlo", "yo");
        }
      }
    }

    initializeMqtt(String mqttBroker, String mqttUser, String mqttPass) {
      ifEmit(wajv) {
       log.log("initializing mqtt");
       mqtt = Mqtt.new();
       mqtt.broker = mqttBroker;
       mqtt.user = mqttUser;
       mqtt.pass = mqttPass;
       mqtt.messageHandler = self;
       mqtt.open();
       if (mqtt.isOpen) {
        log.log("mqtt opened");
        mqtt.subscribe("homeassistant/status");
        mqtt.subscribe("casnic/ktlo");
        setupMqttDevices();
       } else {
         if (TS.notEmpty(mqtt.lastError)) {
           lastError = "Mqtt Error: " + mqtt.lastError;
         }
        mqtt.close();
        mqtt = null;
       }
       //mqtt.subscribe("test");
       //mqtt.publish("test", "hi from casnic");
      }
    }

    setupMqttDevices() {
      ifEmit(wajv) {
        auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
        auto hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
        auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
        auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
        auto hargb = app.kvdbs.get("HARGB"); //hargb - device id to rgb
        Map devices = Map.new();
        Map ctls = Map.new();
        Map topubs = Map.new();
        for (any kv in hadevs.getMap()) {
          String did = kv.key;
          String confs = kv.value;
          Map conf = Json:Unmarshaller.unmarshall(confs);
          devices.put(did, confs);
          String ctl = hactls.get(did);
          if (TS.notEmpty(ctl)) {
            ctls.put(did, ctl);
            auto ctll = ctl.split(",");
            log.log("got ctl " + ctl);
            for (Int i = 1;i < ctll.size;i++=) {
              String itype = ctll.get(i);
              log.log("got ctled itype " + itype + " pos " + i);
              if (itype == "sw") {
                //mosquitto_pub -r -h 127.0.0.1 -p 1883 -t "homeassistant/switch/irrigation/config" -m '{"name": "garden", "command_topic": "homeassistant/switch/irrigation/set", "state_topic": "homeassistant/switch/irrigation/state"}'
                String tpp = "homeassistant/switch/" + did + "-" + i;
                Map cf = Maps.from("name", conf["name"], "command_topic", tpp + "/set", "state_topic", tpp + "/state", "unique_id", did + "-" + i);
                String cfs = Json:Marshaller.marshall(cf);
                log.log("will set discovery tpp " + tpp + " cfs " + cfs);
                mqtt.subscribe(tpp + "/set");
                mqtt.publish(tpp + "/config", cfs);
                String st = hasw.get(did + "-" + i);
                if (TS.notEmpty(st)) {
                  topubs.put(tpp + "/state", st.upper());
                } else {
                  topubs.put(tpp + "/state", "OFF");
                }
              } elseIf(itype == "dim" || itype == "gdim") {
                tpp = "homeassistant/light/" + did + "-" + i;
                cf = Maps.from("name", conf["name"], "command_topic", tpp + "/set", "state_topic", tpp + "/state", "unique_id", did + "-" + i, "schema", "json", "brightness", true, "brightness_scale", 255);
                //optimistic, false
                cfs = Json:Marshaller.marshall(cf);
                log.log("will set discovery tpp " + tpp + " cfs " + cfs);
                mqtt.subscribe(tpp + "/set");
                mqtt.publish(tpp + "/config", cfs);
                st = hasw.get(did + "-" + i);
                Map dps = Map.new();
                if (TS.notEmpty(st)) {
                  dps.put("state", st.upper());
                } else {
                  dps.put("state", "OFF");
                }
                String lv = halv.get(did + "-" + i);
                if (TS.notEmpty(lv)) {
                  //log.log("got lv " + lv);
                  Int gamd = Int.new(lv);
                  dps.put("brightness", gamd);
                }
                topubs.put(tpp + "/state", Json:Marshaller.marshall(dps));
              } elseIf (itype == "rgb" || itype == "rgbgdim") {
                tpp = "homeassistant/light/" + did + "-" + i;
                cf = Maps.from("name", conf["name"], "command_topic", tpp + "/set", "state_topic", tpp + "/state", "unique_id", did + "-" + i, "schema", "json", "brightness", false, "rgb", true, "color_temp", false);
                //optimistic, false
                if (itype == "rgbgdim") {
                  cf.put("brightness", true);
                  cf.put("brightness_scale", 255);
                }
                cfs = Json:Marshaller.marshall(cf);
                log.log("will set discovery tpp " + tpp + " cfs " + cfs);
                mqtt.subscribe(tpp + "/set");
                mqtt.publish(tpp + "/config", cfs);
                st = hasw.get(did + "-" + i);
                dps = Map.new();
                if (TS.notEmpty(st)) {
                  dps.put("state", st.upper());
                } else {
                  dps.put("state", "OFF");
                }
                if (itype == "rgbgdim") {
                  lv = halv.get(did + "-" + i);
                  if (TS.notEmpty(lv)) {
                    dps.put("brightness", Int.new(lv));
                  }
                }
                String rgb = hargb.get(did + "-" + i);
                if (TS.isEmpty(rgb)) {
                  rgb = "255,255,255";
                }
                auto rgbl = rgb.split(",");
                Map rgbm = Maps.from("r", Int.new(rgbl[0]), "g", Int.new(rgbl[1]), "b", Int.new(rgbl[2]));
                dps.put("color", rgbm);
                topubs.put(tpp + "/state", Json:Marshaller.marshall(dps));
              }
            }
          }
        }
        Time:Sleep.sleepMilliseconds(200);
        for (any pkv in topubs) {
          mqtt.publish(pkv.key, pkv.value);
        }
      }
    }

    handleMessage(String topic, String payload) {
      ifEmit(wajv) {
        log.log("in bam handlemessage for " + topic + " " + payload);
        if (TS.notEmpty(topic) && TS.notEmpty(payload)) {
          if (topic == "homeassistant/status" && payload == "online") {
            log.log("ha startedup");
            mqtt.close();
            mqtt = null;
            checkStartMqtt();
          } elseIf (topic.begins("homeassistant/switch/") && topic.ends("/set")) {
            log.log("ha switched");
            auto ll = topic.split("/");
            String didpos = ll[2];
            log.log("ha got didpos " + didpos);
            auto dp = didpos.split("-");
            Map mcmd = setDeviceSwMcmd(dp[0], dp[1], payload.lower());
            mcmd["runSync"] = true;
            processDeviceMcmd(mcmd);
            if (mcmd.has("cb")) {
              self.invoke(mcmd["cb"], Lists.from(mcmd, null));
            }
            stDiffed = true;
          } elseIf (topic.begins("homeassistant/light/") && topic.ends("/set")) {
            log.log("ha light switched");
            ll = topic.split("/");
            didpos = ll[2];
            log.log("ha got didpos " + didpos);
            dp = didpos.split("-");
            Map incmd = Json:Unmarshaller.unmarshall(payload);
            //if has brightness, do brightness
            //else state
            if (incmd.has("brightness")) {
              mcmd = setDeviceLvlMcmd(dp[0] + "-" + dp[1], incmd.get("brightness").toString());
              mcmd["runSync"] = true;
              processDeviceMcmd(mcmd);
              if (mcmd.has("cb")) {
                self.invoke(mcmd["cb"], Lists.from(mcmd, null));
              }
            } elseIf (incmd.has("color")) {
              Map rgb = incmd.get("color");
              String rgbs = "" + rgb["r"] + "," + rgb["g"] + "," + rgb["b"];
              mcmd = setDeviceRgbMcmd(dp[0] + "-" + dp[1], rgbs);
              mcmd["runSync"] = true;
              processDeviceMcmd(mcmd);
              if (mcmd.has("cb")) {
                self.invoke(mcmd["cb"], Lists.from(mcmd, null));
              }
            } elseIf (incmd.has("state")) {
              mcmd = setDeviceSwMcmd(dp[0], dp[1], incmd.get("state").lower());
              mcmd["runSync"] = true;
              processDeviceMcmd(mcmd);
              if (mcmd.has("cb")) {
                self.invoke(mcmd["cb"], Lists.from(mcmd, null));
              }
            }
            stDiffed = true;
          }
        }
      }
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

    showDeviceConfigRequest(String did, request) Map {
      log.log("in showDeviceConfigRequest ");

      auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
      String confs = hadevs.get(did);
      return(CallBackUI.showDeviceConfigResponse(addFtype(confs), getCachedIp(confs)));

    }
    
    showNextDeviceConfigRequest(String lastDid, request) Map {
      log.log("in showNextDeviceConfigRequest ");
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
     if (TS.notEmpty(kdaddr)) {
       log.log("got kdaddr " + kdaddr + " for " + kdname);
    } else {
      log.log("got no kdaddr for " + kdname);
      discoverNow.o = true;
    }
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
     ifEmit(wajv) {
      if (def(mqtt)) {
        mqtt.close();
        mqtt = null;
      }
      checkStartMqtt();
     }
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
    pdevices = null;

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

     Map mcmd = Maps.from("cb", "resetDeviceCb", "did", did, "kdaddr", kdaddr, "kdname", kdname, "pwt", 1, "pw", conf["pass"], "cmds", cmds);

     sendDeviceMcmd(mcmd, 1);

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

     Map mcmd = Maps.from("cb", "sendDeviceCommandCb", "kdaddr", kdaddr, "kdname", kdname, "pwt", pt, "pw", tp, "cmds", cmds);

     sendDeviceMcmd(mcmd, 1);

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
     pdevices = null;
     
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
     ifEmit(wajv) {
      if (def(mqtt)) {
        mqtt.close();
        mqtt = null;
      }
      checkStartMqtt();
     }
     return(CallBackUI.reloadResponse());
   }
   
   getDevicesRequest(request) Map {
     log.log("in getDevicesRequest");
     Account account = request.context.get("account");
     auto uhex = Hex.encode(account.user);
     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     auto hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     auto hargb = app.kvdbs.get("HARGB"); //hargb - device id to rgb
     auto hacw = app.kvdbs.get("HACW");
     auto haowns = app.kvdbs.get("HAOWNS"); //haowns - prefix account hex to map of owned device ids
     Map devices = Map.new();
     Map ctls = Map.new();
     Map states = Map.new();
     Map levels = Map.new();
     Map rgbs = Map.new();
     Map cws = Map.new();
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
            Int gamd = Int.new(lv);
            lv = gamd.toString();
            levels.put(did + "-" + i, lv);
          }
          log.log("getting rgb for " + did + "-" + i);
          String rgb = hargb.get(did + "-" + i);
          if (TS.notEmpty(rgb)) {
            log.log("got rgb " + rgb);
            rgbs.put(did + "-" + i, rgb);
          }
          log.log("getting cw for " + did + "-" + i);
          String cw = hacw.get(did + "-" + i);
          if (TS.notEmpty(cw)) {
            log.log("got cw " + cw);
            cws.put(did + "-" + i, cw);
          }
        }
       }
     }
     if (def(nextInform)) {
       Int nsecs = nextInform.seconds;
     } else {
       nsecs = 0;
     }
     return(CallBackUI.getDevicesResponse(devices, ctls, states, levels, rgbs, cws, nsecs));
   }

   updateSpec(String did) {
     log.log("in updateSpec " + did);

     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config

     String confs = hadevs.get(did);
     Map conf = Json:Unmarshaller.unmarshall(confs);

     String cmds = "doswspec " + conf["spass"] + " e";
     log.log("cmds " + cmds);

     //getting the name
     String kdname = "CasNic" + conf["ondid"];
     String kdaddr = getCashedAddr(kdname);

     if (def(kdaddr)) {
       Map mcmd = Maps.from("cb", "updateSpecCb", "did", did, "kdaddr", kdaddr, "kdname", kdname, "pwt", 2, "pw", conf["spass"], "cmds", cmds);

       ifEmit(wajv) {
        if (backgroundPulse) {
          mcmd["runSync"] = true;
          processDeviceMcmd(mcmd);
          if (mcmd.has("cb")) {
            self.invoke(mcmd["cb"], Lists.from(mcmd, null));
          }
        } else {
          sendDeviceMcmd(mcmd, 2);
        }
       }
       ifNotEmit(wajv) {
        sendDeviceMcmd(mcmd, 2);
       }

     } else {
      log.log("updateSpec kdaddr empty");
     }

     return(null);
   }

   updateSpecCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String did = mcmd["did"];
     auto haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
     if (TS.notEmpty(cres)) {
        log.log("got dospec " + cres);
        if (cres.begins("controldef")) {
          log.log("pre swspec");
          haspecs.put(did, "1,p2.gsh.4");
        } elseIf (cres.has("p2.")) {
          log.log("got swspec");
          haspecs.put(did, cres);
        } else {
          log.log("swspec got nonsense, doing default");
          haspecs.put(did, "1,p2.gsh.4");
        }
      }
      return(null);
   }

   getLastEvents(String confs) {
     log.log("in getLastEvents");

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

     if (def(kdaddr)) {
       Map mcmd = Maps.from("cb", "getLastEventsCb", "did", conf["id"], "kdaddr", kdaddr, "kdname", kdname, "pwt", 0, "pw", "", "cmds", cmds);

       ifEmit(wajv) {
         if (backgroundPulse) {
          mcmd["runSync"] = true;
          processDeviceMcmd(mcmd);
          if (mcmd.has("cb")) {
            self.invoke(mcmd["cb"], Lists.from(mcmd, null));
          }
         } else {
           sendDeviceMcmd(mcmd, 5);
         }
       }
       ifNotEmit(wajv) {
        sendDeviceMcmd(mcmd, 5);
       }

     } else {
      log.log("getlastevents kdaddr empty");
      if (def(currentEvents)) {
        currentEvents.delete(conf["id"]);
      }
     }

     return(null);
   }

   getLastEventsCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String leid = mcmd["did"];
     if (TS.notEmpty(cres)) {
        log.log("getlastevents cres |" + cres + "|");
        String ores = currentEvents.get(leid);
        if (TS.notEmpty(ores)) {
          if (cres != ores) {
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
            }
          }
        }
        currentEvents.put(leid, cres);
        auto haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
        //haspecs.delete(leid);
        unless (haspecs.has(leid)) {
          pendingSpecs.put(leid);
          //log.log("no have haspec");
        } //else {
          //log.log("have haspec " + haspecs.get(leid));
        //}
      } else {
        log.log("getlastevents cres empty");
      }
     return(null);
   }

   updateSwState(String did, Int dp, String cname) {
     log.log("in updateSwState " + did + " " + dp);

     auto hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
     String ctl = hactls.get(did);
     auto ctll = ctl.split(",");
     String itype = ctll.get(dp);

     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config

     String confs = hadevs.get(did);
     Map conf = Json:Unmarshaller.unmarshall(confs);

     //dostate eek setsw on e
     Int dpd = dp--;

     //getting the name
     String kdname = "CasNic" + conf["ondid"];
     String kdaddr = getCashedAddr(kdname);

     //tcpjv edition

     //cmds += "\r\n";

     if (def(kdaddr)) {

       auto haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
       String sws = haspecs.get(did);
       if (TS.notEmpty(sws) && sws.has("q,")) {
         cmds = "dostate Q " + dpd + " getsw e";
         log.log("cmds " + cmds);
         mcmd = Maps.from("cb", "updateSwStateCb", "did", did, "dp", dp, "kdaddr", kdaddr, "kdname", kdname, "pwt", 0, "pw", "", "itype", itype, "cname", cname, "cmds", cmds);
       } else {
         String cmds = "dostate " + conf["spass"] + " " + dpd + " getsw e";
         log.log("cmds " + cmds);
         Map mcmd = Maps.from("cb", "updateSwStateCb", "did", did, "dp", dp, "kdaddr", kdaddr, "kdname", kdname, "pwt", 2, "pw", conf["spass"], "itype", itype, "cname", cname, "cmds", cmds);
       }

       ifEmit(wajv) {
         if (backgroundPulse) {
          mcmd["runSync"] = true;
          processDeviceMcmd(mcmd);
          if (mcmd.has("cb")) {
            self.invoke(mcmd["cb"], Lists.from(mcmd, null));
          }
         } else {
           sendDeviceMcmd(mcmd, 4);
         }
       }
       ifNotEmit(wajv) {
        sendDeviceMcmd(mcmd, 4);
       }

     } else {
      log.log("getsw kdaddr empty");
     }

     return(null);
   }

   updateSwStateCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String did = mcmd["did"];
     String itype = mcmd["itype"];
     Int dp = mcmd["dp"];
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     if (TS.notEmpty(cres)) {
        log.log("got getsw " + cres);
        unless (cres.has("undefined")) {
          String cset = hasw.get(did + "-" + dp);
          if (TS.isEmpty(cset) || cset != cres) {
            hasw.put(did + "-" + dp, cres);
            stDiffed = true;
            ifEmit(wajv) {
              if (def(mqtt)) {
                if (TS.notEmpty(itype)) {
                  if (itype == "sw") {
                    String stpp = "homeassistant/switch/" + did + "-" + dp + "/state";
                    mqtt.publish(stpp, cres.upper());
                  } elseIf (itype == "dim" || itype == "gdim") {
                    Map dps = Map.new();
                    dps.put("state", cres.upper());
                    stpp = "homeassistant/light/" + did + "-" + dp + "/state";
                    mqtt.publish(stpp, Json:Marshaller.marshall(dps));
                  } elseIf (itype == "rgb") {
                    dps = Map.new();
                    dps.put("state", cres.upper());
                    stpp = "homeassistant/light/" + did + "-" + dp + "/state";
                    mqtt.publish(stpp, Json:Marshaller.marshall(dps));
                  } elseIf (itype == "rgbgdim") {
                    dps = Map.new();
                    dps.put("state", cres.upper());
                    stpp = "homeassistant/light/" + did + "-" + dp + "/state";
                    mqtt.publish(stpp, Json:Marshaller.marshall(dps));
                  }
                }
              }
            }
          }
        }
      }
      return(null);
   }

   updateRgbState(String did, Int dp, String cname) {
     log.log("in updateRgbState " + did + " " + dp);

     auto hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
     String ctl = hactls.get(did);
     auto ctll = ctl.split(",");
     String itype = ctll.get(dp);

     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config

     String confs = hadevs.get(did);
     Map conf = Json:Unmarshaller.unmarshall(confs);

     //dostate eek setsw on e
     Int dpd = dp--;

     //getting the name
     String kdname = "CasNic" + conf["ondid"];
     String kdaddr = getCashedAddr(kdname);

     if (def(kdaddr)) {

       auto haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
       String sws = haspecs.get(did);
       if (TS.notEmpty(sws) && sws.has("q,")) {
         if (itype == "rgbgdim" || itype == "rgbcwgd") {
           cmds = "getstatexd Q " + dpd + " e";
         } else {
           cmds = "dostate Q " + dpd + " getrgb e";
         }
         log.log("cmds " + cmds);
         mcmd = Maps.from("cb", "updateRgbStateCb", "did", did, "dp", dp, "kdaddr", kdaddr, "kdname", kdname, "pwt", 0, "pw", "", "itype", itype, "cname", cname, "cmds", cmds);
       } else {
         if (itype == "rgbgdim" || itype == "rgbcwgd") {
           cmds = "getstatexd " + conf["spass"] + " " + dpd + " e";
         } else {
          String cmds = "dostate " + conf["spass"] + " " + dpd + " getrgb e";
         }
         log.log("cmds " + cmds);
         Map mcmd = Maps.from("cb", "updateRgbStateCb", "did", did, "dp", dp, "kdaddr", kdaddr, "kdname", kdname, "pwt", 2, "pw", conf["spass"], "itype", itype, "cname", cname, "cmds", cmds);
       }

       ifEmit(wajv) {
         if (backgroundPulse) {
          mcmd["runSync"] = true;
          processDeviceMcmd(mcmd);
          if (mcmd.has("cb")) {
            self.invoke(mcmd["cb"], Lists.from(mcmd, null));
          }
         } else {
           sendDeviceMcmd(mcmd, 4);
         }
       }
       ifNotEmit(wajv) {
        sendDeviceMcmd(mcmd, 4);
       }

     } else {
      log.log("getlvl kdaddr empty");
     }

     return(null);
   }



   updateRgbStateCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String did = mcmd["did"];
     String itype = mcmd["itype"];
     Int dp = mcmd["dp"];
     auto hargb = app.kvdbs.get("HARGB"); //hargb - device id to rgb
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     auto hacw = app.kvdbs.get("HACW");

     if (TS.notEmpty(cres)) {
        log.log("got getrgb " + cres);
        unless (cres.has("undefined")) {
          if (cres.has(",")) {
            if (itype == "rgbgdim" || itype == "rgbcwgd") {
              auto crl = cres.split(",");
              cres = crl[0] + "," + crl[1] + "," + crl[2];
              String lv = crl[3];
              String lvl = halv.get(did + "-" + dp);
              if (TS.isEmpty(lvl) || lvl != lv) {
                log.log("got lvl change in rgb update");
                halv.put(did + "-" + dp, lv);
                stDiffed = true;
              }
              if (itype == "rgbcwgd") {
                String cw = crl[4];
                String ocw = hacw.get(did + "-" + dp);
                if (TS.isEmpty(ocw) || ocw != cw) {
                  log.log("got cw change in rgb update");
                  hacw.put(did + "-" + dp, cw);
                  stDiffed = true;
                }
              }
            }
            String cset = hargb.get(did + "-" + dp);
            if (TS.isEmpty(cset) || cset.has(",")! || cset != cres) {
              log.log("got rgb update");
              hargb.put(did + "-" + dp, cres);
              stDiffed = true;
            }
            ifEmit(wajv) {
              if (def(mqtt)) {
                Map dps = Map.new();
                String st = hasw.get(did + "-" + dp);
                if (TS.notEmpty(st)) {
                  dps.put("state", st.upper());
                } else {
                  dps.put("state", "OFF");
                }
                if (itype == "rgbgdim") {
                  dps.put("brightness", Int.new(lv));
                }
                auto rgbl = cres.split(",");
                Map rgbm = Maps.from("r", Int.new(rgbl[0]), "g", Int.new(rgbl[1]), "b", Int.new(rgbl[2]));
                dps.put("color", rgbm);
                String stpp = "homeassistant/light/" + did + "-" + dp + "/state";
                mqtt.publish(stpp, Json:Marshaller.marshall(dps));
              }
            }
          }
        }
      }
      return(null);
   }

   updateLvlState(String did, Int dp, String cname) {
     log.log("in updateLvlState " + did + " " + dp);

     auto hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
     String ctl = hactls.get(did);
     auto ctll = ctl.split(",");
     String itype = ctll.get(dp);

     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config

     String confs = hadevs.get(did);
     Map conf = Json:Unmarshaller.unmarshall(confs);

     //dostate eek setsw on e
     Int dpd = dp--;

     //getting the name
     String kdname = "CasNic" + conf["ondid"];
     String kdaddr = getCashedAddr(kdname);

     if (def(kdaddr)) {

       auto haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
       String sws = haspecs.get(did);
       if (TS.notEmpty(sws) && sws.has("q,")) {
         if (itype == "gdim") {
          cmds = "getstatexd Q " + dpd + " e";
         } else {
          cmds = "dostate Q " + dpd + " getlvl e";
         }
         log.log("cmds " + cmds);
         mcmd = Maps.from("cb", "updateLvlStateCb", "did", did, "dp", dp, "kdaddr", kdaddr, "kdname", kdname, "pwt", 0, "pw", "", "itype", itype, "itype", itype, "cname", cname, "cmds", cmds);
       } else {
         if (itype == "gdim") {
           cmds = "getstatexd " + conf["spass"] + " " + dpd + " e";
         } else {
           String cmds = "dostate " + conf["spass"] + " " + dpd + " getlvl e";
         }
         log.log("cmds " + cmds);
         Map mcmd = Maps.from("cb", "updateLvlStateCb", "did", did, "dp", dp, "kdaddr", kdaddr, "kdname", kdname, "pwt", 2, "pw", conf["spass"], "itype", itype, "cname", cname, "cmds", cmds);
       }

       ifEmit(wajv) {
         if (backgroundPulse) {
          mcmd["runSync"] = true;
          processDeviceMcmd(mcmd);
          if (mcmd.has("cb")) {
            self.invoke(mcmd["cb"], Lists.from(mcmd, null));
          }
        } else {
          sendDeviceMcmd(mcmd, 4);
        }
       }
       ifNotEmit(wajv) {
        sendDeviceMcmd(mcmd, 4);
       }

     } else {
      log.log("getlvl kdaddr empty");
     }

     return(null);
   }

   updateLvlStateCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String did = mcmd["did"];
     Int dp = mcmd["dp"];
     String itype = mcmd["itype"];
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     if (TS.notEmpty(cres)) {
        log.log("got getlvl " + cres);
        unless (cres.has("undefined")) {
          String cset = halv.get(did + "-" + dp);
          Int cresi = Int.new(cres);
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
          ifEmit(wajv) {
            if (def(mqtt)) {
              if (TS.notEmpty(itype)) {
                if (itype == "dim" || itype == "gdim") {
                  Map dps = Map.new();
                  String st = hasw.get(did + "-" + dp);
                  if (TS.notEmpty(st)) {
                    dps.put("state", st.upper());
                  } else {
                    dps.put("state", "OFF");
                  }
                  //dps.put("state", "ON");
                  Int gamd = cresi;
                  dps.put("brightness", gamd);
                  String stpp = "homeassistant/light/" + did + "-" + dp + "/state";
                  mqtt.publish(stpp, Json:Marshaller.marshall(dps));
                }
              }
            }
          }
        }
      }
      return(null);
   }

   didInformRequest(request) Map {
     slots {
       Interval nextInform = Interval.now().addSeconds(75);
     }
     return(null);
   }

   manageStateUpdatesRequest(request) {

     fields {
       String lastError;
     }

     ifEmit(wajv) {
      slots {
        Int pulseCheck = Time:Interval.now().seconds;
      }
      if (backgroundPulse) {
        log.log("disabling backgroundPulse");
      }
      backgroundPulse = false;
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
     if (undef(cmdQueues.get(0))) {
       Bool qzempty = true;
     } else {
       qzempty = cmdQueues.get(0).isEmpty;
     }
     if (def(stDiffed) && stDiffed && qzempty && undef(currCmds)) {
       stDiffed = false;
       return(getDevicesRequest(request));
     }

     Map mres = processCmdsRequest(request);
     if (def(mres)) {
       return(mres);
     }
     ifEmit(wajv) {
       unless (backgroundPulse) {
         pulseDevices();
       }
     }
     ifNotEmit(wajv) {
      pulseDevices();
     }
     //log.log("done w manageStateUpdatesRequest");
     return(null);
   }

   runPulseDevices() {
      ifEmit(wajv) {
        while (true) {
          Time:Sleep.sleepMilliseconds(250);
          unless(backgroundPulse) {
            if (undef(pulseCheck)) {
              if (backgroundPulseOnIdle) {
                log.log("enabling backgroundPulse");
                backgroundPulse = backgroundPulseOnIdle;
              }
            } else {
              if (Time:Interval.now().seconds - pulseCheck > 5) {
                if (backgroundPulseOnIdle) {
                  log.log("enabling backgroundPulse");
                  backgroundPulse = backgroundPulseOnIdle;
                }
              }
            }
          }
          try {
            if (backgroundPulse) {
              pulseDevices();
            }
          } catch (any e) {
            log.elog("except in pulseDevices");
          }
        }
      }
    }

   pulseDevices() {
     //called every 250msish
     slots {
       Bool stDiffed;
       Set pendingStateUpdates;
       Set pendingSpecs;
       Map currentEvents;
       Int pcount;
       Map pdevices; //hadevs cpy
       Map pdcount; //id to last getlastevents count
       //Int lastRun;
     }

     Int ns = Time:Interval.now().seconds;

     /*if (undef(lastRun) || ns - lastRun > 20) {
       log.log("lastRun a while ago clearing events and reloading");
       stDiffed = true;
       pendingStateUpdates = null;
       currentEvents = null;
       pdevices = null;
       pdcount = null;
     }
     lastRun = ns;*/

     if (undef(pcount) || pcount > 9999) {
       pcount = 0;
       pdcount = null;
     }
     pcount++=;
     if (undef(pendingStateUpdates)) {
       pendingStateUpdates = Set.new();
     }
     if (undef(pendingSpecs)) {
       pendingSpecs = Set.new();
     }
     if (undef(currentEvents)) {
       currentEvents = Map.new();
     }
     if (undef(pdcount)) {
       pdcount = Map.new();
     }
     if (undef(pdevices)) {
       auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
       pdevices = hadevs.getMap();
     }

     if (pcount % 2 == 0) {
      Set toDel = Set.new();
      if (def(pendingStateUpdates)) {
        for (any k in pendingStateUpdates) {
            if (TS.notEmpty(k)) {
              try {
                log.log("doing updateXState for " + k);
                auto ks = k.split(",");
                if (ks[0] == "sw") {
                  updateSwState(ks[1], Int.new(ks[2]), ks[0]);
                } elseIf (ks[0] == "dim" || ks[0] == "gdim") {
                  updateSwState(ks[1], Int.new(ks[2]), ks[0]);
                  updateLvlState(ks[1], Int.new(ks[2]), ks[0]);
                } elseIf (ks[0] == "pwm") {
                  updateLvlState(ks[1], Int.new(ks[2]), ks[0]);
                } elseIf (ks[0] == "rgb" || ks[0] == "rgbgdim" || ks[0] == "rgbcwgd") {
                  updateSwState(ks[1], Int.new(ks[2]), ks[0]);
                  updateRgbState(ks[1], Int.new(ks[2]), ks[0]);
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
     if (pcount % 6 == 0 && pendingSpecs.notEmpty) {
       Set spToDel = Set.new();
       for (String spdid in pendingSpecs) {
          updateSpec(spdid);
          spToDel += spdid;
          break;
       }
       for (String spk in spToDel) {
         pendingSpecs.delete(spk);
         return(null);
       }
     }

      Map lpd = pdevices;
      Map lpc = pdcount;
      if (def(lpd) && def (lpc)) {
        for (auto pdc in pdevices) {
          Int dc = pdcount.get(pdc.key);
          if (undef(dc) || dc < pcount) {
            dc = pcount + 16 + System:Random.getIntMax(16); //(secs * 4), was 12
            pdcount.put(pdc.key, dc);
            getLastEvents(pdc.value);
            break;
          }
        }
      }
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
              InitializeResolveListener.nowResolving = null;
              InitializeResolveListener.resolving.clear();
              InitializeResolveListener.maybeResolve();
          }

          @Override
          public void onServiceFound(NsdServiceInfo service) {
              // A service was found! Do something with it.
              System.out.println("Service discovery success" + service);
              String sname = service.getServiceName();
              if (sname != null && sname.startsWith("CasNic")) {
                System.out.println("onServiceFound " + sname);
                if (!InitializeResolveListener.knownDevices.containsKey(sname)) {
                  InitializeResolveListener.resolving.put(sname, service);
                  InitializeResolveListener.maybeResolve();
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
      if (discoverNow.o) {
        startDiscovery();
        log.log("started discovery");
        Time:Sleep.sleepSeconds(10);
        log.log("discovery sleep done");
        stopDiscovery();
        log.log("stopped discovery");
        Time:Sleep.sleepSeconds(10);
        discoverNow.o = false;
      } else {
        Time:Sleep.sleepSeconds(10);
      }
     }
   }

   startDiscovery() {
     ifEmit(jvad) {
     emit(jv) {
       """
       try {
        //multicastLock.acquire();
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

     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config

     if (def(pendingSpecs)) {
       pendingSpecs.put(did);
     }
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

     Map mcmd = Maps.from("cb", "rectlDeviceCb", "did", conf["id"], "kdaddr", kdaddr, "kdname", kdname, "pwt", 2, "pw", conf["spass"], "cmds", cmds);
     sendDeviceMcmd(mcmd, 2);

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
      if (def(request)) {
        return(CallBackUI.reloadResponse());
      }
      return(null);
   }

   setDeviceSwRequest(String rhan, String rpos, String rstate, request) Map {
     log.log("in setDeviceSwRequest " + rhan + " " + rpos + " " + rstate);

     //not checking user rn
     Map mcmd = setDeviceSwMcmd(rhan, rpos, rstate);
     if (sendDeviceMcmd(mcmd, 0)!) {
       if (def(request)) {
         return(CallBackUI.showDevErrorResponse());
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

     Map mcmd = Maps.from("cb", "setDeviceSwCb", "did", conf["id"], "rhan", did, "rpos", iposs, "rstate", state, "kdaddr", kdaddr, "kdname", kdname, "pwt", 2, "pw", conf["spass"], "itype", itype, "cmds", cmds);
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
       ifEmit(wajv) {
        if (def(mqtt)) {
          if (TS.notEmpty(itype)) {
            if (itype == "sw") {
              String stpp = "homeassistant/switch/" + rhan + "-" + rpos + "/state";
              mqtt.publish(stpp, rstate.upper());
            } elseIf (itype == "dim" || itype == "gdim") {
              Map dps = Map.new();
              dps.put("state", rstate.upper());
              stpp = "homeassistant/light/" + rhan + "-" + rpos + "/state";
              mqtt.publish(stpp, Json:Marshaller.marshall(dps));
            } elseIf (itype == "rgb") {
              dps = Map.new();
              dps.put("state", rstate.upper());
              stpp = "homeassistant/light/" + rhan + "-" + rpos + "/state";
              mqtt.publish(stpp, Json:Marshaller.marshall(dps));
            } elseIf (itype == "rgbgdim") {
              dps = Map.new();
              dps.put("state", rstate.upper());
              stpp = "homeassistant/light/" + rhan + "-" + rpos + "/state";
              mqtt.publish(stpp, Json:Marshaller.marshall(dps));
            }
          }
        }
       }
     }
     stDiffed = true;
     return(null);
   }

   setDeviceRgbRequest(String rhanpos, String rgb, request) Map {
     log.log("in setDeviceRgbRequest " + rhanpos);

     //not checking user rn
     Map mcmd = setDeviceRgbMcmd(rhanpos, rgb);
     if (sendDeviceMcmd(mcmd, 0)!) {
       if (def(request)) {
         //return(CallBackUI.showDevErrorResponse());
         //return(CallBackUI.reloadResponse());
       }
     }

     return(null);
   }

   setDeviceRgbMcmd(String rhanpos, String rgb) Map {

     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     auto hacw = app.kvdbs.get("HACW");
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

     if (itype == "rgbgdim" || itype == "rgbcwgd") {
       String lv = halv.get(rhanpos);
       if (TS.isEmpty(lv)) { lv = "255"; }
       Int gamd = Int.new(lv);
       gamd = gamma(gamd);
       String gamds = gamd.toString();
       String frgb = rgbForRgbLvl(rgb, gamds);
       String xd = rgb + "," + lv;
       if (itype == "rgbcwgd") {
         if (frgb == "255,255,255") {
           String cw = "0";
         } else {
           cw = "127";
         }
         frgb += "," += cwForCwLvl(cw, gamds);
         xd += "," += cw;
         String setcmd = " setrgbcw ";
       } else {
         setcmd = " setrgb ";
       }
       cmds = "dostatexd " + conf["spass"] + " " + rpos.toString() + setcmd + frgb + " " + xd + " e";
     } else {
       String cmds = "dostate " + conf["spass"] + " " + rpos.toString() + " setrgb " + rgb + " e";
     }

     log.log("cmds " + cmds);

     //getting the name
     String kdname = "CasNic" + conf["ondid"];
     String kdaddr = getAddrDis(kdname);

     //tcpjv edition

     //cmds += "\r\n";

     Map mcmd = Maps.from("cb", "setDeviceRgbCb", "did", conf["id"], "rhanpos", rhanpos, "rgb", rgb, "kdaddr", kdaddr, "kdname", kdname, "pwt", 2, "pw", conf["spass"], "itype", itype, "cmds", cmds);
     if (itype == "rgbgdim" || itype == "rgbcwgd") {
       mcmd.put("lv", lv);
       if (itype == "rgbcwgd") {
        mcmd.put("cw", cw);
      }
     }

     return(mcmd);
   }

   setDeviceRgbCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String rhanpos = mcmd["rhanpos"];
     String rgb = mcmd["rgb"];
     String itype = mcmd["itype"];
     auto hargb = app.kvdbs.get("HARGB"); //hargb - device id to rgb
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     auto hacw = app.kvdbs.get("HACW");
     if (TS.notEmpty(cres) && cres.has("ok")) {
       //Map tb = trueRgb(rgb);
       //rgb = "" + tb["r"] + "," + tb["g"] + "," + tb["b"];
       log.log("hargb putting " + rhanpos + " " + rgb);
       hargb.put(rhanpos, rgb);
       hasw.put(rhanpos, "on");
       if (TS.notEmpty(mcmd["cw"])) {
         hacw.put(rhanpos, mcmd["cw"]);
       }
       ifEmit(wajv) {
        if (def(mqtt)) {
          if (TS.notEmpty(itype)) {
            if (itype == "rgb" || itype == "rgbgdim") {
              auto rgbl = rgb.split(",");
              Map rgbm = Maps.from("r", Int.new(rgbl[0]), "g", Int.new(rgbl[1]), "b", Int.new(rgbl[2]));
              Map dps = Map.new();
              dps.put("state", "ON");
              dps.put("color", rgbm);
              if (itype == "rgbgdim") {
                dps.put("brightness", Int.new(mcmd["lv"]));
              }
              String stpp = "homeassistant/light/" + rhanpos + "/state";
              mqtt.publish(stpp, Json:Marshaller.marshall(dps));
            }
          }
        }
       }
     } else {
       if (def(request)) {
          //return(CallBackUI.reloadResponse());
        }
     }
     stDiffed = true;
     return(null);
   }

   setDeviceTempRequest(String rhanpos, String rstate, request) Map {
     log.log("in setDeviceTempRequest " + rhanpos + " " + rstate);

     //not checking user rn
     Map mcmd = setDeviceTempMcmd(rhanpos, rstate);
     if (sendDeviceMcmd(mcmd, 0)!) {
       if (def(request)) {
         return(CallBackUI.showDevErrorResponse());
       }
     }
     return(null);
   }

   setDeviceTempMcmd(String rhanpos, String rstate) Map {

     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     auto hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
     auto hargb = app.kvdbs.get("HARGB"); //hargb - device id to rgb
     auto hacw = app.kvdbs.get("HACW"); //hargb - device id to rgb

     auto rhp = rhanpos.split("-");
     String rhan = rhp.get(0);

     Int rpos = Int.new(rhp.get(1));

     String ctl = hactls.get(rhan);
     auto ctll = ctl.split(",");
     String itype = ctll.get(rpos);

     rpos--=;

     String confs = hadevs.get(rhan);
     Map conf = Json:Unmarshaller.unmarshall(confs);

     String ocw = rstate;

     if (itype == "cwgd" || itype == "rgbcwgd") {
       String lv = halv.get(rhanpos);
       if (TS.isEmpty(lv)) { lv = "255"; }
       Int gamd = Int.new(lv);
       gamd = gamma(gamd);
       String gamds = gamd.toString();
       log.log("ocw " + ocw);
       String fcw = cwForCwLvl(ocw, gamds);
       if (itype == "rgbcwgd") {
         String orgb = "255,255,255";
         fcw = orgb + "," + fcw;
         String xd = orgb + "," + lv + "," + rstate;
         String setcmd = " setrgbcw ";
       } else {
         setcmd = " setcw ";
         xd = ocw + "," + lv;
       }
       log.log("fcw " + fcw);
       String cmds = "dostatexd " + conf["spass"] + " " + rpos.toString() + setcmd + fcw + " " + xd + " e";
     }
     log.log("cmds " + cmds);

     //getting the name
     String kdname = "CasNic" + conf["ondid"];
     String kdaddr = getAddrDis(kdname);

     Map mcmd = Maps.from("cb", "setDeviceTempCb", "did", conf["id"], "rhanpos", rhanpos, "cw", rstate, "kdaddr", kdaddr, "kdname", kdname, "pwt", 2, "pw", conf["spass"], "itype", itype, "cmds", cmds);
     if (itype == "rgbcwgd") {
       mcmd.put("rgb", orgb);
     }

     return(mcmd);
   }

   setDeviceTempCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String rhanpos = mcmd["rhanpos"];
     String cw = mcmd["cw"];
     String itype = mcmd["itype"];
     auto hacw = app.kvdbs.get("HACW"); //hargb - device id to rgb
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     auto hargb = app.kvdbs.get("HARGB"); //hargb - device id to rgb
     if (TS.notEmpty(cres) && cres.has("ok")) {
       //Map tb = trueRgb(rgb);
       //rgb = "" + tb["r"] + "," + tb["g"] + "," + tb["b"];
       log.log("hacw putting " + rhanpos + " " + cw);
       hacw.put(rhanpos, cw);
       hasw.put(rhanpos, "on");
       if (TS.notEmpty(mcmd["rgb"])) {
         hargb.put(rhanpos, mcmd["rgb"]);
       }
     }
     stDiffed = true;
     return(null);
   }

   gamma(Int start) Int {
     //start^2/255
     //if (true) { return(start); }
     Int res = start.squared;
     res = res / 255;
     if (res < 1) {
       res = 1;
       log.log("upped gamma to 1");
     }
     if (res > 255) {
       res = 255;
       log.log("downed gamma to 255");
     }
     log.log("gamma got " + res + " for " + start);
     return(res);
   }

   setDeviceLvlRequest(String rhanpos, String rstate, request) Map {
     log.log("in setDeviceLvlRequest " + rhanpos + " " + rstate);

     //not checking user rn
     Map mcmd = setDeviceLvlMcmd(rhanpos, rstate);
     if (sendDeviceMcmd(mcmd, 0)!) {
       if (def(request)) {
         return(CallBackUI.showDevErrorResponse());
       }
     }
     return(null);
   }

   setDeviceLvlMcmd(String rhanpos, String rstate) Map {

     auto hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     auto hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     auto halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     auto hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
     auto hargb = app.kvdbs.get("HARGB"); //hargb - device id to rgb
     auto hacw = app.kvdbs.get("HACW"); //hargb - device id to rgb

     auto rhp = rhanpos.split("-");
     String rhan = rhp.get(0);

     Int rpos = Int.new(rhp.get(1));

     String ctl = hactls.get(rhan);
     auto ctll = ctl.split(",");
     String itype = ctll.get(rpos);

     rpos--=;

     String confs = hadevs.get(rhan);
     Map conf = Json:Unmarshaller.unmarshall(confs);

     Int gamd = Int.new(rstate);
     gamd = gamma(gamd);
     String gamds = gamd.toString();

     if (itype == "gdim") {
       cmds = "dostatexd " + conf["spass"] + " " + rpos.toString() + " setlvl " + gamds + " " + rstate + " e";
     } elseIf (itype == "rgbgdim" || itype == "rgbcwgd") {
       String orgb = hargb.get(rhanpos);
       if (TS.isEmpty(orgb)) {
         orgb = "255,255,255";
       }
       gamd = Int.new(rstate);
       gamd = gamma(gamd);
       gamds = gamd.toString();
       if (itype == "rgbcwgd") {
         if (orgb == "255,255,255") {
           String ocw = hacw.get(rhanpos);
           if (TS.isEmpty(ocw)) {
             ocw = "127";
           }
           String fcw = cwForCwLvl(ocw, gamds);
           String frgb = orgb + "," + fcw;
           xd = orgb + "," + rstate + "," + ocw;
         } else {
           ocw = "127";
           frgb = rgbForRgbLvl(orgb, gamds);
           frgb += "," + cwForCwLvl(ocw, gamds);
           xd = orgb + "," + rstate + "," + ocw;
         }
         cmds = "dostatexd " + conf["spass"] + " " + rpos.toString() + " setrgbcw " + frgb + " " + xd + " e";
       } else {
        frgb = rgbForRgbLvl(orgb, gamds);
        String xd = orgb + "," + rstate;
        cmds = "dostatexd " + conf["spass"] + " " + rpos.toString() + " setrgb " + frgb + " " + xd + " e";
       }
     } elseIf (itype == "cwgd") {
       ocw = hacw.get(rhanpos);
       if (TS.isEmpty(ocw)) {
         ocw = "127";
       }
       gamd = Int.new(rstate);
       gamd = gamma(gamd);
       gamds = gamd.toString();
       fcw = cwForCwLvl(ocw, gamds);
       xd = ocw + "," + rstate;
       cmds = "dostatexd " + conf["spass"] + " " + rpos.toString() + " setcw " + fcw + " " + xd + " e";
     } else {
       String cmds = "dostate " + conf["spass"] + " " + rpos.toString() + " setlvl " + rstate + " e";
     }
     log.log("cmds " + cmds);

     //getting the name
     String kdname = "CasNic" + conf["ondid"];
     String kdaddr = getAddrDis(kdname);

     Map mcmd = Maps.from("cb", "setDeviceLvlCb", "did", conf["id"], "rhanpos", rhanpos, "rstate", rstate, "kdaddr", kdaddr, "kdname", kdname, "pwt", 2, "pw", conf["spass"], "itype", itype, "cmds", cmds);

     return(mcmd);
   }

   //get the rgb value for the color at max brightness, so if largest were at 255
   trueRgb(String rgb) Map {
     log.log("in trueRgb");
     log.log("rgb " + rgb);
     Float tff = Float.intNew(255);
     auto rgbl = rgb.split(",");
     Int r = Int.new(rgbl[0]);
     Int g = Int.new(rgbl[1]);
     Int b = Int.new(rgbl[2]);
     Int max = Math:Ints.max(r, Math:Ints.max(g, b));
     if (max > 255 || max < 1) {
       plyer = Float.intNew(1);
     } else {
      Float maxf = Float.intNew(max);
      Float plyer = tff / maxf;
     }
     Float rf = Float.intNew(r);
     Float gf = Float.intNew(g);
     Float bf = Float.intNew(b);
     rf = rf * plyer;
     gf = gf * plyer;
     bf = bf * plyer;
     r = rf.toInt();
     g = gf.toInt();
     b = bf.toInt();
     log.log("true rgb " + r + "," + g + "," + b);
     return(Maps.from("rf", rf, "gf", gf, "bf", bf, "r", r, "g", g, "b", b));
   }

   rgbForRgbLvl(String rgb, String lvl) {
     //what would you multiply the max color by to get to 255 (IS 255/maxcolorval)
     //multiply all 3 by this, that's the true rgb color
     log.log("in rgbForRgbLvl");
     log.log("rgb " + rgb);
     log.log("lvl " + lvl);
     Float tff = Float.intNew(255);
     Map tb = trueRgb(rgb);
     Float rf = tb["rf"];
     Float gf = tb["gf"];
     Float bf = tb["bf"];
     Int r = tb["r"];
     Int g = tb["g"];
     Int b = tb["b"];
     Int min = 0;
     if (r > 0 && (min == 0 || r < min)) { min = r; }
     if (g > 0 && (min == 0 || g < min)) { min = g; }
     if (b > 0 && (min == 0 || b < min)) { min = b; }
     // what times min will make min == 1, can't go below
     // min * x = 1, 1 / min = x
     Float minf = Float.intNew(min);
     Float onef = Float.intNew(1);
     Float mindplyer = onef / minf;
     Int lvli = Int.new(lvl);
     if (lvli < 0 || lvli > 255) {
       lvli = 255;
     }
     Float lvlf = Float.intNew(lvli);
     Float dplyer = lvlf / tff;
     if (dplyer < mindplyer) {
       log.log("dplyer too low floor at mindplyer");
       dplyer = mindplyer;
     }
     rf = rf * dplyer;
     gf = gf * dplyer;
     bf = bf * dplyer;
     r = rf.toInt();
     g = gf.toInt();
     b = bf.toInt();
     log.log("adjusted rgb " + r + "," + g + "," + b);
     return(r.toString() + "," + g.toString() + "," + b.toString());
   }

   cwForCwLvl(String cw, String lvl) {
     log.log("in cwForCwLvl cw " + cw + " lvl " + lvl);

     //higher value more warm
     //first value is cold, second is warm

     //right in middle is 255,255
     //at first quartile 255, 255-128
     //at third quartile 255-128, 255
     //at left 255,0
     //at right 0,255

     Int rsi = Int.new(cw);
     if (rsi == 127) {
       Int c = 255;
       Int w = 255;
     } elseIf (rsi < 127) {
       c = 255;
       w = rsi * 2; //127 == 254, 120 == 240, 64 == 128, 32 == 64, 16 == 8, 8 == 16, 4 == 8
     } elseIf (rsi > 127) {
       //254 == 2, 128 == 254, 134 == 240,
       Int rsii = 255 - rsi;//128 == 127, 127+7=134,255-134=121,127+64= 255-251=4
       c = rsii * 2; //127 == 254, 121 == 242, 64 == 128, 32 == 64
       w = 255;
     }

     //c and w scaled to lvl/255
     Float tff = Float.intNew(255);
     Float cf = Float.intNew(c);
     Float wf = Float.intNew(w);
     Int l = Int.new(lvl);
     Float lf = Float.intNew(l);
     Float mpl = lf / tff;
     Float fcf = cf * mpl;
     Float fwf = wf * mpl;
     Int fc = fcf.toInt();
     Int fw = fwf.toInt();
     if (fc < 1 && c > 0) { fc = 1; }
     if (fw < 1 && w > 0) { fw = 1; }
     String res = fc.toString() + "," + fw.toString();
     log.log("cwForCwLvl res " + res);
     return(res);
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
       ifEmit(wajv) {
        if (def(mqtt)) {
          if (TS.notEmpty(itype)) {
            if (itype == "dim" || itype == "gdim") {
              Map dps = Map.new();
              dps.put("state", "ON");
              Int gamd = Int.new(rstate);
              dps.put("brightness", gamd);
              String stpp = "homeassistant/light/" + rhanpos + "/state";
              mqtt.publish(stpp, Json:Marshaller.marshall(dps));
            }
          }
        }
       }
     }
     stDiffed = true;
     return(null);
   }

   processCmdsRequest(request) Map {
     slots {
       String cmdsRes;
       Map currCmds;
       Int aptrs; //12 for 3s (was), 16 for 4s
     }
      if (undef(cmdsRes) && def(currCmds)) {
      if (undef(aptrs)) {
        aptrs = 1;
      } else {
        aptrs++=;
      }
      if (aptrs > 16) {
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
       if (mcmd.has("cb")) {
         return(self.invoke(mcmd["cb"], Lists.from(mcmd, request)));
       }
     } elseIf (undef(currCmds)) {
       for (Int i = 0;i < 10;i++=) {
         Container:LinkedList cmdQueue = cmdQueues.get(i);
         if (def(cmdQueue)) {
          Map mcmd = cmdQueue.get(0);
          if (def(mcmd)) {
            auto n = cmdQueue.getNode(0);
            n.delete();
            cmdsRes = null;
            aptrs = null;
            if (TS.notEmpty(mcmd["kdaddr"])) {
              currCmds = mcmd;
              processDeviceMcmd(mcmd);
            } else {
              currCmds = null;
            }
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
     }
     //?failre / timeout callback?
     String kdaddr = mcmd["kdaddr"];
     String kdname = mcmd["kdname"];

     if (mcmd.has("cb")) {
       cmdsFailMcmd = mcmd;
     }


     auto haknc = app.kvdbs.get("HAKNC"); //kdname to addr
     if (TS.notEmpty(kdname)) {
      log.log("SHOULD NOW EJECT " + kdname);
      haknc.delete(kdname);
      if (def(knc)) {
        knc.delete(kdname);
      }
      ifEmit(jvad) {
        emit(jv) {
          """
        InitializeResolveListener.knownDevices.remove(bevl_kdname.bems_toJvString());
        """
        }
      }
     }

     if (TS.notEmpty(kdaddr)) {
       log.log("SHOULD NOW EJECT " + kdaddr);
       if (def(kac)) {
          String kdn = kac.get(kdaddr);
          if (TS.notEmpty(kdn)) {
            //clear pending
            for (auto kv in cmdQueues) {
              Container:LinkedList cmdQueue = kv.value;
              if (def(cmdQueue)) {
                for (Map mcmdcl in cmdQueue) {
                  if (TS.notEmpty(mcmdcl["kdaddr"]) && mcmdcl["kdaddr"] == kdaddr) {
                    log.log("clearing kdaddr in cmdQueue");
                    mcmdcl["kdaddr"] = "";
                  }
                }
              }
             }
            String kda = knc.get(kdn);
            if (TS.notEmpty(kda)) {
              knc.delete(kdn);
              haknc.delete(kdn);
             }
            kac.delete(kdaddr);
           }
         }
       }

      if (TS.notEmpty(kdname)) {
      for (kv in cmdQueues) {
        cmdQueue = kv.value;
        if (def(cmdQueue)) {
          for (mcmdcl in cmdQueue) {
            if (TS.notEmpty(mcmdcl["kdname"]) && mcmdcl["kdname"] == kdname) {
              log.log("clearing kdaddr for kdname in cmdQueue");
              mcmdcl["kdaddr"] = "";
            }
          }
        }
      }
      }
   }

   sendDeviceMcmd(Map mcmd, Int priority) Bool {
      if (def(mcmd) && TS.notEmpty(mcmd["kdaddr"])) {
        Container:LinkedList cmdQueue = cmdQueues.get(priority);
        if (undef(cmdQueue)) {
          cmdQueue = Container:LinkedList.new();
          cmdQueues.put(priority, cmdQueue);
        }
        //max waiting per kdaddr
        Int wct = 0;
        for (auto i = cmdQueue.iterator;i.hasNext;;) {
          Map mc = i.next;
          if (mc["kdaddr"] == mcmd["kdaddr"]) {
            wct++=;
            if (wct > 6) {
              log.log("too many waiting no adding to cmdQueue");
              return(false);
            }
          }
        }
        cmdQueue += mcmd;
        log.log("added to cmdQueue");
        return(true);
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

     if (mcmd.has("did") && TS.notEmpty(mcmd["did"])) {
      auto haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
      String sws = haspecs.get(mcmd["did"]);
      if (TS.notEmpty(sws) && sws.has("p3,")) {
        log.log("adding tesh in processDeviceMcmd");
        Int teshi = Time:Interval.now().seconds;
        //teshi -= 300;
        mcmd["tesh"] = teshi.toString();
      } else {
        log.log("no p3 in  processDeviceMcmd");
      }
     } else {
       log.log("no did in processDeviceMcmd");
     }

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
         //System.out.println("ma.getLastCx()");
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

     if (visnetsFails > 3) {
       log.log("visnetsFails overmuch");
       if (TS.notEmpty(ssid) && TS.notEmpty(sec)) {
         log.log("have ssid sec giving it a go, is old device");
         count.setValue(tries);
         return(CallBackUI.getDevWifisResponse(count, tries, wait));
       } else {
         return(CallBackUI.informResponse("Older device and no known Wifi config.  Under Settings / Advanced Settings configure a 2.4Ghz Wifi Network Name (ssid) and password and then retry device setup"));
       }
     } elseIf (count >= tries || visnetsDone) {
       log.log("doing settle wifi");
       return(CallBackUI.settleWifiResponse(visnets, ssid, sec));
     }

     String cmds = "previsnets " + visnetsPos + " e";
     Map mcmd = Maps.from("cb", "previsnetsCb", "kdaddr", "192.168.4.1", "pwt", 0, "pw", "", "cmds", cmds);
     sendDeviceMcmd(mcmd, 1);
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

          sendDeviceMcmd(mcmd, 1);
        } elseIf (alStep == "getcontroldef") {
          cmds = "getcontroldef " + devSpass + " e";
          mcmd = Maps.from("cb", "allsetCb", "disDevId", disDevId, "kdaddr", "192.168.4.1", "pwt", 0, "pw", "", "cmds", cmds);
          sendDeviceMcmd(mcmd, 1);
        } elseIf (alStep == "setname") {
          cmds = "putconfigs " + devPass + " vhex fc.dname " + Hex.encode(devName) + " e";
          mcmd = Maps.from("cb", "allsetCb", "disDevId", disDevId, "kdaddr", "192.168.4.1", "pwt", 0, "pw", "", "cmds", cmds);
          sendDeviceMcmd(mcmd, 1);
        } elseIf (alStep == "setmqtt") {
          String mqttBroker = app.configManager.get("mqtt.broker");
          String mqttUser = app.configManager.get("mqtt.user");
          String mqttPass = app.configManager.get("mqtt.pass");
          cmds = "putconfigs " + devPass + " vhex fc.mqhost " + Hex.encode(mqttBroker) + " fc.mquser " + Hex.encode(mqttUser) + " fc.mqpass " + Hex.encode(mqttPass) + " e";
          mcmd = Maps.from("cb", "allsetCb", "disDevId", disDevId, "kdaddr", "192.168.4.1", "pwt", 0, "pw", "", "cmds", cmds);
          sendDeviceMcmd(mcmd, 1);
        } elseIf (alStep == "setwifi") {
          cmds = "setwifi " + devPass + " hex " + devSsid + " " + devSec + " e";
          mcmd = Maps.from("cb", "allsetCb", "disDevId", disDevId, "kdaddr", "192.168.4.1", "pwt", 0, "pw", "", "cmds", cmds);
          sendDeviceMcmd(mcmd, 1);
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
          sendDeviceMcmd(mcmd, 1);
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
         alStep = "setwifi";
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
          ifEmit(wajv) {
            if (def(mqtt) && mqtt.isOpen) {
              System:Thread.new(System:Invocation.new(self, "waitCloseMqtt", List.new())).start();
            }
          }
          return(CallBackUI.reloadResponse());
        }
     }
     return(null);
   }

   waitCloseMqtt() {
     ifEmit(wajv) {
       log.log("waiting to close");
       Time:Sleep.sleepSeconds(5);
       if (def(mqtt)) {
         log.log("closing mqtt");
         mqtt.close();
         mqtt = null;
       }
     }
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
    sendDeviceMcmd(mcmd, 1);
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
          ftype = "Athom 7w Bulb";
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
     App:AppStart.start(Parameters.new(Lists.from("--plugin", "BA:BamPlugin", "--plugin", "App:ConfigPlugin", "--appPlugin", "CasCon", "--appType", "browser", "--appName", "CasCon", "--sdbClass", "Db:MemFileStoreKeyValue", "--appKvPoolSize", "1")));
   }
   
}

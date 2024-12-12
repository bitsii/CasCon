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

  doFakeAuth(Map arg, request) Bool {
    unless (app.params.isTrue("fakeAuth") && TS.notEmpty(System:Environment.getVariable("FAKE_AUTH"))) { return(false); }
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
    return(true);
  }

  loginRequest(Map arg, request) {
    ifEmit(wajv) {
    //Account a = self.accountManager.getAccount(arg["accountName"]);
    //a.checkPass(arg["accountPass"])
    //check pass against ha if present
    //set pass if it doesn't checkPass (it's changed), or if account missing
    Bool authOk = false;
    if (doFakeAuth(arg, request)) {
      authOk = true;
    } elseIf (TS.notEmpty(prot.supTok) && TS.notEmpty(prot.supUrl) && prot.doSupAuth) {
        //log.log("GOT supTok " + prot.supTok);
        log.log("got supTok");
        Web:Client client = Web:Client.new();
        client.url = prot.supUrl + "/auth";
        client.outputContentType = "application/json";

        client.outputHeaders.put("X-Supervisor-Token", prot.supTok);
        //client.outputHeaders.put("X-Supervisor-Token", "blah");

        client.verb = "POST";
        String co = Json:Marshaller.marshall(Maps.from("username", arg["accountName"], "password", arg["accountPass"]));
        //log.log("co " + co);
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
    ifNotEmit(wajv) {
      return(null);
    }
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
          Bool backgroundPulseOnIdle = false;
          Bool backgroundPulse = backgroundPulseOnIdle;
          Mqtt mqtt;
          String mqttMode;
          String mqttReId;
        }
        slots {
          Map knc = Map.new();
          Set remoteAddrs = Set.new();
        }
        ifEmit(wajv) {
          backgroundPulseOnIdle = true;
          backgroundPulse = backgroundPulseOnIdle;
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
      }

      ifEmit(wajv) {
        System:Thread.new(System:Invocation.new(self, "runPulseDevices", List.new())).start();
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
      ifEmit(wajv) {
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
    }

    keepMqttUp() {
      ifEmit(wajv) {
        while (true) {
          Time:Sleep.sleepSeconds(20);
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
            var mqtt2 = mqtt;
            mqtt = null;
            mqtt2.close();
          }
          String mqttBroker = app.configManager.get("mqtt.broker");
          String mqttUser = app.configManager.get("mqtt.user");
          String mqttPass = app.configManager.get("mqtt.pass");
          String mqttMode = app.configManager.get("mqtt.mode");
          if (TS.isEmpty(mqttMode)) { mqttMode = "haRelay"; }
          if (TS.isEmpty(mqttBroker) || TS.isEmpty(mqttUser) || TS.isEmpty(mqttPass)) {
            ifEmit(wajv) {
            if (TS.notEmpty(prot.supTok) && TS.notEmpty(prot.supUrl) && prot.doSupAuth) {
              //log.log("GOT supTok " + prot.supTok);
              log.log("got supTok");
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
                  mqttMode = "haRelay";
                }
              } else {
                log.log("mqtt ha get conn res empty");
              }
            }
            }
          }
          if (TS.notEmpty(mqttMode) && TS.notEmpty(mqttBroker) && TS.notEmpty(mqttUser) && TS.notEmpty(mqttPass)) {
            initializeMqtt(mqttMode, mqttBroker, mqttUser, mqttPass);
          }
        } else {
          mqtt.publish("casnic/ktlo", "yo");
        }
      }
    }

    initializeMqtt(String _mqttMode, String mqttBroker, String mqttUser, String mqttPass) {
      ifEmit(wajv) {
       log.log("initializing mqtt");
       mqttMode = _mqttMode;
       mqttReId = System:Random.getString(16);
       mqtt = Mqtt.new();
       mqtt.broker = mqttBroker;
       mqtt.user = mqttUser;
       mqtt.pass = mqttPass;
       mqtt.messageHandler = self;
       mqtt.open();
       if (mqtt.isOpen) {
        log.log("mqtt opened");
        if (mqttMode == "haRelay") {
          mqtt.subscribe("homeassistant/status");
        }
        if (mqttMode == "remote" || mqttMode == "fullRemote") {
          mqtt.subscribe("casnic/res/" + mqttReId);
        }
        if (mqttMode == "relay") {
          mqtt.subscribe("casnic/cmds");
        }
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
        var hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
        var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
        var hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
        var halv = app.kvdbs.get("HALV"); //halv - device id to lvl
        var hargb = app.kvdbs.get("HARGB"); //hargb - device id to rgb
        var hacw = app.kvdbs.get("HACW");
        Map devices = Map.new();
        Map ctls = Map.new();
        Map topubs = Map.new();
        if (mqttMode == "relay" || mqttMode == "haRelay") {
          for (any kv in hadevs.getMap()) {
            String did = kv.key;
            String confs = kv.value;
            Map conf = Json:Unmarshaller.unmarshall(confs);
            devices.put(did, confs);
            String ctl = hactls.get(did);
            if (TS.notEmpty(ctl)) {
              ctls.put(did, ctl);
              var ctll = ctl.split(",");
              log.log("got ctl " + ctl);
              for (Int i = 1;i < ctll.length;i++) {
                String itype = ctll.get(i);
                log.log("got ctled itype " + itype + " pos " + i);
                if (mqttMode == "haRelay") {
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
                  } elseIf (itype == "rgb" || itype == "rgbgdim" || itype == "rgbcwgd" || itype == "rgbcwsgd" || itype == "cwgd") {
                    tpp = "homeassistant/light/" + did + "-" + i;
                    cf = Maps.from("name", conf["name"], "command_topic", tpp + "/set", "state_topic", tpp + "/state", "unique_id", did + "-" + i, "schema", "json");
                    if (itype == "rgb" || itype == "rgbgdim" || itype == "rgbcwgd" || itype == "rgbcwsgd") {
                      cf.put("rgb", true);
                    } else {
                      cf.put("rgb", false);
                    }
                    if (itype == "rgbgdim" || itype == "rgbcwgd" || itype == "rgbcwsgd" || itype == "cwgd") {
                      cf.put("brightness", true);
                      cf.put("brightness_scale", 255);
                    } else {
                      cf.put("brightness", false);
                    }
                    if (itype == "rgbcwgd" || itype == "rgbcwsgd" || itype == "cwgd") {
                      cf.put("color_temp", true);
                    } else {
                      cf.put("color_temp", false);
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
                    if (itype == "rgbgdim" || itype == "rgbcwgd" || itype == "rgbcwsgd" || itype == "cwgd") {
                      lv = halv.get(did + "-" + i);
                      if (TS.notEmpty(lv)) {
                        dps.put("brightness", Int.new(lv));
                      }
                      if (itype == "rgbcwgd" || itype == "rgbcwsgd" || itype == "cwgd") {
                        String cw = hacw.get(did + "-" + i);
                        if (TS.notEmpty(cw)) {
                          dps.put("color_temp", lsToMired(Int.new(cw)));
                        }
                      }
                    }
                    unless (itype == "cwgd") {
                      String rgb = hargb.get(did + "-" + i);
                      if (TS.isEmpty(rgb)) {
                        rgb = "255,255,255";
                      }
                      var rgbl = rgb.split(",");
                      Map rgbm = Maps.from("r", Int.new(rgbl[0]), "g", Int.new(rgbl[1]), "b", Int.new(rgbl[2]));
                      dps.put("color", rgbm);
                    }
                    topubs.put(tpp + "/state", Json:Marshaller.marshall(dps));
                  }
                }
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
      if (TS.notEmpty(topic) && TS.notEmpty(payload)) {
        if (topic == "casnic/ktlo") { return(self); } //noop
        ifEmit(wajv) {
          //log.log("in bam handlemessage for " + topic + " " + payload);
            if (mqttMode == "haRelay") {
              if (topic == "homeassistant/status" && payload == "online") {
                log.log("ha startedup");
                mqtt.close();
                mqtt = null;
                checkStartMqtt();
              } elseIf (topic.begins("homeassistant/switch/") && topic.ends("/set")) {
                log.log("ha switched");
                var ll = topic.split("/");
                String didpos = ll[2];
                log.log("ha got didpos " + didpos);
                var dp = didpos.split("-");
                Map mcmd = setDeviceSwMcmd(dp[0], dp[1], payload.lower());
                mcmd["runSync"] = true;
                sendDeviceMcmd(mcmd);
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
                  mcmd = setDeviceLvlMcmd(dp[0], dp[1], incmd.get("brightness").toString());
                  mcmd["runSync"] = true;
                  sendDeviceMcmd(mcmd);
                } elseIf (incmd.has("color")) {
                  Map rgb = incmd.get("color");
                  String rgbs = "" + rgb["r"] + "," + rgb["g"] + "," + rgb["b"];
                  mcmd = setDeviceRgbMcmd(dp[0], dp[1], rgbs);
                  mcmd["runSync"] = true;
                  sendDeviceMcmd(mcmd);
                } elseIf (incmd.has("color_temp")) {
                  mcmd = setDeviceTempMcmd(dp[0], dp[1], miredToLs(incmd.get("color_temp")).toString());
                  mcmd["runSync"] = true;
                  sendDeviceMcmd(mcmd);
                } elseIf (incmd.has("state")) {
                  mcmd = setDeviceSwMcmd(dp[0], dp[1], incmd.get("state").lower());
                  mcmd["runSync"] = true;
                  sendDeviceMcmd(mcmd);
                }
                stDiffed = true;
              }
            } elseIf (mqttMode == "relay" && topic == "casnic/cmds") {
              log.log("relay handlemessage for " + topic + " " + payload);
              System:Thread.new(System:Invocation.new(self, "handleRelay", Lists.from(topic, payload))).start()
            }
          }
          if ((mqttMode == "remote" || mqttMode == "fullRemote") && topic == "casnic/res/" + mqttReId) {
            if (TS.notEmpty(payload)) {
              log.log("got res in mqtt remote " + payload);
              Map mqres = Json:Unmarshaller.unmarshall(payload);
                if (def(currCmds) && TS.notEmpty(currCmds["iv"]) && TS.notEmpty(mqres["iv"]) && mqres["iv"] == currCmds["iv"]) {
                  log.log("res good, setting to creso");
                  currCmds["creso"].o = mqres["cres"];
                } else {
                  log.log("currCmds undef or preempted");
                }
            } else {
              log.log("empty payload in remote casnic/res");
            }
          }
        }
    }

    handleRelay(String topic, String payload) {
      Map mqcmd = Json:Unmarshaller.unmarshall(payload);
      if (TS.isEmpty(mqcmd["kdname"]) || TS.isEmpty(mqcmd["cmds"])) {
        log.log("missing kdname or cmds");
        return(self);
      }
      String kdaddr = getAddrDis(mqcmd["kdname"]);
      if (TS.isEmpty(kdaddr)) {
        log.log("no kdaddr for " + mqcmd["kdname"]);
        return(self);
      }
      String cres = prot.sendJvadCmds(kdaddr, mqcmd["cmds"] + "\r\n");
      if (TS.notEmpty(cres)) {
        log.log("relay cres " + cres);
        mqcmd["cres"] = cres;
        mqtt.publish("casnic/res/" + mqcmd["reid"], Json:Marshaller.marshall(mqcmd));
      } else {
        log.log("relay no cres");
      }
    }

    miredToLs(Int mr) Int {
      if (mr < 153 || mr > 500) { mr = 153; }
      Int mrb = mr - 153;
      Float mrbf = Float.intNew(mrb);
      Float fh = Float.intNew(347);
      Float mp = mrbf / fh;
      Float lsm = Float.intNew(255);
      Float lsf = mp * lsm;
      Int ls = lsf.toInt();
      return(ls);
    }

    lsToMired(Int ls) Int {
      if (ls < 0 || ls > 255) { ls = 255; }
      Float lsf = Float.intNew(ls);
      Float fh = Float.intNew(255);
      Float mp = lsf / fh;
      Float mrm = Float.intNew(347);
      Float mrf = mp * mrm;
      Int mr = mrf.toInt();
      mr = mr + 153;
      return(mr);
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
     
     openToUrlRequest(String url, request) {
      UI:ExternalBrowser.openToUrl(url);
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

      var hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
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
      var uhex = Hex.encode(account.user);
      var hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
      var hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
      var halv = app.kvdbs.get("HALV"); //halv - device id to lvl
      var haowns = app.kvdbs.get("HAOWNS"); //haowns - prefix account hex to map of owned device ids
      
      
       for (any kv in haowns.getMap(uhex + ".")) {
         String did = kv.value;
         String confs = hadevs.get(did);
         if (retnext) {
           //log.log("returning conf " + confs);
           return(CallBackUI.showDeviceConfigResponse(addFtype(confs), getCachedIp(confs)));
         }
         if (lastDid == did) {
           retnext = true;
         }
       }
       if (TS.notEmpty(confs)) {
         //log.log("returning conf " + confs);
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
        var haknc = app.kvdbs.get("HAKNC"); //kdname to addr
        String tkda = haknc.get(kdname);
        if (TS.notEmpty(tkda)) {
          kdaddr = tkda;
        }
      }
      return(kdaddr);
    }

    getAddr(String kdname) {
      String kdaddr;

     if (knc.has(kdname)) {
          kdaddr = knc.get(kdname);
     } else {
        String tkda = reloadAddr(kdname);
        if (TS.notEmpty(tkda)) {
          kdaddr = tkda;
        } else {
          resolveAddr(kdname);
        }
     }
     if (TS.notEmpty(kdaddr)) {
      //log.log("got kdaddr " + kdaddr + " for " + kdname);
    } else {
      log.log("got no kdaddr for " + kdname);
    }
      return(kdaddr);
    }

    reloadAddr(String kdname) String {
      var haknc = app.kvdbs.get("HAKNC"); //kdname to addr
      String tkda = haknc.get(kdname);
      if (TS.notEmpty(tkda)) {
          String kdaddr = tkda;
          knc.put(kdname, kdaddr);
      }
      return(kdaddr);
    }

    resolveAddr(String kdname) {
      String kdaddr;
       var haknc = app.kvdbs.get("HAKNC"); //kdname to addr
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
            discoverNow.o = true;
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

          ifNotEmit(apwk) {
            if (TS.notEmpty(kdaddr)) {
              haknc.put(kdname, kdaddr);
            }
          }
            ifEmit(apwk) {
               app.runAsync("CasCon", "goGetAddr", Lists.from(kdname));
            }

    }

    goGetAddr(String kdname) {
      app.configManager;
      var haknc = app.kvdbs.get("HAKNC"); //kdname to addr
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
     //log.log("kdname " + kdname);
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
     //log.log("in asr " + cx);
     log.log("in asr");
     clearCxRequest(request);
     String confs = Encode:Hex.decode(cx);
     Map conf = Json:Unmarshaller.unmarshall(confs);
     conf["id"] = System:Random.getString(11);
     String controlDef = conf["controlDef"];
     if (TS.notEmpty(controlDef)) {
       var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
       hactls.put(conf["id"], controlDef);
       conf.remove("controlDef");
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
   
   deleteDeviceRequest(String did, request) Map {
     log.log("in removeDeviceRequest " + did);
     
    Account account = request.context.get("account");
    var uhex = Hex.encode(account.user);
    var hadevs = app.kvdbs.get("HADEVS"); //hadevs - device aid to config
    var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
    var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
    var hasw = app.kvdbs.get("HASW"); //hasw - device aid to switch state
    var halv = app.kvdbs.get("HALV"); //halv - device aid to lvl
    var hacw = app.kvdbs.get("HACW"); //hargb - device id to rgb
    var hargb = app.kvdbs.get("HARGB"); //hargb - device id to rgb
    var haowns = app.kvdbs.get("HAOWNS"); //haowns - prefix account hex to map of owned device aids
    var haknc = app.kvdbs.get("HAKNC"); //kdname to addr
    
    String confs = hadevs.get(did);
    if (TS.notEmpty(confs)) {
      Map conf = Json:Unmarshaller.unmarshall(confs);
      //getting the name
      if (TS.notEmpty(conf["ondid"])) {
        String kdname = "CasNic" + conf["ondid"];
        haknc.remove(kdname);
      }
    }

    haowns.remove(uhex + "." + did);
    hadevs.remove(did);
    pdevices = null;

    String ctl = hactls.get(did);
    if (TS.notEmpty(ctl)) {
      var ctll = ctl.split(",");
      log.log("got ctl " + ctl);
      for (Int i = 1;i < ctll.length;i++) {
        hasw.remove(did + "-" + i);
        halv.remove(did + "-" + i);
        hargb.remove(did + "-" + i);
        hacw.remove(did + "-" + i);
      }
      hactls.remove(did);
      haspecs.remove(did);
    }
    return(CallBackUI.reloadResponse());
   }

   resetDeviceRequest(String did, request) Map {
     log.log("in resetDeviceRequest " + did);

     //not checking user rn

     //dostate eek setsw on e
     String cmds = "reset pass e";
     log.log("cmds " + cmds);

     //tcpjv edition

     //cmds += "\r\n";

     Map mcmd = Maps.from("prio", 1, "cb", "resetDeviceCb", "did", did, "pwt", 1, "cmds", cmds);

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

     var cmdl = cmdline.split(" ");
     Int pt = 0;
     if (cmdl.length > 1) {
       if (cmdl[1] == "pass") {
         pt = 1;
       } elseIf (cmdl[1] == "spass") {
         pt = 2;
       }
     }

     //dostate eek setsw on e
     String cmds = cmdline;
     //log.log("cmds " + cmds);

     //tcpjv edition

     //cmds += "\r\n";

     Map mcmd = Maps.from("prio", 1, "cb", "sendDeviceCommandCb", "did", did, "pwt", pt, "cmds", cmds);

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
     //log.log("in addDeviceRequest " + confs);
     log.log("in saveDeviceRequest");
     
     Account account = request.context.get("account");
     var uhex = Hex.encode(account.user);
     var hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     //var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
     //var hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     //var halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     var haowns = app.kvdbs.get("HAOWNS"); //haowns - prefix account hex to map of owned device ids
     
     //String did = System:Random.getString(16);
     


     hadevs.put(did, confs);
     haowns.put(uhex + "." + did, did);
     pdevices = null;
     
     return(CallBackUI.reloadResponse());
   }

   loadWifiRequest(request) Map {
     Account account = request.context.get("account");
     var uhex = Hex.encode(account.user);
     var hawifi = app.kvdbs.get("HAWIFI"); //account hex to wifi network

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

   loadMqttModeRequest(request) Map {
     //app.configManager.remove("mqtt.mode"); return(null);
     String mqttMode = app.configManager.get("mqtt.mode");
     if (TS.isEmpty(mqttMode)) { mqttMode = "remote"; }
     return(CallBackUI.mqttModeResponse(mqttMode));
   }

   saveWifiRequest(String ssid, String sec, Bool reloadAfter, request) Map {

     Account account = request.context.get("account");
     var uhex = Hex.encode(account.user);
     var hawifi = app.kvdbs.get("HAWIFI"); //account hex to wifi network

     if (TS.notEmpty(ssid) && TS.notEmpty(sec)) {
      hawifi.put(uhex + ".ssid.0", ssid);
      hawifi.put(uhex + ".sec.0", sec);
      //log.log("saved " + ssid + " " + sec + " for wifi for user hex " + uhex);
     } elseIf (TS.isEmpty(ssid) && TS.isEmpty(sec)) {
      hawifi.remove(uhex + ".ssid.0");
      hawifi.remove(uhex + ".sec.0");
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
      app.configManager.remove("mqtt.broker");
      app.configManager.remove("mqtt.user");
      app.configManager.remove("mqtt.pass");
      log.log("cleared mqtt");
     }
     if (TS.isEmpty(mqttMode)) { String mqttMode = "haRelay"; }
     app.configManager.put("mqtt.mode", mqttMode);
     self.mqttMode = mqttMode;
     log.log("set mqttMode " + mqttMode);
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
     var uhex = Hex.encode(account.user);
     var hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
     var hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     var halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     var hargb = app.kvdbs.get("HARGB"); //hargb - device id to rgb
     var hacw = app.kvdbs.get("HACW");
     var haowns = app.kvdbs.get("HAOWNS"); //haowns - prefix account hex to map of owned device ids
     var haof = app.kvdbs.get("HAOF"); //haof - device id pos to oif
     Map devices = Map.new();
     Map ctls = Map.new();
     Map states = Map.new();
     Map levels = Map.new();
     Map rgbs = Map.new();
     Map cws = Map.new();
     Map oifs = Map.new();
     for (any kv in haowns.getMap(uhex + ".")) {
       String did = kv.value;
       String confs = hadevs.get(did);
       devices.put(did, confs);
       String ctl = hactls.get(did);
       if (TS.notEmpty(ctl)) {
         ctls.put(did, ctl);
        var ctll = ctl.split(",");
        log.log("got ctl " + ctl);
        for (Int i = 1;i < ctll.length;i++) {
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
          log.log("getting oif for " + did + "-" + i);
          String oif = haof.get(did + "-" + i);
          if (TS.notEmpty(oif)) {
            log.log("got oif " + oif);
            oifs.put(did + "-" + i, oif);
          }
        }
       }
     }
     if (def(nextInform)) {
       Int nsecs = nextInform.seconds;
     } else {
       nsecs = 0;
     }
     return(CallBackUI.getDevicesResponse(devices, ctls, states, levels, rgbs, cws, oifs, nsecs));
   }

   updateSpec(String did) {
    log.log("in updateSpec " + did);

    String cmds = "doswspec spass e";
    //log.log("cmds " + cmds);

    Map mcmd = Maps.from("prio", 3, "cb", "updateSpecCb", "did", did, "pwt", 2, "cmds", cmds);

    if (backgroundPulse) {
      mcmd["runSync"] = true;
    }
    sendDeviceMcmd(mcmd);

    return(null);
   }

   updateSpecCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String did = mcmd["did"];
     var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
     var hadevs = app.kvdbs.get("HADEVS");
     if (TS.notEmpty(cres)) {
        log.log("got dospec " + cres);
        pdevices = null;
        if (cres.begins("controldef")) {
          log.log("pre swspec");
          haspecs.put(did, "1,p2.gsh.4");
        } elseIf (cres.has("p2.")) {
          log.log("got swspec");
          haspecs.put(did, cres);
          var sl = cres.split(".");
          String dt = sl[1];
          String confs = hadevs.get(did);
          Map conf = Json:Unmarshaller.unmarshall(confs);
          conf["type"] = dt;
          confs = Json:Marshaller.marshall(conf);
          hadevs.put(did, confs);
          if (def(request)) {
            return(CallBackUI.reloadResponse());
          }
        } else {
          log.log("swspec got nonsense, doing default");
          haspecs.put(did, "1,p2.gsh.4");
        }
      }
      return(null);
   }

   getSecQ(Map conf) {
     slots {
       Map secQs;
     }
     if (undef(secQs)) { secQs = Map.new(); }
     String did = conf["ondid"];
     String spass = conf["spass"];
     if (secQs.has(did)) { return(secQs[did]); }
     if (TS.notEmpty(did) && TS.notEmpty(spass)) {
       String tosec = spass.substring(0, 8) + did;
       String sq = prot.sha1hex(tosec).substring(0, 12);
     } else {
       sq = "Q";
     }
     secQs.put(did, sq);
     return(sq);
   }

   getLastEvents(String confs) {
     //log.log("in getLastEvents");

     try {
       Map conf = Json:Unmarshaller.unmarshall(confs);
     } catch (any e) {
       log.elog("error in gle", e);
       return(null);
     }
     String cmds = "getlastevents q e";
     //log.log("cmds " + cmds);

     Map mcmd = Maps.from("prio", 5, "cb", "getLastEventsCb", "did", conf["id"], "pwt", 3, "cmds", cmds);
     if (System:Random.getIntMax(10) > 7) {
       //in case something was remote or offline, every once in a while try local to see if back to local net
       //mcmd["forceLocal"] = true;
     }
     mcmd["skipIfRemote"] = true;

     if (backgroundPulse) {
       mcmd["runSync"] = true;
     }
     sendDeviceMcmd(mcmd);

     return(null);
   }

   getLastEventsCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String leid = mcmd["did"];
     if (TS.notEmpty(cres) && cres.has(";")) {
        if (TS.notEmpty(mcmd["kdaddr"]) && remoteAddrs.has(mcmd["kdaddr"])) {
          log.log("clearing kdaddr from remoteAddrs");
          remoteAddrs.remove(mcmd["kdaddr"]);
        }
        //log.log("getlastevents cres |" + cres + "|");
        String ores = currentEvents.get(leid);
        if (TS.notEmpty(ores)) {
          if (cres != ores) {
            var ol = ores.split(";");
            var cl = cres.split(";");
            if (ol.length == cl.length) {
              for (Int i = 0;i < cl.length;i++) {
                String ci = cl.get(i);
                String oi = ol.get(i);
                if (TS.notEmpty(ci) && TS.notEmpty(oi) && ci != oi) {
                  log.log("found diffed events " + ci + " " + oi);
                  var de = ci.split(",");
                  if (def(pendingStateUpdates)) {
                    Int pos = Int.new(de.get(1));
                    pos++;
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
          for (i = 0;i < cl.length;i++) {
            ci = cl.get(i);
            if (TS.notEmpty(ci)) {
              log.log("found new events " + ci);
              de = ci.split(",");
              if (def(pendingStateUpdates)) {
                pos = Int.new(de.get(1));
                pos++;
                psu = de.get(0) + "," + leid + "," + pos;
                pendingStateUpdates += psu;
              }
            }
          }
        }
        currentEvents.put(leid, cres);
      } else {
        //log.log("getlastevents cres empty");
      }
     return(null);
   }

   updateSwState(String did, Int dp, String cname) {
     log.log("in updateSwState " + did + " " + dp);

     var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
     String ctl = hactls.get(did);
     var ctll = ctl.split(",");
     String itype = ctll.get(dp);

     //dostate eek setsw on e
     Int dpd = dp - 1;

     //tcpjv edition

     //cmds += "\r\n";
     var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
     String sws = haspecs.get(did);
     if (TS.notEmpty(sws) && sws.has("q,")) {
       cmds = "dostate q " + dpd + " getsw e";
       //log.log("cmds " + cmds);
       mcmd = Maps.from("prio", 4, "mw", 5, "cb", "updateSwStateCb", "did", did, "dp", dp, "pwt", 3, "itype", itype, "cname", cname, "cmds", cmds);
     } else {
       String cmds = "dostate spass " + dpd + " getsw e";
       //log.log("cmds " + cmds);
       Map mcmd = Maps.from("prio", 4, "mw", 5, "cb", "updateSwStateCb", "did", did, "dp", dp, "pwt", 2, "itype", itype, "cname", cname, "cmds", cmds);
     }

     if (backgroundPulse) {
       mcmd["runSync"] = true;
     }
     sendDeviceMcmd(mcmd);

     return(null);
   }

   updateSwStateCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String did = mcmd["did"];
     String itype = mcmd["itype"];
     Int dp = mcmd["dp"];
     var hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     if (TS.notEmpty(cres)) {
        log.log("got getsw " + cres);
        unless (cres.has("undefined")) {
          String cset = hasw.get(did + "-" + dp);
          if (TS.isEmpty(cset) || cset != cres) {
            hasw.put(did + "-" + dp, cres);
            stDiffed = true;
            ifEmit(wajv) {
              if (def(mqtt) && mqttMode == "haRelay") {
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
                  } elseIf (itype == "rgbgdim" || itype == "rgbcwgd" || itype == "rgbcwsgd") {
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

      var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
      String ctl = hactls.get(did);
      var ctll = ctl.split(",");
      String itype = ctll.get(dp);

      //dostate eek setsw on e
      Int dpd = dp - 1;

      var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
      String sws = haspecs.get(did);
      if (TS.notEmpty(sws) && sws.has("q,")) {
        if (itype == "rgbgdim" || itype == "rgbcwgd" || itype == "rgbcwsgd") {
          cmds = "getstatexd q " + dpd + " e";
        } else {
          cmds = "dostate q " + dpd + " getrgb e";
        }
        //log.log("cmds " + cmds);
        mcmd = Maps.from("prio", 4, "mw", 5, "cb", "updateRgbStateCb", "did", did, "dp", dp, "pwt", 3, "itype", itype, "cname", cname, "cmds", cmds);
      } else {
        if (itype == "rgbgdim" || itype == "rgbcwgd" || itype == "rgbcwsgd") {
          cmds = "getstatexd spass " + dpd + " e";
        } else {
        String cmds = "dostate spass " + dpd + " getrgb e";
        }
        //log.log("cmds " + cmds);
        Map mcmd = Maps.from("prio", 4, "mw", 5, "cb", "updateRgbStateCb", "did", did, "dp", dp, "pwt", 2, "itype", itype, "cname", cname, "cmds", cmds);
      }

      if (backgroundPulse) {
        mcmd["runSync"] = true;
      }
      sendDeviceMcmd(mcmd);

      return(null);
   }

   updateRgbStateCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String did = mcmd["did"];
     String itype = mcmd["itype"];
     Int dp = mcmd["dp"];
     var hargb = app.kvdbs.get("HARGB"); //hargb - device id to rgb
     var hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     var halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     var hacw = app.kvdbs.get("HACW");

     if (TS.notEmpty(cres)) {
        log.log("got getrgb " + cres);
        unless (cres.has("undefined")) {
          if (cres.has(",")) {
            if (itype == "rgbgdim" || itype == "rgbcwgd" || itype == "rgbcwsgd") {
              var crl = cres.split(",");
              cres = crl[0] + "," + crl[1] + "," + crl[2];
              String lv = crl[3];
              String lvl = halv.get(did + "-" + dp);
              if (TS.isEmpty(lvl) || lvl != lv) {
                log.log("got lvl change in rgb update");
                halv.put(did + "-" + dp, lv);
                stDiffed = true;
              }
              if (itype == "rgbcwgd" || itype == "rgbcwsgd") {
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
              if (def(mqtt) && mqttMode == "haRelay") {
                Map dps = Map.new();
                String st = hasw.get(did + "-" + dp);
                if (TS.notEmpty(st)) {
                  dps.put("state", st.upper());
                } else {
                  dps.put("state", "OFF");
                }
                if (itype == "rgbgdim" || itype == "rgbcwgd" || itype == "rgbcwsgd") {
                  dps.put("brightness", Int.new(lv));
                  if (itype == "rgbcwgd" || itype == "rgbcwsgd") {
                    if (TS.notEmpty(cw)) {
                       dps.put("color_temp", lsToMired(Int.new(cw)));
                    }
                  }
                }
                var rgbl = cres.split(",");
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

   updateTempState(String did, Int dp, String cname) {
      log.log("in updateRgbState " + did + " " + dp);

      var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
      String ctl = hactls.get(did);
      var ctll = ctl.split(",");
      String itype = ctll.get(dp);

      //dostate eek setsw on e
      Int dpd = dp - 1;

      var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
      String sws = haspecs.get(did);
      if (TS.notEmpty(sws) && sws.has("q,")) {
        String cmds = "getstatexd q " + dpd + " e";
        //log.log("cmds " + cmds);
        Map mcmd = Maps.from("prio", 4, "mw", 5, "cb", "updateTempStateCb", "did", did, "dp", dp, "pwt", 3, "itype", itype, "cname", cname, "cmds", cmds);
      } else {
        cmds = "getstatexd spass " + dpd + " e";
        //log.log("cmds " + cmds);
        mcmd = Maps.from("prio", 4, "mw", 5, "cb", "updateTempStateCb", "did", did, "dp", dp, "pwt", 2, "itype", itype, "cname", cname, "cmds", cmds);
      }

      if (backgroundPulse) {
        mcmd["runSync"] = true;
      }
      sendDeviceMcmd(mcmd);

      return(null);
   }



   updateTempStateCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String did = mcmd["did"];
     String itype = mcmd["itype"];
     Int dp = mcmd["dp"];
     var hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     var halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     var hacw = app.kvdbs.get("HACW");

     if (TS.notEmpty(cres)) {
        log.log("got gettemp " + cres);
        unless (cres.has("undefined")) {
          if (cres.has(",")) {
            if (itype == "cwgd") {
              var crl = cres.split(",");
              String lv = crl[1];
              String lvl = halv.get(did + "-" + dp);
              if (TS.isEmpty(lvl) || lvl != lv) {
                log.log("got lvl change in rgb update");
                halv.put(did + "-" + dp, lv);
                stDiffed = true;
              }
              String cw = crl[0];
              String ocw = hacw.get(did + "-" + dp);
              if (TS.isEmpty(ocw) || ocw != cw) {
                log.log("got cw change in rgb update");
                hacw.put(did + "-" + dp, cw);
                stDiffed = true;
              }
            }
            ifEmit(wajv) {
              if (def(mqtt) && mqttMode == "haRelay") {
                Map dps = Map.new();
                String st = hasw.get(did + "-" + dp);
                if (TS.notEmpty(st)) {
                  dps.put("state", st.upper());
                } else {
                  dps.put("state", "OFF");
                }
                if (itype == "cwgd") {
                  dps.put("brightness", Int.new(lv));
                  dps.put("color_temp", lsToMired(Int.new(cw)));
                }
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

      var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
      String ctl = hactls.get(did);
      var ctll = ctl.split(",");
      String itype = ctll.get(dp);

      //dostate eek setsw on e
      Int dpd = dp - 1;

      var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
      String sws = haspecs.get(did);
      if (TS.notEmpty(sws) && sws.has("q,")) {
        if (itype == "gdim") {
        cmds = "getstatexd q " + dpd + " e";
        } else {
        cmds = "dostate q " + dpd + " getlvl e";
        }
        //log.log("cmds " + cmds);
        mcmd = Maps.from("prio", 4, "mw", 5, "cb", "updateLvlStateCb", "did", did, "dp", dp, "pwt", 3, "itype", itype, "itype", itype, "cname", cname, "cmds", cmds);
      } else {
        if (itype == "gdim") {
          cmds = "getstatexd spass " + dpd + " e";
        } else {
          String cmds = "dostate spass " + dpd + " getlvl e";
        }
        //log.log("cmds " + cmds);
        Map mcmd = Maps.from("prio", 4, "mw", 5, "cb", "updateLvlStateCb", "did", did, "dp", dp, "pwt", 2, "itype", itype, "cname", cname, "cmds", cmds);
      }

      if (backgroundPulse) {
        mcmd["runSync"] = true;
      }
      sendDeviceMcmd(mcmd);

      return(null);
   }

   updateLvlStateCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String did = mcmd["did"];
     Int dp = mcmd["dp"];
     String itype = mcmd["itype"];
     var hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     var halv = app.kvdbs.get("HALV"); //halv - device id to lvl
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
            if (def(mqtt) && mqttMode == "haRelay") {
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

   updateOifState(String did, Int dp, String cname) {
      log.log("in updateOifState " + did + " " + dp);

      var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
      String ctl = hactls.get(did);
      var ctll = ctl.split(",");
      String itype = ctll.get(dp);

      //dostate eek setsw on e
      Int dpd = dp - 1;

      var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
      String sws = haspecs.get(did);
      if (TS.notEmpty(sws) && sws.has("q,")) {
        cmds = "dostate q " + dpd + " getoif e";
        //log.log("cmds " + cmds);
        mcmd = Maps.from("prio", 4, "mw", 5, "cb", "updateOifStateCb", "did", did, "dp", dp, "pwt", 3, "itype", itype, "cname", cname, "cmds", cmds);
      } else {
        String cmds = "dostate spass " + dpd + " getoif e";
        //log.log("cmds " + cmds);
        Map mcmd = Maps.from("prio", 4, "mw", 5, "cb", "updateOifStateCb", "did", did, "dp", dp, "pwt", 2, "itype", itype, "cname", cname, "cmds", cmds);
      }

      if (backgroundPulse) {
        mcmd["runSync"] = true;
      }
      sendDeviceMcmd(mcmd);

      return(null);
   }

   updateOifStateCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String did = mcmd["did"];
     Int dp = mcmd["dp"];
     String itype = mcmd["itype"];
     var haof = app.kvdbs.get("HAOF"); //haof - device id pos to oif
     if (TS.notEmpty(cres)) {
        log.log("got getoif " + cres);
        unless (cres.has("undefined")) {
          String cset = haof.get(did + "-" + dp);
          if (TS.notEmpty(cset)) {
            if (cset != cres) {
              haof.put(did + "-" + dp, cres);
              stDiffed = true;
            }
          } else {
            haof.put(did + "-" + dp, cres);
            stDiffed = true;
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
     if (backgroundPulse) {
      log.log("disabling backgroundPulse");
      backgroundPulse = false;
     }

     ifEmit(wajv) {
      slots {
        Int pulseCheck = Time:Interval.now().seconds;
      }
     }

     if (TS.notEmpty(lastError)) {
       String lastErrorL = lastError;
       lastError = null;
       throw(Alert.new(lastErrorL));
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
                unless (backgroundPulse) {
                  log.log("enabling backgroundPulse");
                  backgroundPulse = backgroundPulseOnIdle;
                }
              }
            } else {
              if (Time:Interval.now().seconds - pulseCheck > 5) {
                if (backgroundPulseOnIdle) {
                  unless (backgroundPulse) {
                    log.log("enabling backgroundPulse");
                    backgroundPulse = backgroundPulseOnIdle;
                  }
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
       Map pspecs; //haspecs cpy
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
     pcount++;
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
       var hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
       pdevices = hadevs.getMap();
       var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
       pspecs = haspecs.getMap();
     }

     if (pcount % 2 == 0) {
      Set toDel = Set.new();
      if (def(pendingStateUpdates)) {
        for (any k in pendingStateUpdates) {
            if (TS.notEmpty(k)) {
              try {
                log.log("doing updateXState for " + k);
                var ks = k.split(",");
                if (ks[0] == "sw") {
                  updateSwState(ks[1], Int.new(ks[2]), ks[0]);
                } elseIf (ks[0] == "dim" || ks[0] == "gdim") {
                  updateSwState(ks[1], Int.new(ks[2]), ks[0]);
                  updateLvlState(ks[1], Int.new(ks[2]), ks[0]);
                } elseIf (ks[0] == "pwm") {
                  updateLvlState(ks[1], Int.new(ks[2]), ks[0]);
                } elseIf (ks[0] == "rgb" || ks[0] == "rgbgdim" || ks[0] == "rgbcwgd" || ks[0] == "rgbcwsgd") {
                  updateSwState(ks[1], Int.new(ks[2]), ks[0]);
                  updateRgbState(ks[1], Int.new(ks[2]), ks[0]);
                } elseIf (ks[0] == "cwgd") {
                  updateSwState(ks[1], Int.new(ks[2]), ks[0]);
                  updateTempState(ks[1], Int.new(ks[2]), ks[0]);
                } elseIf (ks[0] == "oui") {
                  updateOifState(ks[1], Int.new(ks[2]), ks[0]);
                  //updateOuiState(ks[1], Int.new(ks[2]), ks[0]);
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
          pendingStateUpdates.remove(k);
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
         pendingSpecs.remove(spk);
         return(null);
       }
     }

      Map lpd = pdevices;
      Map lpc = pdcount;
      if (def(lpd) && def (lpc)) {
        for (var pdc in pdevices) {
          Int dc = pdcount.get(pdc.key);
          if (undef(dc) || dc < pcount) {
            dc = pcount + 16 + System:Random.getIntMax(16); //(secs * 4 + rand secs up to 4), was 16 both
            pdcount.put(pdc.key, dc);
            Map conf = Json:Unmarshaller.unmarshall(pdc.value);
            String did = conf["id"];
            if (TS.notEmpty(did) && pspecs.has(did) && pspecs.get(did) != "1.p4,p2.phx.4") {
              getLastEvents(pdc.value);
              break;
            } elseIf (TS.notEmpty(did)) {
              pendingSpecs.put(did);
            }
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
                //if (!InitializeResolveListener.knownDevices.containsKey(sname)) {
                  InitializeResolveListener.resolving.put(sname, service);
                  InitializeResolveListener.maybeResolve();
                //}
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

   updateWifiRequest(String did, request) Map {
     log.log("in updateWifiRequest " + did);

     Account account = request.context.get("account");
     var uhex = Hex.encode(account.user);

     var hawifi = app.kvdbs.get("HAWIFI"); //account hex to wifi network
     String devSsid = Hex.encode(hawifi.get(uhex + ".ssid.0"));
     String devSec = Hex.encode(hawifi.get(uhex + ".sec.0"));

     String cmds = "setwifi pass hex " + devSsid + " " + devSec + " e";

     //tcpjv edition

     //cmds += "\r\n";

     Map mcmd = Maps.from("prio", 2, "cb", "updateWifiCb", "did", did, "pwt", 1, "cmds", cmds);
     sendDeviceMcmd(mcmd);

     return(null);
   }

   updateWifiCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String did = mcmd["did"];
     if (TS.notEmpty(cres)) {
        log.log("got cres " + cres);
      }
      if (def(request)) {
        return(CallBackUI.reloadResponse());
      }
      return(null);
   }

   shdefCb(Map mcmd, request) Map {
     String cress = mcmd["cres"];
     if (TS.notEmpty(cress)) {
      log.log("got cress in shdefCb " + cress);
      if (cress.begins("shdef:")) {
        var cres = cress.split(":");
        //have it all, make and save, put in for controldef

        Map conf = Map.new();
        conf["type"] = cres[1];
        conf["id"] = System:Random.getString(11);
        conf["ondid"] = cres[2];
        conf["name"] = Hex.decode(cres[5]);
        conf["pass"] = cres[3];
        conf["spass"] = cres[4];
        String confs = Json:Marshaller.marshall(conf);
        saveDeviceRequest(conf["id"], confs, request);
        rectlDeviceRequest(conf["id"], request);
      } else {
        throw(Alert.new("Unable to receive share info.  Get a new share code and try again."));
      }
     } else {
       throw(Alert.new("Unable to receive share info.  Make sure this device is on the same wifi network as the device you are sharing to it."));
     }
     return(null);
   }

   restartDevRequest(String did, request) Map {
     log.log("in restartDevRequest " + did);

     String cmds = "restart pass e";

     //tcpjv edition

     //cmds += "\r\n";

     Map mcmd = Maps.from("prio", 2, "cb", "restartDevCb", "did", did, "pwt", 1, "cmds", cmds);
     sendDeviceMcmd(mcmd);

     return(null);
   }

   restartDevCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String did = mcmd["did"];
     if (TS.notEmpty(cres)) {
        log.log("got cres " + cres);
      }
      if (def(request)) {
        return(CallBackUI.reloadResponse());
      }
      return(null);
   }

   rectlDeviceRequest(String did, request) Map {
     log.log("in rectlDeviceRequest " + did);

     //dostate eek setsw on e
     String cmds = "getcontroldef spass e";
     //log.log("cmds " + cmds);

     //tcpjv edition

     //cmds += "\r\n";

     Map mcmd = Maps.from("prio", 2, "cb", "rectlDeviceCb", "did", did, "pwt", 2, "cmds", cmds);
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
        var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
        hactls.put(did, controlDef);
        ifEmit(wajv) {
          if (def(mqtt)) {
            mqtt.close();
            mqtt = null;
          }
          checkStartMqtt();
        }
      }
      //if (def(request)) {
      //  return(CallBackUI.reloadResponse());
      //}
      updateSpec(did);
      return(null);
   }

   //callApp('devActRequest', 'setSw', 'IDOFDEVICE', 'POSOFDEVICE', document.getElementById('hatIDOFDEVICE-POSOFDEVICE').checked);
   devActRequest(String aType, String rhan, String rpos, String rstate, request) Map {
     log.log("in devActRequest " + aType + " " + rhan + " " + rpos + " " + rstate);

     Map mcmd;

     if (aType == "setSw") {
      mcmd = setDeviceSwMcmd(rhan, rpos, rstate);
     } elseIf (aType == "setLvl") {
      mcmd = setDeviceLvlMcmd(rhan, rpos, rstate);
     } elseIf (aType == "setTemp") {
      mcmd = setDeviceTempMcmd(rhan, rpos, rstate);
     } elseIf (aType == "setRgb") {
      mcmd = setDeviceRgbMcmd(rhan, rpos, rstate);
     }

     if (sendDeviceMcmd(mcmd)!) {
       if (def(request)) {
         return(CallBackUI.setElementsDisplaysResponse(Maps.from("devErr", "block")));
       }
     } else {
       if (def(request)) {
         return(CallBackUI.setElementsDisplaysResponse(Maps.from("devErr", "none")));
       }
     }
     return(null);
   }

   setDeviceSwMcmd(String did, String iposs, String state) Map {
     var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef

     Int ipos = Int.new(iposs);

     String ctl = hactls.get(did);
     var ctll = ctl.split(",");
     String itype = ctll.get(ipos);

     ipos--;

     //dostate eek setsw on e
     String cmds = "dostate spass " + ipos + " setsw " + state + " e";
     //log.log("cmds " + cmds);

     //tcpjv edition

     //cmds += "\r\n";

     Map mcmd = Maps.from("prio", 0, "cb", "setDeviceSwCb", "did", did, "rhan", did, "rpos", iposs, "rstate", state, "pwt", 2, "itype", itype, "cmds", cmds);
     return(mcmd);

   }

   setDeviceSwCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String rhan = mcmd["rhan"];
     String rpos = mcmd["rpos"];
     String rstate = mcmd["rstate"];
     String itype = mcmd["itype"];
     var hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     if (TS.notEmpty(cres) && cres.has("ok")) {
       hasw.put(rhan + "-" + rpos, rstate);
       ifEmit(wajv) {
        if (def(mqtt) && mqttMode == "haRelay") {
          if (TS.notEmpty(itype)) {
            if (itype == "sw") {
              String stpp = "homeassistant/switch/" + rhan + "-" + rpos + "/state";
              mqtt.publish(stpp, rstate.upper());
            } elseIf (itype == "dim" || itype == "gdim" || itype == "rgb" || itype == "rgbgdim" || itype == "rgbcwgd" || itype == "rgbcwsgd" || itype == "cwgd") {
              Map dps = Map.new();
              dps.put("state", rstate.upper());
              stpp = "homeassistant/light/" + rhan + "-" + rpos + "/state";
              mqtt.publish(stpp, Json:Marshaller.marshall(dps));
            }
          }
        }
       }
     } else {
       if (def(request)) {
         stDiffed = true;
         return(CallBackUI.setElementsDisplaysResponse(Maps.from("devErr", "block")));
        }
     }
     stDiffed = true;
     return(null);
   }

   setDeviceRgbMcmd(String rhan, String rposs, String rgb) Map {

     var halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     var hacw = app.kvdbs.get("HACW");
     var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef

     Int rpos = Int.new(rposs);

     String rhanpos = rhan + "-" + rposs;

     String ctl = hactls.get(rhan);
     var ctll = ctl.split(",");
     String itype = ctll.get(rpos);

     rpos--;

     if (itype == "rgbgdim" || itype == "rgbcwgd" || itype == "rgbcwsgd") {
       String lv = halv.get(rhanpos);
       if (TS.isEmpty(lv)) { lv = "255"; }
       Int gamd = Int.new(lv);
       gamd = gamma(gamd);
       String gamds = gamd.toString();
       String frgb = rgbForRgbLvl(rgb, gamds);
       String xd = rgb + "," + lv;
       if (itype == "rgbcwgd" || itype == "rgbcwsgd") {
         if (frgb == "255,255,255") {
           String cw = "0";
         } else {
           cw = "127";
         }
         if (itype == "rgbcwsgd") {
          frgb += "," += cwForCwsLvl(cw, gamds);
         } else {
          frgb += "," += cwForCwLvl(cw, gamds);
         }
         xd += "," += cw;
         String setcmd = " setrgbcw ";
       } else {
         setcmd = " setrgb ";
       }
       cmds = "dostatexd spass " + rpos.toString() + setcmd + frgb + " " + xd + " e";
     } else {
       String cmds = "dostate spass " + rpos.toString() + " setrgb " + rgb + " e";
     }

     //log.log("cmds " + cmds);

     //tcpjv edition

     //cmds += "\r\n";

     Map mcmd = Maps.from("prio", 0, "cb", "setDeviceRgbCb", "did", rhan, "rhanpos", rhanpos, "rgb", rgb, "pwt", 2, "itype", itype, "cmds", cmds);
     if (itype == "rgbgdim" || itype == "rgbcwgd" || itype == "rgbcwsgd") {
       mcmd.put("lv", lv);
       if (itype == "rgbcwgd" || itype == "rgbcwsgd") {
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
     var hargb = app.kvdbs.get("HARGB"); //hargb - device id to rgb
     var hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     var hacw = app.kvdbs.get("HACW");
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
        if (def(mqtt) && mqttMode == "haRelay") {
          if (TS.notEmpty(itype)) {
            if (itype == "rgb" || itype == "rgbgdim") {
              var rgbl = rgb.split(",");
              Map rgbm = Maps.from("r", Int.new(rgbl[0]), "g", Int.new(rgbl[1]), "b", Int.new(rgbl[2]));
              Map dps = Map.new();
              dps.put("state", "ON");
              dps.put("color", rgbm);
              if (itype == "rgbgdim" || itype == "rgbcwgd" || itype == "rgbcwsgd") {
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
         stDiffed = true;
         return(CallBackUI.setElementsDisplaysResponse(Maps.from("devErr", "block")));
        }
     }
     stDiffed = true;
     return(null);
   }

   setDeviceTempMcmd(String rhan, String rposs, String rstate) Map {

     var halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
     var hargb = app.kvdbs.get("HARGB"); //hargb - device id to rgb
     var hacw = app.kvdbs.get("HACW"); //hargb - device id to rgb

     Int rpos = Int.new(rposs);

     String rhanpos = rhan + "-" + rposs;

     String ctl = hactls.get(rhan);
     var ctll = ctl.split(",");
     String itype = ctll.get(rpos);

     rpos--;

     String ocw = rstate;

     if (itype == "cwgd" || itype == "rgbcwgd" || itype == "rgbcwsgd") {
       String lv = halv.get(rhanpos);
       if (TS.isEmpty(lv)) { lv = "255"; }
       Int gamd = Int.new(lv);
       gamd = gamma(gamd);
       String gamds = gamd.toString();
       log.log("ocw " + ocw);
       if (itype == "rgbcwsgd") {
        fcw = cwForCwsLvl(ocw, gamds);
       } else {
        String fcw = cwForCwLvl(ocw, gamds);
       }
       if (itype == "rgbcwgd" || itype == "rgbcwsgd") {
         String orgb = "255,255,255";
         fcw = orgb + "," + fcw;
         String xd = orgb + "," + lv + "," + rstate;
         String setcmd = " setrgbcw ";
       } else {
         setcmd = " setcw ";
         xd = ocw + "," + lv;
       }
       log.log("fcw " + fcw);
       String cmds = "dostatexd spass " + rpos.toString() + setcmd + fcw + " " + xd + " e";
     }
     //log.log("cmds " + cmds);

     Map mcmd = Maps.from("prio", 0, "cb", "setDeviceTempCb", "did", rhan, "rhanpos", rhanpos, "cw", rstate, "pwt", 2, "itype", itype, "cmds", cmds);
     if (itype == "rgbcwgd" || itype == "rgbcwsgd") {
       mcmd.put("rgb", orgb);
     }
     if (TS.notEmpty(lv)) {
       mcmd.put("lv", lv);
     }

     return(mcmd);
   }

   setDeviceTempCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String rhanpos = mcmd["rhanpos"];
     String cw = mcmd["cw"];
     String itype = mcmd["itype"];
     var hacw = app.kvdbs.get("HACW"); //hargb - device id to rgb
     var hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     var hargb = app.kvdbs.get("HARGB"); //hargb - device id to rgb
     if (TS.notEmpty(cres) && cres.has("ok")) {
       //Map tb = trueRgb(rgb);
       //rgb = "" + tb["r"] + "," + tb["g"] + "," + tb["b"];
       log.log("hacw putting " + rhanpos + " " + cw);
       hacw.put(rhanpos, cw);
       hasw.put(rhanpos, "on");
       if (TS.notEmpty(mcmd["rgb"])) {
         hargb.put(rhanpos, mcmd["rgb"]);
       }
       ifEmit(wajv) {
        if (def(mqtt) && mqttMode == "haRelay") {
          if (TS.notEmpty(itype)) {
            if (itype == "rgbcwgd" || itype == "rgbcwsgd" || itype == "cwgd") {
              Map dps = Map.new();
              dps.put("state", "ON");
              if (TS.notEmpty(mcmd["lv"])) {
                dps.put("brightness", Int.new(mcmd["lv"]));
              }
              if (TS.notEmpty(cw)) {
                dps.put("color_temp", lsToMired(Int.new(cw)));
              }
              if (TS.notEmpty(mcmd["rgb"])) {
                var rgbl = mcmd.get("rgb").split(",");
                Map rgbm = Maps.from("r", Int.new(rgbl[0]), "g", Int.new(rgbl[1]), "b", Int.new(rgbl[2]));
                dps.put("color", rgbm);
              }
              String stpp = "homeassistant/light/" + rhanpos + "/state";
              mqtt.publish(stpp, Json:Marshaller.marshall(dps));
            }
          }
        }
       }
    } else {
       if (def(request)) {
         stDiffed = true;
         return(CallBackUI.setElementsDisplaysResponse(Maps.from("devErr", "block")));
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

   setDeviceLvlMcmd(String rhan, String rposs, String rstate) Map {

     var halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
     var hargb = app.kvdbs.get("HARGB"); //hargb - device id to rgb
     var hacw = app.kvdbs.get("HACW"); //hargb - device id to rgb

     Int rpos = Int.new(rposs);

     String rhanpos = rhan + "-" + rposs;

     String ctl = hactls.get(rhan);
     var ctll = ctl.split(",");
     String itype = ctll.get(rpos);

     rpos--;

     Int gamd = Int.new(rstate);
     gamd = gamma(gamd);
     String gamds = gamd.toString();

     if (itype == "gdim") {
       cmds = "dostatexd spass " + rpos.toString() + " setlvl " + gamds + " " + rstate + " e";
     } elseIf (itype == "rgbgdim" || itype == "rgbcwgd" || itype == "rgbcwsgd") {
       String orgb = hargb.get(rhanpos);
       if (TS.isEmpty(orgb)) {
         orgb = "255,255,255";
       }
       gamd = Int.new(rstate);
       gamd = gamma(gamd);
       gamds = gamd.toString();
       if (itype == "rgbcwgd" || itype == "rgbcwsgd") {
         if (orgb == "255,255,255") {
           String ocw = hacw.get(rhanpos);
           if (TS.isEmpty(ocw)) {
             ocw = "127";
           }
           if (itype == "rgbcwsgd") {
             fcw = cwForCwsLvl(ocw, gamds);
           } else {
            String fcw = cwForCwLvl(ocw, gamds);
           }
           String frgb = orgb + "," + fcw;
           xd = orgb + "," + rstate + "," + ocw;
         } else {
           ocw = "127";
           frgb = rgbForRgbLvl(orgb, gamds);
           if (itype == "rgbcwsgd") {
             frgb += "," + cwForCwsLvl(ocw, gamds);
           } else {
             frgb += "," + cwForCwLvl(ocw, gamds);
           }
           xd = orgb + "," + rstate + "," + ocw;
         }
         cmds = "dostatexd spass " + rpos.toString() + " setrgbcw " + frgb + " " + xd + " e";
       } else {
        frgb = rgbForRgbLvl(orgb, gamds);
        String xd = orgb + "," + rstate;
        cmds = "dostatexd spass " + rpos.toString() + " setrgb " + frgb + " " + xd + " e";
       }
     } elseIf (itype == "cwgd") {
       ocw = hacw.get(rhanpos);
       if (TS.isEmpty(ocw)) {
         ocw = "127";
       }
       gamd = Int.new(rstate);
       gamd = gamma(gamd);
       gamds = gamd.toString();
       if (itype == "rgbcwsgd") {
        fcw = cwForCwsLvl(ocw, gamds);
       } else {
        fcw = cwForCwLvl(ocw, gamds);
       }
       xd = ocw + "," + rstate;
       cmds = "dostatexd spass " + rpos.toString() + " setcw " + fcw + " " + xd + " e";
     } else {
       String cmds = "dostate spass " + rpos.toString() + " setlvl " + rstate + " e";
     }
     //log.log("cmds " + cmds);

     Map mcmd = Maps.from("prio", 0, "cb", "setDeviceLvlCb", "did", rhan, "rhanpos", rhanpos, "rstate", rstate, "pwt", 2, "itype", itype, "cmds", cmds);

     return(mcmd);
   }

   //get the rgb value for the color at max brightness, so if largest were at 255
   trueRgb(String rgb) Map {
     log.log("in trueRgb");
     log.log("rgb " + rgb);
     Float tff = Float.intNew(255);
     var rgbl = rgb.split(",");
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

   cwForCwsLvl(String cw, String lvl) {
     log.log("in cwForCwLvlWs cw " + cw + " lvl " + lvl);

     //straight up lvl and temp

     Int lvli = Int.new(lvl);
     if (lvli < 0 || lvli > 255) { lvli = 255; }
     if (lvli == 1) { lvli = 2; } //cws seems to be off at analog write 1
     Int cwi = Int.new(cw);
     if (cwi < 0 || cwi > 255) { cwi = 255; }
     cwi = 255 - cwi;

     String res = lvli.toString() + "," + cwi.toString();
     log.log("cwForCwLvlWs res " + res);
     return(res);
   }

   setDeviceLvlCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String rhanpos = mcmd["rhanpos"];
     String rstate = mcmd["rstate"];
     String itype = mcmd["itype"];
     var halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     var hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     if (TS.notEmpty(cres) && cres.has("ok")) {
       halv.put(rhanpos, rstate);
       hasw.put(rhanpos, "on");
       ifEmit(wajv) {
        if (def(mqtt) && mqttMode == "haRelay") {
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
     } else {
       if (def(request)) {
         stDiffed = true;
         return(CallBackUI.setElementsDisplaysResponse(Maps.from("devErr", "block")));
        }
     }
     stDiffed = true;
     return(null);
   }

   processCmdsRequest(request) Map {
     slots {
       Map currCmds;
     }
      if (def(currCmds) && undef(currCmds["cres"])) {
      Int aptrs = currCmds["aptrs"];
      if (undef(aptrs)) {
        aptrs = 1;
        currCmds["aptrs"] = aptrs;
      } else {
        aptrs++;
      }
      if (aptrs > 16) {  //12 for 3s (orig), 16 for 4s (is), 24 for 6s
        //timed out
        mcmd = currCmds;
        currCmds = null;
        return(processCmdsFail(mcmd, request));
      }
        ifEmit(jv) {
           String jvadCmdsRes;
           jvadCmdsRes = currCmds["creso"].o;
           if (TS.notEmpty(jvadCmdsRes)) {
             currCmds["cres"] = jvadCmdsRes;
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
            for (Int ji = 0;ji < jspw.length;ji++) {
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
            currCmds["cres"] = jspw;
          } else {
            //"no getLastCres".print();
          }
        }
     }

     if (def(currCmds) && def(currCmds["cres"])) {
       mcmd = currCmds;
       currCmds = null;
       return(processMcmdRes(mcmd, request));
     } elseIf (undef(currCmds)) {
       //try a few times, for ignores
       for (Int j = 0;j < 20;j++) {
        for (Int i = 0;i < 10;i++) {
          Container:LinkedList cmdQueue = cmdQueues.get(i);
          if (def(cmdQueue)) {
            Map mcmd = cmdQueue.get(0);
            if (def(mcmd)) {
              var n = cmdQueue.getNode(0);
              n.remove();
              Bool ignore = mcmd["ignore"];
              if (def(ignore) && ignore) {
                log.log("got ignore in pcomrequest, noop");
              } else {
                prepMcmd(mcmd);
                currCmds = mcmd;
                if (def(mcmd["doRemote"]) && mcmd["doRemote"]) {
                  log.log("doing remote");
                  String finCmds = prot.secCmds(mcmd);
                  if (def(mqtt)) {
                    Map mqcmd = Maps.from("kdname", mcmd["kdname"], "cmds", finCmds, "reid", mqttReId, "iv", mcmd["iv"]);
                    mqtt.publish("casnic/cmds", Json:Marshaller.marshall(mqcmd));
                    //mcmd["cres"] = "ok"; //tmp to test
                  } else {
                    log.log("failed doing remote mqtt undef");
                  }
                  return(null);
                }
                processDeviceMcmd(mcmd);
                return(null);
              }
            }
          }
        }
       }
     }
     //check for timeout and null / interrupt
     return(null);
   }

   processMcmdRes(Map mcmd, request) {
       if (mcmd.has("cb")) {
         Int pver = mcmd["pver"];
         Int pwt = mcmd["pwt"];
         String pw = mcmd["pw"];
         String cres = mcmd["cres"];
         String iv = mcmd["iv"];
         ifEmit(jv) {
           Bool rs = mcmd["runSync"];
           if (def(rs) && rs) {
            if (TS.isEmpty(mcmd["cres"])) {
              String jvadCmdsRes;
              jvadCmdsRes = mcmd["creso"].o;
              if (TS.notEmpty(jvadCmdsRes)) {
                mcmd["cres"] = jvadCmdsRes;
              }
            }
           }
         }
         if (def(pver) && pver == 5 && def(pwt) && pwt > 0 && TS.notEmpty(pw) && TS.notEmpty(iv) && TS.notEmpty(cres)) {
           log.log("will decrypt cres");
           cres = Encode:Hex.decode(cres);
           cres = Crypt.decrypt(iv, pw, cres);
           log.log("decrypted cres" + cres);
           mcmd["cres"] = cres;
         }
         return(self.invoke(mcmd["cb"], Lists.from(mcmd, request)));
       }
       return(null);
   }

   clearQueueDid(String did) {
     //clear pending
      for (var kv in cmdQueues) {
        Container:LinkedList cmdQueue = kv.value;
        if (def(cmdQueue)) {
          for (Map mcmdcl in cmdQueue) {
            if (TS.notEmpty(mcmdcl["did"]) && mcmdcl["did"] == did) {
              log.log("marking ignore in cmdQueue did");
              mcmdcl["ignore"] = true;
            }
           }
         }
       }
   }

   clearQueueKdaddr(String kdaddr) {
     //clear pending
      for (var kv in cmdQueues) {
        Container:LinkedList cmdQueue = kv.value;
        if (def(cmdQueue)) {
          for (Map mcmdcl in cmdQueue) {
            if (TS.notEmpty(mcmdcl["kdaddr"]) && mcmdcl["kdaddr"] == kdaddr) {
              log.log("marking ignore in cmdQueue kdaddr");
              mcmdcl["ignore"] = true;
            }
           }
         }
       }
   }

   processCmdsFail(Map mcmd, request) {

    String did = mcmd["did"];

    if (TS.notEmpty(did)) {
      if (def(currentEvents)) {
        log.log("in cmds fail clearing currentEvents for did " + did);
        currentEvents.remove(did);
      }
      String kdaddr = mcmd["kdaddr"];
      if (TS.notEmpty(kdaddr)) {
        remoteAddrs.put(kdaddr);
      }
      clearQueueDid(did);
     }

     //?failre / timeout callback?
     String kdname = mcmd["kdname"];

     if (TS.notEmpty(kdname)) {
      log.log("RERESOLVE " + kdname);
      ifNotEmit(apwk) {
        resolveAddr(kdname);
        reloadAddr(kdname);
      }
      ifEmit(apwk) {
        //avoid race with goGetAddr
        reloadAddr(kdname);
        resolveAddr(kdname);
      }
     }
       if (mcmd.has("cb")) {
         return(processMcmdRes(mcmd, request));
       }
       return(null);
   }

   sendDeviceMcmd(Map mcmd) Bool {
      if (def(mcmd)) {
        String did = mcmd["did"];
        if (TS.notEmpty(did)) {
          var hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
          String confs = hadevs.get(did);
          Map conf = Json:Unmarshaller.unmarshall(confs);
          String kdname = "CasNic" + conf["ondid"];
          String kdaddr = getAddrDis(kdname);
          mcmd["kdname"] = kdname;
          mcmd["kdaddr"] = kdaddr;
          var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
          String sws = haspecs.get(did);
          if (TS.notEmpty(sws)) {
            if (sws.has("p4,")) {
              mcmd["pver"] = 4;
            }
            if (sws.has("p5,")) {
              mcmd["pver"] = 5;
            }
          }
          Int pwt = mcmd["pwt"];
          if (def(pwt)) {
            if (pwt > 0) {
              String cmdline = mcmd["cmds"];
              var cmdl = cmdline.split(" ");
              if (pwt == 1) {
                cmdl[1] = conf["pass"];
                mcmd["pw"] = cmdl[1];
              } elseIf (pwt == 2) {
                cmdl[1] = conf["spass"];
                mcmd["pw"] = cmdl[1];
              } elseIf (pwt == 3) {
                cmdl[1] = getSecQ(conf);
                mcmd["pw"] = "";
              }
              cmdline = Text:Strings.new().join(Text:Strings.new().space, cmdl);
              mcmd["cmds"] = cmdline;
            } else {
              mcmd["pw"] = "";
            }
          }
        }
        Bool doRemote = false;
        if (def(mqtt) && TS.notEmpty(mqttMode) && mqttMode == "fullRemote") {
          doRemote = true;
        }
        if (TS.notEmpty(mcmd["kdaddr"]) && remoteAddrs.has(mcmd["kdaddr"])) {
          if (mcmd.has("skipIfRemote") && mcmd["skipIfRemote"]) {
            unless (mcmd.has("forceLocal") && mcmd["forceLocal"]) {
              //also, be sure there IS a remote server for device
              //log.log("in remoteAddrs remove kdaddr");
              mcmd.remove("kdaddr");
            } else {
              log.log("was forceLocal, did not remove kdaddr");
            }
          }
        }
        if (TS.isEmpty(mcmd["kdaddr"])) {
          log.log("kdaddr empty");
          if (def(mqtt) && TS.notEmpty(mqttMode) && mqttMode == "remote") {
            doRemote = true;
          }
          unless (doRemote) {
            return(false);
          }
        }
        if (doRemote) {
          if (TS.notEmpty(mcmd["kdname"]) && TS.notEmpty(mcmd["cmds"])) {
            mcmd.remove("runSync");
            mcmd.put("doRemote", true);
          } else {
            return(false);
          }
        }
        Bool rs = mcmd["runSync"];
        if (def(rs) && rs) {
          Bool ignore = mcmd["ignore"];
          if (def(ignore) && ignore) {
            log.log("got ignore noop");
            return(false);
          }
          prepMcmd(mcmd);
          processDeviceMcmd(mcmd);
          processMcmdRes(mcmd, null);
          return(true);
        }
        Int priority = mcmd["prio"];
        if (undef(priority)) {
          log.log("prio undefined in sendDeviceMcmd");
          priority = 5;
        }

        Container:LinkedList cmdQueue = cmdQueues.get(priority);
        if (undef(cmdQueue)) {
          cmdQueue = Container:LinkedList.new();
          cmdQueues.put(priority, cmdQueue);
        }

        if (TS.notEmpty(did)) {
          //max waiting per did
          wct = 0;
          mw = null;
          for (i = cmdQueue.iterator;i.hasNext;;) {
            mc = i.next;
            if (TS.notEmpty(mc["did"]) && mc["did"] == mcmd["did"]) {
              unless (def(mc["ignore"]) && mc["ignore"]) {
                wct++;
                if (undef(mw)) {
                  if (def(mc["mw"])) {
                    mw = mc["mw"];
                  } else {
                    mw = 5 - priority;
                    if (mw < 0) { mw = 0; }
                  }
                }
                if (wct > mw) {
                  log.log("too many waiting did no adding to cmdQueue");
                  return(false);
                }
              }
            }
          }
        }
        if (TS.notEmpty(mcmd["kdaddr"])) {
          //max waiting per kdaddr
          Int wct = 0;
          Int mw = null;
          for (var i = cmdQueue.iterator;i.hasNext;;) {
            Map mc = i.next;
            if (TS.notEmpty(mc["kdaddr"]) && mc["kdaddr"] == mcmd["kdaddr"]) {
              unless (def(mc["ignore"]) && mc["ignore"]) {
                wct++;
                if (undef(mw)) {
                  if (def(mc["mw"])) {
                    mw = mc["mw"];
                  } else {
                    mw = 5 - priority;
                    if (mw < 0) { mw = 0; }
                  }
                }
                if (wct > mw) {
                  log.log("too many waiting kdaddr no adding to cmdQueue");
                  return(false);
                }
              }
            }
          }
        }
        cmdQueue += mcmd;
        //log.log("added to cmdQueue");
        return(true);
      }
      return(false);
   }

   /*
     //tcp edition
     var client = App:TCPClient.new("CasNic" + conf["id"] + ".local", 6420);
     //var client = App:TCPClient.new("192.168.1.243", 6420);
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
     var client = Web:Client.new();
     client.url = ucmd;
     String res = client.openInput().readString();
     client.close();
     log.log("res was " + res);
     */

  prepMcmd(Map mcmd) {
    //log.log("in processDeviceMcmd");
    mcmd["creso"] = OLocker.new(null);
    unless (mcmd.has("pver")) {
      mcmd["pver"] = 1;
    }
    mcmd["iv"] = System:Random.getString(16);
    //log.log("adding tesh in processDeviceMcmd");
    Int teshi = Time:Interval.now().seconds;
    //teshi -= 300;
    mcmd["tesh"] = teshi.toString();
  }

  processDeviceMcmd(Map mcmd) {
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

   getDevWifisRequest(Int count, Bool starting, Bool forcing, request) Map {
     slots {
       Set visnets; //set no marshall
       Bool visnetsDone;
       Int visnetsFails;
       Int visnetsPos;
     }
     if (starting) {
       visnets = Set.new();
       visnetsDone = false;
       visnetsFails = 0;
       visnetsPos = 0;
     }
     Int tries = 200;
     Int wait = 1000;

     Account account = request.context.get("account");
     var uhex = Hex.encode(account.user);
     var hawifi = app.kvdbs.get("HAWIFI"); //account hex to wifi network

     String ssid = hawifi.get(uhex + ".ssid.0");
     String sec = hawifi.get(uhex + ".sec.0");
     if (undef(ssid)) { ssid = ""; }
     if (undef(sec)) { sec = ""; }

     if (TS.notEmpty(ssid) && TS.notEmpty(sec) && (visnets.has(ssid) || forcing)) {
       log.log("have wifi setup and found my ssid, moving to allset");
       count.setValue(tries);
       clearQueueKdaddr("192.168.4.1");
       return(CallBackUI.getDevWifisResponse(count, tries, wait));
     }

     if (visnetsFails > 20) {
       log.log("visnetsFails overmuch");
       if (TS.notEmpty(ssid) && TS.notEmpty(sec)) {
         log.log("have ssid sec giving it a go, is old device");
         count.setValue(tries);
         clearQueueKdaddr("192.168.4.1");
         return(CallBackUI.getDevWifisResponse(count, tries, wait));
       } else {
         return(CallBackUI.informResponse("Older device and no known Wifi config.  Under Settings / Advanced Settings configure a 2.4Ghz Wifi Network Name (ssid) and password and then retry device setup"));
       }
     } elseIf (count >= tries || visnetsDone) {
       log.log("doing settle wifi");
       List vnl = List.new();
       for (String vn in visnets) {
        vnl += vn;
       }
       clearQueueKdaddr("192.168.4.1");
       return(CallBackUI.settleWifiResponse(vnl, ssid, sec));
     }

     String cmds = "previsnets " + visnetsPos + " e";
     Map mcmd = Maps.from("prio", 1, "mw", 1, "cb", "previsnetsCb", "kdaddr", "192.168.4.1", "pwt", 0, "cmds", cmds);
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
           for (Int i = 1;i < ssp.length;i++) {
             String vna = Encode:Hex.decode(ssp[i]);
             log.log("got vna " + vna);
             visnets.put(vna);
             visnetsPos++;
           }
        } else {
          //done
          log.log("got no : ssids, previsnetsCb is done");
          visnetsDone = true;
        }
      } else {
        //failed
        log.log("got a fail in previsnetsCb");
        visnetsFails++;
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
     unless (devSsid.begins("OCasnic-") || devSsid.begins("CasnicO-")) {
       String sec = devPin.substring(8, 16);
     }

     //log.log("in getOnWifiRequest " + devPin + " " + devSsid);

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
      Int length = toCheck.length;
      String ret = String.new(toCheck.length);
      for (Int j = 0;j < length;j++;) {
        toCheck.getInt(j, ic);
        if ((ic > 47 && ic < 58) || (ic > 64 && ic < 91) || (ic > 96 && ic < 123) || ic == 32) {
            ret.length = ret.length + 1;
            ret.setInt(j, ic);
        }
      }
      return(ret);
   }

   allsetRequest(Int count, String devName, String devType, String devPin, String disDevSsid, String disDevId, String devPass, String devSpass, String devDid, String devSsid, String devSec, request) {
      Int tries = 200;
      Int wait = 1000;
      count++;
      slots {
        String alStep;
      }

      Account account = request.context.get("account");
      var uhex = Hex.encode(account.user);

      if (TS.isEmpty(devPass)) {
        Int dps = System:Random.getIntMax(4) + 16;
        devPass = System:Random.getString(dps);
      }

      var hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config

      if (TS.isEmpty(devSpass)) {
        dps = System:Random.getIntMax(4) + 16;
        devSpass = System:Random.getString(dps);
      }

      if (TS.isEmpty(devDid)) {
        devDid = System:Random.getString(16);
      }

      if (TS.isEmpty(devSsid)) {
        var hawifi = app.kvdbs.get("HAWIFI"); //account hex to wifi network
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
          mcmd = Maps.from("prio", 1, "mw", 1, "cb", "allsetCb", "disDevId", disDevId, "kdaddr", "192.168.4.1", "pwt", 0, "cmds", cmds);

          Map conf = Map.new();
          conf["type"] = devType;
          conf["id"] = disDevId;
          conf["ondid"] = devDid;
          conf["name"] = devName;
          conf["pass"] = devPass;
          conf["spass"] = devSpass;
          String confs = Json:Marshaller.marshall(conf);
          saveDeviceRequest(conf["id"], confs, request);
          sendDeviceMcmd(mcmd);
        } elseIf (alStep == "getcontroldef") {
          cmds = "getcontroldef " + devSpass + " e";
          mcmd = Maps.from("prio", 1, "mw", 1, "cb", "allsetCb", "disDevId", disDevId, "kdaddr", "192.168.4.1", "pwt", 0, "cmds", cmds);
          sendDeviceMcmd(mcmd);
        } elseIf (alStep == "setwifi") {
          cmds = "setwifi " + devPass + " hex " + devSsid + " " + devSec + " e";
          mcmd = Maps.from("prio", 1, "mw", 1, "cb", "allsetCb", "disDevId", disDevId, "kdaddr", "192.168.4.1", "pwt", 0, "cmds", cmds);
          sendDeviceMcmd(mcmd);
        } elseIf (alStep == "restart") {
          cmds = "restart " + devPass + " e";
          mcmd = Maps.from("prio", 1, "mw", 1, "cb", "allsetCb", "disDevId", disDevId, "kdaddr", "192.168.4.1", "pwt", 0, "cmds", cmds);
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
        clearQueueKdaddr("192.168.4.1");
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
          if (cres.has("p4")) {
            log.log("has p4");
            var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
            haspecs.put(disDevId, "1.p4,p2.phx.4");
          }
          clearQueueKdaddr("192.168.4.1");
          alStep = "getcontroldef";
       } elseIf (TS.notEmpty(cres) && cres.has("pass is incorrect")) {
          throw(Alert.new("Device is already configured, reset before setting up again."));
       } elseIf (TS.notEmpty(cres) && cres.has("mins of power on")) {
          throw(Alert.new("Error, must setup w/in 30 mins of power on. Unplug and replug in device and try again"));
       }
     } elseIf (alStep == "getcontroldef") {
       if (TS.notEmpty(cres) && cres.has("controldef")) {
         log.log("got controldef " + cres);
         String controlDef = cres;
         var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
         hactls.put(disDevId, controlDef);
         clearQueueKdaddr("192.168.4.1");
         alStep = "setwifi";
       }
     } elseIf (alStep == "setwifi") {
       if (TS.notEmpty(cres) && cres.has("Wifi Setup Written")) {
         log.log("wifi setup worked");
         clearQueueKdaddr("192.168.4.1");
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
          clearQueueKdaddr("192.168.4.1");
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
    Map mcmd = Maps.from("prio", 1, "mw", 1, "cb", "displayNextDeviceCmdCb", "kdaddr", "192.168.4.1", "pwt", 0, "cmds", cmds);
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
      if (ssid.begins("OCasnic-") || ssid.begins("Casnic")) {
        var pts = ssid.split("-");
        if (pts.length == 4) {
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
            if (ssid.begins("OCasnic-") || ssid.begins("Casnic")) {
              var pts = ssid.split("-");
              if (pts.length == 4) {
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
      if (type.begins("r")) {
        if (type == "rNodeMCU") {
          ftype = "NodeMCU";
        } elseIf (type == "rAthPlugV2") {
          ftype = "Athom Plug V2";
        } elseIf (type == "rAthBlb7w") {
          ftype = "Athom 7w Bulb";
        } elseIf (type == "rAthBlb15w") {
          ftype = "Athom 15w Bulb";
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
     for (Int i = 0;i < 3;i++) {
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

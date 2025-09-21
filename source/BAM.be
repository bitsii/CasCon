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
    public WifiManager wifi;
    WifiManager.MulticastLock multicastLock;
    public boolean gotOnDevNetwork = false;
    ConnectivityManager lastConnectivityManager;
    ConnectivityManager.NetworkCallback lastNetworkCallback;


    public static class InitializeResolveListener implements NsdManager.ResolveListener {

    public static java.util.Hashtable<String, String> knownDevices = new java.util.Hashtable<String, String>();
    public static java.util.Hashtable<String, String> wantedDevices = new java.util.Hashtable<String, String>();
    public static java.util.Hashtable<String, NsdServiceInfo> resolving = new java.util.Hashtable<String, NsdServiceInfo>();

    public static void maybeResolve() {
       if (!resolving.isEmpty()) {
        try {
          java.util.Collection<NsdServiceInfo> rv = resolving.values();
          int rnd = new java.util.Random().nextInt(rv.size());
          java.util.Iterator<NsdServiceInfo> rvi = rv.iterator();
          NsdServiceInfo rs = null;
          for (int i = 0;i <= rnd;i++) {
            rs = rvi.next();
          }
          nsdManager.resolveService(rs, new InitializeResolveListener());
        } catch (ClassCastException cce) {
          System.out.println("class cast exception in resolving");
          resolving.clear();
        }
      }
    }

    @Override
    public void onResolveFailed(NsdServiceInfo serviceInfo, int errorCode) {
      System.out.println("Resolve failed " + errorCode);
      String sname = serviceInfo.getServiceName();
      resolving.remove(sname);
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
      wantedDevices.remove(sname);
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
          OLocker inDiscovery = OLocker.new(false);
          Bool backgroundPulseOnIdle = false;
          Bool backgroundPulse = backgroundPulseOnIdle;
          CLocker mqtts = CLocker.new(Map.new());
          String reId;
        }
        slots {
          Map knc = Map.new();
          Set locAddrs = Set.new();
          Bool mqttFullRemote = false;
        }
        ifEmit(wajv) {
          backgroundPulseOnIdle = true;
          backgroundPulse = backgroundPulseOnIdle;
        }
        reId = System:Random.getString(12);
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
        System:Thread.new(System:Invocation.new(self, "runPulseDevices", List.new())).start();
        if (prot.doSupUpdate) {
          System:Thread.new(System:Invocation.new(self, "haDoUp", List.new())).start();
        }

      }

      initializeDiscoveryListener();
      checkStartMqtt();


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

    checkStartMqtt() {
      String mqft = app.configManager.get("mqtt.fullTime");
      if (TS.notEmpty(mqft) && mqft == "on") {
        mqttFullRemote = true;
      } else {
        mqttFullRemote = false;
      }
      String mqdis = app.configManager.get("mqtt.disabled");
      if (TS.isEmpty(mqdis) || mqdis != "on") {
       checkStartMqtt("remote");
       //checkStartMqtt("relay");
       //checkStartMqtt("haRelay");
      }
      slots {
       Bool haveGm;
      }
      Bool hgm = false;
      var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
      for (any kv in haspecs.getMap()) {
        if (TS.notEmpty(kv.value) && kv.value.has(",gm,")) {
          hgm = true;
        }
      }
      haveGm = hgm;
    }

    checkStartMqtt(String mqttMode) {

       Mqtt mqtt = mqtts[mqttMode];
        if (undef(mqtt) || mqtt.isOpen!) {
          String mqttBroker = app.configManager.get("mqtt." + mqttMode + ".broker");
          String mqttUser = app.configManager.get("mqtt." + mqttMode + ".user");
          String mqttPass = app.configManager.get("mqtt." + mqttMode + ".pass");
          if (TS.isEmpty(mqttBroker) || TS.isEmpty(mqttUser) || TS.isEmpty(mqttPass)) {
            ifEmit(wajv) {
            if (mqttMode == "haRelay" && TS.notEmpty(prot.supTok) && TS.notEmpty(prot.supUrl) && prot.doSupAuth) {
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
          mqtt.publish("casnic/ktlo/" + reId, "yo");
        }

    }

    initializeMqtt(String mqttMode, String mqttBroker, String mqttUser, String mqttPass) {

       log.log("initializing mqtt");
       Mqtt mqtt = Mqtt.new();
       mqtt.broker = mqttBroker;
       mqtt.user = mqttUser;
       mqtt.pass = mqttPass;
       mqtt.messageHandler = self;
       mqtt.open();
       mqtts[mqttMode] = mqtt;
       if (mqtt.canSubscribe) {
        log.log("mqtt opened");
        if (mqttMode == "haRelay") {
          mqtt.subscribe("homeassistant/status");
        }
        if (mqttMode == "remote") {
          mqtt.subscribe("casnic/res/" + reId);
        }
        if (mqttMode == "relay") {
          mqtt.subscribe("casnic/cmds");
          mqtt.subscribe("casnic/shares");
        }
        mqtt.subscribe("casnic/ktlo/" + reId);
        setupMqttDevices(mqttMode);
       }
       //mqtt.subscribe("test");
       //mqtt.publish("test", "hi from casnic");

    }

    setupMqttDevices(String mqttMode) {
      ifEmit(wajv) {
        Mqtt mqtt = mqtts[mqttMode];
        if (def(mqtt) && mqtt.isOpen) {
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
    }

    handleMessage(String topic, String payload) {
      if (TS.notEmpty(topic) && TS.notEmpty(payload)) {
        if (topic.begins("casnic/ktlo")) { return(self); } //noop
        //log.log("in bam handlemessage for " + topic + " " + payload);
        if (topic == "homeassistant/status" && payload == "online") {
          log.log("ha startedup");
          setupMqttDevices("haRelay");
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
        } elseIf (topic == "casnic/cmds") {
          log.log("relay handlemessage for " + topic + " " + payload);
          System:Thread.new(System:Invocation.new(self, "handleRelay", Lists.from(topic, payload))).start();
        } elseIf (topic == "casnic/shares") {
          String ashare = app.configManager.get("mqtt.autoShare");
          if (TS.isEmpty(ashare) || ashare == "on") {
            log.log("would now auto accept share");
            log.log(payload);
            acceptShareRequest(payload, null);
          }
        } elseIf (topic == "casnic/res/" + reId) {
          log.log("got res in mqtt remote " + payload);

          //Map mqres = Json:Unmarshaller.unmarshall(payload);
          //String resiv = mqres["iv"];
          //String rescres = mqres["cres"];

          log.log("getting iv in remote res");
          String rescres = payload;
          String resivcr = rescres.substring(0, rescres.find(" "));
          String resiv = resivcr.substring(0, resivcr.find(","));
          //log.log("resivcr |" + resivcr + "| resiv |" + resiv + "|");

          if (def(currCmds) && TS.notEmpty(currCmds["iv"]) && TS.notEmpty(resiv) && resiv == currCmds["iv"]) {
            log.log("res good, setting to creso");
            Int lmt = rescres.find("\r");
            if (def(lmt)) { rescres = rescres.substring(0, lmt); }
            lmt = rescres.find("\n");
            if (def(lmt)) { rescres = rescres.substring(0, lmt); }
            currCmds["creso"].o = rescres;
          } else {
            log.log("currCmds undef or preempted ");
            if (def(currCmds) && TS.notEmpty(currCmds["iv"])) {
              log.log("currCmds iv |" + currCmds["iv"] + "|");
            } else {
              log.log("currCmds iv empty");
            }
          }
        }
      }
    }

    handleRelay(String topic, String payload) {
      if (TS.notEmpty(payload) && payload.begins("rel1:")) {
        String kdn = payload.substring(payload.find(":") + 1, payload.find(";"));
        String cmds = payload.substring(payload.find(";") + 1, payload.length);
        log.log("relay kdn |" + kdn + "| cmds |" + cmds + "|");
      } else {
        log.log("malformed relay request");
        return(self);
      }
      String kdaddr = getAddrDis(kdn);
      if (TS.isEmpty(kdaddr)) {
        log.log("no kdaddr for " + kdn);
        return(self);
      }
      String cres = prot.sendJvadCmds(kdaddr, cmds + "\r\n", 4000);
      if (TS.notEmpty(cres)) {
        log.log("relay cres " + cres);
        String resivcr = cres.substring(0, cres.find(" "));
        String resreid = resivcr.substring(resivcr.find(",") + 1, resivcr.length);
        //log.log("resivcr |" + resivcr + "| resreid |" + resreid + "|");
        Mqtt mqtt = mqtts["relay"];
        mqtt.publish("casnic/res/" + resreid, cres);
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

    lvlToPct(Int ls) Int {
      if (ls < 0 || ls > 255) { ls = 255; }
      Float lsf = Float.intNew(ls);
      Float fh = Float.intNew(255);
      Float mp = lsf / fh;
      Float mrm = Float.intNew(100);
      Float mrf = mp * mrm;
      Int mr = mrf.toInt();
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
      //log.log("in showDeviceConfigRequest ");

      var hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
      String confs = hadevs.get(did);
      return(CallBackUI.showDeviceConfigResponse(addFtype(confs), getCachedIp(confs)));

    }
    
    showNextDeviceConfigRequest(String lastDid, request) Map {
      //log.log("in showNextDeviceConfigRequest ");
      if (TS.notEmpty(lastDid)) {
        //log.log("lastDid " + lastDid);
        Bool retnext = false;
      } else {
        //log.log("lastDid empty");
        retnext = true;
      }
      //Account account = request.context.get("account");
      var uhex = Hex.encode("Adrian");
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

    considerTds(String kdname) {
      if (TS.isEmpty(kdname)) { return(false); }
      var hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
      var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
      for (any kv in hadevs.getMap()) {
        String did = kv.key;
        String confs = kv.value;
        Map conf = Json:Unmarshaller.unmarshall(confs);
        String dkdname = "CasNic" + conf["ondid"];
        if (dkdname == kdname) {
          String spec = haspecs.get(did);
          if (TS.isEmpty(spec) || spec.has(",nm,") || spec.has(".gsh.")) {
            log.log("WILL TRY TDS");
            if (def(pendingTds)) {
              pendingTds += did;
            }
            return(null);
          }
        }
      }
      return(null);
    }

    resolveAddr(String kdname) {
      considerTds(kdname);
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
          emit(jv) {
            """
            //new $class/Text:String$(fnames[i].getBytes("UTF-8"))
            String jkdn = beva_kdname.bems_toJvString();
            String kdaddr = InitializeResolveListener.knownDevices.get(jkdn);
            if (kdaddr != null) {
              bevl_kdaddr =  new $class/Text:String$(kdaddr.getBytes("UTF-8"));
            } else {
              InitializeResolveListener.wantedDevices.put(jkdn, jkdn);
            }
            """
          }
          if (TS.isEmpty(kdaddr)) {
            System:Thread.new(System:Invocation.new(self, "runDiscoveryInnerJvad", List.new())).start();
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

     //String confs = onDevId + "," + Encode:Hex.encode(devName) + "," + devPass + "," + devSpass;
     //Map conf = Map.new();
     //conf["type"] = devType;
     //conf["id"] = devId;
     //conf["ondid"] = onDevId;
     //conf["name"] = devName;
     //if (admin && TS.notEmpty(devPass)) {
     //  conf["pass"] = devPass;
     //}
     //conf["spass"] = devSpass;

     var confsl = confs.split(",");
     if (confsl.length < 4) {
       log.log("got a bad share conf too small");
       return(null);
     }
     Map conf = Map.new();
     conf["ondid"] = confsl[0];
     conf["name"] = confsl[1];
     conf["pass"] = confsl[2];
     conf["spass"] = confsl[3];

     //Map conf = Json:Unmarshaller.unmarshall(confs);

     //dedupe reshares
     var hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     for (any kv in hadevs.getMap()) {
      String did = kv.key;
      String dconfs = kv.value;
      Map dconf = Json:Unmarshaller.unmarshall(dconfs);
      if (TS.notEmpty(dconf["ondid"]) && TS.notEmpty(conf["ondid"]) && conf["ondid"] == dconf["ondid"]) {
        //conf["id"] = dconf["id"];
        return(CallBackUI.reloadResponse());//we already have it.
      }
     }
     if (TS.isEmpty(conf["id"])) {
       conf["id"] = System:Random.getString(11);
     }
     var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
     haspecs.put(conf["id"], "1,q,p6,p2.gsh.4");
     confs = Json:Marshaller.marshall(conf);
     saveDeviceRequest(conf["id"], confs, request);
     //rectlDeviceRequest(conf["id"], null, request);
     //ifEmit(wajv) {
     // setupMqttDevices("haRelay");
     // setupMqttDevices("relay");
     //}
     return(CallBackUI.reloadResponse());
     //return(null);
   }
   
   deleteDeviceRequest(String did, request) Map {
     log.log("in removeDeviceRequest " + did);
     
    //Account account = request.context.get("account");
    var uhex = Hex.encode("Adrian");
    var hadevs = app.kvdbs.get("HADEVS"); //hadevs - device aid to config
    var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
    var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
    var hasw = app.kvdbs.get("HASW"); //hasw - device aid to switch state
    var halv = app.kvdbs.get("HALV"); //halv - device aid to lvl
    var hacw = app.kvdbs.get("HACW"); //hargb - device id to rgb
    var hargb = app.kvdbs.get("HARGB"); //hargb - device id to rgb
    var haowns = app.kvdbs.get("HAOWNS"); //haowns - prefix account hex to map of owned device aids
    var haknc = app.kvdbs.get("HAKNC"); //kdname to addr
    var haposdm = app.kvdbs.get("HAPOSDM"); //position names dev id to json of names and ohter stuff
    var hahid = app.kvdbs.get("HAHID");
    var havsh = app.kvdbs.get("HAVSH"); //havsh - device id to voice autoshare
    
    String confs = hadevs.get(did);
    if (TS.notEmpty(confs)) {
      Map conf = Json:Unmarshaller.unmarshall(confs);
      //getting the name
      if (TS.notEmpty(conf["ondid"])) {
        String kdname = "CasNic" + conf["ondid"];
        haknc.remove(kdname);
      }
    }

    Set todel = Set.new();
    Map tocheck = haposdm.getMap();
    if (def(tocheck)) {
      for (any kvd in tocheck) {
        if (kvd.key.begins(did)) {
          todel += kvd.key;
        }
      }
    }
    for (any d in todel) {
      haposdm.remove(d);
    }

    todel = Set.new();
    tocheck = hahid.getMap();
    if (def(tocheck)) {
      for (kvd in tocheck) {
        if (kvd.key.begins(did)) {
          todel += kvd.key;
        }
      }
    }
    for (d in todel) {
      hahid.remove(d);
    }

    todel = Set.new();
    tocheck = havsh.getMap();
    if (def(tocheck)) {
      for (kvd in tocheck) {
        if (kvd.key.begins(did)) {
          todel += kvd.key;
        }
      }
    }
    for (d in todel) {
      havsh.remove(d);
    }

    haowns.remove(uhex + "." + did);
    hadevs.remove(did);
    pdevices = hadevs.getMap();

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


     var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
     String spec = haspecs.get(did);

     Map mcmd = Maps.from("prio", 1, "cb", "resetDeviceCb", "did", did, "pwt", 1, "cmds", cmds);

     sendDeviceMcmd(mcmd);

     unless (spec.has(",a1,") || spec.has(",h1,")) {
       brd("unshare", did, null, request);
     }

     return(null);

   }

   resetDeviceCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     if (TS.isEmpty(cres)) {
       log.log("reset got no cres");
       throw(Alert.new("Device did not respond to reset request"));
     } else {
       if (cres.has("Device re")) {
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

   saveHideRequest(String hide, String did, String forPos, request) Map {
     log.log("saveHideRequest");
     var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
     var hahid = app.kvdbs.get("HAHID");
     //String sws = haspecs.get(did);
     if (TS.notEmpty(forPos)) {
       hahid.put(did + "-" + forPos, hide);
     } else {
       hahid.put(did, hide);
     }
     //return(CallBackUI.reloadResponse());
     return(CallBackUI.closeSettingsResponse());
   }

   saveDeviceForPosRequest(String did, String forPos, String devName, String confs, request) Map {
     var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
     //String sws = haspecs.get(did);
     if (TS.notEmpty(forPos) && TS.notEmpty(devName)) {
      //if (TS.notEmpty(sws) && sws.has(",gt1,")) {
        log.log("doing forPos " + forPos + " " + devName);
        var haposdm = app.kvdbs.get("HAPOSDM"); //position names dev id to json of names and ohter stuff
        haposdm.put(did + "-" + forPos, devName);
      //}
     }
     return(saveDeviceRequest(did, confs, request));
   }
   
   saveDeviceRequest(String did, String confs, request) Map {
     //log.log("in addDeviceRequest " + confs);
     log.log("in saveDeviceRequest");
     
     //Account account = request.context.get("account");
     var uhex = Hex.encode("Adrian");
     var hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     //var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
     //var hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     //var halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     var haowns = app.kvdbs.get("HAOWNS"); //haowns - prefix account hex to map of owned device ids
     
     //String did = System:Random.getString(16);
     


     hadevs.put(did, confs);
     pdevices = hadevs.getMap();
     haowns.put(uhex + "." + did, did);
     
     return(CallBackUI.reloadResponse());
   }

   loadWifiRequest(request) Map {
     //Account account = request.context.get("account");
     var uhex = Hex.encode("Adrian");
     var hawifi = app.kvdbs.get("HAWIFI"); //account hex to wifi network

     String ssid = hawifi.get(uhex + ".ssid.0");
     String sec = hawifi.get(uhex + ".sec.0");
     if (undef(ssid)) { ssid = ""; }
     if (undef(sec)) { sec = ""; }
     return(CallBackUI.setElementsValuesResponse(Maps.from("wifiSsid", ssid, "wifiSec" sec)));
   }

   loadMqtt(String mqttMode) Map {
     if (TS.notEmpty(mqttMode)) {
      String mqttBroker = app.configManager.get("mqtt." + mqttMode + ".broker");
      String mqttUser = app.configManager.get("mqtt." + mqttMode + ".user");
      String mqttPass = app.configManager.get("mqtt." + mqttMode + ".pass");
      if (undef(mqttBroker)) { mqttBroker = ""; }
      if (undef(mqttUser)) { mqttUser = ""; }
      if (undef(mqttPass)) { mqttPass = ""; }
     }
     return(Maps.from("mqttBroker", mqttBroker, "mqttUser" mqttUser, "mqttPass", mqttPass));
   }

   loadMqttRequest(String mqttMode, request) Map {
     return(CallBackUI.setElementsValuesResponse(loadMqtt(mqttMode)));
   }

   loadMqFullRequest(request) Map {
     String ashare = app.configManager.get("mqtt.fullTime");
     if (TS.isEmpty(ashare)) {
       ashare = "off";
       app.configManager.put("mqtt.fullTime", ashare);
     }
     return(CallBackUI.mqFullResponse(ashare));
   }

   saveMqFullRequest(String ashare, request) Map {
     log.log("got mqFull " + ashare);
     app.configManager.put("mqtt.fullTime", ashare);
     if (ashare == "on") {
       mqttFullRemote = true;
     } else {
       mqttFullRemote = false;
     }
     return(null);
   }

   loadMqDisRequest(request) Map {
     String ashare = app.configManager.get("mqtt.disabled");
     if (TS.isEmpty(ashare)) {
       ashare = "off";
       app.configManager.put("mqtt.disabled", ashare);
     }
     return(CallBackUI.mqDisResponse(ashare));
   }

   saveMqDisRequest(String ashare, request) Map {
     log.log("got mqDis " + ashare);
     app.configManager.put("mqtt.disabled", ashare);
     if (ashare == "on") {
       for (any kv in mqtts.container) {
         if (def(kv.value) && kv.value.isOpen) {
           kv.value.close();
         }
       }
     }
     return(null);
   }

   loadMqAsRequest(request) Map {
     String ashare = app.configManager.get("mqtt.autoShare");
     if (TS.isEmpty(ashare)) {
       ashare = "on";
       app.configManager.put("mqtt.autoShare", ashare);
     }
     return(CallBackUI.mqAsResponse(ashare));
   }

   saveMqAsRequest(String ashare, request) Map {
     log.log("got mqAsSet " + ashare);
     app.configManager.put("mqtt.autoShare", ashare);
     return(null);
   }

   loadAutoVShareRequest(request) Map {
     String ashare = app.configManager.get("vshare.autoShare");
     if (TS.isEmpty(ashare)) {
       ashare = "on";
       app.configManager.put("vshare.autoShare", ashare);
     }
     return(CallBackUI.vsAsResponse(ashare));
   }

   saveAutoVShareRequest(String ashare, request) Map {
     log.log("got saveAutoVShareRequest " + ashare);
     app.configManager.put("vshare.autoShare", ashare);
     return(null);
   }

   saveWifiRequest(String ssid, String sec, Bool reloadAfter, request) Map {

     //Account account = request.context.get("account");
     var uhex = Hex.encode("Adrian");
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

   saveMqttRequest(String mqttMode, String mqttBroker, String mqttUser, String mqttPass, request) Map {
     if (TS.notEmpty(mqttMode)) {
      if (TS.notEmpty(mqttBroker) && TS.notEmpty(mqttUser) && TS.notEmpty(mqttPass)) {
        mqttBroker = mqttBroker.swap(" ", "");
        //mqttUser = mqttUser.swap(" ", "");
        //mqttPass = mqttPass.swap(" ", "");
        app.configManager.put("mqtt." + mqttMode + ".broker", mqttBroker);
        app.configManager.put("mqtt." + mqttMode + ".user", mqttUser);
        app.configManager.put("mqtt." + mqttMode + ".pass", mqttPass);
        log.log("saved mqtt");
      } else {
        app.configManager.remove("mqtt." + mqttMode + ".broker");
        app.configManager.remove("mqtt." + mqttMode + ".user");
        app.configManager.remove("mqtt." + mqttMode + ".pass");
        log.log("cleared mqtt");
      }
      Mqtt mqtt = mqtts[mqttMode];
      if (def(mqtt) && mqtt.isOpen) {
        mqtt.close();
        mqtts.remove(mqttMode);
      }
      checkStartMqtt(mqttMode);
     } else {
       log.log("not saving mqtt, mqttMode empty");
     }

     return(CallBackUI.reloadResponse());
   }
   
   getDevicesRequest(request) Map {
     log.log("in getDevicesRequest");
     //Account account = request.context.get("account");
     var uhex = Hex.encode("Adrian");
     var hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
     var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
     var hasw = app.kvdbs.get("HASW"); //hasw - device id to switch state
     var halv = app.kvdbs.get("HALV"); //halv - device id to lvl
     var hargb = app.kvdbs.get("HARGB"); //hargb - device id to rgb
     var hacw = app.kvdbs.get("HACW");
     var haowns = app.kvdbs.get("HAOWNS"); //haowns - prefix account hex to map of owned device ids
     var haof = app.kvdbs.get("HAOF"); //haof - device id pos to oif
     Map devices = Map.new();
     Map ctls = Map.new();
     Map specs = Map.new();
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
       String spec = haspecs.get(did);
       if (TS.notEmpty(spec)) {
         specs.put(did, spec);
       }
     }
     if (def(nextInform)) {
       Int nsecs = nextInform.seconds;
     } else {
       nsecs = 0;
     }
     var haposdm = app.kvdbs.get("HAPOSDM"); //position names dev id to json of names and ohter stuff
     Map haposn = haposdm.getMap();
     var hahid = app.kvdbs.get("HAHID");
     Map hahi = hahid.getMap();
     return(CallBackUI.getDevicesResponse(devices, ctls, specs, states, levels, rgbs, cws, oifs, haposn, hahi, nsecs));
   }

   updateSpec(String did, String controlHash) {
    log.log("in updateSpec " + did);

    String cmds = "doswspec spass e";
    //log.log("cmds " + cmds);

    Map mcmd = Maps.from("prio", 3, "cb", "updateSpecCb", "did", did, "pwt", 2, "cmds", cmds);
    if (TS.notEmpty(controlHash)) {
      mcmd.put("controlHash", controlHash);
    }

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
        if (cres.begins("controldef")) {
          log.log("pre swspec");
          haspecs.put(did, "1,q,p6,p2.gsh.4");
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
          pdevices = hadevs.getMap();
          if (TS.notEmpty(mcmd["controlHash"])) {
            log.log("got controlHash in updateSpecCb, saving");
            var hasccfs = app.kvdbs.get("HACCFS"); //hasccfs - device id to control hash
            hasccfs.put(did, mcmd["controlHash"]);
            sccfs.put(did, mcmd["controlHash"]);
            checkShareDevices(did, cres);
          }
          if (cres.has(",a1,")) {
            return(CallBackUI.setElementsDisplaysResponse(Maps.from("doVB", "block")));
            //return(CallBackUI.showVBReponse());
          }
          if (def(request)) {
            return(CallBackUI.reloadResponse());
          }
        } else {
          log.log("swspec got nonsense, doing default");
          haspecs.put(did, "1,q,p6,p2.gsh.4");
        }
      }
      return(null);
   }

   resolveTds(String did) {
    log.log("in resolveTds " + did);
    //find a did with t1

    var hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
    var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec

    List topt = List.new();
    for (any kv in hadevs.getMap()) {
      String odid = kv.key;
      String spec = haspecs.get(odid);
      if (TS.notEmpty(spec)) {
        if (spec.has(",t3,")) {
          unless (spec.has("nm,")) {
            topt += odid;
          }
        }
      }
    }
    if (topt.length > 0) {
      String godid = topt.get(System:Random.getIntMax(topt.length));
    }

    if (TS.isEmpty(godid)) {
      log.log("found no dev to try gettda for");
      return(null);
    }

    String confs = hadevs.get(did);
    Map conf = Json:Unmarshaller.unmarshall(confs);
    String dkdname = "CasNic" + conf["ondid"];

    String cmds = "gettda spass " + dkdname + " e";
    //log.log("cmds " + cmds);

    log.log("going to resolveTds sendDeviceMcmd");

    Map mcmd = Maps.from("prio", 3, "cb", "resolveTdsCb", "did", godid, "dkdname", dkdname, "pwt", 2, "cmds", cmds);

    if (backgroundPulse) {
      mcmd["runSync"] = true;
    }
    sendDeviceMcmd(mcmd);

    return(null);
   }

   resolveTdsCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String dkdname = mcmd["dkdname"];
     var haknc = app.kvdbs.get("HAKNC"); //kdname to addr
     if (TS.notEmpty(cres) && cres != "undefined" && cres != "ok") {
       log.log("resolveTdsCb got " + cres + " for " + dkdname);
       haknc.put(dkdname, cres);
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

   getLastEvents(String confs, Bool firstRun) {
     //log.log("in getLastEvents");

     try {
       Map conf = Json:Unmarshaller.unmarshall(confs);
     } catch (any e) {
       log.elog("error in gle", e);
       return(null);
     }
     String iv = System:Random.getString(16);
     //String cmds = "getlastevents q e";
     String cmds = "getlastevents q " + iv + "," + reId + " e";
     //log.log("cmds " + cmds);

     Map mcmd = Maps.from("prio", 5, "cb", "getLastEventsCb", "did", conf["id"], "pwt", 3, "cmds", cmds, "iv", iv);
     Int jit = System:Random.getIntMax(9);
     if (firstRun) { jit = 4; }
     if (jit > 2 && jit < 6) {  //4-8 seconds (av 6) per device try
       //in case something was remote or offline, every once in a while try local to see if back to local net
       mcmd["forceLocal"] = true;
       mcmd["smallFail"] = true;
     } elseIf (jit > 5) {
       //also see if should be cleared from remote fails from time to time
       mcmd["forceRemote"] = true;
       mcmd["smallFail"] = true;
     }

     if (backgroundPulse) {
       mcmd["runSync"] = true;
     }
     sendDeviceMcmd(mcmd);

     return(null);
   }

   getLastEventsCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String leid = mcmd["did"];
     if (mcmd.has("fromCmdsFail") && mcmd["fromCmdsFail"]) {
       Int ns = Time:Interval.now().seconds + 8;
       if (def(gletimes)) { gletimes.put(leid, ns); }
     }
     //log.log("!!!! gle fc " + fc + " " + leid);
     if (TS.notEmpty(cres) && cres.has(";")) {
        if (cres.has(" ") && cres.find(" ") < cres.find(";")) {
          //log.log("dropping iv,reid from gle res");
          cres = cres.substring(cres.find(" ") + 1, cres.length);
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
            } else {
              log.log("len changed removing leid");
              Bool cerm = true;
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
                psu = de.get(0) + "," + leid + "," + pos + "," + de.get(2);
                pendingStateUpdates += psu;
              }
            }
          }
        }
        if (def(cerm) && cerm) {
          currentEvents.remove(leid);
        } else {
          currentEvents.put(leid, cres);
        }
      } else {
        //log.log("getlastevents cres empty");
      }
     return(null);
   }

   updateSwState(String did, Int dp, String cname, String repsu) {
     log.log("in updateSwState " + did + " " + dp);

     var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
     String ctl = hactls.get(did);
     if (TS.isEmpty(ctl)) { return(null); }
     var ctll = ctl.split(",");
     String itype = ctll.get(dp);

     //dostate eek setsw on e
     Int dpd = dp - 1;

     //tcpjv edition

     //cmds += "\r\n";

     String iv = System:Random.getString(16);
     //cmds = "dostate q " + dpd + " getsw e";
     String cmds = "dostate q " + dpd + " getsw " + iv + "," + reId + " e";
     //log.log("cmds " + cmds);
     Map mcmd = Maps.from("prio", 4, "mw", 5, "cb", "updateSwStateCb", "did", did, "dp", dp, "pwt", 3, "itype", itype, "cname", cname, "cmds", cmds, "iv", iv);
     mcmd["repsu"] = repsu;
     if (backgroundPulse) {
       mcmd["runSync"] = true;
     }
     sendDeviceMcmd(mcmd);

     return(null);
   }

   deIvReidMCres(Map mcmd) {
     if (def(mcmd) && mcmd.has("pwt") && mcmd["pwt"] == 3) {
       String cres = mcmd["cres"];
       if (TS.notEmpty(cres) && cres.has(" ")) {
          //log.log("removing iv,reid in deIvReidMCres");
          cres = cres.substring(cres.find(" ") + 1, cres.length);
          mcmd["cres"] = cres;
       }
     }
   }

   updateSwStateCb(Map mcmd, request) Map {
     deIvReidMCres(mcmd);
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
              Mqtt mqtt = mqtts["haRelay"];
              if (def(mqtt) && mqtt.isOpen) {
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

   updateRgbState(String did, Int dp, String cname, String repsu) {
      log.log("in updateRgbState " + did + " " + dp);

      var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
      String ctl = hactls.get(did);
      if (TS.isEmpty(ctl)) { return(null); }
      var ctll = ctl.split(",");
      String itype = ctll.get(dp);

      //dostate eek setsw on e
      Int dpd = dp - 1;

      String iv = System:Random.getString(16);
      if (itype == "rgbgdim" || itype == "rgbcwgd" || itype == "rgbcwsgd") {
        //cmds = "getstatexd q " + dpd + " e";
        String cmds = "getstatexd q " + dpd + " " + iv + "," + reId + " e";
      } else {
        //cmds = "dostate q " + dpd + " getrgb e";
        cmds = "dostate q " + dpd + " getrgb " + iv + "," + reId + " e";
      }
      //log.log("cmds " + cmds);
      Map mcmd = Maps.from("prio", 4, "mw", 5, "cb", "updateRgbStateCb", "did", did, "dp", dp, "pwt", 3, "itype", itype, "cname", cname, "cmds", cmds, "iv", iv);
      mcmd["repsu"] = repsu;
      if (backgroundPulse) {
        mcmd["runSync"] = true;
      }
      sendDeviceMcmd(mcmd);

      return(null);
   }

   updateRgbStateCb(Map mcmd, request) Map {
     deIvReidMCres(mcmd);
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
              Mqtt mqtt = mqtts["haRelay"];
              if (def(mqtt) && mqtt.isOpen) {
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

   updateTempState(String did, Int dp, String cname, String repsu) {
      log.log("in updateRgbState " + did + " " + dp);

      var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
      String ctl = hactls.get(did);
      if (TS.isEmpty(ctl)) { return(null); }
      var ctll = ctl.split(",");
      String itype = ctll.get(dp);

      //dostate eek setsw on e
      Int dpd = dp - 1;

      String iv = System:Random.getString(16);
      //String cmds = "getstatexd q " + dpd + " e";
      String cmds = "getstatexd q " + dpd + " " + iv + "," + reId + " e";
      //log.log("cmds " + cmds);
      Map mcmd = Maps.from("prio", 4, "mw", 5, "cb", "updateTempStateCb", "did", did, "dp", dp, "pwt", 3, "itype", itype, "cname", cname, "cmds", cmds, "iv", iv);
      mcmd["repsu"] = repsu;
      if (backgroundPulse) {
        mcmd["runSync"] = true;
      }
      sendDeviceMcmd(mcmd);

      return(null);
   }



   updateTempStateCb(Map mcmd, request) Map {
     deIvReidMCres(mcmd);
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
              Mqtt mqtt = mqtts["haRelay"];
              if (def(mqtt) && mqtt.isOpen) {
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

   updateLvlState(String did, Int dp, String cname, String repsu) {
      log.log("in updateLvlState " + did + " " + dp);

      var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
      String ctl = hactls.get(did);
      if (TS.isEmpty(ctl)) { return(null); }
      var ctll = ctl.split(",");
      String itype = ctll.get(dp);

      //dostate eek setsw on e
      Int dpd = dp - 1;

      String iv = System:Random.getString(16);
      if (itype == "gdim") {
        //cmds = "getstatexd q " + dpd + " e";
        String cmds = "getstatexd q " + dpd + " " + iv + "," + reId + " e";
      } else {
        //cmds = "dostate q " + dpd + " getlvl e";
        cmds = "dostate q " + dpd + " getlvl " + iv + "," + reId + " e";
      }
      //log.log("cmds " + cmds);
      Map mcmd = Maps.from("prio", 4, "mw", 5, "cb", "updateLvlStateCb", "did", did, "dp", dp, "pwt", 3, "itype", itype, "itype", itype, "cname", cname, "cmds", cmds, "iv", iv);
      mcmd["repsu"] = repsu;
      if (backgroundPulse) {
        mcmd["runSync"] = true;
      }
      sendDeviceMcmd(mcmd);

      return(null);
   }

   updateLvlStateCb(Map mcmd, request) Map {
     deIvReidMCres(mcmd);
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
            Mqtt mqtt = mqtts["haRelay"];
            if (def(mqtt) && mqtt.isOpen) {
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

   updateOifState(String did, Int dp, String cname, String repsu) {
      log.log("in updateOifState " + did + " " + dp);

      var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
      String ctl = hactls.get(did);
      if (TS.isEmpty(ctl)) { return(null); }
      var ctll = ctl.split(",");
      String itype = ctll.get(dp);

      //dostate eek setsw on e
      Int dpd = dp - 1;

      String iv = System:Random.getString(16);
      //cmds = "dostate q " + dpd + " getoif e";
      String cmds = "dostate q " + dpd + " getoif " + iv + "," + reId + " e";
      //log.log("cmds " + cmds);
      Map mcmd = Maps.from("prio", 4, "mw", 5, "cb", "updateOifStateCb", "did", did, "dp", dp, "pwt", 3, "itype", itype, "cname", cname, "cmds", cmds, "iv", iv);
      mcmd["repsu"] = repsu;
      if (backgroundPulse) {
        mcmd["runSync"] = true;
      }
      sendDeviceMcmd(mcmd);

      return(null);
   }

   updateOifStateCb(Map mcmd, request) Map {
     deIvReidMCres(mcmd);
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

   manageStateUpdatesRequest(Bool doPulse, request) {

     fields {
       String lastError;
     }

     ifEmit(wajv) {
      slots {
        if (doPulse) {
          Int pulseCheck = Time:Interval.now().seconds;
        }
      }
     }

     if (doPulse && backgroundPulse) {
      log.log("disabling backgroundPulse");
      backgroundPulse = false;
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
         if (doPulse) {
          pulseDevices();
         }
       }
     }
     ifNotEmit(wajv) {
       if (doPulse) {
        pulseDevices();
       }
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
       Set pendingTds;
       Map currentEvents;
       Int pcount;
       Map pdevices; //hadevs cpy
       Map gletimes; //id to last getlastevents seconds
       Int lastRun;
     }

     Int ns = Time:Interval.now().seconds;

     if (undef(lastRun)) {
       lastRun = ns;
     }
     if (ns - lastRun > 40) {
       //log.log("lastRun a while ago doing");
       lastRun = ns;
       checkStartMqtt();
     }

     if (undef(pcount) || pcount > 9999) {
       pcount = 0;
     }
     pcount++;
     if (undef(pendingStateUpdates)) {
       pendingStateUpdates = Set.new();
     }
     if (undef(pendingTds)) {
       pendingTds = Set.new();
     }
     if (undef(currentEvents)) {
       currentEvents = Map.new();
     }
     if (undef(gletimes)) {
       gletimes = Map.new();
     }
     if (undef(pdevices)) {
       var hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
       pdevices = hadevs.getMap();
     }

     if (pcount % 3 == 0) {
      Set toDelTd = Set.new();
      if (def(pendingTds)) {
        for (k in pendingTds) {
            if (TS.notEmpty(k)) {
              try {
                resolveTds(k);
              } catch (e) {
                log.elog("Error resolving Tds", e);
              }
              toDelTd += k;
              break;
            }
          }
        }
        for (k in toDelTd) {
          pendingTds.remove(k);
        }
        if (toDelTd.notEmpty) {
          return(null);
        }
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
                  updateSwState(ks[1], Int.new(ks[2]), ks[0], k);
                } elseIf (ks[0] == "dim" || ks[0] == "gdim") {
                  updateSwState(ks[1], Int.new(ks[2]), ks[0], k);
                  updateLvlState(ks[1], Int.new(ks[2]), ks[0], k);
                } elseIf (ks[0] == "pwm") {
                  updateLvlState(ks[1], Int.new(ks[2]), ks[0], k);
                } elseIf (ks[0] == "rgb" || ks[0] == "rgbgdim" || ks[0] == "rgbcwgd" || ks[0] == "rgbcwsgd") {
                  updateSwState(ks[1], Int.new(ks[2]), ks[0], k);
                  updateRgbState(ks[1], Int.new(ks[2]), ks[0], k);
                } elseIf (ks[0] == "cwgd") {
                  updateSwState(ks[1], Int.new(ks[2]), ks[0], k);
                  updateTempState(ks[1], Int.new(ks[2]), ks[0], k);
                } elseIf (ks[0] == "oui") {
                  updateOifState(ks[1], Int.new(ks[2]), ks[0], k);
                  //updateOuiState(ks[1], Int.new(ks[2]), ks[0]);
                } elseIf (ks[0] == "sccf") {
                  checkUpdateSccf(ks[1], ks[3]);
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

      ns = Time:Interval.now().seconds;
      //Int glesecs = 4 + System:Random.getIntMax(4);
      Int glesecs = 7 + System:Random.getIntMax(2);
      //Int glesecs = 9 + System:Random.getIntMax(3);
      if (def(pdevices) && def (gletimes)) {
        //log.log("in gletimes");
        for (var pdc in pdevices) {
          //log.log("in devices");
          Int dc = gletimes.get(pdc.key);
          if (undef(dc)) {
            //log.log("no dc");
            //gletimes.put(pdc.key, ns);
            dc = 0;
          } else {
            //log.log("got dc " + dc);
          }
          Int nsdiff = ns - dc;
          //log.log("nsdiff " + nsdiff + " glesecs " + glesecs + " ns " + ns);
          if (nsdiff > glesecs) {
            //log.log("gonna gle");
            gletimes.put(pdc.key, ns);
            Map conf = Json:Unmarshaller.unmarshall(pdc.value);
            String did = conf["id"];
            if (dc == 0) { //firstrun force local to get to using local asap if available
              getLastEvents(pdc.value, true);
            } else {
              getLastEvents(pdc.value, false);
            }
            break;
          }
        }
      }
   }

   checkUpdateSccf(String did, String controlHash) {
     slots {
       Map sccfs;
     }
     if (undef(sccfs)) {
       sccfs = Map.new();
     }
     if (TS.notEmpty(did) && TS.notEmpty(controlHash)) {
       log.log("in checkUpdateSccf for " + did + " " + controlHash);
       String oldch = sccfs.get(did);
       if (TS.isEmpty(oldch)) {
         log.log("no oldch for did inmem");
         var hasccfs = app.kvdbs.get("HACCFS"); //hasccfs - device id to control hash
         oldch = hasccfs.get(did);
         if (TS.notEmpty(oldch)) {
           log.log("oldch for did in kvdb, updating mem");
           sccfs.put(did, oldch);
         }
       }
     } else {
       log.log("did or controlHash empty");
     }
     if (TS.isEmpty(oldch) || oldch != controlHash) {
       log.log("detected new controlHash, rectling");
       rectlDeviceRequest(did, controlHash, null);
     } else {
       log.log("no ch change");
     }
   }

   initializeDiscoveryListener() {
     ifEmit(jvad) {
     emit(jv) {
       """
         wifi = (WifiManager) be.BEC_3_2_4_10_UIJvAdWebBrowser.MainActivity.appContext.getSystemService(Context.WIFI_SERVICE);
         multicastLock = wifi.createMulticastLock("CasnicDiscover");
         multicastLock.setReferenceCounted(true);

        // Instantiate a new DiscoveryListener
        discoveryListener = new NsdManager.DiscoveryListener() {

          // Called as soon as service discovery begins.
          @Override
          public void onDiscoveryStarted(String regType) {
              System.out.println("Service discovery started");
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
                if (InitializeResolveListener.wantedDevices.containsKey(sname)) {
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
   }

   runDiscoveryInnerJvad() {
      log.log("maybe runDiscoveryInnerJvad");
      unless (inDiscovery.o) {
        log.log("try runDiscoveryInnerJvad");
        try {
          log.log("starting discovery");
          inDiscovery.o = true;
          startDiscovery();
          log.log("started discovery");
          Time:Sleep.sleepSeconds(10);
          log.log("discovery sleep done");
          stopDiscovery();
          log.log("stopped discovery");
          Time:Sleep.sleepSeconds(5);
          inDiscovery.o = false;
        } catch (any e) {
          inDiscovery.o = false;
          log.log("except in runDiscoveryInnerJvad");
        }
      }
   }

   startDiscovery() {
     ifEmit(jvad) {
     emit(jv) {
       """
       try {
        multicastLock.acquire();
        nsdManager = (NsdManager) be.BEC_3_2_4_10_UIJvAdWebBrowser.MainActivity.appContext.getSystemService(Context.NSD_SERVICE);
        nsdManager.discoverServices(
        "_casnic._tcp.", NsdManager.PROTOCOL_DNS_SD, discoveryListener);
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
       multicastLock.release();
       if (nsdManager != null) {
         nsdManager.stopServiceDiscovery(discoveryListener);
       }
       } catch (Exception e) { }
       """
     }
     }
   }

   updateWifiRequest(String did, request) Map {
     log.log("in updateWifiRequest " + did);

     //Account account = request.context.get("account");
     var uhex = Hex.encode("Adrian");

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

   updateMqttRequest(String did, request) Map {
     log.log("in updateMqttRequest " + did);

      Map mqr = loadMqtt("relay");
      //TS.notEmpty(mqr["mqttBroker"]) && TS.notEmpty(mqr["mqttUser"]) && TS.notEmpty(mqr["mqttPass"])
      String bkr = mqr["mqttBroker"];
      bkr = bkr.swap("//", "");
      bkr = bkr.swap(" ", "");
      String cmds = "setsmc pass nohex " + bkr + " " + mqr["mqttUser"] + " " + mqr["mqttPass"] + " e";


     Map mcmd = Maps.from("prio", 2, "cb", "updateMqttCb", "did", did, "pwt", 1, "cmds", cmds);
     sendDeviceMcmd(mcmd);

     return(null);
   }

   updateMqttCb(Map mcmd, request) Map {
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

   reshareDevicesRequest(request) {
     var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
     Map hasp = haspecs.getMap();
     for (any kv in hasp) {
      String sws = kv.value;
      if (TS.notEmpty(sws) && (sws.has(",a1,") || sws.has(",h1,"))) {
        checkShareDevices(kv.key, sws);
        break;
      }
     }
     return(CallBackUI.closeSettingsResponse());
   }

   disTasRequest(request) {
     log.log("in disTasRequest");
     var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
     Map hasp = haspecs.getMap();
     for (any kv in hasp) {
      String sws = kv.value;
      if (TS.notEmpty(sws) && sws.has(",gt1,")) {
        String cmds = "tacmd pass startdis e";
        Map mcmd = Maps.from("prio", 2, "cb", "tasCb", "did", kv.key, "pwt", 1, "cmds", cmds);
        sendDeviceMcmd(mcmd);
      }
     }
     return(null);
   }

   clearTasRequest(request) {
     log.log("in disTasRequest");
     var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
     Map hasp = haspecs.getMap();
     for (any kv in hasp) {
      String sws = kv.value;
      if (TS.notEmpty(sws) && sws.has(",gt1,")) {
        String cmds = "tacmd pass clear e";
        Map mcmd = Maps.from("prio", 2, "cb", "tasCb", "did", kv.key, "pwt", 1, "cmds", cmds);
        sendDeviceMcmd(mcmd);
      }
     }
     return(null);
   }

   tasCb(Map mcmd, request) {
     String cres = mcmd["cres"];
     String did = mcmd["did"];
     if (TS.notEmpty(cres)) {
        log.log("tasCb got cres " + cres);
        if (def(request)) {
          return(CallBackUI.closeSettingsResponse());
        }
      }
      return(null);
   }

   checkShareDevices(String did, String spec) {
     log.log("in checkShareDevices");
     Bool wasBridge = false;
     if (spec.has(",a1,") || spec.has(",h1,")) {
        log.log("it's a bridge, sharing all to it");
        wasBridge = true;
        var hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
        for (any kv in hadevs.getMap()) {
          String didk = kv.key;
          unless (didk == did) {
              checkShareDevice(didk);
          }
        }
     } else {
       log.log("it's not a bridge sharing to bridges");
       checkShareDevice(did);
     }
     //do the redact here if it was all
     if (wasBridge) {
       brd("rmold", did, null, null);
     }
     brd("chrestart", did, null, null);
    }

   checkShareDevice(String did) {
     log.log("in checkShareDevice " + did);
     String ashare = app.configManager.get("vshare.autoShare");
     if (TS.isEmpty(ashare) || ashare == "on") {
      var havsh = app.kvdbs.get("HAVSH"); //havsh - device id to voice autoshare
      String vsc = havsh.get(did);
      if (TS.isEmpty(vsc) || vsc == "isok") {
        brd("share", did, null, null);
      }
     }
   }

   unshareFromBridgeRequest(String sdid, String forPos, request) Map {
     var havsh = app.kvdbs.get("HAVSH"); //havsh - device id to voice autoshare
     havsh.put(sdid, "notok");
     brd("unshare", sdid, forPos, request);
     brd("chrestart", sdid, null, request);
     return(CallBackUI.closeSettingsResponse());
   }

   shareToBridgeRequest(String sdid, String forPos, request) Map {
     var havsh = app.kvdbs.get("HAVSH"); //havsh - device id to voice autoshare
     havsh.put(sdid, "isok");
     brd("share", sdid, forPos, request);
     brd("chrestart", sdid, null, request);
     return(CallBackUI.closeSettingsResponse());
   }

   brd(String act, String sdid, String forPos, request) Map {
     log.log("in brd " + act + " " + sdid);

     String sconf;
     String gdid;
     var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
     var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
     var hadevs = app.kvdbs.get("HADEVS"); //hadevs - device id to config
     Map hads = hadevs.getMap();
     sconf = hads.get(sdid);
     Map conf = Json:Unmarshaller.unmarshall(sconf);
     String ctl = hactls.get(sdid);
     for (any kv in hads) {
      String did = kv.key;
      String dconfs = kv.value;
      String sws = haspecs.get(did);
      if (TS.notEmpty(sws) && (sws.has(",a1,") || sws.has(",h1,"))) {
        gdid = did;
        if (act == "chrestart") {
          cmds = "brd pass chrestart e";
          Map mcmd = Maps.from("prio", 2, "cb", "brdCb", "did", gdid, "pwt", 1, "mw", 8, "act", act, "cmds", cmds);
          sendDeviceMcmd(mcmd);
        } elseIf(act == "rmold") {
          cmds = "brd pass rmold e";
          mcmd = Maps.from("prio", 2, "cb", "brdCb", "did", gdid, "pwt", 1, "mw", 8, "act", act, "cmds", cmds);
          sendDeviceMcmd(mcmd);
        } else {
          //brd pass add ool ondid 0 spass e
          if (TS.notEmpty(ctl)) {
            var ctll = ctl.split(",");
            log.log("got ctl " + ctl);
            for (Int i = 1;i < ctll.length;i++) {
              if (def(mcmd)) {
                sendDeviceMcmd(mcmd);
                mcmd = null;
              }
              String itype = ctll.get(i);
              log.log("got ctled itype " + itype + " pos " + i);
              String etype;
              if (itype == "sw" || itype == "rgbcwsgd" || itype == "rgbcwgd") { etype = "ool"; }
              if (itype == "gdim") { etype = "dl"; }
              if (itype == "rgbcwsgd") { etype = "ecl"; }
              if (itype == "rgbcwgd") { etype = "eclns"; }
              if (TS.notEmpty(etype)) {
                Int ipos = i.copy();
                //forPos equivalence check is before subtraction
                if (TS.isEmpty(forPos) || forPos == i.toString()) {
                  ipos--;
                  if (act == "share") {
                    String cmds = "brd pass add " + etype + " " + conf["ondid"] + " " + ipos + " " + conf["spass"] + " e";
                  } else {
                    cmds = "brd pass rm " + etype + " " + conf["ondid"] + " " + ipos + " " + " e";
                  }
                  mcmd = Maps.from("prio", 2, "cb", "brdCb", "did", gdid, "pwt", 1, "mw", 8, "act", act, "cmds", cmds);
                }
              }
            }
            if (def(mcmd)) {
              sendDeviceMcmd(mcmd);
              mcmd = null;
            }
          }
        }
      }
     }
     return(null);
   }

   brdCb(Map mcmd, request) Map {
     String cres = mcmd["cres"];
     String did = mcmd["did"];
     if (TS.notEmpty(cres) && cres.has("brdok")) {
        log.log("got good maprep cres " + cres);
      }
      //if (def(request)) {
      //  return(CallBackUI.reloadResponse()); //ios won't process the restart request, it will restart in the restartdev callback anyway
      //}
      return(null);
   }

   restartDevRequest(String did, request) Map {
     log.log("in restartDevRequest " + did);

     String cmds = "restart pass e";

     //tcpjv edition

     //cmds += "\r\n";

     Map mcmd = Maps.from("prio", 3, "cb", "restartDevCb", "did", did, "pwt", 1, "cmds", cmds);
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

   rectlDeviceRequest(String did, String controlHash, request) Map {
     log.log("in rectlDeviceRequest " + did);

     //dostate eek setsw on e
     String cmds = "getcontroldef spass e";
     //log.log("cmds " + cmds);

     //tcpjv edition

     //cmds += "\r\n";

     Map mcmd = Maps.from("prio", 2, "cb", "rectlDeviceCb", "did", did, "pwt", 2, "cmds", cmds);
     if (TS.notEmpty(controlHash)) {
       mcmd.put("controlHash", controlHash);
     }
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

      //if (def(request)) {
      //  return(CallBackUI.reloadResponse());
      //}
      updateSpec(did, mcmd["controlHash"]);
      if (TS.notEmpty(controlDef)) {
        var hactls = app.kvdbs.get("HACTLS"); //hadevs - device id to ctldef
        hactls.put(did, controlDef);
        ifEmit(wajv) {
          setupMqttDevices("haRelay");
          setupMqttDevices("relay");
        }
      }
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
     mcmd["mw"] = 3;
     //mcmd["mw"] = 5;

     Bool preempt = false;
     if (def(request)) {
      Map hcc = currCmds;
      if (def(hcc) && TS.notEmpty(hcc["did"]) && def(hcc["prio"]) && def(mcmd) && TS.notEmpty(mcmd["did"])) {
        log.log("past preempt 1 " + hcc["prio"] + " " + hcc["did"] + " " + mcmd["did"]);
        unless (def(mcmd["runSync"]) && mcmd["runSync"]) {
          log.log("will prempt!!!!!");
          preempt = true;
          if (TS.notEmpty(hcc["repsu"])) {
            pendingStateUpdates += hcc["repsu"];
          }
        } else {
          log.log("not preempt 2");
        }
      }
     }

     if (sendDeviceMcmd(mcmd)!) {
       if (def(request)) {
         return(CallBackUI.setElementsDisplaysResponse(Maps.from("devErr", "block")));
       }
     } else {
       //if (def(request)) {
       //  return(CallBackUI.setElementsDisplaysResponse(Maps.from("devErr", "none")));
       //}
     }

     if (preempt) {
      log.log("preempting now!!!!!");
      currCmds = null;
     }
    Map mres = processCmdsRequest(request);
    if (def(mres)) {
      return(mres);
    }

     return(CallBackUI.setElementsDisplaysResponse(Maps.from("devErr", "none")));
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
        Mqtt mqtt = mqtts["haRelay"];
        if (def(mqtt) && mqtt.isOpen) {
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
        Mqtt mqtt = mqtts["haRelay"];
        if (def(mqtt) && mqtt.isOpen) {
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
        Mqtt mqtt = mqtts["haRelay"];
        if (def(mqtt) && mqtt.isOpen) {
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
     log.log("in cwForCwLvlWs lvl " + lvl + " cw " + cw);

     //straight up lvl and temp

     Int lvli = Int.new(lvl);
     if (lvli < 0 || lvli > 255) { lvli = 255; }
     if (lvli == 1) { lvli = 2; } //cws seems to be off at analog write 1
     Int cwi = Int.new(cw);
     if (cwi < 0 || cwi > 255) { cwi = 255; }
     cwi = 255 - cwi;

     String res = lvli.toString() + "," + cwi.toString();
     log.log("cwForCwLvlWs lvli cwi " + res);
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
        Mqtt mqtt = mqtts["haRelay"];
        if (def(mqtt) && mqtt.isOpen) {
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
      Int ns = Time:Interval.now().seconds;
      Int aptrs = currCmds["aptrs"];
      if (undef(aptrs)) {
        aptrs = ns;
        currCmds["aptrs"] = aptrs;
      }
      Int runSecs = currCmds["runSecs"];
      if (undef(runSecs)) { runSecs = 4; }
      if (ns - aptrs > runSecs) { //howmany secs to wait, was counting 1/4 seconds and 16 so 4, starting there
        //timed out
        mcmd = currCmds;
        log.log("failing in aptrs " + aptrs + " " + ns);
        currCmds = null;
        return(processCmdsFail(mcmd, request));
      }
           String jvadCmdsRes;
           jvadCmdsRes = currCmds["creso"].o;
           if (TS.notEmpty(jvadCmdsRes)) {
             currCmds["cres"] = jvadCmdsRes;
           }

        ifEmit(apwk) {
          unless (def(currCmds["doRemote"]) && currCmds["doRemote"]) {
          if (undef(currCmds["cres"])) {
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
       }
     }

     if (def(currCmds) && def(currCmds["cres"])) {
       //log.log("CRES " + currCmds["cres"]);
       if (def(currCmds["pwt"]) && currCmds["pwt"] > 0) {
        //log.log("pwt " + currCmds["pwt"]);
        String rescres = currCmds["cres"];
        Int rf1 = rescres.find(" ");
        if (def(rf1)) {
            String resivcr = rescres.substring(0, rf1);
            Int rf2 = resivcr.find(",");
            if (def(rf2)) {
              String resiv = resivcr.substring(0, rf2);
              //log.log("resivcr |" + resivcr + "| resiv |" + resiv + "|");
              //if (TS.notEmpty(currCmds["iv"])) { log.log("currCmdsIv " + currCmds["iv"]); }
            }
        }
        if (TS.notEmpty(currCmds["iv"]) && TS.notEmpty(resiv) && resiv == currCmds["iv"]) {
          mcmd = currCmds;
          //log.log("got currCmds n cres will process res");
          currCmds = null;
          return(processMcmdRes(mcmd, request));
        } else {
          log.log("diff iv, preempted!!!!!!!!!!!!!!!!");
          if (def(currCmds["creso"])) { currCmds["creso"].o = null; }
          currCmds["cres"] = null;
        }
       } else {
         log.log("no iv check");
         mcmd = currCmds;
         //log.log("got currCmds n cres will process res");
         currCmds = null;
         return(processMcmdRes(mcmd, request));
       }
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
                  //log.log("doing remote");
                  String finCmds = prot.secCmds(mcmd);
                  Mqtt mqtt = mqtts["remote"];
                  if (def(mqtt) && mqtt.isOpen) {
                    if (TS.notEmpty(mcmd["spec"]) && mcmd["spec"].has(",dm,")) {
                      log.log("doing direct smc");
                      mqtt.publish("casnic/cmd/" + mcmd["ondid"], finCmds);
                    } else {
                      log.log("doing proxy smc");
                      finCmds = "rel1:" + mcmd["kdname"] + ";" + finCmds;
                      mqtt.publish("casnic/cmds", finCmds);
                    }
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

   shareToMqttRequest(String shBlob, request) {
     log.log("try publishing shBlob to mqtt");
     Mqtt mqtt = mqtts["remote"];
     if (def(mqtt) && mqtt.isOpen) {
       mqtt.publish("casnic/shares", shBlob);
       log.log("share published");
     }
   }

   processMcmdRes(Map mcmd, request) {
       unless (mcmd.has("fromCmdsFail") && mcmd["fromCmdsFail"]) {
         if (TS.notEmpty(mcmd["kdaddr"])) {
           locAddrs.put(mcmd["kdaddr"]);
         } elseIf (TS.notEmpty(mcmd["kdname"])) {
           var harfails = app.kvdbs.get("HARFAILS"); //harfails - kdname to remote failing
           harfails.remove(mcmd["kdname"]);
         }
       }
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
         if (def(pver) && pver > 4 && def(pwt) && pwt > 0 && TS.notEmpty(pw) && TS.notEmpty(iv) && TS.notEmpty(cres)) {
           if (pver == 5) {
             log.log("will decrypt cres");
             cres = Encode:Hex.decode(cres);
             cres = Crypt.decrypt(iv, pw, cres);
             log.log("decrypted cres" + cres);
             mcmd["cres"] = cres;
           } else {
             log.log("will pull iv,reid off cres |" + cres + "|");
             cres = cres.substring(cres.find(" ") + 1, cres.length);
             log.log("final cres |" + cres + "|");
             mcmd["cres"] = cres;
           }
         }
         return(self.invoke(mcmd["cb"], Lists.from(mcmd, request)));
       }
       return(null);
   }

   clearQueueDid(String did) {
     //clear pending
      for (var kv in cmdQueues) {
        Container:LinkedList cmdQueue = kv.value;
        if (def(cmdQueue) && kv.key > 1) {
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
    String kdaddr = mcmd["kdaddr"];
    String kdname = mcmd["kdname"];
    if (def(mcmd["smallFail"]) && mcmd["smallFail"]) {
      if (mcmd.has("cb")) {
         mcmd["fromCmdsFail"] = true;
         return(processMcmdRes(mcmd, request));
       }
      return(null);
    }
    if (TS.notEmpty(did)) {
      if (def(currentEvents)) {
        log.log("in cmds fail clearing currentEvents for did " + did);
        currentEvents.remove(did);
      }
      if (TS.notEmpty(kdaddr)) {
        locAddrs.remove(kdaddr);
      } elseIf (TS.notEmpty(kdname)) {
        var harfails = app.kvdbs.get("HARFAILS"); //harfails - kdname to remote failing
        harfails.put(kdname, kdname);
      }
      clearQueueDid(did);
     }

     //?failre / timeout callback?

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
         mcmd["fromCmdsFail"] = true;
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
          //log.log("ondid " + conf["ondid"]);
          String kdname = "CasNic" + conf["ondid"];
          String kdaddr = getAddrDis(kdname);
          mcmd["kdname"] = kdname;
          mcmd["kdaddr"] = kdaddr;
          mcmd["ondid"] = conf["ondid"];
          var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
          String sws = haspecs.get(did);
          if (TS.isEmpty(sws)) {
            sws = "1,q,p6,p2.gsh.4";
          }
          //log.log("sws " + sws);
          mcmd["spec"] = sws;
          if (sws.has(".") && sws.has(",")) {
            sws = sws.substring(0, sws.find("."));
            var swl = sws.split(",");
            for (var swe in swl) {
              //log.log("swe " + swe);
              if (swe.begins("p")) {
                Int sp = Int.new(swe.substring(1, swe.length));
                //log.log("sp " + sp);
                if (undef(spm) || spm < sp) {
                  Int spm = sp;
                }
              }
            }
          }
          if (def(spm)) {
            //log.log("spm " + spm);
            mcmd["pver"] = spm;
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
        Mqtt mqtt = mqtts["remote"];
        if (def(mqtt) && mqtt.isOpen) {
          if (mqttFullRemote) {
            doRemote = true;
          } else {
            unless (TS.notEmpty(mcmd["kdaddr"]) && locAddrs.has(mcmd["kdaddr"])) {
              var harfails = app.kvdbs.get("HARFAILS"); //harfails - kdname to remote failing
              unless (TS.notEmpty(mcmd["kdname"]) && harfails.has(mcmd["kdname"])) {
                unless (TS.isEmpty(did) || TS.isEmpty(sws) || sws.has(".gsh.")) {
                  if (TS.notEmpty(sws) && sws.has(",dm,")) {
                    doRemote = true;
                  }
                  if (def(haveGm) && haveGm) {
                    doRemote = true;
                  }
                }
              }
            }
          }
          if (mcmd.has("forceRemote") && mcmd["forceRemote"]) {
            //log.log("got forceRemote");
            if (TS.notEmpty(sws) && sws.has(",dm,")) {
              doRemote = true;
            }
            if (def(haveGm) && haveGm) {
              doRemote = true;
            }
          }
        }
        if (mcmd.has("forceLocal") && mcmd["forceLocal"]) {
          //log.log("got forceLocal");
          doRemote = false;
        }
        mcmd.put("doRemote", doRemote);
        //log.log("doRemote " + doRemote);
        if (doRemote) {
          mcmd.remove("kdaddr");
        }
        if (doRemote) {
          if (TS.notEmpty(mcmd["kdname"]) && TS.notEmpty(mcmd["cmds"])) {
            mcmd.remove("runSync");
          } else {
            return(false);
          }
        }
        Int priority = mcmd["prio"];
        if (undef(priority)) {
          log.log("prio undefined in sendDeviceMcmd");
          priority = 5;
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
      mcmd["pver"] = 6;
    }
    unless (mcmd.has("iv")) {
      mcmd["iv"] = System:Random.getString(16);
    }
    mcmd["reid"] = reId;
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

   findNewDevicesDf(request) {
     slots {
       Set dfnets; //set no marshall
       Int dfnetsPos;
       String dfdid;
       Bool foundDf;
       Bool failedDfCb;
       Bool dfWorks;
     }
     if (TS.isEmpty(dfdid)) {
      dfnets = Set.new();
      var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec

      List topt = List.new();
      for (any kv in haspecs.getMap()) {
        String odid = kv.key;
        String spec = kv.value;
        if (TS.notEmpty(spec)) {
          if (spec.has(",df,")) {
            topt += odid;
          }
        }
      }
      if (topt.length > 0) {
        String godid = topt.get(System:Random.getIntMax(topt.length));
      }

      if (TS.isEmpty(godid)) {
        log.log("found no dev to try findNewDevicesDf for");
        foundDf = false;
        return(null);
      }
      foundDf = true;
      dfdid = godid;
     }

    if (undef(dfnetsPos)) {
       String cmds = "dfvisnets pass S e";
       dfnetsPos = 0;
     } else {
       cmds = "dfvisnets pass " + dfnetsPos + " e";
     }
     Map mcmd = Maps.from("runSecs", 10, "prio", 1, "mw", 1, "forceLocal", true, "cb", "dfCb", "did", dfdid, "pwt", 1, "cmds", cmds);
     sendDeviceMcmd(mcmd);
     return(null);
   }

   dfCb(Map mcmd, request) {
     String cres = mcmd["cres"];
     if (TS.notEmpty(cres)) {
       log.log("dfCb cres " + cres);
     }
     if (TS.notEmpty(cres) && cres.has("ssids")) {
        if (cres.has(":")) {
           List ssp = cres.split(":");
           for (Int i = 1;i < ssp.length;i++) {
             String vna = Encode:Hex.decode(ssp[i]);
             log.log("got vna " + vna);
             dfnets.put(vna);
             lastSsids.addValue(dfnets);
             dfWorks = true;
             dfnetsPos++;
           }
        } else {
          //done
          log.log("got no : ssids, dfCb is done");
          lastSsids.addValue(dfnets);
          dfnetsPos = null;
        }
      } else {
        //failed
        unless(failedDfCb) {
          if (lastSsids.isEmpty) {
            log.log("failed and lasssids empty setting to fail");
            failedDfCb = true;
          } else {
            log.log("failed in dfcb but lastssids not empty");
          }
        }
        log.log("got a fail in dfCb");
      }
      return(null);
   }

   findNewDevicesRequest(Bool startingDiscover, request) Map {
       log.log("in find new devices");
       if (startingDiscover) {
         log.log("in startingDiscover");
         dfdid = null;
         foundDf = false;
         failedDfCb = false;
         dfWorks = null;
         lastSsids = Set.new();
         dfnetsPos = null;
         inOutset = false;
         findNewDevicesDf(request);
         return(null);
       }
        slots {
          Set lastSsids;
          Bool inOutset;
        }
        Bool giveDfTry = true;
        unless (foundDf) {
          log.log("found df false");
          giveDfTry = false;
        }
        if (failedDfCb) {
          log.log("failed dfcb");
          giveDfTry = false;
        }
        if (giveDfTry) {
          log.log("giveDfTry");
          findNewDevicesDf(request);
        } else {
          log.log("no giveDfTry");
          ifEmit(platDroid) {
            findNewDevicesAndroid(request);
          }
        }
        //return(displayNextDeviceRequest("", request));
        return(null);
   }

   findNewDevicesAndroid(request) {
     ifEmit(platDroid) {
       Set ssids = Set.new();
       String ssid;
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
        lastSsids = ssids;
        }
        log.log("find new devices startscan done");
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

     //Account account = request.context.get("account");
     var uhex = Hex.encode("Adrian");
     var hawifi = app.kvdbs.get("HAWIFI"); //account hex to wifi network

     String ssid = hawifi.get(uhex + ".ssid.0");
     String sec = hawifi.get(uhex + ".sec.0");
     if (undef(ssid)) { ssid = ""; }
     if (undef(sec)) { sec = ""; }

     if (TS.notEmpty(dfdid) && def(dfWorks) && dfWorks) {
       log.log("doing df skipping getDevWifis");
       count.setValue(tries);
       return(CallBackUI.getDevWifisResponse(count, tries, wait));
     }

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

     if (starting) {
       cmds = "previsnets S e";
     } else {
       String cmds = "previsnets " + visnetsPos + " e";
     }
     Map mcmd = Maps.from("prio", 1, "mw", 1, "cb", "previsnetsCb", "kdaddr", "192.168.4.1", "pwt", 0, "forceLocal", true, "cmds", cmds);
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
     if (TS.notEmpty(dfdid) && def(dfWorks) && dfWorks) {
       log.log("doing df skipping getOnWifi");
       return(CallBackUI.getOnWifiResponse(tries, tries, wait));
     }
     ifNotEmit(jvad) {
       if (true) {
        return(CallBackUI.getOnWifiResponse(tries, tries, wait));
       }
     }
     unless (devSsid.begins("OCasnic-") || devSsid.begins("CasnicO-")) {
       String sec = devPin.substring(8, 16);
     }

     //log.log("in getOnWifiRequest " + devPin + " " + devSsid);

     lastSsids = Set.new();
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

   outsetCb(Map mcmd, request) Map {
     log.log("in outsetCb");
     String cres = mcmd["cres"];
     if (TS.notEmpty(cres)) {
       log.log("outsetCb cres " + cres);
     }
     if (TS.notEmpty(cres) && cres.has("success")) {
       log.log("got success in outsetCb");
       return(CallBackUI.reloadResponse());
     }
     if (TS.notEmpty(cres) && cres.has("failed")) {
       log.log("got failed in outsetCb");
       if (TS.notEmpty(cres) && cres.has("pass is incorrect")) {
          deleteDeviceRequest(mcmd["outdid"], request);
          throw(Alert.new("Device is already configured, reset before setting up again."));
       } elseIf (TS.notEmpty(cres) && cres.has("mins of power on")) {
          deleteDeviceRequest(mcmd["outdid"], request);
          throw(Alert.new("Error, must setup w/in 30 mins of power on. Unplug and replug in device and try again"));
       }
       return(CallBackUI.reloadResponse());
     }
     return(null);
   }

   allsetRequest(Int count, String devName, String devType, String devPin, String disDevSsid, String disDevId, String devPass, String devSpass, String devDid, String devSsid, String devSec, request) {
      Int tries = 200;
      Int wait = 1000;
      count++;
      slots {
        String alStep;
      }

      //Account account = request.context.get("account");
      var uhex = Hex.encode("Adrian");

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
          Map conf = Map.new();
          conf["type"] = devType;
          conf["id"] = disDevId;
          conf["ondid"] = devDid;
          conf["name"] = devName;
          conf["pass"] = devPass;
          conf["spass"] = devSpass;
          String confs = Json:Marshaller.marshall(conf);
          saveDeviceRequest(conf["id"], confs, request);

          if (TS.notEmpty(dfdid) && def(dfWorks) && dfWorks) {
            if (def(inOutset) && inOutset) {
              log.log("in outset getting status");
              cmds = "dfis pass status e";
              mcmd = Maps.from("prio", 1, "mw", 1, "forceLocal", true, "cb", "outsetCb", "outdid", disDevId, "did", dfdid, "pwt", 1, "cmds", cmds);
              sendDeviceMcmd(mcmd);
            } else {
              inOutset = true;
              log.log("df is working should now do outset");
              cmds = "dfis pass outset " + disDevSsid + " " + devPin + " " + devPass + " " + devSpass + " " + devDid + " e";
              mcmd = Maps.from("prio", 1, "mw", 1, "forceLocal", true, "cb", "outsetCb", "outdid", disDevId, "did", dfdid, "pwt", 1, "cmds", cmds);
              sendDeviceMcmd(mcmd);
            }
          } else {
            log.log("not doing df doing allset");
            cmds = "allset " + devPin + " " + devPass + " " + devSpass + " " + devDid + " e";
            mcmd = Maps.from("prio", 1, "mw", 1, "cb", "allsetCb", "disDevId", disDevId, "kdaddr", "192.168.4.1", "pwt", 0, "forceLocal", true, "cmds", cmds);
            sendDeviceMcmd(mcmd);
          }
        /*} elseIf (alStep == "getcontroldef") {
          cmds = "getcontroldef " + devSpass + " e";
          mcmd = Maps.from("prio", 1, "mw", 1, "cb", "allsetCb", "disDevId", disDevId, "kdaddr", "192.168.4.1", "pwt", 0, "forceLocal", true, "cmds", cmds);
          sendDeviceMcmd(mcmd);
        } elseIf (alStep == "doswspec") {
          cmds = "doswspec " + devSpass + " e";
          mcmd = Maps.from("prio", 1, "mw", 1, "cb", "allsetCb", "disDevId", disDevId, "kdaddr", "192.168.4.1", "pwt", 0, "forceLocal", true, "cmds", cmds);
          sendDeviceMcmd(mcmd);
        } elseIf (alStep == "setsmcr") {
          Map mqr = loadMqtt("relay");
          //TS.notEmpty(mqr["mqttBroker"]) && TS.notEmpty(mqr["mqttUser"]) && TS.notEmpty(mqr["mqttPass"])
          String bkr = mqr["mqttBroker"];
          bkr = bkr.swap("//", "");
          bkr = bkr.swap(" ", "");
          cmds = "setsmc " + devPass + " nohex " + bkr + " " + mqr["mqttUser"] + " " + mqr["mqttPass"] + " e";
          mcmd = Maps.from("prio", 1, "mw", 1, "cb", "allsetCb", "disDevId", disDevId, "kdaddr", "192.168.4.1", "pwt", 0, "forceLocal", true, "cmds", cmds);
          sendDeviceMcmd(mcmd);*/
        } elseIf (alStep == "setwifi") {
          cmds = "setwifi " + devPass + " hex " + devSsid + " " + devSec + " e";
          mcmd = Maps.from("prio", 1, "mw", 1, "cb", "allsetCb", "disDevId", disDevId, "kdaddr", "192.168.4.1", "pwt", 0, "forceLocal", true, "cmds", cmds);
          sendDeviceMcmd(mcmd);
        } elseIf (alStep == "restart") {
          cmds = "restart " + devPass + " e";
          mcmd = Maps.from("prio", 1, "mw", 1, "cb", "allsetCb", "disDevId", disDevId, "kdaddr", "192.168.4.1", "pwt", 0, "forceLocal", true, "cmds", cmds);
          lastSsids = Set.new();
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
          }
          var haspecs = app.kvdbs.get("HASPECS"); //haspecs - device id to swspec
          haspecs.put(disDevId, "1,q,p6,p2.gsh.4");
          clearQueueKdaddr("192.168.4.1");
          //alStep = "getcontroldef";
          alStep = "setwifi";
       } elseIf (TS.notEmpty(cres) && cres.has("pass is incorrect")) {
          deleteDeviceRequest(disDevId, request);
          throw(Alert.new("Device is already configured, reset before setting up again."));
       } elseIf (TS.notEmpty(cres) && cres.has("mins of power on")) {
          deleteDeviceRequest(disDevId, request);
          throw(Alert.new("Error, must setup w/in 30 mins of power on. Unplug and replug in device and try again"));
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
            Mqtt mqtt = mqtts["haRelay"];
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
       Mqtt mqtt = mqtts["haRelay"];
       if (def(mqtt)) {
         log.log("closing mqtt");
         mqtt.close();
         mqtts.remove("haRelay");
       }
     }
   }

   displayNextDeviceRequest(String ssidn, request) Map {
     if (def(lastSsids) && lastSsids.notEmpty) {
       return(displayNextDeviceSsidRequest(ssidn, request));
     }
     return(displayNextDeviceCmdRequest(ssidn, request));
   }

   displayNextDeviceCmdRequest(String ssidn, request) Map {
     //log.log("in displayNextDeviceCmdRequest");
    String cmds = "getapssid e";
    Map mcmd = Maps.from("prio", 1, "mw", 1, "cb", "displayNextDeviceCmdCb", "kdaddr", "192.168.4.1", "pwt", 0, "forceLocal", true, "cmds", cmds);
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
     List ssids = List.new().addAll(lastSsids);
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
        if (type == "rAthPlugV2") {
          ftype = "Athom Plug V2";
        } elseIf (type == "rAthBlb7w") {
          ftype = "Athom Color Bulb 7w";
        } elseIf (type == "rAthBlb15w") {
          ftype = "Athom Color Bulb 15w";
        } elseIf (type.begins("rMatr")) {
          ftype = "Voice Bridge";
        } elseIf (type.begins("rGateTas")) {
          ftype = "Tasmota Bridge";
        } elseIf (type.begins("rGateMq")) {
          ftype = "Remote Bridge";
        } elseIf (type.begins("rGateHass")) {
          ftype = "Homeassistant Bridge";
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

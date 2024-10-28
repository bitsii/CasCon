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

emit(jv) {
"""
import java.io.*;
import java.net.*;
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

use Encode:Hex as Hex;
use Crypto:Symmetric as Crypt;

class CasNic:CasProt {

  new() self {
    fields {
      IO:Log log;
    }
    ifEmit(wajv) {
      fields {
        String supTok;
        String supUrl;
        Bool doSupIp;
        Bool doSupAuth;
        Bool doSupUpdate;
        Bool doGetMqtt;
      }
    }
    log = IO:Logs.get(self);
    IO:Logs.turnOnAll();
    ifEmit(wajv) {

      supTok = System:Environment.getVar("SUPERVISOR_TOKEN"); //inside
      supUrl = "http://supervisor"; //inside
      doSupIp = true; //inside
      doSupAuth = true; //inside
      doSupUpdate = true;
      doGetMqtt = true;

      //supTok = "f4ff4758e1e9aece1787b4b63fd6378d2320b0b799e6d47c9bb0dd49716e963caa4fbf35736348f769ca626a5ba6e0cb33ccb59c4c7dbfb7"; //outside
      //supUrl = "http://192.168.1.182"; //outside
      //doSupIp = false; //really running outside
      //doSupAuth = true; //testing
      //doSupUpdate = true;
      //doGetMqtt = true;

    }
  }

   processDeviceMcmd(Map mcmd) {
     //log.log("in processDeviceMcmd");

       String kdaddr = mcmd["kdaddr"];
       Int pwt = mcmd["pwt"];
       String pw = mcmd["pw"];
       String cmds = mcmd["cmds"];

       if (true && pwt > 0 && pwt != 3 && TS.notEmpty(pw)) {
         cmds = secCmds(pwt, pw, cmds, mcmd);
       }

       cmds += "\r\n";

       ifEmit(apwk) {
        String jspw = "sendAdCmds:" + kdaddr + ":" + cmds;
        emit(js) {
        """
        var jsres = prompt(bevl_jspw.bems_toJsString());
        bevl_jspw = new be_$class/Text:String$().bems_new(jsres);
        """
        }
      }
      if (def(mcmd["runSync"]) && mcmd["runSync"]) {
        sendRecvJvadMcmd(kdaddr, cmds, mcmd);
      } else {
        System:Thread.new(System:Invocation.new(self, "sendRecvJvadMcmd", Lists.from(kdaddr, cmds, mcmd))).start();
      }
      return(null);
   }

   sendRecvJvadMcmd(String kdaddr, String cmds, Map mcmd) {
      String cres = sendJvadCmds(kdaddr, cmds);
      if (TS.notEmpty(cres)) {
          mcmd["creso"].o = cres;
      }
   }

   sendJvadCmds(String kdaddr, String cmds) String {
      emit(jv) {
       """

      try{

          Socket ysocket = new Socket();
          ysocket.setKeepAlive(true);
          ysocket.setSoTimeout(4000);
          ysocket.connect(new java.net.InetSocketAddress(beva_kdaddr.bems_toJvString(), 6420), 4000);

          //System.out.println("Client Connected");

          BufferedWriter out = new BufferedWriter(new OutputStreamWriter(ysocket.getOutputStream()));
          //System.out.println("Sending Message...");
          out.write(beva_cmds.bems_toJvString());
          out.flush();

          BufferedReader in = new BufferedReader(new InputStreamReader(ysocket.getInputStream()));
          //System.out.println("Client response: " + in.readLine());
          bevl_cres = new $class/Text:String$(in.readLine());
          while (in.ready()) { in.read(); }
          ysocket.close();

      } catch (Exception e) {

      }
      """
      }
      String cres;
      return(cres);
   }

  secCmds(Int pwt, String pw, String cmds, Map mcmd) String {
    Int pver = mcmd["pver"];
    String tesh = mcmd["tesh"];
    if (pwt < 1 || pver < 4) {
      //we are dropping everything pre-4 to simplify, and pwt < 1 is passwordless
      return(cmds);
    }
    if (pwt == 1) {
      String ncmd = "ap";
    } else {
      ncmd = "sp";
    }
    ncmd += pver;
    String iv = mcmd["iv"];
    String insec = iv + "," + pw + "," + tesh + ",";
    var cmdl = cmds.split(" ");
    cmdl[1] = "X";
    Int toc = cmdl.length - 1;
    String sp = " ";
    for (Int j = 0;j < toc;j++) {
      insec += cmdl[j] += sp;
    }
    //log.log("insec |" + insec + "|");
    String outsec = sha1hex(insec);
    //log.log("insec " + insec);
    //log.log("outsec " + outsec);
    String fcmds = Text:Strings.new().join(Text:Strings.new().space, cmdl);
    if (pver == 5) {
      fcmds = Hex.encode(Crypt.encrypt(iv, pw, fcmds)) += " e";
    }
    String henres = ncmd + " " + iv + " " + outsec + " " + tesh + " ";
    henres += fcmds;
    log.log("secCmds " + henres);
    return(henres);
   }

   sha1hex(String insec) String {
      String outsec;
      ifEmit(jv) {
      Digest:SHA1 ds = Digest:SHA1.new();
      outsec = ds.digestToHex(insec).lowerValue();
      }
      ifEmit(apwk) {
      String jspw = "getSha1Hex:" + insec;
      emit(js) {
      """
      var jsres = prompt(bevl_jspw.bems_toJsString());
      bevl_jspw = new be_$class/Text:String$().bems_new(jsres);
      """
      }
      if (TS.notEmpty(jspw)) {
        outsec = jspw.lowerValue();
      }
      }
      return(outsec);
   }

   getMyOutIp() String {

    String ip;
    ifEmit(jvad) {
    emit(jv) {
      """
    //WifiManager wifiManager = (WifiManager) context.getSystemService(WIFI_SERVICE);
    WifiManager wifiManager = (WifiManager) be.BEC_3_2_4_10_UIJvAdWebBrowser.MainActivity.appContext.getSystemService(Context.WIFI_SERVICE);
    int ipAddress = wifiManager.getConnectionInfo().getIpAddress();

    if (java.nio.ByteOrder.nativeOrder().equals(java.nio.ByteOrder.LITTLE_ENDIAN)) {
        ipAddress = Integer.reverseBytes(ipAddress);
    }

    byte[] ipByteArray = java.math.BigInteger.valueOf(ipAddress).toByteArray();

    String ipAddressString;
    try {
        ipAddressString = InetAddress.getByAddress(ipByteArray).getHostAddress();
    } catch (UnknownHostException ex) {
        ipAddressString = null;
    }
    if (ipAddressString != null) {
      bevl_ip =  new $class/Text:String$(ipAddressString.getBytes("UTF-8"));
    }
    """
   }
    }

   ifEmit(wajv) {
     slots {
       String wajvip;
     }
     if (TS.notEmpty(wajvip)) {
       return(wajvip);
     }

      if (TS.notEmpty(supTok) && TS.notEmpty(supUrl) && doSupIp) {
        log.log("GOT supTok " + supTok);
        Web:Client client = Web:Client.new();
        client.url = supUrl + "/network/info";
        client.outputContentType = "application/json";

        client.outputHeaders.put("Authorization", "Bearer " + supTok);

        client.verb = "GET";
        String res = client.openInput().readString();

        if (TS.notEmpty(res)) {
          log.log("res is " + res);
          Map resm = Json:Unmarshaller.unmarshall(res);
          Map data = resm.get("data");
          if (def(data)) {
            log.log("got data");
            List ifc = data.get("interfaces");
            if (def(ifc)) {
              log.log("got interfaces");
              for (Map ifm in ifc) {
                if (ifm.has("ipv4")) {
                  log.log("got ipv4");
                  Map fer = ifm.get("ipv4");
                  List addrl = fer.get("address");
                  if (def(addrl)) {
                    log.log("got addrl");
                    if (addrl.length > 0) {
                      log.log("addrl got length");
                      log.log(addrl[0]);
                      var adll = addrl.get(0).split("/");
                      String sip = adll.get(0);
                      ip = sip;
                      wajvip = ip;
                    }
                  }
                }
              }
            }
          }
        } else {
          log.log("res empty");
        }

      } else {
        log.log("NO SBT");
        String defadd = Net:Gateway.defaultAddress;
          var inter = Net:Interface.interfaceForNetwork(defadd);
          if (def(inter)) {
            String addr = inter.address;
            if (TS.notEmpty(addr)) {
              log.log("WAJV ADDR " + addr);
              ip = addr;
              //wajvip = ip;
            }
          }
      }
    }

    ifEmit(apwk) {
        String jspw = "getWifiIPAddress:";
        emit(js) {
        """
        var jsres = prompt(bevl_jspw.bems_toJsString());
        bevl_jspw = new be_$class/Text:String$().bems_new(jsres);
        """
        }
        if (TS.notEmpty(jspw)) {
          ip = jspw;
        }
     }
    return(ip);
   }

}

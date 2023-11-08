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

class CasNic:CasProt {

  emit(jv) {
    """
    public Socket ysocket;
    """
  }

  new() self {
    fields {
      IO:Log log;
    }
    slots {
      String jvadCmdsRes;
    }
    log = IO:Logs.get(self);
    IO:Logs.turnOnAll();
  }

   processDeviceMcmd(Map mcmd) {
     //log.log("in processDeviceMcmd");

       String kdaddr = mcmd["kdaddr"];
       Int pwt = mcmd["pwt"];
       String pw = mcmd["pw"];
       String cmds = mcmd["cmds"];

       if (true && pwt > 0 && TS.notEmpty(pw)) {
         cmds = secCmds(kdaddr, pwt, pw, cmds);
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
        sendJvadCmds(kdaddr, cmds);
        mcmd["cres"] = jvadCmdsRes;
        jvadCmdsRes = null;
      } else {
        System:Thread.new(System:Invocation.new(self, "sendJvadCmds", Lists.from(kdaddr, cmds))).start();
      }
      return(null);
   }

   sendJvadCmds(String kdaddr, String cmds) {
      emit(jv) {
       """
      if (ysocket != null) {
        try {
          ysocket.close();
        }  catch (Exception ee) {

        }
      }

      try{

          ysocket = new Socket();
          ysocket.setKeepAlive(true);
          ysocket.setSoTimeout(1000);
          ysocket.connect(new java.net.InetSocketAddress(beva_kdaddr.bems_toJvString(), 6420), 1000);

          //System.out.println("Client Connected");

          BufferedWriter out = new BufferedWriter(new OutputStreamWriter(ysocket.getOutputStream()));
          //System.out.println("Sending Message...");
          out.write(beva_cmds.bems_toJvString());
          out.flush();

          BufferedReader in = new BufferedReader(new InputStreamReader(ysocket.getInputStream()));
          //System.out.println("Client response: " + in.readLine());
          bevl_cres = new $class/Text:String$(in.readLine());

      } catch (Exception e) {

      }
      """
      }
      String cres;
      if (TS.notEmpty(cres)) {
        emit(jv) {
          """
          synchronized(this) {
            bevp_jvadCmdsRes = bevl_cres;
          }
          """
        }
      }
   }

   secCmds(String kdaddr, Int pwt, String pw, String cmds) String {
      String myip = getMyOutIp(kdaddr);
       if (TS.notEmpty(myip)) {
         log.log("MY IP IS " + myip);
         //return(cmds);
         if (pwt == 1) {
           String ncmd = "ap2";
         } else {
           ncmd = "sp2";
         }
         String iv = System:Random.getString(16);
         String insec = iv + "," + myip + "," + pw + ",";
         auto cmdl = cmds.split(" ");
         cmdl[1] = "X";
         Int toc = cmdl.size - 1;
         String sp = " ";
         for (Int j = 0;j < toc;j++=) {
           insec += cmdl[j] += sp;
         }
         //log.log("insec |" + insec + "|");
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
         //log.log("insec " + insec);
         //log.log("outsec " + outsec);
         String fcmds = Text:Strings.new().join(Text:Strings.new().space, cmdl);
         String henres = ncmd + " " + iv + " " + outsec + " " + fcmds;
         log.log("secCmds " + henres);
         return(henres);
       } else {
         log.log("MY IP EMPTY");
       }
       return(cmds);
   }

   getMyOutIp(String kdaddr) String {

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
      auto inter = Net:Interface.interfaceForNetwork(kdaddr);
      if (def(inter)) {
        String addr = inter.address;
        if (TS.notEmpty(addr)) {
          log.log("WAJV ADDR " + addr);
          ip = addr;
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

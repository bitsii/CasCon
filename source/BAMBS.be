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

use System:Parameters;
use Encode:Hex as Hex;

use class BA:BS {

     new() self {
       slots {
          IO:Log log;
        }
        log = IO:Logs.get(self);
        IO:Logs.turnOnAll();
     }

     main() {
      try {
        log.log("In BA:BS main");
        Parameters params = Parameters.new(System:Process.new().args);
        sendWifiUrl(params.getFirst("addr"), params.getFirst("ssid"), params.getFirst("sec"), params.getFirst("furl"));
      } catch (any e) {
        log.elog("fail in appstart main", e);
      }
    }

    sendWifiUrl(String addr, String ssid, String sec, String furl) {
      var client = App:TCPClient.new(addr, 5308);
      client.open().write("from bambs");
      Time:Sleep.sleepSeconds(2);
      client.close();
    }
     
}


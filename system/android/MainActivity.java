/*
 * Copyright (c) 2015-2023, the Brace App Authors.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Licensed under the BSD 2-Clause License (the "License").
 * See the LICENSE file in the project root for more information.
 *
 */

package casnic.control;

import androidx.appcompat.app.AppCompatActivity;

import android.Manifest;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.net.wifi.ScanResult;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.Bundle;

//generated default above

import android.content.pm.ActivityInfo;
import android.webkit.WebView;
import android.view.SearchEvent;

import java.util.ArrayList;
import java.util.List;

public class MainActivity extends be.BEC_3_2_4_10_UIJvAdWebBrowser.MainActivity {
    public WifiManager mWifiManager;
    public List<String> ssids;
    public String lastCx = null;

    //generated default onCreate
    /*@Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
    }*/

    public synchronized String getLastCx() {
      if (lastCx == null) {
        return "";
      }
      return lastCx;
    }

    public synchronized void clearLastCx() {
      lastCx = null;
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        try {

        String action = null;
        Uri data = null;
        String cx = null;
        Intent intent = getIntent();

        if (intent != null) {
            action = intent.getAction();
            data = intent.getData();
            if (action != null) {
            System.out.println("action " + action);
            }
            if (data != null) {
            System.out.println("data " + data.toString());
            cx = data.getQueryParameter("cx");
            }
            if (cx != null) {
            System.out.println("cx " + cx);
            lastCx = cx;
            }
        }
        /*Bundle exb = getIntent().getExtras();
        if (exb != null) {
          System.out.println("exb notnull");
        } else {
          System.out.println("exb isnull");
        }
        String cx = savedInstanceState.getString("cx");
        if (cx != null) {
          System.out.println("got cx " + cx);
        } else {
          System.out.println("got no cx");
        }*/
        } catch (Exception e) {
          System.out.println("got exception");
          System.out.println(e.getMessage());
        }

        //setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
        setContentView(R.layout.activity_main);
        //mWebView = (WebView) findViewById(R.id.activity_main_webview);
        mWebView = new WebView(this);
        setContentView(mWebView);
        postCreate();
        mWifiManager = (WifiManager) getApplicationContext().getSystemService(Context.WIFI_SERVICE);
        registerReceiver(mWifiScanReceiver,
                new IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION));
        System.out.println("all setup starting scan wifi");
        /*if(checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED)
        { System.out.println("requesting permissions");
            requestPermissions(new String[]{Manifest.permission.ACCESS_COARSE_LOCATION}, 87);
        }*/
        if(checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED)
        {  System.out.println("requesting permissions");
            requestPermissions(new String[]{Manifest.permission.ACCESS_FINE_LOCATION}, 87);
        }
        if(checkSelfPermission(Manifest.permission.CHANGE_WIFI_STATE) != PackageManager.PERMISSION_GRANTED)
        {  System.out.println("requesting permissions");
            requestPermissions(new String[]{Manifest.permission.CHANGE_WIFI_STATE}, 87);
        }
        startScan();
    }

    public void startScan() {
      System.out.println("wifimanager starting scan");
      boolean worked = mWifiManager.startScan();
      if (worked) {
        System.out.println("starting scan worked");
      } else {
        System.out.println("starting scan failed");
      }
    }

    @Override
    public void onResume()
    {
        super.onResume();

        /*if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
        {
            if(checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED)
            {  System.out.println("requesting permissions");
                requestPermissions(new String[]{Manifest.permission.ACCESS_COARSE_LOCATION}, 87);
            }
        }*/
    }

    @Override
    public boolean onSearchRequested (SearchEvent searchEvent) {
      return true;
    }

    private static final String TAG = MainActivity.class.getSimpleName();

    public static String[] innerGetStartupArgs() {
        return new String[] {"--plugin", "BA:BamPlugin", "--plugin", "App:ConfigPlugin", "--appPlugin", "CasCon", "--appType", "browser", "--appName", "CasCon", "--sdbClass", "Db:MemFileStoreKeyValue", "--appKvPoolSize", "1"};
    }

    public String[] getStartupArgs() {
        return innerGetStartupArgs();
    }

    private final BroadcastReceiver mWifiScanReceiver = new BroadcastReceiver() {
    @Override
    public void onReceive(Context c, Intent intent) {
        System.out.println("breceiver in onReceive");
        if (intent.getAction().equals(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION)) {
            System.out.println("got results");
            List<ScanResult> mScanResults = mWifiManager.getScanResults();
            ssids = new ArrayList<String>();

            for (int i = 0; i < mScanResults.size(); i++){
                System.out.println((mScanResults.get(i)).SSID);
                System.out.println("adding ssid to ssids");
                ssids.add((mScanResults.get(i)).SSID);
            }
                }
            }
        };

}

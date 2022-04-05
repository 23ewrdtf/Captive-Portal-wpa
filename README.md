## Captive Portal on Rapsberry Pi

The following script will create an open wifi network and when you connect to it, it will automatically open the browser. Make sure you don't have the internet on your device you are connecting it from. This is originally designed to only provide local website from the RPI.

This is based on https://github.com/tretos53/Captive-Portal and adds a posibility to switch between AP mode and connecting to external wifi mode.

Awesome thanks to https://github.com/Autodrop3d/raspiApWlanScripts for helping with switching networks.

## Instructions

Flash microsd card with etcher

Connect to the SSH and run below command. You can get the IP address from IP scanner.

```
sudo -i
```

Before running below command **REPLACE** `ExternalWiFiSSID` and `ExternalWiFiPassword` with the wifi you want RPI to connect to.

```
curl -H 'Cache-Control: no-cache' -sSL https://raw.githubusercontent.com/tretos53/Captive-Portal-wpa/master/captiveportal-wpa.sh | bash $0 ExternalWiFiSSID ExternalWiFiPassword
```

By default this will run in Captive Portal Mode. To change the mode, SSH to the pi and run `bash wlan.sh` or `bash ap.sh` respectively.

## To Do

A lot to do. Please send any suggestions and issues.

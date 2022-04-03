#!/bin/bash
systemctl stop wpa_supplicant@ap0.service
systemctl disable wpa_supplicant@ap0.service
systemctl enable wpa_supplicant@wlan0.service
systemctl start wpa_supplicant@wlan0.service

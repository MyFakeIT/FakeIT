# How to Block Viber Ads

This guide provides instructions to block Viber ads by modifying the hosts file on PC (Windows, macOS, Linux) and using ad-blocking solutions on mobile devices (Android, iOS). The hosts file redirects ad-related domains to `127.0.0.1`, preventing ads from loading. For mobile devices, alternative methods are recommended due to restrictions on hosts file access.

The guide is titled in the top 10 most popular languages (based on global usage): English, Mandarin Chinese, Hindi, Spanish, French, Arabic, Bengali, Russian, Portuguese, and Urdu.

## Titles in Top 10 Languages
- **English**: How to Block Viber Ads
- **Mandarin Chinese**: 如何屏蔽Viber广告
- **Hindi**: वाइबर विज्ञापनों को कैसे ब्लॉक करें
- **Spanish**: Cómo bloquear los anuncios de Viber
- **French**: Comment bloquer les publicités Viber
- **Arabic**: كيفية حظر إعلانات فايبر
- **Bengali**: ভাইবারের বিজ্ঞাপন কীভাবে ব্লক করবেন
- **Russian**: Как заблокировать рекламу в Viber
- **Portuguese**: Como bloquear anúncios do Viber
- **Urdu**: وائبر کے اشتہارات کو کیسے بلاک کریں

## Instructions for PC (Windows, macOS, Linux)

### Windows
1. **Open the Hosts File**:
   - Press `Win + R`, type `notepad C:\Windows\System32\drivers\etc\hosts`, and press Enter. If prompted, select "Run as administrator."
2. **Add the Ad-Blocking Entries**:
   - Copy the list of domains from [hosts.txt](hosts.txt) (starting from the first `127.0.0.1` line, excluding the note at the top) into the hosts file.
   - Each line should start with `127.0.0.1` followed by the domain (e.g., `127.0.0.1 ads.viber.com`).
   - **Do not copy the entire hosts.txt file directly**; only copy the domain entries as instructed.
3. **Save and Flush DNS**:
   - Save the file (`Ctrl + S`).
   - Open Command Prompt as administrator and run: `ipconfig /flushdns`.
4. **Restart Viber**:
   - Close and reopen Viber to apply changes.

### macOS
1. **Open Terminal**:
   - Launch Terminal from Applications > Utilities.
2. **Edit the Hosts File**:
   - Run `sudo nano /etc/hosts` and enter your admin password.
3. **Add the Ad-Blocking Entries**:
   - Copy the list of domains from [hosts.txt](hosts.txt) (starting from the first `127.0.0.1` line, excluding the note at the top) into the bottom of the hosts file.
   - Ensure each line starts with `127.0.0.1` followed by the domain.
   - **Do not copy the entire hosts.txt file directly**; only copy the domain entries as instructed.
4. **Save and Flush DNS**:
   - Save the file (`Ctrl + O`, then Enter, then `Ctrl + X` to exit).
   - Run `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder` to flush DNS.
5. **Restart Viber**:
   - Close and reopen Viber.

### Linux
1. **Open Terminal**:
   - Launch your terminal application.
2. **Edit the Hosts File**:
   - Run `sudo nano /etc/hosts` and enter your password.
3. **Add the Ad-Blocking Entries**:
   - Copy the list of domains from [hosts.txt](hosts.txt) (starting from the first `127.0.0.1` line, excluding the note at the top) into the end of the hosts file.
   - Ensure each line starts with `127.0.0.1` followed by the domain.
   - **Do not copy the entire hosts.txt file directly**; only copy the domain entries as instructed.
4. **Save and Flush DNS**:
   - Save the file (`Ctrl + O`, then Enter, then `Ctrl + X` to exit).
   - If your system uses a DNS cache, flush it (e.g., `sudo systemd-resolve --flush-caches` or `sudo service dnsmasq restart`).
5. **Restart Viber**:
   - Close and reopen Viber.

**Note for PC Users**:
- Modifying the hosts file requires administrative privileges.
- Backup the hosts file before editing.
- If Viber stops working, remove specific entries causing issues or restore the original hosts file.

## Instructions for Mobile Devices (Android, iOS)

Modifying the hosts file on mobile devices is complex due to system restrictions and often requires root (Android) or jailbreak (iOS), which voids warranties and poses security risks. Instead, use these safer alternatives:

### Android
1. **Use an Ad-Blocking App**:
   - Download a reputable ad-blocking app like **AdGuard** (available on Google Play or as an APK from AdGuard’s [official site](https://adguard.com)).
   - Enable AdGuard and add the domains from [hosts.txt](hosts.txt) (starting from the first `127.0.0.1` line, excluding the note at the top) to its blocklist (under Filters > Custom Filters). Only copy the domain names (e.g., `ads.viber.com`), not the `127.0.0.1` prefix.
2. **Use a DNS-Based Ad Blocker**:
   - Configure your device to use a DNS service like **AdGuard DNS**:
     - Go to Settings > Wi-Fi > Modify Network > Advanced > Manual DNS.
     - Set DNS 1 to `94.140.14.14` and DNS 2 to `94.140.15.15`.
   - Alternatively, use **Cloudflare’s 1.1.1.1 for Families** (DNS: `1.1.1.2` and `1.0.0.2`) for ad and tracker blocking.
3. **Block Ads via Browser** (if using Viber Web):
   - Install a browser with built-in ad-blocking, like **Brave**, or use Firefox with the **uBlock Origin** extension.
   - Add the domains from [hosts.txt](hosts.txt) (starting from the first `127.0.0.1` line, excluding the note at the top) to uBlock Origin’s custom filter list. Only copy the domain names.
4. **Restart Viber**:
   - Close and reopen Viber to apply changes.

### iOS
1. **Use an Ad-Blocking App**:
   - Download **AdGuard** from the App Store.
   - Enable AdGuard’s Safari content blocker and add the domains from [hosts.txt](hosts.txt) (starting from the first `127.0.0.1` line, excluding the note at the top) to its custom blocklist. Only copy the domain names.
2. **Use a DNS-Based Ad Blocker**:
   - Configure AdGuard DNS:
     - Go to Settings > Wi-Fi > [Your Network] > DNS > Manual.
     - Set DNS to `94.140.14.14` and `94.140.15.15`.
   - Alternatively, use **Cloudflare’s 1.1.1.1 for Families** (DNS: `1.1.1.2` and `1.0.0.2`).
3. **Enable Content Blockers in Safari** (for Viber Web):
   - Use Safari with a content blocker like **1Blocker** or **AdBlock Plus**.
   - Add the domains from [hosts.txt](hosts.txt) (starting from the first `127.0.0.1` line, excluding the note at the top) to the custom blocklist in the blocker’s settings. Only copy the domain names.
4. **Restart Viber**:
   - Close and reopen Viber.

**Note for Mobile Users**:
- Some ad-blocking apps require a premium subscription for full functionality.
- DNS-based blocking may not cover all Viber ads but is effective for most.
- Avoid rooting or jailbreaking unless you understand the risks.

## Ad-Blocking Hosts List
The list of domains to block Viber ads is available in [hosts.txt](hosts.txt). **Do not copy the entire file directly into your system’s hosts file or ad-blocker.** Only copy the domain entries starting from the first `127.0.0.1` line, excluding the note at the top, as instructed above.

## Additional Notes
- **Testing**: After applying changes, test Viber to ensure it functions correctly. If issues arise, remove problematic domains from the list.
- **Updates**: Ad domains may change. Check for updated lists on forums or ad-blocking communities.
- **Legal Considerations**: Blocking ads may violate Viber’s terms of service. Proceed at your own risk.
- **Contributing**: Feel free to submit pull requests to update the hosts list or improve the guide.
- **GitHub Hosting**: To host this guide on.ConcurrentLinkedQueue GitHub:
  - Create a new repository (e.g., `viber-ad-block`).
  - Add this guide as `How to Block Viber Ads.md` and the hosts list as `hosts.txt`.
  - Enable GitHub Pages in the repository settings to make the guide accessible online.

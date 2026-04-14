<img width="100" height="100" src="https://github.com/user-attachments/assets/b5a6e1e0-6318-43f5-9a28-3d52fd44afef" />

# Reynard Browser

Reynard is a **Gecko-based** mobile web browser for iOS 14+.

Unlike other browsers on iOS that are forced to use Apple's **WebKit** engine (including Safari and all third-party browsers), Reynard uses **Gecko**. This is the same engine that powers the Firefox browser on desktop and Android devices.

This project is mainly for users on older iOS versions who are stuck with an outdated version of WebKit. Because WebKit is bundled with the OS, these devices cannot receive engine updates and often fail to load modern websites. By using Gecko which is kept up to date independently, Reynard allows these sites to work again. Users on newer iOS versions can also use the browser if they want to use an alternative browser engine on their device.

## Installation

The latest builds are available on the [Releases](https://github.com/minh-ton/reynard-browser/releases) page.

For the best performance and automatic JIT enablement, it is recommended to sideload Reynard using [TrollStore](https://github.com/opa334/TrollStore), using the `Reynard-TrollStore.ipa` build.

If TrollStore is not available, you should use [AltStore](https://altstore.io/) or [SideStore](https://sidestore.io/) to sideload the `Reynard.ipa` build instead. Please note that you must select the **Keep App Extensions** option during installation, as Reynard relies on its extension to function and will not work without it. After sideloading, you may want to enable JIT by following [this guide](https://github.com/minh-ton/reynard-browser/wiki/2.-Enabling-JIT).

> [!WARNING]
> - **LiveContainer is not supported**, as it does not handle extensions or launch apps in a way that is compatible with Reynard.
> - Compatibility with other sideloading methods is currently unknown.

This project is still in an early experimental state, so expect bugs and missing features. If you encounter issues, check the [Issues & FAQ](https://github.com/minh-ton/reynard-browser/wiki/3.-Issues-&-FAQ) page before opening a new issue.

## Preview

### iOS 14 (iPhone 6S Plus, iOS 14.1)

These sites are known to break or render incorrectly on iOS 14. The screenshots below compare how they load in Safari versus Reynard.

<table>
  <tr>
    <th colspan="2">github.com</th>
    <th colspan="2">chatgpt.com</th>
    <th colspan="2">apple.com</th>
  </tr>
  <tr>
    <td align="center">Safari</td>
    <td align="center">Reynard</td>
    <td align="center">Safari</td>
    <td align="center">Reynard</td>
    <td align="center">Safari</td>
    <td align="center">Reynard</td>
  </tr>
  <tr>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/e558041d-4552-4f60-996f-2657958d7a06"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/eae998cf-9dc6-468a-a240-8731c0683d81"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/2d14675b-8648-452d-a80a-f64b4ff3f7e3"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/66d48ede-ca71-43f0-a8bb-a437a9b92f55"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/158c3626-8d26-4a24-a975-ea5b83e5842d"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/af440996-62db-4c74-a98d-259a128399e6"><br>
    </td>
  </tr>
</table>

### iOS 15 (iPhone 7, iOS 15.8.6)

<table>
  <tr>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/f9238d3f-2a06-4ec2-aa1f-83b00e93a720"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/38021234-0ec0-47d0-bedf-06fb9428865f"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/17f25dcf-2197-4b68-9753-d05ca9ead132"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/68f2c8a2-c07f-4aa3-b2f5-7c897f2eed81"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/9c5ec535-5a35-41ae-a7c6-24faa84c192f"><br>
    </td>
  </tr>
</table>

### iOS 26 (iPhone 13 Mini, iOS 26.1)

Reynard also works great on the latest version of iOS!

<table>
  <tr>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/97fbb40f-9471-4a32-bdfd-691c459fc82b"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/fe9ba115-a242-4281-ab14-3a07527ec36a"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/6e918f0f-af28-4e12-855e-8065f6ceebf3"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/d199aad2-9234-43a0-9ea1-aed2d143cacf"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/2edeb828-9602-4198-8c8c-ba761f3a5dae"><br>
    </td>
  </tr>
</table>

## Building

> [!WARNING]
> Build instructions are included below for reference. Please be aware that I **do not** provide support for issues or errors encountered during the build process.

Clone the repository.

```bash
git clone --recursive https://github.com/minh-ton/reynard-browser
cd reynard-browser
```

Download Gecko and apply patches.

```bash
./tools/development/update-gecko.sh
./tools/development/apply-patches.sh
```

Build dependencies and the Gecko engine.

```bash
./tools/development/build-idevice.sh
./tools/development/build-gecko.sh
```

To run Reynard, open `Reynard.xcodeproj` in Xcode and build/run it from there.

## Notes

This project initially started out of curiosity. I wanted to see if I could get Gecko to run without the [BrowserEngineKit](https://developer.apple.com/documentation/browserenginekit) framework, so it could run on iOS versions as far back as possible. I got it working, and since then, I’ve been focusing on developing engine patches for better UIKit integration, fixing bugs, and turning this into a full, usable browser.

If you’ve come across this repository and find it interesting, I’d love to get help or collaborate on it. I’m learning as I go here and don’t have much prior experience with iOS app development or with Gecko itself, so any contributions, feedback, or pointers would be greatly appreciated.

## Acknowledgements
- [LiveContainer](https://github.com/LiveContainer/LiveContainer): app extension handling and NSExtension usage.
- [StikDebug](https://github.com/StephenDev0/StikDebug) and [idevice](https://github.com/jkcoxson/idevice): pairing-based JIT enablement support.
- [TrollStore](https://github.com/opa334/TrollStore): spawning a binary as root and JIT enablement.
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS) and [dolphin-ios](https://github.com/OatmealDome/dolphin-ios): Various utility functions, numerous private API usage, and memory mapping stuff.
- [Pre-existing work](https://bugzilla.mozilla.org/show_bug.cgi?id=1882872) on bringing Gecko to iOS using BrowserEngineKit: most of the difficult engine integration. 

## License

This project is licensed under the MIT License, except for the `patches` directory containing the modifications to the Firefox Gecko engine and therefore is licensed under the Mozilla Public License 2.0.

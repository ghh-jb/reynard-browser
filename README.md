# Reynard Browser

Reynard is a simple **Gecko-based** web browser for iOS 14+.

I still use devices that can’t be updated beyond iOS 15. On these versions, a lot of modern websites simply don’t work in Safari.

The core issue is **WebKit**, the browser engine behind Safari. It’s bundled with the OS, so if your device is stuck on an older iOS version, you’re stuck with an outdated browser. Although Apple now allows custom browser engines through the [BrowserEngineKit](https://developer.apple.com/documentation/browserenginekit) framework, this only applies to **iOS 17.4+** and only for users in the **EU** and **Japan**. There’s also the [CyberKit](https://github.com/CyberKitGroup/CyberKit) project, which attempts to backport WebKit, but its current releases are far from usable.

With Reynard, my goal is to build a Gecko-based browser that does not depend on BrowserEngineKit, allowing it to run on older iOS and iPadOS versions.

## Preview

These clips compare how several sites that are known to break in Safari on iOS 14 & 15 load versus how they load in Reynard. The screen recordings were captured on an iPhone 6S Plus running iOS 14.1 and an iPhone 7 running iOS 15.8.6.

### iOS 14

<table>
  <tr>
    <th colspan="2">github.com</th>
    <th colspan="2">chatgpt.com</th>
  </tr>
  <tr>
    <td align="center">Safari</td>
    <td align="center">Reynard</td>
    <td align="center">Safari</td>
    <td align="center">Reynard</td>
  </tr>
  <tr>
    <td>
      <img width=200 src="https://github.com/user-attachments/assets/9b1bb22c-d377-439c-818a-2f5d30a3e6e1"><br>
    </td>
    <td>
      <img width=200 src="https://github.com/user-attachments/assets/c5ad77e1-a29c-4258-88b0-135c78f68798"><br>
    </td>
    <td>
      <img width=200 src="https://github.com/user-attachments/assets/94b5ad3d-d8c5-4440-908d-3a1e174527de"><br>
    </td>
    <td>
      <img width=200 src="https://github.com/user-attachments/assets/31749c9e-14a2-4451-8b28-4bce61d2b339"><br>
    </td>
  </tr>
</table>

### iOS 15

<table>
  <tr>
    <th colspan="2">github.com</th>
  </tr>
  <tr>
    <td align="center">Safari</td>
    <td align="center">Reynard</td>
  </tr>
  <tr>
    <td>
      <img width=200 src="https://github.com/user-attachments/assets/5972c5ad-7293-4d78-93b3-49d118e22248"><br>
    </td>
    <td>
      <img width=200 src="https://github.com/user-attachments/assets/eeaf53e2-f6cb-4c1d-aad9-2554e3d1065a"><br>
    </td>
  </tr>
</table>

### iOS 26

And Reynard also works on iOS 26!

<table>
  <tr>
    <th>apple.com</th>
  </tr>
  <tr>
    <td>
      <img width=200 src="https://github.com/user-attachments/assets/0785f6f7-8f5c-40d4-ab55-7934c1446ded"><br>
    </td>
  </tr>
</table>

## Issues
- The JIT backend for child processes is disabled, which means that the JS interpreter, JIT compiler, and WebAssembly are currently not available. As a result, performance will be slower on several sites and features requiring WebAssembly will not work.
- Some POST request responses like dynamically loaded scripts and video streams are not fully delivered, which can cause Google reCAPTCHA to fail during loading or lead to stalled playback on YouTube. A workaround would be to set the user-agent string to a generic Firefox on Android one. I observed this behavior through debug logs and never fully understood it.
- On some websites that use `-apple-system` or `BlinkMacSystemFont`, the rendered text falls back to an overly thin SF UI variant.
- Video playback has no sound output.
- Child processes responsible for WebContent and Rendering crashes due to "fault hit memory shortage" quite frequently on devices such as the iPad Air 2 on iOS 15.

## Installation

> [!IMPORTANT]
> I would **highly** recommend that you sideload Reynard using **TrollStore**, **SideStore**, or **AltStore**. 
> 
> When sideloading through SideStore or AltStore, you **must** enable **Keep App Extensions**. Reynard relies on an app extension to launch child processes and will not function properly without it. 
> 
> Please note that **LiveContainer is not supported**, as it does not currently support signing the app extension required for running Reynard.
>
> <table>
>   <tr>
>     <td><img src="https://github.com/user-attachments/assets/b8578358-8c0a-4148-a33b-4e8f8da5514b" width=250/></td>
>     <td><img src="https://github.com/user-attachments/assets/62d10f96-47d4-45bd-83f9-3a205fe9ff1f" width=250/></td>
>   </tr>
> </table>

The latest experimental Reynard `.ipa` builds are available on the [Releases](https://github.com/minh-ton/reynard-browser/releases) page. Please note that this project is under active development and there is no formal release yet, so these experimental builds are updated frequently and may contain significant bugs.

## Changes
As of February 23, the browser uses a multi-process architecture, spawning child-processes (WebContent, Rendering, and Networking) through NSExtension. Most modern websites render correctly, including proper font and emoji support, and general browsing feels much smoother. While performance still does not match Safari, the browser is now reliable enough for everyday use.

<details>
<summary>Changes on February 4, 2026</summary>
As of Feb 4th 2026, the browser uses a single-process architecture, which is the simplest way I found to get Gecko up and running. It's slow and laggy in terms of performance. Most webpages render correctly, but fonts fall back to the system default, and the browser can crash on sites with popup or redirect ads.

<table>
  <tr>
    <td align="left">
      <img width=580 src="https://github.com/user-attachments/assets/03413002-be62-43ad-b648-4ef9367d3305"><br>
      Here's Reynard running on iPadOS 15...
    </td>
    <td align="left">
      <img width=200 src="https://github.com/user-attachments/assets/6c2ddfd8-ba2f-492c-975d-37d545bee02f"><br>
      …and on iOS 26
    </td>
  </tr>
</table>
</details>

## Build

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

If you’ve come across this repository and find it interesting, I’d love to get help or collaborate on it. I’m learning as I go here and don’t have much prior experience with iOS app development or with Gecko itself, so any contributions, feedback, or pointers would be greatly appreciated.

## License

This project is licensed under the MIT License, except for the `patches` directory containing the modifications to the Firefox Gecko engine and therefore is licensed under the Mozilla Public License 2.0.

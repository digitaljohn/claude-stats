import Cocoa
import FlutterMacOS
import IOKit
import IOKit.hid

class MainFlutterWindow: NSWindow {
  // Retain the side-light plugin for the lifetime of the window.
  private var sideLights: SideLightPlugin?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    sideLights = SideLightPlugin.register(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// Drives the NuPhy Air75 V2 side LEDs over its QMK "raw HID" vendor interface
/// (usage page 0xFF60 / usage 0x61) using IOKit's IOHIDManager. This is a plain
/// vendor collection — not the keyboard collection — so opening it never
/// interferes with typing and needs no Input Monitoring permission.
///
/// Requires the matching custom firmware (see firmware/README.md). Against stock
/// firmware the writes are silently ignored.
final class SideLightPlugin {
  static let channelName = "claude_stats/sidelights"

  private static let vendorId = 0x19F5 // NuPhy
  private static let usagePage = 0xFF60 // QMK raw HID
  private static let usage = 0x61
  private static let reportLength = 32 // RAW_EPSIZE

  private let manager: IOHIDManager

  init() {
    manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    let match: [String: Any] = [
      kIOHIDVendorIDKey: SideLightPlugin.vendorId,
      kIOHIDDeviceUsagePageKey: SideLightPlugin.usagePage,
      kIOHIDDeviceUsageKey: SideLightPlugin.usage,
    ]
    IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
  }

  static func register(with messenger: FlutterBinaryMessenger) -> SideLightPlugin {
    let plugin = SideLightPlugin()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in plugin.handle(call, result) }
    return plugin
  }

  // MARK: - Device

  private func device() -> IOHIDDevice? {
    guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return nil }
    return devices.first
  }

  private func send(_ payload: [UInt8]) {
    guard let dev = device() else { return }
    var report = [UInt8](repeating: 0, count: SideLightPlugin.reportLength)
    for i in 0 ..< min(payload.count, report.count) { report[i] = payload[i] }
    _ = IOHIDDeviceSetReport(dev, kIOHIDReportTypeOutput, 0, report, report.count)
  }

  // MARK: - Commands (must match firmware/README.md protocol)

  private func setGauge(_ args: [String: Any]) {
    func u8(_ key: String) -> UInt8 { UInt8(truncatingIfNeeded: (args[key] as? Int) ?? 0) }
    send([0xC1,
          u8("leftPct"), u8("lr"), u8("lg"), u8("lb"),
          u8("rightPct"), u8("rr"), u8("rg"), u8("rb")])
  }

  private func handle(_ call: FlutterMethodCall, _ result: FlutterResult) {
    switch call.method {
    case "detect":
      result(device() != nil)
    case "setGauge":
      setGauge(call.arguments as? [String: Any] ?? [:])
      result(nil)
    case "release":
      send([0xC0])
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

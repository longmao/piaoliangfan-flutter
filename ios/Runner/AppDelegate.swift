import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // why: 真机 BDD 自验钩子 - devicectl openURL plf://auto 写一个文件
    // Flutter 端 initState 读文件触发 autoRunShareFlow
    // 避开 app_links/spm/pod 三条都断路的坑
    if let url = launchOptions?[.url] as? URL {
      writeBDDTrigger(url: url)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // devicectl openURL 调用路径
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    writeBDDTrigger(url: url)
    return super.application(app, open: url, options: options)
  }

  private func writeBDDTrigger(url: URL) {
    let tmp = NSTemporaryDirectory()
    let f = (tmp as NSString).appendingPathComponent("bdd_trigger.txt")
    let payload = "url=\(url.absoluteString)\nhost=\(url.host ?? "")\npath=\(url.path)\nts=\(Date().timeIntervalSince1970)\n"
    try? payload.write(toFile: f, atomically: true, encoding: .utf8)
    NSLog("[BDD] wrote trigger \(f) url=\(url.absoluteString)")
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // why: share_plus 9/11 在 iOS 26.6 + 真机有 bug（UIActivityViewController 不弹）
    //      用 MethodChannel 走 native UIActivityViewController，最稳
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "piaoliangfan.share")!
    setupShareChannel(messenger: registrar.messenger())
  }

  private func setupShareChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "piaoliangfan/share", binaryMessenger: messenger)
    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "share":
        guard let args = call.arguments as? [String: Any],
              let imagePath = args["imagePath"] as? String else {
          result(FlutterError(code: "BAD_ARGS", message: "imagePath required", details: nil))
          return
        }
        let text = args["text"] as? String ?? ""
        DispatchQueue.main.async {
          self.presentShareSheet(imagePath: imagePath, text: text, result: result)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    NSLog("[BDD] share channel registered")
  }

  private func presentShareSheet(imagePath: String, text: String, result: @escaping FlutterResult) {
    let activityItems: [Any] = {
      var items: [Any] = []
      let img = UIImage(contentsOfFile: imagePath)
      if img != nil { items.append(img!) }
      if !text.isEmpty { items.append(text) }
      return items
    }()
    guard !activityItems.isEmpty else {
      result(FlutterError(code: "NO_ITEMS", message: "nothing to share", details: nil))
      return
    }
    let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    // why: iOS 13+ Scene-based app, AppDelegate.window 是 nil,
    //      rootViewController 必须从 SceneDelegate.window 拿
    let presenter: UIViewController? = {
      if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
         let win = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
        return win.rootViewController
      }
      return self.window?.rootViewController
    }()
    if let popover = vc.popoverPresentationController {
      popover.sourceView = presenter?.view
      popover.sourceRect = presenter?.view.bounds ?? CGRect.zero
      popover.permittedArrowDirections = []
    }
    vc.completionWithItemsHandler = { (activityType, completed, _, error) in
      // why: API-level verify — activityType = .saveToCameraRoll ⇔ 真存到相册
      //      杨总反"飘"教训: 视觉 verify 不可靠 (Photos app UI 列表可见图片数=0 也能误报)
      let at = activityType?.rawValue ?? "nil"
      NSLog("[BDD] share activityType=\(at) completed=\(completed) error=\(error?.localizedDescription ?? "nil")")
      if let error = error {
        result(FlutterError(code: "SHARE_FAIL", message: error.localizedDescription, details: nil))
      } else {
        result(completed ? "shared:\(at)" : "cancelled:\(at)")
      }
    }
    guard let p = presenter else {
      NSLog("[BDD] no presenter (rootVC nil)")
      result(FlutterError(code: "NO_ROOT", message: "no root VC", details: nil))
      return
    }
    NSLog("[BDD] presenting UIActivityViewController")
    p.present(vc, animated: true, completion: nil)
  }
}
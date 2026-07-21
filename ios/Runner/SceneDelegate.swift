import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  // why: 真机 BDD 自验钩子 - devicectl openURL 走 scene 这条路（iOS 13+ Scene-based）
  // AppDelegate.application(_:open:) 在 app 已 running 时不会被调
  // 必须 SceneDelegate.scene(_:openURLContexts:) 处理才能进 app
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for ctx in URLContexts {
      let url = ctx.url
      writeBDDTrigger(url: url)
    }
    super.scene(scene, openURLContexts: URLContexts)
  }

  private func writeBDDTrigger(url: URL) {
    let tmp = NSTemporaryDirectory()
    let f = (tmp as NSString).appendingPathComponent("bdd_trigger.txt")
    let payload = "url=\(url.absoluteString)\nhost=\(url.host ?? "")\npath=\(url.path)\nts=\(Date().timeIntervalSince1970)\n"
    try? payload.write(toFile: f, atomically: true, encoding: .utf8)
    NSLog("[BDD] SceneDelegate wrote trigger url=\(url.absoluteString)")
  }
}
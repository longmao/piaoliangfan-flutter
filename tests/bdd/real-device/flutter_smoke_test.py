"""
漂亮饭 Flutter 真机 share BDD v3 - 3 项硬验收
Why: 杨总反飘 4 条教训 - 测试框架必须自验，每次有 evidence
     + 网络授权选择权归用户，Appium 不替用户做选择
Acceptance:
  1. 网络授权: 弹窗让用户手点，Appium verify 弹窗 dismiss + vision API 真的算通
  2. share sheet 弹: page_source 含 活动/AirDrop/拷贝
  3. image 真在 sheet: 含 Save Image action (说明 items 有 UIImage)
"""
import sys, time, re
from pathlib import Path
from appium import webdriver
from appium.options.ios import XCUITestOptions

UDID = "00008101-000914AE11F9001E"
BUNDLE = "com.vincent.plf.flutter"
DEVID = "A346A94F-F841-55BF-9599-909037BA6AA3"
RESULTS = Path("/tmp/real-device-bdd")
RESULTS.mkdir(exist_ok=True)


def make_opts():
    opts = XCUITestOptions()
    opts.platform_version = "26.6"
    opts.device_name = "iPhone 12"
    opts.udid = UDID
    opts.bundle_id = BUNDLE
    opts.no_reset = True
    opts.new_command_timeout = 300
    opts.set_capability("xcodeOrgId", "5DCJKSP8CQ")
    opts.set_capability("xcodeSigningId", "Apple Development")
    # === 反"飘"硬尺：测试框架不替用户做选择 ===
    # autoAcceptAlerts=False: alert 弹出来让用户在 iPhone 上手点
    # Appium 只 verify alert 已 dismiss + 网络真的通了
    opts.set_capability("settings", {"autoAcceptAlerts": False})
    return opts


def shot(driver, name):
    p = RESULTS / f"{name}.png"
    driver.save_screenshot(str(p))
    return p


def alert_state(driver):
    """返回 alert 当前状态 (text, buttons) 或 None"""
    try:
        al = driver.switch_to.alert
        return al.text
    except:
        return None


def wait_user_dismiss_alert(driver, max_sec=120):
    """等用户在 iPhone 上手点 alert, Appium 不替点"""
    print(f"   ⏳ 等用户在 iPhone 上手点 alert (max {max_sec}s)...")
    start = time.time()
    while time.time() - start < max_sec:
        state = alert_state(driver)
        if state is None:
            print(f"   ✅ alert 已 dismiss (用户选了) @ {int(time.time()-start)}s")
            return True
        time.sleep(2)
    print(f"   ❌ {max_sec}s 内 alert 未 dismiss")
    return False


def main():
    print("=" * 50)
    print("漂亮饭 Flutter 真机 share BDD v3")
    print("3 项硬验收: 网络授权 / share sheet 弹 / image 真在")
    print("=" * 50)

    driver = webdriver.Remote("http://127.0.0.1:4723/wd/hub", options=make_opts())
    time.sleep(3)

    # === 0) 检测网络弹窗 + 让用户手点 ===
    print("\n[0] 检测 iOS 网络授权弹窗")
    state = alert_state(driver)
    if state:
        print(f"   alert 弹了: {state[:60]}")
        print(f"   ⚠️ 测试框架不替用户做选择 — 请在 iPhone 上手点")
        if not wait_user_dismiss_alert(driver, max_sec=120):
            print("   失败: alert 未 dismiss")
            driver.quit()
            return 1
    else:
        print("   (无 alert，可能已 dismiss)")

    # === 1) 验收 #1: 网络授权 verify ===
    print("\n[验收 1] 网络授权 verify — vision API 实际跑通")
    # vision API 调用是端到端: 需要 iPhone 网络通 + DNS 解析 minimax + TLS + 收 200
    # 如果 vision 失败 → 网络没通 → 验收 1 fail
    print("   tap '用示例图（测试）'")
    el = driver.find_element("xpath", '//*[contains(@label, "用示例图")]')
    el.click()
    time.sleep(3)
    print("   tap '胶片框'")
    el = driver.find_element("xpath", '//*[contains(@label, "胶片框")]')
    el.click()
    time.sleep(2)
    print("   tap 'AI 算这顿值不值得' (触发 vision API)")
    el = driver.find_element("xpath", '//*[contains(@label, "AI 算这顿")]')
    el.click()

    print("   等 kcal (max 90s) — vision 跑通 = 网络真授权了")
    kcal_ok = False
    for i in range(45):
        time.sleep(2)
        try:
            if driver.find_element("xpath", '//*[contains(@label, "kcal")]').is_displayed():
                print(f"   ✅ kcal 出现 @ {(i+1)*2}s — vision API 通了 = 网络授权 verify OK")
                kcal_ok = True
                break
        except: pass
    if not kcal_ok:
        print(f"   ❌ 90s 内 kcal 没出现 — vision API 失败 = 网络未授权")
        shot(driver, "v3-FAIL-no-kcal")
        driver.quit()
        return 1
    shot(driver, "v3-1-vision-done")

    # === 2) tap 分享 ===
    print("\n[2] tap '分享' 按钮")
    el = driver.find_element("xpath", '//*[contains(@label, "分享")]')
    el.click()
    print("   ✅ click sent")
    time.sleep(6)
    shot(driver, "v3-2-share-clicked")

    # === 3) 验收 #2: share sheet 弹 ===
    print("\n[验收 2] share sheet 真弹 verify")
    src = driver.page_source
    sheet_markers = ["活动", "AirDrop", "拷贝", "UIActivity", "Message", "Copy to"]
    sheet_found = [k for k in sheet_markers if k in src]
    if sheet_found:
        print(f"   ✅ share sheet 弹了 (markers: {sheet_found})")
    else:
        print(f"   ❌ share sheet 没弹")

    # === 4) 验收 #3: image 真在 sheet ===
    print("\n[验收 3] image 真在 sheet verify")
    image_actions = ["Save Image", "存储图像", "存储图片", "保存到相册", "Save to Photos", "拷贝"]
    image_found = [a for a in image_actions if a in src]
    if image_found:
        print(f"   ✅ image 在 sheet (actions: {image_found})")
    else:
        print(f"   ⚠️ 没找到 Save Image action")
        labels = [m.group(1) for m in re.finditer(r'label="([^"]+)"', src) if m.group(1) and len(m.group(1)) < 30]
        print(f"   当前 label: {labels[:30]}")

    # === 5) 验收 #5: 点 Save Image + 验证存到相册 ===
    print("\n[验收 5] tap 'Save Image' 验证 image 真存到相册")
    save_ok = False
    try:
        # 找 Save Image 按钮 (iOS 18+ 中文 "存储图像" / 英文 "Save Image")
        el = None
        for label in ["Save Image", "存储图像", "保存到照片", "Save to Photos"]:
            try:
                el = driver.find_element("xpath", f'//*[contains(@label, "{label}")]')
                print(f"   找到按钮: {label}")
                break
            except: continue
        if el is None:
            print("   ❌ 找不到 Save Image 按钮")
        else:
            el.click()
            print("   ✅ tap Save Image")
            time.sleep(4)
            # iOS 16+ 保存成功会弹 alert "已添加" / "Added"
            try:
                al = driver.switch_to.alert
                txt = al.text
                print(f"   alert: {txt[:60]}")
                if any(k in txt for k in ["已添加", "Added", "已保存", "Saved"]):
                    print(f"   ✅ image 真存到相册")
                    save_ok = True
                al.accept()  # dismiss alert
                time.sleep(2)
            except:
                # 无 alert，看 share sheet 是否 dismiss
                print("   ⚠️ 无 alert — 看 share sheet 状态")
        shot(driver, "v3-3-save-image")
    except Exception as e:
        print(f"   ❌: {e}")

    # === 6) 验收 #4: BDD syslog ===
    print("\n[验收 4] syslog BDD 输出 verify")
    logs = driver.get_log('syslog')
    bdd = [l.get('message','') for l in logs if 'BDD' in l.get('message','')]
    print(f"   BDD log 数: {len(bdd)}")
    for m in bdd[-8:]:
        print(f"   {m[:200]}")

    # === 总结 ===
    print("\n" + "=" * 50)
    print("5 项硬验收结果:")
    print(f"  1. 网络授权 (vision 通):   {'✅' if kcal_ok else '❌'}")
    print(f"  2. share sheet 弹:         {'✅' if sheet_found else '❌'}")
    print(f"  3. image 在 sheet:         {'✅' if image_found else '⚠️ 待 verify'}")
    print(f"  4. Save Image 真存相册:    {'✅' if save_ok else '⚠️'}")
    print(f"  5. BDD syslog 输出:        {'✅' if bdd else '⚠️'}")
    print("=" * 50)

    driver.quit()
    return 0 if (sheet_found and image_found and save_ok) else 1


if __name__ == "__main__":
    sys.exit(main())


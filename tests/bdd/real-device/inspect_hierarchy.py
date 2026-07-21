"""Dump 完整 hierarchy，找 a11y label 真实值"""
from appium import webdriver
from appium.options.ios import XCUITestOptions
import time

UDID = "00008101-000914AE11F9001E"
BUNDLE = "com.vincent.plf.flutter"
TEAM_ID = "5DCJKSP8CQ"

opts = XCUITestOptions()
opts.platform_version = "26.6"
opts.device_name = "iPhone 12"
opts.udid = UDID
opts.bundle_id = BUNDLE
opts.no_reset = True
opts.new_command_timeout = 300
opts.set_capability("xcodeOrgId", TEAM_ID)
opts.set_capability("xcodeSigningId", "Apple Development")
opts.set_capability("includeNonModalElements", True)

driver = webdriver.Remote("http://127.0.0.1:4723/wd/hub", options=opts)
time.sleep(5)
driver.save_screenshot("/tmp/real-device-bdd/inspect.png")
src = driver.page_source
# 找所有 label/name 包含"示例"或"胶片"或"算"
import re
for m in re.finditer(r'label="([^"]+)"\s+name="([^"]+)"', src):
    lbl, nm = m.group(1), m.group(2)
    if any(k in lbl for k in ['示例', '胶片', '算', '分享', '漂亮', 'kcal', '蛋白', '碳水', '脂肪', '选一']):
        print(f"label='{lbl}' name='{nm}'")
print("---")
# 也试 -ios class chain
for m in re.finditer(r'<XCUIElementType(?:Button|StaticText)\b[^/]*?(?:name|label)="([^"]+)"', src):
    txt = m.group(1)
    if any(k in txt for k in ['示例', '胶片', '算', '分享', '漂亮', 'kcal', '蛋白', '碳水', '脂肪', '选一']):
        print(f"elem: {txt}")
driver.quit()

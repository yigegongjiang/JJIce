//
//  main.swift
//  JJIce
//

import AppKit

// 纯代码 AppKit（无 storyboard / nib）：`@main` 等价于调用 `NSApplicationMain`，
// 而后者在缺少 Interface Builder 连接时不会挂上 delegate，导致
// `applicationDidFinishLaunching` 永不触发、状态栏图标永不创建（进程存活却零表现）。
// 故在此手动创建 NSApplication 并显式赋 delegate 再进事件循环。
// 顺序要紧：先取 `NSApplication.shared` 完成 NSApp 初始化，再创建并挂载 delegate。
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

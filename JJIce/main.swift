//
//  main.swift
//  JJIce
//

import AppKit

// Code-only AppKit app: create NSApplication, attach the delegate, then enter the event loop.
// Using `@main`/`NSApplicationMain` without Interface Builder wiring leaves the delegate unset.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

import AppKit

let app = NSApplication.shared
let controller = AppController()

app.setActivationPolicy(.accessory)
app.delegate = controller
app.run()

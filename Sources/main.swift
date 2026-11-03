import Cocoa
import WebKit

final class Editor: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    var window: NSWindow!
    var web: WKWebView!
    var status: NSTextField!
    var currentURL: URL?
    var pendingURL: URL?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem(); mainMenu.addItem(appItem)
        let appMenu = NSMenu(); appMenu.addItem(withTitle: "退出网页可视化编辑器", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); appItem.submenu = appMenu
        let fileItem = NSMenuItem(); mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "文件"); fileMenu.addItem(withTitle: "打开…", action: #selector(openFile), keyEquivalent: "o").target = self; fileMenu.addItem(withTitle: "保存", action: #selector(saveFile), keyEquivalent: "s").target = self; fileItem.submenu = fileMenu
        NSApp.mainMenu = mainMenu
        let config = WKWebViewConfiguration()
        web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 1200,height: 850), styleMask: [.titled,.closable,.miniaturizable,.resizable], backing: .buffered, defer: false)
        window.title = "网页可视化编辑器"
        window.center()
        let container = NSView()
        let bar = NSStackView(); bar.orientation = .horizontal; bar.spacing = 8; bar.alignment = .centerY
        func button(_ title:String,_ action:Selector) -> NSButton { let b=NSButton(title:title,target:self,action:action); b.bezelStyle = .rounded; return b }
        [button("打开 HTML",#selector(openFile)),button("保存",#selector(saveFile)),button("另存为…",#selector(saveAs)),button("撤销",#selector(undoEdit)),button("重做",#selector(redoEdit)),button("加粗",#selector(bold)),button("斜体",#selector(italic))].forEach { bar.addArrangedSubview($0) }
        let imageBar = NSStackView(); imageBar.orientation = .horizontal; imageBar.spacing = 8
        [button("插入图片",#selector(insertImage)),button("替换选中图片",#selector(replaceImage)),button("调整图片宽度",#selector(resizeImage)),button("删除选中图片",#selector(deleteImage)),button("编辑图表文字",#selector(editSVGText))].forEach { imageBar.addArrangedSubview($0) }
        status = NSTextField(labelWithString:"打开 HTML 后，点击页面文字直接编辑；链接需按住 Command 点击。")
        status.textColor = .secondaryLabelColor; status.font = .systemFont(ofSize: 12)
        [bar,imageBar,web,status].forEach { $0.translatesAutoresizingMaskIntoConstraints=false; container.addSubview($0) }
        NSLayoutConstraint.activate([bar.topAnchor.constraint(equalTo:container.topAnchor,constant:10),bar.leadingAnchor.constraint(equalTo:container.leadingAnchor,constant:12),bar.trailingAnchor.constraint(lessThanOrEqualTo:container.trailingAnchor,constant:-12),imageBar.topAnchor.constraint(equalTo:bar.bottomAnchor,constant:5),imageBar.leadingAnchor.constraint(equalTo:container.leadingAnchor,constant:12),imageBar.trailingAnchor.constraint(lessThanOrEqualTo:container.trailingAnchor,constant:-12),web.topAnchor.constraint(equalTo:imageBar.bottomAnchor,constant:8),web.leadingAnchor.constraint(equalTo:container.leadingAnchor),web.trailingAnchor.constraint(equalTo:container.trailingAnchor),web.bottomAnchor.constraint(equalTo:status.topAnchor,constant:-5),status.leadingAnchor.constraint(equalTo:container.leadingAnchor,constant:12),status.trailingAnchor.constraint(equalTo:container.trailingAnchor,constant:-12),status.bottomAnchor.constraint(equalTo:container.bottomAnchor,constant:-8)])
        window.contentView = container; window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
        if let url = pendingURL { pendingURL = nil; openURL(url); return }
        web.loadHTMLString("<meta charset='utf-8'><div style='font:18px -apple-system;padding:55px;color:#294155'><h2>网页可视化编辑器</h2><p>点击“打开 HTML”，在页面上点击文字进行修改。</p><p>使用“另存为”保留一份原始文件。图表和复杂布局仍需在原代码中编辑。</p></div>",baseURL:nil)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard currentURL != nil else { return }
        web.evaluateJavaScript("""
        document.designMode='on';
        window._editorImg=null; window._editorRange=null; window._editorSVGText=null;
        const st=document.createElement('style'); st.id='__editor_visual_style'; st.textContent='img.__editor_selected {outline: 3px solid #00a7ad !important; outline-offset: 3px !important;}'; document.head.appendChild(st);
        document.addEventListener('click', e => { window._editorSVGText = e.target.closest && e.target.closest('svg text'); if(window._editorImg) window._editorImg.classList.remove('__editor_selected'); window._editorImg = e.target.tagName === 'IMG' ? e.target : null; if(window._editorImg){window._editorImg.classList.add('__editor_selected'); e.preventDefault();} });
        document.addEventListener('selectionchange', () => {const s=window.getSelection(); if(s.rangeCount && document.body.contains(s.anchorNode)) window._editorRange=s.getRangeAt(0).cloneRange();});
        """)
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy)->Void) {
        if action.navigationType == .linkActivated { decisionHandler(.cancel); if let url=action.request.url, ["http","https"].contains(url.scheme ?? "") { NSWorkspace.shared.open(url) }; return }
        decisionHandler(.allow)
    }
    @objc func openFile() {
        let p=NSOpenPanel(); p.allowedContentTypes = [.html]; p.allowsMultipleSelection=false
        guard p.runModal() == .OK, let url=p.url else { return }
        openURL(url)
    }
    func application(_ sender: NSApplication, openFile filename: String) -> Bool { receiveFile(URL(fileURLWithPath: filename)); return true }
    func application(_ sender: NSApplication, openFiles filenames: [String]) { if let name=filenames.first { receiveFile(URL(fileURLWithPath:name)); sender.reply(toOpenOrPrint:.success) } else { sender.reply(toOpenOrPrint:.failure) } }
    func application(_ application: NSApplication, open urls: [URL]) { if let url=urls.first { receiveFile(url) } }
    func receiveFile(_ url: URL) { if web == nil || window == nil { pendingURL=url } else { openURL(url); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true) } }
    func openURL(_ url: URL) {
        do { let html=try String(contentsOf:url,encoding:.utf8); currentURL=url; window.title="网页可视化编辑器 — \(url.lastPathComponent)"; status.stringValue="点击图片选中，再使用图片工具；点击文字可编辑。"; web.loadHTMLString(html,baseURL:url.deletingLastPathComponent()) } catch { alert("无法打开文件：\(error.localizedDescription)") }
    }
    func alert(_ text:String) { let a=NSAlert(); a.messageText=text; a.runModal() }
    func command(_ name:String) { web.evaluateJavaScript("document.execCommand('\(name)', false, null)") }
    @objc func undoEdit(){command("undo")}; @objc func redoEdit(){command("redo")}; @objc func bold(){command("bold")}; @objc func italic(){command("italic")}
    func imageData() -> String? {
        guard currentURL != nil else { alert("请先打开 HTML 文件。"); return nil }
        let panel=NSOpenPanel(); panel.allowedContentTypes=[.png,.jpeg,.gif,.tiff,.webP]; panel.allowsMultipleSelection=false
        guard panel.runModal() == .OK, let url=panel.url else { return nil }
        do { let data=try Data(contentsOf:url); let ext=url.pathExtension.lowercased(); let mime = ext == "png" ? "image/png" : ext == "gif" ? "image/gif" : ext == "webp" ? "image/webp" : ext == "tif" || ext == "tiff" ? "image/tiff" : "image/jpeg"; return "data:\(mime);base64," + data.base64EncodedString() } catch { alert("无法读取图片：\(error.localizedDescription)"); return nil }
    }
    func jsonString(_ value:String) -> String { let d=try! JSONSerialization.data(withJSONObject:[value]); let a=String(data:d,encoding:.utf8)!; return String(a.dropFirst().dropLast()) }
    @objc func insertImage() { guard let src=imageData() else {return}; let js="""
        (() => { const img=document.createElement('img'); img.src=\(jsonString(src)); img.alt='插入的图片'; img.style.maxWidth='100%'; const r=window._editorRange; if(r && document.body.contains(r.commonAncestorContainer)){r.deleteContents();r.insertNode(img);} else {document.body.appendChild(img);} return true; })()
        """; web.evaluateJavaScript(js); status.stringValue="图片已插入到光标处；如果未选择位置，则添加到页面末尾。" }
    func withSelected(_ action:String) { web.evaluateJavaScript("""
        (()=>{const i=window._editorImg;if(!i || !i.isConnected)return false; \(action); return true;})()
        """) { [weak self] value, error in if error != nil || (value as? Bool) != true { self?.alert("请先在页面中点击要编辑的图片。SVG 图表暂不支持此操作。") } } }
    @objc func replaceImage() { guard let src=imageData() else{return}; withSelected("i.src=\(jsonString(src))") }
    @objc func deleteImage() { withSelected("i.remove(); window._editorImg=null") }
    @objc func resizeImage() { let a=NSAlert(); a.messageText="设置图片宽度"; a.informativeText="输入宽度（像素），高度将按比例调整。"; let f=NSTextField(string:"600"); f.frame=NSRect(x:0,y:0,width:200,height:24); a.accessoryView=f; a.addButton(withTitle:"确定"); a.addButton(withTitle:"取消"); guard a.runModal() == .alertFirstButtonReturn else{return}; guard let width=Int(f.stringValue), (1...10000).contains(width) else {alert("请输入 1 至 10000 的整数。"); return}; withSelected("i.style.width='\(width)px'; i.style.height='auto'; i.style.maxWidth='100%'; i.removeAttribute('width'); i.removeAttribute('height')") }
    @objc func editSVGText() {
        web.evaluateJavaScript("window._editorSVGText && window._editorSVGText.isConnected ? window._editorSVGText.textContent : null") { [weak self] value, error in
            guard let self=self else { return }
            guard let original=value as? String else { self.alert("请先点击图表中要修改的一行文字，再点“编辑图表文字”。"); return }
            let a=NSAlert(); a.messageText="编辑图表文字"; a.informativeText="修改选中的这一行文字。"; let f=NSTextField(string:original); f.frame=NSRect(x:0,y:0,width:380,height:24); a.accessoryView=f; a.addButton(withTitle:"确定"); a.addButton(withTitle:"取消")
            guard a.runModal() == .alertFirstButtonReturn else { return }
            self.web.evaluateJavaScript("if(window._editorSVGText && window._editorSVGText.isConnected) window._editorSVGText.textContent=\(self.jsonString(f.stringValue))")
        }
    }
    @objc func saveFile(){ guard let url=currentURL else { saveAs(); return }; write(to:url) }
    @objc func saveAs(){ guard currentURL != nil else { alert("请先打开 HTML 文件。"); return }; let p=NSSavePanel(); p.allowedContentTypes=[.html]; p.nameFieldStringValue=currentURL?.deletingPathExtension().lastPathComponent.appending("-编辑版.html") ?? "编辑版.html"; guard p.runModal() == .OK, let url=p.url else{return}; write(to:url) }
    func write(to url:URL) {
        guard currentURL != nil else { alert("请先打开 HTML 文件。"); return }
        web.evaluateJavaScript("(()=>{const c=document.documentElement.cloneNode(true);c.querySelector('#__editor_visual_style')?.remove();c.querySelectorAll('.__editor_selected').forEach(e=>{e.classList.remove('__editor_selected');if(!e.getAttribute('class'))e.removeAttribute('class')});return '<!DOCTYPE html>\\n'+c.outerHTML})()") { [weak self] value,error in
            guard let self=self else{return}; guard let html=value as? String, error == nil else { self.alert("保存失败：无法读取页面内容。"); return }
            do { try html.write(to:url,atomically:true,encoding:.utf8); self.currentURL=url; self.window.title="网页可视化编辑器 — \(url.lastPathComponent)"; self.status.stringValue="已保存：\(url.lastPathComponent)" } catch { self.alert("保存失败：\(error.localizedDescription)") }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { true }
}
let app=NSApplication.shared
let delegate=Editor(); app.delegate=delegate; app.setActivationPolicy(.regular); app.run()

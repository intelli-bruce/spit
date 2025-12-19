import SwiftUI
import WebKit

struct MarkdownPreviewView: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = convertMarkdownToHTML(markdown)
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func convertMarkdownToHTML(_ markdown: String) -> String {
        var html = markdown

        // Headers
        html = html.replacingOccurrences(of: "(?m)^### (.+)$", with: "<h3>$1</h3>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^## (.+)$", with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^# (.+)$", with: "<h1>$1</h1>", options: .regularExpression)

        // Bold and Italic
        html = html.replacingOccurrences(of: "\\*\\*\\*(.+?)\\*\\*\\*", with: "<strong><em>$1</em></strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)

        // Inline code
        html = html.replacingOccurrences(of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)

        // Code blocks
        html = html.replacingOccurrences(of: "```([\\s\\S]*?)```", with: "<pre><code>$1</code></pre>", options: .regularExpression)

        // Links
        html = html.replacingOccurrences(of: "\\[([^\\]]+)\\]\\(([^)]+)\\)", with: "<a href=\"$2\">$1</a>", options: .regularExpression)

        // Horizontal rules
        html = html.replacingOccurrences(of: "(?m)^---+$", with: "<hr>", options: .regularExpression)

        // Unordered lists
        html = html.replacingOccurrences(of: "(?m)^- (.+)$", with: "<li>$1</li>", options: .regularExpression)

        // Ordered lists
        html = html.replacingOccurrences(of: "(?m)^\\d+\\. (.+)$", with: "<li>$1</li>", options: .regularExpression)

        // Paragraphs (convert double newlines)
        html = html.replacingOccurrences(of: "\n\n", with: "</p><p>")

        // Single newlines to <br>
        html = html.replacingOccurrences(of: "\n", with: "<br>")

        // Wrap list items
        html = html.replacingOccurrences(of: "(<li>.*?</li>)+", with: "<ul>$0</ul>", options: .regularExpression)

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                :root {
                    color-scheme: light dark;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    font-size: 14px;
                    line-height: 1.6;
                    padding: 20px;
                    max-width: 100%;
                    margin: 0 auto;
                    color: var(--text-color);
                    background: var(--bg-color);
                }
                @media (prefers-color-scheme: dark) {
                    :root {
                        --text-color: #e0e0e0;
                        --bg-color: #1e1e1e;
                        --code-bg: #2d2d2d;
                        --border-color: #444;
                    }
                }
                @media (prefers-color-scheme: light) {
                    :root {
                        --text-color: #333;
                        --bg-color: #fff;
                        --code-bg: #f5f5f5;
                        --border-color: #ddd;
                    }
                }
                h1, h2, h3 {
                    margin-top: 1.5em;
                    margin-bottom: 0.5em;
                    font-weight: 600;
                }
                h1 { font-size: 1.8em; border-bottom: 1px solid var(--border-color); padding-bottom: 0.3em; }
                h2 { font-size: 1.4em; color: #666; }
                h3 { font-size: 1.2em; }
                code {
                    background: var(--code-bg);
                    padding: 2px 6px;
                    border-radius: 4px;
                    font-family: "SF Mono", Monaco, "Courier New", monospace;
                    font-size: 0.9em;
                }
                pre {
                    background: var(--code-bg);
                    padding: 16px;
                    border-radius: 8px;
                    overflow-x: auto;
                }
                pre code {
                    background: none;
                    padding: 0;
                }
                hr {
                    border: none;
                    border-top: 1px solid var(--border-color);
                    margin: 2em 0;
                }
                ul, ol {
                    padding-left: 2em;
                }
                li {
                    margin: 0.5em 0;
                }
                a {
                    color: #007AFF;
                    text-decoration: none;
                }
                a:hover {
                    text-decoration: underline;
                }
                p {
                    margin: 1em 0;
                }
            </style>
        </head>
        <body>
            <p>\(html)</p>
        </body>
        </html>
        """
    }
}

"""Wraps app.html (the page as published in Claude) into index.html, a full page for GitHub Pages / home screen."""
import os
HERE = os.path.dirname(os.path.abspath(__file__))
app = open(os.path.join(HERE, "app.html"), encoding="utf8").read()
head = """<!doctype html>
<html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-title" content="NoteTok">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="theme-color" content="#202124">
<link rel="apple-touch-icon" href="../v1/icon-180.png">
</head><body>
"""
open(os.path.join(HERE, "index.html"), "w", encoding="utf8").write(head + app + "\n</body></html>\n")
print("built index.html")

# Right Panel

https://github.com/raminturne/right-panel

MIT License

Copyright (c) 2026 raminturne

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Nex and fonts

Nex is MIT licensed, copyright (c) 2026 Nex contributors. Its licence text is included in `assets/notices/nex.txt` and exposed in the app licences page. Source reference: https://github.com/sanyzrn/DbsNex at `4861feac41530c951cb9e637ff921c6472d7de58`.

The Inter and Vazirmatn assets are the existing Nex font files. They are licensed under SIL Open Font License 1.1; complete original notices are in `assets/notices/inter-OFL.txt` and `assets/notices/vazirmatn-OFL.txt`, also exposed in the app. Original licence sources: https://github.com/rsms/inter/blob/master/LICENSE.txt and https://github.com/rastikerdar/vazirmatn/blob/master/OFL.txt.

The normal Flutter licences page also displays dependency notices. Windows Segoe UI Emoji is used from the host OS for rendering/tests; its font file is not redistributed.

## Windows intelligence storage

Cloud adapters and pure-Dart AI contracts follow DbsNex Android 2.1.6 at `67930daa7230273055107ac210faa8b86167e540`. The desktop uses `flutter_secure_storage` (10.3.4 in the lockfile) and its Windows implementation (4.2.2) for account-bound credential protection. Their original dependency licenses are included through the Flutter license registry. No provider key or local inference model is distributed.


## PDF reading

pdfrx 2.4.8, pdfrx_engine 0.4.7 and pdfium_dart/pdfium_flutter provide offline
PDF reading under their bundled package licenses. PDFium's pinned
`chromium/7811` Windows distribution and all 16 included upstream notices are
preserved in [assets/notices/pdfium.txt](assets/notices/pdfium.txt) and registered
in About → Licenses. PDFium is downloaded at build time and included in setup.

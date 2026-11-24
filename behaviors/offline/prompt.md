# #offline — Offline
The page goes to a reader the server can't reach: hand over a file, not a URL.

∀ #html pages: an offline copy to send; its answers come back as the .edn its Download saves, which #html reads. offline ∩ {WaitingOnACopy, URLAsHandOff, OfflineWithoutHtml} = ∅    -- HARD CONSTRAINT
Applies with #html only. Without #html: say #offline needs #html, then carry on as if #offline were absent.
With #html: write and check the page as #html says, then export it: export_page, else `html-channel export <session>/<page>`. Start no wait and give no page URL. Give the copy's path, and say: it opens from disk in a desktop browser, not on an iPhone; it keeps answers in the reader's browser; the reader sends back the .edn its Download answers button saves. Say the copy carries the page's code-link repo roots as defaults, before the user sends it. A rewritten page needs a new export and a new copy for the reader.
No export (html-channel older than 0.9.0): say #offline needs html-channel 0.9.0 or newer, then carry on as #html alone.

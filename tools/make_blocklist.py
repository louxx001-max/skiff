"""Builds Sources/blocklist.json (WebKit content rules) from Peter Lowe's ad-server list."""
import json, re, sys, urllib.request

LIST = "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=nohtml&showintro=0&mimetype=plaintext"
EXTRA = """doubleclick.net googlesyndication.com googleadservices.com adservice.google.com
amazon-adsystem.com taboola.com outbrain.com criteo.com criteo.net adnxs.com popads.net
popcash.net propellerads.com exoclick.com adsterra.com onclickads.net mgid.com revcontent.com
adform.net pubmatic.com rubiconproject.com openx.net moatads.com scorecardresearch.com""".split()
# Common ad containers hidden on every page so blocked ads don't leave empty boxes.
HIDE = ", ".join([
    "ins.adsbygoogle", ".adsbygoogle", "[id^='google_ads_iframe']", "[id^='div-gpt-ad']",
    "[data-ad-slot]", "amp-ad", "amp-embed[type='taboola']", ".trc_related_container", ".OUTBRAIN",
])

hosts = set(EXTRA)
try:
    text = urllib.request.urlopen(LIST, timeout=30).read().decode()
    hosts |= {h.strip().lower() for h in text.splitlines() if re.fullmatch(r"[a-z0-9.-]+", h.strip().lower())}
except Exception as e:
    print("warning: list download failed, using built-in domains only:", e, file=sys.stderr)

rules = [{"trigger": {"url-filter": r"^[^:]+://+([^:/]+\.)?" + h.replace(".", r"\.") + "[:/]"},
          "action": {"type": "block"}} for h in sorted(hosts)]
rules.append({"trigger": {"url-filter": ".*"}, "action": {"type": "css-display-none", "selector": HIDE}})
json.dump(rules, open(sys.argv[1], "w"))
print(f"{len(hosts)} blocked domains")

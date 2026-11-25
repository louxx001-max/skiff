"""Prints the SideStore source JSON for build number argv[1] and IPA argv[2]."""
import datetime, json, os, sys

repo = "louxx001-max/skiff"
build, ipa = sys.argv[1], sys.argv[2]
version = f"1.0.{build}"
print(json.dumps({
    "name": "Skiff",
    "identifier": "com.luke.skiff.source",
    "sourceURL": f"https://github.com/{repo}/releases/latest/download/source.json",
    "apps": [{
        "name": "Skiff",
        "bundleIdentifier": "com.luke.skiff",
        "developerName": "Luke",
        "subtitle": "Custom browser",
        "localizedDescription": "Tabs, ad blocking and pop-up blocking.",
        "iconURL": f"https://raw.githubusercontent.com/{repo}/main/Sources/Assets.xcassets/AppIcon.appiconset/icon.png",
        "tintColor": "1E5AC8",
        "versions": [{
            "version": version,
            "buildVersion": build,
            "date": datetime.date.today().isoformat(),
            "downloadURL": f"https://github.com/{repo}/releases/download/v{version}/Skiff.ipa",
            "size": os.path.getsize(ipa),
            "minOSVersion": "16.0",
        }],
        "appPermissions": {"entitlements": [], "privacy": {}},
    }],
    "news": [],
}, indent=2))

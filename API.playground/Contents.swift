import Defaults
import Foundation

Defaults[.deviceID] = "302f10ab-90e9-485d-a1fb-3ae5735a2193"
Defaults[.teamID] = "fd4e6814-440c-46d2-b240-4e0d2f786fbc"

let device = ReportingDevice(id: "302f10ab-90e9-485d-a1fb-3ae5735a2193", machineUUID: "5d486371-7841-4e4d-95c4-78c71cdaa44c")
let report = Report(passedCount: 1, failedCount: 2, disabledCount: 3, device: device, version: AppInfo.appVersion, lastChecked: Date().as3339String())

// $ curl -v \
//    -X PUT \
//    -H "Accept-Language: en;q=1.0, en-SI;q=0.9" \
//    -H "User-Agent: com.apple.dt.Xcode.PlaygroundStub-macosx/1.0 (com.apple.dt.Xcode.PlaygroundStub-macosx; build:1; macOS 12.0.0) Alamofire/5.4.3" \
//    -H "Accept-Encoding: br;q=1.0, gzip;q=0.9, deflate;q=0.8" \
//    -H "Content-Type: application/json" \
//    -d "{\"id\":\"302f10ab-90e9-485d-a1fb-3ae5735a2193\",\"machineUUID\":\"5d486371-7841-4e4d-95c4-78c71cdaa44c\"}" \
//    "https://dash.paretosecurity.com/api/v1/team/fd4e6814-440c-46d2-b240-4e0d2f786fbc/device"
try? Team.link(withDevice: device)

// $ curl -v \
//    -X POST \
//    -H "Accept-Language: en;q=1.0, en-SI;q=0.9" \
//    -H "User-Agent: com.apple.dt.Xcode.PlaygroundStub-macosx/1.0 (com.apple.dt.Xcode.PlaygroundStub-macosx; build:1; macOS 12.0.0) Alamofire/5.4.3" \
//    -H "Accept-Encoding: br;q=1.0, gzip;q=0.9, deflate;q=0.8" \
//    -H "Content-Type: application/json" \
//    -d "{\"passedCount\":1,\"version\":\"1.0\",\"device\":{\"id\":\"302f10ab-90e9-485d-a1fb-3ae5735a2193\",\"machineUUID\":\"5d486371-7841-4e4d-95c4-78c71cdaa44c\"},\"disabledCount\":3,\"lastChecked\":\"2021-09-20T09:09:49Z\",\"failedCount\":2}" \
//    "https://dash.paretosecurity.com/api/v1/team/fd4e6814-440c-46d2-b240-4e0d2f786fbc/device"
try? Team.update(withReport: report)

// $ curl -v \
//    -X DELETE \
//    -H "Accept-Language: en;q=1.0, en-SI;q=0.9" \
//    -H "User-Agent: com.apple.dt.Xcode.PlaygroundStub-macosx/1.0 (com.apple.dt.Xcode.PlaygroundStub-macosx; build:1; macOS 12.0.0) Alamofire/5.4.3" \
//    -H "Accept-Encoding: br;q=1.0, gzip;q=0.9, deflate;q=0.8" \
//    -H "Content-Type: application/json" \
//    -d "{\"id\":\"302f10ab-90e9-485d-a1fb-3ae5735a2193\",\"machineUUID\":\"5d486371-7841-4e4d-95c4-78c71cdaa44c\"}" \
//    "https://dash.paretosecurity.com/api/v1/team/fd4e6814-440c-46d2-b240-4e0d2f786fbc/device"
try? Team.unlink(withDevice: device)

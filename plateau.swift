// plateau: turn the macOS greyscale color filter on while video plays.
//
// Video detection: video players and browsers hold a "PreventUserIdleDisplaySleep"
// power assertion while video is playing. Audio-only playback holds only
// "PreventUserIdleSystemSleep", so it never triggers this.

import Foundation
import IOKit.pwr_mgt

let pollInterval: TimeInterval = 1
let offDelay: TimeInterval = 3 // keep grey this long after video stops (pause/seek flicker)
let ignoredProcesses: Set<String> = ["caffeinate", "powerd"] // keep-awake tools aren't video

// MediaAccessibility is private-ish, so load it at runtime. Category 1 = greyscale.
let greyscaleCategory: Int32 = 1
let lib = dlopen("/System/Library/Frameworks/MediaAccessibility.framework/MediaAccessibility", RTLD_NOW)
typealias SetEnabled = @convention(c) (Int32, Bool) -> Void
typealias GetEnabled = @convention(c) (Int32) -> Bool
guard let setSym = dlsym(lib, "MADisplayFilterPrefSetCategoryEnabled"),
      let getSym = dlsym(lib, "MADisplayFilterPrefGetCategoryEnabled") else {
    FileHandle.standardError.write(Data("MediaAccessibility display filter API not found\n".utf8))
    exit(1)
}
let setGreyscale = unsafeBitCast(setSym, to: SetEnabled.self)
let isGreyscale = unsafeBitCast(getSym, to: GetEnabled.self)

func processName(_ pid: pid_t) -> String {
    var buf = [CChar](repeating: 0, count: 256)
    proc_name(pid, &buf, UInt32(buf.count))
    return String(cString: buf)
}

func videoIsPlaying() -> Bool {
    var raw: Unmanaged<CFDictionary>?
    guard IOPMCopyAssertionsByProcess(&raw) == kIOReturnSuccess,
          let byPid = raw?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else { return false }
    for (pid, assertions) in byPid {
        let holdsDisplayAssertion = assertions.contains {
            ($0["AssertType"] as? String) == "PreventUserIdleDisplaySleep"
        }
        if holdsDisplayAssertion && !ignoredProcesses.contains(processName(pid.int32Value)) {
            return true
        }
    }
    return false
}

// Only undo greyscale that we turned on, so a user who already runs greyscale keeps it.
var weEnabledIt = false

func restore() {
    if weEnabledIt { setGreyscale(greyscaleCategory, false); weEnabledIt = false }
}

var signalSources: [DispatchSourceSignal] = [] // keep sources alive
for sig in [SIGINT, SIGTERM] {
    signal(sig, SIG_IGN)
    let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    src.setEventHandler { restore(); exit(0) }
    src.resume()
    signalSources.append(src)
}

var lastVideo = Date.distantPast
let timer = DispatchSource.makeTimerSource(queue: .main)
timer.schedule(deadline: .now(), repeating: pollInterval)
timer.setEventHandler {
    if videoIsPlaying() {
        lastVideo = Date()
        if !isGreyscale(greyscaleCategory) {
            setGreyscale(greyscaleCategory, true)
            weEnabledIt = true
        }
    } else if weEnabledIt && Date().timeIntervalSince(lastVideo) > offDelay {
        restore()
    }
}
timer.resume()
dispatchMain()

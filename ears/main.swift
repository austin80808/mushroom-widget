// Mushroom Ears: taps the Mac's system audio output and sends three loudness
// numbers (bass, mid, high RMS) to the mushroom widget over local UDP.
// Nothing is recorded or stored. It quits when the widget stops pinging it.

import AudioToolbox
import CoreAudio
import Foundation

let levelsPort: UInt16 = 47808  // widget listens here
let pingPort: UInt16 = 47809  // widget pings us here

func log(_ message: String) {
    let line = "\(Date()) \(message)\n"
    let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/MushroomEars.log")
    if let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        try? handle.close()
    } else {
        try? line.write(to: url, atomically: true, encoding: .utf8)
    }
}

func check(_ status: OSStatus, _ what: String) {
    if status != noErr {
        log("\(what) failed: \(status)")
        exit(1)
    }
}

func localAddress(_ port: UInt16) -> sockaddr_in {
    var addr = sockaddr_in()
    addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = port.bigEndian
    addr.sin_addr.s_addr = inet_addr("127.0.0.1")
    return addr
}

// Sockets: one to send levels, one to hear the widget's pings.
let outSock = socket(AF_INET, SOCK_DGRAM, 0)
var dest = localAddress(levelsPort)
let pingSock = socket(AF_INET, SOCK_DGRAM, 0)
var mine = localAddress(pingPort)
let bound = withUnsafePointer(to: &mine) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(pingSock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
    }
}
if bound != 0 {
    log("ping port busy, another copy is running")
    exit(0)
}
_ = fcntl(pingSock, F_SETFL, O_NONBLOCK)

// Default output device UID, needed as the aggregate device's clock.
var outputID = AudioObjectID(kAudioObjectUnknown)
var size = UInt32(MemoryLayout<AudioObjectID>.size)
var address = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain)
check(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &outputID), "default output")
var outputUID: CFString = "" as CFString
size = UInt32(MemoryLayout<CFString>.size)
address.mSelector = kAudioDevicePropertyDeviceUID
check(withUnsafeMutablePointer(to: &outputUID) {
    AudioObjectGetPropertyData(outputID, &address, 0, nil, &size, $0)
}, "output uid")

// A global tap on everything the Mac plays, left unmuted.
let tap = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
tap.uuid = UUID()
tap.name = "Mushroom Ears"
tap.isPrivate = true
tap.muteBehavior = .unmuted
var tapID = AudioObjectID(kAudioObjectUnknown)
check(AudioHardwareCreateProcessTap(tap, &tapID), "create tap")

var format = AudioStreamBasicDescription()
size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
address.mSelector = kAudioTapPropertyFormat
check(AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &format), "tap format")
let sampleRate = format.mSampleRate > 0 ? format.mSampleRate : 48000

let aggregate: [String: Any] = [
    kAudioAggregateDeviceNameKey: "Mushroom Ears",
    kAudioAggregateDeviceUIDKey: UUID().uuidString,
    kAudioAggregateDeviceMainSubDeviceKey: outputUID,
    kAudioAggregateDeviceIsPrivateKey: true,
    kAudioAggregateDeviceIsStackedKey: false,
    kAudioAggregateDeviceTapAutoStartKey: true,
    kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
    kAudioAggregateDeviceTapListKey: [[
        kAudioSubTapDriftCompensationKey: true,
        kAudioSubTapUIDKey: tap.uuid.uuidString,
    ]],
]
var aggregateID = AudioObjectID(kAudioObjectUnknown)
check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), "create aggregate")

// One-pole low-passes split the signal into bass (<150 Hz), mid and high (>2 kHz).
let bassCoef = Float(1 - exp(-2 * Double.pi * 150 / sampleRate))
let midCoef = Float(1 - exp(-2 * Double.pi * 2000 / sampleRate))
var lowState: Float = 0
var midState: Float = 0

var procID: AudioDeviceIOProcID?
let queue = DispatchQueue(label: "mushroom.ears.audio")
check(AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) { _, input, _, _, _ in
    let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
    guard let first = buffers.first, let data = first.mData else { return }
    let channels = max(Int(first.mNumberChannels), 1)
    let frames = Int(first.mDataByteSize) / MemoryLayout<Float32>.size / channels
    if frames == 0 { return }
    let samples = data.bindMemory(to: Float32.self, capacity: frames * channels)
    var bass: Float = 0
    var mid: Float = 0
    var high: Float = 0
    for frame in 0..<frames {
        var x: Float = 0
        for channel in 0..<channels { x += samples[frame * channels + channel] }
        x /= Float(channels)
        lowState += bassCoef * (x - lowState)
        midState += midCoef * (x - midState)
        bass += lowState * lowState
        mid += (midState - lowState) * (midState - lowState)
        high += (x - midState) * (x - midState)
    }
    let n = Float(frames)
    let message = String(format: "%.6f %.6f %.6f", sqrt(bass / n), sqrt(mid / n), sqrt(high / n))
    message.withCString { text in
        withUnsafePointer(to: &dest) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                _ = sendto(outSock, text, strlen(text), 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }
}, "create io proc")
check(AudioDeviceStart(aggregateID, procID), "start")
log("listening at \(sampleRate) Hz")

// Quit when the widget has not pinged for a while.
var lastPing = Date()
let timer = DispatchSource.makeTimerSource(queue: .main)
timer.schedule(deadline: .now() + 1, repeating: 1)
timer.setEventHandler {
    var scratch = [UInt8](repeating: 0, count: 64)
    while recv(pingSock, &scratch, scratch.count, 0) > 0 { lastPing = Date() }
    if Date().timeIntervalSince(lastPing) > 6 {
        AudioDeviceStop(aggregateID, procID)
        if let procID { AudioDeviceDestroyIOProcID(aggregateID, procID) }
        AudioHardwareDestroyAggregateDevice(aggregateID)
        AudioHardwareDestroyProcessTap(tapID)
        log("widget gone, quitting")
        exit(0)
    }
}
timer.resume()
dispatchMain()

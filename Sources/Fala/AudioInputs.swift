import CoreAudio

/// Microfones do Mac e qual está em uso (o padrão do sistema).
enum AudioInputs {
    struct Device: Identifiable { let id: AudioDeviceID; let name: String }

    private static func address(_ selector: AudioObjectPropertySelector,
                                _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static func list() -> [Device] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var addr = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }

        return ids.compactMap { id in
            var cfg = address(kAudioDevicePropertyStreamConfiguration, kAudioDevicePropertyScopeInput)
            var sz: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &cfg, 0, nil, &sz) == noErr, sz > 0 else { return nil }
            let buf = UnsafeMutableRawPointer.allocate(byteCount: Int(sz), alignment: 16)
            defer { buf.deallocate() }
            guard AudioObjectGetPropertyData(id, &cfg, 0, nil, &sz, buf) == noErr else { return nil }
            let list = UnsafeMutableAudioBufferListPointer(buf.assumingMemoryBound(to: AudioBufferList.self))
            guard list.reduce(0, { $0 + Int($1.mNumberChannels) }) > 0 else { return nil }   // só entradas

            var nameAddr = address(kAudioObjectPropertyName)
            var name: Unmanaged<CFString>?
            var ns = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &ns, &name) == noErr,
                  let cf = name?.takeRetainedValue() else { return nil }
            return Device(id: id, name: cf as String)
        }
    }

    static var current: AudioDeviceID {
        var addr = address(kAudioHardwarePropertyDefaultInputDevice)
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return id
    }

    static func select(_ id: AudioDeviceID) {
        var addr = address(kAudioHardwarePropertyDefaultInputDevice)
        var dev = id
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil,
                                   UInt32(MemoryLayout<AudioDeviceID>.size), &dev)
    }
}

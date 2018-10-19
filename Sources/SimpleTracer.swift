//
//  SimpleTracer.swift
//  SimpleTracer
//
//  Created by Wang Xingbin on 2018/10/18.
//  Copyright © 2018 Beary Innovative. All rights reserved.
//

import Foundation

public protocol SimpleTracerLogger: class {
    func logTrace(_ trace: String)
}

public class SimpleTracer: NSObject {
    
    public var host: String
    
    private var pinger: SimplePing?
    
    private var ipAddress: String?
    private var icmpSrcAddress: String?
    
    private var currentTTL: Int?
    private var packetCountPerTTL: Int?
    private var maxTraceTTL: Int = 30
    private var sendSequence: UInt16?
    
    private var startDate: Date?
    private var sendTimer: Timer?
    private var sendTimeoutTimer: Timer?
    
    public private(set) var result: String = ""
    public weak var logger: SimpleTracerLogger?
    public var completion: ((String) -> Void)?
    
    public init(host: String) {
        self.host = host
        super.init()
    }
    
    private static var _current: SimpleTracer?
    
    @discardableResult
    public static func trace(host: String,
                             logger: SimpleTracerLogger? = nil,
                             maxTraceTTL: Int = 30,
                             completion: ((String) -> Void)?) -> SimpleTracer {
        let tracer = SimpleTracer(host: host)
        tracer.logger = logger
        tracer.maxTraceTTL = maxTraceTTL
        tracer.completion = completion
        _current = tracer
        _current?.start()
        return _current!
    }
    
    public func start() {
        pinger = SimplePing(hostName: host)
        pinger?.delegate = self
        pinger?.start()
    }
    
    public func stop() {
        sendTimer?.invalidate()
        sendTimer = nil
        sendTimeoutTimer?.invalidate()
        sendTimeoutTimer = nil
        
        pinger?.stop()
        pinger = nil
        
        completion?(result)
    }
}

// MARK: - Private
private extension SimpleTracer {
    func appendResult(_ result: String) {
        self.result.append(result)
        logger?.logTrace(result)
        #if DEBUG
        NSLog("SimpleTracer: %@", result)
        #endif
    }
    
    func sendPing() -> Bool {
        self.currentTTL! += 1
        if self.currentTTL! > maxTraceTTL {
            appendResult("TTL exceed the Max, stop tracing")
            stop()
            return false
        }
        sendPing(withTTL: self.currentTTL!)
        return true
    }
    
    func sendPing(withTTL ttl: Int) {
        packetCountPerTTL = 0
        
        pinger?.setTTL(Int32(ttl))
        pinger?.send()
        
        sendTimer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(checkSingleRoundTimeout), userInfo: nil, repeats: false)
    }
    
    func invalidSendTimer() {
        sendTimer?.invalidate()
        sendTimer = nil
    }
    
    @objc
    func checkSingleRoundTimeout() {
        var msg: String = ""
        switch self.packetCountPerTTL! {
        case 0:
            msg = "#\(sendSequence!) *  *  *\n"
        case 1:
            msg = "  *  *\n"
        case 2:
            msg = "  *\n"
        default:
            break
        }
        appendResult(msg)
        _ = sendPing()
    }
}

// MARK: Utilities from: https://developer.apple.com/library/archive/samplecode/SimplePing/
extension SimpleTracer {
    
    /// Returns the string representation of the supplied address.
    ///
    /// - parameter address: Contains a `(struct sockaddr)` with the address to render.
    ///
    /// - returns: A string representation of that address.
    
    static func displayAddressForAddress(address: NSData) -> String {
        var hostStr = [Int8](repeating: 0, count: Int(NI_MAXHOST))
        
        let success = getnameinfo(
            address.bytes.assumingMemoryBound(to: sockaddr.self),
            socklen_t(address.length),
            &hostStr,
            socklen_t(hostStr.count),
            nil,
            0,
            NI_NUMERICHOST
            ) == 0
        let result: String
        if success {
            result = String(cString: hostStr)
        } else {
            result = "?"
        }
        return result
    }
}

// MARK: - SimplePingDelegate
extension SimpleTracer: SimplePingDelegate {
    public func simplePing(_ pinger: SimplePing, didStartWithAddress address: Data) {
        ipAddress = SimpleTracer.displayAddressForAddress(address: address as NSData)
        let msg = "Start tracing \(host): \(ipAddress ?? "* * *")\n"
        NSLog(msg)
        appendResult(msg)
        
        currentTTL = 1
        sendPing(withTTL: currentTTL!)
    }
    
    public func simplePing(_ pinger: SimplePing, didFailWithError error: Error) {
        let msg = "Failed to trace \(host): \(error.localizedDescription)"
        NSLog(msg)
        appendResult(msg)
        stop()
    }
    
    public func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16) {
        NSLog("#\(sequenceNumber) Data sent, size=\(packet.count)\n")
        sendSequence = sequenceNumber
        startDate = Date()
    }
    
    public func simplePing(_ pinger: SimplePing, didFailToSendPacket packet: Data, sequenceNumber: UInt16, error: Error) {
        let msg = "#\(sequenceNumber) send \(packet) failed: \(error.localizedDescription)"
        appendResult(msg)
    }
    
    public func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16) {
        invalidSendTimer()
        guard let startDate = startDate else { return }
        let interval = Date().timeIntervalSince(startDate)
        let responsedMsg = "### Host responsed, latency (ms): \(interval * 1000) ms\n"
        let receivedMsg = "#\(sequenceNumber) Data received, size=\(packet.count)\n"
        appendResult(responsedMsg + receivedMsg)
        sendTimeoutTimer?.invalidate()
        
        // Complete
        guard sequenceNumber == sendSequence, let ipAddress = ipAddress else { return }
        let completedMsg = "#\(sequenceNumber) reach the destination \(ipAddress), trace completed. It's simple! Right?\n"
        appendResult(completedMsg)
        
        stop()
    }
    
    public func simplePing(_ pinger: SimplePing, didReceiveUnexpectedPacket packet: Data) {
        assert(startDate != nil)
        let interval = Date().timeIntervalSince(startDate!)
        
        let srcAddr = pinger.srcAddr(inIPv4Packet: packet)
        if packetCountPerTTL == 0 {
            icmpSrcAddress = srcAddr
            self.packetCountPerTTL! += 1
            let msg = String(format: "#\(sendSequence!)) \(srcAddr)     %0.3lf ms", interval * 1000)
            appendResult(msg)
        } else {
            self.packetCountPerTTL! += 1
            appendResult(String(format: "    %0.3lf ms", interval * 1000))
        }
        
        if packetCountPerTTL == 3 {
            invalidSendTimer()
            appendResult("\n")
            _ = sendPing()
        }
    }
}

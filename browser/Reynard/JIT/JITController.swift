//
//  JITController.swift
//  Reynard
//
//  Created by Minh Ton on 11/3/26.
//

import Foundation

final class JITController {
    static let shared = JITController()
    
    private static let initialAttachDelay: DispatchTimeInterval = .milliseconds(0)
    private static let attachRetryDelay: DispatchTimeInterval = .milliseconds(500)
    private static let maxAttachAttempts = 5
    
    private let stateQueue = DispatchQueue(label: "me.minh-ton.jit.child-process.state", qos: .userInitiated)
    private let workQueue = DispatchQueue(label: "me.minh-ton.jit.child-process.work", qos: .userInitiated, attributes: .concurrent)
    private let setupQueue = DispatchQueue(label: "me.minh-ton.jit.child-process.setup", qos: .userInitiated)
    private var attachedPIDs: Set<Int32> = []
    
    private init() {}
    
    func start() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleChildProcessNotification(_:)),
            name: NSNotification.Name("GeckoRuntimeChildProcessDidStart"),
            object: nil
        )
    }
    
    private func shouldAttach(to processType: String) -> Bool {
        let normalized = processType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "tab"
    }
    
    func childProcessDidStart(pid: Int32, processType: String) {
        guard pid > 0 else {
            return
        }
        
        let preferences = BrowserPreferences.shared
        print("REYNARD_DEBUG: Child process JIT observer saw pid=\(pid), type=\(processType), enabled=\(preferences.isJITEnabled), pairing=\(preferences.hasPairingFile)")
        guard preferences.isJITEnabled else {
            ReportChildProcessJITEnabled(pid, false)
            return
        }
        
        guard shouldAttach(to: processType) else {
            print("REYNARD_DEBUG: Skipping JIT attach for pid=\(pid), type=\(processType)")
            ReportChildProcessJITEnabled(pid, false)
            return
        }
        
        let shouldAttach = stateQueue.sync { () -> Bool in
            if attachedPIDs.contains(pid) {
                return false
            }
            attachedPIDs.insert(pid)
            return true
        }
        
        guard shouldAttach else {
            return
        }
        
        scheduleAttach(pid: pid,
                       processType: processType,
                       attempt: 1,
                       delay: Self.initialAttachDelay)
    }
    
    private func scheduleAttach(pid: Int32,
                                processType: String,
                                attempt: Int,
                                delay: DispatchTimeInterval) {
        workQueue.asyncAfter(deadline: .now() + delay) {
            print("REYNARD_DEBUG: Starting JIT attach workflow for pid=\(pid), type=\(processType), attempt=\(attempt)")
            do {
                try self.setupQueue.sync {
                    try JITEnabler.shared.enable(forProcessIdentifier: pid) { message in
                        print("REYNARD_DEBUG: \(message)")
                    }
                }
                ReportChildProcessJITEnabled(pid, true)
            } catch {
                if attempt < Self.maxAttachAttempts {
                    print("REYNARD_DEBUG: JIT enablement attempt \(attempt) failed for pid=\(pid), retrying: \(error)")
                    self.scheduleAttach(pid: pid,
                                        processType: processType,
                                        attempt: attempt + 1,
                                        delay: Self.attachRetryDelay)
                    return
                }
                
                self.stateQueue.async {
                    self.attachedPIDs.remove(pid)
                }
                ReportChildProcessJITEnabled(pid, false)
                print("REYNARD_DEBUG: JIT enablement verification failed for pid=\(pid), error=\(error)")
            }
        }
    }
    
    @objc private func handleChildProcessNotification(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let pidNumber = userInfo["pid"] as? NSNumber,
            let processType = userInfo["processType"] as? String
        else {
            return
        }
        
        childProcessDidStart(pid: pidNumber.int32Value, processType: processType)
    }
}

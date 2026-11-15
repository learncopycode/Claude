// Zikr: the full adhan as a system alarm (iOS 26+, AlarmKit).
// An alarm rings at its time even when the app is closed or the phone is locked, and is not limited to
// 30 seconds like a notification sound, so it plays the whole adhan (adhan_full.caf in the app bundle).
// It is stopped from the lock screen like any alarm. On older iOS the app falls back to notifications.
import Foundation
import Capacitor
#if canImport(AlarmKit)
import AlarmKit
import ActivityKit
import SwiftUI

@available(iOS 26.0, *)
struct AdhanAlarmMetadata: AlarmMetadata {}
#endif

@objc(AdhanAlarmPlugin)
public class AdhanAlarmPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "AdhanAlarmPlugin"
    public let jsName = "AdhanAlarm"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "available", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestPermission", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "schedule", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "cancelAll", returnType: CAPPluginReturnPromise)
    ]

    @objc func available(_ call: CAPPluginCall) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            call.resolve(["available": true])
            return
        }
        #endif
        call.resolve(["available": false])
    }

    @objc func requestPermission(_ call: CAPPluginCall) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            Task {
                do {
                    let state = try await AlarmManager.shared.requestAuthorization()
                    call.resolve(["state": state == .authorized ? "granted" : "denied"])
                } catch {
                    call.resolve(["state": "denied"])
                }
            }
            return
        }
        #endif
        call.resolve(["state": "unavailable"])
    }

    @objc func cancelAll(_ call: CAPPluginCall) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let manager = AlarmManager.shared
            if let alarms = try? manager.alarms {
                for alarm in alarms { try? manager.cancel(id: alarm.id) }
            }
            call.resolve()
            return
        }
        #endif
        call.resolve()
    }

    /// alarms: [{ atMs: Number (ms since 1970), title: String }]
    @objc func schedule(_ call: CAPPluginCall) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let items = call.getArray("alarms", JSObject.self) ?? []
            Task {
                let manager = AlarmManager.shared
                var count = 0
                for item in items {
                    guard let ms = (item["atMs"] as? NSNumber)?.doubleValue,
                          let title = item["title"] as? String else { continue }
                    let at = Date(timeIntervalSince1970: ms / 1000)
                    if at <= Date() { continue }
                    let stop = AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill")
                    let alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: title), stopButton: stop)
                    let attributes = AlarmAttributes<AdhanAlarmMetadata>(
                        presentation: AlarmPresentation(alert: alert),
                        metadata: AdhanAlarmMetadata(),
                        tintColor: Color(red: 0.85, green: 0.63, blue: 0.24))
                    let config = AlarmManager.AlarmConfiguration<AdhanAlarmMetadata>.alarm(
                        schedule: .fixed(at),
                        attributes: attributes,
                        sound: .named("adhan_full.caf"))
                    do {
                        _ = try await manager.schedule(id: UUID(), configuration: config)
                        count += 1
                    } catch {
                        CAPLog.print("AdhanAlarm: could not schedule \(title): \(error)")
                    }
                }
                call.resolve(["scheduled": count])
            }
            return
        }
        #endif
        call.reject("AlarmKit is not available on this iOS version", "UNAVAILABLE")
    }
}

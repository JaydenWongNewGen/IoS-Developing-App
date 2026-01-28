//
//  ContentView.swift
//  NewGen App
//
//  Created by Jayden Wong on 1/28/26.
//

import SwiftUI
import Charts
import Combine

struct ContentView: View {
    @State private var isLoggedIn = false
    @State private var enrollmentComplete = false

    // Enrollment fields
    @State private var fullName = ""
    @State private var email = ""
    @State private var dateOfBirth = Date(timeIntervalSince1970: 0)
    @State private var consentAccepted = false

    // Monitoring state
    @State private var bluetoothSyncing = false
    @State private var bluetoothProgress: Double = 0.2
    @State private var latestBPM: Int = 72
    @State private var threshold: Int = 95
    @State private var thresholdAlertsEnabled = true
    @State private var trendSamples: [BpmSample] = BpmSample.mockWeek
    @State private var activeSensor: SensorSource = .defaultSensors.first!
    @State private var lastSampleDate: Date = Date()

    // Symptoms and reminders
    @State private var symptoms: [Symptom] = Symptom.defaultList
    @State private var notificationsEnabled = true
    @State private var reminderTime = Date()

    private let liveTimer = Timer.publish(every: 7, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            brandBackground

            NavigationStack {
                ZStack {
                    Theme.sceneGradient.ignoresSafeArea()
                    if !isLoggedIn {
                        LoginView(isLoggedIn: $isLoggedIn)
                    } else if !enrollmentComplete {
                        EnrollmentView(fullName: $fullName,
                                       email: $email,
                                       dateOfBirth: $dateOfBirth,
                                       consentAccepted: $consentAccepted,
                                       enrollmentComplete: $enrollmentComplete)
                    } else {
                        TabView {
                            DashboardView(latestBPM: $latestBPM,
                                          threshold: $threshold,
                                          thresholdAlertsEnabled: $thresholdAlertsEnabled,
                                          trendSamples: $trendSamples,
                                          lastSampleDate: lastSampleDate,
                                          activeSensor: activeSensor)
                                .tabItem { Label("Results", systemImage: "heart.fill") }

                            MonitorView(bluetoothSyncing: $bluetoothSyncing,
                                        bluetoothProgress: $bluetoothProgress,
                                        latestBPM: $latestBPM,
                                        threshold: $threshold,
                                        thresholdAlertsEnabled: $thresholdAlertsEnabled,
                                        symptoms: $symptoms,
                                        trendSamples: $trendSamples,
                                        lastSampleDate: $lastSampleDate,
                                        activeSensor: $activeSensor)
                                .tabItem { Label("Monitor", systemImage: "waveform.path.ecg") }

                            SettingsView(notificationsEnabled: $notificationsEnabled,
                                         reminderTime: $reminderTime,
                                         threshold: $threshold,
                                         thresholdAlertsEnabled: $thresholdAlertsEnabled)
                                .tabItem { Label("Settings", systemImage: "bell.badge.fill") }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
        }
        .accentColor(Theme.accent)
        .onReceive(liveTimer) { _ in
            guard enrollmentComplete else { return }
            let bpm = Int.random(in: 68...112)
            latestBPM = bpm
            appendSample(bpm)
        }
        .preferredColorScheme(.dark)
    }

    private var brandBackground: some View {
        ZStack {
            Theme.sceneGradient
                .ignoresSafeArea()

            RadialGradient(colors: [Theme.glow, .clear],
                           center: .topTrailing,
                           startRadius: 80,
                           endRadius: 520)
                .ignoresSafeArea()

            LinearGradient(colors: [Color.white.opacity(0.06), Color.clear],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .blendMode(.screen)
                .ignoresSafeArea()

            AnimatedBlobBackground()
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private func appendSample(_ bpm: Int) {
        let label = Formatters.sampleTime.string(from: Date())
        trendSamples.append(.init(day: label, bpm: bpm))
        if trendSamples.count > 14 { trendSamples.removeFirst() }
        lastSampleDate = Date()
    }
}

#Preview {
    ContentView()
}

// MARK: - Auth and enrollment

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 12) {
                    Label("NewGen", systemImage: "bolt.heart.fill")
                        .font(Typography.eyebrow)
                        .foregroundStyle(.white.opacity(0.8))
                    Text("Feel in control.\nStay ahead.")
                        .font(Typography.hero)
                        .foregroundStyle(.white)
                    Text("Sign in to sync your sensors, surface trends, and get notified when something needs attention.")
                        .foregroundColor(.white.opacity(0.75))
                        .font(Typography.body)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Theme.accent.opacity(0.35), radius: 18, x: 0, y: 12)

                VStack(alignment: .leading, spacing: 16) {
                    floatingField("Email", text: $email, icon: "envelope")
                    floatingSecure("Password", text: $password, icon: "lock")

                    Button {
                        isLoggedIn = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Continue")
                                .font(Typography.button)
                            Image(systemName: "arrow.right.circle.fill")
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(GradientButtonStyle(enabled: !email.isEmpty && !password.isEmpty))
                    .disabled(email.isEmpty || password.isEmpty)

                    DividerView(label: "or continue with")

                    VStack(spacing: 10) {
                        SocialButton(provider: .apple) {
                            isLoggedIn = true
                        }
                        SocialButton(provider: .google) {
                            isLoggedIn = true
                        }
                        SocialButton(provider: .email) {
                            isLoggedIn = true
                        }
                    }
                }

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .background(Theme.sceneGradient)
    }
}

struct EnrollmentView: View {
    @Binding var fullName: String
    @Binding var email: String
    @Binding var dateOfBirth: Date
    @Binding var consentAccepted: Bool
    @Binding var enrollmentComplete: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Set up your profile")
                        .font(Typography.title)
                    Text("We use this to personalize your experience and keep you informed.")
                        .foregroundColor(.secondary)
                        .font(Typography.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 14) {
                    floatingField("Full name", text: $fullName, icon: "person")
                    floatingField("Email", text: $email, icon: "envelope")
                    DatePicker("Date of birth", selection: $dateOfBirth, displayedComponents: .date)
                        .padding()
                        .background(Theme.cardGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $consentAccepted) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Consent to participate")
                                .font(.headline)
                            Text("Read the consent to understand data handling and risks.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: Theme.accent))

                    NavigationLink {
                        ConsentDetails()
                    } label: {
                        HStack {
                            Label("View consent", systemImage: "doc.text.magnifyingglass")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Theme.cardGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }
                }
                .cardStyle()

                Button {
                    enrollmentComplete = true
                } label: {
                    Text("Finish enrollment")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(AnyShapeStyle(consentAccepted && !fullName.isEmpty && !email.isEmpty ? Theme.primaryGradient : Theme.muted))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Theme.accent.opacity(0.25), radius: 12, x: 0, y: 10)
                }
                .disabled(!consentAccepted || fullName.isEmpty || email.isEmpty)
            }
            .padding()
        }
        .scrollIndicators(.hidden)
        .background(Theme.sceneGradient)
        .navigationTitle("Enrollment")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Theme.bgMid.opacity(0.6), for: .navigationBar)
    }
}

struct ConsentDetails: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Consent").font(Typography.title)
                Text("This is placeholder text for your consent document. Include risks, benefits, data handling, and contact info.")
                    .font(Typography.body)
                Text("You can replace this view with your actual consent PDF or web content.")
                    .font(Typography.body)
            }
            .padding()
        }
        .navigationTitle("Consent")
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @Binding var latestBPM: Int
    @Binding var threshold: Int
    @Binding var thresholdAlertsEnabled: Bool
    @Binding var trendSamples: [BpmSample]
    let lastSampleDate: Date
    let activeSensor: SensorSource

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                resultCard
                thresholdCard
                trendCard
            }
            .padding()
        }
        .navigationTitle("Results")
        .scrollIndicators(.hidden)
        .background(Theme.sceneGradient)
    }

    private var resultCard: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Latest BPM", systemImage: "waveform.path.ecg.rectangle")
                        .font(Typography.title)
                Spacer()
                StatBadge(text: activeSensor.name, icon: activeSensor.icon)
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(latestBPM)")
                    .font(Typography.stat)
            Text("bpm")
                .foregroundColor(.secondary)
            }
            Text("Streaming from \(activeSensor.detail). Updated \(Formatters.relative.localizedString(for: lastSampleDate, relativeTo: Date())).")
                .font(Typography.caption)
                .foregroundColor(.secondary)
            StatBadge(text: "Live sensor stream", icon: "dot.radiowaves.left.and.right")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var thresholdCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Threshold system")
                    .font(.headline)
                Spacer()
                Toggle("Alerts", isOn: $thresholdAlertsEnabled)
                    .labelsHidden()
            }
            Text("Alert if BPM goes above \(threshold).")
                .foregroundColor(.secondary)

            HStack {
                PillSlider(value: Binding(
                    get: { Double(threshold) },
                    set: { threshold = Int($0) }
                ), range: 60...140, step: 1, gradient: Theme.primaryGradient, thumbColor: Theme.accentWarm)
                    .frame(height: 34)
                Text("\(threshold)")
                    .frame(width: 48)
            }

            Label(thresholdStatusText, systemImage: thresholdStatusIcon)
                .foregroundColor(thresholdStatusColor)
        }
        .cardStyle()
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trends (last 7 days)")
                .font(.headline)
            Chart(trendSamples) { sample in
                LineMark(
                    x: .value("Day", sample.day),
                    y: .value("BPM", sample.bpm)
                )
                PointMark(
                    x: .value("Day", sample.day),
                    y: .value("BPM", sample.bpm)
                )
            }
            .frame(height: 180)
        }
        .cardStyle()
    }

    private var thresholdStatusText: String {
        if !thresholdAlertsEnabled { return "Alerts disabled" }
        return latestBPM >= threshold ? "Above threshold now" : "Below threshold"
    }

    private var thresholdStatusIcon: String {
        if !thresholdAlertsEnabled { return "bell.slash.fill" }
        return latestBPM >= threshold ? "exclamationmark.triangle.fill" : "checkmark.seal.fill"
    }

    private var thresholdStatusColor: Color {
        if !thresholdAlertsEnabled { return .gray }
        return latestBPM >= threshold ? .orange : .green
    }
}

// MARK: - Monitor

struct MonitorView: View {
    @Binding var bluetoothSyncing: Bool
    @Binding var bluetoothProgress: Double
    @Binding var latestBPM: Int
    @Binding var threshold: Int
    @Binding var thresholdAlertsEnabled: Bool
    @Binding var symptoms: [Symptom]
    @Binding var trendSamples: [BpmSample]
    @Binding var lastSampleDate: Date
    @Binding var activeSensor: SensorSource

    private let sensors = SensorSource.defaultSensors

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                sensorPicker
                bluetoothCard
                cellularCard
                symptomCard
            }
            .padding()
        }
        .navigationTitle("Monitor")
        .scrollIndicators(.hidden)
        .background(Theme.sceneGradient)
    }

    private var sensorPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live data source")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(sensors) { sensor in
                        Button {
                            activeSensor = sensor
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: sensor.icon)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sensor.name).font(.subheadline.weight(.semibold))
                                    Text(sensor.detail).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: 220, alignment: .leading)
                            .background(AnyShapeStyle(sensor == activeSensor ? Theme.primaryGradient : Theme.cardGradient))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1.2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Label("Last packet \(Formatters.relative.localizedString(for: lastSampleDate, relativeTo: Date()))", systemImage: "clock.badge.checkmark")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .cardStyle()
    }

    private var bluetoothCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bluetooth device sync")
                    .font(Typography.title)
                Spacer()
                if bluetoothSyncing {
                    ProgressView(value: bluetoothProgress)
                        .frame(width: 60)
                }
            }
            Text("Pair and pull the latest heart data.")
                .foregroundColor(.secondary)
                .font(Typography.body)

            Button {
                bluetoothSyncing = true
                animateSync()
            } label: {
                Label("Start sync", systemImage: "bolt.horizontal.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.primaryGradient)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Theme.accent.opacity(0.35), radius: 14, x: 0, y: 10)
            }
            .disabled(bluetoothSyncing)

            Button {
                bluetoothSyncing = false
                bluetoothProgress = 0.0
            } label: {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!bluetoothSyncing)
        }
        .cardStyle()
    }

    private var cellularCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cellular BPM")
                .font(Typography.title)
            Text("Quick check without the paired device — automatically captured from your phone sensors.")
                .foregroundColor(.secondary)
                .font(Typography.body)

            HStack(spacing: 12) {
                Text("\(latestBPM) bpm")
                    .font(Typography.statSmall)
                Spacer()
                Button {
                    latestBPM = Int.random(in: 65...120)
                    recordSample(latestBPM)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            thresholdNotice
        }
        .cardStyle()
    }

    private var thresholdNotice: some View {
        Group {
            if thresholdAlertsEnabled && latestBPM >= threshold {
                Label("Above threshold. Alert would fire.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            } else if !thresholdAlertsEnabled {
                Label("Threshold alerts are off.", systemImage: "bell.slash.fill")
                    .foregroundColor(.gray)
            } else {
                Label("Within threshold.", systemImage: "checkmark.seal.fill")
                    .foregroundColor(.green)
            }
        }
        .font(.subheadline)
    }

    private var symptomCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Symptom check")
                .font(Typography.title)
            ForEach($symptoms) { $symptom in
                Toggle(symptom.name, isOn: $symptom.isPresent)
                    .font(Typography.body)
            }
            Button {
                symptoms = Symptom.defaultList
            } label: {
                Text("Clear symptoms")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .font(.subheadline)
        }
        .cardStyle()
    }

    private func animateSync() {
        bluetoothProgress = 0.05
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            guard bluetoothSyncing else {
                timer.invalidate()
                return
            }
            bluetoothProgress = min(bluetoothProgress + 0.15, 1.0)
            if bluetoothProgress >= 1.0 {
                timer.invalidate()
                bluetoothSyncing = false
                latestBPM = Int.random(in: 60...110)
                recordSample(latestBPM)
            }
        }
    }

    private func recordSample(_ bpm: Int) {
        let label = Formatters.sampleTime.string(from: Date())
        trendSamples.append(.init(day: label, bpm: bpm))
        if trendSamples.count > 14 { trendSamples.removeFirst() }
        lastSampleDate = Date()
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Binding var notificationsEnabled: Bool
    @Binding var reminderTime: Date
    @Binding var threshold: Int
    @Binding var thresholdAlertsEnabled: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Stay in the loop")
                        .font(.headline)
                    Text("Fine-tune reminders and alert thresholds.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Push notifications", isOn: $notificationsEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                    DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable alerts", isOn: $thresholdAlertsEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                    HStack {
                        PillSlider(value: Binding(
                            get: { Double(threshold) },
                            set: { threshold = Int($0) }
                        ), range: 60...140, step: 1, gradient: Theme.primaryGradient, thumbColor: Theme.accentWarm)
                            .frame(height: 34)
                        Text("\(threshold)")
                            .frame(width: 44)
                    }
                    Label("Sensor-driven: alerts trigger automatically on incoming samples.", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .cardStyle()

                NavigationLink {
                    Text("Account settings placeholder.")
                        .padding()
                        .navigationTitle("Account")
                } label: {
                    HStack {
                        Label("Manage account", systemImage: "person.crop.circle")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .cardStyle()
                }
            }
            .padding()
        }
        .navigationTitle("Settings")
        .scrollIndicators(.hidden)
        .background(Theme.sceneGradient)
    }
}

// MARK: - Models

struct BpmSample: Identifiable {
    let id = UUID()
    let day: String
    let bpm: Int

    static let mockWeek: [BpmSample] = [
        .init(day: "Mon", bpm: 78),
        .init(day: "Tue", bpm: 74),
        .init(day: "Wed", bpm: 80),
        .init(day: "Thu", bpm: 76),
        .init(day: "Fri", bpm: 82),
        .init(day: "Sat", bpm: 79),
        .init(day: "Sun", bpm: 77)
    ]
}

struct Symptom: Identifiable {
    let id = UUID()
    let name: String
    var isPresent: Bool

    static let defaultList: [Symptom] = [
        .init(name: "Chest tightness", isPresent: false),
        .init(name: "Shortness of breath", isPresent: false),
        .init(name: "Dizziness", isPresent: false),
        .init(name: "Fatigue", isPresent: false),
        .init(name: "Headache", isPresent: false)
    ]
}

struct SensorSource: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let icon: String
    let detail: String

    static let defaultSensors: [SensorSource] = [
        .init(name: "Aurora Band", icon: "sportscourt.fill", detail: "PPG wrist sensor"),
        .init(name: "PulsePod", icon: "bolt.heart.fill", detail: "Chest strap ECG"),
        .init(name: "iPhone PPG", icon: "iphone.gen3", detail: "Camera fingertip check")
    ]
}

// MARK: - Reusable UI

private struct StatBadge: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .font(Typography.captionBold)
        }
        .font(Typography.captionBold)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.accent.opacity(0.24))
        .foregroundColor(.white.opacity(0.92))
        .clipShape(Capsule())
    }
}

private struct PillSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let gradient: LinearGradient
    let thumbColor: Color
    var height: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.cardGradient.opacity(0.6))
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .frame(height: height)

                Capsule()
                    .fill(gradient)
                    .frame(width: max(height, progress * width), height: height)

                Circle()
                    .fill(thumbColor)
                    .frame(width: height * 1.6, height: height * 1.6)
                    .shadow(color: thumbColor.opacity(0.35), radius: 8, x: 0, y: 4)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .offset(x: max(0, min(width - height * 1.6, progress * width - (height * 0.8))))
                    .gesture(
                        DragGesture(minimumDistance: 0).onChanged { gesture in
                            let ratio = max(0, min(1, gesture.location.x / width))
                            let raw = range.lowerBound + Double(ratio) * (range.upperBound - range.lowerBound)
                            let snapped = (raw / step).rounded() * step
                            value = min(range.upperBound, max(range.lowerBound, snapped))
                        }
                    )
            }
            .frame(height: height * 1.6)
        }
    }
}

private struct GradientButtonStyle: ButtonStyle {
    var enabled: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .background(AnyShapeStyle(enabled ? Theme.primaryGradient : Theme.muted))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Theme.accent.opacity(enabled ? 0.35 : 0.1), radius: 16, x: 0, y: 10)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

private struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.08))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private enum SocialProvider {
    case apple, google, email

    var title: String {
        switch self {
        case .apple: return "Sign in with Apple"
        case .google: return "Sign in with Google"
        case .email: return "Continue with email"
        }
    }

    var icon: String {
        switch self {
        case .apple: return "applelogo"
        case .google: return "g.circle.fill"
        case .email: return "envelope.fill"
        }
    }

    var foreground: Color {
        switch self {
        case .apple: return .white
        case .google: return .black
        case .email: return .white
        }
    }

    var background: Color {
        switch self {
        case .apple: return .black
        case .google: return Color.white
        case .email: return Color.white.opacity(0.08)
        }
    }

    var stroke: Color {
        switch self {
        case .google: return Color.black.opacity(0.08)
        case .email: return Color.white.opacity(0.12)
        case .apple: return Color.white.opacity(0.08)
        }
    }
}

private struct SocialButton: View {
    let provider: SocialProvider
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                ZStack {
                    Circle()
                        .fill(provider == .google ? Color.white : Color.white.opacity(0.12))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(provider == .google ? 0.06 : 0), lineWidth: 0.5)
                        )
                    if provider == .google {
                        Text("G").font(.headline.weight(.bold)).foregroundStyle(.black)
                    } else {
                        Image(systemName: provider.icon)
                            .font(.headline)
                            .foregroundColor(provider.foreground)
                    }
                }
                Text(provider.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(provider.background)
            .foregroundColor(provider.foreground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(provider.stroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct DividerView: View {
    let label: String
    var body: some View {
        HStack {
            Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.12))
            Text(label.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.55))
            Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.12))
        }
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardGradient)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 18)
    }
}

private func floatingField(_ title: String, text: Binding<String>, icon: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Label(title, systemImage: icon)
            .font(.caption)
            .foregroundColor(.secondary)
        TextField(title, text: text)
            .padding()
            .background(Theme.cardGradient)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

private func floatingSecure(_ title: String, text: Binding<String>, icon: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Label(title, systemImage: icon)
            .font(.caption)
            .foregroundColor(.secondary)
        SecureField(title, text: text)
            .padding()
            .background(Theme.cardGradient)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

private enum Typography {
    static let hero = Font.system(size: 34, weight: .heavy, design: .rounded)
    static let title = Font.system(size: 19, weight: .semibold, design: .rounded)
    static let stat = Font.system(size: 46, weight: .black, design: .rounded)
    static let statSmall = Font.system(size: 34, weight: .heavy, design: .rounded)
    static let button = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 15, weight: .regular, design: .rounded)
    static let caption = Font.system(size: 13, weight: .regular, design: .rounded)
    static let captionBold = Font.system(size: 13, weight: .semibold, design: .rounded)
    static let eyebrow = Font.system(size: 12, weight: .bold, design: .rounded)
}

private enum Theme {
    static let bgTop    = Color(red: 0.08, green: 0.12, blue: 0.24)   // deep navy
    static let bgMid    = Color(red: 0.10, green: 0.16, blue: 0.30)
    static let bgBottom = Color(red: 0.09, green: 0.20, blue: 0.36)
    static let glow     = Color(red: 0.18, green: 0.48, blue: 0.92).opacity(0.48)

    static let accent = Color(red: 0.19, green: 0.84, blue: 0.43) // spotify-like green
    static let accent2 = Color(red: 0.06, green: 0.67, blue: 0.76)
    static let accentWarm = Color(red: 0.99, green: 0.74, blue: 0.30)

    static let muted = LinearGradient(colors: [Color(red: 0.18, green: 0.24, blue: 0.34).opacity(0.9),
                                               Color(red: 0.12, green: 0.18, blue: 0.28).opacity(0.9)],
                                      startPoint: .topLeading,
                                      endPoint: .bottomTrailing)
    static let cardTop = Color(red: 0.16, green: 0.22, blue: 0.32).opacity(0.9)
    static let cardBottom = Color(red: 0.10, green: 0.16, blue: 0.26).opacity(0.9)

    static let primaryGradient = LinearGradient(colors: [accent, accent2],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing)
    static let cardGradient = LinearGradient(colors: [cardTop, cardBottom],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing)

    static let sceneGradient = LinearGradient(colors: [bgTop, bgMid, bgBottom],
                                              startPoint: .topLeading,
                                              endPoint: .bottomTrailing)
}

// Animated gradient blobs for subtle motion
private struct AnimatedBlobBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1/24)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let offset1 = CGSize(width: sin(t/3.5) * w*0.25, height: cos(t/4.2) * h*0.18)
                let offset2 = CGSize(width: cos(t/2.8) * w*0.2,  height: sin(t/3.8) * h*0.22)
                let offset3 = CGSize(width: sin(t/4.8) * w*0.3,  height: cos(t/5.2) * h*0.16)

                drawBlob(context: &context, size: size, origin: CGPoint(x: w*0.35 + offset1.width, y: h*0.3 + offset1.height), color: Theme.accent.opacity(0.18))
                drawBlob(context: &context, size: size, origin: CGPoint(x: w*0.7 + offset2.width,  y: h*0.15 + offset2.height), color: Theme.accent2.opacity(0.16))
                drawBlob(context: &context, size: size, origin: CGPoint(x: w*0.5 + offset3.width,  y: h*0.75 + offset3.height), color: Theme.accentWarm.opacity(0.10))
            }
        }
    }

    private func drawBlob(context: inout GraphicsContext, size: CGSize, origin: CGPoint, color: Color) {
        let blobSize = min(size.width, size.height) * 0.65
        let rect = CGRect(origin: CGPoint(x: origin.x - blobSize/2, y: origin.y - blobSize/2),
                          size: CGSize(width: blobSize, height: blobSize))
        context.fill(Ellipse().path(in: rect), with: .color(color))
        context.addFilter(.blur(radius: blobSize * 0.18))
    }
}

enum Formatters {
    static let sampleTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE h:mm a"
        return f
    }()

    static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}

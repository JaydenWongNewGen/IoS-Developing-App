//
//  ContentView.swift
//  NewGen App
//
//  Created by Jayden Wong on 1/28/26.
//

import SwiftUI
import Charts

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

    // Symptoms and reminders
    @State private var symptoms: [Symptom] = Symptom.defaultList
    @State private var notificationsEnabled = true
    @State private var reminderTime = Date()

    var body: some View {
        ZStack {
            brandBackground

            NavigationStack {
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
                                      thresholdAlertsEnabled: $thresholdAlertsEnabled)
                            .tabItem { Label("Results", systemImage: "heart.fill") }

                        MonitorView(bluetoothSyncing: $bluetoothSyncing,
                                    bluetoothProgress: $bluetoothProgress,
                                    latestBPM: $latestBPM,
                                    threshold: $threshold,
                                    thresholdAlertsEnabled: $thresholdAlertsEnabled,
                                    symptoms: $symptoms)
                            .tabItem { Label("Monitor", systemImage: "waveform.path.ecg") }

                        SettingsView(notificationsEnabled: $notificationsEnabled,
                                     reminderTime: $reminderTime,
                                     threshold: $threshold,
                                     thresholdAlertsEnabled: $thresholdAlertsEnabled)
                            .tabItem { Label("Settings", systemImage: "bell.badge.fill") }
                    }
                }
            }
        }
        .accentColor(Theme.accent)
    }

    private var brandBackground: some View {
        ZStack {
            LinearGradient(colors: [Theme.gradientStart, Theme.gradientEnd],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
                .opacity(0.35)

            RadialGradient(colors: [Theme.accent.opacity(0.35), .clear],
                           center: .topTrailing,
                           startRadius: 10,
                           endRadius: 420)
                .ignoresSafeArea()

            Color(.systemBackground)
                .opacity(0.75)
                .ignoresSafeArea()
        }
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
        VStack(spacing: 22) {
            Spacer()
            Text("Welcome to NewGen Health")
                .font(.system(.title, design: .rounded).bold())
            Text("Log in or create an account to continue.")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 14) {
                floatingField("Email", text: $email, icon: "envelope")
                floatingSecure("Password", text: $password, icon: "lock")
            }

            Button {
                isLoggedIn = true
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(email.isEmpty || password.isEmpty ? Theme.muted : Theme.accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Theme.accent.opacity(0.35), radius: 14, x: 0, y: 12)
            }
            .disabled(email.isEmpty || password.isEmpty)

            Button("Create account") {
                isLoggedIn = true
            }
            .font(.subheadline)
            Spacer()
        }
        .padding()
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
                        .font(.title3.weight(.semibold))
                    Text("We use this to personalize your experience and keep you informed.")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 14) {
                    floatingField("Full name", text: $fullName, icon: "person")
                    floatingField("Email", text: $email, icon: "envelope")
                    DatePicker("Date of birth", selection: $dateOfBirth, displayedComponents: .date)
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .cardStyle()

                Button {
                    enrollmentComplete = true
                } label: {
                    Text("Finish enrollment")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(consentAccepted && !fullName.isEmpty && !email.isEmpty ? Theme.accent : Theme.muted)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Theme.accent.opacity(0.25), radius: 12, x: 0, y: 10)
                }
                .disabled(!consentAccepted || fullName.isEmpty || email.isEmpty)
            }
            .padding()
        }
        .navigationTitle("Enrollment")
    }
}

struct ConsentDetails: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Consent").font(.title2.bold())
                Text("This is placeholder text for your consent document. Include risks, benefits, data handling, and contact info.")
                Text("You can replace this view with your actual consent PDF or web content.")
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

    private let trendSamples: [BpmSample] = BpmSample.mockWeek

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
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Latest BPM", systemImage: "waveform.path.ecg.rectangle")
                    .font(.headline)
                Spacer()
                StatBadge(text: "Live", icon: "antenna.radiowaves.left.and.right")
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(latestBPM)")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                Text("bpm")
                    .foregroundColor(.secondary)
            }
            Text("Captured over cellular. Tap Monitor to sync via Bluetooth.")
                .font(.footnote)
                .foregroundColor(.secondary)
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
                Slider(value: Binding(
                    get: { Double(threshold) },
                    set: { threshold = Int($0) }
                ), in: 60...140, step: 1)
                Text("\(threshold)")
                    .frame(width: 44)
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

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                bluetoothCard
                cellularCard
                symptomCard
            }
            .padding()
        }
        .navigationTitle("Monitor")
    }

    private var bluetoothCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bluetooth device sync")
                    .font(.headline)
                Spacer()
                if bluetoothSyncing {
                    ProgressView(value: bluetoothProgress)
                        .frame(width: 60)
                }
            }
            Text("Pair and pull the latest heart data.")
                .foregroundColor(.secondary)

            Button {
                bluetoothSyncing = true
                animateSync()
            } label: {
                Label("Start sync", systemImage: "bolt.horizontal.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.accent)
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
                .font(.headline)
            Text("Quick check without the paired device.")
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Text("\(latestBPM) bpm")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                Spacer()
                Button {
                    latestBPM = Int.random(in: 65...120)
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
                .font(.headline)
            ForEach($symptoms) { $symptom in
                Toggle(symptom.name, isOn: $symptom.isPresent)
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
            }
        }
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
                        Slider(value: Binding(
                            get: { Double(threshold) },
                            set: { threshold = Int($0) }
                        ), in: 60...140, step: 1)
                        Text("\(threshold)")
                            .frame(width: 44)
                    }
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

// MARK: - Reusable UI

private struct StatBadge: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.accent.opacity(0.15))
        .foregroundColor(Theme.accent)
        .clipShape(Capsule())
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private func floatingField(_ title: String, text: Binding<String>, icon: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Label(title, systemImage: icon)
            .font(.caption)
            .foregroundColor(.secondary)
        TextField(title, text: text)
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private func floatingSecure(_ title: String, text: Binding<String>, icon: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Label(title, systemImage: icon)
            .font(.caption)
            .foregroundColor(.secondary)
        SecureField(title, text: text)
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private enum Theme {
    static let gradientStart = Color(red: 0.10, green: 0.42, blue: 0.98)
    static let gradientEnd = Color(red: 0.15, green: 0.79, blue: 0.71)
    static let accent = Color(red: 0.16, green: 0.54, blue: 0.97)
    static let muted = Color.gray.opacity(0.35)
}

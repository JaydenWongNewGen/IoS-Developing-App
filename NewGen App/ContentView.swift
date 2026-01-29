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
    @Environment(\.colorScheme) private var colorScheme
    @State private var isLoggedIn = false
    @State private var enrollmentComplete = false
    @State private var isCreatingAccount = false

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
    private let viewTransition: AnyTransition = .move(edge: .bottom).combined(with: .opacity)

    var body: some View {
        ZStack {
            brandBackground

            NavigationStack {
                ZStack {
                    Theme.sceneGradient(colorScheme).ignoresSafeArea()
                    Group {
                        if !isLoggedIn {
                            if isCreatingAccount {
                                CreateAccountView(fullName: $fullName,
                                                  email: $email,
                                                  onCancel: {
                                                      withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                                                          isCreatingAccount = false
                                                      }
                                                  },
                                                  onCreated: {
                                                      withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                                                          consentAccepted = false
                                                          dateOfBirth = Date(timeIntervalSince1970: 0)
                                                          enrollmentComplete = false
                                                          isLoggedIn = true
                                                          isCreatingAccount = false
                                                      }
                                                  })
                                    .transition(viewTransition)
                            } else {
                                LoginView(onLogin: {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                                        enrollmentComplete = true
                                        isLoggedIn = true
                                    }
                                }, onCreateAccount: {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                                        isCreatingAccount = true
                                    }
                                })
                                .transition(viewTransition)
                        }
                        } else if !enrollmentComplete {
                            EnrollmentView(fullName: $fullName,
                                           email: $email,
                                           dateOfBirth: $dateOfBirth,
                                           consentAccepted: $consentAccepted,
                                           enrollmentComplete: $enrollmentComplete)
                                .transition(viewTransition)
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
                                         thresholdAlertsEnabled: $thresholdAlertsEnabled,
                                         onSignOut: signOut)
                                    .tabItem { Label("Settings", systemImage: "bell.badge.fill") }
                        }
                            .scrollContentBackground(.hidden)
                            .transition(viewTransition)
                        }
                    }
                }
            }
        }
        .accentColor(Theme.accent(colorScheme))
        .onReceive(liveTimer) { _ in
            guard enrollmentComplete else { return }
            let bpm = Int.random(in: 68...112)
            latestBPM = bpm
            appendSample(bpm)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.9), value: isLoggedIn)
        .animation(.spring(response: 0.5, dampingFraction: 0.9), value: enrollmentComplete)
    }

    private var brandBackground: some View {
        let palette = Theme.palette(for: colorScheme)
        return ZStack {
            Theme.sceneGradient(colorScheme)
                .ignoresSafeArea()

            RadialGradient(colors: [palette.glow, .clear],
                           center: .topTrailing,
                           startRadius: 80,
                           endRadius: 520)
                .ignoresSafeArea()

            LinearGradient(colors: [Color.white.opacity(0.06), Color.clear],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .blendMode(.screen)
                .ignoresSafeArea()

            AnimatedBlobBackground(palette: palette)
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

    private func signOut() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            isLoggedIn = false
            enrollmentComplete = false
            isCreatingAccount = false
            fullName = ""
            email = ""
            passwordReset()
            consentAccepted = false
        }
    }

    private func passwordReset() {
        // reset any password fields indirectly by toggling view state
        // login/create-account views own their own local password state
    }
}

#Preview {
    ContentView()
}

// MARK: - Auth and enrollment

struct LoginView: View {
    @Environment(\.colorScheme) private var colorScheme
    var onLogin: () -> Void
    var onCreateAccount: () -> Void
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        BrandLogo(size: 46)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("NewGen")
                                .font(Typography.eyebrow)
                                .foregroundStyle(Theme.accent2(colorScheme))
                            Text("Feel in control.\nStay ahead.")
                                .font(Typography.hero)
                                .foregroundStyle(.black.opacity(0.9))
                        }
                    }
                    Text("Sign in to sync your sensors, surface trends, and get notified when something needs attention.")
                        .foregroundColor(.black.opacity(0.65))
                        .font(Typography.body)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: Theme.accent(colorScheme).opacity(0.12), radius: 22, x: 0, y: 18)

                VStack(alignment: .leading, spacing: 16) {
                    floatingField("Email", text: $email, icon: "envelope", colorScheme: colorScheme)
                    floatingSecure("Password", text: $password, icon: "lock", colorScheme: colorScheme)

                    Button {
                        onLogin()
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
                    .buttonStyle(GradientButtonStyle(enabled: !email.isEmpty && !password.isEmpty, colorScheme: colorScheme))
                    .disabled(email.isEmpty || password.isEmpty)

                    DividerView(label: "or continue with")

                    VStack(spacing: 10) {
                        SocialButton(provider: .apple) {
                            onLogin()
                        }
                        SocialButton(provider: .google) {
                            onLogin()
                        }
                        SocialButton(provider: .email) {
                            onLogin()
                        }
                    }

                    Button {
                        onCreateAccount()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                            Text("Create account")
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(GhostButtonStyle(colorScheme: colorScheme))
                }

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .background(Theme.sceneGradient(colorScheme))
    }
}

struct CreateAccountView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var fullName: String
    @Binding var email: String
    @State private var password = ""
    @State private var confirmPassword = ""
    var onCancel: () -> Void
    var onCreated: () -> Void

    private var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    private var formValid: Bool {
        !fullName.isEmpty && !email.isEmpty && passwordsMatch && password.count >= 8
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 12) {
                    Label("Create account", systemImage: "person.badge.plus")
                        .font(Typography.eyebrow)
                        .foregroundStyle(.white.opacity(0.8))
                    Text("Welcome to NewGen")
                        .font(Typography.hero)
                        .foregroundStyle(.white)
                    Text("Set up your login, then review the study consent on the next step.")
                        .foregroundColor(.white.opacity(0.75))
                        .font(Typography.body)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.primaryGradient(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Theme.accent(colorScheme).opacity(0.35), radius: 18, x: 0, y: 12)

                VStack(alignment: .leading, spacing: 16) {
                    floatingField("Full name", text: $fullName, icon: "person", colorScheme: colorScheme)
                    floatingField("Email", text: $email, icon: "envelope", colorScheme: colorScheme)
                    floatingSecure("Password (min 8 chars)", text: $password, icon: "lock", colorScheme: colorScheme)
                    floatingSecure("Confirm password", text: $confirmPassword, icon: "lock.rotation", colorScheme: colorScheme)

                    if !passwordsMatch && !confirmPassword.isEmpty {
                        Label("Passwords must match", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }

                    Button {
                        onCreated()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Continue to consent")
                                .font(Typography.button)
                            Image(systemName: "arrow.right.circle.fill")
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(GradientButtonStyle(enabled: formValid, colorScheme: colorScheme))
                    .disabled(!formValid)

                    Button(action: onCancel) {
                        HStack {
                            Spacer()
                            Text("Back to login")
                                .font(Typography.button)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(GhostButtonStyle(colorScheme: colorScheme))
                }

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .background(Theme.sceneGradient(colorScheme))
    }
}

struct EnrollmentView: View {
    @Environment(\.colorScheme) private var colorScheme
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
                    floatingField("Full name", text: $fullName, icon: "person", colorScheme: colorScheme)
                    floatingField("Email", text: $email, icon: "envelope", colorScheme: colorScheme)
                    DatePicker("Date of birth", selection: $dateOfBirth, displayedComponents: .date)
                        .padding()
                        .background(Theme.cardGradient(colorScheme))
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
                    .toggleStyle(SwitchToggleStyle(tint: Theme.accent(colorScheme)))

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
                        .background(Theme.cardGradient(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }
                }
                .cardStyle(colorScheme)

                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                        enrollmentComplete = true
                    }
                } label: {
                    Text("Finish enrollment")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(AnyShapeStyle(consentAccepted && !fullName.isEmpty && !email.isEmpty ? Theme.primaryGradient(colorScheme) : Theme.muted(colorScheme)))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Theme.accent(colorScheme).opacity(0.25), radius: 12, x: 0, y: 10)
                }
                .disabled(!consentAccepted || fullName.isEmpty || email.isEmpty)
            }
            .padding()
        }
        .scrollIndicators(.hidden)
        .background(Theme.sceneGradient(colorScheme))
        .navigationTitle("Enrollment")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Theme.palette(for: colorScheme).bgMid.opacity(0.6), for: .navigationBar)
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
    @Environment(\.colorScheme) private var colorScheme
    @Binding var latestBPM: Int
    @Binding var threshold: Int
    @Binding var thresholdAlertsEnabled: Bool
    @Binding var trendSamples: [BpmSample]
    let lastSampleDate: Date
    let activeSensor: SensorSource

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                brandHeader
                resultCard
                thresholdCard
                trendCard
            }
            .padding()
        }
        .navigationTitle("Results")
        .scrollIndicators(.hidden)
        .background(Theme.sceneGradient(colorScheme))
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
        .cardStyle(colorScheme)
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
                ), range: 60...140, step: 1, gradient: Theme.primaryGradient(colorScheme), thumbColor: Theme.accentWarm(colorScheme), track: Theme.cardGradient(colorScheme))
                    .frame(height: 34)
                Text("\(threshold)")
                    .frame(width: 48)
            }

            Label(thresholdStatusText, systemImage: thresholdStatusIcon)
                .foregroundColor(thresholdStatusColor)
        }
        .cardStyle(colorScheme)
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
        .cardStyle(colorScheme)
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

    private var brandHeader: some View {
        HStack(spacing: 12) {
            BrandLogo(size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("NewGen")
                    .font(Typography.title)
                    .foregroundStyle(Theme.accent(colorScheme))
                Text("Health monitoring")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Monitor

struct MonitorView: View {
    @Environment(\.colorScheme) private var colorScheme
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
        .background(Theme.sceneGradient(colorScheme))
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
                            .background(AnyShapeStyle(sensor == activeSensor ? Theme.primaryGradient(colorScheme) : Theme.cardGradient(colorScheme)))
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
        .cardStyle(colorScheme)
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
                    .background(Theme.primaryGradient(colorScheme))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Theme.accent(colorScheme).opacity(0.35), radius: 14, x: 0, y: 10)
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
        .cardStyle(colorScheme)
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
        .cardStyle(colorScheme)
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
        .cardStyle(colorScheme)
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
    @Environment(\.colorScheme) private var colorScheme
    @Binding var notificationsEnabled: Bool
    @Binding var reminderTime: Date
    @Binding var threshold: Int
    @Binding var thresholdAlertsEnabled: Bool
    var onSignOut: () -> Void

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
                        .toggleStyle(SwitchToggleStyle(tint: Theme.accent(colorScheme)))
                    DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                }
                .cardStyle(colorScheme)

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable alerts", isOn: $thresholdAlertsEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: Theme.accent(colorScheme)))
                    HStack {
                        PillSlider(value: Binding(
                            get: { Double(threshold) },
                            set: { threshold = Int($0) }
                        ), range: 60...140, step: 1, gradient: Theme.primaryGradient(colorScheme), thumbColor: Theme.accentWarm(colorScheme), track: Theme.cardGradient(colorScheme))
                            .frame(height: 34)
                        Text("\(threshold)")
                            .frame(width: 44)
                    }
                    Label("Sensor-driven: alerts trigger automatically on incoming samples.", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .cardStyle(colorScheme)

                NavigationLink {
                    AccountSettingsView(onSignOut: onSignOut)
                } label: {
                    HStack {
                        Label("Manage account", systemImage: "person.crop.circle")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .cardStyle(colorScheme)
                }
            }
            .padding()
        }
        .navigationTitle("Settings")
        .scrollIndicators(.hidden)
        .background(Theme.sceneGradient(colorScheme))
    }
}

struct AccountSettingsView: View {
    var onSignOut: () -> Void
    var body: some View {
        Form {
            Section(header: Text("Account")) {
                Button(role: .destructive) {
                    onSignOut()
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Account")
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

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .font(Typography.captionBold)
        }
        .font(Typography.captionBold)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.accent(colorScheme).opacity(0.24))
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
    let track: LinearGradient
    var height: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(track.opacity(0.6))
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
    var colorScheme: ColorScheme
    func makeBody(configuration: Configuration) -> some View {
        let palette = Theme.palette(for: colorScheme)
        let background = enabled
            ? Theme.ctaGradient(colorScheme)
            : LinearGradient(colors: [palette.logoBlue.opacity(0.32), palette.logoBlue.opacity(0.22)],
                             startPoint: .topLeading,
                             endPoint: .bottomTrailing)
        let textColor: Color = enabled ? .white : palette.logoDark.opacity(0.85)
        let stroke: Color = enabled ? Color.clear : palette.logoBlue.opacity(0.45)
        configuration.label
            .frame(maxWidth: .infinity)
            .background(AnyShapeStyle(background))
            .foregroundColor(textColor)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(stroke, lineWidth: enabled ? 0 : 1)
            )
            .shadow(color: Theme.accent(colorScheme).opacity(enabled ? 0.35 : 0.14), radius: 16, x: 0, y: 10)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

private struct GhostButtonStyle: ButtonStyle {
    var colorScheme: ColorScheme
    func makeBody(configuration: Configuration) -> some View {
        let palette = Theme.palette(for: colorScheme)
        let bg = colorScheme == .light ? palette.logoBlue.opacity(0.16) : Color.white.opacity(0.08)
        let stroke = colorScheme == .light ? palette.logoBlue.opacity(0.45) : Color.white.opacity(0.12)
        let fg = colorScheme == .light ? palette.logoDark : Color.white
        return configuration.label
            .frame(maxWidth: .infinity)
            .background(bg)
            .foregroundColor(fg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack {
                ZStack {
                    Circle()
                        .fill(iconCircleBackground)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(iconCircleStroke, lineWidth: 0.5)
                        )
                    if provider == .google {
                        Text("G").font(.headline.weight(.bold)).foregroundStyle(.black)
                    } else {
                        Image(systemName: provider.icon)
                            .font(.headline)
                            .foregroundColor(foreground)
                    }
                }
                Text(provider.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(background)
            .foregroundColor(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .light ? 0.14 : 0.24), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var palette: Theme.Palette { Theme.palette(for: colorScheme) }

    private var foreground: Color {
        switch provider {
        case .apple: return .white
        case .google: return .black
        case .email: return colorScheme == .light ? palette.logoDark : .white
        }
    }

    private var background: Color {
        switch provider {
        case .apple: return .black
        case .google: return Color.white
        case .email: return colorScheme == .light ? palette.logoBlue.opacity(0.16) : Color.white.opacity(0.08)
        }
    }

    private var stroke: Color {
        switch provider {
        case .apple: return Color.white.opacity(0.16)
        case .google: return Color.black.opacity(0.08)
        case .email: return colorScheme == .light ? palette.logoBlue.opacity(0.45) : Color.white.opacity(0.16)
        }
    }

    private var iconCircleBackground: Color {
        switch provider {
        case .google: return Color.white
        case .apple: return Color.white.opacity(0.16)
        case .email: return colorScheme == .light ? palette.logoBlue.opacity(0.22) : Color.white.opacity(0.12)
        }
    }

    private var iconCircleStroke: Color {
        switch provider {
        case .google: return Color.black.opacity(0.06)
        case .apple: return Color.white.opacity(0.0)
        case .email: return colorScheme == .light ? palette.logoBlue.opacity(0.35) : Color.white.opacity(0.0)
        }
    }
}

struct BrandLogo: View {
    var size: CGFloat = 80

    var body: some View {
        Image("BrandLogo")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct LogoMark: View {
    var size: CGFloat = 80
    var invert: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Theme.palette(for: colorScheme)
        let primary = invert ? (colorScheme == .dark ? palette.logoLight : palette.logoDark) : palette.logoBlue
        let secondary = invert ? palette.logoBlue : (colorScheme == .dark ? palette.logoDark : palette.logoLight)
        let core = Color.white
        let ring = Color.white
        let radius = size * 0.32
        let line = size * 0.27
        let coreRadius = size * 0.14
        let ringRadius = size * 0.23
        let ringWidth = size * 0.065
        ZStack {
            ArcShape(start: -200, end: 40)
                .stroke(secondary, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .frame(width: radius * 2, height: radius * 2)
                .offset(x: -size * 0.02, y: size * 0.01)
            ArcShape(start: -20, end: 220)
                .stroke(primary, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .frame(width: radius * 2, height: radius * 2)
                .offset(x: size * 0.02, y: -size * 0.01)

            Circle()
                .fill(core)
                .frame(width: coreRadius * 2, height: coreRadius * 2)

            ArcShape(start: -115, end: -65)
                .stroke(ring, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .frame(width: ringRadius * 2, height: ringRadius * 2)
            ArcShape(start: 65, end: 115)
                .stroke(ring, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .frame(width: ringRadius * 2, height: ringRadius * 2)
        }
        .frame(width: size, height: size)
        .drawingGroup()
    }
}

private struct ArcShape: Shape {
    let start: Double
    let end: Double
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.addArc(center: center,
                    radius: radius,
                    startAngle: .degrees(start),
                    endAngle: .degrees(end),
                    clockwise: false)
        return path
    }
}

private struct DividerView: View {
    let label: String
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        let palette = Theme.palette(for: colorScheme)
        let textColor = colorScheme == .light ? palette.logoDark.opacity(0.72) : Color.white.opacity(0.55)
        let lineColor = colorScheme == .light ? palette.logoBlue.opacity(0.25) : Color.white.opacity(0.12)
        HStack {
            Rectangle().frame(height: 1).foregroundStyle(lineColor)
            Text(label.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(textColor)
            Rectangle().frame(height: 1).foregroundStyle(lineColor)
        }
    }
}

private extension View {
    func cardStyle(_ scheme: ColorScheme) -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardGradient(scheme))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 18)
    }
}

private func floatingField(_ title: String, text: Binding<String>, icon: String, colorScheme: ColorScheme) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Label(title, systemImage: icon)
            .font(.caption)
            .foregroundColor(.secondary)
        TextField(title, text: text)
            .padding()
            .background(Theme.cardGradient(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

private func floatingSecure(_ title: String, text: Binding<String>, icon: String, colorScheme: ColorScheme) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Label(title, systemImage: icon)
            .font(.caption)
            .foregroundColor(.secondary)
        SecureField(title, text: text)
            .padding()
            .background(Theme.cardGradient(colorScheme))
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
    struct Palette {
        let bgTop: Color
        let bgMid: Color
        let bgBottom: Color
        let glow: Color
        let accent: Color
        let accent2: Color
        let accentWarm: Color
        let logoDark: Color
        let logoBlue: Color
        let logoLight: Color
        let cardTop: Color
        let cardBottom: Color
    }

    static let dark = Palette(
        bgTop: Color(red: 0.07, green: 0.11, blue: 0.16),
        bgMid: Color(red: 0.09, green: 0.16, blue: 0.22),
        bgBottom: Color(red: 0.10, green: 0.20, blue: 0.28),
        glow: Color(red: 0.31, green: 0.56, blue: 0.80).opacity(0.35),
        accent: Color(red: 0.31, green: 0.53, blue: 0.75),
        accent2: Color(red: 0.17, green: 0.28, blue: 0.33),
        accentWarm: Color(red: 0.44, green: 0.68, blue: 0.90),
        logoDark: Color(red: 0.20, green: 0.30, blue: 0.36),
        logoBlue: Color(red: 0.36, green: 0.57, blue: 0.78),
        logoLight: Color(red: 0.75, green: 0.84, blue: 0.90),
        cardTop: Color(red: 0.14, green: 0.21, blue: 0.30).opacity(0.92),
        cardBottom: Color(red: 0.08, green: 0.14, blue: 0.22).opacity(0.92)
    )

    static let light = Palette(
        bgTop: Color(red: 0.95, green: 0.97, blue: 0.99),
        bgMid: Color(red: 0.92, green: 0.95, blue: 0.98),
        bgBottom: Color(red: 0.88, green: 0.93, blue: 0.97),
        glow: Color(red: 0.60, green: 0.75, blue: 0.90).opacity(0.30),
        accent: Color(red: 0.31, green: 0.53, blue: 0.75),
        accent2: Color(red: 0.20, green: 0.30, blue: 0.36),
        accentWarm: Color(red: 0.56, green: 0.72, blue: 0.88),
        logoDark: Color(red: 0.20, green: 0.30, blue: 0.36),
        logoBlue: Color(red: 0.36, green: 0.57, blue: 0.78),
        logoLight: Color(red: 0.86, green: 0.91, blue: 0.95),
        cardTop: Color(red: 0.97, green: 0.98, blue: 1.00).opacity(0.96),
        cardBottom: Color(red: 0.90, green: 0.94, blue: 0.98).opacity(0.96)
    )

    static func palette(for scheme: ColorScheme) -> Palette {
        scheme == .dark ? dark : light
    }

    static func accent(_ scheme: ColorScheme) -> Color { palette(for: scheme).accent }
    static func accent2(_ scheme: ColorScheme) -> Color { palette(for: scheme).accent2 }
    static func accentWarm(_ scheme: ColorScheme) -> Color { palette(for: scheme).accentWarm }
    static func logoDark(_ scheme: ColorScheme) -> Color { palette(for: scheme).logoDark }
    static func logoBlue(_ scheme: ColorScheme) -> Color { palette(for: scheme).logoBlue }
    static func logoLight(_ scheme: ColorScheme) -> Color { palette(for: scheme).logoLight }
    static func glow(_ scheme: ColorScheme) -> Color { palette(for: scheme).glow }

    static func primaryGradient(_ scheme: ColorScheme) -> LinearGradient {
        let p = palette(for: scheme)
        return LinearGradient(colors: [p.accent, p.accentWarm],
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing)
    }

    static func ctaGradient(_ scheme: ColorScheme) -> LinearGradient {
        let p = palette(for: scheme)
        if scheme == .light {
            return LinearGradient(colors: [p.logoBlue, p.logoDark],
                                  startPoint: .topLeading,
                                  endPoint: .bottomTrailing)
        } else {
            return primaryGradient(scheme)
        }
    }

    static func muted(_ scheme: ColorScheme) -> LinearGradient {
        let p = palette(for: scheme)
        return LinearGradient(colors: [p.cardTop.opacity(0.8), p.cardBottom.opacity(0.8)],
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing)
    }

    static func cardGradient(_ scheme: ColorScheme) -> LinearGradient {
        let p = palette(for: scheme)
        return LinearGradient(colors: [p.cardTop, p.cardBottom],
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing)
    }

    static func sceneGradient(_ scheme: ColorScheme) -> LinearGradient {
        let p = palette(for: scheme)
        return LinearGradient(colors: [p.bgTop, p.bgMid, p.bgBottom],
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing)
    }
}

// Animated gradient blobs for subtle motion
private struct AnimatedBlobBackground: View {
    let palette: Theme.Palette

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/24)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let offset1 = CGSize(width: sin(t/3.5) * w*0.25, height: cos(t/4.2) * h*0.18)
                let offset2 = CGSize(width: cos(t/2.8) * w*0.2,  height: sin(t/3.8) * h*0.22)
                let offset3 = CGSize(width: sin(t/4.8) * w*0.3,  height: cos(t/5.2) * h*0.16)

                drawBlob(context: &context, size: size, origin: CGPoint(x: w*0.35 + offset1.width, y: h*0.3 + offset1.height), color: palette.accent.opacity(0.18))
                drawBlob(context: &context, size: size, origin: CGPoint(x: w*0.7 + offset2.width,  y: h*0.15 + offset2.height), color: palette.accent2.opacity(0.16))
                drawBlob(context: &context, size: size, origin: CGPoint(x: w*0.5 + offset3.width,  y: h*0.75 + offset3.height), color: palette.accentWarm.opacity(0.10))
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

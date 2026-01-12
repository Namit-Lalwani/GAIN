import SwiftUI

struct TemplatesView: View {
    @EnvironmentObject var templateStore: TemplateStore
    @ObservedObject private var scheduleManager = RoutineScheduleManager.shared
    @State private var activeTemplate: TemplateModel?
    @State private var showingScheduleEditor = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Routines")
                            .font(.largeTitle).bold()
                            .foregroundColor(.gainTextPrimary)
                        Text("\(templateStore.templates.count) custom routines")
                            .font(.subheadline)
                            .foregroundColor(.gainTextSecondary)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Weekly Schedule Section
                    weeklyScheduleSection
                    
                    // Create New Button
                    Button {
                        activeTemplate = TemplateModel()
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.gainTextPrimary)
                            Text("Create New Routine")
                                .font(.headline)
                                .foregroundColor(.gainTextPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gainTextSecondary)
                        }
                        .padding()
                        .background(
                            Color.gainVibrantGradient
                        )
                        .cornerRadius(12)
                        .shadow(color: Color.gainPink.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    // User Templates
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Your Routines")
                                .font(.title3).bold()
                                .foregroundColor(.gainTextPrimary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        if templateStore.templates.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "dumbbell")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gainAccentSoft.opacity(0.5))
                                Text("No routines yet")
                                    .font(.headline)
                                    .foregroundColor(.gainTextSecondary)
                                Text("Create your first routine to get started")
                                    .font(.caption)
                                    .foregroundColor(.gainTextSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(templateStore.templates) { t in
                                    NavigationLink {
                                        TemplateEditorView(template: t)
                                    } label: {
                                        RoutineCard(template: t)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.top)
            }
            .background(Color.gainBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .sheet(item: $activeTemplate) { template in
                NavigationView {
                    TemplateEditorView(template: template)
                }
            }
            .sheet(isPresented: $showingScheduleEditor) {
                WeeklyScheduleEditorSheet()
                    .environmentObject(templateStore)
            }
        }
    }
    
    // MARK: - Weekly Schedule Section
    
    private var weeklyScheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Schedule")
                    .font(.title3).bold()
                    .foregroundColor(.gainTextPrimary)
                Spacer()
                Button("Edit") {
                    showingScheduleEditor = true
                }
                .font(.subheadline)
                .foregroundColor(.gainAccent)
            }
            .padding(.horizontal)
            
            // Compact week view
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Weekday.allCases) { weekday in
                        WeekdayScheduleCard(
                            weekday: weekday,
                            templateName: scheduleManager.templateName(for: weekday, from: templateStore.templates),
                            isToday: weekday == .today,
                            isRestDay: scheduleManager.isRestDay(weekday)
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func createTemplateFromRecommended(name: String, exercises: [String]) {
        let exerciseModels = exercises.map { Exercise(name: $0, sets: []) }
        activeTemplate = TemplateModel(name: name, exercises: exerciseModels)
    }
}

// MARK: - Weekday Schedule Card

struct WeekdayScheduleCard: View {
    let weekday: Weekday
    let templateName: String
    let isToday: Bool
    let isRestDay: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            Text(weekday.shortName)
                .font(.caption2)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(isToday ? .gainAccent : .gainTextSecondary)
            
            Text(isRestDay ? "Rest" : String(templateName.prefix(4)))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isRestDay ? .secondary : .gainTextPrimary)
                .lineLimit(1)
        }
        .frame(width: 48, height: 48)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isToday ? Color.gainAccent.opacity(0.2) : Color.gainCardSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isToday ? Color.gainAccent : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Weekly Schedule Editor Sheet

struct WeeklyScheduleEditorSheet: View {
    @EnvironmentObject var templateStore: TemplateStore
    @ObservedObject private var scheduleManager = RoutineScheduleManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Assign templates to days")) {
                    ForEach(Weekday.allCases) { weekday in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(weekday.fullName)
                                    .font(.headline)
                                if weekday == .today {
                                    Text("Today")
                                        .font(.caption)
                                        .foregroundColor(.gainAccent)
                                }
                            }
                            
                            Spacer()
                            
                            Picker("", selection: Binding(
                                get: { scheduleManager.templateId(for: weekday) },
                                set: { scheduleManager.setTemplate(for: weekday, templateId: $0) }
                            )) {
                                Text("Rest Day").tag(nil as UUID?)
                                ForEach(templateStore.templates) { template in
                                    Text(template.name).tag(template.id as UUID?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Tip", systemImage: "lightbulb.fill")
                            .font(.subheadline)
                            .foregroundColor(.yellow)
                        Text("Your weekly schedule determines which routine appears in \"Start Today's Routine\". Set a day to Rest if you don't want to train that day.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Weekly Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Components

struct RoutineCard: View {
    let template: TemplateModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gainAccent.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "list.bullet.clipboard")
                    .font(.title3)
                    .foregroundColor(.gainAccent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.headline)
                    .foregroundColor(.gainTextPrimary)
                
                HStack(spacing: 8) {
                    Label("\(template.exercises.count)", systemImage: "dumbbell.fill")
                    
                    if !template.exercises.isEmpty {
                        Text("•")
                        Text(exercisePreview)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundColor(.gainTextSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gainTextSecondary)
        }
        .padding()
        .background(Color.gainCard)
        .cornerRadius(12)
    }
    
    private var exercisePreview: String {
        let names = template.exercises.prefix(2).map { $0.name }
        return names.joined(separator: ", ")
    }
}

//
//  ContentView.swift
//  BudgeThink
//
//  Created by MacBook on 18/05/25.
//

import SwiftUI
import SwiftData

// MARK: - Model SwiftData

@Model
final class Plan: Identifiable, Equatable {
    @Attribute(.unique) var id: UUID
    var barang: String
    var harga: Int
    var prioritas: Prioritas
    var kategori: KategoriPlan
    var bulanTahun: String
    
    init(id: UUID = UUID(), barang: String, harga: Int, prioritas: Prioritas, kategori: KategoriPlan, bulanTahun: String) {
        self.id = id
        self.barang = barang
        self.harga = harga
        self.prioritas = prioritas
        self.kategori = kategori
        self.bulanTahun = bulanTahun
    }
    
    static func == (lhs: Plan, rhs: Plan) -> Bool {
        lhs.id == rhs.id
    }
}

@Model
final class Budget: Identifiable {
    @Attribute(.unique) var id: UUID
    var bulanTahun: String
    var totalBudget: Int
    
    init(id: UUID = UUID(), bulanTahun: String, totalBudget: Int) {
        self.id = id
        self.bulanTahun = bulanTahun
        self.totalBudget = totalBudget
    }
}

// MARK: - Enum

enum Prioritas: String, CaseIterable, Identifiable, Comparable, Codable {
    case tinggi = "High"
    case sedang = "Medium"
    case rendah = "Low"
    
    var id: String { self.rawValue }
    
    static func < (lhs: Prioritas, rhs: Prioritas) -> Bool {
        let order: [Prioritas] = [.tinggi, .sedang, .rendah]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

enum KategoriPlan: String, CaseIterable, Identifiable, Codable {
    case needs = "Needs"
    case wants = "Wants"
    
    var id: String { self.rawValue }
}

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Plan.bulanTahun, order: .forward) private var allPlans: [Plan]
    @Query(sort: \Budget.bulanTahun, order: .forward) private var allBudgets: [Budget]
    
    @EnvironmentObject var appState: AppState
    var selectedDate: Date {
        get { appState.selectedDate }
        set { appState.selectedDate = newValue }
    }
    
    @State private var showDatePicker = false
    
    @State private var showAddPlan = false
    @State private var selectedKategori: KategoriPlan = .needs
    @State private var editingPlan: Plan? = nil
    @State private var showBudgetEditor = false
    @State private var deletingPlan: Plan? = nil
    
    @State private var tempBudgetText: String = ""
    
    private var monthlyPlans: [Plan] {
        allPlans.filter { $0.bulanTahun == appState.bulanTahunKey }
    }
    
    private var filteredPlans: [Plan] {
        monthlyPlans.filter { $0.kategori == selectedKategori }
            .sorted { $0.prioritas < $1.prioritas }
    }
    
    private var totalNeedsUsed: Int {
        monthlyPlans.filter { $0.kategori == .needs }.reduce(0) { $0 + $1.harga }
    }
    
    private var totalWantsUsed: Int {
        monthlyPlans.filter { $0.kategori == .wants }.reduce(0) { $0 + $1.harga }
    }
    
    private var totalBudget: Int {
        allBudgets.first(where: { $0.bulanTahun == appState.bulanTahunKey })?.totalBudget ?? 0
    }

    private var remainingBudget: Int {
        totalBudget - (totalNeedsUsed + totalWantsUsed)
    }
    
    private var needsBudget: Int {
        totalBudget * 50 / 100
    }
    
    private var wantsBudget: Int {
        totalBudget * 30 / 100
    }
    
    private var savingsAmount: Int {
        totalBudget * 20 / 100
    }
    
    private let months = Calendar.current.monthSymbols
    private let years: [Int] = {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear-5)...(currentYear+5))
    }()
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack(spacing: 16) {
                    budgetOverviewSection
                    
                    categorySegmentedControl
                    
                    planListSection
                }
                .navigationTitle("Dashboard")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            withAnimation { showDatePicker.toggle() }
                        } label: {
                            HStack(spacing: 12) {
                                Text(appState.bulanTahunKey)
                                Image(systemName: "arrowtriangle.down.fill")
                                    .resizable()
                                    .frame(width: 12, height: 8)
                            }
                        }
                    }
                }
            }
            
            if showDatePicker {
                datePickerOverlay
            }
        }
        .sheet(isPresented: $showAddPlan, onDismiss: { editingPlan = nil }) {
            AddPlanView(
                kategori: selectedKategori,
                existingPlan: editingPlan,
                maxAllocation: selectedKategori == .needs
                ? (needsBudget - totalNeedsUsed + (editingPlan?.harga ?? 0))
                : (wantsBudget - totalWantsUsed + (editingPlan?.harga ?? 0)),
                onSave: { barang, harga, prioritas in
                    savePlan(barang: barang, harga: harga, prioritas: prioritas)
                }
            )
            .environment(\.modelContext, modelContext)
        }
        .confirmationDialog(
            "Are you sure you want to delete \"\(deletingPlan?.barang ?? "")\"?",
            isPresented: Binding(
                get: { deletingPlan != nil },
                set: { if !$0 { deletingPlan = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let plan = deletingPlan {
                    deletePlan(plan)
                }
            }
            Button("Cancel", role: .cancel) {
                deletingPlan = nil
            }
        }
        .sheet(isPresented: $showBudgetEditor) {
            NavigationView {
                Form {
                    Section(header: Text("Set Budget for \(appState.bulanTahunKey)")) {
                        TextField("Budget (IDR)", text: $tempBudgetText)
                            .keyboardType(.numberPad)
                    }
                }
                .navigationTitle("Set Budget")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showBudgetEditor = false
                    },
                    trailing: Button("Save") {
                        saveBudget()
                    }
                        .disabled(Int(tempBudgetText.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)) == nil)
                )
            }
        }
        .onAppear {
            tempBudgetText = "\(totalBudget)"
        }
    }
    
    // MARK: - Subviews
    
    private var budgetOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack (alignment: .leading, spacing: 0) {
                HStack (alignment: .top) {
                    Text("Budget:")
                        .font(.subheadline)
                    Spacer()
                    if totalBudget != 0 {
                        Button {
                            tempBudgetText = "\(totalBudget)"
                            showBudgetEditor = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(.indigo)
                                .padding(6)
                                .background(Color.indigo.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                }
                if totalBudget != 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(formatCurrency(remainingBudget))")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("/ \(formatCurrency(totalBudget))")
                            .font(.subheadline)
                    }
                }
            }

            if totalBudget != 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Needs (50%):")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Spacer()
                        Text("\(formatCurrency(needsBudget - totalNeedsUsed)) / \(formatCurrency(needsBudget))")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    ProgressView(value: Double(needsBudget - totalNeedsUsed), total: Double(needsBudget))
                        .tint(progressColor(for: needsBudget, used: totalNeedsUsed))
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Wants (30%):")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Spacer()
                        Text("\(formatCurrency(wantsBudget - totalWantsUsed)) / \(formatCurrency(wantsBudget))")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    ProgressView(value: Double(wantsBudget - totalWantsUsed), total: Double(wantsBudget))
                        .tint(progressColor(for: wantsBudget, used: totalWantsUsed))
                }

                HStack {
                    Text("Savings (20%):")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    Spacer()
                    Text("\(formatCurrency(savingsAmount))")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            } else {
                Button(action: {
                    tempBudgetText = ""
                    showBudgetEditor = true
                }) {
                    Label("Set Budget", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.indigo)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .gray.opacity(0.2), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
    
    private var categorySegmentedControl: some View {
        VStack(spacing: 16) {
            HStack {
                Picker("Category", selection: $selectedKategori) {
                    ForEach(KategoriPlan.allCases) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)
            Button(action: { showAddPlan = true }){
                Label(
                    title: {
                        Text("Add Plan (\(selectedKategori.rawValue.capitalized))")
                            .font(.callout)
                    },
                    icon: {
                        Image(systemName: "plus.circle")
                    }
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .buttonStyle(.borderedProminent)
            .frame(maxWidth:.infinity)
            .tint(.indigo)
            .buttonBorderShape(.roundedRectangle(radius: 10))
            .disabled(!canAddPlan(for: selectedKategori))
        }
    }
    
    private var planListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredPlans) { plan in
                    PlanRow(
                        plan: plan,
                        onEdit: {
                            editingPlan = plan
                            selectedKategori = plan.kategori
                            showAddPlan = true
                        },
                        onDelete: {
                            deletingPlan = plan
                        }
                    )
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.gray.opacity(0.2), radius: 4, x: 0, y: 2)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
    
    private var datePickerOverlay: some View {
        Color.black.opacity(0.2)
            .ignoresSafeArea()
            .onTapGesture
        {
            withAnimation { showDatePicker = false }
        }
        .overlay {
            VStack {
                HStack(spacing: 16) {
                    Picker("Bulan", selection: monthBinding) {
                        ForEach(0..<months.count, id: \Int.self) { index in
                            Text(months[index]).tag(index)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    Picker("Tahun", selection: yearBinding) {
                        ForEach(years, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 150)
                Button("Done") {
                    withAnimation { showDatePicker = false }
                }
                .padding()
            }
            .background(.regularMaterial)
            .cornerRadius(12)
            .padding()
        }
    }
    
    // MARK: - Helpers
    
    private func progressColor(for budget: Int, used: Int) -> Color {
        let remaining = budget - used
        guard budget > 0 else { return .gray }

        let percentage = Double(remaining) / Double(budget)

        switch percentage {
        case ..<0.25:
            return .red
        case ..<0.5:
            return .orange
        default:
            return .green
        }
    }
    
    private func canAddPlan(for kategori: KategoriPlan) -> Bool {
        let maxBudget = kategori == .needs ? needsBudget : wantsBudget
        let usedBudget = kategori == .needs ? totalNeedsUsed : totalWantsUsed
        return usedBudget < maxBudget
    }
    
    private func savePlan(barang: String, harga: Int, prioritas: Prioritas) {
        if let editingPlan = editingPlan {
            // Update existing plan
            editingPlan.barang = barang
            editingPlan.harga = harga
            editingPlan.prioritas = prioritas
            editingPlan.kategori = selectedKategori
            editingPlan.bulanTahun = appState.bulanTahunKey
            modelContext.insert(editingPlan) // Insert also updates if exists
        } else {
            // Create new plan
            let newPlan = Plan(barang: barang, harga: harga, prioritas: prioritas, kategori: selectedKategori, bulanTahun: appState.bulanTahunKey)
            modelContext.insert(newPlan)
        }
        do {
            try modelContext.save()
        } catch {
            print("Failed to save plan: \(error)")
        }
        showAddPlan = false
        editingPlan = nil
    }
    
    private func deletePlan(_ plan: Plan) {
        modelContext.delete(plan)
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete plan: \(error)")
        }
        deletingPlan = nil
    }
    
    private func saveBudget() {
        guard let newBudget = Int(tempBudgetText.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)) else {
            return
        }
        if let existingBudget = allBudgets.first(where: { $0.bulanTahun == appState.bulanTahunKey }) {
            existingBudget.totalBudget = newBudget
            modelContext.insert(existingBudget)
        } else {
            let budget = Budget(bulanTahun: appState.bulanTahunKey, totalBudget: newBudget)
            modelContext.insert(budget)
        }
        do {
            try modelContext.save()
        } catch {
            print("Failed to save budget: \(error)")
        }
        showBudgetEditor = false
    }
    
    private var monthBinding: Binding<Int> {
        Binding<Int>(
            get: {
                Calendar.current.component(.month, from: appState.selectedDate) - 1
            },
            set: { newMonth in
                var components = Calendar.current.dateComponents([.year, .day], from: appState.selectedDate)
                components.month = newMonth + 1
                appState.selectedDate = Calendar.current.date(from: components) ?? Date()
            }
        )
    }

    private var yearBinding: Binding<Int> {
        Binding<Int>(
            get: {
                Calendar.current.component(.year, from: appState.selectedDate)
            },
            set: { newYear in
                var components = Calendar.current.dateComponents([.month, .day], from: appState.selectedDate)
                components.year = newYear
                appState.selectedDate = Calendar.current.date(from: components) ?? Date()
            }
        )
    }
    
    private func formatCurrency(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.numberStyle = .currency
        formatter.currencySymbol = "Rp"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "Rp0"
    }
}

// MARK: - PlanRow

struct PlanRow: View {
    var plan: Plan
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(plan.barang)
                        .font(.headline)
                        .foregroundColor(.black)
                }
                
                Text(formatCurrency(plan.harga))
                    .font(.subheadline)
                    .foregroundColor(.black)
                
                HStack(spacing: 4) {
                    Image(systemName: "star.circle.fill")
                        .foregroundColor(colorForPriority(plan.prioritas))
                    Text("\(plan.prioritas.rawValue) Priority")
                        .font(.caption)
                        .foregroundColor(.black)
                        .bold()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            Menu {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .foregroundColor(.indigo)
                    .padding(10)
                    .background(Color.indigo.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding()
    }

    private func formatCurrency(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.numberStyle = .currency
        formatter.currencySymbol = "Rp"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "Rp0"
    }

    private func colorForPriority(_ priority: Prioritas) -> Color {
        switch priority {
        case .tinggi: return .red
        case .sedang: return .orange
        case .rendah: return .green
        }
    }
}

// MARK: - AddPlanView

struct AddPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var kategori: KategoriPlan
    var existingPlan: Plan?
    var maxAllocation: Int
    var onSave: (String, Int, Prioritas) -> Void

    @State private var barang: String = ""
    @State private var hargaText: String = ""
    @State private var prioritas: Prioritas = .sedang

    @State private var showAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("Item")
                        Spacer()
                        TextField("Item Name", text: $barang)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Price")
                        Spacer()
                        TextField("Input Price", text: $hargaText)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Priority", selection: $prioritas) {
                        ForEach(Prioritas.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section {
                    Text("Maximum Allocation: \(formatCurrency(maxAllocation))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("\(existingPlan == nil ? "Add" : "Edit") Plan (\(kategori.rawValue.capitalized))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let harga = Int(hargaText), !barang.isEmpty else {
                            showAlert = true
                            return
                        }
                        if harga > maxAllocation {
                            showAlert = true
                            return
                        }
                        onSave(barang, harga, prioritas)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Input tidak valid atau alokasi melebihi batas", isPresented: $showAlert) {
                Button("OK") {}
            }
            .onAppear {
                if let plan = existingPlan {
                    barang = plan.barang
                    hargaText = "\(plan.harga)"
                    prioritas = plan.prioritas
                }
            }
        }
    }

    private func formatCurrency(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.numberStyle = .currency
        formatter.currencySymbol = "Rp"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "Rp0"
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .modelContainer(for: [Plan.self, Budget.self])
}

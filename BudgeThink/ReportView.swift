//
//  ReportView.swift
//  BudgeThink
//
//  Created by MacBook on 18/05/25.
//

import SwiftUI
import SwiftData

struct ReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Plan.bulanTahun, order: .forward) private var allPlans: [Plan]
    @Query(sort: \Budget.bulanTahun, order: .forward) private var allBudgets: [Budget]

    @EnvironmentObject var appState: AppState
    var selectedDate: Date {
        get { appState.selectedDate }
        set { appState.selectedDate = newValue }
    }
    
    @State private var showDatePicker = false

    private var monthlyPlans: [Plan] {
        allPlans.filter { $0.bulanTahun == appState.bulanTahunKey }
    }

    private var needsPlans: [Plan] {
        monthlyPlans.filter { $0.kategori == .needs }
    }

    private var wantsPlans: [Plan] {
        monthlyPlans.filter { $0.kategori == .wants }
    }

    private var subtotalNeeds: Int {
        needsPlans.reduce(0) { $0 + $1.harga }
    }

    private var subtotalWants: Int {
        wantsPlans.reduce(0) { $0 + $1.harga }
    }

    private var totalBudget: Int {
        allBudgets.first(where: { $0.bulanTahun == appState.bulanTahunKey })?.totalBudget ?? 0
    }

    private var totalPengeluaran: Int {
        subtotalNeeds + subtotalWants
    }

    private var sisaBudget: Int {
        totalBudget - totalPengeluaran
    }

    private let months = Calendar.current.monthSymbols
    private let years: [Int] = {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear-5)...(currentYear+5))
    }()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Needs")
                        .font(.headline)
                        .foregroundStyle(.indigo)
                    ForEach(needsPlans) { plan in
                        HStack {
                            Text(plan.barang)
                            Spacer()
                            Text(formatCurrency(plan.harga))
                        }
                    }
                    HStack {
                        Text("Subtotal:")
                            .fontWeight(.bold)
                        Spacer()
                        Text(formatCurrency(subtotalNeeds))
                            .fontWeight(.bold)
                    }

                    Divider()
                        .frame(height: 1)
                        .background(.indigo)

                    Text("Wants")
                        .font(.headline)
                        .foregroundStyle(.indigo)
                    ForEach(wantsPlans) { plan in
                        HStack {
                            Text(plan.barang)
                            Spacer()
                            Text(formatCurrency(plan.harga))
                        }
                    }
                    HStack {
                        Text("Subtotal:")
                            .fontWeight(.bold)
                        Spacer()
                        Text(formatCurrency(subtotalWants))
                            .fontWeight(.bold)
                    }

                    Divider()
                        .frame(height: 1)
                        .background(.indigo)

                    HStack {
                        Text("Total Plan:")
                            .fontWeight(.bold)
                        Spacer()
                        Text(formatCurrency(totalPengeluaran))
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("Sisa Budget:")
                            .fontWeight(.bold)
                        Spacer()
                        Text(formatCurrency(sisaBudget))
                            .foregroundColor(sisaBudget >= 0 ? .green : .red)
                            .fontWeight(.bold)
                    }
                }
                .padding()
            }
            .navigationTitle("Report")
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
            .overlay {
                if showDatePicker {
                    datePickerOverlay
                }
            }
        }
    }

    private var datePickerOverlay: some View {
        Color.black.opacity(0.2)
            .ignoresSafeArea()
            .onTapGesture {
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
        formatter.currencySymbol = "Rp "
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "Rp 0"
    }
}

#Preview {
    ReportView()
        .environmentObject(AppState())
        .modelContainer(for: [Plan.self, Budget.self])
}

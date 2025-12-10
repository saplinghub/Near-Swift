import SwiftUI

struct ContentView: View {
    @EnvironmentObject var countdownManager: CountdownManager
    @EnvironmentObject var aiService: AIService
    @State private var showingAddSheet = false
    @State private var showingSettingsSheet = false
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main Content Layer
            VStack(spacing: 0) {
                // Modified Header (Now contains Tabs + Settings)
                HeaderView(showingSettingsSheet: $showingSettingsSheet, selectedTab: $selectedTab)
                    .zIndex(1) // Ensure header stays on top

                // Scrollable Content Area
                Group {
                    if selectedTab == 0 {
                        activeCountdownsView
                    } else {
                        completedCountdownsView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 380, height: 600)
            .background(
                ZStack {
                    // 主背景
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .nearBackgroundStart,
                            .nearBackgroundEnd
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // 装饰性渐变
                    VStack {
                        HStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.nearPrimary.opacity(0.1),
                                            Color.nearSecondary.opacity(0.05)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .blur(radius: 40)
                            Spacer()
                        }
                        Spacer()
                        HStack {
                            Spacer()
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(hex: "#EC4899").opacity(0.08),
                                            Color(hex: "#F59E0B").opacity(0.04)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .blur(radius: 30)
                        }
                    }
                }
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.8),
                                Color.white.opacity(0.2)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )

            // FAB Layer
            FabButton(action: {
                showingAddSheet = true
            })
            .padding(.bottom, 24)
            .padding(.trailing, 24)
            .scaleEffect(showingAddSheet ? 0.0 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showingAddSheet)
        }
        .frame(width: 380, height: 600) // Explicit frame for the window content
        .sheet(isPresented: $showingAddSheet) {
            AddCountdownView()
                .environmentObject(countdownManager)
                //.presentationDetents([.height(400)]) // Optional: Make it smaller
        }
        .sheet(isPresented: $showingSettingsSheet) {
            SettingsView()
                .environmentObject(countdownManager)
        }
        
        // Modal for AI Parser if needed, currently AddCountdownView handles it?
        // AddCountdownView structure needs checking if it uses AI parser inside. 
    }

    private var activeCountdownsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if countdownManager.activeCountdowns.isEmpty {
                    EmptyStateView(title: "暂无倒计时", subtitle: "点击右下角 + 添加")
                        .padding(.top, 100)
                } else {
                    ForEach(countdownManager.activeCountdowns) { countdown in
                        CountdownCardView(countdown: countdown)
                            .onDrag {
                                let idString = countdown.uuidString
                                return NSItemProvider(object: idString as NSString)
                            }
                            .onDrop(of: [.data], delegate: DragDropDelegate(sourceIndex: countdownManager.activeCountdowns.firstIndex(where: { $0.id == countdown.id }) ?? 0, countdownManager: countdownManager))
                    }
                    .onMove(perform: moveActiveCountdowns)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 80) // Space for FAB
            .padding(.top, 8)
        }
        .animation(.easeInOut(duration: 0.3), value: countdownManager.activeCountdowns.count)
    }

    private var completedCountdownsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if countdownManager.completedCountdowns.isEmpty {
                    EmptyStateView(title: "暂无已结束的倒计时", subtitle: "完成的倒计时会显示在这里")
                        .padding(.top, 100)
                } else {
                    ForEach(countdownManager.completedCountdowns) { countdown in
                        CountdownCardView(countdown: countdown)
                            .onDrag {
                                let idString = countdown.uuidString
                                return NSItemProvider(object: idString as NSString)
                            }
                            .onDrop(of: [.data], delegate: DragDropDelegate(sourceIndex: countdownManager.completedCountdowns.firstIndex(where: { $0.id == countdown.id }) ?? 0, countdownManager: countdownManager))
                    }
                    .onMove(perform: moveCompletedCountdowns)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 80) // Space for FAB
            .padding(.top, 8)
        }
        .animation(.easeInOut(duration: 0.3), value: countdownManager.completedCountdowns.count)
    }

    // 拖拽排序功能
    private func moveActiveCountdowns(from source: IndexSet, to destination: Int) {
        countdownManager.moveActiveCountdowns(from: source, to: destination)
    }

    private func moveCompletedCountdowns(from source: IndexSet, to destination: Int) {
        countdownManager.moveCompletedCountdowns(from: source, to: destination)
    }
}
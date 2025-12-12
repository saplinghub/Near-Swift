import SwiftUI

struct ContentView: View {
    @EnvironmentObject var countdownManager: CountdownManager
    // Add environment objects for others if needed directly, but usually they cascade
    @EnvironmentObject var aiService: AIService
    @EnvironmentObject var storageManager: StorageManager
    @EnvironmentObject var systemMonitor: SystemMonitor
    
    @State private var showingAddView = false
    @State private var showingSettingsView = false
    @State private var selectedTopTab = 0 // "In Progress" vs "Completed"
    @State private var selectedBottomTab = 0 // "Events", "Calendar", etc.

    var body: some View {
        ZStack {
            // Main Content Layer
                // Content Area with Tab Switching
                ZStack {
                    if selectedBottomTab == 0 {
                        // Tab 0: Events (Original Home)
                        VStack(spacing: 0) {
                            // Header linked to our state (Top Tabs)
                            HeaderView(showingSettingsSheet: $showingSettingsView, selectedTab: $selectedTopTab)
                            
                            // Content
                            Group {
                                if selectedTopTab == 0 {
                                    activeCountdownsView
                                } else {
                                    completedCountdownsView
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .transition(.opacity)
                    } else if selectedBottomTab == 1 {
                         // Tab 1: Intelligent Calendar
                         VStack(spacing: 0) {
                             PageHeader(title: "日历 & 黄历", showingSettingsSheet: $showingSettingsView)
                             CalendarView()
                         }
                         .transition(.opacity)
                    } else if selectedBottomTab == 2 {
                         // Tab 2: System View
                         VStack(spacing: 0) {
                             PageHeader(title: "系统状态", showingSettingsSheet: $showingSettingsView)
                             SystemView()
                         }
                         .transition(.opacity)
                    } else if selectedBottomTab == 3 {
                         // Tab 3: Mine/Settings Placeholder
                         VStack(spacing: 0) {
                             PageHeader(title: "我的", showingSettingsSheet: $showingSettingsView)
                             
                             VStack {
                                 Image(systemName: "person.crop.circle")
                                    .font(.system(size: 50))
                                    .foregroundColor(.nearPrimary.opacity(0.3))
                                 Text("个人中心")
                                    .foregroundColor(.secondary)
                                 
                                 Button("打开设置") {
                                     showingSettingsView = true
                                 }
                                 .padding(.top, 20)
                             }
                             .frame(maxWidth: .infinity, maxHeight: .infinity)
                         }
                         .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            .blur(radius: (showingAddView || showingSettingsView) ? 10 : 0) // Blur effect when overlay is active
            .disabled(showingAddView || showingSettingsView)
            
            // FAB (Floating Action Button) - Only show when no overlay
            if !showingAddView && !showingSettingsView {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        CollapsibleFab(action: {
                            withAnimation(.spring()) {
                                showingAddView = true
                            }
                        })

                        .padding(.trailing, 20)
                        .padding(.bottom, 40) // Adjusted for minimal bar
                    }
                }
                .transition(.scale)
            }
            
            // Bottom Tab Bar - Always visible unless overlay
            if !showingAddView && !showingSettingsView {
                VStack {
                    Spacer()
                    BottomTabBar(selectedTab: $selectedBottomTab)
                }
                .transition(.move(edge: .bottom))
                .zIndex(1) // Above content, below FAB? Actually FAB should generally be above. 
                // Z-Index: Content=0, BottomBar=1, FAB= (VStack above is implicit), Overlay=2/3
            }
            
            // Overlays
            if showingAddView {
                // Dimming background
                Color.black.opacity(0.2)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation { showingAddView = false }
                    }
                
                AddCountdownView(isPresented: $showingAddView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.nearBackgroundEnd) // Ensure background
                    .cornerRadius(16) // Match window corner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }
            
            if showingSettingsView {
                Color.black.opacity(0.2)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation { showingSettingsView = false }
                    }
                
                SettingsView(isPresented: $showingSettingsView)
                     .frame(maxWidth: .infinity, maxHeight: .infinity)
                     .background(Color.nearBackgroundEnd)
                     .cornerRadius(16)
                     .transition(.move(edge: .bottom).combined(with: .opacity))
                     .zIndex(3)
            }
        }
        .frame(width: 380, height: 600)
        .background(
             ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.nearBackgroundStart,
                        Color.nearBackgroundEnd
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
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
    }

    private var activeCountdownsView: some View {
        ScrollView(showsIndicators: false) { // No scrollbar
            VStack(spacing: 16) {
                // Pinned Item Section
                if let pinned = countdownManager.pinnedCountdown {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.nearPrimary)
                            Text("置顶")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.nearSecondary)
                        }
                        .padding(.leading, 4)
                        
                        CountdownCardView(countdown: pinned)
                    }
                    .padding(.bottom, 12)
                }

                if countdownManager.activeCountdowns.isEmpty && countdownManager.pinnedCountdown == nil {
                    EmptyStateView(title: "暂无倒计时", subtitle: "点击右下角 + 添加")
                        .padding(.top, 100)
                } else if !countdownManager.activeCountdowns.isEmpty {
                    ForEach(countdownManager.activeCountdowns) { countdown in
                        CountdownCardView(countdown: countdown)
                            .onDrag {
                                let idString = countdown.uuidString
                                return NSItemProvider(object: idString as NSString)
                            }
                            .onDrop(of: [.text], delegate: DragDropDelegate(destination: countdown, countdownManager: countdownManager))
                    }
                }
                
                // Drop zone at bottom for appending
                if !countdownManager.activeCountdowns.isEmpty {
                    Color.clear
                        .frame(height: 50)
                        .contentShape(Rectangle())
                        .onDrop(of: [.text], delegate: DragDropDelegate(destination: nil, countdownManager: countdownManager))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40) // Adjusted for minimal bar
            .padding(.top, 8)
        }
    }

    private var completedCountdownsView: some View {
        ScrollView(showsIndicators: false) { // No scrollbar
            VStack(spacing: 16) {
                if countdownManager.completedCountdowns.isEmpty {
                    EmptyStateView(title: "暂无已结束的倒计时", subtitle: "完成的倒计时会显示在这里")
                        .padding(.top, 100)
                } else {
                    ForEach(countdownManager.completedCountdowns) { countdown in
                        CountdownCardView(countdown: countdown)
                            .opacity(0.7)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40) // Adjusted for minimal bar
            .padding(.top, 8)
        }
    }
}

// Collapsible FAB Component
struct CollapsibleFab: View {
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: isHovering ? 8 : 0) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                
                if isHovering {
                    Text("新建")
                        .font(.system(size: 14, weight: .bold))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .foregroundColor(.white)
            .padding(.vertical, isHovering ? 12 : 8)
            .padding(.horizontal, isHovering ? 20 : 8)
            .background(
                LinearGradient(gradient: Gradient(colors: [.nearPrimary, .nearHoverBlueBg]), startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Capsule())
            .shadow(color: .nearPrimary.opacity(0.4), radius: 8, x: 0, y: 4)
            .scaleEffect(isHovering ? 1.0 : 0.8) // Shrink by default
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hover in
            withAnimation(.spring()) {
                isHovering = hover
            }
        }
    }
}
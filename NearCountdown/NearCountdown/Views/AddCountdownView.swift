import SwiftUI
import Combine

struct AddCountdownView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var countdownManager: CountdownManager
    @EnvironmentObject var aiService: AIService 
    
    @State private var name: String = ""
    @State private var startDate = Date()
    @State private var targetDate = Date()
    @State private var startHour = 0
    @State private var startMinute = 0
    @State private var targetHour = 0
    @State private var targetMinute = 0
    @State private var selectedIcon: IconType = .star
    
    @State private var aiInput: String = ""
    @State private var isParsing = false
    
    @FocusState private var isAIFocused: Bool
    
    // Icon selection
    let icons: [IconType] = IconType.allCases
    
    // Date Picker States
    @State private var showStartDatePicker = false
    @State private var showTargetDatePicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color(hex: "#F1F5F9"))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("新建倒计时")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.nearTextPrimary)
                
                Spacer()
                
                Button(action: saveCountdown) {
                    Text("保存")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 36)
                        .background(LinearGradient(gradient: Gradient(colors: [.nearPrimary, .nearPrimary.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .cornerRadius(10)
                        .shadow(color: .nearPrimary.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(name.isEmpty)
                .opacity(name.isEmpty ? 0.5 : 1)
            }
            .padding(24)
            .background(Color.white.opacity(0.8))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // AI Parse Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI 智能解析")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            TextField("例如：过年倒计时 / 今天下午3点有个会", text: $aiInput)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "#E2E8F0"), lineWidth: 1)
                                )
                                .focused($isAIFocused)
                                .onSubmit {
                                    parseAI()
                                }
                            
                            Button(action: parseAI) {
                                HStack {
                                    if isParsing {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: "sparkles")
                                    }
                                    Text("AI")
                                }
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .frame(height: 40)
                                .background(LinearGradient(gradient: Gradient(colors: [.nearPrimary, .blue]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .disabled(aiInput.isEmpty || isParsing)
                        }
                    }
                    
                    // Name
                    FormGroup(label: "事件名称") {
                        TextField("例如：项目上线", text: $name)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(12)
                            .background(Color(hex: "#F8FAFC"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(name.isEmpty ? Color(hex: "#6366F1") : Color(hex: "#E2E8F0"), lineWidth: 1)
                            )
                    }
                    
                    // Start Time (Custom Card)
                    FormGroup(label: "开始时间") {
                        DateCardView(date: $startDate, isExpanded: $showStartDatePicker, title: "Start Date")
                    }
                    
                    // Target Time (Custom Card)
                    FormGroup(label: "目标时间") {
                        DateCardView(date: $targetDate, isExpanded: $showTargetDatePicker, title: "Target Date")
                    }
                    
                    // Icons
                    FormGroup(label: "选择图标") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(icons, id: \.self) { icon in
                                    Button(action: { selectedIcon = icon }) {
                                        Image(systemName: icon.sfSymbol)
                                            .font(.system(size: 20))
                                            .foregroundColor(selectedIcon == icon ? Color(hex: "#6366F1") : .gray)
                                            .frame(width: 44, height: 44)
                                            .background(selectedIcon == icon ? Color(hex: "#EEF2FF") : Color(hex: "#F8FAFC"))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(selectedIcon == icon ? Color(hex: "#6366F1") : .clear, lineWidth: 2)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [.nearBackgroundStart, .nearBackgroundEnd]), startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(16)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isAIFocused = true
            }
        }
    }
    
    @State private var cancellables = Set<AnyCancellable>() 

    func parseAI() {
        isParsing = true
        
        aiService.parseCountdown(input: aiInput)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isParsing = false
                    if case .failure(let error) = completion {
                        print("AI Parse Error: \(error.localizedDescription)")
                    }
                },
                receiveValue: { event in
                    if let event = event {
                        withAnimation {
                            self.name = event.name
                            self.startDate = event.startDate
                            self.targetDate = event.targetDate
                            self.selectedIcon = event.icon
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func saveCountdown() {
        let newCountdown = CountdownEvent(
            id: UUID(),
            name: name,
            startDate: startDate,
            targetDate: targetDate,
            icon: selectedIcon,
            isPinned: false,
            order: 0
        )
        countdownManager.addCountdown(newCountdown)
        isPresented = false
    }
}

struct FormGroup<Content: View>: View {
    let label: String
    let content: Content
    
    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            
            content
        }
    }
}

struct DateCardView: View {
    @Binding var date: Date
    @Binding var isExpanded: Bool
    let title: String
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Card Header (Always Visible)
            Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateFormatter.string(from: date))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.nearTextPrimary)
                    }
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.system(size: 18))
                        .foregroundColor(.nearPrimary)
                        .padding(8)
                        .background(Color.nearPrimary.opacity(0.1))
                        .clipShape(Circle())
                }
                .padding(12)
                .background(Color.white)
            }
            .buttonStyle(.plain)
            
            // Expanded Content (Graphical Picker)
            if isExpanded {
                Divider()
                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(8)
                    .background(Color.white.opacity(0.95))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.nearTextSecondary.opacity(0.1), lineWidth: 1))
    }
}
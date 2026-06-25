import SwiftUI
import Combine

struct ChatMessage: Identifiable {
    let id = UUID().uuidString
    let role: Role
    let text: String
    var referencedCards: [CardIdentity]
    var dataPulls: [MarketChatDataPull]
    let timestamp: Date

    enum Role { case user, assistant }

    static func user(_ text: String) -> ChatMessage {
        ChatMessage(role: .user, text: text, referencedCards: [], dataPulls: [], timestamp: Date())
    }

    static func assistant(_ response: MarketChatResponse) -> ChatMessage {
        ChatMessage(role: .assistant, text: response.text, referencedCards: response.referencedCards, dataPulls: response.dataPulls, timestamp: Date())
    }

    static func welcome() -> ChatMessage {
        ChatMessage(
            role: .assistant,
            text: "Hey! I'm your CardIQ market analyst. Ask me anything about Pokémon card prices, trends, grading ROI, or your collection.\n\nTry: **\"What's trending?\"** or **\"Best cards to grade?\"**",
            referencedCards: [],
            dataPulls: [],
            timestamp: Date()
        )
    }
}

@Observable
@MainActor
final class MarketChatViewModel {
    var messages: [ChatMessage] = [.welcome()]
    var inputText: String = ""
    var isLoading: Bool = false

    private let chatService: any MarketChatService
    private let services: ServiceContainer

    init(services: ServiceContainer = .shared) {
        self.services = services
        self.chatService = services.marketChat
    }

    var quickPrompts: [String] {
        [
            "What's trending?",
            "Best cards to grade?",
            "Budget picks",
            "What's dropping?",
        ]
    }

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage.user(text)
        messages.append(userMessage)
        inputText = ""
        isLoading = true

        do {
            let context = MarketChatContext(
                recentCards: MockSeedData.cards,
                collectionCardIds: MockSeedData.sampleCollectionItems.map { $0.card.id }
            )
            let response = try await chatService.sendMessage(text, context: context)
            messages.append(.assistant(response))
        } catch {
            messages.append(ChatMessage(
                role: .assistant,
                text: "Sorry, I couldn't process that request. Please try again.",
                referencedCards: [],
                dataPulls: [],
                timestamp: Date()
            ))
        }

        isLoading = false
    }

    func sendQuickPrompt(_ prompt: String) async {
        inputText = prompt
        await send()
    }
}

struct MarketChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = MarketChatViewModel()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messagesList
                if viewModel.messages.count <= 1 {
                    quickPromptsBar
                }
                inputBar
            }
            .background(CIQColors.Fallback.backgroundPrimary)
            .navigationTitle("Market AI")
            .ciqInlineTitle()
            .ciqNavigationBarStyle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(CIQColors.Fallback.accentPrimary)
                }
            }
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: CIQSpacing.md) {
                    ForEach(viewModel.messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }

                    if viewModel.isLoading {
                        TypingIndicator()
                            .id("typing")
                    }
                }
                .padding(CIQSpacing.md)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    if viewModel.isLoading {
                        proxy.scrollTo("typing", anchor: .bottom)
                    } else if let last = viewModel.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isLoading) { _, loading in
                if loading {
                    withAnimation {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var quickPromptsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CIQSpacing.xs) {
                ForEach(viewModel.quickPrompts, id: \.self) { prompt in
                    Button {
                        Task { await viewModel.sendQuickPrompt(prompt) }
                    } label: {
                        Text(prompt)
                            .font(CIQFont.captionBold)
                            .foregroundStyle(CIQColors.Fallback.accentPrimary)
                            .padding(.horizontal, CIQSpacing.sm)
                            .padding(.vertical, CIQSpacing.xs)
                            .background(CIQColors.Fallback.accentPrimary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .padding(.horizontal, CIQSpacing.md)
            .padding(.vertical, CIQSpacing.xs)
        }
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().background(CIQColors.Fallback.border)

            HStack(spacing: CIQSpacing.sm) {
                TextField("Ask about the market...", text: $viewModel.inputText, axis: .vertical)
                    .font(CIQFont.body)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .onSubmit { Task { await viewModel.send() } }

                Button {
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading
                                ? CIQColors.Fallback.textTertiary
                                : CIQColors.Fallback.accentPrimary
                        )
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                .accessibilityLabel("Send message")
            }
            .padding(.horizontal, CIQSpacing.md)
            .padding(.vertical, CIQSpacing.sm)
            .background(CIQColors.Fallback.backgroundSecondary)
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: CIQSpacing.sm) {
            if message.role == .assistant {
                assistantAvatar
            }

            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: CIQSpacing.sm) {
                Text(LocalizedStringKey(message.text))
                    .font(CIQFont.body)
                    .foregroundStyle(message.role == .user ? .black : CIQColors.Fallback.textPrimary)
                    .padding(.horizontal, CIQSpacing.md)
                    .padding(.vertical, CIQSpacing.sm)
                    .background(
                        message.role == .user
                            ? CIQColors.Fallback.accentPrimary
                            : CIQColors.Fallback.backgroundCard
                    )
                    .clipShape(RoundedRectangle(cornerRadius: CIQRadius.lg))
                    .overlay {
                        if message.role == .assistant {
                            RoundedRectangle(cornerRadius: CIQRadius.lg)
                                .strokeBorder(CIQColors.Fallback.borderSubtle, lineWidth: 1)
                        }
                    }

                if !message.dataPulls.isEmpty {
                    dataPullsView(message.dataPulls)
                }

                if !message.referencedCards.isEmpty {
                    referencedCardsView(message.referencedCards)
                }
            }

            if message.role == .assistant { Spacer(minLength: 24) }
        }
    }

    private var assistantAvatar: some View {
        ZStack {
            Circle()
                .fill(CIQColors.Fallback.accentPrimary.opacity(0.15))
                .frame(width: 32, height: 32)
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CIQColors.Fallback.accentPrimary)
        }
    }

    private func dataPullsView(_ pulls: [MarketChatDataPull]) -> some View {
        VStack(spacing: CIQSpacing.xxs) {
            ForEach(pulls) { pull in
                HStack(spacing: CIQSpacing.sm) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(pull.cardName)
                            .font(CIQFont.captionBold)
                            .foregroundStyle(CIQColors.Fallback.textPrimary)
                        Text(pull.label)
                            .font(CIQFont.caption)
                            .foregroundStyle(CIQColors.Fallback.textTertiary)
                    }
                    Spacer()
                    Text(pull.value)
                        .font(CIQFont.mono)
                        .foregroundStyle(CIQColors.Fallback.textPrimary)
                    if let change = pull.changePercent {
                        Text(change >= 0 ? "+\(change.percentFormatted)" : change.percentFormatted)
                            .font(CIQFont.captionBold)
                            .foregroundStyle(change >= 0 ? CIQColors.Fallback.positive : CIQColors.Fallback.negative)
                    }
                }
                .padding(.horizontal, CIQSpacing.sm)
                .padding(.vertical, CIQSpacing.xs)
                .background(CIQColors.Fallback.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: CIQRadius.sm))
            }
        }
        .padding(.leading, CIQSpacing.xxs)
    }

    private func referencedCardsView(_ cards: [CardIdentity]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CIQSpacing.xs) {
                ForEach(cards) { card in
                    HStack(spacing: CIQSpacing.xxs) {
                        Image(systemName: "rectangle.portrait")
                            .font(.system(size: 10))
                            .foregroundStyle(CIQColors.Fallback.accentPrimary)
                        Text(card.name)
                            .font(CIQFont.caption)
                            .foregroundStyle(CIQColors.Fallback.textSecondary)
                    }
                    .padding(.horizontal, CIQSpacing.xs)
                    .padding(.vertical, CIQSpacing.xxxs)
                    .background(CIQColors.Fallback.backgroundTertiary)
                    .clipShape(Capsule())
                }
            }
            .padding(.leading, CIQSpacing.xxs)
        }
    }
}

struct TypingIndicator: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .top, spacing: CIQSpacing.sm) {
            ZStack {
                Circle()
                    .fill(CIQColors.Fallback.accentPrimary.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CIQColors.Fallback.accentPrimary)
            }

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(CIQColors.Fallback.textTertiary)
                        .frame(width: 8, height: 8)
                        .opacity(dotCount % 3 == i ? 1.0 : 0.3)
                }
            }
            .padding(.horizontal, CIQSpacing.md)
            .padding(.vertical, CIQSpacing.md)
            .background(CIQColors.Fallback.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: CIQRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: CIQRadius.lg)
                    .strokeBorder(CIQColors.Fallback.borderSubtle, lineWidth: 1)
            }

            Spacer()
        }
        .onReceive(timer) { _ in
            dotCount += 1
        }
    }
}

#Preview {
    MarketChatView()
}

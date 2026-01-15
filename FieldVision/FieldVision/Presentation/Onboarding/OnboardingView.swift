import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Document Your Work",
            subtitle: "Capture photos and videos with GPS tagging, voice notes, and automatic organization",
            imageName: "camera.viewfinder",
            color: .blue
        ),
        OnboardingPage(
            title: "Stay Organized",
            subtitle: "Pre-built templates for property inspections, construction, roofing, HVAC, and more",
            imageName: "folder.fill.badge.gearshape",
            color: .orange
        ),
        OnboardingPage(
            title: "Work Offline",
            subtitle: "All your photos sync automatically when you're back online. Never lose your work",
            imageName: "icloud.and.arrow.up",
            color: .green
        ),
        OnboardingPage(
            title: "Generate Reports",
            subtitle: "Create professional PDF reports with one tap. Share with clients instantly",
            imageName: "doc.richtext.fill",
            color: .purple
        ),
        OnboardingPage(
            title: "Team Collaboration",
            subtitle: "Invite team members, share projects, and keep everyone on the same page",
            imageName: "person.3.fill",
            color: .cyan
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)
            
            VStack(spacing: FVSpacing.lg) {
                PageIndicator(currentPage: currentPage, pageCount: pages.count)
                
                actionButton
            }
            .padding(.horizontal, FVSpacing.xl)
            .padding(.bottom, FVSpacing.xxl)
        }
        .background(FVColors.background)
    }
    
    private var actionButton: some View {
        Button {
            if currentPage < pages.count - 1 {
                withAnimation {
                    currentPage += 1
                }
            } else {
                completeOnboarding()
            }
        } label: {
            Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                .font(FVTypography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FVSpacing.md)
                .background(pages[currentPage].color)
                .cornerRadius(FVRadius.md)
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation {
            hasCompletedOnboarding = true
        }
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let imageName: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: FVSpacing.xl) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.15))
                    .frame(width: 200, height: 200)
                
                Circle()
                    .fill(page.color.opacity(0.25))
                    .frame(width: 150, height: 150)
                
                Image(systemName: page.imageName)
                    .font(.system(size: 64, weight: .medium))
                    .foregroundStyle(page.color)
            }
            
            VStack(spacing: FVSpacing.md) {
                Text(page.title)
                    .font(FVTypography.largeTitle)
                    .foregroundStyle(FVColors.label)
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(FVTypography.body)
                    .foregroundStyle(FVColors.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FVSpacing.lg)
            }
            
            Spacer()
            Spacer()
        }
        .padding()
    }
}

struct PageIndicator: View {
    let currentPage: Int
    let pageCount: Int
    
    var body: some View {
        HStack(spacing: FVSpacing.xs) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? FVColors.Fallback.primary : FVColors.tertiaryLabel)
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: currentPage)
            }
        }
    }
}

struct FeatureHighlightCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: FVSpacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.15))
                .cornerRadius(FVRadius.sm)
            
            VStack(alignment: .leading, spacing: FVSpacing.xxxs) {
                Text(title)
                    .font(FVTypography.headline)
                    .foregroundStyle(FVColors.label)
                
                Text(description)
                    .font(FVTypography.caption)
                    .foregroundStyle(FVColors.secondaryLabel)
            }
            
            Spacer()
        }
        .padding(FVSpacing.md)
        .background(FVColors.secondaryBackground)
        .cornerRadius(FVRadius.md)
    }
}

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let features: [(icon: String, title: String, description: String, color: Color)] = [
        ("magnifyingglass", "Global Search", "Search across all projects, photos, and notes instantly", .blue),
        ("doc.richtext.fill", "PDF Reports", "Generate professional reports with customizable layouts", .purple),
        ("rectangle.grid.2x2.fill", "Project Templates", "Start projects faster with industry-specific templates", .orange),
        ("person.3.fill", "Team Invites", "Invite collaborators via email with role-based permissions", .green),
        ("mic.fill", "Voice Notes", "Record voice memos with automatic AI transcription", .red)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FVSpacing.lg) {
                    headerSection
                    
                    ForEach(features.indices, id: \.self) { index in
                        FeatureHighlightCard(
                            icon: features[index].icon,
                            title: features[index].title,
                            description: features[index].description,
                            color: features[index].color
                        )
                    }
                }
                .padding(FVSpacing.lg)
            }
            .navigationTitle("What's New")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: FVSpacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(FVColors.Fallback.primary)
            
            Text("New Features")
                .font(FVTypography.title)
                .foregroundStyle(FVColors.label)
            
            Text("Here's what we've been working on")
                .font(FVTypography.subheadline)
                .foregroundStyle(FVColors.secondaryLabel)
        }
        .padding(.vertical, FVSpacing.lg)
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}

#Preview("What's New") {
    WhatsNewView()
}

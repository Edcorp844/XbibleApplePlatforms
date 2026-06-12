
import SwiftUI

struct ToolsView: View {
    @ObservedObject var audioViewModel: AudioBibleViewModel
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Section Header
                Text("AUDIO")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                // Navigation Action Rows
                VStack(spacing: 0) {
                    // 1. Audio Bible Row + Quick Store Link
                    NavigationLink(destination: AudioBibleView(viewModel: audioViewModel)) {
                        HStack {
                            Text("Audio Bible")
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineLimit(1) // Ensures strict text clipping if title exceeds length
                            
                            Spacer()
                            
                            // Emergency inline shortcut to the store
                            NavigationLink(destination: AudioStoreView()) {
                                Text("Get Store")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain) // Prevents the outer row tap from firing this button
                        }
                        .padding()
                        //.background(Color(.selection).opacity(0.05))
                    }
                    
                    Divider()
                        .padding(.leading)
                    
                    // 2. Direct Audio Store Row
                    NavigationLink(destination: AudioStoreView()) {
                        HStack {
                            Text("Audio Store")
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                       // .background(Color(.unemphasizedSelectedTextBackgroundColor).opacity(0.05))
                    }
                }
                //.background(Color(.windowBackgroundColor))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Tools")
        }
    }
}

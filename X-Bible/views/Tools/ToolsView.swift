
import SwiftUI

struct ToolsView: View {
    @ObservedObject var audioViewModel: AudioBibleViewModel
    
    var body: some View {
        NavigationStack {
            List {
                // Section layout container handles headers and rows natively
                Section {
                    // Row 1: Primary Audio Bible link
                    HStack {
                        NavigationLink("Audio Bible", destination: AudioBibleView(viewModel: audioViewModel))
                            .foregroundColor(.primary)
                    }
                    
                    // Row 2: Direct Audio Store link
                    NavigationLink(destination: AudioStoreView()) {
                        Text("Audio Store")
                            .foregroundColor(.primary)
                    }
                } header: {
                    Text("AUDIO")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped) // Delivers standard rounded card formatting automatically
            #endif
            .navigationTitle("Tools")
        }
    }
}

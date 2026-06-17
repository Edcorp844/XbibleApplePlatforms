//  AudioBibleView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/29/26.
//

import SwiftUI
import XbibleEngine

struct AudioBibleView: View {
    @State private var showLibrarySheet = false
    @ObservedObject var viewModel: AudioBibleViewModel
    
    init(viewModel: AudioBibleViewModel) {
        self.viewModel = viewModel
    }
    
   
    var body: some View {
#if os(macOS)
        AudioBibleViewMacOS(viewModel: viewModel)
#else
        AudiobibleViewIos(viewModel: viewModel)
#endif
    }
    

}


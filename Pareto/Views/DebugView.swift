//
//  DebugView.swift
//  Pareto Security
//
//  Created by Janez Troha on 10/06/2022.
//

import SwiftUI

struct DebugView: View {
    @State private var data = ""
    var body: some View {
        Text(data).fixedSize(horizontal: false, vertical: true).frame(width: 640, height: 480).onAppear {}
    }
}

struct DebugView_Previews: PreviewProvider {
    static var previews: some View {
        DebugView()
    }
}

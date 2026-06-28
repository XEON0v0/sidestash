import SwiftUI

struct FileGridItem: View {
    @EnvironmentObject var store: StashStore
    let item: StashItem

    var body: some View {
        DraggableFileItem(item: item, store: store)
            .frame(height: FileStashSidebarStyle.rowHeight)
    }
}

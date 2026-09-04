import SwiftUI

struct MomentsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selected: BrumMoment?
    private let columns = [GridItem(.adaptive(minimum: 155), spacing: 12)]
    var body: some View {
        ScrollView {
            if store.moments.isEmpty {
                VStack(spacing: 12) { Image(systemName: "photo.on.rectangle.angled").font(.largeTitle).foregroundStyle(BrumTheme.muted); Text("Sua galeria está vazia").font(.headline); Text("Durante uma sessão, use o BRUMCOMPANION para capturar um momento.").font(.subheadline).foregroundStyle(BrumTheme.muted).multilineTextAlignment(.center) }.padding(50)
            } else {
                LazyVGrid(columns: columns, spacing: 18) { ForEach(store.moments) { moment in MomentTile(moment: moment).onTapGesture { selected = moment } } }.padding(16)
            }
        }.navigationTitle("BRUMMOMENTS").background(BrumTheme.background.ignoresSafeArea()).sheet(item: $selected) { MomentEditor(moment: $0) }
    }
}

struct MomentTile: View {
    @EnvironmentObject private var store: AppStore
    let moment: BrumMoment
    @State private var image: UIImage?
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack { BrumTheme.surface; if let image { Image(uiImage: image).resizable().scaledToFill() } }.aspectRatio(16.0/9.0, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 10)).clipped()
            Text(moment.gameTitle).font(.subheadline.bold()).foregroundStyle(BrumTheme.text).lineLimit(1)
            Text(moment.location.isEmpty ? moment.category : moment.location).font(.caption2.bold()).foregroundStyle(BrumTheme.primary).lineLimit(1)
        }.task { image = await store.momentImage(moment) }
    }
}

struct MomentEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var value: BrumMoment
    @State private var image: UIImage?
    init(moment: BrumMoment) { _value = State(initialValue: moment) }
    var body: some View {
        NavigationStack {
            Form {
                if let image { Image(uiImage: image).resizable().scaledToFit().listRowInsets(EdgeInsets()) }
                Section("Jogo") { Text(value.gameTitle) }
                Section("Localização para lembrar") { TextField("Ex.: Entrada da torre norte", text: $value.location) }
                Section("Anotação") { TextEditor(text: $value.note).frame(minHeight: 100) }
                Section("Categoria") { TextField("MOMENTO", text: $value.category); Toggle("Favorito", isOn: $value.favorite).tint(BrumTheme.primary) }
                Button("REMOVER CAPTURA", role: .destructive) { Task { await store.removeMoment(value); dismiss() } }
            }.navigationTitle("BRUMMOMENT").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Salvar") { Task { await store.updateMoment(value); dismiss() } } } }.task { image = await store.momentImage(value) }
        }
    }
}

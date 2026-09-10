//
//  SourcesPrefsViewController.swift
//  Subler
//

import Cocoa

/// A text field that also accepts a plain-text drag as a way of setting
/// its content -- used by the field-mapping rows below so a field found by
/// "Test Connection" can be dragged in rather than typed. Dropping still
/// goes through `onDrop` rather than relying on NSTextField's own built-in
/// text-drag handling, so the dropped text always replaces the field's
/// entire contents (matching "assign this JSON path to this row") instead
/// of inserting at a caret position.
private final class DroppableTextField: NSTextField {
    var onDrop: ((String) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.string])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.string])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return sender.draggingPasteboard.canReadObject(forClasses: [NSString.self], options: nil) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let string = sender.draggingPasteboard.string(forType: .string) else { return false }
        stringValue = string
        onDrop?(string)
        return true
    }
}

/// Preferences pane for user-configured additional metadata sources (see
/// CustomMetadataSource / CustomSourceService). A source is entirely data
/// -- a name, a search URL template, where results live in the JSON
/// response, how the API key is attached, and a field-by-field mapping
/// from the response to Subler's own metadata annotations -- so adding one
/// never needs a code change.
///
/// This view controller owns only the list of configured sources and its
/// add/remove buttons. A source's actual settings -- name, URL, auth, field
/// mappings, Test/Retrieve -- live in their own window (see
/// CustomSourceDetailWindowController below), opened by clicking "+" (for a
/// brand-new source) or double-clicking a row (to edit an existing one),
/// rather than docked inline next to the list. That mapping section is
/// substantial (one row per mappable annotation, plus a Discovered Fields
/// list beside it), and a dedicated, resizable window gives it real room
/// instead of squeezing it into a fixed-height split view.
final class SourcesPrefsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    private var sources: [CustomMetadataSource]
    private var selectedIndex: Int?

    private var tableView: NSTableView!
    private var removeButton: NSButton!

    /// The single reusable detail window -- reconfigured in place (see
    /// openDetailWindow) if it's already open when "+" or a double-click
    /// asks for a different source, rather than allowing several of these
    /// windows to pile up at once.
    private var detailWindowController: CustomSourceDetailWindowController?

    init() {
        self.sources = MetadataPrefs.additionalMetadataSources
        super.init(nibName: nil, bundle: nil)
        self.title = NSLocalizedString("Sources", comment: "")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 500))

        let headerLabel = NSTextField(labelWithString: NSLocalizedString("Additional Metadata Sources", comment: ""))
        headerLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false

        let descriptionLabel = NSTextField(wrappingLabelWithString: NSLocalizedString("Add a metadata source by describing its search API: where to search, where the results are in its response, and which response fields map to which annotations. No coding required. Double-click a source below to edit it, or click + to add a new one.", comment: ""))
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.preferredMaxLayoutWidth = 660

        let listPane = makeListPane()

        container.addSubview(headerLabel)
        container.addSubview(descriptionLabel)
        container.addSubview(listPane)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            headerLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            headerLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),

            descriptionLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 6),
            descriptionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            // No fixed height here (unlike the old split view) -- this pane
            // simply fills whatever's left below the description, so the
            // list gets taller now that it isn't sharing this pane with an
            // inline detail form anymore.
            listPane.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 12),
            listPane.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            listPane.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            listPane.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20)
        ])

        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.reloadData()
        updateRemoveButtonState()
    }

    // MARK: - List pane

    private func makeListPane() -> NSView {
        let pane = NSView()
        pane.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        let table = NSTableView()
        table.usesAlternatingRowBackgroundColors = true
        table.allowsMultipleSelection = false
        table.dataSource = self
        table.delegate = self
        table.headerView = nil
        table.rowSizeStyle = .default
        table.target = self
        table.doubleAction = #selector(sourceRowDoubleClicked(_:))

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.title = NSLocalizedString("Name", comment: "")
        table.addTableColumn(column)

        scrollView.documentView = table
        self.tableView = table

        // Sized and styled to match the +/- buttons on the Sets tab
        // (PresetPrefsViewController.xib: rounded bezel, image-only, 44x32)
        // rather than the smaller toolbar-style square button, so the two
        // preferences panes feel like one app.
        let addButton = NSButton(image: NSImage(named: NSImage.addTemplateName) ?? NSImage(),
                                  target: self, action: #selector(addSource(_:)))
        addButton.bezelStyle = .rounded
        addButton.imagePosition = .imageOnly
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.toolTip = NSLocalizedString("Add a new metadata source", comment: "")

        let removeButton = NSButton(image: NSImage(named: NSImage.removeTemplateName) ?? NSImage(),
                                     target: self, action: #selector(removeSource(_:)))
        removeButton.bezelStyle = .rounded
        removeButton.imagePosition = .imageOnly
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.toolTip = NSLocalizedString("Remove the selected metadata source", comment: "")
        self.removeButton = removeButton

        pane.addSubview(scrollView)
        pane.addSubview(addButton)
        pane.addSubview(removeButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: pane.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: pane.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: pane.trailingAnchor),

            addButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 4),
            addButton.leadingAnchor.constraint(equalTo: pane.leadingAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 44),
            addButton.heightAnchor.constraint(equalToConstant: 32),

            removeButton.topAnchor.constraint(equalTo: addButton.topAnchor),
            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 1),
            removeButton.widthAnchor.constraint(equalToConstant: 44),
            removeButton.heightAnchor.constraint(equalToConstant: 32),

            pane.bottomAnchor.constraint(equalTo: addButton.bottomAnchor)
        ])

        return pane
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return sources.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard sources.indices.contains(row) else { return nil }

        let identifier = NSUserInterfaceItemIdentifier("nameCell")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            let newCell = NSTableCellView()
            let textField = NSTextField(labelWithString: "")
            textField.lineBreakMode = .byTruncatingTail
            textField.translatesAutoresizingMaskIntoConstraints = false
            newCell.addSubview(textField)
            newCell.textField = textField
            newCell.identifier = identifier
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: newCell.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: newCell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: newCell.centerYAnchor)
            ])
            cell = newCell
        }

        let source = sources[row]
        cell.textField?.stringValue = source.name.isEmpty ? NSLocalizedString("Untitled Source", comment: "") : source.name
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        selectedIndex = row >= 0 ? row : nil
        updateRemoveButtonState()
    }

    private func updateRemoveButtonState() {
        removeButton.isEnabled = tableView.selectedRow != -1
    }

    @objc private func addSource(_ sender: Any) {
        sources.append(CustomMetadataSource(name: NSLocalizedString("New Source", comment: "")))
        save()
        tableView.reloadData()
        let newIndex = sources.count - 1
        tableView.selectRowIndexes(IndexSet(integer: newIndex), byExtendingSelection: false)
        openDetailWindow(for: newIndex)
    }

    @objc private func removeSource(_ sender: Any) {
        guard let index = selectedIndex, sources.indices.contains(index) else { return }
        sources.remove(at: index)
        save()
        tableView.reloadData()
        selectedIndex = nil
        updateRemoveButtonState()

        // The removed row might be the one the detail window is showing
        // (close it -- there's nothing left to edit), or an earlier one
        // (everything after it just shifted down one, so the open window
        // needs to keep pointing at the same source, not the row that took
        // its old spot).
        if let controller = detailWindowController {
            if controller.editingIndex == index {
                controller.close()
            } else if controller.editingIndex > index {
                controller.editingIndex -= 1
            }
        }
    }

    private func save() {
        MetadataPrefs.additionalMetadataSources = sources
    }

    // MARK: - Detail window

    @objc private func sourceRowDoubleClicked(_ sender: Any) {
        let row = tableView.clickedRow
        guard sources.indices.contains(row) else { return }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        openDetailWindow(for: row)
    }

    private func openDetailWindow(for index: Int) {
        guard sources.indices.contains(index) else { return }
        if let existing = detailWindowController {
            existing.reconfigure(index: index, source: sources[index])
            existing.window?.makeKeyAndOrderFront(nil)
        } else {
            let controller = CustomSourceDetailWindowController(index: index, source: sources[index], delegate: self)
            self.detailWindowController = controller
            controller.window?.center()
            controller.window?.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension SourcesPrefsViewController: CustomSourceDetailWindowDelegate {

    func customSourceDetail(_ controller: CustomSourceDetailWindowController, didUpdate source: CustomMetadataSource, at index: Int) {
        guard sources.indices.contains(index) else { return }
        sources[index] = source
        save()
        tableView.reloadData()
    }

    func customSourceDetailWindowWillClose(_ controller: CustomSourceDetailWindowController) {
        if detailWindowController === controller {
            detailWindowController = nil
        }
    }
}

// MARK: - Detail window controller

/// Notifies the sources list of live edits made in the detail window (so
/// the list can persist them and reflect a renamed source immediately) and
/// of the window closing (so the list can drop its reference and let a
/// later "+"/double-click build a fresh one).
protocol CustomSourceDetailWindowDelegate: AnyObject {
    func customSourceDetail(_ controller: CustomSourceDetailWindowController, didUpdate source: CustomMetadataSource, at index: Int)
    func customSourceDetailWindowWillClose(_ controller: CustomSourceDetailWindowController)
}

/// Hosts a single CustomSourceDetailViewController in its own resizable
/// window -- opened by SourcesPrefsViewController for either a
/// brand-new source (right after "+" appends it) or an existing one
/// (double-click). Editing is live, same as the old inline pane: every
/// field commit round-trips through the delegate immediately, there's no
/// separate Save/Cancel step, and closing the window (any way -- the
/// close button, Cmd-W) is always safe.
final class CustomSourceDetailWindowController: NSWindowController, NSWindowDelegate {

    private let contentController: CustomSourceDetailViewController
    private weak var delegate: CustomSourceDetailWindowDelegate?

    /// Which row in the sources list this window is currently editing.
    /// Kept up to date by the list controller when an earlier row is
    /// removed out from under an open window (see
    /// SourcesPrefsViewController.removeSource).
    var editingIndex: Int

    init(index: Int, source: CustomMetadataSource, delegate: CustomSourceDetailWindowDelegate) {
        self.editingIndex = index
        self.delegate = delegate

        let contentController = CustomSourceDetailViewController(source: source)
        self.contentController = contentController

        let window = NSWindow(contentViewController: contentController)
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 700, height: 640))
        window.minSize = NSSize(width: 620, height: 480)
        window.title = CustomSourceDetailWindowController.title(for: source)

        super.init(window: window)

        window.delegate = self
        contentController.onChange = { [weak self] updated in
            guard let self = self else { return }
            window.title = CustomSourceDetailWindowController.title(for: updated)
            self.delegate?.customSourceDetail(self, didUpdate: updated, at: self.editingIndex)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Repoints an already-open window at a different source -- used when
    /// "+" or a double-click asks for one while this window is still open,
    /// rather than letting several of these windows pile up at once.
    func reconfigure(index: Int, source: CustomMetadataSource) {
        editingIndex = index
        contentController.setSource(source)
        window?.title = CustomSourceDetailWindowController.title(for: source)
    }

    private static func title(for source: CustomMetadataSource) -> String {
        return source.name.trimmingCharacters(in: .whitespaces).isEmpty ? NSLocalizedString("New Source", comment: "") : source.name
    }

    func windowWillClose(_ notification: Notification) {
        delegate?.customSourceDetailWindowWillClose(self)
    }
}

/// A plain container whose origin is the top-left rather than AppKit's
/// default bottom-left. Used as the detail form's scroll-view document
/// view (see makeDetailPane) so that when the window is taller than the
/// form actually needs, the form sits at the top with the extra space
/// below it -- the natural place for a growing window's slack to go --
/// instead of AppKit's default of anchoring a document view shorter than
/// its scroll view to the bottom.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - Detail view controller

/// One source's settings: name, applies-to, search request, authentication,
/// and field mapping (with Test/Retrieve and Discovered Fields) -- exactly
/// what used to be the inline detail pane next to the sources list, now
/// standalone in its own window (see CustomSourceDetailWindowController).
/// Editing is live: every field commit calls `onChange` immediately with
/// the updated source, same as the old pane's direct writes into
/// MetadataPrefs.additionalMetadataSources.
final class CustomSourceDetailViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {

    private var source: CustomMetadataSource
    var onChange: ((CustomMetadataSource) -> Void)?

    private var detailContainer: NSView!

    /// Test Connection / field discovery state for this source. Rebuilt
    /// fresh whenever the form is rebuilt; not persisted -- it's a
    /// scratchpad for filling in field mappings, not part of
    /// CustomMetadataSource itself.
    private var testQueryField: NSTextField!
    private var testButton: NSButton!
    private var statusLabel: NSTextField!
    private var copyStatusButton: NSButton!
    private var discoveredFieldsTable: NSTableView!
    private var discoveredFields: [DiscoveredField] = []

    /// The field-mapping list itself, plus its own +/- buttons (styled and
    /// sized like the Sources list's) for adding/removing which fields a
    /// source maps at all. Rebuilt fresh in rebuildDetail, same as the
    /// other detail-pane controls.
    ///
    /// "+" is an NSPopUpButton (pullsDown, "NSAddTemplate" face) rather
    /// than a plain button with a custom popover -- this matches Subler's
    /// own field picker exactly (MovieViewController's tagsPopUp, the "+"
    /// below the main metadata table): one flat menu of every mappable
    /// field plus a couple of "add a whole set" shortcuts at the top,
    /// single click to add, no separate Add/Cancel step. Its menu is
    /// static (built once in makeDetailPane) since -- unlike the old
    /// popover -- it no longer greys out already-mapped fields: clicking
    /// one that's already in the list just reveals its existing row,
    /// exactly like addTag(_:) does for the main table.
    private var mappingTableView: NSTableView!
    private var addMappingButton: NSPopUpButton!
    private var removeMappingButton: NSButton!

    /// Bumped on every Test Connection click and every time the form is
    /// rebuilt for a new source; a completion or timeout callback that
    /// doesn't match the current generation is stale and is ignored
    /// instead of touching the UI.
    private var testGeneration = 0

    /// The live mapping-row text fields for this source, keyed by which
    /// annotation they map, so a best-guess or a drop can update a row's
    /// displayed text without rebuilding the whole detail form (which
    /// would also throw away whatever the user just typed into the test
    /// query field).
    private var mappingFields: [MetadataResult.Key: NSTextField] = [:]

    /// The Artwork URL Path field, kept around the same way mappingFields
    /// are -- so a best-guess fill-in can update its displayed text
    /// without rebuilding the whole detail form. Artwork isn't a
    /// MetadataResult.Key mapping (it's its own CustomMetadataSource
    /// property), so it can't live in mappingFields alongside those.
    private var artworkPathField: NSTextField?

    /// The API Key row keeps a masked field and a plain one stacked in the
    /// same spot, toggled by the reveal button -- a masked-only field made
    /// it impossible to visually confirm the key matches what actually
    /// worked outside the app (e.g. in a curl test), which is exactly the
    /// question that matters when a source keeps failing to authenticate.
    private var apiKeySecureField: NSSecureTextField!
    private var apiKeyPlainField: NSTextField!
    private var apiKeyRevealButton: NSButton!

    /// Tags for the detail form's fixed, one-of-a-kind text fields.
    /// Field-mapping rows are tagged starting at mappingTagOffset instead,
    /// as mappingTagOffset + the row's index into this source's own
    /// visibleFields array, since there's one row per visible field rather
    /// than one overall.
    private enum FieldTag: Int {
        case name = 0
        case urlTemplate = 1
        case resultsPath = 2
        case authName = 3
        case apiKey = 4
        case artworkPath = 5
    }
    private let mappingTagOffset = 1000

    /// Height given to the field-mapping table and the Discovered Fields
    /// table, side by side -- a fixed value (rather than tied to a sibling
    /// list's height, as when this was an inline pane next to the sources
    /// list) since this window has no such sibling anymore. The window
    /// itself is resizable and everything above sits in its own scroll
    /// view, so this is just a comfortable default, not a hard limit on
    /// how many mapped fields are usable.
    private let fieldTablesHeight: CGFloat = 280

    init(source: CustomMetadataSource) {
        self.source = source
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Repoints this same view controller at a different source, for when
    /// the detail window is reused rather than recreated (see
    /// CustomSourceDetailWindowController.reconfigure).
    func setSource(_ newSource: CustomMetadataSource) {
        source = newSource
        if isViewLoaded {
            rebuildDetail()
        }
    }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 640))
        self.view = container
        // The actual content is a single scrollable form -- see
        // rebuildDetail -- built the same way the old inline detail pane
        // was, just filling this window's whole content view instead of
        // sharing a split view with the sources list.
        let pane = makeDetailPane()
        pane.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(pane)
        NSLayoutConstraint.activate([
            pane.topAnchor.constraint(equalTo: container.topAnchor),
            pane.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pane.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            pane.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        rebuildDetail()
    }

    private func update(_ mutate: (inout CustomMetadataSource) -> Void) {
        mutate(&source)
        onChange?(source)
    }

    // MARK: - Detail pane

    private func makeDetailPane() -> NSView {
        let pane = NSView()
        pane.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let container = FlippedView()
        container.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = container

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            container.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            container.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])

        self.detailContainer = container

        // The field-mapping list's own +/- buttons live here, outside the
        // scrollable form, rather than inline underneath the mapping table
        // -- built once rather than rebuilt with the rest of the form on
        // every rebuild. Pinned to this pane's own bottom edge.
        // A pulldown NSPopUpButton with a "+" face, exactly like Subler's
        // own field-adding control below the main metadata table
        // (MovieViewController's tagsPopUp): one flat menu, click a field
        // to add it, no separate popover/Add/Cancel step. Static content,
        // so it's built once here rather than per rebuild -- see
        // appendMappingFieldMenuItems.
        let addButton = NSPopUpButton(frame: .zero, pullsDown: true)
        addButton.bezelStyle = .rounded
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.toolTip = NSLocalizedString("Add a field to map", comment: "")
        if let menu = addButton.menu {
            let faceItem = NSMenuItem()
            faceItem.image = NSImage(named: NSImage.addTemplateName)
            faceItem.isHidden = true
            menu.addItem(faceItem)
            appendMappingFieldMenuItems(to: menu)
        }
        self.addMappingButton = addButton

        let removeButton = NSButton(image: NSImage(named: NSImage.removeTemplateName) ?? NSImage(),
                                     target: self, action: #selector(removeMappingField(_:)))
        removeButton.bezelStyle = .rounded
        removeButton.imagePosition = .imageOnly
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.toolTip = NSLocalizedString("Remove the selected field mapping", comment: "")
        self.removeMappingButton = removeButton

        pane.addSubview(scrollView)
        pane.addSubview(addButton)
        pane.addSubview(removeButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: pane.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: pane.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: pane.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -4),

            // +12 to match the mapping table's own left edge -- the
            // scrollable form inside this pane insets its content 12pt
            // from detailContainer's (and so this pane's) leading edge
            // (see rebuildDetail's stack.leadingAnchor constraint), so
            // lining this button up with the pane itself would leave it
            // sitting 12pt further left than the field-mapping frame
            // above it.
            addButton.leadingAnchor.constraint(equalTo: pane.leadingAnchor, constant: 12),
            addButton.widthAnchor.constraint(equalToConstant: 44),
            addButton.heightAnchor.constraint(equalToConstant: 32),

            removeButton.topAnchor.constraint(equalTo: addButton.topAnchor),
            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 1),
            removeButton.widthAnchor.constraint(equalToConstant: 44),
            removeButton.heightAnchor.constraint(equalToConstant: 32),

            pane.bottomAnchor.constraint(equalTo: addButton.bottomAnchor)
        ])

        updateRemoveMappingButtonState()
        return pane
    }

    private func rebuildDetail() {
        detailContainer.subviews.forEach { $0.removeFromSuperview() }
        discoveredFields = []
        mappingFields = [:]
        artworkPathField = nil
        mappingTableView = nil
        // Invalidates any Test Connection still in flight from before this
        // rebuild -- its completion/timeout callback checks this and will
        // now no-op instead of writing into a form that's just been torn
        // down and rebuilt.
        testGeneration += 1

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(makeTextRow(label: NSLocalizedString("Name", comment: ""), value: source.name, tag: FieldTag.name.rawValue))
        stack.addArrangedSubview(makeMediaTypesRow(source: source))

        stack.addArrangedSubview(makeSectionLabel(NSLocalizedString("Search Request", comment: "")))
        stack.addArrangedSubview(makeTextRow(label: NSLocalizedString("Search URL", comment: ""),
                                              value: source.searchURLTemplate, tag: FieldTag.urlTemplate.rawValue,
                                              placeholder: "https://api.example.com/search?q={query}",
                                              help: NSLocalizedString("\u{201c}{query}\u{201d} is replaced with the URL-encoded search text.", comment: ""),
                                              stretchesToFillWidth: true))
        stack.addArrangedSubview(makeTextRow(label: NSLocalizedString("Results Path", comment: ""),
                                              value: source.resultsPath, tag: FieldTag.resultsPath.rawValue,
                                              placeholder: "results",
                                              help: NSLocalizedString("JSON path to the array of matches in the response. Leave blank if the response itself is that array.", comment: ""),
                                              stretchesToFillWidth: true))

        stack.addArrangedSubview(makeSectionLabel(NSLocalizedString("Authentication", comment: "")))
        stack.addArrangedSubview(makeAuthRow(source: source))
        stack.addArrangedSubview(makeAPIKeyRow(source: source))

        stack.addArrangedSubview(makeSectionLabel(NSLocalizedString("Field Mapping", comment: "")))
        stack.addArrangedSubview(makeTextRow(label: nil,
                                              value: "",
                                              tag: -1,
                                              disabled: true,
                                              help: NSLocalizedString("JSON path (relative to each result) for each annotation below. Leave a field blank to skip it.", comment: "")))
        stack.addArrangedSubview(makeDiscoverRow())
        stack.addArrangedSubview(makeFieldMappingSplit(source: source))

        detailContainer.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: detailContainer.topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: detailContainer.bottomAnchor, constant: -12)
        ])

        addMappingButton?.isEnabled = true
        updateRemoveMappingButtonState()
        // Belt-and-suspenders: makeMappingTableColumn's freshly-created
        // table should pick up its rows the moment it's laid out, but
        // forcing a reload here removes any doubt -- a table that
        // ends up rendering fewer rows than the model actually has would
        // look exactly like "removing one item removed everything".
        mappingTableView?.reloadData()
    }

    private func makeSectionLabel(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize)
        return label
    }

    /// Pins `row`'s trailing edge to the form's own trailing edge -- a
    /// required upper bound (so it can never push past the window, even
    /// at the window's minimum size) plus a high-but-not-required
    /// preference to actually reach it, so the row grows to use whatever
    /// width the window currently has rather than only ever sitting at
    /// its content's natural minimum size.
    private func stretchRowToFillDetailWidth(_ row: NSView) {
        row.trailingAnchor.constraint(lessThanOrEqualTo: detailContainer.trailingAnchor, constant: -12).isActive = true
        let preferredWidth = row.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor, constant: -12)
        preferredWidth.priority = .defaultHigh
        preferredWidth.isActive = true
    }

    /// A label + text field row, with optional help text on the line
    /// below. Pass `label: nil, disabled: true` for a help-text-only row
    /// (used as the intro line above the field-mapping list). Pass
    /// `droppable: true` to accept a dragged JSON path (from the Discovered
    /// Fields table) as well as typed input; `fieldCreated` hands back the
    /// text field itself, so a caller that needs to update it later (a
    /// best-guess fill-in) doesn't have to rebuild the whole form.
    ///
    /// `fieldWidth` is a *minimum*, not a fixed size: pass
    /// `stretchesToFillWidth: true` for a field whose value is worth
    /// seeing more of when there's room for it (a URL, a JSON path) and
    /// this row grows to use the window's full width, handing all of the
    /// resulting slack to the field itself (the label stays pinned at
    /// 130) -- so widening the window actually shows more of a long value
    /// instead of just adding blank space to its right.
    private func makeTextRow(label: String?, value: String, tag: Int, placeholder: String = "",
                              secure: Bool = false, disabled: Bool = false, help: String? = nil,
                              fieldWidth: CGFloat = 400, stretchesToFillWidth: Bool = false, droppable: Bool = false,
                              fieldCreated: ((NSTextField) -> Void)? = nil) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 2
        container.translatesAutoresizingMaskIntoConstraints = false

        if disabled == false {
            let labelField = NSTextField(labelWithString: label ?? "")
            labelField.alignment = .left
            labelField.translatesAutoresizingMaskIntoConstraints = false
            labelField.widthAnchor.constraint(equalToConstant: 130).isActive = true

            let textField: NSTextField
            if droppable {
                let dropField = DroppableTextField()
                dropField.onDrop = { [weak self] droppedValue in
                    self?.commitDroppedValue(tag: tag, value: droppedValue)
                }
                textField = dropField
            } else {
                textField = secure ? NSSecureTextField() : NSTextField()
            }
            textField.stringValue = value
            textField.placeholderString = placeholder
            textField.tag = tag
            textField.delegate = self
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.widthAnchor.constraint(greaterThanOrEqualToConstant: fieldWidth).isActive = true

            let row = NSStackView(views: [labelField, textField])
            row.orientation = .horizontal
            row.alignment = .firstBaseline
            row.distribution = .fill
            row.spacing = 8
            container.addArrangedSubview(row)

            if stretchesToFillWidth {
                stretchRowToFillDetailWidth(row)
            }

            fieldCreated?(textField)
        }

        if let help = help {
            let helpField = NSTextField(wrappingLabelWithString: help)
            helpField.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize - 1)
            helpField.textColor = .tertiaryLabelColor
            helpField.preferredMaxLayoutWidth = 460
            helpField.translatesAutoresizingMaskIntoConstraints = false
            container.addArrangedSubview(helpField)
        }

        return container
    }

    /// The sample-search-term field, "Test / Retrieve" button, and status
    /// line above the field-mapping split. Named "Test / Retrieve" rather
    /// than just "Test Connection" since it does both at once: it
    /// exercises the source's search URL/auth *and* is how field values
    /// get retrieved for the Discovered Fields list on the right.
    private func makeDiscoverRow() -> NSView {
        let labelField = NSTextField(labelWithString: NSLocalizedString("Sample Search Term", comment: ""))
        labelField.translatesAutoresizingMaskIntoConstraints = false
        labelField.widthAnchor.constraint(equalToConstant: 130).isActive = true

        let queryField = NSTextField()
        queryField.placeholderString = NSLocalizedString("e.g. Inception", comment: "")
        queryField.translatesAutoresizingMaskIntoConstraints = false
        queryField.widthAnchor.constraint(equalToConstant: 400).isActive = true
        self.testQueryField = queryField

        let button = NSButton(title: NSLocalizedString("Test / Retrieve", comment: ""), target: self, action: #selector(testConnection(_:)))
        button.bezelStyle = .rounded
        self.testButton = button

        // .centerY, not .firstBaseline -- a plain text field and a
        // .rounded-bezel push button have different internal baseline
        // metrics, so lining them up by baseline leaves the button (and the
        // label's text next to it) sitting visibly higher than the entry
        // field. Centering the whole row on the entry field's own height is
        // what actually reads as aligned, and matches how the label's
        // "prompt" text lines up with its field elsewhere in Subler.
        let row = NSStackView(views: [labelField, queryField, button])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8

        let status = NSTextField(wrappingLabelWithString: "")
        status.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize - 1)
        status.textColor = .secondaryLabelColor
        status.preferredMaxLayoutWidth = 380
        status.translatesAutoresizingMaskIntoConstraints = false
        // Selectable (without being editable) so the message -- an HTTP
        // status, a server error body, an auth hint -- can be selected and
        // copied normally, on top of the explicit Copy button below.
        status.isSelectable = true
        self.statusLabel = status

        let copyStatusButton = NSButton(title: "", target: self, action: #selector(copyStatusMessage(_:)))
        copyStatusButton.bezelStyle = .smallSquare
        copyStatusButton.isBordered = false
        copyStatusButton.translatesAutoresizingMaskIntoConstraints = false
        copyStatusButton.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize - 1)
        copyStatusButton.toolTip = NSLocalizedString("Copy this message to the clipboard.", comment: "")
        NSLayoutConstraint.activate([
            copyStatusButton.widthAnchor.constraint(equalToConstant: 22),
            copyStatusButton.heightAnchor.constraint(equalToConstant: 22)
        ])
        self.copyStatusButton = copyStatusButton
        setCopyStatusButtonImage()
        // Only worth showing once there's an error message worth grabbing
        // verbatim -- see setStatusMessage(_:isError:). Nothing has run yet
        // when this row is first built, so start hidden.
        copyStatusButton.isHidden = true

        let statusRow = NSStackView(views: [status, copyStatusButton])
        statusRow.orientation = .horizontal
        statusRow.alignment = .firstBaseline
        statusRow.spacing = 6

        let help = NSTextField(wrappingLabelWithString: NSLocalizedString("Runs a real search against this source. Fields it finds appear on the right below \u{2014} drag one onto a mapping to use it, or leave it to a best guess.", comment: ""))
        help.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize - 1)
        help.textColor = .tertiaryLabelColor
        help.preferredMaxLayoutWidth = 460
        help.translatesAutoresizingMaskIntoConstraints = false

        let container = NSStackView(views: [row, statusRow, help])
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 4
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }

    @objc private func copyStatusMessage(_ sender: Any) {
        let message = statusLabel.stringValue
        guard message.isEmpty == false else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message, forType: .string)
    }

    /// Same macOS-11-only SF Symbols constraint as the API key reveal
    /// button (see setAPIKeyRevealButtonState below) -- "doc.on.doc" is
    /// the standard two-staggered-pages copy glyph used throughout macOS
    /// and this Claude interface; pre-11 falls back to a plain "Copy"
    /// text title since no icon is available.
    /// The one place that sets the status line's text and color -- and,
    /// alongside it, whether the Copy button is shown. Copying only makes
    /// sense once there's an error message worth grabbing verbatim (a
    /// server response body, an HTTP status) to paste elsewhere; for the
    /// routine "Testing…" or a plain success summary, the icon is just
    /// clutter next to text nobody needs to copy.
    private func setStatusMessage(_ message: String, isError: Bool) {
        statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
        statusLabel.stringValue = message
        copyStatusButton.isHidden = isError == false
    }

    private func setCopyStatusButtonImage() {
        if #available(macOS 11, *) {
            copyStatusButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: NSLocalizedString("Copy this message to the clipboard.", comment: ""))
            copyStatusButton.title = ""
        } else {
            copyStatusButton.image = nil
            copyStatusButton.title = NSLocalizedString("Copy", comment: "")
        }
    }

    /// The field-mapping section itself: the mapping table (every mapped
    /// field, Artwork URL Path included as its last row -- see
    /// mappingRowCell) on the left, and the Discovered Fields table
    /// (populated by Test Connection) on the right. The table's own +/-
    /// buttons live in the detail pane's footer (see makeDetailPane), not
    /// here, so they stay put rather than scrolling away with the rest of
    /// the form.
    private func makeFieldMappingSplit(source: CustomMetadataSource) -> NSView {
        let mappingTableColumn = makeMappingTableColumn()
        let discoveredColumn = makeDiscoveredFieldsTable()

        let split = NSStackView(views: [mappingTableColumn, discoveredColumn])
        split.orientation = .horizontal
        split.alignment = .top
        split.distribution = .fill
        split.spacing = 16
        split.translatesAutoresizingMaskIntoConstraints = false

        // The two columns grow together as the window widens, keeping
        // their original ~3:2 proportions (matching their old fixed
        // 380/260 widths) rather than only one soaking up the extra
        // space -- a discovered field's own path can run just as long as
        // a mapped one's, so both benefit from the room.
        discoveredColumn.widthAnchor.constraint(equalTo: mappingTableColumn.widthAnchor, multiplier: 260.0 / 380.0).isActive = true
        stretchRowToFillDetailWidth(split)

        return split
    }

    /// The scrolling list of this source's currently-mapped fields, sized
    /// to match the Discovered Fields table beside it (see
    /// fieldTablesHeight). Its last row is always Artwork URL Path (see
    /// mappingRowCell) -- grouped in with the other mapped fields rather
    /// than broken out on its own, even though it isn't itself
    /// addable/removable via the "+"/"-" buttons in the detail pane's
    /// footer, since it isn't a MetadataResult.Key mapping.
    private func makeMappingTableColumn() -> NSView {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        let table = NSTableView()
        table.usesAlternatingRowBackgroundColors = true
        table.allowsMultipleSelection = false
        table.dataSource = self
        table.delegate = self
        table.headerView = nil
        table.rowHeight = 28

        let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("mappingField"))
        tableColumn.title = NSLocalizedString("Field Mapping", comment: "")
        tableColumn.width = 360
        tableColumn.minWidth = 220
        tableColumn.resizingMask = .autoresizingMask
        table.addTableColumn(tableColumn)
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        scrollView.documentView = table
        self.mappingTableView = table

        // A minimum, not a fixed width, so this column (and the JSON path
        // field inside each of its rows -- see mappingRowCell) grows along
        // with the window instead of leaving the extra width unused.
        NSLayoutConstraint.activate([
            scrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 380),
            scrollView.heightAnchor.constraint(equalToConstant: fieldTablesHeight)
        ])

        return scrollView
    }

    /// One row of the mapping table. Every row except the last is one of
    /// this source's visibleFields, tagged mappingTagOffset + its index
    /// for commitMappingRowValue; the last row (index == visibleFields.
    /// count) is always Artwork URL Path, tagged and committed the same
    /// way it always has been (FieldTag.artworkPath), since it's a
    /// CustomMetadataSource property rather than a MetadataResult.Key
    /// mapping.
    private func mappingRowCell(for row: Int) -> NSView? {
        let keys = source.visibleFields

        if row == keys.count {
            return artworkRowCell(source: source)
        }
        guard keys.indices.contains(row) else { return nil }
        let key = keys[row]
        let tag = mappingTagOffset + row

        let cell = NSTableCellView()
        cell.identifier = NSUserInterfaceItemIdentifier("mappingFieldCell")

        let labelField = NSTextField(labelWithString: key.localizedDisplayName)
        labelField.lineBreakMode = .byTruncatingTail
        labelField.translatesAutoresizingMaskIntoConstraints = false
        labelField.widthAnchor.constraint(equalToConstant: 130).isActive = true

        let dropField = DroppableTextField()
        dropField.onDrop = { [weak self] droppedValue in
            self?.commitMappingRowValue(tag: tag, value: droppedValue)
        }
        dropField.stringValue = source.fieldMappings.first(where: { $0.field == key })?.jsonPath ?? ""
        dropField.tag = tag
        dropField.delegate = self
        dropField.translatesAutoresizingMaskIntoConstraints = false
        dropField.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        mappingFields[key] = dropField

        let rowStack = NSStackView(views: [labelField, dropField])
        rowStack.orientation = .horizontal
        rowStack.alignment = .firstBaseline
        rowStack.distribution = .fill
        rowStack.spacing = 8
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(rowStack)
        let preferredTrailing = rowStack.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4)
        preferredTrailing.priority = .defaultHigh
        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            rowStack.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -4),
            preferredTrailing,
            rowStack.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        return cell
    }

    /// The mapping table's Artwork URL Path row -- see mappingRowCell.
    /// Not a MetadataResult.Key mapping, so it's built and committed
    /// separately (commitDroppedValue / the .artworkPath case in
    /// controlTextDidEndEditing) rather than through commitMappingRowValue.
    private func artworkRowCell(source: CustomMetadataSource) -> NSView {
        let cell = NSTableCellView()
        cell.identifier = NSUserInterfaceItemIdentifier("artworkFieldCell")

        let labelField = NSTextField(labelWithString: NSLocalizedString("Artwork URL Path", comment: ""))
        labelField.lineBreakMode = .byTruncatingTail
        labelField.translatesAutoresizingMaskIntoConstraints = false
        labelField.widthAnchor.constraint(equalToConstant: 130).isActive = true

        let dropField = DroppableTextField()
        dropField.onDrop = { [weak self] droppedValue in
            self?.commitDroppedValue(tag: FieldTag.artworkPath.rawValue, value: droppedValue)
        }
        dropField.stringValue = source.artworkPath
        dropField.placeholderString = NSLocalizedString("optional", comment: "")
        dropField.tag = FieldTag.artworkPath.rawValue
        dropField.delegate = self
        dropField.translatesAutoresizingMaskIntoConstraints = false
        dropField.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        self.artworkPathField = dropField

        let rowStack = NSStackView(views: [labelField, dropField])
        rowStack.orientation = .horizontal
        rowStack.alignment = .firstBaseline
        rowStack.distribution = .fill
        rowStack.spacing = 8
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(rowStack)
        let preferredTrailing = rowStack.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4)
        preferredTrailing.priority = .defaultHigh
        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            rowStack.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -4),
            preferredTrailing,
            rowStack.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        return cell
    }

    private func makeDiscoveredFieldsTable() -> NSView {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        let table = NSTableView()
        table.usesAlternatingRowBackgroundColors = true
        table.allowsMultipleSelection = false
        table.dataSource = self
        table.delegate = self
        table.headerView = nil
        table.setDraggingSourceOperationMask(.copy, forLocal: false)
        table.setDraggingSourceOperationMask(.copy, forLocal: true)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("discoveredField"))
        column.title = NSLocalizedString("Discovered Fields", comment: "")
        column.minWidth = 180
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        scrollView.documentView = table
        self.discoveredFieldsTable = table

        // A minimum, not a fixed width -- see makeMappingTableColumn; its
        // width is actually driven from there (kept at a fixed ratio of
        // it, in makeFieldMappingSplit) rather than independently, so both
        // columns grow together.
        NSLayoutConstraint.activate([
            scrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 260),
            scrollView.heightAnchor.constraint(equalToConstant: fieldTablesHeight)
        ])

        return scrollView
    }

    private func makeMediaTypesRow(source: CustomMetadataSource) -> NSView {
        let labelField = NSTextField(labelWithString: NSLocalizedString("Applies To", comment: ""))
        labelField.translatesAutoresizingMaskIntoConstraints = false
        labelField.widthAnchor.constraint(equalToConstant: 130).isActive = true

        let movieCheckbox = NSButton(checkboxWithTitle: NSLocalizedString("Movies", comment: ""), target: self, action: #selector(movieTypeToggled(_:)))
        movieCheckbox.state = source.mediaTypes.contains(.movie) ? .on : .off

        let tvCheckbox = NSButton(checkboxWithTitle: NSLocalizedString("TV Shows", comment: ""), target: self, action: #selector(tvTypeToggled(_:)))
        tvCheckbox.state = source.mediaTypes.contains(.tvShow) ? .on : .off

        let row = NSStackView(views: [labelField, movieCheckbox, tvCheckbox])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 12
        return row
    }

    private func makeAuthRow(source: CustomMetadataSource) -> NSView {
        let labelField = NSTextField(labelWithString: NSLocalizedString("Send Key As", comment: ""))
        labelField.translatesAutoresizingMaskIntoConstraints = false
        labelField.widthAnchor.constraint(equalToConstant: 130).isActive = true

        let popup = NSPopUpButton()
        popup.addItems(withTitles: [NSLocalizedString("None", comment: ""),
                                     NSLocalizedString("Query Parameter", comment: ""),
                                     NSLocalizedString("HTTP Header", comment: "")])
        switch source.authentication {
        case .none: popup.selectItem(at: 0)
        case .queryParameter: popup.selectItem(at: 1)
        case .header: popup.selectItem(at: 2)
        }
        popup.target = self
        popup.action = #selector(authTypeChanged(_:))

        let nameField = NSTextField()
        nameField.tag = FieldTag.authName.rawValue
        nameField.delegate = self
        nameField.stringValue = source.authentication.parameterName
        nameField.placeholderString = NSLocalizedString("name, e.g. api_key or Authorization", comment: "")
        nameField.isEnabled = (source.authentication != .none)
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true

        let row = NSStackView(views: [labelField, popup, nameField])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.distribution = .fill
        row.spacing = 8
        stretchRowToFillDetailWidth(row)
        return row
    }

    /// A masked field and a plain field occupying the same spot, with a
    /// reveal button to swap which one is visible -- see the property
    /// comments on apiKeySecureField for why a masked-only field isn't
    /// enough here.
    private func makeAPIKeyRow(source: CustomMetadataSource) -> NSView {
        let labelField = NSTextField(labelWithString: NSLocalizedString("API Key", comment: ""))
        labelField.translatesAutoresizingMaskIntoConstraints = false
        labelField.widthAnchor.constraint(equalToConstant: 130).isActive = true

        let secureField = NSSecureTextField()
        secureField.stringValue = source.apiKey
        secureField.tag = FieldTag.apiKey.rawValue
        secureField.delegate = self
        secureField.translatesAutoresizingMaskIntoConstraints = false
        self.apiKeySecureField = secureField

        let plainField = NSTextField()
        plainField.stringValue = source.apiKey
        plainField.tag = FieldTag.apiKey.rawValue
        plainField.delegate = self
        plainField.isHidden = true
        plainField.translatesAutoresizingMaskIntoConstraints = false
        self.apiKeyPlainField = plainField

        let fieldContainer = NSView()
        fieldContainer.translatesAutoresizingMaskIntoConstraints = false
        fieldContainer.addSubview(secureField)
        fieldContainer.addSubview(plainField)
        NSLayoutConstraint.activate([
            fieldContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 400),
            secureField.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor),
            secureField.trailingAnchor.constraint(equalTo: fieldContainer.trailingAnchor),
            secureField.topAnchor.constraint(equalTo: fieldContainer.topAnchor),
            secureField.bottomAnchor.constraint(equalTo: fieldContainer.bottomAnchor),
            plainField.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor),
            plainField.trailingAnchor.constraint(equalTo: fieldContainer.trailingAnchor),
            plainField.topAnchor.constraint(equalTo: fieldContainer.topAnchor),
            plainField.bottomAnchor.constraint(equalTo: fieldContainer.bottomAnchor)
        ])

        let revealButton = NSButton(title: "", target: self, action: #selector(toggleAPIKeyVisibility(_:)))
        revealButton.bezelStyle = .smallSquare
        revealButton.isBordered = false
        revealButton.translatesAutoresizingMaskIntoConstraints = false
        revealButton.toolTip = NSLocalizedString("Show/hide the API key -- useful for confirming it matches exactly what you tested outside Subler.", comment: "")
        // A borderless image-only button otherwise shrink-wraps to almost
        // nothing (the icon alone renders barely 10pt tall) -- too small to
        // notice next to the field it belongs to, so give it a real hit
        // target the same size as the Copy icon button below.
        NSLayoutConstraint.activate([
            revealButton.widthAnchor.constraint(equalToConstant: 22),
            revealButton.heightAnchor.constraint(equalToConstant: 22)
        ])
        self.apiKeyRevealButton = revealButton
        setAPIKeyRevealButtonState(showingPlainText: false)

        // .centerY, same reasoning as the Test Connection row above --
        // fieldContainer is a plain wrapper NSView with no intrinsic
        // baseline of its own (AppKit falls back to its bottom edge for
        // .firstBaseline, which reads as misaligned against labelField and
        // revealButton), so centering the row vertically is what actually
        // lines the label, the key field, and the eye icon up with each
        // other.
        let row = NSStackView(views: [labelField, fieldContainer, revealButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 8
        stretchRowToFillDetailWidth(row)

        let help = NSTextField(wrappingLabelWithString: NSLocalizedString("Sent exactly as entered -- for a header like \u{201c}Authorization: Bearer <key>\u{201d}, enter \u{201c}Bearer abc123\u{201d} here, not just the key.", comment: ""))
        help.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize - 1)
        help.textColor = .tertiaryLabelColor
        help.preferredMaxLayoutWidth = 460
        help.translatesAutoresizingMaskIntoConstraints = false

        let container = NSStackView(views: [row, help])
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 2
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }

    @objc private func toggleAPIKeyVisibility(_ sender: NSButton) {
        // Commits whichever of the two fields is currently being edited,
        // same as before running Test Connection -- keeps the model in
        // sync even if the click-through to this button doesn't count as
        // "ending" the edit on its own.
        view.window?.makeFirstResponder(nil)

        let revealing = apiKeyPlainField.isHidden
        if revealing {
            apiKeyPlainField.stringValue = apiKeySecureField.stringValue
            apiKeyPlainField.isHidden = false
            apiKeySecureField.isHidden = true
            setAPIKeyRevealButtonState(showingPlainText: true)
            view.window?.makeFirstResponder(apiKeyPlainField)
        } else {
            apiKeySecureField.stringValue = apiKeyPlainField.stringValue
            apiKeySecureField.isHidden = false
            apiKeyPlainField.isHidden = true
            setAPIKeyRevealButtonState(showingPlainText: false)
            view.window?.makeFirstResponder(apiKeySecureField)
        }
    }

    /// SF Symbols (systemSymbolName) need macOS 11 -- this project's
    /// deployment target is 10.13, same constraint the toolbar icons in
    /// PrefsWindowController already work around -- so pre-11 falls back
    /// to a plain text title instead of an icon.
    private func setAPIKeyRevealButtonState(showingPlainText: Bool) {
        if #available(macOS 11, *) {
            let symbolName = showingPlainText ? "eye.slash" : "eye"
            let description = showingPlainText ? NSLocalizedString("Hide API key", comment: "") : NSLocalizedString("Show API key", comment: "")
            apiKeyRevealButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)
            apiKeyRevealButton.title = ""
        } else {
            apiKeyRevealButton.image = nil
            apiKeyRevealButton.title = showingPlainText ? NSLocalizedString("Hide", comment: "") : NSLocalizedString("Show", comment: "")
        }
    }

    // MARK: - Table view data source / delegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === discoveredFieldsTable { return discoveredFields.count }
        // Must be mappingTableView -- +1 for the trailing Artwork URL Path
        // row -- see mappingRowCell.
        return source.visibleFields.count + 1
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView === discoveredFieldsTable {
            return discoveredFieldCell(for: row)
        }
        return mappingRowCell(for: row)
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard tableView === discoveredFieldsTable, discoveredFields.indices.contains(row) else { return nil }
        let item = NSPasteboardItem()
        _ = item.setString(discoveredFields[row].path, forType: .string)
        return item
    }

    private func discoveredFieldCell(for row: Int) -> NSView? {
        guard discoveredFields.indices.contains(row) else { return nil }

        let identifier = NSUserInterfaceItemIdentifier("discoveredFieldCell")
        let cell: NSTableCellView
        if let reused = discoveredFieldsTable.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            let newCell = NSTableCellView()
            let textField = NSTextField(labelWithString: "")
            textField.lineBreakMode = .byTruncatingTail
            textField.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            textField.translatesAutoresizingMaskIntoConstraints = false
            newCell.addSubview(textField)
            newCell.textField = textField
            newCell.identifier = identifier
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: newCell.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: newCell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: newCell.centerYAnchor)
            ])
            cell = newCell
        }

        let field = discoveredFields[row]
        // JSONPath.discoverFields already caps sample-value length -- this
        // is a defense-in-depth backstop against an oversized string
        // making this table cell expensive to build.
        let displaySample = field.sampleValue.count > 200 ? String(field.sampleValue.prefix(200)) + "\u{2026}" : field.sampleValue
        cell.textField?.stringValue = "\(field.path)  —  \(displaySample)"
        cell.textField?.toolTip = NSLocalizedString("Drag onto a field below to map it.", comment: "") + " (\(field.path))"
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let changedTable = notification.object as? NSTableView, changedTable === mappingTableView else { return }
        updateRemoveMappingButtonState()
    }

    /// Disabled with nothing selected, and also disabled when the Artwork
    /// URL Path row (always the table's last row) is selected, since it
    /// isn't part of visibleFields and so isn't removable, only editable.
    private func updateRemoveMappingButtonState() {
        guard let mappingTableView = mappingTableView else {
            removeMappingButton?.isEnabled = false
            return
        }
        let row = mappingTableView.selectedRow
        removeMappingButton?.isEnabled = source.visibleFields.indices.contains(row)
    }

    // MARK: - Actions

    @objc private func movieTypeToggled(_ sender: NSButton) {
        update { source in
            if sender.state == .on { source.mediaTypes.insert(.movie) } else { source.mediaTypes.remove(.movie) }
        }
    }

    @objc private func tvTypeToggled(_ sender: NSButton) {
        update { source in
            if sender.state == .on { source.mediaTypes.insert(.tvShow) } else { source.mediaTypes.remove(.tvShow) }
        }
    }

    /// Builds the "+" pulldown's menu: two "add a whole set" shortcuts
    /// (mirroring the main metadata table's All/Movie/TV Show quick-adds),
    /// then every individually mappable field. Works the same whether
    /// Test Connection has been run yet or not -- a field or a whole set
    /// can be added before discovery (to fill in by hand) or after (to
    /// map something discovery didn't guess).
    private func appendMappingFieldMenuItems(to menu: NSMenu) {
        let defaultsItem = NSMenuItem(title: NSLocalizedString("Add Default Fields", comment: ""),
                                       action: #selector(addDefaultMappingFields(_:)), keyEquivalent: "")
        defaultsItem.target = self
        menu.addItem(defaultsItem)

        let allItem = NSMenuItem(title: NSLocalizedString("Add All Fields", comment: ""),
                                  action: #selector(addAllMappingFields(_:)), keyEquivalent: "")
        allItem.target = self
        menu.addItem(allItem)

        menu.addItem(.separator())

        for key in MetadataResult.Key.customSourceAllMappableKeys {
            let item = NSMenuItem(title: key.localizedDisplayName, action: #selector(addMappingFieldMenuItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = key
            menu.addItem(item)
        }
    }

    @objc private func addMappingFieldMenuItem(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? MetadataResult.Key else { return }
        addMappingFields([key])
    }

    @objc private func addDefaultMappingFields(_ sender: Any) {
        addMappingFields(MetadataResult.Key.customSourceDefaultFields)
    }

    @objc private func addAllMappingFields(_ sender: Any) {
        addMappingFields(MetadataResult.Key.customSourceAllMappableKeys)
    }

    private func addMappingFields(_ keys: [MetadataResult.Key]) {
        guard keys.isEmpty == false else { return }
        update { source in
            for key in keys where source.visibleFields.contains(key) == false {
                source.visibleFields.append(key)
            }
        }
        rebuildDetail()

        // Matches addTag(_:)'s behavior on the main metadata table:
        // picking a single field that's already mapped doesn't duplicate
        // it, it just reveals the existing row.
        if keys.count == 1, let key = keys.first,
           let row = source.visibleFields.firstIndex(of: key) {
            mappingTableView?.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            mappingTableView?.scrollRowToVisible(row)
        }
    }

    @objc private func removeMappingField(_ sender: Any) {
        let row = mappingTableView.selectedRow
        guard source.visibleFields.indices.contains(row) else { return }

        // Removes by index, entirely inside the mutation closure, rather
        // than resolving a key beforehand and matching by equality --
        // guarantees exactly the one selected row goes, never anything
        // else, regardless of how MetadataResult.Key equality behaves.
        update { source in
            let key = source.visibleFields.remove(at: row)
            source.fieldMappings.removeAll { $0.field == key }
        }
        rebuildDetail()
    }

    @objc private func authTypeChanged(_ sender: NSPopUpButton) {
        update { source in
            switch sender.indexOfSelectedItem {
            case 1:
                // Switching *into* Query Parameter: keep a name the user
                // already typed for this same mode, but never carry over a
                // header name like "Authorization" from a different mode --
                // that's not a sensible query parameter name and silently
                // sending the wrong one is exactly how a source can look
                // configured correctly while still failing every request.
                if case .queryParameter = source.authentication { /* keep existing name */ }
                else { source.authentication = .queryParameter(name: "api_key") }
            case 2:
                if case .header = source.authentication { /* keep existing name */ }
                else { source.authentication = .header(name: "Authorization") }
            default:
                source.authentication = .none
            }
        }
        rebuildDetail()
    }

    // MARK: - Test Connection / field discovery

    /// Network timeout used elsewhere (NetworkUtilities.dataTask, and
    /// CustomSourceService's own bounded semaphore wait) is 30-32s; this is
    /// the outer watchdog on the UI side of a test, a little more generous
    /// so a real (if slow) response always wins the race, but still tight
    /// enough that a stuck test never leaves the button disabled and the
    /// status line reading "Testing…" indefinitely.
    private let testConnectionWatchdogInterval: TimeInterval = 35

    @objc private func testConnection(_ sender: Any) {
        // Commit whatever's mid-edit (e.g. the URL template, if focus is
        // still in that field) before reading the source out to test it.
        view.window?.makeFirstResponder(nil)

        let urlTemplate = source.searchURLTemplate.trimmingCharacters(in: .whitespaces)
        guard urlTemplate.isEmpty == false else {
            showInputError(NSLocalizedString("Value required: enter a Search URL above before testing.", comment: ""),
                            highlighting: detailContainer.viewWithTag(FieldTag.urlTemplate.rawValue) as? NSTextField)
            return
        }

        let query = testQueryField.stringValue.trimmingCharacters(in: .whitespaces)
        guard query.isEmpty == false else {
            showInputError(NSLocalizedString("Value required: enter a sample search term.", comment: ""), highlighting: testQueryField)
            return
        }

        let currentSource = source
        setStatusMessage(NSLocalizedString("Testing…", comment: ""), isError: false)
        testButton.isEnabled = false

        testGeneration += 1
        let generation = testGeneration

        let service = CustomSourceService(source: currentSource)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = service.discoverFields(forQuery: query)
            DispatchQueue.main.async {
                guard let self = self, self.testGeneration == generation else { return }
                self.testButton.isEnabled = true
                self.handleDiscovery(result, source: currentSource)
            }
        }

        // Belt-and-suspenders: if nothing has come back (success, failure,
        // or the network layer's own timeout) by the watchdog interval,
        // stop waiting and tell the user, rather than leaving "Testing…"
        // and a disabled button on screen indefinitely.
        DispatchQueue.main.asyncAfter(deadline: .now() + testConnectionWatchdogInterval) { [weak self] in
            guard let self = self, self.testGeneration == generation else { return }
            self.testGeneration += 1
            self.testButton.isEnabled = true
            self.setStatusMessage(NSLocalizedString("The request took too long and was given up on -- check the URL and your network connection.", comment: ""), isError: true)
        }
    }

    /// Puts a red border on `field` for a couple of seconds so a missing
    /// required value is impossible to miss, on top of the status line.
    private func highlightMissingField(_ field: NSTextField) {
        field.wantsLayer = true
        field.layer?.borderColor = NSColor.systemRed.cgColor
        field.layer?.borderWidth = 2
        field.layer?.cornerRadius = 4
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak field] in
            field?.layer?.borderWidth = 0
        }
    }

    private func showInputError(_ message: String, highlighting field: NSTextField?) {
        setStatusMessage(message, isError: true)
        if let field = field {
            highlightMissingField(field)
        }
    }

    private func handleDiscovery(_ result: CustomSourceService.FieldDiscoveryResult, source: CustomMetadataSource) {
        if let error = result.errorMessage {
            setStatusMessage(error, isError: true)
            discoveredFields = []
        } else {
            setStatusMessage(String(format: NSLocalizedString("Found %d field(s). Unmapped fields below were filled in with a best guess.", comment: ""), result.fields.count), isError: false)
            discoveredFields = result.fields
            applyBestGuesses(source: source)
        }
        discoveredFieldsTable.reloadData()
        // applyBestGuesses already pokes each guessed row's own text field
        // directly for instant feedback, but that only reaches a row
        // AppKit has already asked for a view for -- a mapping table
        // that's taller than its scroll area (more rows than fit
        // on-screen at once) can have rows further down that haven't been
        // built yet. A full reload guarantees every row reflects the
        // model (which update already updated) once, regardless of what's
        // been scrolled into view yet.
        mappingTableView?.reloadData()
    }

    /// Fills in any mapping that's still empty with the discovered field
    /// whose name looks like the best match, without touching a mapping
    /// the user already set (by hand or by an earlier drag) -- a guess
    /// only ever proposes, it never overrides a real choice.
    private func applyBestGuesses(source: CustomMetadataSource) {
        let synonyms: [MetadataResult.Key: [String]] = [
            .name: ["title", "name"],
            .genre: ["genre", "genres", "category", "categories"],
            .releaseDate: ["releasedate", "airdate", "date", "year", "premiered"],
            .description: ["overview", "description", "summary", "synopsis"],
            .longDescription: ["overview", "description", "longdescription", "plot"],
            .rating: ["rating", "contentrating", "certification", "voteaverage"],
            .studio: ["studio", "network", "publisher", "label"],
            .cast: ["cast", "actors", "performers"],
            .director: ["director", "directors"],
            .producers: ["producer", "producers"],
            .screenwriters: ["writer", "writers", "screenwriter", "screenwriters", "author", "authors"],
            .executiveProducer: ["executiveproducer", "executiveproducers"],
            .copyright: ["copyright", "rights"],
            .seriesDescription: ["series", "seriesname", "franchise", "collection"]
        ]

        for key in source.visibleFields {
            let currentPath = source.fieldMappings.first(where: { $0.field == key })?.jsonPath ?? ""
            guard currentPath.isEmpty else { continue }
            guard let candidates = synonyms[key] else { continue }

            guard let match = discoveredFields.first(where: { candidates.contains(normalizedLeaf(of: $0.path)) }) else { continue }

            update { source in
                source.fieldMappings.removeAll { $0.field == key }
                source.fieldMappings.append(CustomSourceFieldMapping(field: key, jsonPath: match.path))
            }
            mappingFields[key]?.stringValue = match.path
        }

        // Artwork URL Path isn't a MetadataResult.Key mapping (it's its
        // own CustomMetadataSource property), so it falls outside the loop
        // above -- without this, "Test Connection" would list an obvious
        // poster/cover field in Discovered Fields and still leave Artwork
        // URL Path blank for the user to fill in by hand or drag
        // themselves, even though the whole point of a best guess is not
        // making them do that.
        if source.artworkPath.trimmingCharacters(in: .whitespaces).isEmpty {
            let artworkCandidates = ["poster", "image", "cover", "coverimage", "thumbnail", "thumb", "artwork", "backdrop", "posterurl", "boxart", "art"]
            if let match = discoveredFields.first(where: { artworkCandidates.contains(normalizedLeaf(of: $0.path)) }) {
                update { $0.artworkPath = match.path }
                artworkPathField?.stringValue = match.path
            }
        }
    }

    /// The last dot-separated component of a discovered path, lowercased
    /// with underscores stripped, so "release_date" and "releaseDate" and
    /// "images[].release_date" all normalize to the same lookup key.
    private func normalizedLeaf(of path: String) -> String {
        let lastComponent = path.components(separatedBy: ".").last ?? path
        let withoutBrackets = lastComponent.replacingOccurrences(of: "[]", with: "")
        return withoutBrackets.lowercased().replacingOccurrences(of: "_", with: "")
    }

    // MARK: - Text field delegate

    /// Used only by the Artwork URL Path row now -- mapping-table rows
    /// wire their own onDrop straight to commitMappingRowValue (see
    /// mappingRowCell), since Artwork isn't a MetadataResult.Key mapping
    /// and so isn't covered by that lookup. A drop sets the field's
    /// displayed text itself (see DroppableTextField.performDragOperation
    /// above); this only needs to persist it into the model, the same way
    /// controlTextDidEndEditing does for typed input.
    private func commitDroppedValue(tag: Int, value: String) {
        guard tag == FieldTag.artworkPath.rawValue else { return }
        update { $0.artworkPath = value.trimmingCharacters(in: .whitespaces) }
    }

    /// Commits a mapping-table row's text, looking the row's key up by its
    /// index into this source's own visibleFields -- see mappingRowCell,
    /// which tags each row mappingTagOffset + its index. Unlike a fixed-
    /// array scheme, this stays correct as fields are added/removed, since
    /// a tag is only ever read back against the same source state it was
    /// created for (any add/remove rebuilds the whole detail pane, handing
    /// out fresh tags).
    private func commitMappingRowValue(tag: Int, value: String) {
        let row = tag - mappingTagOffset
        guard source.visibleFields.indices.contains(row) else { return }
        let key = source.visibleFields[row]
        let path = value.trimmingCharacters(in: .whitespaces)
        update { source in
            source.fieldMappings.removeAll { $0.field == key }
            if path.isEmpty == false {
                source.fieldMappings.append(CustomSourceFieldMapping(field: key, jsonPath: path))
            }
        }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }

        if textField.tag >= mappingTagOffset {
            commitMappingRowValue(tag: textField.tag, value: textField.stringValue)
            return
        }

        guard let tag = FieldTag(rawValue: textField.tag) else { return }

        switch tag {
        case .name:
            update { $0.name = textField.stringValue }
        case .urlTemplate:
            update { $0.searchURLTemplate = textField.stringValue }
        case .resultsPath:
            update { $0.resultsPath = textField.stringValue }
        case .authName:
            update { source in
                switch source.authentication {
                case .queryParameter: source.authentication = .queryParameter(name: textField.stringValue)
                case .header: source.authentication = .header(name: textField.stringValue)
                case .none: break
                }
            }
        case .apiKey:
            update { $0.apiKey = textField.stringValue }
        case .artworkPath:
            update { $0.artworkPath = textField.stringValue }
        }
    }
}

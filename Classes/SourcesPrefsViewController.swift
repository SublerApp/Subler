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

/// The "+" button's popover content: pick one or more of Subler's
/// metadata fields to add to a source's mapping list. Fields already
/// mapped are listed but disabled (greyed out) rather than left out
/// entirely, so it's clear why they can't be picked again rather than
/// just silently missing. Cmd-click (NSTableView's normal multi-select
/// gesture) picks several before a single "Add".
private final class FieldPickerViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    private let allKeys: [MetadataResult.Key]
    private let alreadyUsed: Set<MetadataResult.Key>
    private let onAdd: ([MetadataResult.Key]) -> Void

    private var tableView: NSTableView!

    init(allKeys: [MetadataResult.Key], alreadyUsed: Set<MetadataResult.Key>, onAdd: @escaping ([MetadataResult.Key]) -> Void) {
        self.allKeys = allKeys
        self.alreadyUsed = alreadyUsed
        self.onAdd = onAdd
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 320))

        let label = NSTextField(wrappingLabelWithString: NSLocalizedString("Cmd-click to select multiple fields.", comment: ""))
        label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        let table = NSTableView()
        table.usesAlternatingRowBackgroundColors = true
        table.allowsMultipleSelection = true
        table.headerView = nil
        table.dataSource = self
        table.delegate = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("field"))
        column.title = NSLocalizedString("Field", comment: "")
        table.addTableColumn(column)

        scrollView.documentView = table
        self.tableView = table

        let addButton = NSButton(title: NSLocalizedString("Add", comment: ""), target: self, action: #selector(addTapped(_:)))
        addButton.bezelStyle = .rounded
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.keyEquivalent = "\r"

        let cancelButton = NSButton(title: NSLocalizedString("Cancel", comment: ""), target: self, action: #selector(cancelTapped(_:)))
        cancelButton.bezelStyle = .rounded
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.addSubview(scrollView)
        container.addSubview(addButton)
        container.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),

            scrollView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -8),

            addButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            addButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),

            cancelButton.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -8),
            cancelButton.bottomAnchor.constraint(equalTo: addButton.bottomAnchor)
        ])

        self.view = container
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return allKeys.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard allKeys.indices.contains(row) else { return nil }
        let key = allKeys[row]

        let identifier = NSUserInterfaceItemIdentifier("fieldPickerCell")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            let newCell = NSTableCellView()
            let textField = NSTextField(labelWithString: "")
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

        let used = alreadyUsed.contains(key)
        cell.textField?.stringValue = key.localizedDisplayName
        cell.textField?.textColor = used ? .disabledControlTextColor : .labelColor
        cell.textField?.toolTip = used ? NSLocalizedString("Already added to this source's mapping.", comment: "") : nil
        return cell
    }

    /// Keeps an already-mapped field from being picked again -- shown, so
    /// it's clear it exists and why it's unavailable, but not selectable.
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard allKeys.indices.contains(row) else { return false }
        return alreadyUsed.contains(allKeys[row]) == false
    }

    @objc private func addTapped(_ sender: Any) {
        let selected = tableView.selectedRowIndexes.compactMap { allKeys.indices.contains($0) ? allKeys[$0] : nil }
        dismiss(nil)
        if selected.isEmpty == false {
            onAdd(selected)
        }
    }

    @objc private func cancelTapped(_ sender: Any) {
        dismiss(nil)
    }
}

/// Preferences pane for user-configured additional metadata sources (see
/// CustomMetadataSource / CustomSourceService). A source is entirely data
/// -- a name, a search URL template, where results live in the JSON
/// response, how the API key is attached, and a field-by-field mapping
/// from the response to Subler's own metadata annotations -- so adding one
/// never needs a code change.
///
/// Left: the list of configured sources, with add/remove buttons. Right:
/// the selected source's settings, in a scrolling form since the field
/// mapping section alone is one row per mappable annotation.
final class SourcesPrefsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {

    private var sources: [CustomMetadataSource]
    private var selectedIndex: Int?

    private var tableView: NSTableView!
    private var removeButton: NSButton!
    private var detailContainer: NSView!

    /// Test Connection / field discovery state for the currently selected
    /// source. Rebuilt fresh whenever the selection changes (rebuildDetail);
    /// not persisted -- it's a scratchpad for filling in field mappings,
    /// not part of CustomMetadataSource itself.
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
    private var mappingTableView: NSTableView!
    private var addMappingButton: NSButton!
    private var removeMappingButton: NSButton!

    /// Bumped on every Test Connection click; a completion or timeout
    /// callback that doesn't match the current generation is stale (a
    /// previous test that's still winding down, or the selection changed
    /// mid-request) and is ignored instead of touching the UI.
    private var testGeneration = 0

    /// The live mapping-row text fields for the selected source, keyed by
    /// which annotation they map, so a best-guess or a drop can update a
    /// row's displayed text without rebuilding the whole detail form (which
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
    /// as mappingTagOffset + the row's index into the *selected source's
    /// own* visibleFields array (not a fixed global list -- each source's
    /// mapped-field list is now its own, user-editable set), since there's
    /// one row per visible field rather than one overall.
    private enum FieldTag: Int {
        case name = 0
        case urlTemplate = 1
        case resultsPath = 2
        case authName = 3
        case apiKey = 4
        case artworkPath = 5
    }
    private let mappingTagOffset = 1000

    /// The Sources list on the left gets its height implicitly: the split
    /// view's fixed height (420, see loadView) minus the add/remove
    /// buttons' row (a 4pt gap plus their 32pt height). The field-mapping
    /// table and the Discovered Fields table match it exactly, so all
    /// three lists in this pane feel like one design rather than the
    /// mapping section looking cramped or oversized next to the others.
    private let sourceListVisibleHeight: CGFloat = 420 - 4 - 32

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

        let descriptionLabel = NSTextField(wrappingLabelWithString: NSLocalizedString("Add a metadata source by describing its search API: where to search, where the results are in its response, and which response fields map to which annotations. No coding required.", comment: ""))
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.preferredMaxLayoutWidth = 660

        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false

        let listPane = makeListPane()
        let detailPane = makeDetailPane()

        splitView.addArrangedSubview(listPane)
        splitView.addArrangedSubview(detailPane)
        splitView.setHoldingPriority(NSLayoutConstraint.Priority.defaultLow + 1, forSubviewAt: 0)

        container.addSubview(headerLabel)
        container.addSubview(descriptionLabel)
        container.addSubview(splitView)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            headerLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            headerLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),

            descriptionLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 6),
            descriptionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            splitView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 12),
            splitView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            splitView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            splitView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            splitView.heightAnchor.constraint(equalToConstant: 420),

            listPane.widthAnchor.constraint(equalToConstant: 180)
        ])

        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.reloadData()
        updateRemoveButtonState()
        rebuildDetail()
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
        if tableView === discoveredFieldsTable { return discoveredFields.count }
        if tableView === mappingTableView {
            guard let index = selectedIndex, sources.indices.contains(index) else { return 0 }
            return sources[index].visibleFields.count
        }
        return sources.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView === discoveredFieldsTable {
            return discoveredFieldCell(for: row)
        }
        if tableView === mappingTableView {
            return mappingRowCell(for: row)
        }

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
        guard let changedTable = notification.object as? NSTableView else { return }
        if changedTable === tableView {
            let row = tableView.selectedRow
            selectedIndex = row >= 0 ? row : nil
            updateRemoveButtonState()
            rebuildDetail()
        } else if changedTable === mappingTableView {
            updateRemoveMappingButtonState()
        }
    }

    private func updateRemoveButtonState() {
        removeButton.isEnabled = tableView.selectedRow != -1
    }

    private func updateRemoveMappingButtonState() {
        removeMappingButton?.isEnabled = (mappingTableView?.selectedRow ?? -1) != -1
    }

    @objc private func addSource(_ sender: Any) {
        sources.append(CustomMetadataSource(name: NSLocalizedString("New Source", comment: "")))
        save()
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: sources.count - 1), byExtendingSelection: false)
    }

    @objc private func removeSource(_ sender: Any) {
        guard let index = selectedIndex, sources.indices.contains(index) else { return }
        sources.remove(at: index)
        save()
        tableView.reloadData()
        selectedIndex = nil
        updateRemoveButtonState()
        rebuildDetail()
    }

    private func save() {
        MetadataPrefs.additionalMetadataSources = sources
    }

    private func updateSelected(_ mutate: (inout CustomMetadataSource) -> Void) {
        guard let index = selectedIndex, sources.indices.contains(index) else { return }
        mutate(&sources[index])
        save()
    }

    // MARK: - Detail pane

    private func makeDetailPane() -> NSView {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = container

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            container.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            container.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])

        self.detailContainer = container
        return scrollView
    }

    private func rebuildDetail() {
        detailContainer.subviews.forEach { $0.removeFromSuperview() }
        discoveredFields = []
        mappingFields = [:]
        artworkPathField = nil
        // Invalidates any Test Connection still in flight for whatever was
        // selected before -- its completion/timeout callback checks this
        // and will now no-op instead of writing into the new source's pane.
        testGeneration += 1

        guard let index = selectedIndex, sources.indices.contains(index) else {
            let placeholder = NSTextField(wrappingLabelWithString: NSLocalizedString("Select a source on the left, or click + to add one.", comment: ""))
            placeholder.textColor = .secondaryLabelColor
            placeholder.translatesAutoresizingMaskIntoConstraints = false
            detailContainer.addSubview(placeholder)
            NSLayoutConstraint.activate([
                placeholder.topAnchor.constraint(equalTo: detailContainer.topAnchor, constant: 12),
                placeholder.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor, constant: 12),
                placeholder.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor, constant: -12),
                placeholder.bottomAnchor.constraint(equalTo: detailContainer.bottomAnchor, constant: -12)
            ])
            return
        }

        let source = sources[index]
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
                                              help: NSLocalizedString("\u{201c}{query}\u{201d} is replaced with the URL-encoded search text.", comment: "")))
        stack.addArrangedSubview(makeTextRow(label: NSLocalizedString("Results Path", comment: ""),
                                              value: source.resultsPath, tag: FieldTag.resultsPath.rawValue,
                                              placeholder: "results",
                                              help: NSLocalizedString("JSON path to the array of matches in the response. Leave blank if the response itself is that array.", comment: "")))

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
    }

    private func makeSectionLabel(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize)
        return label
    }

    /// A label + text field row, with optional help text on the line
    /// below. Pass `label: nil, disabled: true` for a help-text-only row
    /// (used as the intro line above the field-mapping list). Pass
    /// `droppable: true` to accept a dragged JSON path (from the Discovered
    /// Fields table) as well as typed input; `fieldCreated` hands back the
    /// text field itself, so a caller that needs to update it later (a
    /// best-guess fill-in) doesn't have to rebuild the whole form.
    private func makeTextRow(label: String?, value: String, tag: Int, placeholder: String = "",
                              secure: Bool = false, disabled: Bool = false, help: String? = nil,
                              fieldWidth: CGFloat = 400, droppable: Bool = false,
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
            textField.widthAnchor.constraint(equalToConstant: fieldWidth).isActive = true

            let row = NSStackView(views: [labelField, textField])
            row.orientation = .horizontal
            row.alignment = .firstBaseline
            row.spacing = 8
            container.addArrangedSubview(row)

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

    /// The sample-search-term field, "Test Connection" button, and status
    /// line above the field-mapping split.
    private func makeDiscoverRow() -> NSView {
        let labelField = NSTextField(labelWithString: NSLocalizedString("Sample Search Term", comment: ""))
        labelField.translatesAutoresizingMaskIntoConstraints = false
        labelField.widthAnchor.constraint(equalToConstant: 130).isActive = true

        let queryField = NSTextField()
        queryField.placeholderString = NSLocalizedString("e.g. Inception", comment: "")
        queryField.translatesAutoresizingMaskIntoConstraints = false
        queryField.widthAnchor.constraint(equalToConstant: 400).isActive = true
        self.testQueryField = queryField

        let button = NSButton(title: NSLocalizedString("Test Connection", comment: ""), target: self, action: #selector(testConnection(_:)))
        button.bezelStyle = .rounded
        self.testButton = button

        let row = NSStackView(views: [labelField, queryField, button])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
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
    private func setCopyStatusButtonImage() {
        if #available(macOS 11, *) {
            copyStatusButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: NSLocalizedString("Copy this message to the clipboard.", comment: ""))
            copyStatusButton.title = ""
        } else {
            copyStatusButton.image = nil
            copyStatusButton.title = NSLocalizedString("Copy", comment: "")
        }
    }

    /// The field-mapping section itself: the mapping table (with its own
    /// +/- buttons) and the Artwork URL Path row on the left, and the
    /// Discovered Fields table (populated by Test Connection) on the
    /// right.
    private func makeFieldMappingSplit(source: CustomMetadataSource) -> NSView {
        let mappingTableColumn = makeMappingTableColumn()

        // Artwork URL Path isn't a MetadataResult.Key mapping (it's its
        // own CustomMetadataSource property, since it produces an Artwork
        // rather than a text annotation) and so isn't addable/removable
        // via the +/- buttons above, but it belongs alongside the other
        // things a discovered field gets dragged onto rather than set
        // apart in its own section elsewhere.
        let artworkRow = makeTextRow(label: NSLocalizedString("Artwork URL Path", comment: ""),
                                      value: source.artworkPath, tag: FieldTag.artworkPath.rawValue,
                                      placeholder: NSLocalizedString("optional", comment: ""),
                                      fieldWidth: 220, droppable: true,
                                      fieldCreated: { [weak self] field in self?.artworkPathField = field })

        let leftColumn = NSStackView(views: [mappingTableColumn, artworkRow])
        leftColumn.orientation = .vertical
        leftColumn.alignment = .leading
        leftColumn.spacing = 10
        leftColumn.translatesAutoresizingMaskIntoConstraints = false

        let discoveredColumn = makeDiscoveredFieldsTable()

        let split = NSStackView(views: [leftColumn, discoveredColumn])
        split.orientation = .horizontal
        split.alignment = .top
        split.spacing = 16
        split.translatesAutoresizingMaskIntoConstraints = false
        return split
    }

    /// The scrolling list of the selected source's currently-mapped
    /// fields, plus the same-styled +/- buttons as the Sources list (see
    /// makeListPane) -- "+" opens a picker of every field Subler knows how
    /// to map (see FieldPickerViewController), "-" removes whichever row
    /// is selected.
    private func makeMappingTableColumn() -> NSView {
        let column = NSView()
        column.translatesAutoresizingMaskIntoConstraints = false

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
        table.addTableColumn(tableColumn)

        scrollView.documentView = table
        self.mappingTableView = table

        let addButton = NSButton(image: NSImage(named: NSImage.addTemplateName) ?? NSImage(),
                                  target: self, action: #selector(addMappingField(_:)))
        addButton.bezelStyle = .rounded
        addButton.imagePosition = .imageOnly
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.toolTip = NSLocalizedString("Add a field to map", comment: "")
        self.addMappingButton = addButton

        let removeButton = NSButton(image: NSImage(named: NSImage.removeTemplateName) ?? NSImage(),
                                     target: self, action: #selector(removeMappingField(_:)))
        removeButton.bezelStyle = .rounded
        removeButton.imagePosition = .imageOnly
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.toolTip = NSLocalizedString("Remove the selected field mapping", comment: "")
        self.removeMappingButton = removeButton

        column.addSubview(scrollView)
        column.addSubview(addButton)
        column.addSubview(removeButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: column.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            scrollView.widthAnchor.constraint(equalToConstant: 380),
            scrollView.heightAnchor.constraint(equalToConstant: sourceListVisibleHeight),

            addButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 4),
            addButton.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 44),
            addButton.heightAnchor.constraint(equalToConstant: 32),

            removeButton.topAnchor.constraint(equalTo: addButton.topAnchor),
            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 1),
            removeButton.widthAnchor.constraint(equalToConstant: 44),
            removeButton.heightAnchor.constraint(equalToConstant: 32),

            column.bottomAnchor.constraint(equalTo: addButton.bottomAnchor)
        ])

        updateRemoveMappingButtonState()
        return column
    }

    /// One row of the mapping table: the field's display name and a
    /// droppable text field for its JSON path, tagged mappingTagOffset +
    /// its index into the selected source's visibleFields -- see
    /// commitMappingRowValue.
    private func mappingRowCell(for row: Int) -> NSView? {
        guard let index = selectedIndex, sources.indices.contains(index) else { return nil }
        let keys = sources[index].visibleFields
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
        dropField.stringValue = sources[index].fieldMappings.first(where: { $0.field == key })?.jsonPath ?? ""
        dropField.tag = tag
        dropField.delegate = self
        dropField.translatesAutoresizingMaskIntoConstraints = false
        dropField.widthAnchor.constraint(equalToConstant: 220).isActive = true
        mappingFields[key] = dropField

        let rowStack = NSStackView(views: [labelField, dropField])
        rowStack.orientation = .horizontal
        rowStack.alignment = .firstBaseline
        rowStack.spacing = 8
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            rowStack.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -4),
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
        table.addTableColumn(column)

        scrollView.documentView = table
        self.discoveredFieldsTable = table

        NSLayoutConstraint.activate([
            scrollView.widthAnchor.constraint(equalToConstant: 260),
            scrollView.heightAnchor.constraint(equalToConstant: sourceListVisibleHeight)
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
        nameField.widthAnchor.constraint(equalToConstant: 220).isActive = true

        let row = NSStackView(views: [labelField, popup, nameField])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 8
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
            fieldContainer.widthAnchor.constraint(equalToConstant: 400),
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

        let row = NSStackView(views: [labelField, fieldContainer, revealButton])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 8

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

    // MARK: - Actions

    @objc private func movieTypeToggled(_ sender: NSButton) {
        updateSelected { source in
            if sender.state == .on { source.mediaTypes.insert(.movie) } else { source.mediaTypes.remove(.movie) }
        }
    }

    @objc private func tvTypeToggled(_ sender: NSButton) {
        updateSelected { source in
            if sender.state == .on { source.mediaTypes.insert(.tvShow) } else { source.mediaTypes.remove(.tvShow) }
        }
    }

    /// Opens the field picker popover, anchored to the "+" button, listing
    /// every field this source doesn't already map (already-mapped ones
    /// are shown but greyed out and unselectable -- see
    /// FieldPickerViewController). Cmd-click there selects several at
    /// once; "Add" appends all of them to the source's visibleFields.
    @objc private func addMappingField(_ sender: NSButton) {
        guard let index = selectedIndex, sources.indices.contains(index) else { return }
        let alreadyUsed = Set(sources[index].visibleFields)

        let picker = FieldPickerViewController(allKeys: MetadataResult.Key.customSourceAllMappableKeys,
                                                alreadyUsed: alreadyUsed) { [weak self] chosen in
            self?.addMappingFields(chosen)
        }
        picker.preferredContentSize = NSSize(width: 260, height: 320)

        let popover = NSPopover()
        popover.contentViewController = picker
        popover.behavior = .transient
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }

    private func addMappingFields(_ keys: [MetadataResult.Key]) {
        guard keys.isEmpty == false else { return }
        updateSelected { source in
            for key in keys where source.visibleFields.contains(key) == false {
                source.visibleFields.append(key)
            }
        }
        rebuildDetail()
    }

    @objc private func removeMappingField(_ sender: Any) {
        guard let index = selectedIndex, sources.indices.contains(index) else { return }
        let row = mappingTableView.selectedRow
        let keys = sources[index].visibleFields
        guard keys.indices.contains(row) else { return }
        let key = keys[row]

        updateSelected { source in
            source.visibleFields.removeAll { $0 == key }
            source.fieldMappings.removeAll { $0.field == key }
        }
        rebuildDetail()
    }

    @objc private func authTypeChanged(_ sender: NSPopUpButton) {
        updateSelected { source in
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

    /// Network timeout used elsewhere (NetworkUtilities.dataTask) is 30s;
    /// this is the outer watchdog on the UI side of a test, a little more
    /// generous so a real (if slow) response always wins the race, but
    /// still tight enough that a stuck test never leaves the button
    /// disabled and the status line reading "Testing…" indefinitely.
    private let testConnectionWatchdogInterval: TimeInterval = 35

    @objc private func testConnection(_ sender: Any) {
        guard let index = selectedIndex, sources.indices.contains(index) else { return }

        // Commit whatever's mid-edit (e.g. the URL template, if focus is
        // still in that field) before reading the source out to test it.
        view.window?.makeFirstResponder(nil)

        let urlTemplate = sources[index].searchURLTemplate.trimmingCharacters(in: .whitespaces)
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

        let source = sources[index]
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = NSLocalizedString("Testing…", comment: "")
        testButton.isEnabled = false

        testGeneration += 1
        let generation = testGeneration

        let service = CustomSourceService(source: source)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = service.discoverFields(forQuery: query)
            DispatchQueue.main.async {
                guard let self = self, self.testGeneration == generation else { return }
                self.testButton.isEnabled = true
                self.handleDiscovery(result, source: source)
            }
        }

        // Belt-and-suspenders: if nothing has come back (success, failure,
        // or the network layer's own 30s timeout) by the watchdog interval,
        // stop waiting and tell the user, rather than leaving "Testing…"
        // and a disabled button on screen indefinitely.
        DispatchQueue.main.asyncAfter(deadline: .now() + testConnectionWatchdogInterval) { [weak self] in
            guard let self = self, self.testGeneration == generation else { return }
            self.testGeneration += 1
            self.testButton.isEnabled = true
            self.statusLabel.textColor = .systemRed
            self.statusLabel.stringValue = NSLocalizedString("The request took too long and was given up on -- check the URL and your network connection.", comment: "")
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
        statusLabel.textColor = .systemRed
        statusLabel.stringValue = message
        if let field = field {
            highlightMissingField(field)
        }
    }

    private func handleDiscovery(_ result: CustomSourceService.FieldDiscoveryResult, source: CustomMetadataSource) {
        if let error = result.errorMessage {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = error
            discoveredFields = []
        } else {
            statusLabel.textColor = .secondaryLabelColor
            statusLabel.stringValue = String(format: NSLocalizedString("Found %d field(s). Unmapped fields below were filled in with a best guess.", comment: ""), result.fields.count)
            discoveredFields = result.fields
            applyBestGuesses(source: source)
        }
        discoveredFieldsTable.reloadData()
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

            updateSelected { source in
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
                updateSelected { $0.artworkPath = match.path }
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
        updateSelected { $0.artworkPath = value.trimmingCharacters(in: .whitespaces) }
    }

    /// Commits a mapping-table row's text, looking the row's key up by its
    /// index into the *selected source's* visibleFields -- see
    /// mappingRowCell, which tags each row mappingTagOffset + its index.
    /// Unlike the old fixed-array scheme, this stays correct as fields are
    /// added/removed, since a tag is only ever read back against the same
    /// source state it was created for (any add/remove rebuilds the whole
    /// detail pane, handing out fresh tags).
    private func commitMappingRowValue(tag: Int, value: String) {
        guard let index = selectedIndex, sources.indices.contains(index) else { return }
        let row = tag - mappingTagOffset
        guard sources[index].visibleFields.indices.contains(row) else { return }
        let key = sources[index].visibleFields[row]
        let path = value.trimmingCharacters(in: .whitespaces)
        updateSelected { source in
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
            updateSelected { $0.name = textField.stringValue }
            tableView.reloadData()
        case .urlTemplate:
            updateSelected { $0.searchURLTemplate = textField.stringValue }
        case .resultsPath:
            updateSelected { $0.resultsPath = textField.stringValue }
        case .authName:
            updateSelected { source in
                switch source.authentication {
                case .queryParameter: source.authentication = .queryParameter(name: textField.stringValue)
                case .header: source.authentication = .header(name: textField.stringValue)
                case .none: break
                }
            }
        case .apiKey:
            updateSelected { $0.apiKey = textField.stringValue }
        case .artworkPath:
            updateSelected { $0.artworkPath = textField.stringValue }
        }
    }
}

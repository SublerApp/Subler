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
    private var discoveredFieldsTable: NSTableView!
    private var discoveredFields: [DiscoveredField] = []

    /// The live mapping-row text fields for the selected source, keyed by
    /// which annotation they map, so a best-guess or a drop can update a
    /// row's displayed text without rebuilding the whole detail form (which
    /// would also throw away whatever the user just typed into the test
    /// query field).
    private var mappingFields: [MetadataResult.Key: NSTextField] = [:]

    /// Tags for the detail form's fixed, one-of-a-kind text fields.
    /// Field-mapping rows (one per MetadataResult.Key.customSourceMappableKeys
    /// entry) are tagged starting at mappingTagOffset instead, since there's
    /// one per key rather than one overall.
    private enum FieldTag: Int {
        case name = 0
        case urlTemplate = 1
        case resultsPath = 2
        case authName = 3
        case apiKey = 4
        case artworkPath = 5
    }
    private let mappingTagOffset = 1000

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

        let addButton = NSButton(image: NSImage(named: NSImage.addTemplateName) ?? NSImage(),
                                  target: self, action: #selector(addSource(_:)))
        addButton.bezelStyle = .smallSquare
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.toolTip = NSLocalizedString("Add a new metadata source", comment: "")

        let removeButton = NSButton(image: NSImage(named: NSImage.removeTemplateName) ?? NSImage(),
                                     target: self, action: #selector(removeSource(_:)))
        removeButton.bezelStyle = .smallSquare
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
            addButton.widthAnchor.constraint(equalToConstant: 24),

            removeButton.topAnchor.constraint(equalTo: addButton.topAnchor),
            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 1),
            removeButton.widthAnchor.constraint(equalToConstant: 24),

            pane.bottomAnchor.constraint(equalTo: addButton.bottomAnchor)
        ])

        return pane
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === discoveredFieldsTable { return discoveredFields.count }
        return sources.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView === discoveredFieldsTable {
            return discoveredFieldCell(for: row)
        }

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

    private func discoveredFieldCell(for row: Int) -> NSView {
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
        cell.textField?.stringValue = "\(field.path)  —  \(field.sampleValue)"
        cell.textField?.toolTip = NSLocalizedString("Drag onto a field below to map it.", comment: "") + " (\(field.path))"
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let changedTable = notification.object as? NSTableView, changedTable === tableView else { return }
        let row = tableView.selectedRow
        selectedIndex = row >= 0 ? row : nil
        updateRemoveButtonState()
        rebuildDetail()
    }

    private func updateRemoveButtonState() {
        removeButton.isEnabled = tableView.selectedRow != -1
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
        stack.addArrangedSubview(makeTextRow(label: NSLocalizedString("API Key", comment: ""),
                                              value: source.apiKey, tag: FieldTag.apiKey.rawValue, secure: true,
                                              help: NSLocalizedString("Sent exactly as entered -- for a header like \u{201c}Authorization: Bearer <key>\u{201d}, enter \u{201c}Bearer abc123\u{201d} here, not just the key.", comment: "")))

        stack.addArrangedSubview(makeSectionLabel(NSLocalizedString("Artwork", comment: "")))
        stack.addArrangedSubview(makeTextRow(label: NSLocalizedString("Artwork URL Path", comment: ""),
                                              value: source.artworkPath, tag: FieldTag.artworkPath.rawValue,
                                              placeholder: NSLocalizedString("optional", comment: ""),
                                              help: NSLocalizedString("JSON path (relative to each result) to its poster/cover image URL.", comment: "")))

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
                              fieldWidth: CGFloat = 320, droppable: Bool = false,
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
                    self?.commitMappingValue(tag: tag, value: droppedValue)
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
        queryField.widthAnchor.constraint(equalToConstant: 160).isActive = true
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
        status.preferredMaxLayoutWidth = 460
        status.translatesAutoresizingMaskIntoConstraints = false
        self.statusLabel = status

        let help = NSTextField(wrappingLabelWithString: NSLocalizedString("Runs a real search against this source. Fields it finds appear on the right below \u{2014} drag one onto a mapping to use it, or leave it to a best guess.", comment: ""))
        help.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize - 1)
        help.textColor = .tertiaryLabelColor
        help.preferredMaxLayoutWidth = 460
        help.translatesAutoresizingMaskIntoConstraints = false

        let container = NSStackView(views: [row, status, help])
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 4
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }

    /// The field-mapping section itself: the existing label + JSON-path
    /// rows on the left, and the Discovered Fields table (populated by
    /// Test Connection) on the right.
    private func makeFieldMappingSplit(source: CustomMetadataSource) -> NSView {
        let mappingColumn = NSStackView()
        mappingColumn.orientation = .vertical
        mappingColumn.alignment = .leading
        mappingColumn.spacing = 8
        mappingColumn.translatesAutoresizingMaskIntoConstraints = false

        for (mappingIndex, key) in MetadataResult.Key.customSourceMappableKeys.enumerated() {
            let existingPath = source.fieldMappings.first(where: { $0.field == key })?.jsonPath ?? ""
            let row = makeTextRow(label: key.localizedDisplayName, value: existingPath,
                                   tag: mappingTagOffset + mappingIndex, fieldWidth: 220, droppable: true,
                                   fieldCreated: { [weak self] field in self?.mappingFields[key] = field })
            mappingColumn.addArrangedSubview(row)
        }

        let discoveredColumn = makeDiscoveredFieldsTable()

        let split = NSStackView(views: [mappingColumn, discoveredColumn])
        split.orientation = .horizontal
        split.alignment = .top
        split.spacing = 16
        split.translatesAutoresizingMaskIntoConstraints = false
        return split
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
            scrollView.heightAnchor.constraint(equalToConstant: 300)
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

    @objc private func authTypeChanged(_ sender: NSPopUpButton) {
        updateSelected { source in
            let currentName = source.authentication.parameterName
            switch sender.indexOfSelectedItem {
            case 1:
                source.authentication = .queryParameter(name: currentName.isEmpty ? "api_key" : currentName)
            case 2:
                source.authentication = .header(name: currentName.isEmpty ? "Authorization" : currentName)
            default:
                source.authentication = .none
            }
        }
        rebuildDetail()
    }

    // MARK: - Test Connection / field discovery

    @objc private func testConnection(_ sender: Any) {
        guard let index = selectedIndex, sources.indices.contains(index) else { return }

        // Commit whatever's mid-edit (e.g. the URL template, if focus is
        // still in that field) before reading the source out to test it.
        view.window?.makeFirstResponder(nil)

        let query = testQueryField.stringValue.trimmingCharacters(in: .whitespaces)
        guard query.isEmpty == false else {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = NSLocalizedString("Enter a sample search term first.", comment: "")
            return
        }

        let source = sources[index]
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = NSLocalizedString("Testing…", comment: "")
        testButton.isEnabled = false

        let service = CustomSourceService(source: source)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = service.discoverFields(forQuery: query)
            DispatchQueue.main.async {
                guard let self = self, self.selectedIndex == index else { return }
                self.testButton.isEnabled = true
                self.handleDiscovery(result, source: source)
            }
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
            .copyright: ["copyright", "rights"]
        ]

        for key in MetadataResult.Key.customSourceMappableKeys {
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

    private func commitMappingValue(tag: Int, value: String) {
        guard tag >= mappingTagOffset, MetadataResult.Key.customSourceMappableKeys.indices.contains(tag - mappingTagOffset) else { return }
        let key = MetadataResult.Key.customSourceMappableKeys[tag - mappingTagOffset]
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
            commitMappingValue(tag: textField.tag, value: textField.stringValue)
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

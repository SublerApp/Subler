//
//  SourcesPrefsViewController.swift
//  Subler
//

import Cocoa

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
        return sources.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
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
        for (mappingIndex, key) in MetadataResult.Key.customSourceMappableKeys.enumerated() {
            let existingPath = source.fieldMappings.first(where: { $0.field == key })?.jsonPath ?? ""
            stack.addArrangedSubview(makeTextRow(label: key.localizedDisplayName, value: existingPath, tag: mappingTagOffset + mappingIndex, fieldWidth: 260))
        }

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
    /// (used as the intro line above the field-mapping list).
    private func makeTextRow(label: String?, value: String, tag: Int, placeholder: String = "",
                              secure: Bool = false, disabled: Bool = false, help: String? = nil,
                              fieldWidth: CGFloat = 320) -> NSView {
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

            let textField: NSTextField = secure ? NSSecureTextField() : NSTextField()
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

    // MARK: - Text field delegate

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }

        if textField.tag >= mappingTagOffset {
            let key = MetadataResult.Key.customSourceMappableKeys[textField.tag - mappingTagOffset]
            let path = textField.stringValue.trimmingCharacters(in: .whitespaces)
            updateSelected { source in
                source.fieldMappings.removeAll { $0.field == key }
                if path.isEmpty == false {
                    source.fieldMappings.append(CustomSourceFieldMapping(field: key, jsonPath: path))
                }
            }
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

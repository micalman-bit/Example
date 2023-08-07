//
//  AccountStatementListViewController.swift
//  OpenBusiness
//
//  Created by Andrey Samchenko on 02.05.2023.
//

import UIKit
import UIFramework
import Markdown

class AccountStatementListViewController: IBBaseViewController, AnalyticsSupport {

    var screenType: ScreenTypes = .accountStatementList

    private var titleAlert: String = ""
    private var subTitleAlert: NSAttributedString = .init(string: "")

    var dataSource: AccountStatementListPresenterDataSource?
    
    private var isLoadingList = false {
        didSet {
            if oldValue && !isLoadingList {
                tableView.performBatchUpdates {
                    tableView.reloadSections(.init(integer: 1), with: .bottom)
                }
            }
        }
    }

    private var state: DocumentType = .accountStatement
    private var copyNumber = ""
    
    private(set) lazy var contentVStack: UIStackView = {
        $0.axis = .vertical
        $0.spacing = 8
        return $0
    }(UIStackView())

    private lazy var documentTypeView: IBChipsView = {
        $0.delegate = self
        return $0
    }(IBChipsView())

    private lazy var tableView: ContentSizedTableView = {
        $0.delegate = self
        $0.dataSource = self
        $0.separatorStyle = .none
        $0.showsVerticalScrollIndicator = false
        $0.contentInset = .init(top: -2, left: 0, bottom: 80, right: 0)
        $0.register(cellWithClass: StatementTableViewCell.self)
        $0.register(cellWithClass: LoadingTableViewCell.self)
        return $0
    }(ContentSizedTableView(frame: .zero, style: .plain))

    private lazy var requestButton: IBButton = {
        $0.addTarget(self, action: #selector(didTapRequest(_:)), for: .touchUpInside)
        return $0
    }(IBButton(
        text: LocalizableKey.AccountStatement.List.new.localized(),
        kind: .md,
        style: .primary
    ))

    init(dataSource: AccountStatementListPresenterDataSource) {
        self.dataSource = dataSource
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    // MARK: Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        setTitleBar(LocalizableKey.AccountStatement.List.title.localized())
        UserDefaultsService.firstRunAccountStatement = true
        addSubviews()
        setupConstraints()
        showEmptyView()
        self.dataSource?.fetch(objectFor: self, state: state)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isModalInPresentation = false
        if let indexPaths = tableView.indexPathsForVisibleRows {
            tableView.reloadRows(at: indexPaths, with: .automatic)
        }
    }

    @objc func applicationDidBecomeActive(_ notification: NSNotification) {
        clearAllItem()
        tableView.reloadData()
        dataSource?.updateItemsList(objectFor: self, state: state)
    }

    @objc func didTapDismiss(_ sender: IBButton) {
        dismiss(animated: true)
    }

    deinit {
        Log.t("deinit \(String(describing: type(of: self)))")
    }
}

// MARK: - PushHandlingViewController
extension AccountStatementListViewController: PushHandlingViewController {
    typealias Context = AccountStatementListFactory.Context

    func handlePush(for context: AccountStatementListFactory.Context) {
        if navigationController?.viewControllers.count ?? 0 > 1 {
            navigationController?.popToRootViewController(animated: true)
        }
        dataSource?.handlePush(self, with: context)
    }

    func needShowPushBanner(for context: AccountStatementListFactory.Context) -> Bool {
        dataSource?.preparePush(self, context: context)
        return true
    }
}

// MARK: - AccountStatementListViewViewer
extension AccountStatementListViewController: AccountStatementListViewViewer {
        
    func setIsLoadingList(_ value: Bool) {
        isLoadingList = value
    }
    
    func showInDeliveryAlert() {
        let alertView = InDeliveryAlertView()
        alertView.closeButton.addTarget(self, action: #selector(didTapDismiss(_:)), for: .touchUpInside)
        alertView.fill(
            title: titleAlert,
            subTitle: subTitleAlert,
            link: dataSource?.getLinkAlertModel(state) ?? ""
        )
        let alert = IBAlertScreenController(type: .custom(alertView))
        alert.present(animated: true)
    }
    
    func applyChanges(for changes: CellChanges) {
        if dataSource?.accountStatementItems.isEmpty == true {
            showEmptyView()
        } else {
            tableView.removeEmptyView()
        }
        tableView.performBatchUpdates {
            tableView.reloadRows(at: changes.reloads, with: .fade)
            tableView.insertRows(at: changes.inserts, with: .fade)
            tableView.deleteRows(at: changes.deletes, with: .fade)
        }
        isLoadingList = false
    }
    
    func removeEmptyView() {
        tableView.removeEmptyView()
    }

    func showEmptyView() {
        switch state {
        case .accountStatement:
            tableView.setEmptyViewWithLeftTitle(
                leftTitle: LocalizableKey.AccountStatement.List.EmptyViewTitle.accountStatement.localized()
            )
        case .referenceDocument:
            tableView.setEmptyViewWithLeftTitle(
                leftTitle: LocalizableKey.AccountStatement.List.EmptyViewTitle.referenceDocument.localized()
            )
        }
    }

    func scrollToTop(completion: (() -> Void)?) {
        guard tableView.numberOfRows(inSection: 0) > 0 else {
            completion?()
            return
        }
        tableView.safeScrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            completion?()
        }
    }

    func reloadTableView() {
        tableView.reloadData()
    }
        
    func setDocumentType(_ viewModel: IBChipsViewModel) {
        documentTypeView.fill(with: viewModel)
    }
    
    func setDataForCustomAlert(_ data: TitleSubtitleAttributedModel) {
        titleAlert = data.title
        subTitleAlert = data.subTitle
    }
}

// MARK: - IBChipsViewDelegate
extension AccountStatementListViewController: IBChipsViewDelegate {
    func selectChips(_ view: UIFramework.IBChipsView, at index: Int) {
        switch index {
        case 0:
            guard state != .accountStatement else { return }
            clearAllItem()
            state = .accountStatement
            tableView.removeEmptyView()
            tableView.reloadData()
            dataSource?.updateItemsList(objectFor: self, state: state)
        case 1:
            guard state != .referenceDocument else { return }
            clearAllItem()
            state = .referenceDocument
            tableView.removeEmptyView()
            tableView.reloadData()
            dataSource?.updateItemsList(objectFor: self, state: state)
        default:
            break
        }
    }
}

// MARK: - UITableViewDataSource
extension AccountStatementListViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 64
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch state {
        case .accountStatement:
            if section == 1 {
                return isLoadingList ? 1 : 0
            } else {
                return dataSource?.accountStatementItems.count ?? 0
            }
        case .referenceDocument:
            if section == 1 {
                return isLoadingList ? 1 : 0
            } else {
                return dataSource?.bankReferencesItems.count ?? 0
            }
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withClass: StatementTableViewCell.self, for: indexPath)
            switch state {
            case .accountStatement:
                guard let accountStatementItems = dataSource?.accountStatementItems[indexPath.row] else {
                    return .init()
                }
                cell.configure(with: accountStatementItems)
            case .referenceDocument:
                guard let bankReferencesItems = dataSource?.bankReferencesItems[indexPath.row] else {
                    return .init()
                }
                cell.configure(with: bankReferencesItems)
            }
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withClass: LoadingTableViewCell.self, for: indexPath)
            cell.loadingView.startAnimating()
            return cell
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if canRequestNext(scrollView) {
            isLoadingList = true
            tableView.performBatchUpdates {
                tableView.reloadSections(.init(integer: 1), with: .bottom)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self = self else {
                    return
                }
                self.dataSource?.fetchNext(self)
            }
        }
    }
}

// MARK: - UITableViewDelegate
extension AccountStatementListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch state {
        case .accountStatement:
            guard let accountStatementItem = dataSource?.accountStatementItems[indexPath.row] else {
                return
            }
            dataSource?.didTapItemAccountStatement(self, item: accountStatementItem)
        case .referenceDocument:
            guard let bankReferencesItem = dataSource?.bankReferencesItems[indexPath.row] else {
                return
            }
            dataSource?.didTapCertificateItem(self, item: bankReferencesItem)
        }
    }
}

// MARK: - Private
private extension AccountStatementListViewController {
    
    func clearAllItem() {
        dataSource?.clearAllItem()
    }
    
    func canRequestNext(_ scrollView: UIScrollView) -> Bool {
        let height = scrollView.frame.size.height
        let contentYoffset = scrollView.contentOffset.y
        let distanceFromBottom = scrollView.contentSize.height - contentYoffset + 10
        switch state {
        case .accountStatement:
            return (distanceFromBottom < height)
                && !isLoadingList
                && (dataSource?.canRequestNext == true)
        case .referenceDocument:
            return (distanceFromBottom < height)
                && !isLoadingList
                && (dataSource?.canDocumentRequestNext == true)
        }
    }

    func addSubviews() {
        view.addSubviews(requestButton)
        contentVStack.addArrangedSubviews(
            documentTypeView,
            tableView
        )
        addContentViews(contentVStack)
    }
    
    func setupConstraints() {
        contentVStack.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        documentTypeView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(12)
            $0.height.equalTo(52)
        }
        
        tableView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(15)
        }
        
        requestButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(12)
            $0.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).inset(12)
            $0.height.equalTo(72)
        }
    }

    @objc func didTapRequest(_ sender: ActionButton) {
        dataSource?.didTapRequestButton(self)
    }
}

//
//  AccountStatementListPresenter.swift
//  OpenBusiness
//
//  Created by Andrey Samchenko on 02.05.2023.
//

import Foundation
import UIFramework
import Markdown

class AccountStatementListPresenter: NSObject {
    
    // MARK: - Private property
    private weak var viewer: AccountStatementListViewViewer?
    private let dataSource: AccountStatementListInteractorDataSource
    private var context: AccountStatementListFactory.Context
    private let diffCalculator: DiffCalculator
    private var isRefreshing = false
    private var contextHasBeenShowed = false
    private var currencies: [CurrencyResponseModel.Currency] = []
    private var company: CompanyProtocol = CompanyManager.shared.getSelectedCompany()
    private var state: DocumentType = .accountStatement
    private var continuationToken: String = "EOF"
    private var inDeliveryData: String = ""
    private var nextPageId: String?
    
    private var processing: TitleSubtitle?
    private var paperProcessing: TitleSubtitle?
    private var errorMessages: TitleSubtitle?
    private var paperInDelivery: TitleSubtitle?

    private var accountStatementDeliveryService = ""
    private var accountStatementTrackNumber = ""
    
    var ignorUpdateAccountItems = false
    var accountStatementItems: [AccountStatementListViewModel.Item] = [] {
        didSet {
            guard !ignorUpdateAccountItems else { return }
            let oldData = flatten(items: oldValue)
            let newData = flatten(items: accountStatementItems)
            let cellChanges = diffCalculator.calculate(oldItems: oldData, newItems: newData, in: 0)
            viewer?.applyChanges(for: cellChanges)
        }
    }
    
    var bankReferencesItems: [BankReferencesListViewModel.Item] = []
    
    init(
        dataSource interactor: AccountStatementListInteractorDataSource,
        context: AccountStatementListFactory.Context
    ) {
        self.dataSource = interactor
        self.context = context
        self.diffCalculator = DiffCalculatorImpl()
    }

    private func listenToWSEvents() {
        WSProvider.shared.publisher.attach(self, key: .needInappNotificationRefresh) { model in
            NotificationCenter.default.post(
                name: Notification.Name.refreshDashboardView,
                object: model
            )
        }
        
        WSProvider.shared.publisher.attach(self, key: .statementStatusUpdate) { (model: StatementStatusUpdateWSModel) in
            guard let status = AccountStatementListViewModel.Item.State(rawValue: model.status) else { return }
            let group = DispatchGroup()
            let changeStatusWorkItem = DispatchWorkItem {
                self.ignorUpdateAccountItems = true
                for i in 0..<self.accountStatementItems.count {
                    if self.accountStatementItems[i].id == model.statementId {
                        self.accountStatementItems[i].state = status
                        break
                    }
                }
                self.ignorUpdateAccountItems = false
                group.leave()
            }

            group.enter()
            DispatchQueue.global().async(execute: changeStatusWorkItem)
            
            group.notify(queue: DispatchQueue.main) {
                self.viewer?.reloadTableView()
            }
        }
    }

    private func sendMetrics(actionType: AnalyticsEvents.ActionType, status: AnalyticsEvents.EventStatus? = nil) {
        AnalyticsManager.shared.track(
            event: TemplateEvent(
                name: AnalyticsEvents.AEventType.inAppAction.rawValue,
                params: AnalyticsEvents.BaseModel(actionType: actionType)
            ),
            serviceTypes: [.exponea]
        )
    }
    
    deinit {
        Log.t("deinit \(String(describing: type(of: self)))")
    }
}

// MARK: - AccountStatementListPresenterDataSource
extension AccountStatementListPresenter: AccountStatementListPresenterDataSource {
    
    func clearAllItem() {
        bankReferencesItems = []
        accountStatementItems = []
        clearContinuationToken()
    }
    
    func setEmptyBankReferencesItemsList() {
        bankReferencesItems = []
        viewer?.setBankReferencesItems(bankReferencesItems)
    }
    
    func clearContinuationToken() {
        continuationToken = "EOF"
    }
    
    func getLinkAlertModel(_ state: DocumentType) -> String {
        switch state {
        case .accountStatement:
            return accountStatementDeliveryService + accountStatementTrackNumber
        case .referenceDocument:
            var inDeliveryLink = ""
            let linkRegex = try? NSRegularExpression(
                pattern: NSRegularExpression.linkPattern,
                options: []
            )
            if let linkMatch = linkRegex?.firstMatch(
                in: inDeliveryData,
                options: [],
                range: NSRange(location: 0, length: inDeliveryData.utf16.count)
            ) {
                let linkRange = linkMatch.range(at: 1)
                let link = (inDeliveryData as NSString).substring(with: linkRange)
                inDeliveryLink = link
            }
            return inDeliveryLink
        }
    }
    
    func fetch(objectFor view: AccountStatementListViewViewer, state: DocumentType) {
        viewer = view
        self.listenToWSEvents()
        viewer?.setDocumentType(setDocumentTypeList(documentType: state))
        viewer?.showLoader()
        dataSource.statementsTexts(self, statementId: nil, type: .fetch)
    }

    func updateItemsList(objectFor view: AccountStatementListViewViewer, state: DocumentType) {
        self.state = state
        switch state {
        case .accountStatement:
            sendMetrics(actionType: .buttonClickExtract)
        case .referenceDocument:
            sendMetrics(actionType: .buttonClickReference)
        }
        loadMainData(state)
    }
    
    private func loadMainData(_ state: DocumentType) {
        viewer?.showLoader()
        dataSource.fetch(objectFor: self, companyId: company.companyId, state: state)
    }

    func didTapItemAccountStatement(_ view: AccountStatementListViewViewer, item: AccountStatementListViewModel.Item) {
        switch item.state {
        case .new, .processing:
            showStatementNotReady(item.isPhysical)
        case .physicalConfirmed:
            showStatementNotReady(false)
        case .ready, .physicalDelivered:
            openFilePreview(item)
        case .error:
            viewer?.showLoader()
            dataSource.statementsTexts(self, statementId: item.id, type: .error)
        case .physicalInDelivery:
            viewer?.showLoader()
            accountStatementDeliveryService = item.deliveryService ?? ""
            dataSource.statementListById(objectFor: self, companyId: company.companyId, statementId: item.id)
        case .physicalConfirmationNeeded:
            let context = PaymentDocumentsFactory.Context(statementId: item.id, from: .statement)
            ProfileRouter.paymentDocuments(context).goto()
        }
    }
    
    func didTapCertificateItem(_ view: AccountStatementListViewViewer, item: BankReferencesListViewModel.Item) {
        switch item.status {
        case .processing:
            showNotReadyAlert(item)
        case .inDelivery:
            showInDeliveryAlert(item)
        case .сompleted:
            openFilePreview(item)
        case .error:
            showErrorAlert(item)
        }
    }

    func didTapRequestButton(_ view: AccountStatementListViewViewer) {
        viewer = view
        sendMetrics(actionType: .buttonClickRequestANewExtractAndReference)
        let accountStatementButton = AlertScreenActions.ViewModel.ActionItem(
            title: LocalizableKey.AccountStatement.AlertButton.accountStatement.localized(),
            action: { [weak self] in
                self?.sendMetrics(actionType: .buttonClickRequestANewExtract)
                self?.didTapAccountStatementButton(view)
            }
        )
        
        let referenceDocumentButton = AlertScreenActions.ViewModel.ActionItem(
            title: LocalizableKey.AccountStatement.AlertButton.referenceDocument.localized(),
            action: { [weak self] in
                self?.sendMetrics(actionType: .buttonClickRequestANewReference)
                self?.didTapReferenceDocumentButton(view)
            }
        )

        let viewModel = AlertScreenActions.ViewModel(
            title: LocalizableKey.AccountStatement.List.Alert.title.localized(),
            actionList: [accountStatementButton, referenceDocumentButton]
        )

        let alert = IBAlertScreenController(type: .actions(viewModel), backgroundStyle: .transparencyGradient)
        alert.present(animated: true)
    }

    func handlePush(_ view: AccountStatementListViewViewer, with context: AccountStatementListFactory.Context) {
        self.context = context
        contextHasBeenShowed = false
        fetch(objectFor: view, state: .accountStatement)
    }

    func preparePush(_ view: AccountStatementListViewViewer, context: AccountStatementListFactory.Context) {
        guard case .showStatement(let pushCompanyId, let statementId, let isSuccess) = context,
              company.companyId == pushCompanyId,
              var item = accountStatementItems.first(where: { $0.id == statementId }),
              let index = accountStatementItems.firstIndex(of: item)
        else {
            return
        }
        item.update(with: isSuccess)
        accountStatementItems.remove(at: index)
        accountStatementItems.insert(item, at: index)
    }

    func fetchNext(_ view: AccountStatementListViewViewer) {
        switch state {
        case .referenceDocument:
            guard canDocumentRequestNext else { return }
            dataSource.getBankReferencesList(objectFor: self, companyId: company.companyId, continuationToken: continuationToken)
        case .accountStatement:
            guard let nextId = nextPageId, canRequestNext else { return }
            dataSource.fetchNext(self, pageId: nextId)
        }
    }
    
    var canDocumentRequestNext: Bool {
        guard !continuationToken.isEmpty, continuationToken != "EOF" else {
            Log.e("continuationToken is now valid for new requesr", isRemoteEvent: false)
            return false
        }
        return true
    }
    
    var canRequestNext: Bool {
        guard !(nextPageId ?? "").isEmpty, nextPageId != "EOF" else {
            Log.e("nextPageId is now valid for new request", isRemoteEvent: false)
            return false
        }
        return true
    }

    func applicationDidBecomeActive(_ view: AccountStatementListViewViewer) {
        if accountStatementItems.contains(where: { $0.state == .processing }) {
            fetch(objectFor: view, state: .accountStatement)
        }
    }
    
    func changeSelectChips(_ documentType: DocumentType) {
        viewer?.setDocumentType(setDocumentTypeList(documentType: documentType))
    }
}

// MARK: - FilePreviewDelegate
extension AccountStatementListPresenter: FilePreviewDelegate {
    func fetchRemoteFile(
        _ viewer: FilePreviewPresenterViewer,
        for object: FilePreviewItem,
        progress: ((Progress) -> Void)?,
        completion: @escaping (Result<URL, WAError>) -> ()
    ) -> Cancellable? {
        switch state {
        case .accountStatement:
            guard let item = object as? AccountStatementListViewModel.Item else {
                return nil
            }
            return dataSource.downloadFile(with: item.fileId, progress: progress, completion: completion)
        case .referenceDocument:
            guard let item = object as? BankReferencesListViewModel.Item, let fileId = item.fileId else {
                return nil
            }
            return dataSource.certificateDownload(fileId: fileId, progress: progress, completion: completion)
        }
    }
}

// MARK: - AccountStatementListPresenterViewer
extension AccountStatementListPresenter: AccountStatementListPresenterViewer {

    func responseModel(_ model: AccountStatementListByIdModel) {
        accountStatementDeliveryService = model.deliveryService ?? ""
        accountStatementTrackNumber = model.trackNumber ?? ""
        paperInDelivery = .init(model.content.messages.paperInDelivery)
        viewer?.hideLoader()
        viewer?.setDataForCustomAlert(configureDataForCustomAlert())
        viewer?.showInDeliveryAlert()
    }
    
    func response(_ model: StatementTextsModel, statementId: String?, type: RequestTextsType) {
        processing = .init(model.content.messages.processing)
        paperProcessing = .init(model.content.messages.paperProcessing)
        errorMessages = .init(model.content.messages.error)
        switch type {
        case .fetch:
            dataSource.getCurrencies(self)
            loadMainData(state)
            checkContext()
        case .error:
            viewer?.hideLoader()
            guard let statementId = statementId else { return }
            showStatementFinishedWithError(statementId: statementId)
        case .inDelivery:
            viewer?.hideLoader()
            viewer?.setDataForCustomAlert(configureDataForCustomAlert())
            viewer?.showInDeliveryAlert()
        }
    }
    
    func responseReferencesList(bankReferences: [BankReferencesListModel.BankReferences], continuationToken: String) {
        self.continuationToken = continuationToken
        let viewModel = bankReferences.map { statement in
            AccountStatementListUseCases.bankReferencesMap(statement)
        }

        self.bankReferencesItems.append(contentsOf: viewModel)
        viewer?.removeEmptyView()
        viewer?.setBankReferencesItems(bankReferencesItems)
        viewer?.setIsLoadingList(false)
        viewer?.hideLoader()
    }
    
    func response(_ model: AccountStatementListModel) {
        nextPageId = model.content.nextId
        var viewModel = AccountStatementListViewModel(model, currencies: currencies)
        viewer?.reloadTableView()
        viewer?.hideLoader()
        viewer?.scrollToTop(completion: { [weak self] in
            self?.accountStatementItems = viewModel.items
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.openStatementIfNeeded(viewModel.items)
            }
        })
    }

    func response(nextPage model: AccountStatementListModel) {
        nextPageId = model.content.nextId
        var viewModel = AccountStatementListViewModel(model, currencies: currencies)
        var itemsSet = Set(accountStatementItems)
        viewModel.items.forEach({ itemsSet.insert($0) })
        accountStatementItems = Array(itemsSet).sorted(by: { $0.orderDate > $1.orderDate })
        viewer?.reloadTableView()
        viewer?.hideLoader()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.openStatementIfNeeded(viewModel.items)
        }
    }

    func responseEmptyList(continuationToken: String) {
        self.continuationToken = continuationToken
        if bankReferencesItems.isNotEmpty {
            viewer?.setIsLoadingList(false)
            viewer?.removeEmptyView()
        } else {
            bankReferencesItems = []
            viewer?.showEmptyView()
        }
        viewer?.setBankReferencesItems(bankReferencesItems)
        viewer?.hideLoader()
    }

    func responseDelete() {
        bankReferencesItems = []
        viewer?.setBankReferencesItems(bankReferencesItems)
        loadMainData(.referenceDocument)
    }

    func response(_ error: WAError) {
        viewer?.hideLoader()
        viewer?.showSurfaceError(error)
    }

    func response(currencies: [CurrencyResponseModel.Currency]) {
        self.currencies = currencies
    }
}

// MARK: - Private method
private extension AccountStatementListPresenter {
    
    func didTapAccountStatementButton(_ view: AccountStatementListViewViewer) {
        let accounts = AccountStatementListUseCases.getAccounts()
        guard !accounts.isEmpty else {
            view.showSurfaceError(DataErrorType.e10005.getWAError())
            return
        }
        let context = StatementRequestFactory.Context(
            companyId: company.companyId,
            closeType: .dismiss,
            completion: handleRequestCompletion
        )
        ProfileRouter.statementRequest(context).goto()
    }

    func didTapReferenceDocumentButton(_ view: AccountStatementListViewViewer) {
        ProfileRouter.certificateList(CertificateListFactory.Context()).goto()
    }

    func setDocumentTypeList(documentType: DocumentType) -> IBChipsViewModel {
        return IBChipsViewModel(
            chips: [
                IBChipsItemModel(
                    title: LocalizableKey.AccountStatement.List.Alert.accountStatement.localized(),
                    state: .active,
                    isSelected: documentType == .accountStatement
                ),
                IBChipsItemModel(
                    title: LocalizableKey.AccountStatement.certificate.localized(),
                    state: .active,
                    isSelected: documentType == .referenceDocument
                ),
            ],
            isMultipleSelectionEnabled: false
        )
    }

    func checkContext() {
        switch context {
        case .showSuccess(let isSuccess):
            handleRequestCompletion(isSuccess)
        default:
            return
        }
    }

    func showNotReadyAlert(_ item: BankReferencesListViewModel.Item) {
        let okButton = AlertScreenButton.ButtonModel(
            title: LocalizableKey.Action.okey.localized(),
            type: .black
        )
        var description = ""
        switch item.referenceType {
        case .paper:
            description = Document(parsing: item.content.messages.paperProcessing.subTitle).format()
        case .digital:
            description = LocalizableKey.AccountStatement.ShowNotReadyAlert.description.localized()
        }

        let viewModel = AlertScreen.ViewModel(
            title: Document(parsing: item.content.messages.paperProcessing.title).format(),
            description: description,
            itemList: [okButton]
        )

        let alert = IBAlertScreenController(type: .alert(viewModel))
        alert.present(animated: true)
    }
    
    func showErrorAlert(_ item: BankReferencesListViewModel.Item) {
        let items = [
            AlertScreenButton.ButtonModel(
                title: LocalizableKey.AccountStatement.Alert.finishedWithErrorDoneButton.localized(),
                type: .white
            )
        ]
        
        let viewModel = AlertScreen.ViewModel(
            title: Document(parsing: item.content.messages.error.title).format(),
            description: Document(parsing: item.content.messages.error.subTitle).format(),
            itemList: items
        )

        let alert = IBAlertScreenController(type: .alert(viewModel))
        alert.present(animated: true)
    }
    
    func showInDeliveryAlert(_ item: BankReferencesListViewModel.Item) {
        viewer?.setDataForCustomAlert(configureDataForCustomAlert(item))
        inDeliveryData = item.content.messages.inDelivery.subTitle
        viewer?.showInDeliveryAlert()
    }

    func configureDataForCustomAlert(_ item: BankReferencesListViewModel.Item) -> TitleSubtitleAttributedModel {
        return TitleSubtitleAttributedModel(
            title: Document(parsing: item.content.messages.inDelivery.title).format(),
            subTitle: AccountStatementListUseCases.convertStringToAttributedTextWithUnderscore(
                with: item.content.messages.inDelivery.subTitle,
                rangeStrung: "сайте партнёра"
            )
        )
    }

    func configureDataForCustomAlert() -> TitleSubtitleAttributedModel {
        return TitleSubtitleAttributedModel(
            title: paperInDelivery?.title ?? "",
            subTitle: AccountStatementListUseCases.convertStringToAttributedTextWithUnderscore(
                with: paperInDelivery?.subTitle ?? "",
                rangeStrung: "сайте партнёра"
            )
        )
    }

    func flatten(
        items: [AccountStatementListViewModel.Item]
    ) -> [ReloadableCell<AccountStatementListViewModel.Item>] {
        return items
                .enumerated()
                .map({
                    ReloadableCell(
                        key: $0.element.id,
                        value: $0.element,
                        index: $0.offset
                    )
                })
    }

    func showRequestSuccessAlert() {
        let okButton = AlertScreenButton.ButtonModel(
            title: LocalizableKey.AccountStatement.Alert.requestSuccessButton.localized(),
            type: .black
        )

        let viewModel = AlertScreenSuccess.ViewModel(
            title: LocalizableKey.AccountStatement.Alert.requestSuccessTitle.localized(),
            description: LocalizableKey.AccountStatement.Alert.requestSuccessMessage.localized(),
            button: okButton,
            media: .imageSource(ImageKey.Other.success.localized())
        )

        let alert = IBAlertScreenController(type: .success(viewModel))
        alert.present(animated: true)
    }

    func showStatementNotReady(_ isPhysical: Bool) {
        let okButton = AlertScreenButton.ButtonModel(
            title: LocalizableKey.Action.okey.localized(),
            type: .black
        )
        let title = isPhysical ? (paperProcessing?.title ?? "") : (processing?.title ?? "")
        let description = isPhysical ? (paperProcessing?.subTitle ?? "") : (processing?.subTitle ?? "")

        let viewModel = AlertScreen.ViewModel(
            title: title,
            description: description,
            itemList: [okButton]
        )

        let alert = IBAlertScreenController(type: .alert(viewModel))
        alert.present(animated: true)
    }

    func showStatementFinishedWithError(statementId: String) {
        let deleteButton = AlertScreenButton.ButtonModel(
            title: LocalizableKey.AccountStatement.Alert.finishedWithErrorDeleteButton.localized(),
            type: .white,
            action: { [weak self] in
                guard let self else { return }
                self.viewer?.showLoader()
                self.dataSource.statementDelete(self, id: statementId)
            }
        )

        let doneButton = AlertScreenButton.ButtonModel(
            title: LocalizableKey.AccountStatement.Alert.finishedWithErrorDoneButton.localized(),
            type: .black
        )
        
        let viewModel = AlertScreen.ViewModel(
            title: errorMessages?.title ?? "",
            description: errorMessages?.subTitle,
            itemList: [deleteButton, doneButton]
        )

        let alert = IBAlertScreenController(type: .alert(viewModel))
        alert.present(animated: true)
    }

    func handleRequestCompletion(_ isSuccess: Bool) {
        viewer?.showLoader()
        if isSuccess {
            NotificationCenter.default.post(
                name: Notification.Name.refreshAccountStatement,
                object: DocumentType.accountStatement
            )
            showRequestSuccessAlert()
        }
        dataSource.fetch(objectFor: self, companyId: company.companyId, state: .accountStatement)
    }

    func openStatementIfNeeded(_ items: [AccountStatementListViewModel.Item]) {
        guard !contextHasBeenShowed,
              case .showStatement(let companyId, let statementId, let isSuccess) = context,
              companyId == self.company.companyId,
              let item = items.first(where: { $0.id == statementId }) else {
            return
        }
        if isSuccess {
            openFilePreview(item)
            contextHasBeenShowed = true
        } else {
            showStatementFinishedWithError(statementId: item.id)
        }
    }

    func openFilePreview(_ item: AccountStatementListViewModel.Item) {
        let context = FilePreviewFactory.Context.remoteFile(forObject: item, delegate: self)
        CommonRouter.filePreview(context).goto()
    }
    
    func openFilePreview(_ item: BankReferencesListViewModel.Item) {
        let context = FilePreviewFactory.Context.remoteFile(forObject: item, delegate: self)
        CommonRouter.filePreview(context).goto()
    }
}

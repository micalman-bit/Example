//
//  AccountStatementListEntities.swift
//  OpenBusiness
//
//  Created by Andrey Samchenko on 02.05.2023.
//

import UIFramework

// MARK: Протоколы

// sourcery: AutoMockable
protocol AccountStatementListViewViewer: IBBaseViewControllerViewer {
    func applyChanges(for changes: CellChanges)
    func scrollToTop(completion: (() -> Void)?)
    func reloadTableView()
    func setDataForCustomAlert(_ data: TitleSubtitleAttributedModel)
    func setDocumentType(_ viewModel: IBChipsViewModel)
    func showEmptyView()
    func removeEmptyView()
    func showInDeliveryAlert()
    func setIsLoadingList(_ value: Bool)
}

// sourcery: AutoMockable
protocol AccountStatementListPresenterDataSource: AnyObject {
    var ignorUpdateAccountItems: Bool { get set }
    var accountStatementItems: [AccountStatementListViewModel.Item] { get set }
    var bankReferencesItems: [BankReferencesListViewModel.Item] { get set }
    var canRequestNext: Bool { get }
    var canDocumentRequestNext: Bool { get }
    func clearAllItem()
    func clearContinuationToken()
    func getLinkAlertModel(_ state: DocumentType) -> String
    func fetch(objectFor view: AccountStatementListViewViewer, state: DocumentType)
    func updateItemsList(objectFor view: AccountStatementListViewViewer, state: DocumentType)
    func didTapItemAccountStatement(_ view: AccountStatementListViewViewer, item: AccountStatementListViewModel.Item)
    func didTapCertificateItem(_ view: AccountStatementListViewViewer, item: BankReferencesListViewModel.Item)
    func didTapRequestButton(_ view: AccountStatementListViewViewer)
    func handlePush(_ view: AccountStatementListViewViewer, with context: AccountStatementListFactory.Context)
    func fetchNext(_ view: AccountStatementListViewViewer)
    func preparePush(_ view: AccountStatementListViewViewer, context: AccountStatementListFactory.Context)
    func applicationDidBecomeActive(_ view: AccountStatementListViewViewer)
    func changeSelectChips(_ documentType: DocumentType)
    func setEmptyBankReferencesItemsList()
}

// sourcery: AutoMockable
protocol AccountStatementListPresenterViewer: AnyObject {
    func response(_ model: AccountStatementListModel)
    func responseReferencesList(bankReferences: [BankReferencesListModel.BankReferences], continuationToken: String)
    func response(nextPage model: AccountStatementListModel)
    func response(_ error: WAError)
    func response(currencies: [CurrencyResponseModel.Currency])
    func responseEmptyList(continuationToken: String)
    func responseDelete()
    func response(_ model: StatementTextsModel, statementId: String?, type: RequestTextsType)
    func responseModel(_ model: AccountStatementListByIdModel)
}

// sourcery: AutoMockable
protocol AccountStatementListInteractorDataSource: AnyObject {
    func fetch(objectFor presenter: AccountStatementListPresenterViewer, companyId: String, state: DocumentType)
    func fetchNext(_ presenter: AccountStatementListPresenterViewer, pageId: String?)
    func downloadFile(
        with id: String,
        progress: ((Progress) -> Void)?,
        completion: @escaping (Result<URL, WAError>) -> ()
    ) -> Cancellable?
    func certificateDownload(
        fileId: String,
        progress: ((Progress) -> Void)?,
        completion: @escaping ((Result<URL, WAError>) -> ())
    ) -> Cancellable?
    func statementDelete(_ presenter: AccountStatementListPresenterViewer, id: String)
    func getRemoteURL(_ presenter: AccountStatementListPresenterViewer, for fileId: String) -> String
    func getCurrencies(_ presenter: AccountStatementListPresenterViewer)
    func getBankReferencesList(objectFor presenter: AccountStatementListPresenterViewer, companyId: String, continuationToken: String?)
    func deleteCertificate(objectFor presenter: AccountStatementListPresenterViewer, companyId: String, requestId: String)
    func statementListById(objectFor presenter: AccountStatementListPresenterViewer, companyId: String, statementId: String)
    func statementsTexts(
        _ presenter: AccountStatementListPresenterViewer,
        statementId: String?,
        type: RequestTextsType
    )
}

// sourcery: AutoMockable
protocol AccountStatementListInteractorViewer: AnyObject {
    func response(_ model: AccountStatementListModel)
    func response(_ error: WAError)
}

// sourcery: AutoMockable
protocol AccountStatementListRepositoryDataSource: AnyObject {
    func statementsList(
        companyId: String,
        nextId: String?,
        completion: @escaping ((Result<AccountStatementListResponseModel.Response, WAError>) -> ())
    )
    func statementDownload(
        fileId: String,
        progress: ((Progress) -> Void)?,
        completion: @escaping ((Result<URL, WAError>) -> ())
    ) -> Cancellable?
    func certificateDownload(
        fileId: String,
        progress: ((Progress) -> Void)?,
        completion: @escaping ((Result<URL, WAError>) -> ())
    ) -> Cancellable?
    func statementDelete(id: String, completion: @escaping ((Result<Void, WAError>) -> ()))
    func getBankReferencesList(
        companyId: String,
        continuationToken: String?,
        completion: @escaping (Result<BankReferencesListResponseModel.Response, WAError>) -> ()
    )
    func deleteCertificate(companyId: String, requestId: String, completion: @escaping ((Result<EmptyResponseModel.Response, WAError>) -> Void))
    func statementsTexts(
        statementId: String?,
        completion: @escaping ((Result<StatementTextResponseModel.Response, WAError>) -> ())
    )
    func statementsListById(
        companyId: String,
        statementId: String,
        completion: @escaping ((Result<AccountStatementListByIdResponseModel.Response, WAError>) -> ())
    )
}

// sourcery: AutoMockable
protocol AccountStatementListRouterProtocol {
    func openFilePreview(context: FilePreviewFactory.Context)
    func openStatementRequest(context: StatementRequestFactory.Context)
    func openShare(context: ShareFactory.Context)
}

// MARK: Структуры
enum DocumentType {
    case accountStatement
    case referenceDocument
}

enum RequestTextsType {
    case fetch
    case inDelivery
    case error
}

struct DocumentTypeViewModel {
    var name: String
    var documentType: DocumentType
}

// MARK: - AccountStatementListViewModel
struct AccountStatementListViewModel {
    var items: [Item]

    struct Action {
        let text: String
        let action: ActionType
        let completion: (() -> Void)?

        enum ActionType {
            case cancel
            case normal
            case distructive
        }
    }

    struct Item: Equatable, Hashable {
        let id: String
        let fileId: String
        let title: String
        var subtitle: String
        let from: Date
        let to: Date
        let isPhysical: Bool
        let format: Format
        var state: State
        let orderDate: Date
        let currency: CurrencyType
        let trackNumber: String?
        let deliveryService: String?

        enum Format {
            case oneS
            case pdf
            case xlsx

            init(_ format: AccountStatementListModel.Statement.Format) {
                switch format {
                case .oneS:
                    self = .oneS
                case .pdf:
                    self = .pdf
                case .xlsx:
                    self = .xlsx
                }
            }

            var icon: ImageKey.Icons40 {
                switch self {
                case .pdf:
                    return .fileIconsThree
                case .xlsx:
                    return .exelFile
                case .oneS:
                    return .oneSFile
                }
            }

            var title: String {
                switch self {
                case .pdf:
                    return "PDF"
                case .xlsx:
                    return "Excel"
                case .oneS:
                    return "1C"
                }
            }

            var `extension`: String {
                switch self {
                case .pdf:
                    return "pdf"
                case .xlsx:
                    return "xlsx"
                case .oneS:
                    return "txt"
                }
            }
        }

        enum State: String, Decodable {
            case new = "New"
            case processing = "Processing"
            case ready = "Ready"
            case error = "Error"
            case physicalInDelivery = "PhysicalInDelivery"
            case physicalDelivered = "PhysicalDelivered"
            case physicalConfirmationNeeded = "PhysicalConfirmationNeeded"
            case physicalConfirmed = "PhysicalConfirmed"

            init(_ state: AccountStatementListModel.Statement.State) {
                switch state {
                case .new:
                    self = .new
                case .processing:
                    self = .processing
                case .ready:
                    self = .ready
                case .error:
                    self = .error
                case .physicalInDelivery:
                    self = .physicalInDelivery
                case .physicalConfirmationNeeded:
                    self = .physicalConfirmationNeeded
                case .physicalConfirmed:
                    self = .physicalConfirmed
                case .physicalDelivered:
                    self = .physicalDelivered
                }
            }
        }

        mutating func update(with result: Bool) {
            self.state = result ? .ready : .error
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.id == rhs.id && lhs.state == rhs.state
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    init(_ model: AccountStatementListModel, currencies: [CurrencyResponseModel.Currency]) {
        items = model.content.statements.map { statement in
            AccountStatementListUseCases.map(
                statement,
                currency: currencies.first(where: {
                    $0.currency == statement.currency.code
                })
            )
        }
    }
}

extension AccountStatementListViewModel.Item: FilePreviewItem {
    var fileName: String? {
        return ""
    }

    var fileUrl: URL? {
        return nil
    }
}

struct TitleSubtitleAttributedModel {
    let title: String
    let subTitle: NSAttributedString
}

// MARK: - AccountStatementListModel
struct AccountStatementListModel {
    var content: Content

    struct Content {
        var statements: [Statement]
        var nextId: String?

        init(_ content: AccountStatementListResponseModel.Response) {
            statements = content.statements.map({ .init($0) })
            nextId = content.nextId
        }
        
        mutating func update(_ content: Self) {
            statements.append(contentsOf: content.statements)
            nextId = content.nextId
        }
    }

    mutating func update(_ model: Self) {
        content.update(model.content)
    }

    init(_ content: AccountStatementListModel.Content) {
        self.content = content
    }

    init(_ content: AccountStatementListResponseModel.Response) {
        self.content = .init(content)
    }

    struct Statement: Equatable {
        let id: String
        let title: String
        let requestDate: Date
        let fileId: String
        let from: Date
        let to: Date
        let isPhysical: Bool
        let trackNumber: String?
        let deliveryService: String?
        let format: Format
        let state: State
        let currency: CurrencyType

        enum Format {
            case oneS
            case pdf
            case xlsx

            init(_ format: AccountStatementListResponseModel.Statement.Format) {
                switch format {
                case .oneS:
                    self = .oneS
                case .pdf:
                    self = .pdf
                case .xlsx:
                    self = .xlsx
                }
            }
        }

        enum State: String, Decodable {
            case new
            case processing
            case ready
            case error
            case physicalInDelivery
            case physicalDelivered
            case physicalConfirmationNeeded
            case physicalConfirmed

            init(_ state: AccountStatementListResponseModel.Statement.Status) {
                switch state {
                case .new:
                    self = .new
                case .processing:
                    self = .processing
                case .ready:
                    self = .ready
                case .error:
                    self = .error
                case .physicalInDelivery:
                    self = .physicalInDelivery
                case .physicalConfirmationNeeded:
                    self = .physicalConfirmationNeeded
                case .physicalConfirmed:
                    self = .physicalConfirmed
                case .physicalDelivered:
                    self = .physicalDelivered
                }
            }
        }

        init(_ statement: AccountStatementListResponseModel.Statement) {
            id = statement.id
            requestDate = statement.orderDate
            from = statement.from
            to = statement.to
            fileId = statement.fileId
            format = .init(statement.type)
            state = .init(statement.status)
            currency = statement.currencyCode
            title = statement.title
            isPhysical = statement.isPhysical
            trackNumber = statement.trackNumber
            deliveryService = statement.deliveryService
        }

        static func == (lhs: Statement, rhs: Statement) -> Bool {
            return lhs.id == rhs.id
        }
    }
}

// MARK: - BankReferencesListModel
struct BankReferencesListModel {
    var content: Content

    init(_ content: BankReferencesListResponseModel.ReferencesList) {
        self.content = .init(content)
    }

    struct Content {
        var bankReferences: [BankReferences]
        var continuationToken: String?

        init(_ content: BankReferencesListResponseModel.ReferencesList) {
            bankReferences = content.bankReferencesRequests.map(BankReferences.init)
            continuationToken = content.continuationToken
        }
    }

    struct BankReferences: Equatable {
        let referenceCode: String
        let requestId: String
        let name: String
        let subTitle: String
        let requestDate: String?
        let status: BankReferencesStatus
        let fileId: String?
        let referenceType: ReferenceType
        let scopeType: String?
        let content: ReferencesContentModel
        let deliveryInfoModel: DeliveryInfo
        let accountNumber: String?
        
        init(_ model: BankReferencesListResponseModel.ReferencesList.BankReferencesRequests) {
            referenceCode = model.referenceCode
            requestId = model.requestId
            name = model.name
            subTitle = model.subTitle
            requestDate = model.requestDate
            status = .init(model.status)
            fileId = model.fileId
            referenceType = .init(model.referenceType)
            scopeType = model.scopeType
            content = model.content
            deliveryInfoModel = .init(model.deliveryInfoModel)
            accountNumber = model.accountNumber
        }
        
        enum ReferenceType: String, Decodable {
            case digital = "Digital"
            case paper = "Paper"
            
            init(_ content: BankReferencesListResponseModel.ReferencesList.BankReferencesRequests.ReferenceType) {
                switch content {
                case .digital:
                    self = .digital
                case .paper:
                    self = .paper
                }
            }
        }

        enum BankReferencesStatus: String, Decodable {
            case processing = "Processing"
            case inDelivery = "InDelivery"
            case сompleted = "Completed"
            case error = "Error"
            
            init(_ content: BankReferencesListResponseModel.ReferencesList.BankReferencesRequests.BankReferencesStatus) {
                switch content {
                case .error:
                    self = .error
                case .сompleted:
                    self = .сompleted
                case .processing:
                    self = .processing
                case .inDelivery:
                    self = .inDelivery
                }
            }
        }

        struct DeliveryInfo: Encodable {
            var fio: String?
            var phone: String?
            var address: String?
            var fiasId: String?
            
            init(_ content: BankReferencesListResponseModel.ReferencesList.BankReferencesRequests.DeliveryInfo) {
                fio = content.fio
                phone = content.phone
                address = content.address
                fiasId = content.fiasId
            }
        }
        
        static func == (lhs: BankReferencesListModel.BankReferences, rhs: BankReferencesListModel.BankReferences) -> Bool {
            return lhs.requestId == rhs.requestId
        }
    }
}

// MARK: - BankReferencesListViewModel
struct BankReferencesListViewModel {
    var items: [Item]

    init(_ model: BankReferencesListModel) {
        items = model.content.bankReferences.map { statement in
            AccountStatementListUseCases.bankReferencesMap(statement)
        }
    }

    struct Item: Equatable, Hashable {
        
        static func == (lhs: BankReferencesListViewModel.Item, rhs: BankReferencesListViewModel.Item) -> Bool {
            return lhs.requestId == rhs.requestId
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(requestId)
        }

        let referenceCode: String
        let requestId: String
        let name: String
        let subTitle: String
        let requestDate: String?
        let status: BankReferencesStatus
        let fileId: String?
        let referenceType: ReferenceType
        let scopeType: String?
        let content: ReferencesContentModel
        let deliveryInfoModel: DeliveryInfo
        let accountNumber: String?
        
        enum BankReferencesStatus: String, Decodable {
            case processing = "Processing"
            case inDelivery = "InDelivery"
            case сompleted = "Completed"
            case error = "Error"
            
            init(_ content: BankReferencesListModel.BankReferences.BankReferencesStatus) {
                switch content {
                case .error:
                    self = .error
                case .сompleted:
                    self = .сompleted
                case .processing:
                    self = .processing
                case .inDelivery:
                    self = .inDelivery
                }
            }
        }
        
        enum ReferenceType: String, Decodable {
            case digital = "Digital"
            case paper = "Paper"
            
            init(_ content: BankReferencesListModel.BankReferences.ReferenceType) {
                switch content {
                case .digital:
                    self = .digital
                case .paper:
                    self = .paper
                }
            }
        }

        struct DeliveryInfo: Encodable {
            var fio: String?
            var phone: String?
            var address: String?
            var fiasId: String?
            
            init(_ content: BankReferencesListModel.BankReferences.DeliveryInfo) {
                fio = content.fio
                phone = content.phone
                address = content.address
                fiasId = content.fiasId
            }
        }
    }
}

extension BankReferencesListViewModel.Item: FilePreviewItem {
    var fileName: String? {
        return ""
    }

    var fileUrl: URL? {
        return nil
    }
}

// MARK: - AccountStatementListByIdModel
struct AccountStatementListByIdModel {
    var content: Content
    let title: String?
    let id: String
    let orderDate: Date
    let fileId: String
    let status: Status
    let type: Format
    let from: Date
    let to: Date
    let orderByClient: Bool
    let currencyCode: CurrencyType
    let isPhysical: Bool
    let fileSize: Int?
    let pageCount: Int?
    let price: Int?
    let trackNumber: String?
    let deliveryService: String?

    struct Content {
        let messages: Messages
        let deliveryFooter: String?
        let deliveryHeader: String?
        let paperFooter: String?
        let pagePrice: Int?
        let minimalPrice: Int?

        init(_ content: AccountStatementListByIdResponseModel.Content) {
            self.messages = .init(content.messages)
            self.deliveryFooter = content.deliveryFooter
            self.deliveryHeader = content.deliveryHeader
            self.paperFooter = content.paperFooter
            self.pagePrice = content.pagePrice
            self.minimalPrice = content.minimalPrice
        }
        
        struct Messages: Decodable {
            let error: TitleSubTitle
            let paperPricing: TitleSubTitle
            let startedProcessing: TitleSubTitle
            let paperStartedProcessing: TitleSubTitle
            let processing: TitleSubTitle
            let paperProcessing: TitleSubTitle
            let paperConfirmed: TitleSubTitle
            let paperInDelivery: TitleSubTitle

            init(_ content: AccountStatementListByIdResponseModel.Content.Messages) {
                self.error = .init(content.error)
                self.paperPricing = .init(content.paperPricing)
                self.startedProcessing = .init(content.startedProcessing)
                self.paperStartedProcessing = .init(content.paperStartedProcessing)
                self.processing = .init(content.processing)
                self.paperProcessing = .init(content.paperProcessing)
                self.paperConfirmed = .init(content.paperConfirmed)
                self.paperInDelivery = .init(content.paperInDelivery)
            }

            struct TitleSubTitle: Decodable {
                let title: String?
                let subTitle: String?
                
                init(_ content: AccountStatementListByIdResponseModel.Content.Messages.TitleSubTitle) {
                    self.title = content.title
                    self.subTitle = content.subTitle
                }
            }
        }
    }

    init(_ content: AccountStatementListByIdResponseModel.Response) {
        self.content = .init(content.content)
        self.title = content.title
        self.id = content.id
        self.orderDate = content.orderDate
        self.fileId = content.fileId
        self.status = .init(content.status)
        self.type = .init(content.type)
        self.from = content.from
        self.to = content.to
        self.orderByClient = content.orderByClient
        self.currencyCode = content.currencyCode
        self.isPhysical = content.isPhysical
        self.fileSize = content.fileSize
        self.pageCount = content.pageCount
        self.price = content.price
        self.trackNumber = content.trackNumber
        self.deliveryService = content.deliveryService
    }
    
    enum Format {
        case oneS
        case pdf
        case xlsx
        
        init(_ format: AccountStatementListByIdResponseModel.Format) {
            switch format {
            case .oneS:
                self = .oneS
            case .pdf:
                self = .pdf
            case .xlsx:
                self = .xlsx
            }
        }
    }
    
    enum Status: String, Decodable {
        case new = "Start"
        case processing = "Processing"
        case ready = "Ready"
        case error = "Error"
        case physicalInDelivery = "PhysicalInDelivery"
        case physicalConfirmationNeeded = "PhysicalConfirmationNeeded"
        case physicalConfirmed = "PhysicalConfirmed"
        case physicalDelivered = "PhysicalDelivered"
        
        init(_ format: AccountStatementListByIdResponseModel.Status) {
            switch format {
            case .error:
                self = .error
            case .processing:
                self = .processing
            case .ready:
                self = .ready
            case .new:
                self = .new
            case .physicalInDelivery:
                self = .physicalInDelivery
            case .physicalDelivered:
                self = .physicalDelivered
            case .physicalConfirmationNeeded:
                self = .physicalConfirmationNeeded
            case .physicalConfirmed:
                self = .physicalConfirmed
            }
        }
    }

    enum State: String, Decodable {
        case new
        case processing
        case ready
        case error
        case physicalInDelivery
        case physicalDelivered
        case physicalConfirmationNeeded
        case physicalConfirmed
        
        init(_ state: AccountStatementListByIdResponseModel.Status) {
            switch state {
            case .new:
                self = .new
            case .processing:
                self = .processing
            case .ready:
                self = .ready
            case .error:
                self = .error
            case .physicalInDelivery:
                self = .physicalInDelivery
            case .physicalConfirmationNeeded:
                self = .physicalConfirmationNeeded
            case .physicalConfirmed:
                self = .physicalConfirmed
            case .physicalDelivered:
                self = .physicalDelivered
            }
        }
    }
}

// MARK: - StatementTextsModel
struct StatementTextsModel {
    var content: Content

    struct Content {
        let messages: Messages
        let deliveryFooter: String?
        let deliveryHeader: String?
        let paperFooter: String?
        let pagePrice: Int?
        let minimalPrice: Int?

        init(_ content: StatementTextResponseModel.Content) {
            self.messages = .init(content.messages)
            self.deliveryFooter = content.deliveryFooter
            self.deliveryHeader = content.deliveryHeader
            self.paperFooter = content.paperFooter
            self.pagePrice = content.pagePrice
            self.minimalPrice = content.minimalPrice
        }
        
        struct Messages: Decodable {
            let error: TitleSubTitle?
            let paperPricing: TitleSubTitle
            let startedProcessing: TitleSubTitle
            let paperStartedProcessing: TitleSubTitle
            let processing: TitleSubTitle
            let paperProcessing: TitleSubTitle
            let paperConfirmed: TitleSubTitle
            let paperInDelivery: TitleSubTitle?

            init(_ content: StatementTextResponseModel.Content.Messages) {
                self.error = .init(content.error)
                self.paperPricing = .init(content.paperPricing)
                self.startedProcessing = .init(content.startedProcessing)
                self.paperStartedProcessing = .init(content.paperStartedProcessing)
                self.processing = .init(content.processing)
                self.paperProcessing = .init(content.paperProcessing)
                self.paperConfirmed = .init(content.paperConfirmed)
                self.paperInDelivery = .init(content.paperInDelivery)
            }

            struct TitleSubTitle: Decodable {
                let title: String?
                let subTitle: String?
                
                init(_ content: StatementTextResponseModel.Content.Messages.TitleSubTitle?) {
                    self.title = content?.title
                    self.subTitle = content?.subTitle
                }
            }
        }
    }

    init(_ content: StatementTextResponseModel.Response) {
        self.content = .init(content.content)
    }
}

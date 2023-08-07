//
//  AccountStatementListInteractor.swift
//  OpenBusiness
//
//  Created by Andrey Samchenko on 02.05.2023.
//

import UIKit

class AccountStatementListInteractor {

    private weak var viewer: AccountStatementListPresenterViewer?
    private var dataSource: AccountStatementListRepositoryDataSource?
    private var companyId: String?
    private var retryCount: Int = 2

    init(dataSource repository: AccountStatementListRepositoryDataSource?) {
        self.dataSource = repository
    }

    deinit {
        Log.t("deinit \(String(describing: type(of: self)))")
    }
}

// MARK: - AccountStatementListInteractorDataSource
extension AccountStatementListInteractor: AccountStatementListInteractorDataSource {

    func fetch(objectFor presenter: AccountStatementListPresenterViewer, companyId: String, state: DocumentType) {
        viewer = presenter
        self.companyId = companyId
        switch state {
        case .accountStatement:
            fetchNext(presenter, pageId: nil)
        case .referenceDocument:
            getBankReferencesList(objectFor: presenter, companyId: companyId, continuationToken: nil)
        }
    }

    func fetchNext(_ presenter: AccountStatementListPresenterViewer, pageId: String?) {
        guard let companyId = companyId else { return }
        dataSource?.statementsList(companyId: companyId, nextId: pageId) { [weak self] result in
            switch result {
            case .success(let response):
                let model = AccountStatementListModel(response)
                if pageId == nil {
                    self?.viewer?.response(model)
                } else {
                    self?.viewer?.response(nextPage: model)
                }
            case .failure(let error):
                self?.viewer?.response(error)
            }
        }
    }

    func downloadFile(
        with id: String,
        progress: ((Progress) -> Void)?,
        completion: @escaping (Result<URL, WAError>) -> ()
    ) -> Cancellable? {
        return dataSource?.statementDownload(fileId: id, progress: progress, completion: completion)
    }
        
    func certificateDownload(
        fileId: String,
        progress: ((Progress) -> Void)?,
        completion: @escaping ((Result<URL, WAError>) -> ())
    ) -> Cancellable? {
        return dataSource?.certificateDownload(fileId: fileId, progress: progress, completion: completion)
    }

    func statementDelete(_ presenter: AccountStatementListPresenterViewer, id: String) {
        dataSource?.statementDelete(id: id) { [weak self] result in
            switch result {
            case .success:
                self?.fetchNext(presenter, pageId: nil)
            case .failure(let error):
                self?.viewer?.response(error)
            }
        }
    }

    func getRemoteURL(_ presenter: AccountStatementListPresenterViewer, for fileId: String) -> String {
        return Constants.backendURL + "/statements/download/" + fileId
    }

    func getBankReferencesList(
        objectFor presenter: AccountStatementListPresenterViewer,
        companyId: String,
        continuationToken: String?
    ) {
        dataSource?.getBankReferencesList(companyId: companyId, continuationToken: continuationToken, completion: { result in
            switch result {
            case .success(let response):
                if response.bankReferencesRequests.isNotEmpty {
                    
                    presenter.responseReferencesList(
                        bankReferences: response.bankReferencesRequests.map(BankReferencesListModel.BankReferences.init),
                        continuationToken: response.continuationToken
                    )
                } else {
                    presenter.responseEmptyList(continuationToken: response.continuationToken)
                }
            case .failure(let error):
                self.viewer?.response(error)
            }
        })
    }
    
    func deleteCertificate(objectFor presenter: AccountStatementListPresenterViewer, companyId: String, requestId: String) {
        dataSource?.deleteCertificate(companyId: companyId, requestId: requestId, completion: { result in
            switch result {
            case .success:
                presenter.responseDelete()
            case .failure(let error):
                presenter.response(error)
            }
        })
    }

    func statementsTexts(_ presenter: AccountStatementListPresenterViewer, statementId: String?, type: RequestTextsType) {
        dataSource?.statementsTexts(statementId: statementId) { result in
            switch result {
            case .success(let value):
                presenter.response(
                    .init(value),
                    statementId: statementId,
                    type: type
                )
            case .failure(let error):
                presenter.response(error)
            }
        }
    }
    
    func statementListById(objectFor presenter: AccountStatementListPresenterViewer, companyId: String, statementId: String) {
        dataSource?.statementsListById(companyId: companyId, statementId: statementId) { result in
            switch result {
            case .success(let value):
                presenter.responseModel(.init(value))
            case .failure(let error):
                presenter.response(error)
            }
        }
    }
}

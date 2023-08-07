//
//  AccountStatementListRepository.swift
//  OpenBusiness
//
//  Created by Andrey Samchenko on 02.05.2023.
//

import UIKit

class AccountStatementListRepository {

    @ProvidedService private var transactionService: TransactionServiceDataSource?
    @ProvidedService private var processingService: ProcessingServiceDataSource?
    @ProvidedService private var bankReferenceService: BankReferenceServiceDataSource?

    init() {
    }

    deinit {
        Log.t("deinit \(String(describing: type(of: self)))")
    }
}

extension AccountStatementListRepository: AccountStatementListRepositoryDataSource {

    func statementsList(
        companyId: String,
        nextId: String?,
        completion: @escaping ((Result<AccountStatementListResponseModel.Response, WAError>) -> ())
    ) {
        transactionService?.statementsList(companyId: companyId, nextId: nextId, completion: completion)
    }

    func statementDownload(
        fileId: String,
        progress: ((Progress) -> Void)?,
        completion: @escaping ((Result<URL, WAError>) -> ())
    ) -> Cancellable? {
        return transactionService?.statementDownload(fileId: fileId, progress: progress, completion: completion)
    }

    func certificateDownload(
        fileId: String,
        progress: ((Progress) -> Void)?,
        completion: @escaping ((Result<URL, WAError>) -> ())
    ) -> Cancellable? {
        return bankReferenceService?.certificateDownload(fileId: fileId, progress: progress, completion: completion)
    }
    
    func statementDelete(id: String, completion: @escaping ((Result<Void, WAError>) -> ())) {
        transactionService?.statementDelete(id: id, completion: completion)
    }

    func getBankReferencesList(companyId: String, continuationToken: String?, completion: @escaping (Result<BankReferencesListResponseModel.Response, WAError>) -> ()) {
        bankReferenceService?.getBankReferencesList(companyId: companyId, continuationToken: continuationToken, completion: completion)
    }
    
    func deleteCertificate(companyId: String, requestId: String, completion: @escaping ((Result<EmptyResponseModel.Response, WAError>) -> Void)) {
        bankReferenceService?.deleteCertificate(companyId: companyId, requestId: requestId, completion: completion)
    }
    
    func statementsTexts(
        statementId: String?,
        completion: @escaping ((Result<StatementTextResponseModel.Response, WAError>) -> ())
    ) {
        transactionService?.statementsTexts(statementId: statementId, completion: completion)
    }
    
    func statementsListById(
        companyId: String,
        statementId: String,
        completion: @escaping ((Result<AccountStatementListByIdResponseModel.Response, WAError>) -> ())
    ) {
        transactionService?.statementsListById(companyId: companyId, statementId: statementId, completion: completion)
    }
}

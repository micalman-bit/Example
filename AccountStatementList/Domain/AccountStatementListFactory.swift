//
//  AccountStatementListFactory.swift
//  OpenBusiness
//
//  Created by Andrey Samchenko on 02.05.2023.
//

import Foundation
import RouteComposer

class AccountStatementListFactory: Factory {

    func build(with context: Context) throws -> AccountStatementListViewController {
        let repository = AccountStatementListRepository()
        let interactor = AccountStatementListInteractor(dataSource: repository)
        let presenter = AccountStatementListPresenter(dataSource: interactor, context: context)
        return AccountStatementListViewController(dataSource: presenter)
    }

    typealias ViewController = AccountStatementListViewController

    enum Context {
        case open(companyId: String)
        case showStatement(companyId: String, statementId: String, isSuccess: Bool)
        case showSuccess(isSuccess: Bool)
    }
}

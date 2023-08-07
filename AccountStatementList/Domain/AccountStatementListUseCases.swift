//
//  AccountStatementListUseCases.swift
//  OpenBusiness
//
//  Created by Andrey Samchenko on 26/07/2023.
//

import UIFramework
import Markdown
import UIKit

enum AccountStatementListUseCases {

    static func map(
        _ item: AccountStatementListModel.Statement,
        currency: CurrencyResponseModel.Currency?
    ) -> AccountStatementListViewModel.Item {
        let format = AccountStatementListViewModel.Item.Format(item.format)
        let subtitle = String(
            format: LocalizableKey.AccountStatement.List.itemDescription.localized(),
            item.from.string(withFormat: .custom("dd.MM.yyyy"), timeZone: .gmt),
            item.to.string(withFormat: .custom("dd.MM.yyyy"), timeZone: .gmt),
            format.title
        )
        return AccountStatementListViewModel.Item(
            id: item.id,
            fileId: item.fileId,
            title: item.title,
            subtitle: subtitle,
            from: item.from,
            to: item.to,
            isPhysical: item.isPhysical,
            format: .init(item.format),
            state: .init(item.state),
            orderDate: item.requestDate,
            currency: item.currency,
            trackNumber: item.trackNumber,
            deliveryService: item.deliveryService
        )
    }

    static func bankReferencesMap(
        _ item: BankReferencesListModel.BankReferences
    ) -> BankReferencesListViewModel.Item {
        return BankReferencesListViewModel.Item(
            referenceCode: item.referenceCode,
            requestId: item.requestId,
            name: item.name,
            subTitle: item.subTitle,
            requestDate: item.requestDate,
            status: .init(item.status),
            fileId: item.fileId,
            referenceType: .init(item.referenceType),
            scopeType: item.scopeType,
            content: item.content,
            deliveryInfoModel: .init(item.deliveryInfoModel),
            accountNumber: item.accountNumber
        )
    }

    static func convertStringToAttributedTextWithUnderscore(
        with text: String,
        rangeStrung: String
    ) -> NSAttributedString {
        let stringWithoutHTML = Document(parsing: text).format().replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
        let stringWithoutBrackets = stringWithoutHTML.replacingOccurrences(of: "[{}]", with: "", options: .regularExpression, range: nil)
        let attributedString = NSMutableAttributedString(string: stringWithoutBrackets)
        let range = (stringWithoutBrackets as NSString).range(of: rangeStrung)
        attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        return attributedString
    }

    static func getShareItems(
        with urlPath: String,
        item: AccountStatementListViewModel.Item,
        currency: CurrencyResponseModel.Currency?
    ) -> [ShareItem] {
        let currencyText = currency?.spellingVariants?.noun.plural.prepositional?.lowercased() ?? item.currency.code
        let text = String(
            format: LocalizableKey.AccountStatement.List.shareText.localized(),
            currencyText,
            item.orderDate.string(withFormat: .custom("dd MMMM"), timeZone: .gmt),
            urlPath
        )
        return [text] as [ShareItem]
    }

    static func getAccounts() -> [StatementRequestFactory.Context.Account] {
        guard let bankAccounts = CacheManager.shared.getCache(
            name: .bankAccounts,
            Array<CompanyDetailResponseModel.Response.BankAccount>.self
        ), !bankAccounts.isEmpty
        else {
            Log.i("bank accounts not found", tag: .statement(situation: .guardWorked), isRemoteEvent: true)
            return []
        }
        return bankAccounts.map({
            .init(
                number: $0.account,
                title: $0.currencyName ?? $0.currencyCode.accountCurrencyName,
                currencyType: $0.currencyCode,
                openedOn: $0.openedOn ?? StatementRequestUseCases.registrationDate ?? Date(),
                default: $0.main
            )
        })
    }
}

fileprivate extension CurrencyType {
    var accountCurrencyName: String {
        switch self {
        case .rub:
            return "Рублёвый"
        case .any(let code, _, _):
            return code
        }
    }
    var accountCurrencyDP: String {
        switch self {
        case .rub:
            return "рублях"
        case .any(let code, _, _):
            return code
        }
    }
}

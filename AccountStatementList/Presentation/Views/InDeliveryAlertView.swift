//
//  InDeliveryAlertView.swift
//  ProjectVesta
//
//  Created by Andrey Samchenko on 02.05.2023.
//

import UIFramework
import UIKit

class InDeliveryAlertView: UIView {
    
    lazy private(set) var titleLabel: Label = {
        $0.numberOfLines = 0
        $0.lineBreakMode = .byWordWrapping
        return $0
    }(Label(font: .h2))

    lazy private(set) var subTitleLabel: Label = {
        $0.numberOfLines = 0
        $0.lineBreakMode = .byWordWrapping
        $0.adjustsFontForContentSizeCategory = true
        $0.isUserInteractionEnabled = true
        return $0
    }(Label(font: .textLG))

    public lazy var closeButton: IBButton = {
        return $0
    }(IBButton(
        text: LocalizableKey.Profile.Referral.alertActionTitle.localized(),
        kind: .md,
        style: .primary
    ))
    
    private lazy var buttonStack: UIStackView = {
        $0.spacing = 12
        $0.axis = .horizontal
        $0.distribution = .fillEqually
        return $0
    }(UIStackView(arrangedSubviews: [closeButton]))

    private var link: String = ""
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleLinkTap(_:)))
        subTitleLabel.addGestureRecognizer(tapGestureRecognizer)

        addSubviews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func fill(
        title: String,
        subTitle: NSAttributedString,
        link: String
    ) {
        self.link = link
        titleLabel.text = title
        subTitleLabel.attributedText = subTitle
        subTitleLabel.font = Typegraphy.textLG.getFont()
    }
    
    private func addSubviews() {
        addSubviews(titleLabel, subTitleLabel, buttonStack)
    }
    
    private func setupConstraints() {
        titleLabel.snp.makeConstraints {
            $0.bottom.equalTo(subTitleLabel.snp.top).inset(-16)
            $0.left.right.equalToSuperview().inset(24)
        }
        
        subTitleLabel.snp.makeConstraints {
            $0.bottom.equalTo(buttonStack.snp.top).inset(-24)
            $0.left.right.equalToSuperview().inset(24)
        }
        
        buttonStack.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(12)
            $0.height.equalTo(72)
            $0.left.right.equalToSuperview().inset(12)
        }
    }

    private func sendMetrics(actionType: AnalyticsEvents.ActionType) {
        AnalyticsManager.shared.track(
            event: TemplateEvent(
                name: AnalyticsEvents.AEventType.inAppAction.rawValue,
                params: AnalyticsEvents.BaseModel(actionType: actionType)
            ),
            serviceTypes: [.exponea]
        )
    }

    @objc func handleLinkTap(_ sender: UITapGestureRecognizer) {
        guard let url = URL(string: link) else { return }
        sendMetrics(actionType: .redirectDeliveryPartnerService)
        UIApplication.shared.open(url)
    }
}

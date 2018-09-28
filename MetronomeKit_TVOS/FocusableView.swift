//
//  FocusableView.swift
//  MetronomeKit_TVOS
//
//  Created by xiangyu sun on 9/28/18.
//  Copyright © 2018 xiangyu sun. All rights reserved.
//

import UIKit

class FocusableView: UIView {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    override var canBecomeFocused: Bool{
        return true
    }
}

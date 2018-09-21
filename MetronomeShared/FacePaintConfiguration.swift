//
//  FacePaintConfiguration.swift
//  Metronome
//
//  Created by xiangyu sun on 9/17/18.
//  Copyright © 2018 xiangyu sun. All rights reserved.
//

import Foundation

public struct FacePaintConfiguration {
    public let scale: CGFloat
    public let contentFrame: CGRect
    public let arcWidth: CGFloat
    public let arcGapAngle: CGFloat
    public let foregroundFillColor: CGColor
    public let firstElementFillColor: CGColor
    public let backgroundFillColor: CGColor
    
    public init(scale: CGFloat, contentFrame: CGRect, arcWidth: CGFloat = 8, arcGapAngle: CGFloat = (16.0 * .pi) / 180.0,
                foregroundFillColor: CGColor = UIColor(red: 0.301, green: 0.556, blue: 0.827, alpha: 1.0).cgColor,
                firstElementFillColor: CGColor = UIColor(red: 0.301, green: 0.729, blue: 0.478, alpha: 1.0).cgColor,
                backgroundFillColor: CGColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0).cgColor) {
        
        self.scale = scale
        self.contentFrame = contentFrame
        self.arcGapAngle = arcGapAngle
        self.arcWidth = arcWidth
        self.foregroundFillColor = foregroundFillColor
        self.firstElementFillColor = firstElementFillColor
        self.backgroundFillColor = backgroundFillColor
    }
}

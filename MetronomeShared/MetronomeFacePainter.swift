//
//  MetronomeFacePainter.swift
//  Metronome
//
//  Created by xiangyu sun on 9/17/18.
//  Copyright © 2018 xiangyu sun. All rights reserved.
//

import Foundation

public final class MetronomeFacePainter {

    let paintConfiguration: FacePaintConfiguration
    let imageAccessQueue = DispatchQueue(label: "ForegroudnImage", qos: .userInitiated)

    private(set) var foregroundArcArray = [UIImage]()

    var center: CGPoint {
        return CGPoint(x: paintConfiguration.contentFrame.size.width / 2.0, y: paintConfiguration.contentFrame.size.height / 2.0)
    }
    var radius: CGFloat {
        return min(self.paintConfiguration.contentFrame.size.width / 2.0, paintConfiguration.contentFrame.size.height / 2.0) - (paintConfiguration.arcWidth / 2.0)
    }
    
    public subscript(index: Int) -> UIImage {
        get {
            return imageAccessQueue.sync {
                return foregroundArcArray[index]
            }
        }
        set(newValue) {
            imageAccessQueue.sync {
                foregroundArcArray[index] = newValue
            }
        }
    }

    public init(faceConfiguration: FacePaintConfiguration) {
        paintConfiguration = faceConfiguration
    }
    
    public func drawArchsWith(meter: Int, updateBackground: (UIImage) -> Void)  {
        
        let stepAngle = CGFloat(((2 * .pi) / Double(meter))) - paintConfiguration.arcGapAngle
        
        if let backgroundImage = backgroundImage(meter: meter, stepAngle: stepAngle) {
            updateBackground(backgroundImage)
        }
        
        redrawForegroundRing(meter: meter, stepAngle: stepAngle)
    }
    

    func newDonutArcWithCenter(centerPoint: CGPoint, withRadius radius: CGFloat, fromStartAngle startAngle: CGFloat, toEndAngle endAngle: CGFloat) -> CGPath {
        let arc = CGMutablePath()
        arc.addArc(center: centerPoint, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false, transform: CGAffineTransform.identity)
        
        return arc.copy(strokingWithWidth: paintConfiguration.arcWidth, lineCap: .square, lineJoin: .miter, miterLimit: 10)
    }
    
    func backgroundImage(meter: Int, stepAngle: CGFloat) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(paintConfiguration.contentFrame.size, false, paintConfiguration.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        var startAngle = (paintConfiguration.arcGapAngle / 2.0) - (1.5 * .pi/2)
        context.beginPath()
        for _ in (0..<meter) {
            let strokedArc = newDonutArcWithCenter(centerPoint: center, withRadius: radius, fromStartAngle: startAngle, toEndAngle: startAngle + stepAngle)
            
            context.addPath(strokedArc)
            startAngle += stepAngle + paintConfiguration.arcGapAngle
        }
        
        
        context.closePath()
        context.setFillColor(paintConfiguration.backgroundFillColor)
        context.fillPath()
        
        var backgroundImage: UIImage?
        if let cgBackgroundImage = context.makeImage()  {
            backgroundImage = UIImage(cgImage: cgBackgroundImage)
        }
        
        UIGraphicsEndImageContext()
        
        return backgroundImage
    }
    
    func redrawForegroundRing(meter: Int, stepAngle: CGFloat) {
        imageAccessQueue.sync {
            foregroundArcArray.removeAll()
        }
        
        foregroundArcArray.reserveCapacity(meter)
        
        var startAngle = (paintConfiguration.arcGapAngle / 2.0) - (1.5 * .pi/2)
        
        for index in (0..<meter) {
            UIGraphicsBeginImageContextWithOptions(paintConfiguration.contentFrame.size, false, paintConfiguration.scale)
            
            guard let context = UIGraphicsGetCurrentContext() else {
                continue
            }
            
            context.beginPath()
            let strokedArc = newDonutArcWithCenter(centerPoint: center, withRadius: radius, fromStartAngle: startAngle, toEndAngle: startAngle + stepAngle)
            
            context.addPath(strokedArc)
            
            context.closePath()
            
            if (index == 0) {
                context.setFillColor(paintConfiguration.firstElementFillColor)
            } else {
                context.setFillColor(paintConfiguration.foregroundFillColor)
            }
            context.fillPath()
            
            guard let cgImage = context.makeImage() else {
                continue
            }
            
            let foregroundImage = UIImage(cgImage: cgImage)
            imageAccessQueue.sync {
                self.foregroundArcArray.append(foregroundImage)
            }
            
            UIGraphicsEndImageContext()
            
            startAngle += stepAngle + paintConfiguration.arcGapAngle
        }
    }
}

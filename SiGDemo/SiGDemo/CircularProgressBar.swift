//
//  CircularProgressBar.swift
//  SiGDemo
//
//  Created by Mark Zieg on 12/28/18.
//
//  Adapted from:
//      CircularLoaderLBTA
//      Created by Brian Voong on 12/8/17.
//      Copyright © 2017 Lets Build That App. All rights reserved.

import Foundation
import UIKit

let cicelyGreen     = UIColor(red: (73.0 / 255.0), green: (159.0 / 255.0), blue: (103.0 / 255.0), alpha: 1.0)
let cicelyBlue      = UIColor(red: (66.0 / 255.0), green: (142.0 / 255.0), blue: (181.0 / 255.0), alpha: 1.0)
let cicelyLightBlue = UIColor(red: (156.0 / 255.0), green: (216.0 / 255.0), blue: (246.0 / 255.0), alpha: 1.0)

class CircularProgressBar
{
    var view: UIView
    
    let shapeLayer = CAShapeLayer()
    let trackLayer = CAShapeLayer()

    let percentageLabel: UILabel =
    {
        let label = UILabel()
        label.text = "Loading"
        label.textAlignment = .center
        label.font = UIFont.boldSystemFont(ofSize: 32)
        return label
    }()

    // call from ViewController's viewDidLoad()
    init(_ view: UIView)
    {
        self.view = view
    }
    
    func display()
    {
        view.addSubview(percentageLabel)
        
        percentageLabel.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        percentageLabel.center = view.center

        let circularPath = UIBezierPath(arcCenter: .zero, radius: 100, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true)

        // create the background track layer
        trackLayer.path = circularPath.cgPath
        trackLayer.strokeColor = UIColor.lightGray.cgColor
        trackLayer.lineWidth = 10
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.lineCap = CAShapeLayerLineCap.round
        trackLayer.position = view.center
        view.layer.addSublayer(trackLayer)

        // now create the progress bar ring
        shapeLayer.path = circularPath.cgPath
        shapeLayer.strokeColor = cicelyGreen.cgColor
        shapeLayer.lineWidth = 10
        shapeLayer.fillColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.8).cgColor
        shapeLayer.lineCap = CAShapeLayerLineCap.round
        shapeLayer.position = view.center
        shapeLayer.transform = CATransform3DMakeRotation(-CGFloat.pi / 2, 0, 0, 1)
        shapeLayer.strokeEnd = 0
        view.layer.addSublayer(shapeLayer)
    }
    
    func hide()
    {
        percentageLabel.removeFromSuperview()
        trackLayer.removeFromSuperlayer()
        shapeLayer.removeFromSuperlayer()
    }
    
    func updatePercentage(_ complete: Float)
    {
        let percentage = CGFloat(complete)
        DispatchQueue.main.async {
            self.percentageLabel.text = "\(Int(percentage * 100))%"
            self.shapeLayer.strokeEnd = percentage
        }
        print("CircularProgressBar.update: \(percentage)")
    }
    
    func animate_NOT_USED()
    {
        let basicAnimation = CABasicAnimation(keyPath: "strokeEnd")

        basicAnimation.toValue = 1 // 100% completion
        basicAnimation.duration = 2 // seconds
        
        basicAnimation.fillMode = CAMediaTimingFillMode.forwards
        basicAnimation.isRemovedOnCompletion = false
        
        shapeLayer.add(basicAnimation, forKey: "urSoBasic")
    }
}

//
//  TeachableMachine.swift
//  AIComponentKit
//
//  Created by David Kim on 10/22/24.
//  Copyright © 2024 Massachusetts Institute of Technology. All rights reserved.
//

import Foundation
import UIKit
import WebKit

fileprivate let TRANSFER_MODEL_PREFIX = "appinventor://teachable-machine/transfer/"
fileprivate let PERSONAL_MODEL_PREFIX = "appinventor://teachable-machine/personal/"

@objc open class TeachableMachine: BaseClassifier, LifecycleDelegate {
  public static let MODE_VIDEO = "Video"
  public static let MODE_IMAGE = "Image"
  public static let IMAGE_WIDTH = 500
  public static let ERROR_INVALID_INPUT_MODE = -6;

  private let logTag = "TeachableMachine"
  private let modelURL = "https://teachablemachine.withgoogle.com/models/"

  private var _inputMode = TeachableMachine.MODE_VIDEO
  private var _modelLink: String?
  private var _running = false
  private var _minClassTime: Int32 = 0

  @objc public init(_ container: ComponentContainer) {
    super.init(container, "teachable_machine", TRANSFER_MODEL_PREFIX, PERSONAL_MODEL_PREFIX)
  }

  @objc public override func Initialize() {
    super.Initialize()
    guard let webview = _webview else {
      print("\(logTag): WebViewer is not set")
      return
    }

    if let modelLink = _modelLink {
      webview.evaluateJavaScript("TeachableMachine.isLoaded = function() { return \"\(modelLink)\" },")
    } else {
      print("\(logTag): Model file is not provided")
    }
  }

  @objc public var ModelLink: String? {
    get {
      return _modelLink
    }
    set {
      guard let link = newValue else {
        print("\(logTag): Model Link is nil")
        return
      }
      print("\(logTag): Model Link: \(link)")
      if link.contains(modelURL) {
        _modelLink = link
      } else {
        print("\(logTag): Incorrect Model Link: The link should look like \(modelURL)")
      }
    }
  }

  open override func configureWebView(_ webview: WKWebView, _ extras: String? = nil) {
    let modelLink = _modelLink ?? ""
    super.configureWebView(webview, "isLoaded: function() { return \"\(modelLink)\" },\n")
  }

  @objc public var InputMode: String {
    get {
      return _inputMode
    }
    set {
      if newValue.caseInsensitiveCompare(TeachableMachine.MODE_VIDEO) == .orderedSame {
        _webview?.evaluateJavaScript("setInputMode(\"video\");", completionHandler: nil)
        _inputMode = TeachableMachine.MODE_VIDEO
      } else if newValue.caseInsensitiveCompare(TeachableMachine.MODE_IMAGE) == .orderedSame {
        _webview?.evaluateJavaScript("setInputMode(\"image\");", completionHandler: nil)
        _inputMode = TeachableMachine.MODE_IMAGE
      } else {
        _form?.dispatchErrorOccurredEvent(self, "InputMode", ErrorMessage.ERROR_INPUT_MODE, TeachableMachine.ERROR_INVALID_INPUT_MODE, "Invalid input mode \(newValue)")
      }
    }
  }

  @objc public var MinimumInterval: Int32 {
    get {
      return _minClassTime
    }
    set {
      _minClassTime = newValue
      _webview?.evaluateJavaScript("minClassTime = \(newValue);", completionHandler: nil)
    }
  }

  @objc public var Running: Bool {
    return _running
  }

  @objc public func ClassifyImageData(_ imagePath: String?) {
    do  {
      try assertWebView("ClassifyImageData")
    } catch {
      print("Error webViewer not set during ClassifyImageData")
    }
    guard let imagePath = imagePath, !imagePath.isEmpty else{
      print("Image path is nil or empty.")
      return
    }
    print("Entered Classify")
    print(imagePath)
    var scaledImageBitmap: UIImage? = nil
    if let image = UIImage(named: imagePath) {
      let width = TeachableMachine.IMAGE_WIDTH
      let height = Int(image.size.height * CGFloat(TeachableMachine.IMAGE_WIDTH) / image.size.width)

      UIGraphicsBeginImageContext(CGSize(width: width, height: height))
      image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
      scaledImageBitmap = UIGraphicsGetImageFromCurrentImageContext()
      UIGraphicsEndImageContext()
    } else {
      print("Unable to load \(imagePath)")
    }

    if let immagex = scaledImageBitmap {
      if let imageData = immagex.pngData() {
        let imageEncodedBase64String = imageData.base64EncodedString(options: .lineLength64Characters).replacingOccurrences(of: "\n", with: "")
        print("imageEncodedBase64String: \(imageEncodedBase64String)")
        _webview?.evaluateJavaScript("classifyImageData(\"\(imageEncodedBase64String)\");", completionHandler: nil)
      }
    }
  }

  @objc public func ToggleCameraFacingMode() {
    do {
      try assertWebView("ToggleCameraFacingMode")
    } catch {
      print("Error webViewer not set during ToggleCameraFacingMode")
    }
    _webview?.evaluateJavaScript("toggleCameraFacingMode();", completionHandler: nil)
  }

  @objc public func ClassifyVideoData() {
    do {
      try assertWebView("ClassifyVideoData")
    } catch {
      print("Error webViewer not set during ClassifyVideoData" )
    }
    print("ClassifyVideoData")
    _webview?.evaluateJavaScript("classifyVideoData();", completionHandler: nil)
  }


  @objc public func StartContinuousClassification() {
    if InputMode.caseInsensitiveCompare(TeachableMachine.MODE_VIDEO) == .orderedSame && !_running {
      do {
        try assertWebView("StartVideoClassification")
      } catch {
        print("Error webViwer not set during StartVideoClassification")
      }
      _webview?.evaluateJavaScript("startVideoClassification();", completionHandler: nil)
      _running = true
    }
  }

  @objc public func StopContinuousClassification() {
    if InputMode.caseInsensitiveCompare(TeachableMachine.MODE_VIDEO) == .orderedSame && _running {
      do {
        try assertWebView("StopVideoClassification")
      } catch {
        print("Error webViewer not set during StopVideoClassification")
      }
      _webview?.evaluateJavaScript("stopVideoClassification();", completionHandler: nil)
      _running = false
    }
  }

  @objc public override func ClassifierReady() {
    InputMode = _inputMode
    MinimumInterval = _minClassTime
    super.ClassifierReady()
  }

  @objc public func onPause() {
    if let webview = _webview, _inputMode == TeachableMachine.MODE_VIDEO {
      webview.evaluateJavaScript("stopVideo();", completionHandler: nil)
    }
  }

  @objc public func onResume() {
    if let webview = _webview, _inputMode == TeachableMachine.MODE_VIDEO {
      webview.evaluateJavaScript("startVideo();", completionHandler: nil)
    }
  }

  @objc public func onClear() {
    if let webview = _webview, _inputMode == TeachableMachine.MODE_VIDEO {
      webview.evaluateJavaScript("stopVideo();", completionHandler: nil)
    }
  }
}

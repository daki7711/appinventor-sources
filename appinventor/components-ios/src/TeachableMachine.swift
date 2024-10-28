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

fileprivate let TRANSFER_MODEL_PREFIX = "appinventor://teachable_machine/transfer/"
fileprivate let PERSONAL_MODEL_PREFIX = "appinventor://teachable_machine/personal/"

class TeachableMachine: BaseClassifier, LifecycleDelegate {
  public static let MODE_VIDEO = "Video"
  public static let MODE_IMAGE = "Image"
  public static let IMAGE_WIDTH = 500
  public static let ERROR_INVALID_INPUT_MODE = -6;


  private let logTag = "TeachableMachine"
  private let modelURL = "https://teachablemachine.withgoogle.com/models/"
  private var webView: WKWebView?
  private var _modelPath: String?
  private var _inputMode = TeachableMachine.MODE_VIDEO
  private var labels: [String] = []
  private var _running = false
  private var _minClassTime = 0

  @objc public init(_ container: ComponentContainer) {
    super.init(container, "teachable_machine", TRANSFER_MODEL_PREFIX, PERSONAL_MODEL_PREFIX)
  }

  func initialize() {
    guard let webView = webView else {
      print("\(logTag): WebViewer is not set")
      return
    }

    if let modelPath = _modelPath {
      let js = "loadModel('\(modelPath)');"
      webView.evaluateJavaScript(js, completionHandler: nil)
    } else {
      print("\(logTag): Model file is not provided")
    }
  }

  @objc public var ModelLink: String? {
    get {
      return self._modelPath
    }
    set {
      guard let link = newValue else {
        print("\(logTag): Model Link is nil")
        return
      }
      print("\(logTag): Model Link: \(link)")
      if link.contains(modelURL) {
        self._modelPath = link
      } else {
        // Handle invalid model link
        print("\(logTag): Incorrect Model Link: The link should look like \(modelURL)")
        showError("Incorrect Model Link: The link should look like \(modelURL)")
      }
    }
  }

  @objc public var InputMode: String {
    get {
      return self._inputMode
    }
    set {
      print("\(logTag): INPUT MODE RUN")
      guard let webView = self.webView else {
        self._inputMode = newValue
        return
      }
      switch newValue.lowercased() {
      case "video":
        webView.evaluateJavaScript("setInputMode('video');", completionHandler: nil)
        self._inputMode = TeachableMachine.MODE_VIDEO
      case "image":
        webView.evaluateJavaScript("setInputMode('image');", completionHandler: nil)
        self._inputMode = TeachableMachine.MODE_IMAGE
      default:
        print("\(logTag): Invalid input mode \(newValue)")
        // Handle error: Display alert or another appropriate error handling mechanism
        showError("Invalid input mode. Valid values are 'Video' or 'Image'.")
      }
    }
  }

  // Computed property for running state
  @objc public var Running: Bool {
    get {
      return _running
    }
    set(newRunningState) {
      _running = newRunningState
      // Additional actions can be performed here when the state changes.
    }
  }

  @objc public var MinimumInterval: Int {
    get {
      return _minClassTime
    }
    set {
      _minClassTime = newValue
      webView?.evaluateJavaScript("minClassTime = \(newValue);", completionHandler: nil)
    }
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
      let width = PersonalImageClassifier.IMAGE_WIDTH
      let height = Int(image.size.height * CGFloat(PersonalImageClassifier.IMAGE_WIDTH) / image.size.width)

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

  private func showError(_ message: String) {
    DispatchQueue.main.async {
      let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .default))
      if let topController = UIApplication.shared.keyWindow?.rootViewController {
        topController.present(alert, animated: true, completion: nil)
      }
    }
  }
}

//
//  ViewController.swift
//  SwiftLinkPreviewExample
//
//  Created by Leonardo Cardoso on 09/06/2016.
//  Copyright © 2016 leocardz.com. All rights reserved.
//

import UIKit
import ImageSlideshow
import SwiftLinkPreview

class ViewController: UIViewController {

    // MARK: - Properties
    @IBOutlet private weak var centerLoadingActivityIndicatorView: UIActivityIndicatorView?
    @IBOutlet private weak var textField: UITextField?
    @IBOutlet private weak var randomTextButton: UIButton?
    @IBOutlet private weak var submitButton: UIButton?
    @IBOutlet private weak var openWithButton: UIButton?
    @IBOutlet private weak var indicator: UIActivityIndicatorView?
    @IBOutlet private weak var previewArea: UIView?
    @IBOutlet private weak var previewAreaLabel: UILabel?
    @IBOutlet private weak var slideshow: ImageSlideshow?
    @IBOutlet private weak var previewTitle: UILabel?
    @IBOutlet private weak var previewCanonicalUrl: UILabel?
    @IBOutlet private weak var previewDescription: UILabel?
    @IBOutlet private weak var detailedView: UIView?
    @IBOutlet private weak var favicon: UIImageView?

    // MARK: - Vars
    private var response: Response?
    private let placeholderImages = [ImageSource(image: UIImage(named: "Placeholder")!)]
    private let slp = SwiftLinkPreview(cache: InMemoryCache())

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        showHideAll(hide: true)
        slideshow?.backgroundColor = UIColor.white
        slideshow?.slideshowInterval = 7.0
        slideshow?.pageIndicator = LabelPageIndicator()
        slideshow?.pageIndicatorPosition = .init(horizontal: .right(padding: 16), vertical: .top)
        slideshow?.contentScaleMode = .scaleAspectFill
    }

    /// Starts the crawling
    private func startCrawling() {
        centerLoadingActivityIndicatorView?.startAnimating()
        updateUI(enabled: false)
        showHideAll(hide: true)
        textField?.resignFirstResponder()
        indicator?.isHidden = false
    }

    /// End crawling
    private func endCrawling() {
        self.updateUI(enabled: true)
    }

    /// Updates the UI
    private func showHideAll(hide: Bool) {
        slideshow?.isHidden = hide
        detailedView?.isHidden = hide
        openWithButton?.isHidden = hide
        previewAreaLabel?.isHidden = !hide
    }

    /// Updates the UI
    private func updateUI(enabled: Bool) {
        indicator?.isHidden = enabled
        textField?.isEnabled = enabled
        randomTextButton?.isEnabled = enabled
        submitButton?.isEnabled = enabled
    }

    /// Sets data for the current result
    private func setData(_ response: Response?) {
        self.response = response
        defer {
            showHideAll(hide: false)
            endCrawling()
        }

        // There's no result, let's stop here
        guard let response = response else {
            debug_showAlert(title: "Error", message: "Nothing was crawled")
            return
        }

        // Set the images
        if let value = response.images, !value.isEmpty {
            let images = value.compactMap { $0.imageSource}
            setImages(images)
        } else {
            setSingleImage(response.image)
        }

        // Set the preview title, if any
        if let value = response.title, !value.isEmpty {
            previewTitle?.text = value
        } else {
            previewTitle?.text = "No title"
        }

        // Canonical url
        previewCanonicalUrl?.text = response.canonicalUrl

        // Description
        if let value = response.description, !value.isEmpty {
            previewDescription?.text = value
        } else {
            previewDescription?.text = "No description"
        }

        // Favicon
        if let value = response.icon, let url = URL(string: value) {
            favicon?.sd_setImage(with: url, completed: nil)
        }

        response.debugPrint()
    }

    /// Set a single image in the slideshow
    /// - Parameter stringUrl: url
    private func setSingleImage(_ stringUrl: String?) {
        guard let source = stringUrl?.imageSource else {
            setImages(nil)
            return
        }
        setImages([source])
    }

    /// Sets multiple images in the slideshow
    /// - Parameter images: Images urls
    private func setImages(_ images: [InputSource]?) {
        defer {
            centerLoadingActivityIndicatorView?.stopAnimating()
        }
        guard let images = images, images.count > 0 else {
            slideshow?.setImageInputs(placeholderImages)
            return
        }
        slideshow?.setImageInputs(images)
    }

    // MARK: - Actions
    @IBAction func randomTextAction(_ sender: AnyObject) {
        textField?.text = LoremIpsum.getRandomText()
    }

    @IBAction func submitAction(_ sender: AnyObject) {
        guard textField?.text?.isEmpty == false else {
            debug_showAlert(title: "Warning", message: "Please, enter a text")
            return
        }

        startCrawling()

        let textFieldText = textField?.text ?? String()

        // Look for cached data
        if let url = slp.extractURL(text: textFieldText),
            let cached = slp.cache.slp_getCachedResponse(url: url.absoluteString) {
            setData(cached)

        } else {
            // Fetch data
            slp.preview(textFieldText, onSuccess: { [unowned self] result in
                self.setData(result)
                }, onError: { [unowned self] error in
                    print(error)
                    self.setData(nil)
                    self.debug_showAlert(title: "Error", message: error.description)
            })
        }

    }

    @IBAction func openWithAction(_ sender: UIButton) {
        guard let url = response?.finalUrl else {
            debug_showAlert(title: "Error", message: "No url was found")
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}


// MARK: - UITextFieldDelegate
extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        submitAction(textField)
        textField.resignFirstResponder()
        return false
    }
}

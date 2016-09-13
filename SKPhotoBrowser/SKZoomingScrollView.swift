//
//  SKZoomingScrollView.swift
//  SKViewExample
//
//  Created by suzuki_keihsi on 2015/10/01.
//  Copyright © 2015 suzuki_keishi. All rights reserved.
//

import UIKit
import AVFoundation

public class SKZoomingScrollView: UIScrollView {
    var captionView: SKCaptionView!
    var photo: SKPhotoProtocol! {
        didSet {
            photoImageView.image = nil
            if photo != nil {
                displayImage(complete: false)
            }
        }
    }
    var displayPlaybackControls = false
    
    private(set) var photoImageView: SKDetectingImageView!
    private weak var photoBrowser: SKPhotoBrowser?
    private var tapView: SKDetectingView!
    private var indicatorView: SKIndicatorView!
    private var videoPlayer: SKVideoPlayer!
    private var playButton: UIButton!
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    convenience init(frame: CGRect, browser: SKPhotoBrowser) {
        self.init(frame: frame)
        photoBrowser = browser
        setup()
    }
    
    deinit {
        photoBrowser = nil
        videoPlayer = nil
        playButton = nil
    }
    
    func setup() {
        // tap
        tapView = SKDetectingView(frame: bounds)
        tapView.delegate = self
        tapView.backgroundColor = .clearColor()
        tapView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
        addSubview(tapView)
        
        // image
        photoImageView = SKDetectingImageView(frame: frame)
        photoImageView.delegate = self
        photoImageView.contentMode = .Bottom
        photoImageView.backgroundColor = .clearColor()
        addSubview(photoImageView)
        
        // indicator
        indicatorView = SKIndicatorView(frame: frame)
        addSubview(indicatorView)
        
        // self
        backgroundColor = .clearColor()
        delegate = self
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        decelerationRate = UIScrollViewDecelerationRateFast
        autoresizingMask = [.FlexibleWidth, .FlexibleTopMargin, .FlexibleBottomMargin, .FlexibleRightMargin, .FlexibleLeftMargin]
    
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(scrubberStart), name: SKVideoScrubber.Start, object: nil)
    }
    
    func viewWillAppear() {
        guard let videoPlayer = videoPlayer else {
            return
        }
        videoPlayer.reset()
        displayPlaybackControls = false
        
        if let playButton = playButton {
            playButton.hidden = false
            bringSubviewToFront(playButton)
        }
    }
    
    func displayingVideo() -> Bool {
        return photo.videoURL != nil
    }
    
    func videoDuration() -> Float64 {
        if !displayingVideo() {
            return 0
        }
        let asset = AVURLAsset(URL: photo.videoURL)
        return CMTimeGetSeconds(asset.duration)
    }
    
    func isPlayingVideo() -> Bool {
        guard let videoPlayer = videoPlayer else {
            return false
        }
        return videoPlayer.isPlaying()
    }
    
    func isPausedVideo() -> Bool {
        guard let videoPlayer = videoPlayer else {
            return false
        }
        return !videoPlayer.isPlaying()
    }
    
    func playVideo() {
        if videoPlayer == nil {
            initVideoPlayer()
        }
        
        guard let videoPlayer = self.videoPlayer else {
            return
        }
        
        playButton.hidden = true
        displayPlaybackControls = true
        
        videoPlayer.play()
        photoBrowser?.toolbar.updateButtons()
    }
    
    func pauseVideo() {
        guard let videoPlayer = videoPlayer else {
            return
        }
        videoPlayer.pause()
        photoBrowser?.toolbar.updateButtons()
    }
    
    // MARK: - override
    
    public override func layoutSubviews() {
        tapView.frame = bounds
        indicatorView.frame = bounds
        
        super.layoutSubviews()
        
        let boundsSize = bounds.size
        var frameToCenter = photoImageView.frame
        
        // horizon
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = floor((boundsSize.width - frameToCenter.size.width) / 2)
        } else {
            frameToCenter.origin.x = 0
        }
        // vertical
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = floor((boundsSize.height - frameToCenter.size.height) / 2)
        } else {
            frameToCenter.origin.y = 0
        }
        
        // Center
        if !CGRectEqualToRect(photoImageView.frame, frameToCenter) {
            photoImageView.frame = frameToCenter
        }
        
        // Video Player
        if let videoPlayer = self.videoPlayer {
            videoPlayer.frame = self.bounds
        }
        
        // Play Button
        if let playButton = self.playButton {
            playButton.center = CGPoint(x: frame.width/2, y: frame.height/2)
        }
    }
    
    public func setMaxMinZoomScalesForCurrentBounds() {
        maximumZoomScale = 1
        minimumZoomScale = 1
        zoomScale = 1
        
        guard let photoImageView = photoImageView else {
            return
        }
        
        let boundsSize = bounds.size
        let imageSize = photoImageView.frame.size
        
        let xScale = boundsSize.width / imageSize.width
        let yScale = boundsSize.height / imageSize.height
        let minScale: CGFloat = min(xScale, yScale)
        var maxScale: CGFloat = 1.0
        
        let scale = max(UIScreen.mainScreen().scale, 2.0)
        let deviceScreenWidth = UIScreen.mainScreen().bounds.width * scale // width in pixels. scale needs to remove if to use the old algorithm
        let deviceScreenHeight = UIScreen.mainScreen().bounds.height * scale // height in pixels. scale needs to remove if to use the old algorithm
        
        if photoImageView.frame.width < deviceScreenWidth {
            // I think that we should to get coefficient between device screen width and image width and assign it to maxScale. I made two mode that we will get the same result for different device orientations.
            if UIApplication.sharedApplication().statusBarOrientation.isPortrait {
                maxScale = deviceScreenHeight / photoImageView.frame.width
            } else {
                maxScale = deviceScreenWidth / photoImageView.frame.width
            }
        } else if photoImageView.frame.width > deviceScreenWidth {
            maxScale = 1.0
        } else {
            // here if photoImageView.frame.width == deviceScreenWidth
            maxScale = 2.5
        }
    
        maximumZoomScale = maxScale
        minimumZoomScale = minScale
        zoomScale = minScale
        
        // on high resolution screens we have double the pixel density, so we will be seeing every pixel if we limit the
        // maximum zoom scale to 0.5
        // After changing this value, we still never use more
        /*
        maxScale = maxScale / scale 
        if maxScale < minScale {
            maxScale = minScale * 2
        }
        */
        
        // reset position
        photoImageView.frame = CGRect(x: 0, y: 0, width: photoImageView.frame.size.width, height: photoImageView.frame.size.height)
        
        // Disable scrolling initially until the first pinch to fix issues with swiping on an initally zoomed in photo
        self.scrollEnabled = false
        
        // If it's a video then disable zooming
        if displayingVideo() {
            self.maximumZoomScale = self.zoomScale;
            self.minimumZoomScale = self.zoomScale;
        }
        
        setNeedsLayout()
    }
    
    public func prepareForReuse() {
        photo = nil
        
        if videoPlayer != nil {
            videoPlayer.pause()
            videoPlayer = nil
        }
        
        if playButton != nil {
            playButton.removeFromSuperview()
            playButton = nil
        }
    }
    
    // MARK: - image
    public func displayImage(complete flag: Bool) {
        // reset scale
        maximumZoomScale = 1
        minimumZoomScale = 1
        zoomScale = 1
        contentSize = CGSize.zero
        
        if !flag {
            if photo.underlyingImage == nil {
                indicatorView.startAnimating()
            }
            photo.loadUnderlyingImageAndNotify()
        } else {
            indicatorView.stopAnimating()
        }
        
        if let image = photo.underlyingImage {
            /*
            // create padding
            let width: CGFloat = image.size.width + SKPhotoBrowserOptions.imagePaddingX
            let height: CGFloat = image.size.height + SKPhotoBrowserOptions.imagePaddingY;
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), false, 0.0);
            let context: CGContextRef = UIGraphicsGetCurrentContext()!;
            UIGraphicsPushContext(context);
            let origin: CGPoint = CGPointMake((width - image.size.width) / 2, (height - image.size.height) / 2);
            image.drawAtPoint(origin)
            UIGraphicsPopContext();
            let imageWithPadding = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
             */
            
            // image
            photoImageView.image = image
            photoImageView.contentMode = photo.contentMode
            photoImageView.backgroundColor = SKPhotoBrowserOptions.backgroundColor
            
            var photoImageViewFrame = CGRect.zero
            photoImageViewFrame.origin = CGPoint.zero
            photoImageViewFrame.size = image.size
            
            photoImageView.frame = photoImageViewFrame
            
            contentSize = photoImageViewFrame.size
            
            setMaxMinZoomScalesForCurrentBounds()
            
            if displayingVideo() && playButton == nil {
                playButton = UIButton(type: .Custom)
                playButton.setImage(UIImage(named: "SKPhotoBrowser.bundle/images/btn_common_play_blk", inBundle: NSBundle(forClass: SKPhotoBrowser.self), compatibleWithTraitCollection: nil), forState: .Normal)
                playButton.setImage(UIImage(named: "SKPhotoBrowser.bundle/images/btn_common_play_tap_blk", inBundle: NSBundle(forClass: SKPhotoBrowser.self), compatibleWithTraitCollection: nil), forState: .Highlighted)
                playButton.addTarget(self, action: #selector(playVideo), forControlEvents: .TouchUpInside)
                playButton.sizeToFit()
                playButton.userInteractionEnabled = true
                addSubview(playButton)
            }
        }
        setNeedsLayout()
    }
    
    public func displayImageFailure() {
        indicatorView.stopAnimating()
    }
    
    // MARK: - handle tap
    
    public func handleDoubleTap(touchPoint: CGPoint) {
        if let photoBrowser = photoBrowser {
            NSObject.cancelPreviousPerformRequestsWithTarget(photoBrowser)
        }
        
        if zoomScale > minimumZoomScale {
            // zoom out
            setZoomScale(minimumZoomScale, animated: true)
        } else {
            // zoom in
            // I think that the result should be the same after double touch or pinch
           /* var newZoom: CGFloat = zoomScale * 3.13
            if newZoom >= maximumZoomScale {
                newZoom = maximumZoomScale
            }
            */
            let zoomRect = zoomRectForScrollViewWith(maximumZoomScale, touchPoint: touchPoint)
            zoomToRect(zoomRect, animated: true)
        }
        
        // delay control
        photoBrowser?.hideControlsAfterDelay()
    }
}

// MARK: - UIScrollViewDelegate

extension SKZoomingScrollView: UIScrollViewDelegate {
    public func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return photoImageView
    }
    
    public func scrollViewWillBeginZooming(scrollView: UIScrollView, withView view: UIView?) {
        self.scrollEnabled = true
        photoBrowser?.cancelControlHiding()
    }
    
    public func scrollViewDidZoom(scrollView: UIScrollView) {
        setNeedsLayout()
        layoutIfNeeded()
    }
}

// MARK: - SKDetectingImageViewDelegate

extension SKZoomingScrollView: SKDetectingViewDelegate {
    func handleSingleTap(view: UIView, touch: UITouch) {
        guard let browser = photoBrowser else {
            return
        }
        guard SKPhotoBrowserOptions.enableZoomBlackArea == true else {
            return
        }
        
        if browser.areControlsHidden() == false && SKPhotoBrowserOptions.enableSingleTapDismiss == true {
            browser.determineAndClose()
        } else {
            browser.toggleControls()
        }
    }
    
    func handleDoubleTap(view: UIView, touch: UITouch) {
        if SKPhotoBrowserOptions.enableZoomBlackArea == true {
            let needPoint = getViewFramePercent(view, touch: touch)
            handleDoubleTap(needPoint)
        }
    }
}

// MARK: - SKDetectingImageViewDelegate

extension SKZoomingScrollView: SKDetectingImageViewDelegate {
    func handleImageViewSingleTap(touchPoint: CGPoint) {
        guard let browser = photoBrowser else {
            return
        }
        if SKPhotoBrowserOptions.enableSingleTapDismiss {
            browser.determineAndClose()
        } else {
            browser.toggleControls()
        }
    }
    
    func handleImageViewDoubleTap(touchPoint: CGPoint) {
        if displayingVideo() {
            return
        }
        handleDoubleTap(touchPoint)
    }
}

extension SKZoomingScrollView: SKVideoPlayerDelegate {
    func playerCurrentTimeDidChange(progress: Float, currentTime: Float, videoPlayer: SKVideoPlayer) {
        photoBrowser?.navigationBar.updateScrubber(progress, currentTime: currentTime)
    }
    
    func playerPlaybackDidEnd(videoPlayer: SKVideoPlayer) {
        playButton.hidden = false
        photoBrowser?.toolbar.updateButtons()
    }
    
    func playerStarted(videoPlayer: SKVideoPlayer) {
        photoBrowser?.toolbar.updateButtons()
    }
    
    func playerPaused(videoPlayer: SKVideoPlayer) {
        photoBrowser?.toolbar.updateButtons()
    }
}

private extension SKZoomingScrollView {
    func getViewFramePercent(view: UIView, touch: UITouch) -> CGPoint {
        let oneWidthViewPercent = view.bounds.width / 100
        let viewTouchPoint = touch.locationInView(view)
        let viewWidthTouch = viewTouchPoint.x
        let viewPercentTouch = viewWidthTouch / oneWidthViewPercent
        
        let photoWidth = photoImageView.bounds.width
        let onePhotoPercent = photoWidth / 100
        let needPoint = viewPercentTouch * onePhotoPercent
        
        var Y: CGFloat!
        
        if viewTouchPoint.y < view.bounds.height / 2 {
            Y = 0
        } else {
            Y = photoImageView.bounds.height
        }
        let allPoint = CGPoint(x: needPoint, y: Y)
        return allPoint
    }
    
    func zoomRectForScrollViewWith(scale: CGFloat, touchPoint: CGPoint) -> CGRect {
        let w = frame.size.width / scale
        let h = frame.size.height / scale
        let x = touchPoint.x - (h / max(UIScreen.mainScreen().scale, 2.0))
        let y = touchPoint.y - (w / max(UIScreen.mainScreen().scale, 2.0))
        
        return CGRect(x: x, y: y, width: w, height: h)
    }
    
    func initVideoPlayer() {
        guard let photo = self.photo else {
            return
        }
        
        videoPlayer = SKVideoPlayer(URL: photo.videoURL)
        videoPlayer.delegate = self
        layer.addSublayer(videoPlayer.layer())
    }
}

private extension SKZoomingScrollView {
    
    @objc func scrubberStart() {
        if videoPlayer == nil {
            initVideoPlayer()
        }
    }
}

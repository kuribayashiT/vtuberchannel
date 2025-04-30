//
// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

// COMPLETE: Import google_mobile_ads
import google_mobile_ads

class ListTileNativeAdFactory : FLTNativeAdFactory {
    
    func createNativeAd(_ nativeAd: GADNativeAd,
                        customOptions: [AnyHashable : Any]? = nil) -> GADNativeAdView? {
        let nibView = Bundle.main.loadNibNamed("ListTileNativeAdView", owner: nil, options: nil)!.first
        let nativeAdView = nibView as! GADNativeAdView
        
        (nativeAdView.headlineView as! UILabel).text = nativeAd.headline
        
        (nativeAdView.bodyView as! UILabel).text = nativeAd.body
        nativeAdView.bodyView!.isHidden = nativeAd.body == nil
        //nativeAd.delegate = self
        
        (nativeAdView.iconView as! UIImageView).image = nativeAd.icon?.image
        nativeAdView.iconView!.isHidden = nativeAd.icon == nil
        nativeAdView.mediaView?.mediaContent = nativeAd.mediaContent
        //nativeAdView.adChoicesView? = nativeAd.adChoicesView
        // (nativeAdView.advertiserView as? UILabel)?.text = nativeAd.advertiser
        // nativeAdView.advertiserView?.isHidden = nativeAd.advertiser == nil
        // (nativeAdView.mediaView as! GADMediaView ).mediaContent = nativeAd.mediaContent
        // nativeAdView.mediaView!.isHidden = nativeAd.mediaContent == nil
        // GADMediaViewの設定
        // if let mediaView = nativeAdView.mediaView as? GADMediaView {
        //     mediaView.mediaContent = nativeAd.mediaContent
        // }
        if let mediaView = nativeAdView.mediaView, nativeAd.mediaContent.aspectRatio > 0 {
            let heightConstraint = NSLayoutConstraint(
            item: mediaView,
            attribute: .height,
            relatedBy: .equal,
            toItem: mediaView,
            attribute: .width,
            multiplier: CGFloat(1 / nativeAd.mediaContent.aspectRatio),
            constant: 0)
            heightConstraint.isActive = true
        }
        
        nativeAdView.callToActionView?.isUserInteractionEnabled = false

        nativeAdView.nativeAd = nativeAd
        
        return nativeAdView
    }
}

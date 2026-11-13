Pod::Spec.new do |s|
  s.name             = 'advanced_in_app_review'
  s.version          = '2.0.0'
  s.summary          = 'Native in-app reviews with persistent eligibility conditions.'
  s.description      = 'Native StoreKit and Google Play in-app review integration for Flutter.'
  s.homepage         = 'https://github.com/eeoom/advanced_in_app_review'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'eeoom Apps / Stefan Mayr' => 'https://eeoom.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'advanced_in_app_review/Sources/advanced_in_app_review/**/*.swift'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.resource_bundles = { 'advanced_in_app_review_privacy' => ['advanced_in_app_review/Sources/advanced_in_app_review/PrivacyInfo.xcprivacy'] }
end

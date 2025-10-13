//
//  AnalyticsService.swift
//  SnatchShot
//
//  Created by AI Assistant on 22/09/25.
//

import Foundation
import Mixpanel
import AppsFlyerLib
import UIKit

/// Centralized analytics service for tracking events to Mixpanel and AppsFlyer
class AnalyticsService {
    static let shared = AnalyticsService()

    private var userPropertiesSetup = false

    private init() {
        // Defer user properties setup to ensure Mixpanel is initialized
        // Will be called when first analytics event is tracked
    }

    // MARK: - Event Constants

    enum AppsFlyerEvent {
        static let install = "af_install"
        static let purchase = "af_purchase"
        static let trialStarted = "af_trial_started"
    }

    enum MixpanelEvent {
        // Onboarding Flow
        static let onboardingStarted = "onboarding_started"
        static let onboardingSlideViewed = "onboarding_slide_viewed"
        static let onboardingCompleted = "onboarding_completed"

        // Authentication Flow
        static let signupPageViewed = "signup_page_viewed"
        static let signupAppleSigninTapped = "signup_apple_signin_tapped"
        static let signupGoogleSigninTapped = "signup_google_signin_tapped"
        static let signupTermsLinkTapped = "signup_terms_link_tapped"
        static let signupPrivacyLinkTapped = "signup_privacy_link_tapped"
        static let signupImageSliderInteracted = "signup_image_slider_interacted"
        static let signupCompleted = "signup_completed"

        static let personalizationStarted = "personalization_started"
        static let personalizationCompleted = "personalization_completed"

        // Verification Flow
        static let verificationStarted = "verification_started"
        static let facePhotoCameraSelected = "face_photo_camera_selected"
        static let facePhotoGallerySelected = "face_photo_gallery_selected"
        static let facePhotoUploaded = "face_photo_uploaded"
        static let faceVerificationPassed = "face_verification_passed"
        static let faceVerificationFailed = "face_verification_failed"
        static let faceVerificationUnderReview = "face_verification_under_review"

        static let fullbodyPhotoCameraSelected = "fullbody_photo_camera_selected"
        static let fullbodyPhotoGallerySelected = "fullbody_photo_gallery_selected"
        static let fullbodyPhotoUploaded = "fullbody_photo_uploaded"
        static let verificationCompleted = "verification_completed"

        // Camera & Feature Usage
        static let cameraOpened = "camera_opened"
        static let photoCaptured = "photo_captured"
        static let photoSavedToGallery = "photo_saved_to_gallery"
        static let photoShared = "photo_shared"

        // Pose Suggestions
        static let poseSuggestionsToggledOn = "pose_suggestions_toggled_on"
        static let poseSuggestionsToggledOff = "pose_suggestions_toggled_off"
        static let poseSuggestionRequested = "pose_suggestion_requested"
        static let poseSuggestionViewed = "pose_suggestion_viewed"
        static let poseSuggestionSelected = "pose_suggestion_selected"

        // Camera Settings
        static let cameraSettingsToggledOn = "camera_settings_toggled_on"
        static let cameraSettingsToggledOff = "camera_settings_toggled_off"
        static let filterDrawerOpened = "filter_drawer_opened"
        static let filterApplied = "filter_applied"
        static let aspectRatioChanged = "aspect_ratio_changed"
        static let timerChanged = "timer_changed"
        static let wbPresetChanged = "wb_preset_changed"

        // Paywall & Subscription
        static let paywallShown = "paywall_shown"
        static let paywallDismissed = "paywall_dismissed"
        static let trialStarted = "trial_started"
        static let subscriptionPurchased = "subscription_purchased"
        static let subscriptionCancelled = "subscription_cancelled"
        static let subscriptionRestored = "subscription_restored"
        static let purchaseFailed = "purchase_failed"
        static let restoreFailed = "restore_failed"
    }

    enum UserProperty {
        static let campaignName = "campaign_name"
        static let campaignSource = "campaign_source"
        static let signupDate = "signup_date"
        static let subscriptionStatus = "subscription_status"
        static let subscriptionProductId = "subscription_product_id"
        static let trialStartDate = "trial_start_date"
        static let deviceType = "device_type"
        static let iosVersion = "ios_version"
        static let photosTakenCount = "photos_taken_count"
        static let filtersUsed = "filters_used"
        static let poseSuggestionsUsedCount = "pose_suggestions_used_count"
    }

    // MARK: - Setup

    private func setupUserProperties() {
        let mixpanel = Mixpanel.mainInstance()

        // Set device and app properties
        mixpanel.people.set(properties: [
            UserProperty.deviceType: UIDevice.current.model,
            UserProperty.iosVersion: UIDevice.current.systemVersion,
            UserProperty.signupDate: Date(),
            UserProperty.subscriptionStatus: "free",
            UserProperty.photosTakenCount: 0,
            UserProperty.poseSuggestionsUsedCount: 0
        ])
    }

    // MARK: - Event Tracking Methods

    // MARK: Onboarding Events
    func trackOnboardingStarted() {
        trackMixpanelEvent(MixpanelEvent.onboardingStarted)
    }

    func trackOnboardingSlideViewed(slideNumber: Int, slideName: String) {
        trackMixpanelEvent(MixpanelEvent.onboardingSlideViewed, properties: [
            "slide_number": slideNumber,
            "slide_name": slideName
        ])
    }

    func trackOnboardingCompleted() {
        trackMixpanelEvent(MixpanelEvent.onboardingCompleted)
    }

    // MARK: Sign Up Events
    func trackSignupPageViewed() {
        trackMixpanelEvent(MixpanelEvent.signupPageViewed)
    }

    func trackSignupAppleSigninTapped() {
        trackMixpanelEvent(MixpanelEvent.signupAppleSigninTapped)
    }

    func trackSignupGoogleSigninTapped() {
        trackMixpanelEvent(MixpanelEvent.signupGoogleSigninTapped)
    }

    func trackSignupTermsLinkTapped() {
        trackMixpanelEvent(MixpanelEvent.signupTermsLinkTapped)
    }

    func trackSignupPrivacyLinkTapped() {
        trackMixpanelEvent(MixpanelEvent.signupPrivacyLinkTapped)
    }

    func trackSignupImageSliderInteracted() {
        trackMixpanelEvent(MixpanelEvent.signupImageSliderInteracted)
    }

    func trackSignupCompleted() {
        trackMixpanelEvent("signup_completed")
    }

    func trackSignupGuestModeTapped() {
        trackMixpanelEvent("signup_guest_mode_tapped")
    }

    func trackGuestModeActivated() {
        trackMixpanelEvent("guest_mode_activated")
    }

    // Legacy method - keeping for compatibility
    func trackSignupCompleted_legacy() {
        trackMixpanelEvent(MixpanelEvent.signupCompleted)
    }

    // MARK: Personalization Events
    func trackPersonalizationStarted() {
        trackMixpanelEvent(MixpanelEvent.personalizationStarted)
    }

    func trackPersonalizationCompleted() {
        trackMixpanelEvent(MixpanelEvent.personalizationCompleted)
    }

    // MARK: Verification Events
    func trackVerificationStarted() {
        trackMixpanelEvent(MixpanelEvent.verificationStarted)
    }

    func trackFacePhotoCameraSelected() {
        trackMixpanelEvent(MixpanelEvent.facePhotoCameraSelected)
    }

    func trackFacePhotoGallerySelected() {
        trackMixpanelEvent(MixpanelEvent.facePhotoGallerySelected)
    }

    func trackFacePhotoUploaded() {
        trackMixpanelEvent(MixpanelEvent.facePhotoUploaded)
    }

    func trackFaceVerificationPassed() {
        trackMixpanelEvent(MixpanelEvent.faceVerificationPassed)
    }

    func trackFaceVerificationFailed(reason: String) {
        trackMixpanelEvent(MixpanelEvent.faceVerificationFailed, properties: [
            "failure_reason": reason
        ])
    }

    func trackFaceVerificationUnderReview() {
        trackMixpanelEvent(MixpanelEvent.faceVerificationUnderReview)
    }

    func trackFullbodyPhotoCameraSelected() {
        trackMixpanelEvent(MixpanelEvent.fullbodyPhotoCameraSelected)
    }

    func trackFullbodyPhotoGallerySelected() {
        trackMixpanelEvent(MixpanelEvent.fullbodyPhotoGallerySelected)
    }

    func trackFullbodyPhotoUploaded() {
        trackMixpanelEvent(MixpanelEvent.fullbodyPhotoUploaded)
    }

    func trackVerificationCompleted() {
        trackMixpanelEvent(MixpanelEvent.verificationCompleted)
    }

    // MARK: Camera & Feature Events
    func trackCameraOpened() {
        trackMixpanelEvent(MixpanelEvent.cameraOpened)
    }

    func trackPhotoCaptured(filter: String? = nil, aspectRatio: String? = nil, hasPoseSuggestions: Bool = false) {
        var properties: [String: MixpanelType] = [:]

        if let filter = filter {
            properties["filter_used"] = filter
        }
        if let aspectRatio = aspectRatio {
            properties["aspect_ratio"] = aspectRatio
        }
        properties["pose_suggestions_enabled"] = hasPoseSuggestions

        trackMixpanelEvent(MixpanelEvent.photoCaptured, properties: properties)

        // Increment photos taken count
        Mixpanel.mainInstance().people.increment(properties: [UserProperty.photosTakenCount: 1])
    }

    func trackPhotoSavedToGallery() {
        trackMixpanelEvent(MixpanelEvent.photoSavedToGallery)
    }

    func trackPhotoShared() {
        trackMixpanelEvent(MixpanelEvent.photoShared)
    }

    // MARK: Pose Suggestion Events
    func trackPoseSuggestionsToggledOn() {
        trackMixpanelEvent(MixpanelEvent.poseSuggestionsToggledOn)
    }

    func trackPoseSuggestionsToggledOff() {
        trackMixpanelEvent(MixpanelEvent.poseSuggestionsToggledOff)
    }

    func trackPoseSuggestionRequested() {
        trackMixpanelEvent(MixpanelEvent.poseSuggestionRequested)
    }

    func trackPoseSuggestionViewed(suggestionCount: Int) {
        trackMixpanelEvent(MixpanelEvent.poseSuggestionViewed, properties: [
            "suggestion_count": suggestionCount
        ])
    }

    func trackPoseSuggestionSelected(suggestionId: String, suggestionTitle: String) {
        trackMixpanelEvent(MixpanelEvent.poseSuggestionSelected, properties: [
            "suggestion_id": suggestionId,
            "suggestion_title": suggestionTitle
        ])

        // Increment pose suggestions used count
        Mixpanel.mainInstance().people.increment(properties: [UserProperty.poseSuggestionsUsedCount: 1])
    }

    // MARK: Camera Settings Events
    func trackCameraSettingsToggledOn() {
        trackMixpanelEvent(MixpanelEvent.cameraSettingsToggledOn)
    }

    func trackCameraSettingsToggledOff() {
        trackMixpanelEvent(MixpanelEvent.cameraSettingsToggledOff)
    }

    func trackFilterApplied(filterName: String) {
        trackMixpanelEvent(MixpanelEvent.filterApplied, properties: [
            "filter_name": filterName
        ])

        // Add to filters used array
        Mixpanel.mainInstance().people.append(properties: [UserProperty.filtersUsed: filterName])
    }

    func trackAspectRatioChanged(newRatio: String) {
        trackMixpanelEvent(MixpanelEvent.aspectRatioChanged, properties: [
            "aspect_ratio": newRatio
        ])
    }

    func trackTimerChanged(timerDuration: String) {
        trackMixpanelEvent(MixpanelEvent.timerChanged, properties: [
            "timer_duration": timerDuration
        ])
    }

    func trackFilterDrawerOpened() {
        trackMixpanelEvent(MixpanelEvent.filterDrawerOpened)
    }

    func trackWBPresetChanged(presetName: String) {
        trackMixpanelEvent(MixpanelEvent.wbPresetChanged, properties: [
            "wb_preset": presetName
        ])
    }

    // MARK: - Private Helper Methods

    private func trackMixpanelEvent(_ eventName: String, properties: [String: MixpanelType] = [:]) {
        // Ensure user properties are set up on first event (after Mixpanel initialization)
        if !userPropertiesSetup {
            setupUserProperties()
            userPropertiesSetup = true
        }

        Mixpanel.mainInstance().track(event: eventName, properties: properties)
        print("📊 Mixpanel Event: \(eventName) - Properties: \(properties)")
    }

    private func trackAppsFlyerEvent(_ eventName: String, values: [String: Any] = [:]) {
        AppsFlyerLib.shared().logEvent(eventName, withValues: values)
        print("📊 AppsFlyer Event: \(eventName) - Values: \(values)")
    }

    // MARK: - AppsFlyer Revenue Events (called from PurchaseController)

    func trackAppsFlyerPurchase(productId: String, revenue: Double, currency: String) {
        trackAppsFlyerEvent(AppsFlyerEvent.purchase, values: [
            AFEventParamContentId: productId,
            AFEventParamRevenue: revenue,
            AFEventParamCurrency: currency,
            AFEventParamContentType: "subscription"
        ])
    }

    func trackAppsFlyerTrialStarted(productId: String, revenue: Double, currency: String) {
        trackAppsFlyerEvent(AppsFlyerEvent.trialStarted, values: [
            AFEventParamContentId: productId,
            AFEventParamRevenue: revenue,
            AFEventParamCurrency: currency,
            AFEventParamContentType: "trial"
        ])
    }
}

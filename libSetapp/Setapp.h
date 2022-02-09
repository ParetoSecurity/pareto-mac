//
//  Setapp.h
//  Setapp
//
//  Created on 7/15/2016.
//  Copyright © 2016 Setapp Ltd. All rights reserved.
//

#if __has_feature(modules)
@import Foundation;
#else
#import <Foundation/Foundation.h>
#endif

#if !__has_feature(nullability)
#define _Nonnull
#define _Nullable
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
#endif

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Library Version API

/*! @brief Constant that shows library version
 */
static NSString * const SCLibraryVersion = @"1.6.6";

#pragma mark - Request authorization code

/// Enumerates the available authorization scope values.
typedef NSString *const SCVendorAuthScope NS_EXTENSIBLE_STRING_ENUM;

/// Grants authorization to check if the current Setapp user has an active subscription and thus can access the application.
FOUNDATION_EXTERN SCVendorAuthScope SCVendorAuthScopeApplicationAccess;

/// Requests an authorization code for communication with Setapp backend server.
/// The code is used to obtain the access & refresh tokens from the Vendor API.
///
/// This function requires an Internet connection and will fail with a corresponding error if the device is offline.
///
/// @param clientID A string ID generated for the app's client in the Setapp developer account.
/// @param scope An array of case-sensitive strings that specify the scope of functionalities to be authorized for the app's client.
/// See the @c SCVendorAuthScope enum for the full list of available values.
/// @param completionHandler A block executed upon the request completion.
/// The first parameter is an optional @c NSString containing the requested auth code,
/// the second parameter is an optional @c NSError containing a possible error.
FOUNDATION_EXTERN void SCRequestAuthorizationCode(NSString *clientID,
                                                  NSArray<SCVendorAuthScope> *scope,
                                                  void(^completionHandler)(NSString *_Nullable authorizationCode,
                                                                           NSError *_Nullable error));

#pragma mark - Release Notes API

/*! @brief Shows a release notes window if the application is
 *          launched for the first time after update.
 */
FOUNDATION_EXTERN void SCShowReleaseNotesWindowIfNeeded(void);


/*! @brief Shows a window with release notes.
 */
FOUNDATION_EXTERN void SCShowReleaseNotesWindow(void);


/*! @brief Checks if a release notes window can be shown.
 *  @deprecated This method is deprecated and always returns YES.
 */
FOUNDATION_EXTERN BOOL SCCanShowReleaseNotesWindow(void) DEPRECATED_ATTRIBUTE;


#pragma mark - Usage Events API

/*! @brief Reports special application events that denote app usage.
 *  @discussion More information about special Setapp events is available in
 *              <a href="https://docs.setapp.com/docs/library-integration">the knowledge base</a>.
 *  @discussion Events must be reported only after the @c applicationDidFinishLaunching
 *              method is called (if applicable).
 *  @param eventName    Setapp event names are described in the knowledge base.
 *  @param eventInfo    Additional info about an event. Currently, not supported.
 */
FOUNDATION_EXTERN void SCReportUsageEvent(NSString *eventName, NSDictionary *_Nullable eventInfo);


#pragma mark - User Permissions API

/*!
 *  @typedef SCUserEmailSharingResponse
 *  @brief A list of a user’s possible actions in response to an email sharing dialog.
 */
typedef NS_ENUM(NSInteger, SCUserEmailSharingResponse)
{
    /// User hasn’t seen the dialog yet.
    SCUserEmailSharingResponseAbsent = 0,
    
    /// User has made a choice (allow or forbid email sharing).
    SCUserEmailSharingResponseMadeChoice,
    
    /// User has just closed the dialog without making a choice.
    SCUserEmailSharingResponseAskLater,
    
    /// The app couldn't connect to the Setapp Agent.
    SCUserEmailSharingResponseUndefined = NSNotFound
};

/*! @brief Get the user’s last action in response to the email sharing dialog.
 *  @return Returns the user’s last action.
 */
FOUNDATION_EXTERN SCUserEmailSharingResponse SCGetLastUserEmailSharingResponse(void);

/*! @brief Shows the dialog that offers sharing an email address
 *  @discussion Although you should call this method when it makes sense in the user experience flow of your app, the actual display of an email sharing dialog is governed by Setapp policy.
 *  For example, the dialog won't show if user has already shared the email or one was recently shown and user selected "later" option.
 *  Each time user selects "later" option, the presentation cooldown increases (up to one mounth).
 *  @param completionHandler Completion block with the user’s response as an input param.
 *  @returns YES if the dialog was shown. Otherwise returns NO.
 */
FOUNDATION_EXTERN BOOL SCAskUserToShareEmail(void (^_Nullable completionHandler)(SCUserEmailSharingResponse userResponse));


#pragma mark - Debug Logging API

/*! @brief Enables debug logging of Setapp Library.
 *  @discussion Disable debug logging in release builds.
 *  @code
 *  #ifdef DEBUG
 *      SCEnableDebugLogging(YES);
 *  #endif
 *  @endcode
 *  @param shouldEnable If set to YES, enables debug logging. If NO, disables it.
 */
FOUNDATION_EXTERN void SCEnableDebugLogging(BOOL shouldEnable);

NS_ASSUME_NONNULL_END

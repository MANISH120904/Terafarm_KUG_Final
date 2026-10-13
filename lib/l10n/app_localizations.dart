import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_ml.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale.fromSubtags(languageCode: 'bn', scriptCode: 'clean'),
    Locale('en'),
    Locale.fromSubtags(languageCode: 'en', scriptCode: 'cleaned'),
    Locale('gu'),
    Locale('hi'),
    Locale('kn'),
    Locale('ml'),
    Locale('mr'),
    Locale('ta'),
    Locale('te'),
    Locale('ur')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'TeraFarm'**
  String get appTitle;

  /// No description provided for @buyDirect.
  ///
  /// In en, this message translates to:
  /// **'Buy directly from farms'**
  String get buyDirect;

  /// No description provided for @noFarms.
  ///
  /// In en, this message translates to:
  /// **'No farms found.'**
  String get noFarms;

  /// No description provided for @buyer.
  ///
  /// In en, this message translates to:
  /// **'Buyer'**
  String get buyer;

  /// No description provided for @farmer.
  ///
  /// In en, this message translates to:
  /// **'Farmer'**
  String get farmer;

  /// No description provided for @ai.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get ai;

  /// No description provided for @fetchingLocation.
  ///
  /// In en, this message translates to:
  /// **'Fetching location...'**
  String get fetchingLocation;

  /// No description provided for @priceLowToHigh.
  ///
  /// In en, this message translates to:
  /// **'Price: Low to High'**
  String get priceLowToHigh;

  /// No description provided for @noDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get noDescription;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @dailyTasks.
  ///
  /// In en, this message translates to:
  /// **'Daily Tasks'**
  String get dailyTasks;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @sustainableFarming.
  ///
  /// In en, this message translates to:
  /// **'Sustainable Farming'**
  String get sustainableFarming;

  /// No description provided for @community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// No description provided for @shop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shop;

  /// No description provided for @cropSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Crop Suggestion'**
  String get cropSuggestion;

  /// No description provided for @marketPriceAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Market Price Analysis'**
  String get marketPriceAnalysis;

  /// No description provided for @listFarm.
  ///
  /// In en, this message translates to:
  /// **'List a Farm'**
  String get listFarm;

  /// No description provided for @growPlant.
  ///
  /// In en, this message translates to:
  /// **'Grow a Plant'**
  String get growPlant;

  /// No description provided for @aiPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Tera AI'**
  String get aiPageTitle;

  /// No description provided for @teraCareAI.
  ///
  /// In en, this message translates to:
  /// **'Tera Care AI'**
  String get teraCareAI;

  /// No description provided for @teraDocAI.
  ///
  /// In en, this message translates to:
  /// **'Tera Doc AI'**
  String get teraDocAI;

  /// No description provided for @teraRecommendAI.
  ///
  /// In en, this message translates to:
  /// **'Tera Recommend AI'**
  String get teraRecommendAI;

  /// No description provided for @productPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get productPageTitle;

  /// No description provided for @farmNotFound.
  ///
  /// In en, this message translates to:
  /// **'Farm not found.'**
  String get farmNotFound;

  /// No description provided for @unnamedFarm.
  ///
  /// In en, this message translates to:
  /// **'Unnamed Farm'**
  String get unnamedFarm;

  /// No description provided for @scaleLabel.
  ///
  /// In en, this message translates to:
  /// **'Scale:'**
  String get scaleLabel;

  /// No description provided for @distanceChargeLabel.
  ///
  /// In en, this message translates to:
  /// **'distance charge'**
  String get distanceChargeLabel;

  /// No description provided for @availableProducts.
  ///
  /// In en, this message translates to:
  /// **'Available products'**
  String get availableProducts;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHint;

  /// No description provided for @kgEachUnit.
  ///
  /// In en, this message translates to:
  /// **'kg Each unit'**
  String get kgEachUnit;

  /// No description provided for @buyNow.
  ///
  /// In en, this message translates to:
  /// **'Buy Now'**
  String get buyNow;

  /// No description provided for @ordersPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get ordersPageTitle;

  /// No description provided for @pendingRequests.
  ///
  /// In en, this message translates to:
  /// **'Pending requests'**
  String get pendingRequests;

  /// No description provided for @noPendingOrders.
  ///
  /// In en, this message translates to:
  /// **'No pending orders.'**
  String get noPendingOrders;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @noCompletedOrders.
  ///
  /// In en, this message translates to:
  /// **'No completed orders.'**
  String get noCompletedOrders;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @deliveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get deliveryLabel;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @addProductPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProductPageTitle;

  /// No description provided for @productNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Product Name'**
  String get productNameLabel;

  /// No description provided for @priceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get priceLabel;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @categoryVegetables.
  ///
  /// In en, this message translates to:
  /// **'Vegetables'**
  String get categoryVegetables;

  /// No description provided for @categoryFruits.
  ///
  /// In en, this message translates to:
  /// **'Fruits'**
  String get categoryFruits;

  /// No description provided for @categoryHerbs.
  ///
  /// In en, this message translates to:
  /// **'Herbs'**
  String get categoryHerbs;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @addProductButton.
  ///
  /// In en, this message translates to:
  /// **'+ Add Product'**
  String get addProductButton;

  /// No description provided for @productAddedMessage.
  ///
  /// In en, this message translates to:
  /// **'Product Added!'**
  String get productAddedMessage;

  /// No description provided for @farmDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Farm Dashboard'**
  String get farmDashboardTitle;

  /// No description provided for @totalEarnings.
  ///
  /// In en, this message translates to:
  /// **'Total Earnings'**
  String get totalEarnings;

  /// No description provided for @viewPlantAnalysis.
  ///
  /// In en, this message translates to:
  /// **'View Plant Growth Analysis'**
  String get viewPlantAnalysis;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No Data'**
  String get noData;

  /// No description provided for @yourFarm.
  ///
  /// In en, this message translates to:
  /// **'Your Farm'**
  String get yourFarm;

  /// No description provided for @noFarmRegistered.
  ///
  /// In en, this message translates to:
  /// **'No farm registered by you.'**
  String get noFarmRegistered;

  /// No description provided for @productListings.
  ///
  /// In en, this message translates to:
  /// **'Product Listings'**
  String get productListings;

  /// No description provided for @noProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found.'**
  String get noProductsFound;

  /// No description provided for @tableIndex.
  ///
  /// In en, this message translates to:
  /// **'#'**
  String get tableIndex;

  /// No description provided for @tableCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get tableCrop;

  /// No description provided for @tableStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get tableStock;

  /// No description provided for @tablePricePerKg.
  ///
  /// In en, this message translates to:
  /// **'Price per Kg'**
  String get tablePricePerKg;

  /// No description provided for @accountPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountPageTitle;

  /// No description provided for @errorLoadingProfile.
  ///
  /// In en, this message translates to:
  /// **'Error loading profile'**
  String get errorLoadingProfile;

  /// No description provided for @defaultPhone.
  ///
  /// In en, this message translates to:
  /// **'+91 00000 00000'**
  String get defaultPhone;

  /// No description provided for @defaultEmail.
  ///
  /// In en, this message translates to:
  /// **'example@email.com'**
  String get defaultEmail;

  /// No description provided for @defaultUserName.
  ///
  /// In en, this message translates to:
  /// **'User Name'**
  String get defaultUserName;

  /// No description provided for @buyerSellerLabel.
  ///
  /// In en, this message translates to:
  /// **'Buyer / Seller'**
  String get buyerSellerLabel;

  /// No description provided for @levelLabel.
  ///
  /// In en, this message translates to:
  /// **'Lvl'**
  String get levelLabel;

  /// No description provided for @xpLabel.
  ///
  /// In en, this message translates to:
  /// **'XP'**
  String get xpLabel;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get myOrders;

  /// No description provided for @badges.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get badges;

  /// No description provided for @myAddresses.
  ///
  /// In en, this message translates to:
  /// **'My Addresses'**
  String get myAddresses;

  /// No description provided for @myList.
  ///
  /// In en, this message translates to:
  /// **'My List'**
  String get myList;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @levelRoadmapTitle.
  ///
  /// In en, this message translates to:
  /// **'Level Roadmap'**
  String get levelRoadmapTitle;

  /// No description provided for @rewardToBeAnnounced.
  ///
  /// In en, this message translates to:
  /// **'Reward: To be announced'**
  String get rewardToBeAnnounced;

  /// No description provided for @eatHealthy.
  ///
  /// In en, this message translates to:
  /// **'Eat what makes you healthy'**
  String get eatHealthy;

  /// No description provided for @farmsAroundYou.
  ///
  /// In en, this message translates to:
  /// **'Farms around you'**
  String get farmsAroundYou;

  /// No description provided for @noFarmsFound.
  ///
  /// In en, this message translates to:
  /// **'No farms found.'**
  String get noFarmsFound;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get navCommunity;

  /// No description provided for @navBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get navBuy;

  /// No description provided for @navShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get navShop;

  /// No description provided for @catOnion.
  ///
  /// In en, this message translates to:
  /// **'Onion'**
  String get catOnion;

  /// No description provided for @catTomato.
  ///
  /// In en, this message translates to:
  /// **'Tomato'**
  String get catTomato;

  /// No description provided for @catBeans.
  ///
  /// In en, this message translates to:
  /// **'Beans'**
  String get catBeans;

  /// No description provided for @catGreens.
  ///
  /// In en, this message translates to:
  /// **'Greens'**
  String get catGreens;

  /// No description provided for @myCommunity.
  ///
  /// In en, this message translates to:
  /// **'My community'**
  String get myCommunity;

  /// No description provided for @leaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboard;

  /// No description provided for @collab.
  ///
  /// In en, this message translates to:
  /// **'Collab'**
  String get collab;

  /// No description provided for @forum.
  ///
  /// In en, this message translates to:
  /// **'Forum'**
  String get forum;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @editFarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Farm'**
  String get editFarmTitle;

  /// No description provided for @changeImage.
  ///
  /// In en, this message translates to:
  /// **'Change Image'**
  String get changeImage;

  /// No description provided for @farmDataNotFound.
  ///
  /// In en, this message translates to:
  /// **'Farm data not found.'**
  String get farmDataNotFound;

  /// No description provided for @errorLoadingFarmData.
  ///
  /// In en, this message translates to:
  /// **'Error loading farm data: {error}'**
  String errorLoadingFarmData(Object error);

  /// No description provided for @errorPickingImage.
  ///
  /// In en, this message translates to:
  /// **'Error picking image: {error}'**
  String errorPickingImage(Object error);

  /// No description provided for @errorUploadingImage.
  ///
  /// In en, this message translates to:
  /// **'Error uploading image: {error}'**
  String errorUploadingImage(Object error);

  /// No description provided for @farmUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Farm updated successfully!'**
  String get farmUpdatedSuccess;

  /// No description provided for @farmNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Farm Name'**
  String get farmNameLabel;

  /// No description provided for @contactNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact Number'**
  String get contactNumberLabel;

  /// No description provided for @farmDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Farm Description'**
  String get farmDescriptionLabel;

  /// No description provided for @scaleSmall.
  ///
  /// In en, this message translates to:
  /// **'Small Scale'**
  String get scaleSmall;

  /// No description provided for @scaleLarge.
  ///
  /// In en, this message translates to:
  /// **'Large Scale'**
  String get scaleLarge;

  /// No description provided for @productsLabel.
  ///
  /// In en, this message translates to:
  /// **'Products:'**
  String get productsLabel;

  /// No description provided for @productIndex.
  ///
  /// In en, this message translates to:
  /// **'Product {index}'**
  String productIndex(Object index);

  /// No description provided for @cropNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Crop Name'**
  String get cropNameLabel;

  /// No description provided for @stockLabel.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stockLabel;

  /// No description provided for @pricePerKgLabel.
  ///
  /// In en, this message translates to:
  /// **'Price per kg'**
  String get pricePerKgLabel;

  /// No description provided for @removeProduct.
  ///
  /// In en, this message translates to:
  /// **'Remove Product'**
  String get removeProduct;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProduct;

  /// No description provided for @updateFarmButton.
  ///
  /// In en, this message translates to:
  /// **'Update Farm'**
  String get updateFarmButton;

  /// No description provided for @errorEnterFarmName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a farm name'**
  String get errorEnterFarmName;

  /// No description provided for @errorEnterLocation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a location'**
  String get errorEnterLocation;

  /// No description provided for @errorEnterContact.
  ///
  /// In en, this message translates to:
  /// **'Please enter a contact number'**
  String get errorEnterContact;

  /// No description provided for @errorEnterDescription.
  ///
  /// In en, this message translates to:
  /// **'Please enter a farm description'**
  String get errorEnterDescription;

  /// No description provided for @errorEnterCropName.
  ///
  /// In en, this message translates to:
  /// **'Please enter crop name'**
  String get errorEnterCropName;

  /// No description provided for @errorEnterStock.
  ///
  /// In en, this message translates to:
  /// **'Please enter stock'**
  String get errorEnterStock;

  /// No description provided for @errorEnterPrice.
  ///
  /// In en, this message translates to:
  /// **'Please enter price'**
  String get errorEnterPrice;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'My email Address'**
  String get emailLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneLabel;

  /// No description provided for @localityLabel.
  ///
  /// In en, this message translates to:
  /// **'Locality'**
  String get localityLabel;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @errorEmptyField.
  ///
  /// In en, this message translates to:
  /// **'This field cannot be empty'**
  String get errorEmptyField;

  /// No description provided for @errorUploadingProfileImage.
  ///
  /// In en, this message translates to:
  /// **'Error uploading profile image: {error}'**
  String errorUploadingProfileImage(Object error);

  /// No description provided for @profileUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdatedSuccess;

  /// No description provided for @errorSavingProfile.
  ///
  /// In en, this message translates to:
  /// **'Error saving profile: {error}'**
  String errorSavingProfile(Object error);

  /// No description provided for @growPlantTitle.
  ///
  /// In en, this message translates to:
  /// **'Grow a Plant'**
  String get growPlantTitle;

  /// No description provided for @cropStageLabel.
  ///
  /// In en, this message translates to:
  /// **'Crop Stage'**
  String get cropStageLabel;

  /// No description provided for @cityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get cityLabel;

  /// No description provided for @registerPlantButton.
  ///
  /// In en, this message translates to:
  /// **'Register Plant'**
  String get registerPlantButton;

  /// No description provided for @plantRegisteredSuccess.
  ///
  /// In en, this message translates to:
  /// **'Plant registered successfully!'**
  String get plantRegisteredSuccess;

  /// No description provided for @errorSelectStage.
  ///
  /// In en, this message translates to:
  /// **'Please select a crop stage'**
  String get errorSelectStage;

  /// No description provided for @errorEnterCity.
  ///
  /// In en, this message translates to:
  /// **'Please enter the city'**
  String get errorEnterCity;

  /// No description provided for @stageSeed.
  ///
  /// In en, this message translates to:
  /// **'Seed'**
  String get stageSeed;

  /// No description provided for @stageSapling.
  ///
  /// In en, this message translates to:
  /// **'Sapling'**
  String get stageSapling;

  /// No description provided for @stageBud.
  ///
  /// In en, this message translates to:
  /// **'Bud'**
  String get stageBud;

  /// No description provided for @stageFlower.
  ///
  /// In en, this message translates to:
  /// **'Flower'**
  String get stageFlower;

  /// No description provided for @stageFruit.
  ///
  /// In en, this message translates to:
  /// **'Fruit'**
  String get stageFruit;

  /// No description provided for @leaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboardTitle;

  /// No description provided for @tabGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get tabGlobal;

  /// No description provided for @tabLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get tabLocal;

  /// No description provided for @errorLoadingLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Error loading leaderboard'**
  String get errorLoadingLeaderboard;

  /// No description provided for @unknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownUser;

  /// No description provided for @youLabel.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get youLabel;

  /// No description provided for @listFarmTitle.
  ///
  /// In en, this message translates to:
  /// **'List a Farm'**
  String get listFarmTitle;

  /// No description provided for @uploadImageHint.
  ///
  /// In en, this message translates to:
  /// **'Please upload a square image:'**
  String get uploadImageHint;

  /// No description provided for @noImageSelected.
  ///
  /// In en, this message translates to:
  /// **'No image selected.'**
  String get noImageSelected;

  /// No description provided for @chooseFileButton.
  ///
  /// In en, this message translates to:
  /// **'Choose File'**
  String get chooseFileButton;

  /// No description provided for @fileChosenLabel.
  ///
  /// In en, this message translates to:
  /// **'File Chosen'**
  String get fileChosenLabel;

  /// No description provided for @productDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Product Details:'**
  String get productDetailsLabel;

  /// No description provided for @removeProductButton.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeProductButton;

  /// No description provided for @createFarmButton.
  ///
  /// In en, this message translates to:
  /// **'Create a Farm'**
  String get createFarmButton;

  /// No description provided for @farmCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Farm created successfully!'**
  String get farmCreatedSuccess;

  /// No description provided for @errorSavingFarm.
  ///
  /// In en, this message translates to:
  /// **'Error saving farm details: {error}'**
  String errorSavingFarm(Object error);

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @farm.
  ///
  /// In en, this message translates to:
  /// **'Farm'**
  String get farm;

  /// No description provided for @userName.
  ///
  /// In en, this message translates to:
  /// **'User Name'**
  String get userName;

  /// No description provided for @teradocTitle.
  ///
  /// In en, this message translates to:
  /// **'Teradoc Plant Health Analyzer'**
  String get teradocTitle;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @noAnalysisYet.
  ///
  /// In en, this message translates to:
  /// **'No analysis yet.'**
  String get noAnalysisYet;

  /// No description provided for @teradocWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: This application is designed exclusively for plant health analysis. Uploading images that do not depict plants may yield irrelevant or inaccurate results. Please upload only images of plants.'**
  String get teradocWarning;

  /// No description provided for @teradocPrompt.
  ///
  /// In en, this message translates to:
  /// **'You are Teradoc, the plant doctor. Analyze the health of the plant in the provided image, identify any diseases, and provide necessary treatment recommendations.'**
  String get teradocPrompt;

  /// No description provided for @errorAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Error analyzing image: {error}'**
  String errorAnalyzing(Object error);

  /// No description provided for @enterCity.
  ///
  /// In en, this message translates to:
  /// **'Enter City'**
  String get enterCity;

  /// No description provided for @getWeather.
  ///
  /// In en, this message translates to:
  /// **'Get Weather'**
  String get getWeather;

  /// No description provided for @fetchWeatherFirst.
  ///
  /// In en, this message translates to:
  /// **'Please fetch weather first.'**
  String get fetchWeatherFirst;

  /// No description provided for @enterPlant.
  ///
  /// In en, this message translates to:
  /// **'Enter Plant Name'**
  String get enterPlant;

  /// No description provided for @getTips.
  ///
  /// In en, this message translates to:
  /// **'Get Sustainable Tips'**
  String get getTips;

  /// No description provided for @tryAnother.
  ///
  /// In en, this message translates to:
  /// **'Try Another Plant'**
  String get tryAnother;

  /// No description provided for @translationInstruction.
  ///
  /// In en, this message translates to:
  /// **'Translate the following text while preserving meaning:'**
  String get translationInstruction;

  /// No description provided for @welcomeTo.
  ///
  /// In en, this message translates to:
  /// **'Welcome to'**
  String get welcomeTo;

  /// No description provided for @unableFetchLocation.
  ///
  /// In en, this message translates to:
  /// **'Unable to fetch location'**
  String get unableFetchLocation;

  /// No description provided for @market.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get market;

  /// No description provided for @tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// No description provided for @sustainable.
  ///
  /// In en, this message translates to:
  /// **'Sustainable Farming'**
  String get sustainable;

  /// No description provided for @plantDoctor.
  ///
  /// In en, this message translates to:
  /// **'Plant Doctor'**
  String get plantDoctor;

  /// No description provided for @plantSuggest.
  ///
  /// In en, this message translates to:
  /// **'Plant Suggest'**
  String get plantSuggest;

  /// No description provided for @plantCare.
  ///
  /// In en, this message translates to:
  /// **'Plant Care'**
  String get plantCare;

  /// No description provided for @sustainability.
  ///
  /// In en, this message translates to:
  /// **'Green Tips (Sustainability)'**
  String get sustainability;

  /// No description provided for @rover.
  ///
  /// In en, this message translates to:
  /// **'Rover'**
  String get rover;

  /// No description provided for @get.
  ///
  /// In en, this message translates to:
  /// **'Get'**
  String get get;

  /// No description provided for @plant.
  ///
  /// In en, this message translates to:
  /// **'Plant'**
  String get plant;

  /// No description provided for @myFarm.
  ///
  /// In en, this message translates to:
  /// **'My Farm'**
  String get myFarm;

  /// No description provided for @plantAR.
  ///
  /// In en, this message translates to:
  /// **'Plant AR'**
  String get plantAR;

  /// No description provided for @arAppNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Unity AR app not installed'**
  String get arAppNotInstalled;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get hindi;

  /// No description provided for @tamil.
  ///
  /// In en, this message translates to:
  /// **'Tamil'**
  String get tamil;

  /// No description provided for @telugu.
  ///
  /// In en, this message translates to:
  /// **'Telugu'**
  String get telugu;

  /// No description provided for @plantCareAI.
  ///
  /// In en, this message translates to:
  /// **'Plant Care AI'**
  String get plantCareAI;

  /// No description provided for @greenTips.
  ///
  /// In en, this message translates to:
  /// **'Green Tips (Sustainability)'**
  String get greenTips;

  /// No description provided for @collaborate.
  ///
  /// In en, this message translates to:
  /// **'Collaborate'**
  String get collaborate;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @farmFeatures.
  ///
  /// In en, this message translates to:
  /// **'Farm Features'**
  String get farmFeatures;

  /// No description provided for @manageFarms.
  ///
  /// In en, this message translates to:
  /// **'Manage Farms'**
  String get manageFarms;

  /// No description provided for @trackGrowth.
  ///
  /// In en, this message translates to:
  /// **'Track Growth'**
  String get trackGrowth;

  /// No description provided for @communityFeatures.
  ///
  /// In en, this message translates to:
  /// **'Community Features'**
  String get communityFeatures;

  /// No description provided for @connectCollaborateGrow.
  ///
  /// In en, this message translates to:
  /// **'Connect, Collaborate & Grow Together'**
  String get connectCollaborateGrow;

  /// No description provided for @workTogetherProjects.
  ///
  /// In en, this message translates to:
  /// **'Work together on projects'**
  String get workTogetherProjects;

  /// No description provided for @discussShareIdeas.
  ///
  /// In en, this message translates to:
  /// **'Discuss and share ideas'**
  String get discussShareIdeas;

  /// No description provided for @topPerformingFarmers.
  ///
  /// In en, this message translates to:
  /// **'See top performing farmers'**
  String get topPerformingFarmers;

  /// No description provided for @aiTools.
  ///
  /// In en, this message translates to:
  /// **'AI Tools'**
  String get aiTools;

  /// No description provided for @diagnosePlantDiseases.
  ///
  /// In en, this message translates to:
  /// **'Diagnose plant diseases using AI'**
  String get diagnosePlantDiseases;

  /// No description provided for @personalizedCropRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Get personalized crop recommendations'**
  String get personalizedCropRecommendations;

  /// No description provided for @smartPlantCareGuidance.
  ///
  /// In en, this message translates to:
  /// **'Smart plant care guidance'**
  String get smartPlantCareGuidance;

  /// No description provided for @sustainableFarmingPractices.
  ///
  /// In en, this message translates to:
  /// **'Sustainable farming practices'**
  String get sustainableFarmingPractices;

  /// No description provided for @controlSmartRovers.
  ///
  /// In en, this message translates to:
  /// **'Control smart agricultural rovers'**
  String get controlSmartRovers;

  /// No description provided for @aiPoweredFarmingAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI-powered farming assistant'**
  String get aiPoweredFarmingAssistant;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'bn',
        'en',
        'gu',
        'hi',
        'kn',
        'ml',
        'mr',
        'ta',
        'te',
        'ur'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'bn':
      {
        switch (locale.scriptCode) {
          case 'clean':
            return AppLocalizationsBnClean();
        }
        break;
      }
    case 'en':
      {
        switch (locale.scriptCode) {
          case 'cleaned':
            return AppLocalizationsEnCleaned();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'gu':
      return AppLocalizationsGu();
    case 'hi':
      return AppLocalizationsHi();
    case 'kn':
      return AppLocalizationsKn();
    case 'ml':
      return AppLocalizationsMl();
    case 'mr':
      return AppLocalizationsMr();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

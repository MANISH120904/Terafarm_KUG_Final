# Navigation System Documentation

## Overview
This document describes the unified navigation system implemented across the AgriGuru app to provide consistent navigation experience and reduce code duplication.

## Architecture

### 1. NavigationService (`lib/services/navigation_service.dart`)
Central service that handles all page navigation logic.

**Key Features:**
- Defines page indices as constants
- Provides smooth page transitions
- Handles buyer/seller mode switching
- Centralized route management

**Page Indices:**
```dart
static const int homeIndex = 0;     // SellerPage
static const int marketIndex = 1;   // MarketplacePage  
static const int aiIndex = 2;       // AIPage
static const int communityIndex = 3; // CommunityPage
```

**Main Methods:**
- `getPageByIndex(int index)` - Returns widget for given index
- `navigateToPage(context, targetIndex, currentIndex)` - Navigate with animation
- `navigateToBuyerSeller(context, isSeller)` - Switch buyer/seller mode
- `getPageTitle(int index)` - Get page title for index

### 2. CustomBottomNav (`lib/widgets/custom_bottom_nav.dart`)
Reusable bottom navigation bar component used across all main pages.

**Key Features:**
- Consistent styling across all pages
- Automatic current page highlighting
- Smooth transition animations
- Integrated with NavigationService

**Usage:**
```dart
bottomNavigationBar: const CustomBottomNav(
  currentIndex: NavigationService.homeIndex,
),
```

## Implementation

### Updated Pages
All main pages now use the unified navigation system:

1. **SellerPage** (`seller_page.dart`)
   - Index: `NavigationService.homeIndex` (0)
   - Uses: `CustomBottomNav(currentIndex: NavigationService.homeIndex)`

2. **MarketplacePage** (`marketplace.dart`)
   - Index: `NavigationService.marketIndex` (1)  
   - Uses: `CustomBottomNav(currentIndex: NavigationService.marketIndex)`

3. **AIPage** (`ai_page.dart`)
   - Index: `NavigationService.aiIndex` (2)
   - Uses: `CustomBottomNav(currentIndex: NavigationService.aiIndex)`

4. **CommunityPage** (`Community_page.dart`)
   - Index: `NavigationService.communityIndex` (3)
   - Uses: `CustomBottomNav(currentIndex: NavigationService.communityIndex)`

### Required Imports
Each page using the navigation system needs:
```dart
import 'widgets/custom_bottom_nav.dart';
import 'services/navigation_service.dart';
```

### Buyer/Seller Toggle
Updated to use NavigationService for consistent transitions:
```dart
// Navigate to buyer mode
NavigationService.navigateToBuyerSeller(context, false);

// Navigate to seller mode  
NavigationService.navigateToBuyerSeller(context, true);
```

## Benefits

1. **Code Reduction**: Eliminated ~200 lines of duplicated navigation code across 4 pages
2. **Consistency**: Uniform styling and behavior across all pages
3. **Maintainability**: Single point of control for navigation logic
4. **Extensibility**: Easy to add new pages or modify navigation behavior
5. **Performance**: Optimized transitions and reduced widget rebuilds

## Animation System

### Page Transitions
- **Scale Animation**: Smooth scale from 0.85 to 1.0
- **Fade Animation**: Smooth opacity transition
- **Duration**: 400ms forward, 300ms reverse
- **Curve**: `easeOutCubic` for natural feel

### Button Highlighting
- Current page button gets white background with opacity
- Border highlighting with rounded corners
- Smooth color transitions

## Usage Guidelines

### Adding New Pages
1. Add page index constant to `NavigationService`
2. Update `getPageByIndex()` method
3. Add case in navigation switch statement
4. Use `CustomBottomNav` with correct index

### Customizing Transitions
Modify transition logic in `NavigationService.navigateToPage()`:
```dart
transitionsBuilder: (context, animation, secondaryAnimation, child) {
  // Custom transition logic here
}
```

### Styling Modifications
Update `CustomBottomNav` for visual changes:
- Colors in gradient and highlights
- Icon sizes and padding
- Border radius and shadows

## File Structure
```
lib/
├── services/
│   └── navigation_service.dart     # Central navigation logic
├── widgets/
│   └── custom_bottom_nav.dart      # Reusable bottom nav widget
├── seller_page.dart               # Updated to use new system
├── marketplace.dart               # Updated to use new system  
├── ai_page.dart                   # Updated to use new system
└── Community_page.dart            # Updated to use new system
```

## Migration Notes

### Before (Each Page)
- 80+ lines of duplicate navigation code
- Inconsistent styling across pages
- Manual route management
- Separate animation implementations

### After (Unified System)
- 2 lines: Import and usage
- Consistent styling and behavior
- Centralized route management
- Shared animation system

This navigation system provides a solid foundation for the app's navigation needs while maintaining consistency and reducing maintenance overhead.

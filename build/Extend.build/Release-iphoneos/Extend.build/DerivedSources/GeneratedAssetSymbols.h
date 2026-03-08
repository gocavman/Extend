#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "Apple" asset catalog image resource.
static NSString * const ACImageNameApple AC_SWIFT_PRIVATE = @"Apple";

/// The "Dumbbell" asset catalog image resource.
static NSString * const ACImageNameDumbbell AC_SWIFT_PRIVATE = @"Dumbbell";

/// The "Kettlebell" asset catalog image resource.
static NSString * const ACImageNameKettlebell AC_SWIFT_PRIVATE = @"Kettlebell";

/// The "Shaker" asset catalog image resource.
static NSString * const ACImageNameShaker AC_SWIFT_PRIVATE = @"Shaker";

/// The "topview1" asset catalog image resource.
static NSString * const ACImageNameTopview1 AC_SWIFT_PRIVATE = @"topview1";

/// The "topview2" asset catalog image resource.
static NSString * const ACImageNameTopview2 AC_SWIFT_PRIVATE = @"topview2";

/// The "topview3" asset catalog image resource.
static NSString * const ACImageNameTopview3 AC_SWIFT_PRIVATE = @"topview3";

#undef AC_SWIFT_PRIVATE

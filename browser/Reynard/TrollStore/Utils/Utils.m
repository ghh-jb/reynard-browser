//
//  Utils.m
//  Reynard
//
//  Created by Minh Ton on 12/4/26.
//

// https://github.com/AngelAuraMC/Amethyst-iOS/blob/ed267f52dafa24219f1166c542294b0e682ebc64/Natives/utils.m

#import "Utils.h"

CFTypeRef SecTaskCopyValueForEntitlement(void *task, NSString *entitlement, CFErrorRef _Nullable *error);
void *SecTaskCreateFromSelf(CFAllocatorRef allocator);

BOOL getEntitlementValue(NSString *key) {
    void *secTask = SecTaskCreateFromSelf(NULL);
    if (!secTask) return NO;
    
    CFTypeRef value = SecTaskCopyValueForEntitlement(secTask, key, nil);
    CFRelease(secTask);
    if (!value) return NO;
    
    BOOL hasValue = ![(__bridge id)value isKindOfClass:NSNumber.class] || [(__bridge NSNumber *)value boolValue];
    CFRelease(value);
    return hasValue;
}

//
//  UIScrollViewProcessor.m
//  nib2objc
//
//  Created by Adrian on 3/15/09.
//  Adrian Kosmaczewski 2009
//

#import "UIScrollViewProcessor.h"
#import "NSNumber+Nib2ObjcExtensions.h"

@implementation UIScrollViewProcessor

- (void)dealloc
{
    [super dealloc];
}

- (NSString *)getProcessedClassName
{
    return @"UIScrollView";
}

- (void)processKey:(id)item value:(id)value
{
    if ([item isEqualToString:@"indicatorStyle"])
    {
        [output setObject:[value scrollViewIndicatorStyleString] forKey:item];
    }
    else if ([item isEqualToString:@"showsHorizontalScrollIndicator"] && [value integerValue] != 1)
    {
        [output setObject:[value booleanString] forKey:item];
    }
    else if ([item isEqualToString:@"showsVerticalScrollIndicator"] && [value integerValue] != 1)
    {
        [output setObject:[value booleanString] forKey:item];
    }
    else if ([item isEqualToString:@"scrollEnabled"] && [value integerValue] != 1)
    {
        [output setObject:[value booleanString] forKey:item];
    }
    else if ([item isEqualToString:@"pagingEnabled"] && [value integerValue] != 0)
    {
        [output setObject:[value booleanString] forKey:item];
    }
    else if ([item isEqualToString:@"directionalLockEnabled"] && [value integerValue] != 0)
    {
        [output setObject:[value booleanString] forKey:item];
    }
    else if ([item isEqualToString:@"bounces"] && [value integerValue] != 1)
    {
        [output setObject:[value booleanString] forKey:item];
    }
    else if ([item isEqualToString:@"alwaysBounceHorizontal"] && [value integerValue] != 0)
    {
        [output setObject:[value booleanString] forKey:item];
    }
    else if ([item isEqualToString:@"alwaysBounceVertical"] && [value integerValue] != 0)
    {
        [output setObject:[value booleanString] forKey:item];
    }
    else if ([item isEqualToString:@"maximumZoomScale"] && [value floatValue] != 1.0)
    {
        [output setObject:[value floatString] forKey:item];
    }
    else if ([item isEqualToString:@"minimumZoomScale"] && [value floatValue] != 1.0)
    {
        [output setObject:[value floatString] forKey:item];
    }
    else if ([item isEqualToString:@"bouncesZoom"] && [value integerValue] != 1)
    {
        [output setObject:[value booleanString] forKey:item];
    }
    else if ([item isEqualToString:@"delaysContentTouches"] && [value integerValue] != 1)
    {
        [output setObject:[value booleanString] forKey:item];
    }
    else if ([item isEqualToString:@"canCancelContentTouches"] && [value integerValue] != 1)
    {
        [output setObject:[value booleanString] forKey:item];
    }
    else
    {
        [super processKey:item value:value];
    }
}

@end

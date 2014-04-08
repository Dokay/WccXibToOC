//
//  UILabelProcessor.m
//  nib2objc
//
//  Created by Adrian on 3/14/09.
//  Adrian Kosmaczewski 2009
//

#import "UILabelProcessor.h"
#import "NSString+Nib2ObjcExtensions.h"
#import "NSNumber+Nib2ObjcExtensions.h"
#import "NSDictionary+Nib2ObjcExtensions.h"

@implementation UILabelProcessor

- (void)dealloc
{
    [super dealloc];
}

- (NSString *)getProcessedClassName
{
    return @"UILabel";
}

- (void)processKey:(id)item value:(id)value
{
    if ([item isEqualToString:@"text"])
    {
        [output setObject:[value quotedAsCodeString] forKey:item];
    }
    else if ([item isEqualToString:@"textAlignment"] && [value integerValue] != 0)
    {
        [output setObject:[value textAlignmentString] forKey:item];
    }
    else if ([item isEqualToString:@"textColor"])
    {
        [output setObject:[value colorString] forKey:item];
    }
    else if ([item isEqualToString:@"font"])
    {
        [output setObject:[value fontString] forKey:item];
    }
    else if ([item isEqualToString:@"adjustsFontSizeToFitWidth"] && [value integerValue] != NO)
    {
        [output setObject:[value booleanString] forKey:item];
    }
    else if ([item isEqualToString:@"minimumFontSize"] && [value integerValue] != 0)
    {
        [output setObject:[value floatString] forKey:item];
    }
    else if ([item isEqualToString:@"enabled"] && [value integerValue] != YES)
    {
        [output setObject:[value booleanString] forKey:item];
    }
    else if ([item isEqualToString:@"baselineAdjustment"] && [value integerValue] != 0)//UIBaselineAdjustmentAlignBaselines
    {
        [output setObject:[value baselineAdjustmentString] forKey:item];
    }
    else if ([item isEqualToString:@"lineBreakMode"])
    {
        [output setObject:[value lineBreakModeString] forKey:item];
    }
    else if ([item isEqualToString:@"numberOfLines"] && [value integerValue] != 1)
    {
        [output setObject:[value intString] forKey:item];
    }
    else if ([item isEqualToString:@"shadowOffset"] && ![value isEqualToString:@"{0, -1}"])
    {
        [output setObject:[value sizeString] forKey:item];
    }
    else if ([item isEqualToString:@"shadowColor"])
    {
        [output setObject:[value colorString] forKey:item];
    }
    else if ([item isEqualToString:@"highlightedColor"])
    {
        [output setObject:[value colorString] forKey:@"highlightedTextColor"];
    }
    else if ([item isEqualToString:@"userInteractionEnabled"])
    {
        if([value integerValue] != 0)
        {
           [output setObject:[value booleanString] forKey:item];
        }
    }
    else if ([item isEqualToString:@"clipsSubviews"])
    {
        if ([value integerValue] != 1) {
            item = @"clipsToBounds";
            [output setObject:[value booleanString] forKey:item];
        }
    }
    else if ([item isEqualToString:@"opaqueForDevice"])
    {
        if ([value integerValue] != 0) {
            item = @"opaque";
            [output setObject:[value booleanString] forKey:item];
        }
    }
    else if ([item isEqualToString:@"contentMode"] )
    {
        if ([value integerValue] != 7) {
             [output setObject:[value contentModeString] forKey:item];
        }
    }
    else
    {
        [super processKey:item value:value];
    }
}

@end

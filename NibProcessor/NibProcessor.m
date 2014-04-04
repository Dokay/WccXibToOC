//
//  NibProcessor.m
//  nib2objc
//
//  Created by Adrian on 3/13/09.
//  Adrian Kosmaczewski 2009
//

#import "NibProcessor.h"
#import "Processor.h"
#import "NSString+Nib2ObjcExtensions.h"

@interface NibProcessor ()

- (void)getDictionaryFromNIB;
- (void)parseChildren:(NSDictionary *)dict withObjects:(NSDictionary *)objects;
- (NSString *)instanceNameForObject:(id)obj :(NSString *)ID;

@end


@implementation NibProcessor
{
    NSArray *arrOutLetName;
    
    NSDictionary *_dicObjectsConnects;
}

@dynamic input;
@synthesize output = _output;
@synthesize codeStyle = _codeStyle;

- (id)init
{
    if (self = [super init])
    {
        self.codeStyle = NibProcessorCodeStyleProperties;
    }
    return self;
}

- (void)dealloc
{
    [_filename release];
    [_output release];
    [_dictionary release];
    [_data release];
    [super dealloc];
}

#pragma mark -
#pragma mark Properties

- (NSString *)input
{
    return _filename;
}

- (void)setInput:(NSString *)newFilename
{
    [_filename release];
    _filename = nil;
    _filename = [newFilename copy];
    [self getDictionaryFromNIB];
    
    //    [self getOutLetFromNIB];
}

- (NSString *)inputAsText
{
    return [[[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding] autorelease];
}

- (NSDictionary *)inputAsDictionary
{
    NSString *errorStr = nil;
    NSPropertyListFormat format;
    NSDictionary *propertyList = [NSPropertyListSerialization propertyListFromData:_data
                                                                  mutabilityOption:NSPropertyListImmutable
                                                                            format:&format
                                                                  errorDescription:&errorStr];
    [errorStr release];
    return propertyList;
}

#pragma mark -
#pragma mark Private methods

//- (void)getOutLetFromNIB
//{
//    //    echo "$(grep .png ./ddd.txt)" > ddd.txt
//
//    NSArray *arguments = [NSArray arrayWithObjects: @"<outlet",
//                          _filename, nil];
//    NSTask *task = [[NSTask alloc] init];
//    NSPipe *pipe = [NSPipe pipe];
//    NSFileHandle *readHandle = [pipe fileHandleForReading];
//    NSData *temp = nil;
//
//    NSMutableData *tempData = [[NSMutableData alloc]init];
//
//    [task setLaunchPath:@"/usr/bin/grep"];
//    [task setArguments:arguments];
//    [task setStandardOutput:pipe];
//    [task launch];
//
//    while ((temp = [readHandle availableData]) && [temp length])
//    {
//        [tempData appendData:temp];
//    }
//    NSString *strOutLetResult = [[NSString alloc] initWithData:tempData encoding:NSASCIIStringEncoding];
//    arrOutLetName =  [strOutLetResult componentsSeparatedByString:@"outlet"];
//
//    [task release];
//
//}

- (void)getDictionaryFromNIB
{
    // Build the NSTask that will run the ibtool utility
    NSArray *arguments = [NSArray arrayWithObjects:_filename, @"--objects",
                          @"--hierarchy", @"--connections", @"--classes", @"--all",nil];
    NSTask *task = [[NSTask alloc] init];
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *readHandle = [pipe fileHandleForReading];
    NSData *temp = nil;
    
    [_data release];
    _data = [[NSMutableData alloc] init];
    
    [task setLaunchPath:@"/usr/bin/ibtool"];
    [task setArguments:arguments];
    [task setStandardOutput:pipe];
    [task launch];
    
    while ((temp = [readHandle availableData]) && [temp length])
    {
        [_data appendData:temp];
    }
    
    // This dictionary is ready to be parsed, and it contains
    // everything we need from the NIB file.
    _dictionary = [[self inputAsDictionary] retain];
    
    [task release];
}

- (void)process
{
    //    NSDictionary *nibClasses = [_dictionary objectForKey:@"com.apple.ibtool.document.classes"];
    _dicObjectsConnects = [_dictionary objectForKey:@"com.apple.ibtool.document.connections"];
    NSDictionary *nibObjects = [_dictionary objectForKey:@"com.apple.ibtool.document.objects"];
    NSMutableDictionary *objects = [[NSMutableDictionary alloc] init];
    
    for (NSDictionary *key in nibObjects)
    {
        id object = [nibObjects objectForKey:key];
        NSString *klass = [object objectForKey:@"class"];
        
        Processor *processor = [Processor processorForClass:klass];
        
        if (processor == nil)
        {
#ifdef CONFIGURATION_Debug
            // Get notified about classes not yet handled by this utility
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            [dict setObject:klass forKey:@"// unknown object (yet)"];
            [objects setObject:dict forKey:key];
            [dict release];
#endif
        }
        else
        {
            NSDictionary *dict = [processor processObject:object];
            [objects setObject:dict forKey:key];
        }
    }
    
    // Let's print everything as source code
    [_output release];
    _output = [[NSMutableString alloc] init];
     [_output appendString:@"- (void)initUIWithXib\n"];
    [_output appendString:@"{\n"];
    for (NSString *identifier in objects)
    {
        id object = [objects objectForKey:identifier];
        NSString *identifierKey = [[identifier stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString];
        
        // First, output any helper functions, ordered alphabetically
        NSArray *orderedKeys = [object keysSortedByValueUsingSelector:@selector(caseInsensitiveCompare:)];
        for (NSString *key in orderedKeys)
        {
            id value = [object objectForKey:key];
            if ([key hasPrefix:@"__helper__"])
            {
                [_output appendString:value];
                [_output appendString:@"\n"];
            }
        }
        
        NSString *instanceName = [self instanceNameForObject:object :identifier];
        // Then, output the constructor
        NSString *custom_klass = [object objectForKey:@"custom-class"];
        NSString *klass = [object objectForKey:@"class"];
        NSString *constructor = [object objectForKey:@"constructor"];
        
        //        if ([self hasOutletName:ID]) {
        
        if ([custom_klass length] > 0) {
            constructor = [constructor stringByReplacingOccurrencesOfString:klass withString:custom_klass];
            [_output appendFormat:@"  %@ *%@ = %@;\n",custom_klass, instanceName, constructor];
        }else{
            [_output appendFormat:@"  %@ *%@ = %@;\n",klass, instanceName, constructor];
        }
        
        
        // Then, output the properties only, ordered alphabetically
        orderedKeys = [[object allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
        for (NSString *key in orderedKeys)
        {
            id value = [object objectForKey:key];
            if (![key hasPrefix:@"__method__"]
                && ![key isEqualToString:@"constructor"] && ![key isEqualToString:@"class"]
                && ![key hasPrefix:@"__helper__"])
            {
                switch (self.codeStyle)
                {
                    case NibProcessorCodeStyleProperties:
                        [_output appendFormat:@"  %@.%@ = %@;\n", instanceName, key, value];
                        break;
                        
                    case NibProcessorCodeStyleSetter:
                        
                        [_output appendFormat:@"  [%@ set%@:%@];\n", instanceName, key, value];
                        break;
                        
                    default:
                        break;
                }
            }
        }
        
        //添加event outlet
        for (NSDictionary *key in _dicObjectsConnects)
        {
            id object = [_dicObjectsConnects objectForKey:key];
            NSString *des_id = [object objectForKey:@"source-id"];
            NSString *des_type = [object objectForKey:@"type"];
            if ([des_id length] > 0 && [des_id isEqualToString:identifier] && [des_type isEqualToString:@"IBCocoaTouchEventConnection"]) {
                
                if ([[[object objectForKey:@"source-label"] lowercaseString]rangeOfString:@"button"].location != NSNotFound) {
                    //                    [btnDeleteRecord addTarget:self action:@selector(onDeleteRecord:) forControlEvents:UIControlEventTouchUpInside];
                    NSString *selector = [object objectForKey:@"label"];
                    for (id key_obj in object)
                    {
                        if ([[object objectForKey:key_obj] isEqualToString:@"event-type"]) {
                            NSString *event = [NSString stringWithFormat:@"UIControlEvent%@", [key_obj stringByReplacingOccurrencesOfString:@" " withString:@""]];
                            [_output appendFormat:@"  [%@ addTarget:self action:@selector(%@) forControlEvents:%@];\n", instanceName, selector, event];
                        }
                    }
                    
                }
            }
        }
    if ([self hasOutletName:identifier]) {
//        [instanceName appendString:[self getElementNameFromOutlet:ID]];
        [_output appendFormat:@"  %@ = %@;\n",[self getElementNameFromOutlet:identifier], instanceName];

    }
        
        
        // Finally, output the method calls, ordered alphabetically
        orderedKeys = [object keysSortedByValueUsingSelector:@selector(caseInsensitiveCompare:)];
        for (NSString *key in orderedKeys)
        {
            id value = [object objectForKey:key];
            if ([key hasPrefix:@"__method__"])
            {
                [_output appendFormat:@"  [%@%@ %@];\n", instanceName, identifierKey, value];
            }
        }
        [_output appendString:@"\n"];
    }
    
    // Now that the objects are created, recreate the hierarchy of the NIB
    NSArray *nibHierarchy = [_dictionary objectForKey:@"com.apple.ibtool.document.hierarchy"];
    for (NSDictionary *item in nibHierarchy)
    {
        //        int currentView = [[item objectForKey:@"object-id"] intValue];
        [self parseChildren:item withObjects:objects];
    }
    [_output appendString:@"}\n"];

    
    [objects release];
    objects = nil;
}

- (void)parseChildren:(NSDictionary *)dict withObjects:(NSDictionary *)objects
{
    NSArray *children = [dict objectForKey:@"children"];
    if (children != nil)
    {
        for (NSDictionary *subitem in children)
        {
            NSString *subviewID = [subitem objectForKey:@"object-id"];
            NSString *superViewID = [dict objectForKey:@"object-id"];
            
            id currentViewObject = [objects objectForKey:superViewID];
            NSString *instanceName = [self instanceNameForObject:currentViewObject :superViewID];
            
            id subViewObject = [objects objectForKey:[NSString stringWithFormat:@"%@", subviewID]];
            NSString *subInstanceName = [self instanceNameForObject:subViewObject :subviewID];
            
            [self parseChildren:subitem withObjects:objects];
            
            [_output appendFormat:@"  [%@ addSubview:%@];\n", instanceName, subInstanceName];
        }
    }
}

- (NSString *)instanceNameForObject:(id)obj :(NSString *)ID
{
    NSMutableString *instanceName = [[NSMutableString alloc]init];
//    if ([self hasOutletName:ID]) {
//        [instanceName appendString:[self getElementNameFromOutlet:ID]];
//        return instanceName;
//    }else{
        NSString *custom_kclass = [obj objectForKey:@"custom-class"];
        if ([custom_kclass length] > 0) {
            [instanceName appendString:custom_kclass];
        }else{
            id klass = [obj objectForKey:@"class"];
            [instanceName appendString:[klass substringFromIndex:2]];
        }
        
        [instanceName appendString:[[ID stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString]];
        
        return instanceName;
//    }
}

- (BOOL)hasOutletName:(NSString *)ID
{
    //    if([arrOutLetName count] > 0){
    //        for (NSString *str_outlet in arrOutLetName) {
    //            if ([str_outlet rangeOfString:ID].location != NSNotFound) {
    //                return YES;
    //            }
    //        }
    //    }
    
    if ([_dicObjectsConnects count ] > 0) {
        
        for (NSDictionary *key in _dicObjectsConnects)
        {
            id object = [_dicObjectsConnects objectForKey:key];
            NSString *des_id = [object objectForKey:@"destination-id"];
            NSString *des_type = [object objectForKey:@"type"];
            if ([des_id length] > 0 && [des_id isEqualToString:ID] && [des_type isEqualToString:@"IBCocoaTouchOutletConnection"]) {
                return YES;
            }
        }
    }
    return NO;
}

- (NSString *)getElementNameFromOutlet:(NSString *)ID
{
    if ([self hasOutletName:ID]) {
        //        for (NSString *str_outlet in arrOutLetName) {
        //            if ([str_outlet rangeOfString:ID].location != NSNotFound) {
        //                NSArray *values = [str_outlet componentsSeparatedByString:@" "];
        //
        //                if ([values count] > 0) {
        //                    for(NSString *value in values)
        //                    {
        //                        if ([value hasPrefix:@"property"]) {
        //                            NSArray *values2 = [value componentsSeparatedByString:@"="];
        //
        //                            if ([values2 count] > 0) {
        //                                NSString *valueWithM = values2[1];
        //                                return [valueWithM stringByReplacingOccurrencesOfString:@"\"" withString:@""];
        //                            }
        //                        }
        //                    }
        //                }
        //            }
        //        }
        
        for (NSDictionary *key in _dicObjectsConnects)
        {
            id object = [_dicObjectsConnects objectForKey:key];
            NSString *des_id = [object objectForKey:@"destination-id"];
            NSString *des_type = [object objectForKey:@"type"];
            if ([des_id length] > 0 && [des_id isEqualToString:ID] && [des_type isEqualToString:@"IBCocoaTouchOutletConnection"]) {
                
                return [NSString stringWithFormat:@"_%@",[object objectForKey:@"label"]];
            }
        }
        
    }
    return @"error";
}

@end

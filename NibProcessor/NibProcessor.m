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
    NSArray *_arrImagesLine;
    
    NSDictionary *_dicObjectsConnects;
    
    NSMutableArray *_arrBtnsWithState;
    
    NSMutableDictionary *_dicBtnWithStateProperty;
    
    BOOL _bBtnBegin;
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
    
    [self getImgaesFromNIB];

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

- (void)getImgaesFromNIB
{
    //    echo "$(grep .png ./ddd.txt)" > ddd.txt

    NSArray *arguments = [NSArray arrayWithObjects: @".png",
                          _filename, nil];
    NSTask *task = [[NSTask alloc] init];
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *readHandle = [pipe fileHandleForReading];
    NSData *temp = nil;

    NSMutableData *tempData = [[NSMutableData alloc]init];

    [task setLaunchPath:@"/usr/bin/grep"];
    [task setArguments:arguments];
    [task setStandardOutput:pipe];
    [task launch];

    while ((temp = [readHandle availableData]) && [temp length])
    {
        [tempData appendData:temp];
    }
    NSString *strOutLetResult = [[NSString alloc] initWithData:tempData encoding:NSASCIIStringEncoding];
    _arrImagesLine =  [strOutLetResult componentsSeparatedByString:@"\n"];
    
    //输出未处理的state,比如 button的state
    if ([_arrImagesLine count] > 0) {
        for(NSString *imageLine in _arrImagesLine)
        {
            if ([imageLine rangeOfString:@"<state "].location != NSNotFound) {
//                NSLog(@"state not peocess :%@\n",imageLine);
                
                [self praseXml];
            }
        }
    }
    [task release];

}

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
    //    NSArray *_dicObjectsHierarchy = [_dictionary objectForKey:@"com.apple.ibtool.document.hierarchy"];
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
    [_output appendString:@"#pragma --mark replace xib with code \n"];
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
        
        if ([custom_klass length] > 0) {
            constructor = [constructor stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"[[%@",klass] withString:[NSString stringWithFormat:@"[[%@",custom_klass]];
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
                && ![key isEqualToString:@"constructor"]
                && ![key isEqualToString:@"class"]
                && ![key isEqualToString:@"custom-class"]
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
        
        //处理state，例如Button的
        if([_arrBtnsWithState count] > 0){
            for(NSDictionary *dic in _arrBtnsWithState){
                NSDictionary *dicValue = [dic valueForKey:@"button"];
                if ([[dicValue valueForKey:@"id"] isEqualToString:identifier]) {
                    NSDictionary *stateValue = [dic valueForKey:@"state"];
                    NSString *stateName = [stateValue valueForKey:@"key"];
                    
                    NSString *stateNameFirstCharaxterRight = [stateName substringFromIndex:1];
                    NSString *stateNameFirstCharaxterLeft = [[stateName substringToIndex:1] uppercaseString];
                    
                    NSString *imageName = [stateValue valueForKey:@"image"];
                    if ([imageName length] > 0){
                        // [butt setImage: [UIImage imageNamed:@"selectedImage.png"] forState:UIControlStateNormal];
                        //        UIControlStateNormal       = 0,         常规状态显现
                        //        UIControlStateHighlighted  = 1 << 0,    高亮状态显现
                        //        UIControlStateDisabled     = 1 << 1,    禁用的状态才会显现
                        //        UIControlStateSelected     = 1 << 2,    选中状态
                        imageName = [imageName stringByReplacingOccurrencesOfString:@"@2x" withString:@""];
                        imageName = [imageName stringByReplacingOccurrencesOfString:@".png" withString:@""];
                        [_output appendFormat:@"  [%@ setImage: [UIImage imageNamed:@\"%@\"] forState:UIControlState%@%@];\n", instanceName, imageName,stateNameFirstCharaxterLeft,stateNameFirstCharaxterRight];
                    }
                    
                    NSString *titleText = [stateValue valueForKey:@"title"];
                    if ([titleText length] > 0) {
                       [_output appendFormat:@"  [%@ setTitle:@\"%@\" forState:UIControlState%@%@];\n", instanceName, titleText,stateNameFirstCharaxterLeft,stateNameFirstCharaxterRight];
                    }
                }
            }
        }
        
        //处理Xib中的图片,UIImageView
        if ([_arrImagesLine count] > 0) {
            for(NSString *imageLine in _arrImagesLine)
            {
                if ([imageLine rangeOfString:@"<imageView "].location != NSNotFound) {
                    NSRange range = [imageLine rangeOfString:@"<imageView "];
                    imageLine = [imageLine substringFromIndex:range.location];//去除前面空格；
//
                    imageLine = [imageLine stringByReplacingOccurrencesOfString:@"<imageView " withString:@"{\""];
                    imageLine = [imageLine stringByReplacingOccurrencesOfString:@">" withString:@"}"];
                    imageLine = [imageLine stringByReplacingOccurrencesOfString:@" " withString:@",\""];
                     imageLine = [imageLine stringByReplacingOccurrencesOfString:@"=" withString:@"\":"];
//                    imageLine = [imageLine stringByReplacingOccurrencesOfString:@"<imageView," withString:@"\"imageView\" = {"];
                    NSData *dataStr = [imageLine dataUsingEncoding:NSUTF8StringEncoding];
                    NSDictionary *dicImageView = [NSJSONSerialization JSONObjectWithData:dataStr options:NSJSONReadingAllowFragments error:nil];
                    
                    if (dicImageView != Nil && [[dicImageView valueForKey:@"id"] isEqualToString:identifier]) {
                        
                        for(NSString *dicKey in dicImageView)
                        {
                            NSString *imageName = [dicImageView valueForKey:dicKey];

                            if ([imageName length] > 0 && [imageName rangeOfString:@".png"].location != NSNotFound) {
                                imageName = [imageName stringByReplacingOccurrencesOfString:@"@2x" withString:@""];
                                imageName = [imageName stringByReplacingOccurrencesOfString:@".png" withString:@""];
                                NSString *uiImage = [NSString stringWithFormat:@"[UIImage imageNamed:@\"%@\"]",imageName];
                                switch (self.codeStyle)
                                {
                                    case NibProcessorCodeStyleProperties:
//                                        [UIImage imageNamed:@"a.png"];
                                        
                                        [_output appendFormat:@"  %@.%@ = %@;\n", instanceName, dicKey, uiImage];
                                        break;
                                        
                                    case NibProcessorCodeStyleSetter:
                                        
//                                        [_output appendFormat:@"  [%@ set%@:%@];\n", instanceName, key, value];
                                     [_output appendFormat:@"  %@.%@ = %@;\n", instanceName, dicKey, uiImage];
                                        break;
                                        
                                    default:
                                        break;
                                }
                            }
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
                
                return [NSString stringWithFormat:@"self.%@",[object objectForKey:@"label"]];
            }
        }
        
    }
    return @"error";
}


#pragma --mark process xml for button state
- (void)praseXml
{
    NSData *data = [NSData dataWithContentsOfFile:_filename];
    
    NSXMLParser *parser=[[NSXMLParser alloc] initWithData:data];
    
    [parser setDelegate:self];//设置NSXMLParser对象的解析方法代理
    [parser setShouldProcessNamespaces:NO];
    [parser parse];//开始解析
}

#pragma --mark NSXMLParserDelegate
//发现元素开始符的处理函数  （即报告元素的开始以及元素的属性）
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
    attributes:(NSDictionary *)attributeDict
{
//    NSLog(@"didStartElement---%@:%@",elementName,attributeDict);
    
    
    
    if ([elementName isEqualToString:@"button"]) {
        _bBtnBegin = YES;

    }
    if (_bBtnBegin == YES) {
        if (_dicBtnWithStateProperty == nil) {
            _dicBtnWithStateProperty = [[NSMutableDictionary alloc]init];
        }
        
        if (_arrBtnsWithState == nil) {
            _arrBtnsWithState = [[NSMutableArray alloc]init];
        }
        [_dicBtnWithStateProperty setObject:attributeDict forKey:elementName];
    }
}


//处理标签包含内容字符 （报告元素的所有或部分内容）
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    
}

//发现元素结束符的处理函数，保存元素各项目数据（即报告元素的结束标记）
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
//    NSLog(@"didEndElement---%@:%@",elementName,qName);
    if ([elementName isEqualToString:@"button"]) {
        _bBtnBegin = NO;
        
        for(NSString *key in _dicBtnWithStateProperty)
        {
            if ([key isEqualToString:@"state"]) {
                NSDictionary *dic = [_dicBtnWithStateProperty copy];
                [_arrBtnsWithState addObject:dic];
            }
        }
        _dicBtnWithStateProperty = nil;
    }
}

//报告解析的结束
- (void)parserDidEndDocument:(NSXMLParser *)parser
{

}

//报告不可恢复的解析错误
- (void)paser:parserErrorOccured
{

}

@end

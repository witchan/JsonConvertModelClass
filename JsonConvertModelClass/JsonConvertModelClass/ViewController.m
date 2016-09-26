//
//  ViewController.m
//  JsonConvertModelClass
//
//  Created by MWeit on 16/8/26.
//  Copyright © 2016年 Wit. All rights reserved.
//

#import "ViewController.h"

#import <objc/runtime.h>

#import "ViewController.h"

@interface ViewController ()
@property (strong, nonatomic) NSArray   *systemKeywords;

@property (weak) IBOutlet NSTextField   *rootClassNameTextField;
@property (weak) IBOutlet NSTextField *classPrefixTextField;
@property (weak) IBOutlet NSTextField *baseClassNameTextField;

@property (weak) IBOutlet NSButton      *generateButton;

@property (unsafe_unretained) IBOutlet  NSTextView *textView;

/**
 *  生成按钮的点击事件
 */
- (IBAction)generateButtonOnClicked:(NSButton *)sender;

/**
 *  生成Class文件
 *
 *  @param className 类名
 *  @param obj       生成属性所需要的数据
 */
- (void)generateClassWithClassName:(NSString *)className data:(id)obj;

@end

@implementation ViewController


#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    
}


#pragma mark - IBActions

- (IBAction)generateButtonOnClicked:(NSButton *)sender {
 
    if ([self.rootClassNameTextField.stringValue isEqualToString:@""]) {
        self.rootClassNameTextField.stringValue = @"RootClass";
    }
    
    if ([self.classPrefixTextField.stringValue isEqualToString:@""]) {
        self.classPrefixTextField.stringValue = @"WW";
    }
    
    if ([self.baseClassNameTextField.stringValue isEqualToString:@""]) {
        self.baseClassNameTextField.stringValue = @"NSObject";
    }
    
    NSError *error;
    
    // 将json文字转换成字典
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"[a-zA-z]+://[^\\s]*"];
    NSData *data;
    if ([predicate evaluateWithObject:self.textView.string]) {
        NSURL *url = [NSURL URLWithString:self.textView.string];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored"-Wdeprecated-declarations"
            data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
        #pragma clang diagnostic pop
    } else {
        data = [self.textView.string dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    if (data == nil || [NSJSONSerialization isValidJSONObject:data]) {
        self.textView.string = @"json format error";
        return;
    }
    
    NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    
    if (jsonDictionary == nil || error) {
        self.textView.string = @"json format error";
        return;
    }
    
    // 生成class文件
    NSString *className =  [NSString stringWithFormat:@"%@%@",
                            self.classPrefixTextField.stringValue,
                            self.rootClassNameTextField.stringValue];
    [self generateClassWithClassName:className data:jsonDictionary];
    [self inportModelFile];
    
    self.textView.string = @"转换成功！文件已保存到桌面的Models文件夹中.";
}


#pragma mark - Private

- (void)generateClassWithClassName:(NSString *)className data:(id)obj {
    
    // 获取.h文件框架
    NSString *hFilePath = [[NSBundle mainBundle] pathForResource:@"HFile" ofType:@"wit"];
    NSMutableString *hFile = [NSMutableString stringWithContentsOfFile:hFilePath  encoding:NSUTF8StringEncoding error:nil];
    
    // 获取.m文件框架
    NSString *mFilePath = [[NSBundle mainBundle] pathForResource:@"MFile" ofType:@"wit"];
    NSMutableString *mFile = [NSMutableString stringWithContentsOfFile:mFilePath encoding:NSUTF8StringEncoding error:nil];
    
    // 设置属性
    NSMutableString *properties = [NSMutableString string];
    
    NSString *property;
    
    if ([obj isKindOfClass:[NSArray class]]) {
        
        NSString *name = [NSString stringWithFormat:@"%@_%@",self.classPrefixTextField.stringValue , [className capitalizedString]];
        [self generateClassWithClassName:className data:[obj firstObject]];
        [self importHaderFileToClassWithHFile:hFile inportString:[name stringByAppendingString:@".h"]];
        property = [NSString stringWithFormat:@"@property (strong, nonatomic) NSArray *arr_%@;\n", name];
        
        [properties appendString:property];
    }
    
    if ([obj isKindOfClass:[NSDictionary class]]) {
        for (NSString *key in [obj allKeys]) {
            id value = obj[key];
            
            if ([value isKindOfClass:[NSString class]]) {
                
                property = [NSString stringWithFormat:@"@property (copy, nonatomic) NSString *str_%@;\n", key];
            } else if ([value isKindOfClass:[NSArray class]]) {
                
                NSString *name = [NSString stringWithFormat:@"%@_%@",className , [key capitalizedString]];
                [self generateClassWithClassName:name data:[value firstObject]];
                [self importHaderFileToClassWithHFile:hFile inportString:[name stringByAppendingString:@".h"]];
                
                property = [NSString stringWithFormat:@"@property (strong, nonatomic) NSArray *arr_%@;\n", key];
            } else if ([value isKindOfClass:[NSDictionary class]]) {
                NSString *name = [NSString stringWithFormat:@"%@_%@",className , [key capitalizedString]];
                
                [self generateClassWithClassName:name data:value];
                [self importHaderFileToClassWithHFile:hFile inportString:[name stringByAppendingString:@".h"]];
                property = [NSString stringWithFormat:@"@property (strong, nonatomic) %@ *%@;\n", name, key];
            } else if ([[value className] isEqualToString:@"__NSCFBoolean"]) {
                property = [NSString stringWithFormat:@"@property (assign, nonatomic, getter=is%@) BOOL b_%@;\n", [[key copy] capitalizedString], key];
            } else if ([[value className] isEqualToString:@"__NSCFNumber"]) {
                property = [NSString stringWithFormat:@"@property (copy, nonatomic) NSNumber *n_%@;\n", key];
            } else {
                property = [NSString stringWithFormat:@"@property (strong, nonatomic) id id_%@;\n", key];
            }
            
            [properties appendString:property];
        }
    }
    
    NSString *baseClass = self.baseClassNameTextField.stringValue? : @"NSObject";
    
    [hFile replaceOccurrencesOfString:@"#ClassName#" withString:className options:0 range:NSMakeRange(0, hFile.length)];
    [hFile replaceOccurrencesOfString:@"#property#" withString:properties options:0 range:NSMakeRange(0, hFile.length)];
    [hFile replaceOccurrencesOfString:@"#BaseClass#" withString:baseClass options:0 range:NSMakeRange(0, hFile.length)];
    if ([baseClass isEqualToString:@"NSObject"]) {
        [hFile replaceOccurrencesOfString:@"\n#import \"NSObject.h\"" withString:@"" options:0 range:NSMakeRange(0, hFile.length)];
    }
    
    [mFile replaceOccurrencesOfString:@"#ClassName#" withString:className options:0 range:NSMakeRange(0, mFile.length)];
    [mFile replaceOccurrencesOfString:@"#BaseClass#" withString:baseClass options:0 range:NSMakeRange(0, mFile.length)];
    
    NSString *savePath = [[NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"Models/"];
    NSString *hSavePath = [NSString stringWithFormat:@"%@/%@.h", savePath, className];
    NSString *mSavePath = [NSString stringWithFormat:@"%@/%@.m", savePath, className];
    
    
    [[NSFileManager defaultManager] createDirectoryAtPath:savePath withIntermediateDirectories:NO attributes:nil error:nil];

    [hFile writeToFile:hSavePath atomically:NO encoding:NSUTF8StringEncoding error:nil];
    [mFile writeToFile:mSavePath atomically:NO encoding:NSUTF8StringEncoding error:nil];
}

- (void)importHaderFileToClassWithHFile:(NSMutableString *)hFile inportString:(NSString *)text {
    NSString *importString = [NSString stringWithFormat:@"#import \"%@\"\n", text];
    
    [hFile insertString:importString atIndex:87];
}

- (void)inportModelFile {
    NSString *HWWModelPath  = [[NSBundle mainBundle] pathForResource:@"HWWModel" ofType:@"wit"];
    NSString *MWWModelPath  = [[NSBundle mainBundle] pathForResource:@"MWWModel" ofType:@"wit"];
    
    NSString *HWWModel = [NSString stringWithContentsOfFile:HWWModelPath encoding:NSUTF8StringEncoding error:nil];
    NSString *MWWModel = [NSString stringWithContentsOfFile:MWWModelPath encoding:NSUTF8StringEncoding error:nil];
    
    NSString *savePath = [[NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"Models/"];
    NSString *hSavePath = [NSString stringWithFormat:@"%@/NSObject+WWModel.h", savePath];
    NSString *mSavePath = [NSString stringWithFormat:@"%@/NSObject+WWModel.m", savePath];

    [HWWModel writeToFile:hSavePath atomically:NO encoding:NSUTF8StringEncoding error:nil];
    [MWWModel writeToFile:mSavePath atomically:NO encoding:NSUTF8StringEncoding error:nil];
}

@end


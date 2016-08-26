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
@property (weak) IBOutlet NSButton      *generateButton;
@property (weak) IBOutlet NSTextField   *classNameTextField;
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
    
    NSString *className = [self.classNameTextField.stringValue capitalizedString];
    
    NSError *error;
//    
//    self.textView.string = [self.textView.string stringByReplacingOccurrencesOfString:@"\\t" withString:@""];
//    self.textView.string = [self.textView.string stringByReplacingOccurrencesOfString:@"\\r" withString:@""];
//    self.textView.string = [self.textView.string stringByReplacingOccurrencesOfString:@"，" withString:@","];
//    self.textView.string = [self.textView.string stringByReplacingOccurrencesOfString:@"：" withString:@":"];

//
    
//    /Users/MWeit/Documents/JsonConvertModelClass/JsonConvertModelClass/JsonConvertModelClass/ViewController.m:72:33: 'sendSynchronousRequest:returningResponse:error:' is deprecated: first deprecated in OS X 10.11 - Use [NSURLSession dataTaskWithRequest:completionHandler:] (see NSURLSession.h
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
        self.textView.string = @"json格式不正确";
        return;
    }
    
    NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    
    if (jsonDictionary == nil || error) {
        self.textView.string = @"json格式不正确";
        return;
    }
    
    // 生成class文件
    [self generateClassWithClassName:className data:jsonDictionary];
    
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
    
    [hFile replaceOccurrencesOfString:@"@ClassName@" withString:className options:0 range:NSMakeRange(0, hFile.length)];
    
    // 设置属性
    NSMutableString *properties = [NSMutableString string];
    
    NSString *property;
    
    if ([obj isKindOfClass:[NSArray class]]) {
        NSString *name = [NSString stringWithFormat:@"%@DetailModel", [className capitalizedString]];
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
                
                NSString *name = [NSString stringWithFormat:@"%@Model", [key capitalizedString]];
                [self generateClassWithClassName:name data:[value firstObject]];
                [self importHaderFileToClassWithHFile:hFile inportString:[name stringByAppendingString:@".h"]];
                
                property = [NSString stringWithFormat:@"@property (strong, nonatomic) NSArray *arr_%@;\n", key];
            } else if ([value isKindOfClass:[NSDictionary class]]) {
                NSString *name = [NSString stringWithFormat:@"%@Model", [key capitalizedString]];
                
                [self generateClassWithClassName:name data:value];
                [self importHaderFileToClassWithHFile:hFile inportString:[name stringByAppendingString:@".h"]];
                property = [NSString stringWithFormat:@"@property (strong, nonatomic) %@ *%@;\n", name, key];
            } else if ([[value className] isEqualToString:@"__NSCFBoolean"]) {
                property = [NSString stringWithFormat:@"@property (assign, nonatomic, getter=is%@) BOOL b_%@;\n", [[key copy] capitalizedString], key];
            } else if ([[value className] isEqualToString:@"__NSCFNumber"]) {
                property = [NSString stringWithFormat:@"@property (copy, nonatomic) NSNumber *n_%@;\n", key];
            } else {
                property = [NSString stringWithFormat:@"@property (strong, nonatomic) id %@;\n", key];
            }
            
            [properties appendString:property];
        }
    }
    
    [hFile replaceOccurrencesOfString:@"@property@" withString:properties options:0 range:NSMakeRange(0, hFile.length)];
    
    [mFile replaceOccurrencesOfString:@"@ClassName@" withString:className options:0 range:NSMakeRange(0, mFile.length)];
    
    NSString *savePath = [[NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"Models/"];
    NSString *hSavePath = [NSString stringWithFormat:@"%@/%@.h", savePath, className];
    NSString *mSavePath = [NSString stringWithFormat:@"%@/%@.m", savePath, className];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:savePath withIntermediateDirectories:NO attributes:nil error:nil];

    [hFile writeToFile:hSavePath atomically:NO encoding:NSUTF8StringEncoding error:nil];
    [mFile writeToFile:mSavePath atomically:NO encoding:NSUTF8StringEncoding error:nil];
}

- (void)importHaderFileToClassWithHFile:(NSMutableString *)hFile inportString:(NSString *)text {
    NSString *importString = [NSString stringWithFormat:@"#import \"%@\"\n", text];
    
    [hFile insertString:importString atIndex:35];
}

@end


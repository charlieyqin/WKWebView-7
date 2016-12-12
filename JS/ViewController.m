//
//  ViewController.m
//  JS
//
//  Created by 索晓晓 on 16/12/12.
//  Copyright © 2016年 SXiao.RR. All rights reserved.
//

#import "ViewController.h"
#import <WebKit/WebKit.h>

@protocol WKUserCustomDelegate <NSObject>

@required
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message;

@end

@interface WKUserCustom : NSObject <WKScriptMessageHandler>

@property (nonatomic , weak)id<WKUserCustomDelegate>delegate;

@end
@implementation WKUserCustom

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    if ([self.delegate respondsToSelector:@selector(userContentController:didReceiveScriptMessage:)]) {
        [self.delegate userContentController:userContentController didReceiveScriptMessage:message];
    }
}

@end



@interface ViewController ()
<WKUIDelegate,WKNavigationDelegate,WKUserCustomDelegate>
{
    WKWebView *webView ;
    WKWebViewConfiguration *config;
    
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    //创建配置文件
    config = [[WKWebViewConfiguration alloc] init];
    
    config.userContentController = [[WKUserContentController alloc] init];
    //// 注入JS对象名称AppModel，当JS通过AppModel来调用时，
    //// 我们可以在WKScriptMessageHandler代理中接收到
    //   当JS通过AppModel发送数据到iOS端时，会在代理中收到：
    //
    WKUserCustom *user =[[WKUserCustom alloc] init];
    user.delegate = self;
    //注:  这边使用 user作为代理的原因是:
    // 如果使用self作为代理带接受回调函数, 将不会释放 造成内存泄露
    // 这边使用代理来接受代理 来达到释放的问题
    [config.userContentController addScriptMessageHandler:user name:@"AppModel"];
    
    webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
    
    [self.view addSubview:webView];
    
    webView.UIDelegate = self;
    webView.navigationDelegate = self;
    
    NSString *path = [[[NSBundle mainBundle] bundlePath]  stringByAppendingPathComponent:@"jsoc.html"];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:path]];
    [webView loadRequest:request];
    
}

- (void)dealloc
{
    [config.userContentController removeScriptMessageHandlerForName:@"AppModel"];
    NSLog(@"dealloc");
}

#pragma mark - WKScriptMessageHandler  处理接受js调用通过注册的名称调用的方法接受
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    if ([message.name isEqualToString:@"AppModel"]) {
        // 打印所传过来的参数，只支持NSNumber, NSString, NSDate, NSArray, NSDictionary, and NSNull类型
        NSLog(@"%@", message.body);
    }
}

#pragma mark -WKUIDelegate
#pragma mark - alert
// 在JS端调用alert函数时，会触发此代理方法。
// JS端调用alert时所传的数据可以通过message拿到
// @param frmae 这个参数可以获取都当前webView加载的URL
// 在原生得到结果后，需要回调JS，是通过completionHandler回调
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler
{

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler();
    }]];
    
    [self presentViewController:alert animated:YES completion:NULL];
}
#pragma mark - confirm
// JS端调用confirm函数时，会触发此方法
// 通过message可以拿到JS端所传的数据
// 在iOS端显示原生alert得到YES/NO后
// 通过completionHandler回调给JS端
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL result))completionHandler
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"YES" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(YES);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"NO" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(NO);
    }]];

    [self presentViewController:alert animated:YES completion:NULL];
    
}
#pragma mark - TextInput
// JS端调用prompt函数时，会触发此方法
// 要求输入一段文本
// 在原生输入得到文本内容后，通过completionHandler回调给JS
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(nullable NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable result))completionHandler;
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:prompt preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        
    }];
    [[alert.textFields lastObject] setPlaceholder:defaultText];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(alert.textFields[0].text);
    }]];
    [self presentViewController:alert animated:YES completion:NULL];
}

#pragma mark - WKNavigationDelegate
#pragma mark - 决定是否跳转
//请求开始前，会先调用此代理方法
// 与UIWebView的
// - (BOOL)webView:(UIWebView *)webView
// shouldStartLoadWithRequest:(NSURLRequest *)request
// navigationType:(UIWebViewNavigationType)navigationType; 一样
// 类型，在请求先判断能不能跳转（请求）
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler{

    NSString *hostname = navigationAction.request.URL.host.lowercaseString;//域名
//    NSLog(@"%@",hostname);
    
    if (navigationAction.navigationType == WKNavigationTypeLinkActivated && ![hostname containsString:@"10.1.140.238"]) {
        
        // 告诉JS打不开
        // 这是js的调用方法string形式
        NSString *js = @"linkFailed()";
        [webView evaluateJavaScript:js completionHandler:^(id _Nullable response, NSError * _Nullable error) {
            //response   js方法的返回值
            NSLog(@"%@====%@",response,error);
        }];
        
        //对于跨域的应用内不允许打开
        if([[UIApplication sharedApplication] canOpenURL:navigationAction.request.URL]){
        
            [[UIApplication sharedApplication] openURL:navigationAction.request.URL options:@{} completionHandler:^(BOOL success) {
                NSLog(@"===%d",success);
            }];
        }else{
            
            
        }
        
        decisionHandler(WKNavigationActionPolicyCancel);
    }
    
    decisionHandler(WKNavigationActionPolicyAllow);
    
}

// 在响应完成时，会回调此方法
// 如果设置为不允许响应，web内容就不会传过来
// 在收到响应后，决定是否跳转
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler{
    decisionHandler(WKNavigationResponsePolicyAllow);
}

// 开始导航跳转时会回调
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    NSLog(@"%s %d", __FUNCTION__,__LINE__);
}

// 接收到重定向时会回调
- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    NSLog(@"%s", __FUNCTION__);
}

// 导航失败时会回调
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"%s %d", __FUNCTION__,__LINE__);
}

// 页面内容到达main frame时回调
- (void)webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation {
    NSLog(@"%s %d", __FUNCTION__,__LINE__);
}

// 导航完成时，会回调（也就是页面载入完成了）
- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    NSLog(@" %s %d" ,__FUNCTION__,__LINE__);
}

// 导航失败时会回调
- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    
}

// 对于HTTPS的都会触发此代理，如果不要求验证，传默认就行
// 如果需要证书验证，与使用AFN进行HTTPS证书验证是一样的
- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *__nullable credential))completionHandler {
    NSLog(@"%s", __FUNCTION__);
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

// 9.0才能使用，web内容处理中断时会触发
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    NSLog(@"%s", __FUNCTION__);
}



@end

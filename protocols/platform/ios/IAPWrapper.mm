/****************************************************************************
Copyright (c) 2014 cocos2d-x.org

http://www.cocos2d-x.org

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
****************************************************************************/

#import "IAPWrapper.h"
#include "PluginUtilsIOS.h"
#include "ProtocolIAP.h"
#import <StoreKit/StoreKit.h>
#import "ParseUtils.h"

using namespace cocos2d::plugin;

@implementation IAPWrapper

+ (void) onPayResult:(id) obj withRet:(IAPResult) ret withTransaction:(SKPaymentTransaction*)transaction withMsg:(NSString*) msg
{
    PluginProtocol* plugin = PluginUtilsIOS::getPluginPtr(obj);
    ProtocolIAP* iapPlugin = dynamic_cast<ProtocolIAP*>(plugin);
    ProtocolIAP::ProtocolIAPCallback callback = iapPlugin->getCallback();
    PayResultCode cRet = (PayResultCode) ret;
    
    if (iapPlugin) {
        NSDictionary *infoDict = [[[NSDictionary alloc]
                                   initWithObjectsAndKeys:@"payResult",@"type",
                                   transaction.payment.productIdentifier, @"sku",
                                   msg, @"msg",
                                   nil] autorelease];
        NSString *resultJson = [ParseUtils NSDictionaryToNSString:infoDict];
        
        if (resultJson == nil )
        {
            std::string errMsg = "Can not generate pay result";
            iapPlugin->onPayResult((PayResultCode)kPayFail, errMsg.c_str());

            if (callback)
                callback(kPayFail, errMsg);
            return;
        }
        
        std::string stdmsg([resultJson UTF8String]);
        iapPlugin->onPayResult(cRet, stdmsg.c_str());
        if (callback){
            callback(cRet, stdmsg);
        }
    }
    else {
        PluginUtilsIOS::outputLog("Can't find the C++ object of the IAP plugin");
    }
}
+ (NSString *) priceAsString:(SKProduct*) product
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [formatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [formatter setLocale:[product priceLocale]];
    
    NSString *str = [formatter stringFromNumber:[product price]];
    [formatter release];
    return str;
}

+(NSArray*) convertSKProductsToLocalizedProduct:(NSArray*) products
{
    NSMutableArray* convertedProducts = [[[NSMutableArray alloc] init] autorelease];
    for(SKProduct *product in products){
        NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:product.productIdentifier, @"productIdentifier", product.localizedTitle, @"localizedTitle", product.localizedDescription, @"localizedDescription", [self priceAsString: product], @"localizedPrice", nil];
        
        [convertedProducts addObject:info];
    }
    return convertedProducts;
}

+(NSString*) convertSKProductsToJSON:(NSArray*) products
{
    if (products) {
        return [ParseUtils NSDictionaryToNSString:[self convertSKProductsToLocalizedProduct:products]];
    }
    
    return @"[]";
}
                                  
+(void) onRequestProduct:(id)obj withRet:(ProductRequest) ret withProducts:(NSArray *)products{
    PluginProtocol* plugin = PluginUtilsIOS::getPluginPtr(obj);
    ProtocolIAP* iapPlugin = dynamic_cast<ProtocolIAP*>(plugin);
    PayResultListener *listener = iapPlugin->getResultListener();
    ProtocolIAP:: ProtocolIAPCallback callback = iapPlugin->getCallback();
    if (iapPlugin) {
        if(listener){
            TProductList pdlist;
            if (products) {
                for(SKProduct *product in products){
                    TProductInfo info;
                    info.insert(std::make_pair("productId", std::string([product.productIdentifier UTF8String])));
                    info.insert(std::make_pair("productName", std::string([product.localizedTitle UTF8String])));
                    info.insert(std::make_pair("productPrice", std::string([[product.price stringValue] UTF8String])));
                    info.insert(std::make_pair("productDesc", std::string([product.localizedDescription UTF8String])));
                    pdlist.push_back(info);
                }
            }
            listener->onRequestProductsResult((IAPProductRequest )ret,pdlist);
        }else if(callback){
            
            NSArray* convertedProducts = [self convertSKProductsToLocalizedProduct:products];
            NSDictionary *infoDict = [[[NSDictionary alloc]
                                         initWithObjectsAndKeys:@"productResult",@"type",
                                         convertedProducts,@"msg",
                                         nil] autorelease];
            
            NSString *productInfo = [ParseUtils NSDictionaryToNSString:infoDict];
            const char *charProductInfo;
            if (productInfo != nil){
                charProductInfo =[productInfo UTF8String];
                
                std::string stdstr(charProductInfo);
                callback((IAPProductRequest )ret, stdstr);
                
            }else{
                std::string retStr("Parse product info failed");
                callback((IAPProductRequest )IAPProductRequest::RequestFail, retStr);
            }
        }
    } else {
        PluginUtilsIOS::outputLog("Can't find the C++ object of the IAP plugin");
    }
}
@end

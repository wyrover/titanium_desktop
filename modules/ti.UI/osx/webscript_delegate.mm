/**
 * Appcelerator Titanium - licensed under the Apache Public License 2
 * see LICENSE in the root folder for details on the license.
 * Copyright (c) 2010 Appcelerator, Inc. All Rights Reserved.
 */

#import "webscript_delegate.h"

#import <kroll/kroll.h>
#import <kroll/javascript/javascript_module.h>

using namespace kroll;

@implementation WebScriptDelegate

- (bool)canEvaluateWithMimeType:(NSString *)mimeType
{
	printf("-----can evaluate script with type %s\n\n", [mimeType UTF8String]);
	return Script::GetInstance()->CanEvaluate([mimeType UTF8String]);
}

- (JSValueRef)evaluate:(NSString *)source withContext:(void *)context withMimeType:(NSString *)mimeType
{
	JSContextRef ctx = reinterpret_cast<JSContextRef>(context);
	KObjectRef scope = new KKJSObject(ctx, JSContextGetGlobalObject(ctx));
	KValueRef result = Script::GetInstance()->Evaluate(
		[mimeType UTF8String], "<script>", [source UTF8String], scope);

	return KJSUtil::ToJSValue(result, ctx);
}

@end

/**
 * Appcelerator Titanium - licensed under the Apache Public License 2
 * see LICENSE in the root folder for details on the license.
 * Copyright (c) 2010 Appcelerator, Inc. All Rights Reserved.
 */

#include "webkit_client.h"

#include <kroll/kroll.h>
#include <kroll/javascript/javascript_module.h>
#include <JavaScriptCore/JSContextRef.h>

using namespace kroll;

namespace ti {

bool WebKitClient::evaluateScript(void* context, const char* source, const char* mimetype)
{
	printf("Asked to evaluate code with type ... %s\n", mimetype);

	SharedPtr<Script> script = Script::GetInstance();

	if (!script->CanEvaluate(mimetype))
		return false;

	JSContextRef ctx = reinterpret_cast<JSContextRef>(context);
	KObjectRef scope = new KKJSObject(ctx, JSContextGetGlobalObject(ctx));
	script->Evaluate(mimetype, "<script>", source, scope);

	printf("Done evaluating!\n\n");

	return true;
}

}

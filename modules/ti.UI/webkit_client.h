/**
 * Appcelerator Titanium - licensed under the Apache Public License 2
 * see LICENSE in the root folder for details on the license.
 * Copyright (c) 2010 Appcelerator, Inc. All Rights Reserved.
 */

#ifndef _WEBKIT_CLIENT_H_
#define _WEBKIT_CLIENT_H_

#include <WebCore/TitaniumClient.h>

namespace ti {

class WebKitClient : public WebCore::TitaniumClient
{
public:
	WebKitClient() { }
	virtual ~WebKitClient() { }

	bool evaluateScript(void* context, const char* source, const char* mimetype);
};

}

#endif

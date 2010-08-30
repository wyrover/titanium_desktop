/**
 * Appcelerator Titanium - licensed under the Apache Public License 2
 * see LICENSE in the root folder for details on the license.
 * Copyright (c) 2009 Appcelerator, Inc. All Rights Reserved.
 */
#include "../ui_module.h"
namespace ti
{
	OSXMenuItem::OSXMenuItem(MenuItemType type) : MenuItem(type)
	{
	}

	OSXMenuItem::~OSXMenuItem()
	{
	}

	void OSXMenuItem::SetLabelImpl(std::string newLabel)
	{
		if (this->type == SEPARATOR)
			return;
		this->UpdateNativeMenuItems();
	}

	void OSXMenuItem::SetIconImpl(std::string newIconPath)
	{
		if (this->type == SEPARATOR || this->type == CHECK)
			return;
		this->UpdateNativeMenuItems();
	}

	void OSXMenuItem::SetStateImpl(bool newState)
	{
		if (this->type != CHECK)
			return;
		this->UpdateNativeMenuItems();
	}

	void OSXMenuItem::SetSubmenuImpl(AutoMenu newSubmenu)
	{
		if (this->type == SEPARATOR)
			return;
		this->UpdateNativeMenuItems();
	}

	void OSXMenuItem::SetEnabledImpl(bool enabled)
	{
		if (this->type == SEPARATOR)
			return;
		this->UpdateNativeMenuItems();
	}

	/*static*/
	void OSXMenuItem::SetNSMenuItemTitle(NSMenuItem* item, std::string& title)
	{
		NSString* nstitle = [NSString stringWithUTF8String:title.c_str()];
		[item setTitle:nstitle];

		NSMenu* submenu = [item submenu];
		if (submenu != nil)
		{
			// Need to set the new native menu's title as this item's label. Each
			// native menu will have to use the title of the item it is attached to.
			[submenu setTitle:nstitle];
		}
		if ([item menu] != nil)
		{
			[[item menu] sizeToFit];
		}
	}

	/*static*/
	void OSXMenuItem::SetNSMenuItemIconPath(
		NSMenuItem* item, std::string& iconPath, NSImage* image)
	{
		bool needsRelease = false;

		// If we weren't passed an image, create one for this call. This
		// allows callers to do one image creation in cases where the same
		// image is used over and over again.
		if (image == nil) {
			image = OSXUIBinding::MakeImage(iconPath);
			needsRelease = true;
		}

		if (!iconPath.empty()) {
			[item setImage:image];
		} else {
			[item setImage:nil];
		}

		if ([item menu] != nil) {
			[[item menu] sizeToFit];
		}

		if (needsRelease) {
			[image release];
		}
	}

	/*static*/
	void OSXMenuItem::SetNSMenuItemState(NSMenuItem* item, bool state)
	{
		[item setState:state ? NSOnState : NSOffState];
	}

	/*static*/
	void OSXMenuItem::SetNSMenuItemSubmenu(
		NSMenuItem* item, AutoMenu submenu, bool registerNative)
	{
		if (!submenu.isNull()) {
			AutoPtr<OSXMenu> osxSubmenu = submenu.cast<OSXMenu>();
			NSMenu* nativeMenu = osxSubmenu->CreateNativeLazily(registerNative);
			[nativeMenu setTitle:[item title]];
			[item setSubmenu:nativeMenu];

		} else {
			[item setSubmenu:nil];
		}
	}

	/*static*/
	void OSXMenuItem::SetNSMenuItemEnabled(NSMenuItem* item, bool enabled)
	{
		[item setEnabled:(enabled ? YES : NO)];
	}
	
	void OSXMenuItem::FillFromNativeItem(NSMenuItem *nativeItem)
	{
		NSMenuItem *itemCopy = [nativeItem copy];
		// Nothing to fill in for separators
		if (!this->IsSeparator()) {
			this->label = [[itemCopy title] UTF8String];
			this->state = [itemCopy state] != NSOffState;
			this->enabled = [itemCopy isEnabled] == YES;
			if ([itemCopy image]) {
				// TODO: find something to signify that there is an image... we can't get the original path from an NSImage
				// this->iconPath = ;
				// this->iconURL = ;
			}
			if ([itemCopy hasSubmenu]) {
				// The title for an item with a submenu is actually the submenu's title
				this->label = [[[itemCopy submenu] title] UTF8String];
				
				AutoPtr<OSXMenu> submenu = new OSXMenu();
				submenu->FillFromNativeMainMenu([itemCopy submenu]);
				this->submenu = submenu;
			}
		}
		this->nativeItems.push_back(itemCopy);
	}
	
	void OSXMenuItem::FillNativeMenuItem(NSMenuItem *item, bool registerNative)
	{
		SetNSMenuItemTitle(item, this->label);
		SetNSMenuItemIconPath(item, this->iconPath);
		SetNSMenuItemState(item, this->state);
		SetNSMenuItemEnabled(item, this->enabled);
		SetNSMenuItemSubmenu(item, this->submenu, registerNative);
	}

	NSMenuItem* OSXMenuItem::CreateNative(bool registerNative)
	{
		if (this->IsSeparator()) {
			return [NSMenuItem separatorItem];
		} else {
			NSMenuItem* item = [[NSMenuItem alloc] 
				initWithTitle:@"Temp" action:@selector(invoke:) keyEquivalent:@""];
			
			// Deal with the target here (instead of FillNativeMenuItem)
			// because we want to preserve the "First Responder" (nil) target on pre-built items
			if (![item target]) {
				OSXMenuItemDelegate* delegate = [[OSXMenuItemDelegate alloc] initWithMenuItem:this];
				[item setTarget:delegate];
			}

			this->FillNativeMenuItem(item, registerNative);

			if (registerNative)
			{
				this->nativeItems.push_back(item);
			}

			return item;
		}
	}
	
	// Return NSMenuItem associated with this menu item or create one
	NSMenuItem* OSXMenuItem::GetNative(bool registerNative)
	{
		NSMenuItem *nativeItem = nil;
		if (this->nativeItems.size() > 0) {
			nativeItem = this->nativeItems.back();
			nativeItem = [nativeItem copy];
			this->FillNativeMenuItem(nativeItem, registerNative);
			if (registerNative) {
				this->nativeItems.push_back(nativeItem);
			}
		} else {
			nativeItem = this->CreateNative(registerNative);
		}
		return nativeItem;
	}

	void OSXMenuItem::DestroyNative(NSMenuItem* realization)
	{
		std::vector<NSMenuItem*>::iterator i = this->nativeItems.begin();
		while (i != this->nativeItems.end())
		{
			NSMenuItem* item = *i;
			if (item == realization)
			{
				i = this->nativeItems.erase(i);
				if (!this->submenu.isNull() && [item submenu] != nil)
				{
					AutoPtr<OSXMenu> osxSubmenu = this->submenu.cast<OSXMenu>();
					osxSubmenu->DestroyNative([item submenu]);
				}
				[item release];
			}
			else
			{
				i++;
			}
		}
	}

	void OSXMenuItem::UpdateNativeMenuItems()
	{
		std::vector<NSMenuItem*>::iterator i = this->nativeItems.begin();
		while (i != this->nativeItems.end())
		{
			NSMenuItem* nativeItem = (*i++);
			if ([nativeItem menu]) {
				OSXMenu::UpdateNativeMenu([nativeItem menu]);
			}
		}

		// Must now iterate through the native menus and fix
		// the main menu -- it will modify this iterator so we
		// must do it in isolation.
		i = this->nativeItems.begin();
		while (i != this->nativeItems.end())
		{
			NSMenuItem* nativeItem = (*i++);
			if ([nativeItem menu] == [NSApp mainMenu]) {
				OSXUIBinding* binding =
					dynamic_cast<OSXUIBinding*>(UIBinding::GetInstance());
				binding->SetupMainMenu(true);
				break;
			}
		}
	}

	void OSXMenuItem::HandleClickEvent(KObjectRef source)
	{
		MenuItem::HandleClickEvent(source);
	}
}



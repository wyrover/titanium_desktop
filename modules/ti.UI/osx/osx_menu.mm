/**
 * Appcelerator Titanium - licensed under the Apache Public License 2
 * see LICENSE in the root folder for details on the license.
 * Copyright (c) 2009 Appcelerator, Inc. All Rights Reserved.
 */
#include <kroll/kroll.h>
#include "../ui_module.h" 

// The front offset accounts for the appplication and edit menus:w
// The rear offset accounts for the window and help menus
#define MAINMENU_FRONT_OFFSET 2
#define MAINMENU_REAR_OFFSET 2
namespace ti
{
	using std::vector;
	using std::string;

	OSXMenu::OSXMenu() :
		Menu()
	{
	}
	
	OSXMenu::OSXMenu(bool builtIn) :
		Menu(),
		builtIn(builtIn)
	{
	}

	OSXMenu::~OSXMenu()
	{
		std::vector<NSMenu*>::iterator i = this->nativeMenus.begin();
		while (i != this->nativeMenus.end()) {
			this->ClearNativeMenu((*i++));
		}
		nativeMenus.clear();
	}

	void OSXMenu::AppendItemImpl(AutoMenuItem item)
	{
		this->UpdateNativeMenus();
	}

	void OSXMenu::InsertItemAtImpl(AutoMenuItem item, unsigned int index)
	{
		this->UpdateNativeMenus();
	}

	void OSXMenu::RemoveItemAtImpl(unsigned int index)
	{
		this->UpdateNativeMenus();
	}

	void OSXMenu::ClearImpl()
	{
		this->Clear();
	}

	void OSXMenu::Clear()
	{
		this->UpdateNativeMenus();
	}
	
	bool OSXMenu::IsBuiltIn()
	{
		return this->builtIn;
	}

	/*static*/
	void OSXMenu::ClearNativeMenu(NSMenu* nativeMenu)
	{
		SEL getMenuItemSelector = @selector(getMenuItem:);

		while ([nativeMenu numberOfItems] > 0)
		{
			NSMenuItem* nativeItem = [nativeMenu itemAtIndex: 0];
			id delegate = [nativeItem target];

			// This delegate is one of our OSXMenuItem delegates, so grab its
			// OSXMenuItem reference and tell it to destroy this native menu item
			if (delegate && [delegate respondsToSelector:getMenuItemSelector]) {
				OSXMenuItem* menuItem = (OSXMenuItem*) [delegate performSelector:getMenuItemSelector];
				menuItem->DestroyNative(nativeItem);
			}
			[nativeMenu removeItemAtIndex:0];
		}
	}

	void OSXMenu::DestroyNative(NSMenu* nativeMenu)
	{
		// Remove the native menu from our list of known native menus
		std::vector<NSMenu*>::iterator i = this->nativeMenus.begin();
		while (i != this->nativeMenus.end()) {
			if (*i == nativeMenu) {
				i = this->nativeMenus.erase(i);
			} else {
				i++;
			}
		}

		// Clear the native menu and release it
		this->ClearNativeMenu(nativeMenu);
		[nativeMenu release];
	}

	void OSXMenu::UpdateNativeMenus()
	{
		std::vector<NSMenu*>::iterator i = this->nativeMenus.begin();
		while (i != this->nativeMenus.end()) {
			OSXMenu::UpdateNativeMenu(*i++);
		}

		// If this native menu is the application's current main menu,
		// we want to force the main menu to reload.
		OSXUIBinding* binding = dynamic_cast<OSXUIBinding*>(UIBinding::GetInstance());
		if (binding->GetActiveMenu().get() == this) {
			binding->SetupMainMenu(true);
		}
	}

	/*static*/
	void OSXMenu::UpdateNativeMenu(NSMenu* nativeMenu)
	{
		// If this is the application's main menu, just wait until
		// later to fix it -- it will modify the parent iterator.
		if (nativeMenu == [NSApp mainMenu]) {

		// Otherwise, just mark this menu as dirty and the next time OS X
		// shows it, it will trigger a redraw.
		} else {
			if ([nativeMenu delegate] && [[nativeMenu delegate] respondsToSelector:@selector(markAsDirty)]) {
				[[nativeMenu delegate] performSelector:@selector(markAsDirty)];
			}
		}
	}
	
	void OSXMenu::FillFromNativeMainMenu(NSMenu *nativeMainMenu)
	{
		NSMenu *menuCopy = [nativeMainMenu copy];
		for (int i = 0; i < [menuCopy numberOfItems]; i++)
		{
			NSMenuItem* nativeItem = [menuCopy itemAtIndex:i];
			AutoPtr<OSXMenuItem> item;
			if ([nativeItem isSeparatorItem]) {
				item = new OSXMenuItem(MenuItem::SEPARATOR);
			} else {
				// On OS X, all NSMenuItems are check-able
				item = new OSXMenuItem(MenuItem::CHECK);
			}
			// Fill in state
			item->FillFromNativeItem(nativeItem);
			this->children.push_back(item);
		}	
		this->nativeMenus.push_back(menuCopy);
	}

	NSMenu* OSXMenu::CreateNativeNow(bool registerNative)
	{
		return this->CreateNative(false, registerNative);
	}

	NSMenu* OSXMenu::CreateNativeLazily(bool registerNative)
	{
		return this->CreateNative(true, registerNative);
	}

	NSMenu* OSXMenu::CreateNative(bool lazy, bool registerNative)
	{
		// Not sure if we should be copying the last native menu on this->nativeMenus
		// and clearing it instead (along the lines of OSXMenuItem::GetNative)
		
		// This title should be set by the callee - see OSXMenuItem::NSMenuSetSubmenu
		NSMenu* menu = [[NSMenu alloc] initWithTitle:@"TopLevelMenu"];
		OSXMenuDelegate* delegate = [[OSXMenuDelegate alloc] 
			initWithMenu:this
			willRegister: registerNative ? YES : NO];
		
		// Add menu children lazily
		[delegate markAsDirty];
		[menu setDelegate:delegate];
		[menu setAutoenablesItems:NO];

		if (!lazy)
			this->AddChildrenToNativeMenu(menu, registerNative);

		if (registerNative)
		{
			this->nativeMenus.push_back(menu);
		}
		return menu;
	}

	void OSXMenu::FillNativeMainMenu(NSMenu* defaultMenu, NSMenu* nativeMainMenu)
	{
		// We are keeping a reference to this NSMenu*, so bump the reference
		// count. This method must be matched with a DestroyNative(...) call
		// to avoid a memory leak.
		[nativeMainMenu retain];
		
		[nativeMainMenu setTitle:[defaultMenu title]];
		[nativeMainMenu setAutoenablesItems:NO];
		this->AddChildrenToNativeMenu(nativeMainMenu, true);
		if (!OSXMenu::IsNativeMenuAMainMenu(nativeMainMenu)) {
			[nativeMainMenu insertItem:OSXMenu::CopyMenuItem([defaultMenu itemAtIndex:0])
				atIndex:0];
		}
		
		// We MUST end with a window menu and a help menu
		// This is cheap security; we can probably do better...
		// TODO: Might identify these better by setting the tag or represented object on them...?
		if ([nativeMainMenu numberOfItems] < 3) {
			// Copy the last two items from default menu in (window and help)
			[nativeMainMenu addItem:OSXMenu::CopyMenuItem([defaultMenu itemAtIndex:2])];
			[nativeMainMenu addItem:OSXMenu::CopyMenuItem([defaultMenu itemAtIndex:3])];
		}
		
		OSXMenu::SetupInspectorItem(nativeMainMenu);
		
		// The main menu needs all NSMenuItems in it to have submenus for 
		// proper display. So we just add empty submenus to those items missing them.
		OSXMenu::EnsureAllItemsHaveSubmenus(nativeMainMenu);

		this->nativeMenus.push_back(nativeMainMenu);
	}

	void OSXMenu::AddChildrenToNativeMenu(NSMenu* nativeMenu, bool registerNative, bool mainMenu)
	{
		vector<AutoMenuItem>::iterator i = this->children.begin();
		while (i != this->children.end()) {
			AutoMenuItem item = *i++;
			AutoPtr<OSXMenuItem> osxItem = item.cast<OSXMenuItem>();
			NSMenuItem* nativeItem = osxItem->GetNative(registerNative);

			int rearOffset = mainMenu ?  MAINMENU_REAR_OFFSET : 0;
			int index = [nativeMenu numberOfItems] - rearOffset;
			[nativeMenu insertItem:nativeItem atIndex:index];
		}
		[nativeMenu sizeToFit];
	}

	void OSXMenu::AddChildrenToNSArray(NSMutableArray* array)
	{
		vector<AutoMenuItem>::iterator i = this->children.begin();
		while (i != this->children.end())
		{
			AutoMenuItem item = *i++;
			AutoPtr<OSXMenuItem> osxItem = item.cast<OSXMenuItem>();
			NSMenuItem* nsItem = osxItem->CreateNative(false);
			[array addObject:nsItem];
			[nsItem release];
		}
	}

	/*static*/
	void OSXMenu::CopyMenu(NSMenu* from, NSMenu* to)
	{
		[to setTitle:[from title]];
		[to setAutoenablesItems:NO];
		for (int i = 0; i < [from numberOfItems]; i++)
		{
			NSMenuItem* duplicateItem = OSXMenu::CopyMenuItem([from itemAtIndex:i]);
			[to addItem:duplicateItem];
		}
	}

	/*static*/
	NSMenuItem* OSXMenu::CopyMenuItem(NSMenuItem* item)
	{
		if ([item isSeparatorItem])
		{
			return [NSMenuItem separatorItem];
		}
		else
		{
			NSMenuItem* duplicate = [[NSMenuItem alloc] 
				initWithTitle:[item title]
				action:[item action]
				keyEquivalent:[item keyEquivalent]];
			[duplicate setState:[item state]];
			[duplicate setTag:[item tag]];
			[duplicate setEnabled:[item isEnabled]];
			[duplicate setKeyEquivalentModifierMask:[item keyEquivalentModifierMask]];

			if ([item submenu] != nil)
			{
				NSMenu* newSubmenu = [[NSMenu alloc] init];
				OSXMenu::CopyMenu([item submenu], newSubmenu);
				[duplicate setSubmenu:newSubmenu];
				[newSubmenu release];
			}
			return duplicate;
		}

	}

	/*static*/
	bool OSXMenu::IsNativeMenuAMainMenu(NSMenu* menu)
	{
		// Getting the app name is hard.
		OSXUIBinding* binding = dynamic_cast<OSXUIBinding*>(UIBinding::GetInstance());
		NSString* appName = [NSString stringWithUTF8String:binding->GetHost()->GetApplication()->name.c_str()];
		
		return ([menu numberOfItems] > 0 &&
			([[[[menu itemAtIndex:0] submenu] title] isEqualToString:@"Apple"]
			 || [[[[menu itemAtIndex:0] submenu] title] isEqualToString:@"APPNAME"]
			 || [[[[menu itemAtIndex:0] submenu] title] isEqualToString:appName]));
	}

	/*static*/
	NSMenu* OSXMenu::GetWindowMenu(NSMenu* menu)
	{
		if (IsNativeMenuAMainMenu(menu))
		{
			return [[menu itemAtIndex:([menu numberOfItems] - 2)] submenu];
		}
		else
		{
			return nil;
		}
	}

	/*static*/
	NSMenu* OSXMenu::GetAppleMenu(NSMenu* menu)
	{
		if (IsNativeMenuAMainMenu(menu))
		{
			return [[menu itemAtIndex:0] submenu];
		}
		else
		{
			return nil;
		}
	}

	/*static*/
	NSMenu* OSXMenu::GetServicesMenu(NSMenu* menu)
	{
		if (!IsNativeMenuAMainMenu(menu))
		{
			return nil;
		}

		NSMenu* submenu = [[menu itemAtIndex:0] submenu];
		if (submenu == nil)
		{
			return nil;
		}

		for (int i = 0; i < [submenu numberOfItems]; i++)
		{
			NSMenuItem* item = [submenu itemAtIndex:i];
			if ([[item title] isEqualToString:@"Services"])
			{
				return [item submenu];
			}
		}
		return nil;
	}

	/*static*/
	void OSXMenu::EnsureAllItemsHaveSubmenus(NSMenu* menu)
	{
		for (int i = 0; i < [menu numberOfItems]; i++)
		{
			NSMenuItem* item = [menu itemAtIndex:i];
			if ([item submenu] == nil)
			{
				NSMenu* sm = [[NSMenu alloc] initWithTitle:[item title]];
				[item setSubmenu:sm];
				[sm release];
			}
		}
	}

	/*static*/
	void OSXMenu::FixWindowMenu(NSMenu* menu)
	{
		NSMenu* windowMenu = OSXMenu::GetWindowMenu(menu);
		if (windowMenu == nil)
		{
			return;
		}

		int lastSeparator = -1;
		for (int i = 0; i < [windowMenu numberOfItems]; i++)
		{
			if ([[windowMenu itemAtIndex:i] isSeparatorItem])
			{
				lastSeparator = i;
			}
		}

		if (lastSeparator == -1)
		{
			return;
		}

		while ([windowMenu numberOfItems] > lastSeparator+1)
		{
			[windowMenu removeItemAtIndex:lastSeparator+1];
		}
	}

	/*static*/
	void OSXMenu::SetupInspectorItem(NSMenu* menu)
	{
		NSMenu* windowMenu = OSXMenu::GetWindowMenu(menu);
		NSMenuItem* showInspector = [windowMenu
			itemWithTitle:NSLocalizedString(@"Show Inspector", @"")];
		NSMenuItem* showInspectorSeparator = [windowMenu
			itemWithTitle:NSLocalizedString(@"Show Inspector Separator", @"")];

		if (!Host::GetInstance()->DebugModeEnabled())
		{
			if (showInspector != nil)
				[windowMenu removeItem:showInspector];
			if (showInspectorSeparator != nil)
				[windowMenu removeItem:showInspectorSeparator];
		}
	}

	/*static*/
	void OSXMenu::ReplaceAppNameStandinInMenu(NSMenu* menu, NSString* appName)
	{
		static NSString* appNameStandin = @"APPNAME";

		for (int i = 0; i < [menu numberOfItems]; i++)
		{
			NSMenuItem* item = [menu itemAtIndex:i];
			NSString* title = [item title];
			if ([title rangeOfString:appNameStandin].location != NSNotFound)
			{
				title = [title stringByReplacingOccurrencesOfString:appNameStandin
					withString:appName];
				[item setTitle:title];
			}

			if ([item submenu])
			{
				title = [[item submenu] title];
				if ([title rangeOfString:appNameStandin].location != NSNotFound)
				{
					title = [title stringByReplacingOccurrencesOfString:appNameStandin
						withString:appName];
					[[item submenu] setTitle:title];
				}
				ReplaceAppNameStandinInMenu([item submenu], appName);
			}
		}
	}
}

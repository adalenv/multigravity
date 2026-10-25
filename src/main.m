#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) NSString *profilesDir;
@property (strong, nonatomic) NSString *geminiDir;
@property (strong, nonatomic) NSString *geminiCliDir;
@property (strong, nonatomic) NSString *appSupportDir;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSString *home = NSHomeDirectory();
    self.profilesDir = [home stringByAppendingPathComponent:@".antigravity_profiles"];
    self.geminiDir = [home stringByAppendingPathComponent:@".gemini/antigravity"];
    self.geminiCliDir = [home stringByAppendingPathComponent:@".gemini/antigravity-cli"];
    self.appSupportDir = [home stringByAppendingPathComponent:@"Library/Application Support/Antigravity"];

    [[NSFileManager defaultManager] createDirectoryAtPath:self.profilesDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    // Auto-detect and register live account on startup if needed
    [self ensureActiveProfileSynced];

    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    
    // Status bar icon
    NSImage *icon = nil;
    if (@available(macOS 11.0, *)) {
        icon = [NSImage imageWithSystemSymbolName:@"person.2.circle" accessibilityDescription:@"Multigravity"];
    }
    if (icon) {
        [icon setTemplate:YES];
        self.statusItem.button.image = icon;
    } else {
        self.statusItem.button.title = @"⇋ AGY";
    }

    NSMenu *menu = [[NSMenu alloc] init];
    menu.delegate = self;
    self.statusItem.menu = menu;
}

- (NSString *)detectLiveAccount {
    NSString *home = NSHomeDirectory();
    
    // 1. Check app_storage.json in Application Support
    NSString *appStorage = [home stringByAppendingPathComponent:@"Library/Application Support/Antigravity/app_storage.json"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:appStorage]) {
        NSData *data = [NSData dataWithContentsOfFile:appStorage];
        if (data) {
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSString *email = dict[@"jetski.onboarding.lastLoginUsername"];
            if (email && email.length > 0) return email;
        }
    }
    
    // 2. Check antigravity-oauth-token in ~/.gemini/antigravity-cli
    NSString *tokenFile = [home stringByAppendingPathComponent:@".gemini/antigravity-cli/antigravity-oauth-token"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:tokenFile]) {
        NSData *data = [NSData dataWithContentsOfFile:tokenFile];
        if (data) {
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSString *idToken = dict[@"id_token"];
            if (idToken) {
                NSArray *parts = [idToken componentsSeparatedByString:@"."];
                if (parts.count >= 2) {
                    NSMutableString *b64 = [parts[1] mutableCopy];
                    [b64 replaceOccurrencesOfString:@"-" withString:@"+" options:0 range:NSMakeRange(0, b64.length)];
                    [b64 replaceOccurrencesOfString:@"_" withString:@"/" options:0 range:NSMakeRange(0, b64.length)];
                    while (b64.length % 4 != 0) {
                        [b64 appendString:@"="];
                    }
                    NSData *payloadData = [[NSData alloc] initWithBase64EncodedString:b64 options:0];
                    if (payloadData) {
                        NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:payloadData options:0 error:nil];
                        NSString *email = payload[@"email"];
                        if (email && email.length > 0) return email;
                    }
                }
            }
        }
    }
    return nil;
}

- (NSString *)currentProfile {
    NSString *curFile = [self.profilesDir stringByAppendingPathComponent:@".current"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:curFile]) {
        NSString *name = [NSString stringWithContentsOfFile:curFile encoding:NSUTF8StringEncoding error:nil];
        name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (name.length > 0) return name;
    }
    return nil;
}

- (void)setCurrentProfile:(NSString *)name {
    NSString *curFile = [self.profilesDir stringByAppendingPathComponent:@".current"];
    [name writeToFile:curFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (void)ensureActiveProfileSynced {
    NSString *current = [self currentProfile];
    NSString *detected = [self detectLiveAccount];

    if (!current && detected) {
        [self setCurrentProfile:detected];
        [self saveActiveSessionToProfile:detected];
    } else if (detected && current && [detected containsString:@"@"] && ![current isEqualToString:detected]) {
        // If live user was changed directly in Antigravity, record and save it
        [self setCurrentProfile:detected];
        [self saveActiveSessionToProfile:detected];
    }
}

- (NSArray<NSString *> *)availableProfiles {
    NSError *error = nil;
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.profilesDir error:&error];
    if (!contents) return @[];

    NSMutableArray *profiles = [NSMutableArray array];
    for (NSString *item in contents) {
        if ([item hasPrefix:@"."]) continue;
        NSString *fullPath = [self.profilesDir stringByAppendingPathComponent:item];
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir] && isDir) {
            [profiles addObject:item];
        }
    }
    [profiles sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return profiles;
}

- (void)saveActiveSessionToProfile:(NSString *)profileName {
    if (!profileName || profileName.length == 0) return;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *destDir = [self.profilesDir stringByAppendingPathComponent:profileName];
    [fm createDirectoryAtPath:destDir withIntermediateDirectories:YES attributes:nil error:nil];

    // Backup gemini dir
    if ([fm fileExistsAtPath:self.geminiDir]) {
        NSString *destGemini = [destDir stringByAppendingPathComponent:@"gemini"];
        [fm removeItemAtPath:destGemini error:nil];
        [fm copyItemAtPath:self.geminiDir toPath:destGemini error:nil];
    }
    // Backup gemini-cli dir
    if ([fm fileExistsAtPath:self.geminiCliDir]) {
        NSString *destCli = [destDir stringByAppendingPathComponent:@"gemini-cli"];
        [fm removeItemAtPath:destCli error:nil];
        [fm copyItemAtPath:self.geminiCliDir toPath:destCli error:nil];
    }
    // Backup app support dir
    if ([fm fileExistsAtPath:self.appSupportDir]) {
        NSString *destApp = [destDir stringByAppendingPathComponent:@"app"];
        [fm removeItemAtPath:destApp error:nil];
        [fm copyItemAtPath:self.appSupportDir toPath:destApp error:nil];
    }
}

- (void)restoreProfile:(NSString *)profileName {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *srcDir = [self.profilesDir stringByAppendingPathComponent:profileName];

    // Remove current active directories
    [fm removeItemAtPath:self.geminiDir error:nil];
    [fm removeItemAtPath:self.geminiCliDir error:nil];
    [fm removeItemAtPath:self.appSupportDir error:nil];

    // Restore gemini
    NSString *srcGemini = [srcDir stringByAppendingPathComponent:@"gemini"];
    if ([fm fileExistsAtPath:srcGemini]) {
        [fm createDirectoryAtPath:[self.geminiDir stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        [fm copyItemAtPath:srcGemini toPath:self.geminiDir error:nil];
    }

    // Restore gemini-cli
    NSString *srcCli = [srcDir stringByAppendingPathComponent:@"gemini-cli"];
    if ([fm fileExistsAtPath:srcCli]) {
        [fm createDirectoryAtPath:[self.geminiCliDir stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        [fm copyItemAtPath:srcCli toPath:self.geminiCliDir error:nil];
    }

    // Restore app support
    NSString *srcApp = [srcDir stringByAppendingPathComponent:@"app"];
    if ([fm fileExistsAtPath:srcApp]) {
        [fm createDirectoryAtPath:[self.appSupportDir stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        [fm copyItemAtPath:srcApp toPath:self.appSupportDir error:nil];
    }

    [self setCurrentProfile:profileName];
}

- (void)quitAntigravity {
    for (NSRunningApplication *app in [[NSWorkspace sharedWorkspace] runningApplications]) {
        if ([[app.localizedName lowercaseString] containsString:@"antigravity"]) {
            [app terminate];
        }
    }
    system("pkill -fi Antigravity 2>/dev/null || true");
    usleep(500000); // 0.5s for clean file lock release
}

- (void)launchAntigravity {
    system("open -a 'Antigravity' 2>/dev/null || open -a 'Google Antigravity' 2>/dev/null || true");
}

- (void)menuWillOpen:(NSMenu *)menu {
    [menu removeAllItems];

    [self ensureActiveProfileSynced];

    NSString *current = [self currentProfile];
    if (!current) {
        current = [self detectLiveAccount];
    }
    NSArray *profiles = [self availableProfiles];

    // Active status header
    NSString *headerTitle = current ? [NSString stringWithFormat:@"● Active: %@", current] : @"○ No Account Detected";
    NSMenuItem *headerItem = [[NSMenuItem alloc] initWithTitle:headerTitle action:nil keyEquivalent:@""];
    [headerItem setEnabled:NO];
    [menu addItem:headerItem];

    [menu addItem:[NSMenuItem separatorItem]];

    // Accounts section
    NSMenuItem *accountsHeader = [[NSMenuItem alloc] initWithTitle:@"Accounts:" action:nil keyEquivalent:@""];
    [accountsHeader setEnabled:NO];
    [menu addItem:accountsHeader];

    if (profiles.count == 0 && !current) {
        NSMenuItem *noneItem = [[NSMenuItem alloc] initWithTitle:@"  (No accounts saved)" action:nil keyEquivalent:@""];
        [noneItem setEnabled:NO];
        [menu addItem:noneItem];
    } else {
        NSMutableSet *shown = [NSMutableSet set];
        for (NSString *prof in profiles) {
            [shown addObject:prof];
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"  %@", prof]
                                                          action:@selector(selectProfile:)
                                                   keyEquivalent:@""];
            item.representedObject = prof;
            item.target = self;
            if ([prof isEqualToString:current]) {
                item.state = NSControlStateValueOn;
            }
            [menu addItem:item];
        }
        // If current wasn't in profiles list yet, display it as active
        if (current && ![shown containsObject:current]) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"  %@", current]
                                                          action:@selector(selectProfile:)
                                                   keyEquivalent:@""];
            item.representedObject = current;
            item.target = self;
            item.state = NSControlStateValueOn;
            [menu addItem:item];
        }
    }

    [menu addItem:[NSMenuItem separatorItem]];

    // Actions
    NSMenuItem *addItem = [[NSMenuItem alloc] initWithTitle:@"＋ Add / Log In New Account..."
                                                    action:@selector(addNewAccount:)
                                             keyEquivalent:@"n"];
    addItem.target = self;
    [menu addItem:addItem];

    NSMenuItem *saveItem = [[NSMenuItem alloc] initWithTitle:@"💾 Save Current Session As..."
                                                     action:@selector(saveCurrentAs:)
                                              keyEquivalent:@"s"];
    saveItem.target = self;
    [menu addItem:saveItem];

    NSMenuItem *folderItem = [[NSMenuItem alloc] initWithTitle:@"📁 Open Profiles Folder"
                                                       action:@selector(openProfilesFolder:)
                                                keyEquivalent:@""];
    folderItem.target = self;
    [menu addItem:folderItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit Multigravity"
                                                     action:@selector(quitApp:)
                                              keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];
}

- (void)selectProfile:(NSMenuItem *)sender {
    NSString *target = sender.representedObject;
    if (!target) return;

    NSString *current = [self currentProfile];
    if ([target isEqualToString:current]) return;

    // Auto-save current before switching
    if (current && current.length > 0) {
        [self saveActiveSessionToProfile:current];
    }

    [self quitAntigravity];
    [self restoreProfile:target];
    [self launchAntigravity];
}

- (void)addNewAccount:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Add & Log In New Account";
    alert.informativeText = @"Enter a label for this account (e.g. Work, user2@gmail.com).\n\nAntigravity will restart with a clean session so you can log into Google.";
    [alert addButtonWithTitle:@"Add & Log In"];
    [alert addButtonWithTitle:@"Cancel"];

    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 240, 24)];
    input.placeholderString = @"e.g. work@example.com";
    alert.accessoryView = input;

    if (@available(macOS 14.0, *)) {
        [NSApp activate];
    } else {
        [NSApp activateIgnoringOtherApps:YES];
    }

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *name = [input.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (name.length == 0) return;

        // Auto-save current session first if named
        NSString *current = [self currentProfile];
        if (current && current.length > 0) {
            [self saveActiveSessionToProfile:current];
        }

        // Close running Antigravity
        [self quitAntigravity];

        // Wipe active session directories to present fresh login
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtPath:self.geminiDir error:nil];
        [fm removeItemAtPath:self.geminiCliDir error:nil];
        [fm removeItemAtPath:self.appSupportDir error:nil];

        // Create new profile dir and set active
        NSString *newDir = [self.profilesDir stringByAppendingPathComponent:name];
        [fm createDirectoryAtPath:newDir withIntermediateDirectories:YES attributes:nil error:nil];
        [self setCurrentProfile:name];

        // Launch Antigravity to trigger new account onboarding
        [self launchAntigravity];
    }
}

- (void)saveCurrentAs:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Save Current Account";
    alert.informativeText = @"Enter a name for the currently active session:";
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Cancel"];

    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 240, 24)];
    NSString *current = [self currentProfile];
    if (!current) current = [self detectLiveAccount];
    if (current) input.stringValue = current;
    input.placeholderString = @"e.g. Personal";
    alert.accessoryView = input;

    if (@available(macOS 14.0, *)) {
        [NSApp activate];
    } else {
        [NSApp activateIgnoringOtherApps:YES];
    }

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *name = [input.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (name.length == 0) return;

        [self saveActiveSessionToProfile:name];
        [self setCurrentProfile:name];
    }
}

- (void)openProfilesFolder:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:self.profilesDir]];
}

- (void)quitApp:(id)sender {
    // shortcut: Active session is saved on switch or explicit save, not on quit. Upgrade to auto-save-on-quit if background drift occurs.
    [NSApp terminate:nil];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [app run];
    }
    return 0;
}

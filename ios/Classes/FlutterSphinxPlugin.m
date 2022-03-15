#import "FlutterSphinxPlugin.h"
#if __has_include(<flutter_sphinx/flutter_sphinx-Swift.h>)
#import <flutter_sphinx/flutter_sphinx-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_sphinx-Swift.h"
#endif

@implementation FlutterSphinxPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterSphinxPlugin registerWithRegistrar:registrar];
}
@end

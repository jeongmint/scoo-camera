"""Regenerate SCOO.xcodeproj without XcodeGen or third-party dependencies."""
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / 'ios'
objects = {}

def uid(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()

def add(key, **values):
    ident = uid(key)
    objects[ident] = values
    return ident

def serialize(value, indent=0):
    if isinstance(value, dict):
        if not value:
            return '{}'
        return '{\n' + ''.join('\t' * (indent + 1) + serialize(str(k)) + ' = ' + serialize(v, indent + 1) + ';\n' for k, v in value.items()) + '\t' * indent + '}'
    if isinstance(value, list):
        return '(' + ', '.join(serialize(v, indent + 1) for v in value) + ')'
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"') + '"'

sources, resources = [], []
test_sources = []
widget_sources, widget_resources = [], []

def group(directory, targets):
    """targets: list of (key, sources, resources); the first one keeps the original build-file ids."""
    children = []
    for item in sorted(directory.iterdir()):
        relative = str(item.relative_to(IOS))
        if item.name.startswith('.'):
            continue
        if item.is_dir() and item.suffix != '.xcassets':
            children.append(group(item, targets))
            continue
        filetype = {'.swift': 'sourcecode.swift', '.plist': 'text.plist.xml', '.xcprivacy': 'text.xml',
                    '.xcassets': 'folder.assetcatalog', '.entitlements': 'text.plist.entitlements'}[item.suffix]
        ref = add(relative, isa='PBXFileReference', lastKnownFileType=filetype, path=item.name, sourceTree='<group>')
        children.append(ref)
        for index, (key, target_sources, target_resources) in enumerate(targets):
            suffix = '.build' if index == 0 else '.build.' + key
            if item.suffix == '.swift':
                target_sources.append(add(relative + suffix, isa='PBXBuildFile', fileRef=ref))
            elif item.suffix in ('.xcassets', '.xcprivacy') and target_resources is not None:
                target_resources.append(add(relative + suffix, isa='PBXBuildFile', fileRef=ref))
    return add(str(directory.relative_to(IOS)) + '.group', isa='PBXGroup', path=directory.name, sourceTree='<group>', children=children)

app_group = group(IOS / 'SCOO', [('app', sources, resources)])
shared_group = group(IOS / 'SCOOShared', [('app', sources, None), ('widget', widget_sources, None)])
widget_group = group(IOS / 'SCOOWidget', [('widget', widget_sources, widget_resources)])
test_group = group(IOS / 'SCOOTests', [('test', test_sources, None)])
app_product = add('SCOO.app', isa='PBXFileReference', explicitFileType='wrapper.application', includeInIndex='0', path='SCOO.app', sourceTree='BUILT_PRODUCTS_DIR')
test_product = add('SCOOTests.xctest', isa='PBXFileReference', explicitFileType='wrapper.cfbundle', includeInIndex='0', path='SCOOTests.xctest', sourceTree='BUILT_PRODUCTS_DIR')
widget_product = add('SCOOWidget.appex', isa='PBXFileReference', explicitFileType='wrapper.app-extension', includeInIndex='0', path='SCOOWidget.appex', sourceTree='BUILT_PRODUCTS_DIR')
products = add('products', isa='PBXGroup', name='Products', sourceTree='<group>', children=[app_product, test_product, widget_product])
main = add('main', isa='PBXGroup', sourceTree='<group>', children=[app_group, shared_group, widget_group, test_group, products])

def phase(name, isa, files):
    return add(name, isa=isa, buildActionMask='2147483647', files=files, runOnlyForDeploymentPostprocessing='0')

embed_widget = add('widget.embed.build', isa='PBXBuildFile', fileRef=widget_product, settings={'ATTRIBUTES': ['RemoveHeadersOnCopy']})
embed_phase = add('app.embed', isa='PBXCopyFilesBuildPhase', buildActionMask='2147483647', dstPath='', dstSubfolderSpec='13',
                  files=[embed_widget], name='Embed Foundation Extensions', runOnlyForDeploymentPostprocessing='0')
app_phases = [phase('app.sources', 'PBXSourcesBuildPhase', sources), phase('app.frameworks', 'PBXFrameworksBuildPhase', []), phase('app.resources', 'PBXResourcesBuildPhase', resources), embed_phase]
test_phases = [phase('test.sources', 'PBXSourcesBuildPhase', test_sources), phase('test.frameworks', 'PBXFrameworksBuildPhase', [])]
widget_phases = [phase('widget.sources', 'PBXSourcesBuildPhase', widget_sources), phase('widget.frameworks', 'PBXFrameworksBuildPhase', []), phase('widget.resources', 'PBXResourcesBuildPhase', widget_resources)]

project_common = {
    'ALWAYS_SEARCH_USER_PATHS': 'NO', 'CLANG_ENABLE_MODULES': 'YES', 'CLANG_ENABLE_OBJC_ARC': 'YES',
    'CLANG_WARN_UNGUARDED_AVAILABILITY': 'YES_AGGRESSIVE', 'GCC_C_LANGUAGE_STANDARD': 'gnu17',
    'IPHONEOS_DEPLOYMENT_TARGET': '17.0', 'SDKROOT': 'iphoneos', 'SWIFT_VERSION': '5.0',
    'ENABLE_USER_SCRIPT_SANDBOXING': 'YES', 'SWIFT_STRICT_CONCURRENCY': 'minimal',
}
app_common = {
    'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon', 'CODE_SIGN_STYLE': 'Automatic',
    'CURRENT_PROJECT_VERSION': '1', 'GENERATE_INFOPLIST_FILE': 'NO', 'INFOPLIST_FILE': 'SCOO/Resources/Info.plist',
    'LD_RUNPATH_SEARCH_PATHS': ['$(inherited)', '@executable_path/Frameworks'], 'MARKETING_VERSION': '0.2.0',
    'PRODUCT_BUNDLE_IDENTIFIER': 'com.jeongmint.scoo', 'PRODUCT_NAME': '$(TARGET_NAME)',
    'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator', 'SUPPORTS_MACCATALYST': 'NO', 'TARGETED_DEVICE_FAMILY': '1',
    'SWIFT_EMIT_LOC_STRINGS': 'YES', 'CODE_SIGN_ENTITLEMENTS': 'SCOO/Resources/SCOO.entitlements',
    # Supabase publishable (anon) key: public by design, protected by row level security. Never a secret key.
    'SUPABASE_ANON_KEY': '',
}
# Home screen and lock screen widget. Shares the app group in SCOOShared/WidgetShared.swift.
widget_common = {
    'CODE_SIGN_STYLE': 'Automatic', 'CODE_SIGN_ENTITLEMENTS': 'SCOOWidget/SCOOWidget.entitlements',
    'CURRENT_PROJECT_VERSION': '1', 'MARKETING_VERSION': '0.2.0', 'GENERATE_INFOPLIST_FILE': 'NO',
    'INFOPLIST_FILE': 'SCOOWidget/Info.plist', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.jeongmint.scoo.widget',
    'PRODUCT_NAME': '$(TARGET_NAME)', 'SKIP_INSTALL': 'YES', 'TARGETED_DEVICE_FAMILY': '1',
    'LD_RUNPATH_SEARCH_PATHS': ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks'],
    'SWIFT_EMIT_LOC_STRINGS': 'YES', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator', 'SUPPORTS_MACCATALYST': 'NO',
}
test_common = {
    'BUNDLE_LOADER': '$(TEST_HOST)', 'CODE_SIGN_STYLE': 'Automatic', 'GENERATE_INFOPLIST_FILE': 'YES',
    'PRODUCT_BUNDLE_IDENTIFIER': 'com.jeongmint.scoo.tests', 'PRODUCT_NAME': '$(TARGET_NAME)',
    'TEST_HOST': '$(BUILT_PRODUCTS_DIR)/SCOO.app/SCOO', 'TARGETED_DEVICE_FAMILY': '1',
    'LD_RUNPATH_SEARCH_PATHS': ['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks'],
}

def configs(name, common):
    configs = []
    for mode in ['Debug', 'Release']:
        settings = dict(common)
        settings.update({'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if mode == 'Debug' else '-O', 'DEBUG_INFORMATION_FORMAT': 'dwarf' if mode == 'Debug' else 'dwarf-with-dsym'})
        if mode == 'Debug':
            settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG $(inherited)'
            settings['ENABLE_TESTABILITY'] = 'YES'
        configs.append(add(name + mode, isa='XCBuildConfiguration', name=mode, buildSettings=settings))
    return add(name + '.configs', isa='XCConfigurationList', buildConfigurations=configs, defaultConfigurationIsVisible='0', defaultConfigurationName='Release')

app_config = configs('app', app_common)
test_config = configs('test', test_common)
widget_config = configs('widget', widget_common)
project_config = configs('project', project_common)
app_target = uid('app.target')
widget_target = uid('widget.target')
proxy = add('test.proxy', isa='PBXContainerItemProxy', containerPortal=uid('project'), proxyType='1', remoteGlobalIDString=app_target, remoteInfo='SCOO')
dependency = add('test.dep', isa='PBXTargetDependency', target=app_target, targetProxy=proxy)
widget_proxy = add('widget.proxy', isa='PBXContainerItemProxy', containerPortal=uid('project'), proxyType='1', remoteGlobalIDString=widget_target, remoteInfo='SCOOWidget')
widget_dependency = add('widget.dep', isa='PBXTargetDependency', target=widget_target, targetProxy=widget_proxy)
add('app.target', isa='PBXNativeTarget', buildConfigurationList=app_config, buildPhases=app_phases, buildRules=[], dependencies=[widget_dependency], name='SCOO', productName='SCOO', productReference=app_product, productType='com.apple.product-type.application')
add('widget.target', isa='PBXNativeTarget', buildConfigurationList=widget_config, buildPhases=widget_phases, buildRules=[], dependencies=[], name='SCOOWidget', productName='SCOOWidget', productReference=widget_product, productType='com.apple.product-type.app-extension')
test_target = add('test.target', isa='PBXNativeTarget', buildConfigurationList=test_config, buildPhases=test_phases, buildRules=[], dependencies=[dependency], name='SCOOTests', productName='SCOOTests', productReference=test_product, productType='com.apple.product-type.bundle.unit-test')
project = add('project', isa='PBXProject', attributes={'BuildIndependentTargetsInParallel': 'YES', 'LastUpgradeCheck': '1600', 'TargetAttributes': {app_target: {'CreatedOnToolsVersion': '16.0'}, widget_target: {'CreatedOnToolsVersion': '16.0'}, test_target: {'CreatedOnToolsVersion': '16.0', 'TestTargetID': app_target}}}, buildConfigurationList=project_config, compatibilityVersion='Xcode 14.0', developmentRegion='ko', hasScannedForEncodings='0', knownRegions=['ko', 'en', 'Base'], mainGroup=main, productRefGroup=products, projectDirPath='', projectRoot='', targets=[app_target, widget_target, test_target])
result = {'archiveVersion': '1', 'classes': {}, 'objectVersion': '56', 'objects': objects, 'rootObject': project}
project_dir = IOS / 'SCOO.xcodeproj'
project_dir.mkdir(exist_ok=True)
(project_dir / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + serialize(result) + '\n')
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="SCOO.app" BlueprintName="SCOO" ReferencedContainer="container:SCOO.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{test_target}" BuildableName="SCOOTests.xctest" BlueprintName="SCOOTests" ReferencedContainer="container:SCOO.xcodeproj"/></TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="SCOO.app" BlueprintName="SCOO" ReferencedContainer="container:SCOO.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="SCOO.app" BlueprintName="SCOO" ReferencedContainer="container:SCOO.xcodeproj"/></BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
scheme_dir = project_dir / 'xcshareddata' / 'xcschemes'
scheme_dir.mkdir(parents=True, exist_ok=True)
(scheme_dir / 'SCOO.xcscheme').write_text(scheme + '\n')
print(f'Generated project: {len(sources)} app sources, {len(widget_sources)} widget sources, {len(test_sources)} test source, {len(resources)} resources')

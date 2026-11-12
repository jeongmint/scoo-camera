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

def group(directory):
    children = []
    for item in sorted(directory.iterdir()):
        relative = str(item.relative_to(IOS))
        if item.is_dir() and item.suffix != '.xcassets':
            children.append(group(item))
            continue
        filetype = {'.swift': 'sourcecode.swift', '.plist': 'text.plist.xml', '.xcprivacy': 'text.xml', '.xcassets': 'folder.assetcatalog'}[item.suffix]
        ref = add(relative, isa='PBXFileReference', lastKnownFileType=filetype, path=item.name, sourceTree='<group>')
        children.append(ref)
        if item.suffix == '.swift':
            build = add(relative + '.build', isa='PBXBuildFile', fileRef=ref)
            (sources if 'SCOOTests' not in relative else test_sources).append(build)
        elif item.suffix in ('.xcassets', '.xcprivacy'):
            resources.append(add(relative + '.build', isa='PBXBuildFile', fileRef=ref))
    return add(str(directory.relative_to(IOS)) + '.group', isa='PBXGroup', path=directory.name, sourceTree='<group>', children=children)

test_sources = []
app_group = group(IOS / 'SCOO')
test_group = group(IOS / 'SCOOTests')
app_product = add('SCOO.app', isa='PBXFileReference', explicitFileType='wrapper.application', includeInIndex='0', path='SCOO.app', sourceTree='BUILT_PRODUCTS_DIR')
test_product = add('SCOOTests.xctest', isa='PBXFileReference', explicitFileType='wrapper.cfbundle', includeInIndex='0', path='SCOOTests.xctest', sourceTree='BUILT_PRODUCTS_DIR')
products = add('products', isa='PBXGroup', name='Products', sourceTree='<group>', children=[app_product, test_product])
main = add('main', isa='PBXGroup', sourceTree='<group>', children=[app_group, test_group, products])

def phase(name, isa, files):
    return add(name, isa=isa, buildActionMask='2147483647', files=files, runOnlyForDeploymentPostprocessing='0')

app_phases = [phase('app.sources', 'PBXSourcesBuildPhase', sources), phase('app.frameworks', 'PBXFrameworksBuildPhase', []), phase('app.resources', 'PBXResourcesBuildPhase', resources)]
test_phases = [phase('test.sources', 'PBXSourcesBuildPhase', test_sources), phase('test.frameworks', 'PBXFrameworksBuildPhase', [])]

project_common = {
    'ALWAYS_SEARCH_USER_PATHS': 'NO', 'CLANG_ENABLE_MODULES': 'YES', 'CLANG_ENABLE_OBJC_ARC': 'YES',
    'CLANG_WARN_UNGUARDED_AVAILABILITY': 'YES_AGGRESSIVE', 'GCC_C_LANGUAGE_STANDARD': 'gnu17',
    'IPHONEOS_DEPLOYMENT_TARGET': '17.0', 'SDKROOT': 'iphoneos', 'SWIFT_VERSION': '5.0',
    'ENABLE_USER_SCRIPT_SANDBOXING': 'YES', 'SWIFT_STRICT_CONCURRENCY': 'minimal',
}
app_common = {
    'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon', 'CODE_SIGN_STYLE': 'Automatic',
    'CURRENT_PROJECT_VERSION': '1', 'GENERATE_INFOPLIST_FILE': 'NO', 'INFOPLIST_FILE': 'SCOO/Resources/Info.plist',
    'LD_RUNPATH_SEARCH_PATHS': ['$(inherited)', '@executable_path/Frameworks'], 'MARKETING_VERSION': '0.1.0',
    'PRODUCT_BUNDLE_IDENTIFIER': 'com.jeongmint.scoo', 'PRODUCT_NAME': '$(TARGET_NAME)',
    'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator', 'SUPPORTS_MACCATALYST': 'NO', 'TARGETED_DEVICE_FAMILY': '1',
    'SWIFT_EMIT_LOC_STRINGS': 'YES',
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
project_config = configs('project', project_common)
app_target = uid('app.target')
proxy = add('test.proxy', isa='PBXContainerItemProxy', containerPortal=uid('project'), proxyType='1', remoteGlobalIDString=app_target, remoteInfo='SCOO')
dependency = add('test.dep', isa='PBXTargetDependency', target=app_target, targetProxy=proxy)
add('app.target', isa='PBXNativeTarget', buildConfigurationList=app_config, buildPhases=app_phases, buildRules=[], dependencies=[], name='SCOO', productName='SCOO', productReference=app_product, productType='com.apple.product-type.application')
test_target = add('test.target', isa='PBXNativeTarget', buildConfigurationList=test_config, buildPhases=test_phases, buildRules=[], dependencies=[dependency], name='SCOOTests', productName='SCOOTests', productReference=test_product, productType='com.apple.product-type.bundle.unit-test')
project = add('project', isa='PBXProject', attributes={'BuildIndependentTargetsInParallel': 'YES', 'LastUpgradeCheck': '1600', 'TargetAttributes': {app_target: {'CreatedOnToolsVersion': '16.0'}, test_target: {'CreatedOnToolsVersion': '16.0', 'TestTargetID': app_target}}}, buildConfigurationList=project_config, compatibilityVersion='Xcode 14.0', developmentRegion='ko', hasScannedForEncodings='0', knownRegions=['ko', 'en', 'Base'], mainGroup=main, productRefGroup=products, projectDirPath='', projectRoot='', targets=[app_target, test_target])
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
print(f'Generated project: {len(sources)} app sources, {len(test_sources)} test source, {len(resources)} resources')

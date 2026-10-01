#!/usr/bin/env ruby
require 'xcodeproj'

# Add the test-only target on the CI runner without changing the shipping project.
project = Xcodeproj::Project.open('NightfallProtocol.xcodeproj')
app = project.targets.find { |target| target.name == 'NightfallProtocol' }
tests = project.new_target(:ui_test_bundle, 'ReleaseEvidenceTests', :ios, '17.0')
tests.add_dependency(app)
tests.source_build_phase.add_file_reference(project.main_group.new_file('Tests/ReleaseEvidenceTests.swift'))
tests.resources_build_phase.add_file_reference(project.main_group.new_file('NightfallProtocol/Resources/NightfallProtocol.storekit'))
tests.add_system_framework('StoreKitTest')
tests.build_configurations.each do |config|
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.nightfallprotocol.release-evidence'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['TEST_TARGET_NAME'] = 'NightfallProtocol'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_build_target(tests)
scheme.add_test_target(tests)
scheme.set_launch_target(app)
scheme.save_as('NightfallProtocol.xcodeproj', 'ReleaseEvidence', true)

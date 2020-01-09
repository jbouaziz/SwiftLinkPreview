Pod::Spec.new do |s|

	s.ios.deployment_target = '10.0'
	s.osx.deployment_target     = "10.12"
    s.watchos.deployment_target = '3.0'
    s.tvos.deployment_target    = '10.0'
	s.name = "SwiftLinkPreview"
	s.summary = "It makes a preview from an url, grabbing all the information such as title, relevant texts and images."
	s.requires_arc = true
	s.version = "3.3.0"
	s.license = { :type => "MIT", :file => "LICENSE" }
	s.author = { "Jonathan Bouaziz" => "jonathan@etvoilapp.com" }
	s.homepage = "https://github.com/jbouaziz/SwiftLinkPreview"
	s.source = { :git => "https://github.com/jbouaziz/SwiftLinkPreview.git", :tag => s.version }
	s.source_files = "Sources/**/*.swift"
	s.swift_version = '5.1'

end

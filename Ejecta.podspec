Pod::Spec.new do |s|
  s.name      = 'Ejecta'
  s.version   = '2.0.0'
  s.license   = { :type => "MIT", :text => "Copyright (c) 2013 Dominic Szablewski."}
  s.homepage  = 'http://impactjs.com/ejecta'
  s.summary   = 'A Fast, Open Source JavaScript, Canvas & Audio Implementation for iOS.'
  s.author    = { 'Dominic Szablewski' => 'dominic.szablewski@gmail.com' }
  s.source    = { :git => 'https://github.com/paperlesspost/Ejecta.git', :tag => s.version.to_s }

  s.platform = :ios, 7.0
  s.ios.deployment_target = '8.0'

  s.source_files = 'Source/Ejecta/**/*.{h,m,mm}', 'Source/lib/SocketRocket/SRWebSocket.{h,m}'
  s.public_header_files = 'Source/Ejecta/**/*.h'
  s.private_header_files = 'Source/Ejecta/EJCanvas/2D/EJCanvasShaders.h', 'Source/lib/SocketRocket/SRWebSocket.h'
  s.resources    = 'Source/Ejecta/Ejecta.js', 'Source/Ejecta/EJCanvas/2D/Shaders/*'
  s.requires_arc = "Source/lib/SocketRocket/SRWebSocket.m"

  s.default_subspec = 'Library'
  s.frameworks = 'JavaScriptCore', 'SystemConfiguration', 'CoreText', 'QuartzCore', 'GameKit', 'CoreGraphics', 'OpenAL', 'AudioToolbox', 'OpenGLES', 'AVFoundation', 'iAd', 'CoreMotion', 'MediaPlayer', 'CoreLocation'

  s.subspec 'Library' do |os|
    os.source_files = 'Source/Ejecta/**/*.{h,m,mm}', 'Source/lib/SocketRocket/SRWebSocket.{h,m}'
#    os.vendored_frameworks = 'Source/lib/JavaScriptCore.framework'
    os.public_header_files = 'Source/Ejecta/**/*.h'
    os.private_header_files = 'Source/Ejecta/EJCanvas/2D/EJCanvasShaders.h', 'Source/lib/SocketRocket/SRWebSocket.h'
    os.library = 'stdc++', 'icucore'
    s.pod_target_xcconfig = {
      'CLANG_CXX_LANGUAGE_STANDARD' => 'gnu++98',
      'CLANG_CXX_LIBRARY' => 'libc++',
      'ENABLE_BITCODE' => 'NO'
    }
  end

end
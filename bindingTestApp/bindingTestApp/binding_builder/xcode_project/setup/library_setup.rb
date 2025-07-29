#!/usr/bin/env ruby

require "fileutils"
require "pathname"
require_relative "../pbxproj_manager"
require_relative "../../project_finder"
require_relative "../../config_manager"

class LibrarySetup < PbxprojManager
  def initialize(project_file_path = nil)
    super(project_file_path)
  end

  def setup_libraries
    puts "Setting up required libraries..."
    
    # SwiftJsonUIパッケージを追加
    add_swiftjsonui_package
    
    # SimpleApiNetworkパッケージを追加（use_networkがtrueの場合）
    add_simpleapinetwork_package_if_enabled
    
    puts "Library setup completed successfully!"
  end

  private

  def add_swiftjsonui_package
    puts "Checking SwiftJsonUI package..."
    
    # pbxprojファイルの内容を読み取り
    content = File.read(@project_file_path)
    
    # 既にSwiftJsonUIパッケージが追加されているかチェック
    if content.include?("SwiftJsonUI") && content.include?("Tai-Kimura/SwiftJsonUI")
      puts "SwiftJsonUI package already exists in the project"
      return
    end
    
    puts "Adding SwiftJsonUI package to Xcode project..."
    
    safe_pbxproj_operation([], []) do
      add_swiftjsonui_package_to_pbxproj
      puts "Successfully added SwiftJsonUI package to Xcode project"
    end
  end

  def add_swiftjsonui_package_to_pbxproj
    # バックアップ作成
    backup_path = create_backup(@project_file_path)
    
    begin
      content = File.read(@project_file_path)
      
      # UUIDを生成
      package_ref_uuid = generate_uuid
      package_dependency_uuid = generate_uuid
      build_file_uuid = generate_uuid
      
      # XCRemoteSwiftPackageReferenceセクションを追加
      if content.include?("/* Begin XCRemoteSwiftPackageReference section */")
        # 既存のセクションに追加
        content = content.gsub(
          /(\/* Begin XCRemoteSwiftPackageReference section \*\/.*?)([\s\S]*?)(\n\/* End XCRemoteSwiftPackageReference section \*\/)/m,
          "\\1\\2\n\t\t#{package_ref_uuid} /* XCRemoteSwiftPackageReference \"SwiftJsonUI\" */ = {\n\t\t\tisa = XCRemoteSwiftPackageReference;\n\t\t\trepositoryURL = \"https://github.com/Tai-Kimura/SwiftJsonUI\";\n\t\t\trequirement = {\n\t\t\t\tkind = upToNextMajorVersion;\n\t\t\t\tminimumVersion = 5.3.0;\n\t\t\t};\n\t\t};\\3"
        )
      else
        # 新しいセクションを作成
        content = content.gsub(
          /(\/* End XCConfigurationList section \*\/)/,
          "\\1\n\n/* Begin XCRemoteSwiftPackageReference section */\n\t\t#{package_ref_uuid} /* XCRemoteSwiftPackageReference \"SwiftJsonUI\" */ = {\n\t\t\tisa = XCRemoteSwiftPackageReference;\n\t\t\trepositoryURL = \"https://github.com/Tai-Kimura/SwiftJsonUI\";\n\t\t\trequirement = {\n\t\t\t\tkind = upToNextMajorVersion;\n\t\t\t\tminimumVersion = 5.3.0;\n\t\t\t};\n\t\t};\n/* End XCRemoteSwiftPackageReference section */"
        )
      end
      
      # XCSwiftPackageProductDependencyセクションを追加
      if content.include?("/* Begin XCSwiftPackageProductDependency section */")
        # 既存のセクションに追加
        content = content.gsub(
          /(\/* Begin XCSwiftPackageProductDependency section \*\/.*?)([\s\S]*?)(\n\/* End XCSwiftPackageProductDependency section \*\/)/m,
          "\\1\\2\n\t\t#{package_dependency_uuid} /* SwiftJsonUI */ = {\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = #{package_ref_uuid} /* XCRemoteSwiftPackageReference \"SwiftJsonUI\" */;\n\t\t\tproductName = SwiftJsonUI;\n\t\t};\\3"
        )
      else
        # 新しいセクションを作成
        content = content.gsub(
          /(\/* End XCRemoteSwiftPackageReference section \*\/)/,
          "\\1\n\n/* Begin XCSwiftPackageProductDependency section */\n\t\t#{package_dependency_uuid} /* SwiftJsonUI */ = {\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = #{package_ref_uuid} /* XCRemoteSwiftPackageReference \"SwiftJsonUI\" */;\n\t\t\tproductName = SwiftJsonUI;\n\t\t};\n/* End XCSwiftPackageProductDependency section */"
        )
      end
      
      # PBXBuildFileセクションを追加
      if content.include?("/* Begin PBXBuildFile section */")
        content = content.gsub(
          /(\/* Begin PBXBuildFile section \*\/)/,
          "\\1\n\t\t#{build_file_uuid} /* SwiftJsonUI in Frameworks */ = {isa = PBXBuildFile; productRef = #{package_dependency_uuid} /* SwiftJsonUI */; };"
        )
      end
      
      # packageReferencesを追加（PBXProjectセクション内）
      unless content.include?("packageReferences = (")
        content = content.gsub(
          /(\s+)(minimizedProjectReferenceProxies = \d+;)/,
          "\\1\\2\n\\1packageReferences = (\n\\1\t#{package_ref_uuid} /* XCRemoteSwiftPackageReference \"SwiftJsonUI\" */,\n\\1);"
        )
      else
        # 既存のpackageReferencesに追加
        content = content.gsub(
          /(packageReferences = \(\s*)(.*?)(\s*\);)/m,
          "\\1\\2\n\t\t\t\t#{package_ref_uuid} /* XCRemoteSwiftPackageReference \"SwiftJsonUI\" */,\\3"
        )
      end
      
      # packageProductDependenciesをプロジェクトターゲットに追加
      project_name = ProjectFinder.detect_project_name(@project_file_path)
      content = content.gsub(
        /(name = #{project_name};[\s\S]*?packageProductDependencies = \(\s*)(.*?)(\s*\);)/m,
        "\\1\\2\n\t\t\t\t#{package_dependency_uuid} /* SwiftJsonUI */,\\3"
      )
      
      # Frameworksセクションに追加（動的にFrameworksセクションを検索）
      frameworks_pattern = /([A-F0-9]{24} \/\* Frameworks \*\/ = \{\s+isa = PBXFrameworksBuildPhase;\s+buildActionMask = \d+;\s+files = \(\s*)(.*?)(\s*\);)/m
      if content.match(frameworks_pattern)
        content = content.gsub(
          frameworks_pattern,
          "\\1\\2\n\t\t\t\t#{build_file_uuid} /* SwiftJsonUI in Frameworks */,\\3"
        )
      end
      
      # ファイルに書き込み
      File.write(@project_file_path, content)
      
      # 整合性検証
      if validate_pbxproj(@project_file_path)
        puts "✅ SwiftJsonUI package added successfully"
        cleanup_backup(backup_path)
      else
        puts "❌ pbxproj validation failed after SwiftJsonUI package addition, rolling back..."
        FileUtils.copy(backup_path, @project_file_path)
        cleanup_backup(backup_path)
        raise "pbxproj file corruption detected after SwiftJsonUI package addition"
      end
      
    rescue => e
      puts "Error during SwiftJsonUI package addition: #{e.message}"
      if File.exist?(backup_path)
        FileUtils.copy(backup_path, @project_file_path)
        cleanup_backup(backup_path)
        puts "Restored pbxproj file from backup"
      end
      raise e
    end
  end

  def add_simpleapinetwork_package_if_enabled
    # ConfigManagerでuse_network設定を確認
    base_dir = File.expand_path('../..', File.dirname(__FILE__))
    use_network = ConfigManager.get_use_network(base_dir)
    
    return unless use_network
    
    puts "Checking SimpleApiNetwork package..."
    
    # pbxprojファイルの内容を読み取り
    content = File.read(@project_file_path)
    
    # 既にSimpleApiNetworkパッケージが追加されているかチェック
    if content.include?("SimpleApiNetwork") && content.include?("Tai-Kimura/SimpleApiNetwork")
      puts "SimpleApiNetwork package already exists in the project"
      return
    end
    
    puts "Adding SimpleApiNetwork package to Xcode project..."
    
    safe_pbxproj_operation([], []) do
      add_simpleapinetwork_package_to_pbxproj
      puts "Successfully added SimpleApiNetwork package to Xcode project"
    end
  end

  def add_simpleapinetwork_package_to_pbxproj
    # バックアップ作成
    backup_path = create_backup(@project_file_path)
    
    begin
      content = File.read(@project_file_path)
      
      # UUIDを生成
      package_ref_uuid = generate_uuid
      package_dependency_uuid = generate_uuid
      build_file_uuid = generate_uuid
      
      # XCRemoteSwiftPackageReferenceセクションを追加
      if content.include?("/* Begin XCRemoteSwiftPackageReference section */")
        # 既存のセクションに追加
        content = content.gsub(
          /(\/* Begin XCRemoteSwiftPackageReference section \*\/.*?)([\s\S]*?)(\n\/* End XCRemoteSwiftPackageReference section \*\/)/m,
          "\\1\\2\n\t\t#{package_ref_uuid} /* XCRemoteSwiftPackageReference \"SimpleApiNetwork\" */ = {\n\t\t\tisa = XCRemoteSwiftPackageReference;\n\t\t\trepositoryURL = \"https://github.com/Tai-Kimura/SimpleApiNetwork\";\n\t\t\trequirement = {\n\t\t\t\tkind = upToNextMajorVersion;\n\t\t\t\tminimumVersion = 2.1.8;\n\t\t\t};\n\t\t};\\3"
        )
      else
        # 新しいセクションを作成
        content = content.gsub(
          /(\/* End XCSwiftPackageProductDependency section \*\/)/,
          "\\1\n\n/* Begin XCRemoteSwiftPackageReference section */\n\t\t#{package_ref_uuid} /* XCRemoteSwiftPackageReference \"SimpleApiNetwork\" */ = {\n\t\t\tisa = XCRemoteSwiftPackageReference;\n\t\t\trepositoryURL = \"https://github.com/Tai-Kimura/SimpleApiNetwork\";\n\t\t\trequirement = {\n\t\t\t\tkind = upToNextMajorVersion;\n\t\t\t\tminimumVersion = 2.1.8;\n\t\t\t};\n\t\t};\n/* End XCRemoteSwiftPackageReference section */"
        )
      end
      
      # XCSwiftPackageProductDependencyセクションを追加
      if content.include?("/* Begin XCSwiftPackageProductDependency section */")
        # 既存のセクションに追加
        content = content.gsub(
          /(\/* Begin XCSwiftPackageProductDependency section \*\/.*?)([\s\S]*?)(\n\/* End XCSwiftPackageProductDependency section \*\/)/m,
          "\\1\\2\n\t\t#{package_dependency_uuid} /* SimpleApiNetwork */ = {\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = #{package_ref_uuid} /* XCRemoteSwiftPackageReference \"SimpleApiNetwork\" */;\n\t\t\tproductName = SimpleApiNetwork;\n\t\t};\\3"
        )
      else
        # 新しいセクションを作成
        content = content.gsub(
          /(\/* End XCRemoteSwiftPackageReference section \*\/)/,
          "\\1\n\n/* Begin XCSwiftPackageProductDependency section */\n\t\t#{package_dependency_uuid} /* SimpleApiNetwork */ = {\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = #{package_ref_uuid} /* XCRemoteSwiftPackageReference \"SimpleApiNetwork\" */;\n\t\t\tproductName = SimpleApiNetwork;\n\t\t};\n/* End XCSwiftPackageProductDependency section */"
        )
      end
      
      # PBXBuildFileセクションを追加
      if content.include?("/* Begin PBXBuildFile section */")
        content = content.gsub(
          /(\/* Begin PBXBuildFile section \*\/)/,
          "\\1\n\t\t#{build_file_uuid} /* SimpleApiNetwork in Frameworks */ = {isa = PBXBuildFile; productRef = #{package_dependency_uuid} /* SimpleApiNetwork */; };"
        )
      end
      
      # packageReferencesを追加（PBXProjectセクション内）
      content = content.gsub(
        /(packageReferences = \(\s*)(.*?)(\s*\);)/m,
        "\\1\\2\n\t\t\t\t#{package_ref_uuid} /* XCRemoteSwiftPackageReference \"SimpleApiNetwork\" */,\\3"
      )
      
      # packageProductDependenciesをプロジェクトターゲットに追加
      project_name = ProjectFinder.detect_project_name(@project_file_path)
      content = content.gsub(
        /(name = #{project_name};[\s\S]*?packageProductDependencies = \(\s*)(.*?)(\s*\);)/m,
        "\\1\\2\n\t\t\t\t#{package_dependency_uuid} /* SimpleApiNetwork */,\\3"
      )
      
      # Frameworksセクションに追加（動的にFrameworksセクションを検索）
      frameworks_pattern = /([A-F0-9]{24} \/\* Frameworks \*\/ = \{\s+isa = PBXFrameworksBuildPhase;\s+buildActionMask = \d+;\s+files = \(\s*)(.*?)(\s*\);)/m
      if content.match(frameworks_pattern)
        content = content.gsub(
          frameworks_pattern,
          "\\1\\2\n\t\t\t\t#{build_file_uuid} /* SimpleApiNetwork in Frameworks */,\\3"
        )
      end
      
      # ファイルに書き込み
      File.write(@project_file_path, content)
      
      # 整合性検証
      if validate_pbxproj(@project_file_path)
        puts "✅ SimpleApiNetwork package added successfully"
        cleanup_backup(backup_path)
      else
        puts "❌ pbxproj validation failed after SimpleApiNetwork package addition, rolling back..."
        FileUtils.copy(backup_path, @project_file_path)
        cleanup_backup(backup_path)
        raise "pbxproj file corruption detected after SimpleApiNetwork package addition"
      end
      
    rescue => e
      puts "Error during SimpleApiNetwork package addition: #{e.message}"
      if File.exist?(backup_path)
        FileUtils.copy(backup_path, @project_file_path)
        cleanup_backup(backup_path)
        puts "Restored pbxproj file from backup"
      end
      raise e
    end
  end

  def generate_uuid
    # Xcodeプロジェクトで使用される24桁の16進数UUIDを生成
    (0...24).map { "0123456789ABCDEF"[rand(16)] }.join
  end
end
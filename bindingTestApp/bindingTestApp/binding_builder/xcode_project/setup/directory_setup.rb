#!/usr/bin/env ruby

require "fileutils"
require "pathname"
require_relative "../xcode_project_manager"
require_relative "../../project_finder"
require_relative "../pbxproj_manager"
require_relative "../generators/ui_view_creator_generator"
require_relative "../generators/base_view_controller_generator"
require_relative "../generators/base_binding_generator"
require_relative "../generators/base_collection_view_cell_generator"

class DirectorySetup < PbxprojManager
  def initialize(project_file_path = nil)
    super(project_file_path)
    base_dir = File.expand_path('../..', File.dirname(__FILE__))
    
    # ProjectFinderを使用してパスを設定
    @paths = ProjectFinder.setup_paths(base_dir, @project_file_path)
    @xcode_manager = XcodeProjectManager.new(@project_file_path)
  end

  def create_missing_directories
    puts "Checking and creating missing directories..."
    
    directories_to_create = []
    
    # 各ディレクトリの存在をチェック
    check_and_add_directory(@paths.view_path, "View", directories_to_create)
    check_and_add_directory(@paths.layout_path, "Layouts", directories_to_create)
    check_and_add_directory(@paths.style_path, "Styles", directories_to_create)
    check_and_add_directory(@paths.bindings_path, "Bindings", directories_to_create)
    check_and_add_directory(@paths.core_path, "Core", directories_to_create)
    check_and_add_directory(@paths.ui_path, "UI", directories_to_create)
    check_and_add_directory(@paths.base_path, "Base", directories_to_create)
    
    if directories_to_create.empty?
      puts "All directories already exist. No action needed."
    else
      # ディレクトリを作成
      directories_to_create.each do |dir_info|
        FileUtils.mkdir_p(dir_info[:path])
        puts "Created directory: #{dir_info[:path]}"
      end
      
      # Xcodeプロジェクトに追加
      add_directories_to_xcode_project(directories_to_create)
      
      # Coreファイルの生成
      create_core_files_if_needed(directories_to_create)
    end
    
    # SwiftJsonUIパッケージを追加
    add_swiftjsonui_package
    
    # HotLoader機能をAppDelegateに追加
    add_hotloader_to_app_delegate
    
    # HotLoad Build Phase設定
    setup_hotload_build_phase
    
    # Info.plistからStoryBoard参照を削除
    remove_storyboard_from_info_plist
    
    # membershipExceptionsを設定
    setup_membership_exceptions
    
    puts "Directory setup completed successfully!"
  end

  private

  def check_and_add_directory(path, name, directories_to_create)
    unless Dir.exist?(path)
      directories_to_create << {
        path: path,
        name: name,
        relative_path: get_relative_path(path)
      }
      puts "  Missing: #{path}"
    else
      puts "  Exists: #{path}"
    end
  end

  def get_relative_path(full_path)
    # プロジェクトルートからの相対パスを取得
    project_root = File.dirname(File.dirname(@project_file_path))
    Pathname.new(full_path).relative_path_from(Pathname.new(project_root)).to_s
  end

  def add_directories_to_xcode_project(directories_to_create)
    return if directories_to_create.empty?
    
    puts "Adding directories to Xcode project..."
    
    safe_pbxproj_operation([], []) do
      directories_to_create.each do |dir_info|
        folder_name = dir_info[:name]
        puts "  Adding #{folder_name} group to Xcode project..."
        @xcode_manager.add_folder_group(folder_name, dir_info[:relative_path])
      end
      puts "Successfully added directories to Xcode project"
    end
  end

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
          /(\/\* Begin XCRemoteSwiftPackageReference section \*\/.*?)(\n\/\* End XCRemoteSwiftPackageReference section \*\/)/m,
          "\\1\n\t\t#{package_ref_uuid} /* XCRemoteSwiftPackageReference \"SwiftJsonUI\" */ = {\n\t\t\tisa = XCRemoteSwiftPackageReference;\n\t\t\trepositoryURL = \"https://github.com/Tai-Kimura/SwiftJsonUI\";\n\t\t\trequirement = {\n\t\t\t\tkind = upToNextMajorVersion;\n\t\t\t\tminimumVersion = 5.3.0;\n\t\t\t};\n\t\t};\\2"
        )
      else
        # 新しいセクションを作成
        content = content.gsub(
          /(\/\* End XCConfigurationList section \*\/)/,
          "\\1\n\n/* Begin XCRemoteSwiftPackageReference section */\n\t\t#{package_ref_uuid} /* XCRemoteSwiftPackageReference \"SwiftJsonUI\" */ = {\n\t\t\tisa = XCRemoteSwiftPackageReference;\n\t\t\trepositoryURL = \"https://github.com/Tai-Kimura/SwiftJsonUI\";\n\t\t\trequirement = {\n\t\t\t\tkind = upToNextMajorVersion;\n\t\t\t\tminimumVersion = 5.3.0;\n\t\t\t};\n\t\t};\n/* End XCRemoteSwiftPackageReference section */"
        )
      end
      
      # XCSwiftPackageProductDependencyセクションを追加
      if content.include?("/* Begin XCSwiftPackageProductDependency section */")
        # 既存のセクションに追加
        content = content.gsub(
          /(\/\* Begin XCSwiftPackageProductDependency section \*\/.*?)(\n\/\* End XCSwiftPackageProductDependency section \*\/)/m,
          "\\1\n\t\t#{package_dependency_uuid} /* SwiftJsonUI */ = {\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = #{package_ref_uuid} /* XCRemoteSwiftPackageReference \"SwiftJsonUI\" */;\n\t\t\tproductName = SwiftJsonUI;\n\t\t};\\2"
        )
      else
        # 新しいセクションを作成
        content = content.gsub(
          /(\/\* End XCRemoteSwiftPackageReference section \*\/)/,
          "\\1\n\n/* Begin XCSwiftPackageProductDependency section */\n\t\t#{package_dependency_uuid} /* SwiftJsonUI */ = {\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = #{package_ref_uuid} /* XCRemoteSwiftPackageReference \"SwiftJsonUI\" */;\n\t\t\tproductName = SwiftJsonUI;\n\t\t};\n/* End XCSwiftPackageProductDependency section */"
        )
      end
      
      # PBXBuildFileセクションを追加
      if content.include?("/* Begin PBXBuildFile section */")
        content = content.gsub(
          /(\/\* Begin PBXBuildFile section \*\/)/,
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
        /(name = #{project_name};\s+packageProductDependencies = \(\s*)(.*?)(\s*\);)/m,
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

  def generate_uuid
    # Xcodeプロジェクトで使用される24桁の16進数UUIDを生成
    (0...24).map { "0123456789ABCDEF"[rand(16)] }.join
  end

  def add_hotloader_to_app_delegate
    require_relative 'app_delegate_setup'
    
    app_delegate_setup = AppDelegateSetup.new(@project_file_path)
    app_delegate_setup.add_hotloader_functionality
  end

  def setup_hotload_build_phase
    require_relative 'hotload_setup'
    
    puts "Setting up HotLoad Build Phase..."
    hotload_setup = HotLoadSetup.new(@project_file_path)
    hotload_setup.setup_hotload_build_phase
  end

  def remove_storyboard_from_info_plist
    puts "Removing StoryBoard references from Info.plist..."
    
    # Info.plistファイルを探す
    project_dir = File.dirname(File.dirname(@project_file_path))
    info_plist_path = find_info_plist_file(project_dir)
    
    if info_plist_path.nil?
      puts "Warning: Could not find Info.plist file. StoryBoard references not removed."
      return
    end

    puts "Updating Info.plist: #{info_plist_path}"
    
    # Info.plistの内容を読み込む
    content = File.read(info_plist_path)
    
    # 既にStoryBoard参照が削除されているかチェック
    unless content.include?("UISceneStoryboardFile")
      puts "StoryBoard references already removed from Info.plist"
      return
    end
    
    # StoryBoard参照を削除
    updated_content = remove_storyboard_references(content)
    
    # ファイルに書き戻す
    File.write(info_plist_path, updated_content)
    puts "StoryBoard references removed from Info.plist successfully"
  end

  def find_info_plist_file(project_dir)
    # プロジェクトディレクトリから再帰的にInfo.plistを検索
    Dir.glob("#{project_dir}/**/Info.plist").first
  end

  def remove_storyboard_references(content)
    # UISceneStoryboardFileキーとその値を削除
    content = content.gsub(/\s*<key>UISceneStoryboardFile<\/key>\s*\n\s*<string>.*?<\/string>\s*\n/, "")
    content
  end

  def create_core_files_if_needed(directories_to_create)
    core_created = directories_to_create.any? { |dir| dir[:name] == "Core" }
    ui_created = directories_to_create.any? { |dir| dir[:name] == "UI" }
    base_created = directories_to_create.any? { |dir| dir[:name] == "Base" }
    
    if core_created || ui_created || base_created
      puts "Creating core files..."
      created_files = []
      
      # UIViewCreator.swift を作成
      if ui_created
        ui_generator = UIViewCreatorGenerator.new(@project_file_path)
        ui_view_creator_path = ui_generator.generate(@paths.ui_path)
        created_files << ui_view_creator_path if ui_view_creator_path
      end
      
      # BaseViewController.swift を作成
      if base_created
        base_vc_generator = BaseViewControllerGenerator.new(@project_file_path)
        base_view_controller_path = base_vc_generator.generate(@paths.base_path)
        created_files << base_view_controller_path if base_view_controller_path
      end
      
      # BaseBinding.swift を作成
      if base_created
        base_binding_generator = BaseBindingGenerator.new(@project_file_path)
        base_binding_path = base_binding_generator.generate(@paths.base_path)
        created_files << base_binding_path if base_binding_path
      end
      
      # BaseCollectionViewCell.swift を作成
      if base_created
        base_cell_generator = BaseCollectionViewCellGenerator.new(@project_file_path)
        base_cell_path = base_cell_generator.generate(@paths.base_path)
        created_files << base_cell_path if base_cell_path
      end
      
      # 作成されたファイルをXcodeプロジェクトに追加
      unless created_files.empty?
        add_core_files_to_xcode_project(created_files)
      end
    end
  end

  def add_core_files_to_xcode_project(file_paths)
    safe_pbxproj_operation([], file_paths) do
      file_paths.each do |file_path|
        file_name = File.basename(file_path)
        
        if file_path.include?("/UI/")
          folder_name = "UI"
        elsif file_path.include?("/Base/")
          folder_name = "Base"
        else
          folder_name = "Core"
        end
        
        # ViewControllerAdderを使用してファイルを追加
        @xcode_manager.add_view_controller_file(file_name, folder_name)
      end
      puts "Added core files to Xcode project"
    end
  end
end

# コマンドライン実行
if __FILE__ == $0
  begin
    # binding_builderディレクトリから検索開始
    binding_builder_dir = File.expand_path("../../", __FILE__)
    project_file_path = ProjectFinder.find_project_file(binding_builder_dir)
    setup = DirectorySetup.new(project_file_path)
    setup.create_missing_directories
  rescue => e
    puts "Error: #{e.message}"
    exit 1
  end
end
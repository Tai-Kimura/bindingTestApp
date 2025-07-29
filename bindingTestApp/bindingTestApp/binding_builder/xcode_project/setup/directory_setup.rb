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
    
    # ライブラリパッケージを追加
    setup_libraries
    
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


  def setup_libraries
    require_relative 'library_setup'
    
    library_setup = LibrarySetup.new(@project_file_path)
    library_setup.setup_libraries
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
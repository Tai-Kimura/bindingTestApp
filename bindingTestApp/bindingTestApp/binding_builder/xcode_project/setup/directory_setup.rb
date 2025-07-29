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
    
    puts "Directory creation completed successfully!"
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


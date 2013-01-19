#
# Author:: John Keiser (<jkeiser@opscode.com>)
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/chef_fs/file_system/base_fs_dir'
require 'chef/chef_fs/file_system/chef_repository_file_system_entry'
require 'chef/chef_fs/file_system/chef_repository_file_system_cookbooks_dir'
require 'chef/chef_fs/file_system/multiplexed_dir'
require 'chef/chef_fs/data_handler/client_data_handler'
require 'chef/chef_fs/data_handler/data_bag_item_data_handler'
require 'chef/chef_fs/data_handler/environment_data_handler'
require 'chef/chef_fs/data_handler/node_data_handler'
require 'chef/chef_fs/data_handler/role_data_handler'
require 'chef/chef_fs/data_handler/user_data_handler'

class Chef
  module ChefFS
    module FileSystem
      class ChefRepositoryFileSystemRootDir < BaseFSDir
        def initialize(child_paths)
          super("", nil)
          @child_paths = child_paths
        end

        attr_reader :child_paths

        def children
          @children ||= child_paths.keys.sort.map { |name| make_child_entry(name) }.select { |child| !child.nil? }
        end

        def can_have_child?(name, is_dir)
          child_paths.has_key?(name) && is_dir
        end

        def create_child(name, file_contents = nil)
          child_paths[name].each do |path|
            Dir.mkdir(path)
          end
          make_child_entry(name)
        end

        def ignore_empty_directories?
          false
        end

        def chefignore
          nil
        end

        def json_class
          nil
        end

        private

        def make_child_entry(name)
          paths = child_paths[name].select do |path|
            File.exists?(path)
          end
          if paths.size == 0
            return nil
          end
          if name == 'cookbooks'
            dirs = paths.map { |path| ChefRepositoryFileSystemCookbooksDir.new(name, self, path) }
          else
            data_handler = case name
              when 'clients'
                Chef::ChefFS::DataHandler::ClientDataHandler.new
              when 'data_bags'
                Chef::ChefFS::DataHandler::DataBagItemDataHandler.new
              when 'environments'
                Chef::ChefFS::DataHandler::EnvironmentDataHandler.new
              when 'nodes'
                Chef::ChefFS::DataHandler::NodeDataHandler.new
              when 'roles'
                Chef::ChefFS::DataHandler::RoleDataHandler.new
              when 'users'
                Chef::ChefFS::DataHandler::UserDataHandler.new
              else
                raise "Unknown top level path #{name}"
              end
            dirs = paths.map { |path| ChefRepositoryFileSystemEntry.new(name, self, path, data_handler) }
          end
          MultiplexedDir.new(dirs)
        end
      end
    end
  end
end

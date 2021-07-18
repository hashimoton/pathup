# coding: utf-8
# System path updator


require "fileutils"
require "optparse"
require "diff/lcs"
require "win32ole"
require "./win32api"


class PathUp

  BASE_DIR = File.expand_path(File.dirname(__FILE__))

  PATH_FILE = "system_path.txt"

  REG_ENV_PATH = "HKEY_LOCAL_MACHINE\\" +
    "SYSTEM\\CurrentControlSet\\Control\\Session Manager\\" +
    "Environment\\Path"

  HWND_BROADCAST = 0xffff
  WM_SETTINGCHANGE = 0x001A
  SMTO_ABORTIFHUNG = 2


  def initialize
    @wsh = WIN32OLE.new('WScript.Shell')
  end

  def opt_parse(argv)
    opts = {}
    
    OptionParser.new do |opt|
      begin
        opt.version = '0.1.0'
        opt.banner = "Update system path with a file\n" + opt.banner
        opt.separator("\nOptions")
        opt.on('    Without any options, show current system path and backup if changed')
        opt.on('-e', '--edit', "edit #{PATH_FILE}") {|v| opts[:edit] = v}
        opt.on('-u', '--update', "update system path with #{PATH_FILE}") {|v| opts[:update] = v}
        opt.parse!(argv)
      rescue => e
        $stderr.puts "ERROR: #{e}.\n#{opt}"
        exit 1
      end
    end
    
    return opts
  end


  def to_env_text(directories)
    return directories.join(";")
  end


  def to_file_text(array)
    return array.join("\n") + "\n"
  end


  def to_array(text)
    return text.gsub(";", "\n").split("\n").delete_if {|d| d.empty?}
  end


  def timestamp
    time = Time.now
    return "#{time.to_i}_"+ time.strftime("%Y%m%d")
  end


  def show_diff(old_dirs, new_dirs, is_verbose = true)
    diffs = Diff::LCS.sdiff(old_dirs, new_dirs)
    added_count = 0
    removed_count = 0
    
    diffs.each do |d|
      if d.old_element == d.new_element
        puts " #{d.old_element}" if is_verbose
      else
        if d.old_element
          removed_count += 1
          puts "-#{d.old_element}" if is_verbose
        end
      
        if d.new_element
          added_count += 1
          puts "+#{d.new_element}" if is_verbose
        end
      end
    end
  
    is_changed = (added_count + removed_count) > 0
  
    if is_changed
      puts "#{added_count} added, #{removed_count} removed."
    else
      puts "Nothing changed."
    end
    
    return is_changed
  end


  def latest_backup(system_path_file)
    backup_files = Dir.glob("#{system_path_file}.*")
    latest = backup_files.sort.last

    return latest
  end


  def read_backup(system_path_file)
    latest_backup_dirs = []
    
    latest_backup_file = latest_backup(system_path_file)

    if !latest_backup_file.nil?
      latest_backup_dirs = to_array(File.read(latest_backup_file))
    end
    
    return latest_backup_dirs
  end


  def write_backup(system_path_file, path_dirs)
    new_backup_file = "#{system_path_file}.#{timestamp()}"
    puts "Backup: #{new_backup_file}"
    File.write(new_backup_file, to_file_text(path_dirs))
  end


  def get_system_path
    current_path = @wsh.RegRead(REG_ENV_PATH)
    current_dirs = to_array(current_path)
    
    return current_dirs
  end


  def set_system_path(new_dirs)
    new_path = to_env_text(new_dirs)
    @wsh.RegWrite(REG_ENV_PATH, new_path, 'REG_EXPAND_SZ')
    
    send_message_timeout = Win32API.new('user32', 'SendMessageTimeout',
      'LLLPLLP', 'L')
    result = 0
    timeout = 5000
    send_message_timeout.call(HWND_BROADCAST, WM_SETTINGCHANGE,
      0, 'Environment', SMTO_ABORTIFHUNG, timeout, result)
  end


  def edit(system_path_file)
    if !File.exists?(system_path_file)
      latest_backup_file = latest_backup(system_path_file)
      FileUtils.copy(latest_backup_file, system_path_file)
    end
    system("start #{system_path_file}")
  end


  def update(system_path_file, current_dirs)
    if !File.exists?(system_path_file)
      $stderr.puts "ERROR: #{system_path_file} not found."
      $stderr.puts "-e to generate from the latest backup."
      exit 1
    end
  
    puts "\nUpdate with #{system_path_file}"
    puts "Check the difference below:\n"
    new_dirs = to_array(File.read(system_path_file))
    is_changed = show_diff(current_dirs, new_dirs)
    
    if is_changed
      begin
        puts "Do you want to update? [y/N]: "
        yesno = gets
        yesno.chomp!.upcase!
      end until (yesno == "Y" || yesno == "N")
      
      if yesno == "Y"
        set_system_path(new_dirs)
        puts "Updated."
      end
    end
  end


  def main(argv)
    opts = opt_parse(argv)
    
    current_dirs = get_system_path()

    system_path_file = BASE_DIR + "/" + PATH_FILE
    latest_backup_dirs = read_backup(system_path_file)

    puts "Checking current system path with the latest backup:"
    is_verbose = !opts[:update]
    is_need_backup = show_diff(latest_backup_dirs, current_dirs, is_verbose)

    if is_need_backup
      write_backup(system_path_file, current_dirs)
    end

    if opts[:edit]
      edit(system_path_file)
    elsif opts[:update]
      update(system_path_file, current_dirs)
    end

  end #main

end # class

###########################

PathUp.new.main(ARGV)

exit 0

# EOF

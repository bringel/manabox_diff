# frozen_string_literal: true

require 'optparse'
require 'csv'
require 'fileutils'

options = {}

parser  = OptionParser.new 
  parser.on('-n [FILE]', '--new_file [FILE]', 'Newest collection file')
  parser.on('-o [FILE]', '--old_file [FILE]', 'File to compare against')
  parser.on('-r', '--[no-]rename', 'Rename the new file with the timestamp')
parser.parse!(into: options)

files_given = options.key?(:new_file)
file_directory = if files_given
                   File.dirname(File.expand_path(options[:new_file]))
                 else
                   File.dirname(File.expand_path(ARGV[0]))
                 end
new_file = if files_given
             File.open(File.expand_path(options[:new_file], file_directory))
           else
             options[:new_file] = ARGV[0]
             File.open(File.expand_path(ARGV[0], file_directory))
           end

old_file = if files_given
             File.open(File.expand_path(options[:old_file], file_directory))
           else
             file_name = Dir.children(file_directory).filter do |fname|
               fname != options[:new_file] && File.extname(fname) == '.csv' && !fname.include?("diff")
             end.max_by do |fname|
               File.open(File.expand_path(fname, file_directory)).mtime
             end
             options[:old_file] = file_name
             File.open(File.expand_path(file_name, file_directory))
           end

if options[:rename]
  updated_new_name = "ManaBox_Collection_#{new_file.mtime.strftime("%FT%R%z")}.csv"
  unless updated_new_name == options[:new_file]
    FileUtils.mv(new_file.path, "#{file_directory}/#{updated_new_name}")
    options[:new_file] = updated_new_name
    new_file = File.open(File.expand_path(updated_new_name, file_directory))
  end

  updated_old_name = "ManaBox_Collection_#{old_file.mtime.strftime("%FT%R%z")}.csv"
  unless updated_old_name == options[:old_file]
    FileUtils.mv(old_file.path, "#{file_directory}/#{updated_old_name}")
    options[:old_file] = updated_old_name
    old_file = File.open(File.expand_path(updated_old_name, file_directory))
  end
end

sort_by_set_and_number = Proc.new do |a, b|
  if a['Set code'] == b['Set code']``
    a['Collector number'] <=> b['Collector number']
  else
    a['Set code'] <=> b['Set code']
  end
end

added = []
removed = []
changed = []

new_collection = CSV.read(new_file, headers: true)
old_collection = CSV.read(old_file, headers: true)

new_collection_enumerator = new_collection.sort(&sort_by_set_and_number).to_enum
old_collection_enumerator = old_collection.sort(&sort_by_set_and_number).to_enum
module EOF; end

def advance(enum)
  begin
    enum.next
  rescue StopIteration
    EOF
  end
end

current_new = advance(new_collection_enumerator)
current_old = advance(old_collection_enumerator)

while current_new != EOF && current_old != EOF
  new_key = current_new.values_at("Set code", "Collector number").join("")
  old_key = current_old.values_at("Set code", "Collector number").join("")

  if old_key == new_key
    if current_new["Quantity"] != current_old["Quantity"]
      changed << { new: current_new, old: current_old }
    end
    current_new = advance(new_collection_enumerator)
    current_old = advance(old_collection_enumerator)
  elsif old_key > new_key 
    # create new, advance new
    added << current_new
    current_new = advance(new_collection_enumerator)
  elsif old_key < new_key
    # delete old, advance old
    removed << current_old
    current_old = advance(old_collection_enumerator)
  end
end

while current_new != EOF
  added << current_new
  current_new = advance(new_collection_enumerator)
end

while current_old != EOF
  removed << current_old
  current_old = advance(old_collection_enumerator)
end

positive_changes, negative_changes = changed.partition do |change|
  (change.dig(:new, "Quantity").to_i - change.dig(:old, "Quantity").to_i) > 0
end

positive_changes.each do |change|
  added << change[:new].to_h.merge(
    {
      "Quantity" => change.dig(:new, "Quantity").to_i - change.dig(:old, "Quantity").to_i
    }
  )
end

negative_changes.each do |change|
  removed << change[:new].to_h.merge(
    {
      "Quantity" => change.dig(:new, "Quantity").to_i - change.dig(:old, "Quantity").to_i
    }
  )
end

output = CSV.generate do |csv|
  csv << new_collection.headers
  added.each do |row|
    csv << row.to_h.values
  end
end

diff_file_path =File.expand_path("diff_#{File.basename(options[:new_file], ".csv")}_#{File.basename(options[:old_file], ".csv")}.csv", file_directory)

File.write(diff_file_path, output)
puts("Wrote diff file to #{diff_file_path}")
puts("The following cards were removed from your collection (Moxfield doesn't have a way to remove cards in an import)")
removed.each do |card|
  puts("#{card["Name"]} - #{card["Set code"]} #{card["Collector number"]} - #{card["Quantity"]}")
end
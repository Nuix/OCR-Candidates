# Menu Title: OCR Processing v1.4


#==================================================================================================
# Required Libraries
#==================================================================================================
require 'set'
require 'java'
require 'fileutils'
require 'tmpdir'
require 'csv'

module JAwt
  include_package "java.awt"
end

module JSwing
  include_package "javax.swing"
  include_package "javax.swing.JDialog"
  include_package "javax.swing.JFrame"
  include_package "javax.swing.JLabel"
  include_package "javax.swing.SwingUtilities"
end

#==================================================================================================
# Classes
#==================================================================================================
class BulkAnnotater

  def initialize(tag)
    @tag = tag
    @item_array = Array.new
    @count = 0
  end

  def add_item(item)
    @item_array << item
    @count += 1
    flush_check
  end

  def add_list(list)
    @item_array += list.to_a
    @count += list.size
    flush_check
  end

  # Return the total number of items that have been added for tagging.
  def count
    @count
  end

  # Return the tag name used by this bulk annotater.
  def tag
    @tag
  end

  # Flush all pending tagging operations.
  def flush
    if ARG_TAG_ITEMS != nil
      if ARG_TAG_ITEMS
        $utilities.bulk_annotater.add_tag(@tag, @item_array)
      else
        $utilities.bulk_annotater.remove_tag(@tag, @item_array)
      end
    end
    @item_array = Array.new
  end

  private

  # Check if the buffer is large enough to flush.
  def flush_check
    flush if @item_array.size >= BATCH_SIZE
  end
end

#==================================================================================================
# Constants
#==================================================================================================

# TAGS
EXPORT_FOR_OCR_TAG = "OCR|Exported For OCR"
IMPORT_OCRED_TAG = "OCR|Imported OCR Document"

# OCR DETECTION TAGS
OCR_MUST = "OCR|Must"
OCR_IMAGES_OVER_500KB = "OCR|Images|Over 500Kb"
OCR_IMAGES_OVER_1MB = "OCR|Images|Over 1MB"
OCR_IMAGES_OVER_5MB = "OCR|Images|Over 5MB"
OCR_AVG_WORDS_01_20 = "OCR|PDF Avg Words Per Page|01 to 20"
OCR_AVG_WORDS_21_40 = "OCR|PDF Avg Words Per Page|21 to 40"
OCR_AVG_WORDS_41_60 = "OCR|PDF Avg Words Per Page|41 to 60"
OCR_AVG_WORDS_61_80 = "OCR|PDF Avg Words Per Page|61 to 80"
OCR_AVG_WORDS_81_100 = "OCR|PDF Avg Words Per Page|41 to 100"
OCR_AVG_WORDS_101 = "OCR|PDF Avg Words Per Page|101 or Greater"

# CONFIG SETTINGS
ROLLOVER_SIZE = 1000
BATCH_SIZE = 1000

# FLAGS
ARG_TAG_ITEMS = true
ARG_HANDLE_EXCLUDED_ITEMS = true
APPEND_OCR_TEXT = false
VERBOSE = false


IDENTIFY_MUST_OCR_FLAG = true
IDENTIFY_IMAGES_OVER_500KB_FLAG = true
IDENTIFY_IMAGES_OVER_1MB_FLAG = true
IDENTIFY_IMAGES_OVER_5MB_FLAG = true
IDENTIFY_PDF_WORD_COUNT_AVERAGE_FLAG = true
	

# OTHER CONSTANTS
OCR_TEXT_SEPARATOR = "\n\nOCR TEXT----------------------\n\n"
MIMETYPE_TO_EXTENSION_HASH = {
    "application/pdf" => "pdf",
    "image/bmp" => "bmp",
    "image/cgm" => "cgm",
    "image/gif" => "gif",
    "image/jp2" => "jp2",
    "image/jpeg" => "jpeg",
    "image/pcx" => "pcx",
    "image/png" => "png",
    "image/svg+xml" => "svg",
    "image/tga" => "tga",
    "image/tiff" => "tiff",
    "image/vnd.apple-quickdraw" => "pct",
    "image/vnd.autocad-dwg" => "dwg",
    "image/vnd.autocad-dxf" => "dxf",
    "image/vnd.corel-draw" => "cdr",
    "image/vnd.corel-ventura" => "img",
    "image/vnd.corel-wordperfect-graphics" => "wpg",
    "image/vnd.justsystem-hanako" => "jsh",
    "image/vnd.lotus-amidraw" => "sdw",
    "image/vnd.lotus-freelance" => "drw",
    "image/vnd.lotus-notes-bitmap" => "dat",
    "image/vnd.micrografx-draw" => "drw",
    "image/vnd.microsoft.icon" => "ico",
    "image/vnd.ms-ani" => "ani",
    "image/vnd.ms-dib" => "dib",
    "image/vnd.ms-emf" => "emf",
    "image/vnd.ms-windows-cursor" => "cur",
    "image/vnd.ms-wmf" => "wmf",
    "image/vnd.wap.wbmp" => "wbmp",
    "image/x-pict" => "pict",
    "image/x-portable-bitmap" => "pbm",
    "image/x-portable-graymap" => "pgm",
    "image/x-portable-pixmap" => "ppm",
    "image/x-raw-bitmap" => "raw",
    "image/x-targa" => "tga",
    "image/x-xbitmap" => "xbm",
    "image/x-xpixmap" => "xpm"
}

#==================================================================================================
# Global Variables
#==================================================================================================

# PROCESSING CHOICES
$ocr_processing_options = ["Identify Documents for OCR", "Export for OCR", "Import OCR'd Documents"]

$md5_exported_set = Set.new
$number_items_no_md5_digest = 0
$number_duplicate_items = 0
$number_unsupported_items = 0
$number_items_failed_export = 0
$number_items_exported = 0
$top_level_export_dir
$processing_option = ""
$ocr_summary = ""

$jdialog_please_wait = JSwing::JDialog.new(nil,"Please Wait")
$jlabel_message = JSwing::JLabel.new("Performing Requested OCR Process...") 

#==================================================================================================
# Short names
#==================================================================================================



#==================================================================================================
# Methods
#==================================================================================================

def thread_safe(&block)
  JSwing::SwingUtilities.invokeAndWait(block)
end

def export_native(item, export_dir, extension)
  if item.digests == nil || item.digests.md5 == nil
    puts "Item with guid #{item.guid} has no MD5 digest, possibly because it is too big?"
    $number_items_no_md5_digest += 1
    return
  end

  if !$md5_exported_set.add?(item.digests.md5)
    # Item with this md5 has already been exported, so skip exporting it.
    puts "Item with guid #{item.guid} skipped as item with same MD5 has already been exported."
    $number_duplicate_items += 1
    item.addTag(EXPORT_FOR_OCR_TAG)
    return
  end

  begin
    $utilities.binary_exporter.export_item(item, File.join(export_dir, item.digests.md5 + "." + extension))
    item.addTag(EXPORT_FOR_OCR_TAG)
    $number_items_exported += 1
  rescue
    puts "ERROR: item with guid #{item.guid} of type: #{item.getType().getName()} could not be exported."
    $number_items_failed_export += 1
  end
end

def export_native_pdf_tiff(export_dir, item)
  extension = MIMETYPE_TO_EXTENSION_HASH[item.getType().getName()]
  if extension != nil
    export_native(item, export_dir, extension)
  else
    puts "Skipping item with guid: " + item.guid + " of type: " + item.getType().getName() + " which is not an image file."
    $number_unsupported_items += 1
  end
end

def choose_dir (title)
  export_dir = nil

  thread_safe do
    chooser = javax.swing.JFileChooser.new
    chooser.dialog_title = title
    chooser.file_selection_mode = JSwing::JFileChooser::DIRECTORIES_ONLY

    if chooser.show_open_dialog(nil) == JSwing::JFileChooser::APPROVE_OPTION
      export_dir = chooser.selected_file.path.gsub('\\', '/')
    end
  end

  return export_dir
end

def import_file(filename)
  md5 = nil
  if File.basename(filename) =~ /^([a-f0-9]+)\./i
    md5 = $1.downcase
  else
    puts "Unable to match MD5 from filename: #{filename}"
    return 0
  end

  item_list = $current_case.search('md5:' + md5)
  puts "Importing data for MD5: #{md5}" if VERBOSE
  if item_list.size == 0
    puts "No items found for md5: " + md5
    return 0
  else
    count = 0
    item_list.each do |item|
      puts "Updating item with GUID: " + item.guid if VERBOSE
      begin
        yield(item)
        item.addTag(IMPORT_OCRED_TAG)
      rescue Exception => e
        puts "Problem updating GUID #{item.guid} for MD5 #{md5} exception: #{e}"
      end
      count += 1
    end
    return count
  end
end

def import_pdf(pdf_file)
  import_file(pdf_file) {|item| $utilities.pdf_print_importer.import_item(item, pdf_file)}
end

def import_text(text_file)
  import_file(text_file) do |item|
    # Note this operation is run for each duplicate matching the MD5.  This ensures that the original text of each
    # item is properly preserved in case they are different for whatever reasons.
    temp_filename = nil
    begin
      update_filename = text_file
      if APPEND_OCR_TEXT
        temp_filename = File.join(Dir.tmpdir, File.basename(text_file))
        File.open(temp_filename, "w") do |temp_file|
          # Write the item's text to the temporary file.
          temp_file.write(item.text)

          # Add a separator between the original text and the OCR text.
          temp_file.write(OCR_TEXT_SEPARATOR)

          # Now copy the OCR file into the temporary file.
          File.open(text_file, "r") do |ocr_file|
            FileUtils.copy_stream(ocr_file, temp_file)
          end
        end

        # Operate on the temporary file below in the modifier code.
        update_filename = temp_filename
      end

      # Update the item's text.
      item.modify { |modifier| modifier.replace_text_from_file(update_filename, "UTF-8") }
    ensure
      # Delete the temporary file if created.
      File.unlink(temp_filename) if temp_filename != nil
    end
  end
end

def time(what, &block)
  start_time = Time.now
  block.call
  end_time = Time.now
  puts "Time for %s: %.3fs" % [what, (end_time - start_time)]
end

def import_steps(dir_file)
  puts "Processing..."
  $currentCase.create_tag(IMPORT_OCRED_TAG)
  # Update the PDFs first if any, before updating the text.  This seems to be necessary
  # with the way $current_case.with_write_access works.  This also traverses through each sub-directory.
  pdf_count = 0
  Dir.glob(File.join(dir_file, "**/*.pdf")) do |file|
    puts "Handling file #{file}"
	$jlabel_message.setText("Performing Requested OCR Process...(Importing #{file})") 
    if file =~ /\/[0-9a-f]{32}\.pdf$/i
      pdf_count += import_pdf(file)
      puts "Loaded #{pdf_count} pdf files..." if pdf_count % 1000 == 0
    else
      puts "Skipped other PDF file: " + file
    end
  end

  # for each text file in the directory and any sub-directories, import the text back in.
  text_count = 0
  $current_case.with_write_access do
    Dir.glob(File.join(dir_file, "**/*.txt")) do |file|
      puts "Handling file #{file}"
      if file =~ /\/[0-9a-f]{32}\.txt$/i
        text_count += import_text(file)
        puts "Loaded #{text_count} text files..." if text_count % 1000 == 0
      else
        puts "Skipped other TXT file: " + file
      end
    end
  end

  puts "#{text_count} text files were imported and #{pdf_count} pdf files were imported."
end

def import_ocr_documents()
	dir_file = choose_dir('Choose the directory containing the updated text/pdf of items.')

	if dir_file == nil
	  JSwing::JOptionPane.showMessageDialog(nil,'Import was not performed as user did not specify a directory')
	  return
	end
		$jdialog_please_wait.setVisible(true)
		time('Import of text/pdf files') do
		import_steps(dir_file)
	end

	$jdialog_please_wait.setVisible(false)
	JSwing::JOptionPane.showMessageDialog(nil, "Import and Update of OCRed documents is complete.  
		Please Close and Re-Open this case for the updates to take effect.")
end

def export_steps ()
  export_dir = choose_dir('Choose the export directory.')
  $jdialog_please_wait.setVisible(true)
  $currentCase.create_tag(EXPORT_FOR_OCR_TAG)

  if export_dir == nil
    return
  else
    # If there are more items to export than ROLLOVER_SIZE, create sub-folders to avoid massive NTFS slowdowns.
    $top_level_export_dir = export_dir
    selected_items = $current_selected_items 
    if selected_items.size > ROLLOVER_SIZE
      export_dir = File.join(export_dir, "0001")
    end

    # Sort selected items by path-position to maximise exporting speed.
    puts "Sorting items by path position..."
    sorted_items = $utilities.item_sorter.sort_items(selected_items) do |item|
      # item.position doesn't seem to sort numerically for earlier versions of the software, so this is a workaround.
      item.position.to_array.map { |e| "%09d" % e }.join('')
    end

    # Records the number of items exported when the current folder was created.
    export_count_current_folder_created = 0

    FileUtils.mkdir_p(export_dir)
    puts "Processing..."
	counti = 0
    sorted_items.each do |item|
      export_native_pdf_tiff(export_dir, item)
	  counti += 1
	  $jlabel_message.setText("Performing Requested OCR Process...(Exporting  #{counti}/#{selected_items.size})")
      # Check if rollover is required.
      if $number_items_exported % ROLLOVER_SIZE == 0 && $number_items_exported != export_count_current_folder_created
        export_dir = File.join(File.dirname(export_dir), "%04d" % (($number_items_exported / ROLLOVER_SIZE)+1))
        export_count_current_folder_created = $number_items_exported
        FileUtils.mkdir_p(export_dir)
      end

      # Output some measure of progress.
      if $number_items_exported % ROLLOVER_SIZE == 0
        puts "#{$number_items_exported} items exported..."
      end
    end

    # Output statistics from the export.
    $ocr_summary = "Exported #{$number_items_exported} items from #{selected_items.size} selected items to #{$top_level_export_dir}.\n"
    $ocr_summary =  $ocr_summary + "#{$number_items_no_md5_digest} items had no MD5 digest\n" if $number_items_no_md5_digest > 0
    $ocr_summary =  $ocr_summary +  "#{$number_duplicate_items} duplicate items were not exported\n" if $number_duplicate_items > 0
    $ocr_summary =  $ocr_summary +  "#{$number_unsupported_items} unsupported items were not exported\n" if $number_unsupported_items > 0
    $ocr_summary =  $ocr_summary +  "#{$number_items_failed_export} items failed to export\n" if $number_items_failed_export > 0
  end
end

def export_for_ocr()
	if $current_selected_items == nil || $current_selected_items.length == 0
	  thread_safe do
		JSwing::JOptionPane.showMessageDialog(nil, "Please select some some items to export.")
	  end
	else
	  export_steps()
	  $jdialog_please_wait.setVisible(false)
	JSwing::JOptionPane.showMessageDialog(nil, "Export of Items for OCRing Completed.\n\nExported #{$number_items_exported} items from #{$current_selected_items.size} selected items to #{$top_level_export_dir}.\n#{$number_items_no_md5_digest} items had no MD5 digest.\n#{$number_duplicate_items} duplicate items were not exported.\n\n#{$ocr_summary}")
	end
end

def select_processing_option()
	option = ""
	thread_safe do
			option = JSwing::JOptionPane.showInputDialog(nil, "Please Select OCR Processing Task To Perform:", 
												 "OCR Processing...", -1, 
												 nil, $ocr_processing_options.to_java(:Object), $ocr_processing_options [0])
	end
	return option
end

def getPageCount(item)
	property_map = item.getProperties
	entryset_prop=property_map.entrySet
	it=entryset_prop.iterator
	pageCount = 1
	while it.hasNext
		prop=it.next
		propKey = prop.getKey
		propVal = prop.getValue
		if propKey == "PDF Page Count"
			pageCount = propVal
		end
		break if  propKey == "PDF Page Count" 	
	end
	return pageCount
end

def search(query)
	query = "has-exclusion:0 (#{query})" if ARG_HANDLE_EXCLUDED_ITEMS
	$currentCase.search(query)
end


# OCR DETECTION SPECIFIC MODULES


def prepare_tags()
	$currentCase.create_tag(OCR_MUST)
	$currentCase.create_tag(OCR_IMAGES_OVER_500KB)
	$currentCase.create_tag(OCR_IMAGES_OVER_1MB)
	$currentCase.create_tag(OCR_IMAGES_OVER_5MB)
	$currentCase.create_tag(OCR_AVG_WORDS_01_20)
	$currentCase.create_tag(OCR_AVG_WORDS_21_40)
	$currentCase.create_tag(OCR_AVG_WORDS_41_60)
	$currentCase.create_tag(OCR_AVG_WORDS_61_80)
	$currentCase.create_tag(OCR_AVG_WORDS_81_100)
	$currentCase.create_tag(OCR_AVG_WORDS_101)
end

def identify_must_ocr()
    puts "Identifying MUST OCR Adobe Acrobat Documents."
	must_ocr_query = "mime-type:application/pdf AND contains-text:0 and encrypted:0"
	item_tag_batch = BulkAnnotater.new(OCR_MUST)
	results = search(must_ocr_query)
	
	results.each do |item|
		item_tag_batch.add_item(item)
	end
	
	puts "Identified: #{item_tag_batch.count}"
	$ocr_summary = "Identified: #{item_tag_batch.count} Adobe Acrobat Documents which MUST be OCR'd.\n"
	item_tag_batch.flush
end

def identify_pdf_word_count_average()
    puts "Calculating PDF Word Count Averages per page."
	must_ocr_query = "mime-type:application/pdf AND contains-text:1"
	
	item_tag_batch_avg_01_20 = BulkAnnotater.new(OCR_AVG_WORDS_01_20)
	item_tag_batch_avg_21_40 = BulkAnnotater.new(OCR_AVG_WORDS_21_40)
	item_tag_batch_avg_41_60 = BulkAnnotater.new(OCR_AVG_WORDS_41_60)
	item_tag_batch_avg_61_80 = BulkAnnotater.new(OCR_AVG_WORDS_61_80)
	item_tag_batch_avg_81_100 = BulkAnnotater.new(OCR_AVG_WORDS_81_100)
	item_tag_batch_avg_over_100 = BulkAnnotater.new(OCR_AVG_WORDS_101)
	
	results = search(must_ocr_query)
	
	results.each do |item|
		words = item.getTextObject().toString()
		wordcount = words.gsub(/[^-a-zA-Z]/, ' ').split.size
		pagecount = getPageCount(item)
		
		if wordcount/pagecount >= 1 and wordcount/pagecount <= 20
			item_tag_batch_avg_01_20.add_item(item)
		elsif wordcount/pagecount >= 21 and wordcount/pagecount <= 40
			item_tag_batch_avg_21_40.add_item(item)
		elsif wordcount/pagecount >= 41 and wordcount/pagecount <= 60
			item_tag_batch_avg_41_60.add_item(item)
		elsif wordcount/pagecount >= 61 and wordcount/pagecount <= 80
			item_tag_batch_avg_61_80.add_item(item)
		elsif wordcount/pagecount >= 81 and wordcount/pagecount <= 100
			item_tag_batch_avg_81_100.add_item(item)
		elsif wordcount/pagecount > 100
			item_tag_batch_avg_over_100.add_item(item)
		end
	end
	
	puts "Identified OCR_AVG_WORDS_01_20: #{item_tag_batch_avg_01_20.count}"
	$ocr_summary = $ocr_summary  + "Identified: #{item_tag_batch_avg_01_20.count} With an Average word count of 1 to 20 per page.\n"
	
	puts "Identified OCR_AVG_WORDS_21_40: #{item_tag_batch_avg_21_40.count}"
	$ocr_summary = $ocr_summary  + "Identified: #{item_tag_batch_avg_21_40.count} With an Average word count of 21 to 40 per page.\n"
	
	puts "Identified OCR_AVG_WORDS_41_60: #{item_tag_batch_avg_41_60.count}"
	$ocr_summary = $ocr_summary  + "Identified: #{item_tag_batch_avg_41_60.count} With an Average word count of 41 to 60 per page.\n"
	
	puts "Identified OCR_AVG_WORDS_61_80: #{item_tag_batch_avg_61_80.count}"
	$ocr_summary = $ocr_summary  + "Identified: #{item_tag_batch_avg_61_80.count} With an Average word count of 61 to 80 per page.\n"
	
	puts "Identified OCR_AVG_WORDS_81_100: #{item_tag_batch_avg_81_100.count}"
	$ocr_summary = $ocr_summary  + "Identified: #{item_tag_batch_avg_81_100.count} With an Average word count of 81 to 100 per page.\n"
	
	puts "Identified OCR_AVG_WORDS_101: #{item_tag_batch_avg_over_100.count}"
	$ocr_summary = $ocr_summary  + "Identified: #{item_tag_batch_avg_over_100.count} With an Average word count of over 100 per page.\n"
	
	item_tag_batch_avg_01_20.flush
	item_tag_batch_avg_21_40.flush
	item_tag_batch_avg_41_60.flush
	item_tag_batch_avg_61_80.flush
	item_tag_batch_avg_81_100.flush
	item_tag_batch_avg_over_100.flush
end

def identify_images_over_5mb()
    puts "Identifying images over 5MB."
	must_ocr_query = "mime-type:(image/jpeg OR image/png OR image/vnd.ms-emf OR image/bmp OR image/tiff) AND digest-input-size:[5242880 TO 1073740824]"
	item_tag_batch = BulkAnnotater.new(OCR_IMAGES_OVER_5MB)
	results = search(must_ocr_query)
	
	results.each do |item|
		item_tag_batch.add_item(item)
	end
	
	puts "Identified: #{item_tag_batch.count}"
	$ocr_summary = $ocr_summary  + "Identified: #{item_tag_batch.count} Images Over 5 MB in Size which are recommended for OCR.\n"
	item_tag_batch.flush
end

def identify_images_over_1mb()
    puts "Identifying images over 1MB."
	must_ocr_query = "mime-type:(image/jpeg OR image/png OR image/vnd.ms-emf OR image/bmp OR image/tiff) AND digest-input-size:[1048576 TO 1073740824]"
	item_tag_batch = BulkAnnotater.new(OCR_IMAGES_OVER_1MB)
	results = search(must_ocr_query)
	
	results.each do |item|
		item_tag_batch.add_item(item)
	end
	
	puts "Identified: #{item_tag_batch.count}"
	$ocr_summary = $ocr_summary  + "Identified: #{item_tag_batch.count} Images Over 1 MB in Size which are recommended for OCR.\n"
	item_tag_batch.flush
end

def identify_images_over_500kb()
    puts "Identifying images over 500KB."
	must_ocr_query = "mime-type:(image/jpeg OR image/png OR image/vnd.ms-emf OR image/bmp OR image/tiff) AND digest-input-size:[512000 TO 1073740824]"
	item_tag_batch = BulkAnnotater.new(OCR_IMAGES_OVER_500KB)
	results = search(must_ocr_query)
	
	results.each do |item|
		item_tag_batch.add_item(item)
	end
	
	puts "Identified: #{item_tag_batch.count}"
	$ocr_summary = $ocr_summary  + "Identified: #{item_tag_batch.count} Images Over 500 KB in Size which are recommended for OCR.\n"
	item_tag_batch.flush
end

def perform_ocr_detection()

	$jlabel_message.setText("Performing Requested OCR Process...(ID Must OCR Documents)") 
	identify_must_ocr() if IDENTIFY_MUST_OCR_FLAG
	$jlabel_message.setText("Performing Requested OCR Process...(ID 500KB+ Images)")
	identify_images_over_500kb() if IDENTIFY_IMAGES_OVER_500KB_FLAG
	$jlabel_message.setText("Performing Requested OCR Process...(ID 1MB+ Images)")
	identify_images_over_1mb() if IDENTIFY_IMAGES_OVER_1MB_FLAG
	$jlabel_message.setText("Performing Requested OCR Process...(ID 5MB+ Images)")
	identify_images_over_5mb() if IDENTIFY_IMAGES_OVER_5MB_FLAG
	$jlabel_message.setText("Performing Requested OCR Process...(Calculating Word Count Averages)")
	identify_pdf_word_count_average() if IDENTIFY_PDF_WORD_COUNT_AVERAGE_FLAG
	
	$jdialog_please_wait.setVisible(false)
		
	thread_safe do
		JSwing::JOptionPane.showMessageDialog(nil, $ocr_summary)
	end
end

def prepare_please_wait_message()
	$jdialog_please_wait.setAlwaysOnTop(true)
	$jdialog_please_wait.setSize(400,100)
	$jlabel_message.setHorizontalAlignment(JSwing::JLabel::CENTER)
	$jdialog_please_wait.add($jlabel_message)
	$jdialog_please_wait.setLocationRelativeTo(nil)
end


#==================================================================================================
# Main code
#==================================================================================================
prepare_please_wait_message()

$processing_option = select_processing_option()

if $processing_option == "Export for OCR"
	export_for_ocr()
elsif $processing_option == "Import OCR'd Documents"
	import_ocr_documents()
elsif $processing_option == "Identify Documents for OCR"
	$jdialog_please_wait.setVisible(true)
	perform_ocr_detection()
else
	JSwing::JOptionPane.showMessageDialog(nil, "No OCR Processing Option Chosen.")
end
#==================================================================================================
# END Main code
#==================================================================================================
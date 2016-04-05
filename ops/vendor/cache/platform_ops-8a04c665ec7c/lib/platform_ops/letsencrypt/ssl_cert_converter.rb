class SslCertConverter

  def convert_files(file_dir)
    Dir.glob(File.join(file_dir,'*.pem')).each do |file_path|
      original_file_content = File.read(file_path)
      convert_file_content = original_file_content.gsub("\n", '\n')
      File.write(File.join(file_dir, "#{File.basename(file_path)}_converted"), convert_file_content)
    end
  end

end


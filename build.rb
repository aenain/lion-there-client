HOST = "http://localhost:4567"
REWRITE_RULES = {
  stylesheets: ".",
  javascripts: ".",
  images:      ".",
  fonts:       ".", 
}
BUILD_DIRECTORY = "build"

def file_entry(server_path, path:".")
  {
    path: File.join(path, server_path.split("/").last),
    content: fetch_file(server_path)
  }
end

def fetch_file(path)
  `curl #{HOST}/#{path}`
end

def find_assets(content, *types)
  content.scan(/(?<=['"])(\/(?:#{types.flatten.join("|")})\/[^'"]+)(?=['"])/).flatten
end

def rewrite_paths(content, **mapping)
  mapping.each do |type, path|
    content.gsub!(/(?<=['"])\/#{type}\/([^'"]+)(?=['"])/, File.join(path, '\1'))
  end
end

def save_entry(file_entry)
  File.open(File.join(BUILD_DIRECTORY, file_entry[:path]), 'wb') { |f| f.write(file_entry[:content]) }
end

all_files = {
  rewrite: [
    {
      path: "index.html",
      content: fetch_file("/")
    }
  ],
  regular: []
}

html = all_files[:rewrite].first[:content]
stylesheet_paths = find_assets(html, "stylesheets")
stylesheet_paths.each do |path|
  all_files[:rewrite].push(file_entry(path))
end

all_files[:rewrite].each do |file_entry|
  paths = find_assets(file_entry[:content], %w(images fonts javascripts))
  file_entries = paths.map { |p| file_entry(p, path: ".") }
  all_files[:regular].concat(file_entries)

  rewrite_paths(file_entry[:content], **REWRITE_RULES)
  save_entry(file_entry)
end

all_files[:regular].each do |file_entry|
  save_entry(file_entry)
end
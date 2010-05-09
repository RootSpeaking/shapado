desc "Fix all"
task :fixall => [:environment, "fixdb:custom_html", "fixdb:reindex", "fixdb:faq", "fixdb:comment_voteable"] do
end

namespace :fixdb do
  desc "move custom html keys to embedded doc"
  task :custom_html => :environment do
    $stderr.puts "Updating #{Group.count} groups..."

    Group.find_each do |group|
      group.set({"custom_html.question_prompt" => group[:_question_prompt],
                 "custom_html.question_help" => group[:_question_help],
                 "custom_html.head" => group[:_head],
                 "custom_html.footer" => group[:footer],
                 "custom_html.head_tag" => group[:head_tag]})
    end

    modifiers = {}
    %w[_question_prompt _question_help _head footer head_tag].each do |key|
      modifiers[key] = 1
    end
    Group.collection.update({}, {:$unset => modifiers}, :multi => true)
  end

  desc "reindex groups"
  task :reindex => :environment do
    class Group
      def update_timestamps
      end
    end

    $stderr.puts "Reindexing #{Group.count} groups..."
    Group.find_each do |group|
      group._keywords = []
      group.save(:validate => false)
    end
  end

  desc "load faq pages"
  task :faq => :environment do
    Dir.glob(RAILS_ROOT+"/db/fixtures/pages/*.markdown") do |page_path|
      basename = File.basename(page_path, ".markdown")
      title = basename.gsub(/\.(\w\w)/, "").titleize
      language = $1

      body = File.read(page_path)

      puts "Loading: #{title.inspect} [lang=#{language}]"

      Page.find_each({:language => language, :body => "", :slug => "faq", :select => [:_id]}) do |page|
        page.set({:body => body})
      end
    end
  end

  desc "initialize values to become comments as voteable"
  task :comment_voteable => :environment do
    Comment.collection.update({:_type => "Comment"}, {:$set => {:votes_count => 0}},
                                                        :upsert => true,
                                                        :safe => true,
                                                        :multi => true)
  end
end

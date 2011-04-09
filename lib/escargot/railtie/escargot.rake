# desc "Explaining what the task does"
# task :elastic_rails do
#   # Task goes here
# end

namespace :escargot do
  desc "indexes the models"
  task :index, :models, :needs => [:environment, :load_all_models] do |t, args|
    each_indexed_model(args) do |model|
      puts "Indexing #{model}"
      Escargot::LocalIndexing.create_index_for_model(model)
    end
  end

  desc "indexes the models"
  task :distributed_index, :models, :needs => [:environment, :load_all_models] do |t, args|
    each_indexed_model(args) do |model|
      puts "Indexing #{model}"
      Escargot::DistributedIndexing.create_index_for_model(model)
    end
  end

  desc "prunes old index versions for this models"
  task :prune_versions, :models, :needs => [:environment, :load_all_models] do |t, args|
    each_indexed_model(args) do |model|
      Escargot.connection.prune_index_versions(model.index_name)
    end
  end

  # I am not too sure where to put this piece of code, the following addes a module that enables
  # you to query the subclasses of a given class
module Subclasses
  # return a list of the subclasses of a class
  def subclasses(direct = false)
    classes = []
    if direct
      ObjectSpace.each_object(Class) do |c|
        next unless c.superclass == self
        classes << c
      end
    else
      ObjectSpace.each_object(Class) do |c|
        next unless c.ancestors.include?(self) and (c != self)
        classes << c
      end
    end
    classes
  end
end

Object.send(:include, Subclasses)

  task :load_all_models do

    models = MongoMapper::Document.send(:subclasses)
    Dir["#{Rails.root}/app/models/*.rb", "#{Rails.root}/app/models/*/*.rb"].each do |file|
      model = File.basename(file, ".*").classify
      unless models.include?(model)
        require file
      end
      models << model
    end
  end

  private
    def each_indexed_model(args)
      if args[:models]
        models = args[:models].split(",").map{|m| m.classify.constantize}
      else
        models = Escargot.indexed_models
      end
      models.each{|m| yield m}
    end
end

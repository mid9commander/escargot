# Escargot
require 'elasticsearch'
require 'escargot/activerecord_ex'
require 'escargot/elasticsearch_ex'
require 'escargot/local_indexing'
require 'escargot/distributed_indexing'
require 'escargot/queue_backend/base'
require 'escargot/queue_backend/resque'


module Escargot

  def self.setup(config, env, options={})
    @@connection = ElasticSearch.new(config["host"] + ":" + config["port"].to_s, :timeout => "")
  end

  def self.default_setup(config, env, options={})
    @@connection = ElasticSearch.new("localhost:9200")
  end

  def self.connection
    @@connection ||= ElasticSearch.new("localhost:9200")
  end

  def self.register_model(model)
    #commenting out the following line because not every underlying DB is table driven. -- Han Qiu
    #    return unless model.table_exists?
    @indexed_models ||= []
    @indexed_models.delete(model) if @indexed_models.include?(model)
    @indexed_models << model
  end

  def self.indexed_models
    @indexed_models || []
  end

  def self.queue_backend
    @queue ||= Escargot::QueueBackend::Rescue.new
  end

  def self.flush_all_indexed_models
    @indexed_models = []
  end

  # search_hits returns a raw ElasticSearch::Api::Hits object for the search results
  # see #search for the valid options
  def self.search_hits(query, options = {}, call_by_instance_method = false)
    unless call_by_instance_method
      if (options[:classes])
        models = Array(options[:classes])
      else
        register_all_models
        models = @indexed_models
      end
      options = options.merge({:index => models.map(&:index_name).join(',')})
    end

    if query.kind_of?(Hash)
      query = {:query => query}
    end
    Escargot.connection.search(query, options)
  end

  # search returns a will_paginate collection of ActiveRecord objects for the search results
  #
  # see ElasticSearch::Api::Index#search for the full list of valid options
  #
  # note that the collection may include nils if ElasticSearch returns a result hit for a
  # record that has been deleted on the database
  def self.search(query, options = {}, call_by_instance_method = false)
    hits = Escargot.search_hits(query, options, call_by_instance_method)
    hits_ar = hits.map{|hit| hit.to_activerecord}
    results = WillPaginate::Collection.new(hits.current_page, hits.per_page, hits.total_entries)
    results.replace(hits_ar)
    results
  end

  # counts the number of results for this query.
  def self.search_count(query = "*", options = {}, call_by_instance_method = false)
    unless call_by_instance_method
      if (options[:classes])
        models = Array(options[:classes])
      else
        register_all_models
        models = @indexed_models
      end
      options = options.merge({:index => models.map(&:index_name).join(',')})
    end
    Escargot.connection.count(query, options)
  end

  private
    def self.register_all_models
      models = []
      # Search all Models in the application Rails
      Dir[File.join("#{RAILS_ROOT}/app/models".split(/\\/), "**", "*.rb")].each do |file|
        model = file.gsub(/#{RAILS_ROOT}\/app\/models\/(.*?)\.rb/,'\1').classify.constantize
        unless models.include?(model)
          require file
        end
        models << model
      end
    end


end

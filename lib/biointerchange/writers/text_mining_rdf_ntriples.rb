require 'rdf'
require 'rdf/ntriples'

module BioInterchange::TextMining

class RDFWriter < BioInterchange::Writer

  # Creates a new instance of a RDFWriter that will use the provided output stream to serialize RDF.
  #
  # +ostream+:: instance of an IO class or derivative that is used for RDF serialization
  def initialize(ostream)
    raise ArgumentError, 'The output stream is not an instance of IO or its subclasses.' unless ostream.kind_of?(IO)
    @ostream = ostream
  end

  # Serializes a model as RDF.
  #
  # +model+:: a generic representation of input data
  def serialize(model)
    if model.instance_of?(BioInterchange::TextMining::Document) then
      serialize_document(model)
    else
      raise ArgumentError, 'The provided model cannot be serialized at the moment. ' +
                           'Supported classes are BioInterchange::TextMining::Document (and that\'s it for now).'
    end
  end

private

  # Generates an URI for a given process and its contents.
  #
  # +process+:: process instance
  # +kind+:: kind of the URI that should be generated, for example, whether the URI should represent the name, date, etc.
  def process_uri(process, kind)
    base_uri = 'biointerchange://textmining/process'
    case kind
    when :process
      RDF::URI.new("#{base_uri}/self/#{process.uri.sub(/^.*?:\/\//, '')}")
    when :name
      RDF::URI.new("#{base_uri}/name/#{process.uri.sub(/^.*?:\/\//, '')}")
    when :uri
      RDF::URI.new("#{base_uri}/uri/#{process.uri.sub(/^.*?:\/\//, '')}")
    when :date
      RDF::URI.new("#{base_uri}/date/#{process.uri.sub(/^.*?:\/\//, '')}")
    else
      raise "There is no implementation for serializing a process as #{kind}."
    end
  end

  # Serializes RDF for a textual document representation using the Semanticsciene Integrated Ontology
  # (http://code.google.com/p/semanticscience/wiki/SIO).
  #
  # +model+:: an instance of +BioInterchange::TextMining::Document+
  def serialize_document(model)
    graph = RDF::Graph.new
    document_uri = RDF::URI.new(model.uri)
    graph.insert(RDF::Statement.new(document_uri, RDF.type, RDF::URI.new('http://semanticscience.org/resource/SIO_000148')))
    model.contents.each { |content|
      graph.insert(serialize_content(graph, document_uri, content))
    }
    RDF::NTriples::Writer.dump(graph, @ostream)
  end

  # 
  #
  #
  def serialize_content(graph, document_uri, content)
    content_uri = RDF::URI.new(content.uri)
    graph.insert(RDF::Statement.new(document_uri, RDF::URI.new('http://semanticscience.org/resource/SIO_000068'), content_uri))
    serialize_process(graph, document_uri, content_uri, content.process) if content.process
  end

  #
  #
  #
  def serialize_process(graph, document_uri, content_uri, process)
    process_uri = process_uri(process, :process)
    graph.insert(RDF::Statement.new(content_uri, RDF::URI.new('http://semanticscience.org/resource/SIO_000068'), process_uri))
    # If this is an email address, then create a FOAF representation, otherwise, do something else:
    unless process_uri.to_s.match(/^[a-z]:\/\//i) then
      graph.insert(RDF::Statement.new(process_uri, RDF.type, RDF::FOAF.Person))
      graph.insert(RDF::Statement.new(process_uri, RDF::FOAF.name, RDF::Literal.new(process.name)))
      graph.insert(RDF::Statement.new(process_uri, RDF::FOAF.name, RDF::URI.new(process.uri)))
    else
      graph.insert(RDF::Statement.new(process_uri, RDF.type, RDF::URI.new('http://semanticscience.org/resource/SIO_000006')))
      graph.insert(RDF::Statement.new(process_uri, RDF::URI.new('http://semanticscience.org/resource/SIO_000068'), serialize_process_name(graph, document_uri, content_uri, process_uri, process)))
      graph.insert(RDF::Statement.new(process_uri, RDF::URI.new('http://semanticscience.org/resource/SIO_000068'), serialize_process_uri(graph, document_uri, content_uri, process_uri, process)))
      graph.insert(RDF::Statement.new(process_uri, RDF::URI.new('http://semanticscience.org/resource/SIO_000068'), serialize_process_date(graph, document_uri, content_uri, process_uri, process)))
    end
  end

  #
  #
  #
  def serialize_process_name(graph, document_uri, content_uri, process_uri, process)
    kind_uri = process_uri(process, :name)
    graph.insert(process_name_uri, RDF.type, RDF::URI.new('http://semanticscience.org/resource/SIO_000116'))
  end

  #
  #
  #
  def serialize_process_uri(graph, document_uri, content_uri, process_uri, process)
    kind_uri = process_uri(process, :uri)
    graph.insert(process_name_uri, RDF.type, RDF::URI.new('http://semanticscience.org/resource/SIO_000097'))
  end

  #
  #
  #
  def serialize_process_date(graph, document_uri, content_uri, process_uri, process)
    kind_uri = process_uri(process, :date)
    graph.insert(process_name_uri, RDF::DC.date, RDF::Literal.new(process.date))
  end

end

end

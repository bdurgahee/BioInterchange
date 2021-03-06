require 'rdf'
require 'rdf/ntriples'
require 'date'

module BioInterchange::Genomics

# Serializes GFF3 and GVF models.
#
# Inputs:
# - biointerchange.gff3
# - biointerchange.gvf
#
# Outputs:
# - rdf.biointerchange.gff3
# - rdf.biointerchange.gvf
class RDFWriter

  # Creates a new instance of a RDFWriter that will use the provided output stream to serialize RDF.
  #
  # +ostream+:: instance of an IO class or derivative that is used for RDF serialization
  def initialize(ostream)
    raise BioInterchange::Exceptions::ImplementationWriterError, 'The output stream is not an instance of IO or its subclasses.' unless ostream.kind_of?(IO)
    @ostream = ostream
  end

  # Serialize a model as RDF.
  #
  # +model+:: a generic representation of input data that is derived from BioInterchange::Genomics::GFF3FeatureSet
  def serialize(model)
    if model.instance_of?(BioInterchange::Genomics::GFF3FeatureSet) then
      @base = BioInterchange::GFF3O
      serialize_model(model)
    elsif model.instance_of?(BioInterchange::Genomics::GVFFeatureSet) then
      @base = BioInterchange::GVF1O
      serialize_model(model)
    else
      raise BioInterchange::Exceptions::ImplementationWriterError, 'The provided model cannot be serialized. ' +
                           'This writer supports serialization for BioInterchange::Genomics::GFF3FeatureSet and '
                           'BioInterchange::Genomics::GVFFeatureSet.'
    end
  end

protected

  # Serializes RDF for a feature set representation.
  #
  # +model+:: an instance of +BioInterchange::Genomics::GFF3FeatureSet+
  def serialize_model(model)
    graph = RDF::Graph.new
    graph.fast_ostream(@ostream) if BioInterchange::skip_rdf_graph
    set_uri = RDF::URI.new(model.uri)
    graph.insert(RDF::Statement.new(set_uri, RDF.type, @base.Set))
    model.pragmas.each { |pragma_name|
      serialize_pragma(graph, set_uri, model.pragma(pragma_name))
    }
    model.contents.each { |feature|
      serialize_feature(graph, set_uri, feature)
    }
    RDF::NTriples::Writer.dump(graph, @ostream)
    # TODO Figure out why the following is very slow. Use with 'rdf-raptor'.
    # RDF::RDFXML::Writer.dump(graph, @ostream)
  end

  # Serializes pragmas for a given feature set URI.
  # +graph+:: RDF graph to which the pragmas are added
  # +set_uri+:: the feature set URI to which the pragmas belong to
  # +pragma+:: an object representing a pragma statement
  def serialize_pragma(graph, set_uri, pragma)
    if pragma.kind_of?(Hash) then
      if pragma.has_key?('gff-version') and @base == BioInterchange::GFF3O then
        graph.insert(RDF::Statement.new(set_uri, @base.version, RDF::Literal.new(pragma['gff-version'], :datatype => RDF::XSD.float )))
      elsif pragma.has_key?('gff-version') and @base == BioInterchange::GVF1O then
        graph.insert(RDF::Statement.new(set_uri, @base.gff_version, RDF::Literal.new(pragma['gff-version'], :datatype => RDF::XSD.float )))
      elsif pragma.has_key?('gvf-version') and @base == BioInterchange::GVF1O then
        graph.insert(RDF::Statement.new(set_uri, @base.gvf_version, RDF::Literal.new(pragma['gvf-version'], :datatype => RDF::XSD.float )))
      end
    else
      # TODO
    end
  end

  # Serializes a +GFF3Feature+ object for a given feature set URI.
  #
  # +graph+:: RDF graph to which the feature is added
  # +set_uri+:: the feature set URI to which the feature belongs to
  # +feature+:: a +GFF3Feature+ instance
  def serialize_feature(graph, set_uri, feature)
    # TODO Make sure there is only one value in the 'ID' list.
    feature_uri = RDF::URI.new("#{set_uri.to_s}/feature/#{feature.sequence_id},#{feature.source},#{feature.type.to_s.sub(/^[^:]+:\/\//, '')},#{feature.start_coordinate},#{feature.end_coordinate},#{feature.strand},#{feature.phase}") unless feature.attributes.has_key?('ID')
    feature_uri = RDF::URI.new("#{set_uri.to_s}/feature/#{feature.attributes['ID'][0]}") if feature.attributes.has_key?('ID')
    feature_properties = @base.feature_properties.select { |uri| @base.is_datatype_property?(uri) }[0]
    graph.insert(RDF::Statement.new(set_uri, @base.contains, feature_uri))
    graph.insert(RDF::Statement.new(feature_uri, RDF.type, @base.Feature))
    graph.insert(RDF::Statement.new(feature_uri, @base.with_parent([ @base.seqid ].flatten, feature_properties)[0], RDF::Literal.new(feature.sequence_id)))
    graph.insert(RDF::Statement.new(feature_uri, @base.source, RDF::Literal.new(feature.source)))
    graph.insert(RDF::Statement.new(feature_uri, @base.type, RDF::Literal.new(feature.type)))
    graph.insert(RDF::Statement.new(feature_uri, @base.with_parent(@base.start, feature_properties)[0], RDF::Literal.new(feature.start_coordinate)))
    graph.insert(RDF::Statement.new(feature_uri, @base.with_parent(@base.end, feature_properties)[0], RDF::Literal.new(feature.end_coordinate)))
    graph.insert(RDF::Statement.new(feature_uri, @base.score, RDF::Literal.new(feature.score))) if feature.score
    feature_properties = @base.feature_properties.select { |uri| @base.is_object_property?(uri) }[0]
    strand_uri = @base.with_parent(@base.strand, feature_properties)[0]
    case feature.strand
    when BioInterchange::Genomics::GFF3Feature::NOT_STRANDED
      graph.insert(RDF::Statement.new(feature_uri, strand_uri, @base.NotStranded))
    when BioInterchange::Genomics::GFF3Feature::UNKNOWN
      graph.insert(RDF::Statement.new(feature_uri, strand_uri, @base.UnknownStrand))
    when BioInterchange::Genomics::GFF3Feature::POSITIVE
      graph.insert(RDF::Statement.new(feature_uri, strand_uri, @base.Positive))
    when BioInterchange::Genomics::GFF3Feature::NEGATIVE
      graph.insert(RDF::Statement.new(feature_uri, strand_uri, @base.Negative))
    else
      raise ArgumentException, 'Strand of feature is set to an unknown constant.'
    end
    graph.insert(RDF::Statement.new(feature_uri, @base.phase, RDF::Literal.new(feature.phase))) if feature.phase

    serialize_attributes(graph, set_uri, feature_uri, feature.attributes) unless feature.attributes.keys.empty?
  end

  # Serializes the attributes of a feature.
  #
  # +graph+:: RDF graph to which the feature is added
  # +set_uri+:: URI of the set these attributes belong to (implicit due to feature)
  # +feature_uri+:: the feature URI to which the attributes belong to
  # +attribtues+:: a map of tag/value pairs
  def serialize_attributes(graph, set_uri, feature_uri, attributes)
    attributes.each_pair { |tag, list|
      if tag == 'Parent' then
        list.each { |parent_id|
          graph.insert(RDF::Statement.new(feature_uri, @base.parent, RDF::URI.new("#{set_uri.to_s}/feature/#{parent_id}")))
        }
      else
        list.each_index { |index|
          value = list[index]
          attribute_uri = RDF::URI.new("#{feature_uri.to_s}/attribute/#{tag}") if list.size == 1
          attribute_uri = RDF::URI.new("#{feature_uri.to_s}/attribute/#{tag}-#{index + 1}") unless list.size == 1
          graph.insert(RDF::Statement.new(feature_uri, @base.attributes, attribute_uri))
          graph.insert(RDF::Statement.new(attribute_uri, RDF.type, @base.Attribute))
          graph.insert(RDF::Statement.new(attribute_uri, @base.tag, RDF::Literal.new("#{tag}")))
          graph.insert(RDF::Statement.new(attribute_uri, RDF.value, RDF::Literal.new(value)))
        }
      end
    }
  end

end

end


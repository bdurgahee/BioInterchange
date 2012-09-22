module BioInterchange

  # Ontologies (besides the ones from the 'rdf' gem)
  require 'biointerchange/gff3.rb'
  require 'biointerchange/sio.rb'
  require 'biointerchange/sofa.rb'

  # Reader/writer interfaces
  require 'biointerchange/reader.rb'
  require 'biointerchange/writer.rb'

  #
  # TEXT MINING
  #

  # Text mining readers
  require 'biointerchange/readers/text_mining_reader.rb'
  require 'biointerchange/readers/pubannos_json_reader.rb'
  require 'biointerchange/readers/pdfx_xml_reader.rb'

	# Text mining model
	require 'biointerchange/tm/document.rb'
	require 'biointerchange/tm/content.rb'
	require 'biointerchange/tm/process.rb'
	
	# Text mining writers
	
  #
  # GENOMICS
  #

  # GFF3 reader
  require 'biointerchange/readers/gff3_reader.rb'

  # Feature base model
  require 'biointerchange/gff3/feature_set.rb'
  require 'biointerchange/gff3/feature.rb'

  # GFF3 writer
  require 'biointerchange/writers/gff3_rdf_ntriples.rb'
  
  #
  # ACTUAL COMMAND LINE IMPLEMENTATION
  #

  # Option parsing 
	require 'getopt/long'
	include Getopt
	
	opt = Getopt::Long.getopts(
	  ["--name", REQUIRED], #name of resourcce/tool/person
	  ["--name_id", REQUIRED], #uri of resource/tool/person
	  ["--date", REQUIRED], #date of processing/annotation
	  ["--version", REQUIRED], #version number of resource
	  ["--file", "-f", REQUIRED], #file to read, will read from STDIN if not supplied
	  ["--out", "-o", REQUIRED] #output file, will out to STDOUT if not supplied
	)
	
	include BioInterchange::TextMining
	
	raise ArgumentError, 'Require --name and -name_id options to specify source of annotations (e.g., a manual annotators name, or software tool name) and their associated URI (e.g., email address, or webaddress).' unless opt['name'] and opt['name_id']

	
	opt['date'] = nil unless opt['date']
	opt['version'] = nil unless opt['version']
	
	raise ArgumentError, 'Require --file or -f switch to specify file to process into RDF.' unless opt['file']
	
	
	#generate model from file (deserialise)
	reader = nil
	
	if opt['file'].match(/\.json$/)
	  reader = PubannosJsonReader.new(opt['name'], opt['name_id'], opt['date'], Process::UNSPECIFIED, opt['version'])
	elsif opt["file"].match(/\.xml$/)
	  reader = PdfxXmlReader.new(opt['name'], opt['name_id'], opt['date'], Process::UNSPECIFIED, opt['version'])
	else
	  raise ArgumentError, 'Unable to guess file type, please use .json or .xml file extensions.'
	end
	

  model = nil
  if opt["file"]
    model = reader.deserialize(File.new(opt["file"],'r'))
  else
    model = reader.deserialize(STDIN)
  end

  #generate rdf from model (serialise)
  writer = nil
  if opt["out"]
    writer = RDFWriter.new(File.new(opt["out"],'w'))
  else
    writer = RDFWriter.new(STDOUT)
  end
  
  writer.serialize(model)
	


end


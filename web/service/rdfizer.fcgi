#!/usr/bin/ruby

require 'rubygems'
require 'net/http'
require 'uri'
require 'cgi'
require 'fcgi'

# This will be obsolete once BioInterchange has been turned into a gem:
load '../../lib/biointerchange/core.rb'
load '../../lib/biointerchange/gff3.rb'
load '../../lib/biointerchange/sio.rb'
load '../../lib/biointerchange/sofa.rb'
load '../../lib/biointerchange/reader.rb'
load '../../lib/biointerchange/writer.rb'
load '../../lib/biointerchange/textmining/text_mining_reader.rb'
load '../../lib/biointerchange/textmining/pubannos_json_reader.rb'
load '../../lib/biointerchange/textmining/pdfx_xml_reader.rb'
load '../../lib/biointerchange/textmining/text_mining_rdf_ntriples.rb'
load '../../lib/biointerchange/textmining/content.rb'
load '../../lib/biointerchange/textmining/document.rb'
load '../../lib/biointerchange/textmining/process.rb'
load '../../lib/biointerchange/genomics/gff3_feature.rb'
load '../../lib/biointerchange/genomics/gff3_feature_set.rb'
load '../../lib/biointerchange/genomics/gff3_reader.rb'
load '../../lib/biointerchange/genomics/gff3_rdf_ntriples.rb'

input_formats = {}
input_formats['dbcls.catanns.json'] = [ BioInterchange::TextMining::PubannosJsonReader, 'name', 'name_id', 'date', [ Proc.new { |*args| BioInterchange::TextMining::TMReader::determine_process(*args) }, 'name_id' ], 'version' ]
input_formats['uk.ac.man.pdfx'] = [ BioInterchange::TextMining::PdfxXmlReader, 'name', 'name_id', 'date', [ Proc.new { |*args| BioInterchange::TextMining::TMReader::determine_process(*args) }, 'name_id' ], 'version' ]
input_formats['biointerchange.gff3'] = [ BioInterchange::Genomics::GFF3Reader, 'name', 'name_uri', 'date' ]

output_formats = {}
output_formats['rdf.bh12.sio'] = BioInterchange::TextMining::RDFWriter
output_formats['rdf.biointerchange.gff3'] = BioInterchange::Genomics::RDFWriter

FCGI.each { |fcgi|
  request = fcgi.in.read

  fcgi.out.print("Content-Type: text/plain\r\n")
  fcgi.out.print("\r\n")

  begin
    request = JSON.parse(request)
    parameters = JSON.parse(URI.decode(request['parameters']))
    data = URI.decode(request['data'])

    raise ArgumentError, 'An input format must be given in the meta-data using the key "input".' unless parameters['input']
    raise ArgumentError, "Unknown input format \"#{parameters['input']}\"." unless input_formats[parameters['input']]
    raise ArgumentError, 'An output format must be given in the meta-data using the key "output".' unless parameters['output']
    raise ArgumentError, "Unknown output format \"#{parameters['output']}\"." unless output_formats[parameters['output']]

    reader_class, *args = input_formats[parameters['input']]
    reader = reader_class.new(*BioInterchange::get_parameters(parameters, args))
    istream, ostream = IO.pipe
    ostream.print(data)
    ostream.close
    model = reader.deserialize(istream)
    istream, ostream = IO.pipe
    output_formats[parameters['output']].new(ostream).serialize(model)
    ostream.close
    fcgi.out.print(istream.read)
  rescue => e
    fcgi.out.print("#{e.backtrace}\n")
  end
  fcgi.finish
}


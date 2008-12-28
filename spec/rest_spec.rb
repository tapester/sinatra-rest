require 'rubygems'
require 'spec'
require 'sinatra'
require 'sinatra/test/rspec'
require 'lib/rest'
require "rexml/document"
require 'ruby-debug'

#require 'spec/person'


class Person
  attr_accessor :id
  attr_accessor :name

  def initialize(*args)
    puts "new #{args.inspect}"
    if args.size == 0
      @id = nil
      @name = nil
    elsif args.size == 2
      @id = args[0].to_i
      @name = args[1]
    else args.size == 1
      update_attributes(args[0])
    end
  end

  def save
    puts "save #{@id}"
    @@people << self
    self.id = @@people.size
  end

  def update_attributes(hash)
    puts "update_attributes #{hash.inspect}"
    unless hash.empty?
      @id = hash['id'].to_i if hash.include?('id')
      @name = hash['name'] if hash.include?('name')
    end
  end

  def self.delete(id)
    @@people.delete_if {|person| person.id == id.to_i}
  end

  @@people = nil

  def self.all
    puts 'all'
    return @@people
  end

  def self.first(id)
    puts "first(#{id})"
    all.find {|f| f.id == id.to_i}
  end

  def self.reset!
    puts 'reset!'
    @@people = [
      Person.new(1, 'one'),
      Person.new(2, 'two'),
      Person.new(3, 'three')
    ]
  end
end

class SomePerson
end

module MyModule
  class ModulePerson
  end
end


def doc(xml)
  REXML::Document.new(xml.gsub(/>\s+</, '><').strip)
end


def response_should_be(status, body)
  @response.status.should == status
  doc(@response.body).to_s.should == body
end

def model_should_be(size)
  Person.all.size.should == size
end

describe Sinatra::REST do

  describe 'as code generator' do
    it "should conjugate a simple model name" do
      Sinatra::REST.conjugate(Person).should eql(%w(Person person people))
    end

    it "should conjugate a model name in camel cases" do
      Sinatra::REST.conjugate(SomePerson).should eql(%w(SomePerson some_person some_people))
    end

    it "should conjugate a model name inside a module" do
      Sinatra::REST.conjugate(MyModule::ModulePerson).should eql(%w(ModulePerson module_person module_people))
    end
  end


  describe 'as url generator' do

    it 'should add url_for helper methods' do
      rest Person

      methods = Sinatra::EventContext.instance_methods.grep /^url_for_people_/
      methods.size.should == 7

      response_mock = mock "Response"
      response_mock.should_receive(:"body=").with(nil).and_return(nil)
      context = Sinatra::EventContext.new(nil, response_mock, nil)

      @person = Person.new
      @person.id = 99

      context.url_for_people_index.should == '/people'
      context.url_for_people_new.should == '/people/new'
      context.url_for_people_create.should == '/people'
      context.url_for_people_show(@person).should == '/people/99'
      context.url_for_people_edit(@person).should == '/people/99/edit'
      context.url_for_people_update(@person).should == '/people/99'
      context.url_for_people_destroy(@person).should == '/people/99'
    end

  end


  describe 'as route generator' do

    before(:each) do
      Sinatra.application = nil
      @app = Sinatra.application
      @app.events.clear
    end

    it 'should add restful routes for a model' do
      rest Person
      events = Sinatra.application.events

      events[:get].size.should be(4)
      events[:get][0].path.should == '/people'
      events[:get][1].path.should == '/people/new'
      events[:get][2].path.should == '/people/:id'
      events[:get][3].path.should == '/people/:id/edit'

      events[:post].size.should be(1)
      events[:post][0].path.should == '/people'

      events[:put].size.should be(1)
      events[:put][0].path.should == '/people/:id'

      events[:delete].size.should be(1)
      events[:delete][0].path.should == '/people/:id'
    end

  end


  describe 'as restful service' do

    before(:each) do
      Sinatra.application = nil
      @app = Sinatra.application
      @app.configure :test do
        set :views, File.join(File.dirname(__FILE__), "views")
      end

      Person.reset!
      rest Person, :renderer => 'erb'
    end
#
#    # index GET /models
#    it 'should list all people on index by their id' do
#      get_it '/people'
#      body.gsub(/>\s+</, '><').strip.should == '<people><person><id>1</id></person><person><id>2</id></person><person><id>3</id></person></people>'
#    end

#    # new GET /models/new
#    it 'should prepare an empty item on new' do
#      get_it '/people/new'
#      body.gsub(/>\s+</, '><').strip.should == '<person><id></id><name></name></person>'
#    end
#
#    # create POST /models
#    it 'should create an item on post' do
#      post_it '/people', '<person><name></name></person>', :content_type => 'application/xml'
#      doc(body).to_s.should == ''
#    end
#
#    # show GET /models/1
#    it 'should show an item on get' do
#      get_it '/people/1'
#      body.gsub(/>\s+</, '><').strip.should == '<person><id>1</id><name>one</name></person>'
#    end

#    # edit GET /models/1/edit
#    it 'should get the item for editing' do
#      get_it '/people/1/edit'
#      body.gsub(/>\s+</, '><').strip.should == '<person><id>1</id><name>one</name></person>'
#    end

#    # update PUT /models/1
#    it 'should update an item on put' do
#      post_it '/people', '<person><name></name></person>', :content_type => 'application/xml'
#      doc(body).to_s.should == ''
#    end

#    # destroy DELETE /models/1
#    it 'should destroy an item on delete' do
#      post_it '/people', '<person><id>1</id></person>', :content_type => 'application/xml'
#      doc(body).to_s.should == ''
#    end

  #######################

    it 'list all persons' do
      get_it '/people'
      response_should_be 200, '<people><person><id>1</id></person><person><id>2</id></person><person><id>3</id></person></people>'
      model_should_be 3
    end

    it 'read all persons' do
      get_it '/people'

      el_people = doc(body).elements.to_a("*/person/id")
      el_people.size.should == 3
      model_should_be 3

      get_it "/people/#{el_people[0].text}"
      response_should_be 200, '<person><id>1</id><name>one</name></person>'
      model_should_be 3

      get_it "/people/#{el_people[1].text}"
      response_should_be 200, '<person><id>2</id><name>two</name></person>'
      model_should_be 3

      get_it "/people/#{el_people[2].text}"
      response_should_be 200, '<person><id>3</id><name>three</name></person>'
      model_should_be 3      
    end

    it 'create a new person' do
      get_it '/people'
      response_should_be 200, '<people><person><id>1</id></person><person><id>2</id></person><person><id>3</id></person></people>'
      model_should_be 3

      get_it '/people/new'
      response_should_be 200, '<person><id/><name/></person>'
      model_should_be 3

      post_it '/people', {:name => 'four'}
      response_should_be 302, 'resource created'
      model_should_be 4

      get_it '/people'
      response_should_be 200, '<people><person><id>1</id></person><person><id>2</id></person><person><id>3</id></person><person><id>4</id></person></people>'
      model_should_be 4
    end

    it 'update a person' do
      get_it '/people/2'
      response_should_be 200, '<person><id>2</id><name>two</name></person>'
      model_should_be 3

      put_it '/people/2', {:name => 'tomorrow'}
      response_should_be 302, 'resource updated'
      model_should_be 3

      get_it '/people/2'
      response_should_be 200, '<person><id>2</id><name>tomorrow</name></person>'
      model_should_be 3
    end

    it 'delete a person' do
      get_it '/people'
      response_should_be 200, '<people><person><id>1</id></person><person><id>2</id></person><person><id>3</id></person></people>'
      model_should_be 3

      delete_it '/people/2'
      response_should_be 302, 'resource deleted'
      model_should_be 2

      get_it '/people'
      response_should_be 200, '<people><person><id>1</id></person><person><id>3</id></person></people>'
      model_should_be 2

      get_it '/people/2'
      response_should_be 404, 'resource not found'
      model_should_be 2
    end

  end

#    it 'should service restful clients' do
#      require 'rest_client'
#      RestClient.get 'http://example.com/person'
#      RestClient.get 'https://user:password@example.com/private/person'
#      RestClient.post 'http://example.com/person', :param1 => 'one', :nested => { :param2 => 'two' }
#      RestClient.delete 'http://example.com/person'
#    end

end


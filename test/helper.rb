require 'rubygems'
require 'test/unit'
require 'fileutils'
require 'rdbi-dbrc'
require 'rdbi/driver/postgresql'

# Tests that can be performed on an empty database
class BasicTest < Test::Unit::TestCase
  def new_database
    RDBI::DBRC.connect(:postgresql_test)
  end

  def role
    RDBI::DBRC.roles[:postgresql_test]
  end
end

# Tests aware of certain pre-existing tables
class DDLTest < BasicTest
  attr_accessor :dbh

  SQL_UP = [
    'SET client_min_messages=error',  # please!
    'CREATE SCHEMA rdbi_test1',
    'CREATE SCHEMA rdbi_test2',
    'SET search_path = rdbi_test1,rdbi_test2',
    'DROP TABLE IF EXISTS foo',
    'DROP TABLE IF EXISTS bar',
    'DROP TABLE IF EXISTS time_test',
    'DROP TABLE IF EXISTS ordinals',
    'create table foo (bar integer)',
    'create table bar (foo varchar, bar integer)',
    'create table time_test (my_date timestamp)',
    'CREATE TABLE ordinals ( id SERIAL PRIMARY KEY, cardinal INTEGER, s VARCHAR )',
    "INSERT INTO ordinals ( cardinal, s ) VALUES ( 1, 'first' )",
    "INSERT INTO ordinals ( cardinal, s ) VALUES ( 2, 'second' )",
    "INSERT INTO ordinals ( cardinal, s ) VALUES ( 3, 'third' )",
  ]

  SQL_DOWN = [
    'SET client_min_messages=error',  # please!
    'DROP SCHEMA rdbi_test2 CASCADE',
    'DROP SCHEMA rdbi_test1 CASCADE',
  ]

  def setup
    @dbh = new_database
    SQL_DOWN.each { |query| @dbh.execute_modification(query) rescue nil }
    SQL_UP.each { |query| dbh.execute_modification(query) }
  end

  def teardown
    SQL_DOWN.each { |query| @dbh.execute_modification(query) }
    @dbh.disconnect if @dbh.connected?
  rescue
    nil
  end
end

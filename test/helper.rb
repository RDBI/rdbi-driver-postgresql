require 'rubygems'
require 'test/unit'
require 'fileutils'
require 'rdbi-dbrc'
require 'rdbi/driver/postgresql'

class Test::Unit::TestCase

  SQL = [
    'DROP TABLE IF EXISTS foo',
    'DROP TABLE IF EXISTS bar',
    'DROP TABLE IF EXISTS time_test',
    'DROP TABLE IF EXISTS time_test2',
    'DROP TABLE IF EXISTS ordinals',
    'create table foo (bar integer)',
    'create table bar (foo varchar, bar integer)',
    'create table time_test (id SERIAL PRIMARY KEY, my_date timestamp)',
    'create table time_test2 (id SERIAL PRIMARY KEY, ts TIMESTAMP(0) WITHOUT TIME ZONE)',
    'CREATE TABLE ordinals ( id SERIAL PRIMARY KEY, cardinal INTEGER, s VARCHAR )',
    "INSERT INTO ordinals ( cardinal, s ) VALUES ( 1, 'first' )",
    "INSERT INTO ordinals ( cardinal, s ) VALUES ( 2, 'second' )",
    "INSERT INTO ordinals ( cardinal, s ) VALUES ( 3, 'third' )",
  ]

  def new_database
    RDBI::DBRC.connect(:postgresql_test)
  end

  def init_database
    dbh = new_database
    SQL.each { |query| dbh.execute_modification(query) }
    return dbh
  end

  def role
    RDBI::DBRC.roles[:postgresql_test]
  end
end

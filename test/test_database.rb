require 'helper'

class TestDatabase < Test::Unit::TestCase

  attr_accessor :dbh

  def teardown
    @dbh.disconnect  if @dbh && @dbh.connected?
  end

  def test_01_connect
    self.dbh = new_database
    assert dbh
    assert_kind_of( RDBI::Driver::PostgreSQL::Database, dbh )
    assert_kind_of( RDBI::Database, dbh )
    assert_equal( dbh.database_name, "rdbi" )
    dbh.disconnect
    assert ! dbh.connected?
  end

  def test_02_ping
    self.dbh = init_database
    assert_kind_of(Numeric, dbh.ping)
    assert_kind_of(Numeric, RDBI.ping(:PostgreSQL, :database => "rdbi"))
    dbh.disconnect

    assert_raises(RDBI::DisconnectedError.new("not connected")) do
      dbh.ping
    end

    # XXX This should still work because it connects. Obviously, testing a
    # downed database is gonna be pretty hard.
    assert_kind_of(Numeric, RDBI.ping(:PostgreSQL, :database => "rdbi"))
  end

  def test_03_execute
    self.dbh = init_database
    res = dbh.execute( "insert into foo (bar) values (?)", 1 )
    assert res
    assert_kind_of( RDBI::Result, res )
    assert_equal( 1, res.affected_count )

    res = dbh.execute( "select * from foo" )
    assert res
    assert_kind_of( RDBI::Result, res )
    assert_equal( [[1]], res.fetch(:all) )

    rows = res.as( :Struct ).fetch( :all )
    row = rows[ 0 ]
    assert_equal( 1, row.bar )

    res = dbh.execute( "select count(*) from foo" )
    assert res
    assert_kind_of( RDBI::Result, res )
    assert_equal( [[1]], res.fetch(:all) )
    row = res.as( :Array ).fetch( :first )
    assert_equal 1, row[ 0 ]

    res = dbh.execute( "SELECT 5" )
    assert res
    assert_kind_of( RDBI::Result, res )
    row = res.as( :Array ).fetch( :first )
    assert_equal 5, row[ 0 ]

    time_str = DateTime.now.strftime( "%Y-%m-%d %H:%M:%S %z" )
    res = dbh.execute( "SELECT 5, TRUE, 'hello', '#{time_str}'::TIMESTAMP" )
    assert res
    assert_kind_of( RDBI::Result, res )
    row = res.fetch( :all )[ 0 ]
    assert_equal 5, row[ 0 ]
    assert_equal true, row[ 1 ]
    assert_equal 'hello', row[ 2 ]
    assert_equal DateTime.parse( time_str ), row[ 3 ]
  end

  def test_04_prepare
    self.dbh = init_database

    sth = dbh.prepare( "insert into foo (bar) values (?)" )
    assert sth
    assert_kind_of( RDBI::Statement, sth )
    assert_respond_to( sth, :execute )

    5.times do
      res = sth.execute( 1 )
      assert_equal( 1, res.affected_count )
    end

    assert_equal( dbh.last_statement.object_id, sth.object_id )

    sth2 = dbh.prepare( "select * from foo" )
    assert sth
    assert_kind_of( RDBI::Statement, sth )
    assert_respond_to( sth, :execute )

    res = sth2.execute
    assert res
    assert_kind_of( RDBI::Result, res )
    assert_equal( [[1]] * 5, res.fetch(:all) )

    sth.execute 1

    res = sth2.execute
    assert res
    assert_kind_of( RDBI::Result, res )
    assert_equal( [[1]] * 6, res.fetch(:all) )

    sth.finish
    sth2.finish
  end

  def test_05_transaction
    self.dbh = init_database

    dbh.transaction do
      assert dbh.in_transaction?
      5.times { dbh.execute( "insert into foo (bar) values (?)", 1 ) }
      dbh.rollback
      assert ! dbh.in_transaction?
    end

    assert ! dbh.in_transaction?

    assert_equal( [], dbh.execute("select * from foo").fetch(:all) )

    dbh.transaction do
      assert dbh.in_transaction?
      5.times { dbh.execute("insert into foo (bar) values (?)", 1) }
      assert_equal( [[1]] * 5, dbh.execute("select * from foo").fetch(:all) )
      dbh.commit
      assert ! dbh.in_transaction?
    end

    assert ! dbh.in_transaction?

    assert_equal( [[1]] * 5, dbh.execute("select * from foo").fetch(:all) )

    dbh.transaction do
      assert dbh.in_transaction?
      assert_raises( RDBI::TransactionError ) do
        dbh.transaction do
        end
      end
    end

    # Not in a transaction

    assert_raises( RDBI::TransactionError ) do
      dbh.rollback
    end

    assert_raises( RDBI::TransactionError ) do
      dbh.commit
    end
  end

  def test_06_preprocess_query
    self.dbh = init_database
    assert_equal(
      "insert into foo (bar) values (1)",
      dbh.preprocess_query( "insert into foo (bar) values (?)", 1 )
    )
  end

  def test_07_schema
    self.dbh = init_database

    dbh.execute( "insert into bar (foo, bar) values (?, ?)", "foo", 1 )
    res = dbh.execute( "select * from bar" )

    assert res
    assert res.schema
    assert_kind_of( RDBI::Schema, res.schema )
    assert res.schema.columns
    res.schema.columns.each { |x| assert_kind_of(RDBI::Column, x) }
  end

  def test_08_datetime
    self.dbh = init_database

    dt = DateTime.now
    dbh.execute( 'insert into time_test (my_date) values (?)', dt )
    dt2 = dbh.execute( 'select * from time_test limit 1' ).fetch(1)[0][0]

    assert_kind_of( DateTime, dt2 )
    assert_equal( dt2.to_s, dt.to_s )

    dbh.execute 'INSERT INTO time_test ( my_date ) VALUES ( NULL )'
    dt3 = "not nil"
    assert_nothing_raised do
      dt3 = dbh.execute( 'SELECT * FROM time_test WHERE my_date IS NULL LIMIT 1' ).fetch( 1 )[0][0]
    end
    assert_nil dt3
  end

  def test_09_basic_schema
    self.dbh = init_database
    assert_respond_to( dbh, :schema )
    schema = dbh.schema.sort_by { |x| x.tables[0].to_s }

    tables = [ :bar, :foo, :ordinals, :time_test ]
    columns = {
      :bar => { :foo => 'character varying'.to_sym, :bar => :integer },
      :foo => { :bar => :integer },
      :time_test => { :my_date => 'timestamp without time zone'.to_sym },
      :ordinals => {
        :id => :integer,
        :cardinal => :integer,
        :s => 'character varying'.to_sym,
      },
    }

    schema.each_with_index do |sch, x|
      assert_kind_of( RDBI::Schema, sch )
      assert_equal( sch.tables[0], tables[x] )

      sch.columns.each do |col|
        assert_kind_of( RDBI::Column, col )
        assert_equal( columns[ tables[x] ][ col.name ], col.type )
      end
    end

    result = dbh.execute( "SELECT id, cardinal FROM ordinals ORDER BY id" )
    rows = result.fetch( :all, RDBI::Result::Driver::Array )
    assert_kind_of( Fixnum, rows[ 0 ][ 0 ] )
    assert_kind_of( Fixnum, rows[ 0 ][ 1 ] )
    rows = result.fetch( :all, RDBI::Result::Driver::Struct )
    assert_kind_of( Fixnum, rows[ 0 ][ :id ] )
    assert_kind_of( Fixnum, rows[ 0 ][ :cardinal ] )
  end

  def test_10_table_schema
    self.dbh = init_database
    assert_respond_to( dbh, :table_schema )

    schema = dbh.table_schema( :foo )
    columns = schema.columns
    assert_equal columns.size, 1
    c = columns[ 0 ]
    assert_equal c.name, :bar
    assert_equal c.type, :integer

    schema = dbh.table_schema( :bar )
    columns = schema.columns
    assert_equal columns.size, 2
    columns.each do |c|
      case c.name
      when :foo
        assert_equal c.type, 'character varying'.to_sym
      when :bar
        assert_equal c.type, :integer
      end
    end

    assert_nil dbh.table_schema( :non_existent )
  end

  def test_11_named_binds
    self.dbh = init_database

    res = dbh.execute("select id, cardinal, s from ordinals where id = ?id", { :id => 1 })
    assert(res)
    assert_equal([[1, 1, 'first']], res.fetch(:all))
   
    res = dbh.execute("select id, cardinal, s from ordinals where id = ?id and cardinal = ?", { :id => 1 }, 1)
    assert(res)
    assert_equal([[1, 1, 'first']], res.fetch(:all))
    
    res = dbh.execute("select id, cardinal, s from ordinals where id = ?id and cardinal = ?", 1, { :id => 1 })
    assert(res)
    assert_equal([[1, 1, 'first']], res.fetch(:all))
  end
end

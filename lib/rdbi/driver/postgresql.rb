require 'rdbi'
require 'epoxy'
require 'methlab'
require 'pg'

class RDBI::Driver::PostgreSQL < RDBI::Driver
  def initialize( *args )
    super( Database, *args )
  end
end

class RDBI::Driver::PostgreSQL < RDBI::Driver
  class Database < RDBI::Database
    extend MethLab

    attr_accessor :pg_conn

    def initialize( *args )
      super( *args )
      self.database_name = @connect_args[:dbname] || @connect_args[:database] || @connect_args[:db]
      @pg_conn = PGconn.new(
        @connect_args[:host] || @connect_args[:hostname],
        @connect_args[:port],
        @connect_args[:options],
        @connect_args[:tty],
        self.database_name,
        @connect_args[:user] || @connect_args[:username],
        @connect_args[:password] || @connect_args[:auth]
      )
    end

    def disconnect
      @pg_conn.close
      super
    end

    def transaction( &block )
      if in_transaction?
        raise RDBI::TransactionError.new( "Already in transaction (not supported by PostgreSQL)" )
      end
      execute 'BEGIN'
      super &block
    end

    def rollback
      if ! in_transaction?
        raise RDBI::TransactionError.new( "Cannot rollback when not in a transaction" )
      end
      execute 'ROLLBACK'
      super
    end
    def commit
      if ! in_transaction?
        raise RDBI::TransactionError.new( "Cannot commit when not in a transaction" )
      end
      execute 'COMMIT'
      super
    end

    def new_statement( query )
      Statement.new( query, self )
    end

    def preprocess_query( query, *binds )
      mutex.synchronize { @last_query = query }

      ep = Epoxy.new( query )
      ep.quote { |x| @pg_conn.escape_string( binds[x].to_s ) }
    end

    def table_schema( table_name, pg_schema = 'public' )
      info_row = execute(
        "SELECT table_type FROM information_schema.tables WHERE table_schema = ? AND table_name = ?",
        pg_schema,
        table_name
      ).fetch( :all )[ 0 ]
      if info_row.nil?
        return nil
      end

      sch = RDBI::Schema.new( [], [] )
      sch.tables << table_name.to_sym

      case info_row[ 0 ]
      when 'BASE TABLE'
        sch.type = :table
      when 'VIEW'
        sch.type = :view
      end

      execute( "SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_schema = ? AND table_name = ?",
        pg_schema,
        table_name
      ).fetch( :all ).each do |row|
        col = RDBI::Column.new
        col.name       = row[0].to_sym
        col.type       = row[1].to_sym
        # TODO: ensure this ruby_type is solid, especially re: dates and times
        col.ruby_type  = row[1].to_sym
        col.nullable   = row[2] == "YES"
        sch.columns << col
      end

      sch
    end

    def schema( pg_schema = 'public' )
      schemata = []
      execute( "SELECT table_name FROM information_schema.tables WHERE table_schema = '#{pg_schema}';" ).fetch( :all ).each do |row|
        schemata << table_schema( row[0], pg_schema )
      end
      schemata
    end

    def ping
      start = Time.now
      rows = begin
               execute("SELECT 1").result_count
             rescue PGError => e
               # XXX Sorry this sucks. PGconn is completely useless without a
               # connection... like asking it if it's connected.
               raise RDBI::DisconnectedError.new(e.message)
             end

      stop = Time.now

      if rows > 0
        stop.to_i - start.to_i
      else
        raise RDBI::DisconnectedError, "disconnected during ping"
      end
    end
  end

  class Statement < RDBI::Statement
    extend MethLab

    attr_accessor :pg_result
    attr_threaded_accessor :stmt_name

    def initialize( query, dbh )
      super( query, dbh )
      @stmt_name = Time.now.to_f.to_s

      ep = Epoxy.new( query )
      @index_map = ep.indexed_binds
      query = ep.quote(@index_map.compact.inject({}) { |x,y| x.merge({ y => nil }) }) do |x| 
        case x
        when Integer
          "$#{x+1}" 
        when Symbol
          num = @index_map.index(x)
          "$#{num+1}"
        end
      end

      @pg_result = dbh.pg_conn.prepare(
        @stmt_name,
        query
      )

      # @input_type_map initialized in superclass
      @output_type_map = RDBI::Type.create_type_hash( RDBI::Type::Out )
      @output_type_map[ :bigint ] = RDBI::Type.filterlist( RDBI::Type::Filters::STR_TO_INT )
    end

    # Returns an Array of things used to fill out the parameters to RDBI::Result.new
    def new_execution( *binds )
      # FIXME move to RDBI::Util or something.
      hashes, binds = binds.partition { |x| x.kind_of?(Hash) }
      hash = hashes.inject({}) { |x, y| x.merge(y) }
      hash.keys.each do |key| 
        if index = @index_map.index(key)
          binds.insert(index, hash[key])
        end
      end

      pg_result = @dbh.pg_conn.exec_prepared( @stmt_name, binds )

      # XXX when did PGresult get so stupid?
      ary = []
      pg_result.num_tuples.times do |i|
        row = []
        pg_result.num_fields.times do |j|
          row[ j ] = pg_result.getvalue( i, j )
        end

        ary.push row
      end
      # XXX end stupid rectifier.

      columns = []
      stub_datetime = DateTime.now.strftime( " %z" )
      (0...pg_result.num_fields).each do |i|
        c = RDBI::Column.new
        c.name = pg_result.fname( i ).to_sym
        c.type = @dbh.pg_conn.exec(
          "SELECT format_type( #{ pg_result.ftype(i) }, #{ pg_result.fmod(i) } )"
        )[ 0 ].values[ 0 ]
        if c.type == 'timestamp without time zone'
          ary.each do |row|
            if row[ i ]
              row[ i ] << stub_datetime
            end
          end
        end
        if c.type.start_with? 'timestamp'
          c.ruby_type = 'timestamp'.to_sym
        else
          c.ruby_type = c.type.to_sym
        end
        columns << c
      end

      this_schema = RDBI::Schema.new
      this_schema.columns = columns

      num_affected = pg_result.cmd_tuples

      pg_result.clear

      [ ary, this_schema, @output_type_map, num_affected ]
    end

    def finish
      @pg_result.clear
      super
    end
  end
end

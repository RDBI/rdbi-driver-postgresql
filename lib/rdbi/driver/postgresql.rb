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

      @preprocess_quoter = proc do |x, named, indexed|
        @pg_conn.escape_string((named[x] || indexed[x]).to_s)
      end
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

    def table_schema( table_name, pg_schema = 'public' )
      info_row = execute(
        "SELECT table_type FROM information_schema.tables WHERE table_schema = ? AND table_name = ?",
        pg_schema,
        table_name
      ).fetch( :first ) rescue nil
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

  class Cursor < RDBI::Cursor
    def initialize(handle, schema)
      super(handle)
      @index = 0
      @stub_datetime = DateTime.now.strftime( " %z" )
      @schema = schema
    end

    def fetch(count=1)
      return [] if last_row?
      a = []
      count.times { a.push(next_row) }
      return a
    end

    def next_row
      val = @handle[@index].values
      @index += 1
      fix_dates(val)
    end

    def result_count
      @handle.num_tuples
    end

    def affected_count
      @handle.cmd_tuples
    end

    def first
      fix_dates(@handle[0].values)
    end

    def last
      fix_dates(@handle[-1].values)
    end

    def rest
      oindex, @index = @index, result_count-1
      fix_dates(fetch_range(oindex, @index))
    end

    def all
      fix_dates(fetch_range(0, result_count-1))
    end

    def [](index)
      fix_dates(@handle[index].values)
    end
    
    def last_row?
      @index == result_count
    end

    def rewind
      @index = 0
    end

    def empty?
      result_count == 0
    end

    def finish
      @handle.clear
    end

    protected

    def fetch_range(start, stop)
      # XXX when did PGresult get so stupid?
      ary = []
      (start..stop).each do |i|
        row = []
        @handle.num_fields.times do |j|
          row[ j ] = @handle.getvalue( i, j )
        end

        ary << row
      end
      # XXX end stupid rectifier.
      
      return ary
    end

    def fix_dates(values)
      index = 0

      values.collect! do |val|
        if val.kind_of?(Array)
          index2 = 0
          val.collect! do |col|
            if !col.nil? and @schema.columns[index2].type == 'timestamp without time zone'
              col << @stub_datetime
            end

            index2 += 1
            col
          end
        else
          if !val.nil? and @schema.columns[index].type == 'timestamp without time zone'
            val << @stub_datetime
          end
        end

        index += 1
        val
      end

      return values
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
      query = ep.quote(Hash[@index_map.compact.zip([])]) do |x|
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

    def new_modification(*binds)
      # FIXME move to RDBI::Util or something.
      hashes, binds = binds.partition { |x| x.kind_of?(Hash) }
      hash = hashes.inject({}) { |x, y| x.merge(y) }
      hash.keys.each do |key| 
        if index = @index_map.index(key)
          binds.insert(index, hash[key])
        end
      end

      pg_result = @dbh.pg_conn.exec_prepared( @stmt_name, binds )
      return pg_result.cmd_tuples
    end

    # Returns an Array of things used to fill out the parameters to RDBI::Result.new
    def new_execution( *binds )
      # FIXME move to RDBI::Util or something.
      hashes, binds = binds.partition { |x| x.kind_of?(Hash) }
      hash = hashes.inject({}, :merge)
      hash.each do |key, value|
        if index = @index_map.index(key)
          binds.insert(index, value)
        end
      end

      pg_result = @dbh.pg_conn.exec_prepared( @stmt_name, binds )

      columns = [] 
      column_query = (0...pg_result.num_fields).map do |x|
        "format_type(#{ pg_result.ftype(x) }, #{ pg_result.fmod(x) }) as col#{x}"
      end.join(", ")

      unless column_query.empty?
        @dbh.pg_conn.exec("select #{column_query}")[0].values.each_with_index do |type, i|
          c = RDBI::Column.new
          c.name = pg_result.fname( i ).to_sym
          c.type = type
          if c.type.start_with? 'timestamp'
            c.ruby_type = 'timestamp'.to_sym
          else
            c.ruby_type = c.type.to_sym
          end
          columns << c
        end
      end

      this_schema = RDBI::Schema.new
      this_schema.columns = columns

      [ Cursor.new(pg_result, this_schema), this_schema, @output_type_map ]
    end

    def finish
      @pg_result.clear
      super
    end
  end
end

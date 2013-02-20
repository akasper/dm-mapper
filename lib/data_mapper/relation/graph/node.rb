module DataMapper
  module Relation
    class Graph

      # Represents a relation in the registry graph
      #
      class Node
        include Enumerable, Equalizer.new(:name)

        # Build a new {Header} instance
        #
        # @param [Symbol] relation_name
        #   the name of the relation
        #
        # @param [Enumerable<Symbol>] attribute_names
        #   the set of attribute names to build the index for
        #
        # @return [Header]
        #
        # @api private
        def self.header(relation_name, attribute_names)
          Header.build(relation_name, attribute_names, join_strategy)
        end

        # The strategy to use for header aliasing when joining headers
        #
        # @return [Header::JoinStrategy::NaturalJoin]
        #
        # @api private
        def self.join_strategy
          Header::JoinStrategy::NaturalJoin
        end

        private_class_method :join_strategy

        # The node name
        #
        # @example
        #
        #   node = Node.new(:name)
        #   node.name
        #
        # @return [Symbol]
        #
        # @api public
        attr_reader :name

        # The underlying relation
        #
        # @return [Veritas::Relation]
        #
        # @api private
        attr_reader :relation

        # The header
        #
        # @return [Header]
        #
        # @api private
        attr_reader :header

        # Initialize a new instance
        #
        # @param [#to_sym] name
        #   the name for the node
        #
        # @param [Veritas::Relation] relation
        #   a veritas relation instance backing this node
        #
        # @param [Header] header
        #   the header to use for this node
        #
        # @return [undefined]
        #
        # @api private
        def initialize(name, relation, header = EMPTY_HASH)
          @name     = name.to_sym
          @relation = relation
          @header   = header
        end

        # Iterate over all tuples in the underlying relation
        #
        # @example
        #
        #   env.relations[:people].each do |tuple|
        #     puts tuple.inspect
        #   end
        #
        # @yield [tuple]
        #
        # @yieldparam [Veritas::Tuple] tuple
        #   each tuple in the relation
        #
        # @return [self, Enumerator]
        #
        # @api public
        def each(&block)
          return to_enum unless block_given?
          @relation.each(&block)
          self
        end

        # Insert +tuples+ into the underlying relation
        #
        # @example
        #
        #   env.relations[:people].insert([ [ 1, 'John' ] ])
        #
        # @param [Enumerable] tuples
        #   an enumerable coercible by {Veritas::Relation.coerce}
        #
        # @return [Node]
        #   a new node backed by a relation containing +tuples+
        #
        # @api public
        def insert(tuples)
          @relation.insert(tuples)
        end
        alias_method :<<, :insert

        # Update +tuples+ in the underlying relation
        #
        # @example
        #
        #   env.relations[:people].update([ [ 1, 'Jane' ] ])
        #
        # @param [Enumerable] tuples
        #   an enumerable coercible by {Veritas::Relation.coerce}
        #
        # @return [Node]
        #   a new node backed by a relation including +tuples+
        #
        # @api public
        def update(key, tuple)
          @relation.update(key, tuple)
        end

        # Delete +tuples+ from the underlying relation
        #
        # @example
        #
        #   env.relations[:people].delete([ [ 1, 'Jane' ] ])
        #
        # @param [Enumerable] tuples
        #   an enumerable coercible by {Veritas::Relation.coerce}
        #
        # @return [Node]
        #   a new node backed by a relation excluding +tuples+
        #
        # @api public
        def delete(tuples)
          @relation.delete(tuples)
        end

        # Renames the relation with the given +aliases+
        #
        # @example
        #
        #   env.relations[:people].rename(:id => :person_id)
        #
        # @param [Hash, Veritas::Relation::Algebra::Rename::Aliases] aliases
        #   the old and new attribute names
        #
        # @return [Node]
        #   a new node with a renamed header
        #
        # @api public
        def rename(aliases)
          renamed_header   = header.rename(aliases)
          renamed_relation = relation.rename(renamed_header.aliases)

          new(name, renamed_relation, renamed_header)
        end

        # Join the underlying relation with +other+
        #
        # @example
        #
        #   people    = env.relations[:people]
        #   addresses = env.relations[:addresses]
        #
        #   joined = people.join(addresses)
        #
        # @param [Node] other
        #   the other node to join
        #
        # @param [Hash<Symbol, Symbol>] join_definition
        #   the left and right attributes to join on
        #
        # @return [Node]
        #   a new node backed by the joined relation
        #
        # @api public
        def join(other, join_definition = EMPTY_HASH)
          joined_header   = header.join(other.header, join_definition)
          joined_relation = join_relation(other, joined_header)

          new(name, joined_relation, joined_header)
        end

        # Restrict the underlying relation
        #
        # @see Veritas::Relation#restrict
        #
        # @example
        #
        #   env.relations[:people].restrict { |r| r.name.eq('John) }
        #
        # @param [Array] args
        #   optional args accepted by {Veritas::Relation#restrict}
        #
        # @yield [context]
        #   optional block to restrict the tuples with
        #
        # @yieldparam [Veritas::Evaluator::Context] context
        #   the context to evaluate the restriction with
        #
        # @yieldreturn [Veritas::Function, #call]
        #   predicate to restrict the tuples with
        #
        # @return [Node]
        #   a new node backed by the restricted relation
        #
        # @api public
        def restrict(*args, &block)
          new(name, relation.restrict(*args, &block), header)
        end

        # Sort the underlying relation by the given +attributes+
        #
        # @example
        #
        #   env.relations[:people].order(:id, :name)
        #
        # @param [*Array] attributes
        #   the attributes to sort by
        #
        # @return [Node]
        #   a new node backed by the sorted relation
        #
        # @api public
        def order(*attributes)
          sorted = relation.sort_by { |r| attributes.map { |attribute| r.send(attribute) } }
          new(name, sorted, header)
        end

        # Sort the underlying relation
        #
        # @example
        #
        #   env.relations[:people].sort_by { |r| [ r.name.desc ] }
        #
        # @param [*Array] args
        #   optional arguments
        #
        # @yield [relation]
        #   optional block to evaluate for directions
        #
        # @yieldparam [Relation] relation
        #   the relation to sort
        #
        # @yieldreturn [Enumerable]
        #   an array of relation attributes
        #
        # @return [Node]
        #   a new node backed by the ordered relation
        #
        # @api public
        def sort_by(*args, &block)
          new(name, relation.sort_by(*args, &block), header)
        end

        # Sort the underlying relation in ascending order
        #
        # TODO think more about this and/or refactor
        #
        # @example
        #
        #   env.relations[:people].ordered
        #
        # @return [Node]
        #   a new node backed by the sorted relation
        #
        # @api public
        def ordered
          new(name, relation.sort_by(relation.header), header)
        end

        private

        def join_relation(other, joined_header)
          relation.join(other.relation.rename(joined_header.aliases))
        end

        def new(*args)
          self.class.new(*args)
        end

      end # class Node

    end # class Graph
  end # module Relation
end # module DataMapper

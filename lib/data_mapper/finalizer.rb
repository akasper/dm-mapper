module DataMapper

  class Finalizer
    attr_reader :relation_registry
    attr_reader :mapper_registry
    attr_reader :connector_builder
    attr_reader :mapper_builder
    attr_reader :mappers

    def self.run
      new(Mapper.descendants.select { |mapper| mapper.model }).run
    end

    def initialize(mappers)
      @mappers           = mappers
      @relation_registry = Mapper.relation_registry
      @mapper_registry   = Mapper.mapper_registry
      @connector_builder = RelationRegistry::RelationConnector::Builder
      @mapper_builder    = Mapper::Builder
    end

    def run
      finalize_relation_registry
      finalize_attribute_mappers
      finalize_relationship_mappers

      self
    end

    private

    def finalize_attribute_mappers
      mappers.each { |mapper| mapper.finalize_attributes }
    end

    def finalize_relation_registry
      mappers.each do |mapper|
        next unless mapper.relation.respond_to?(:name) # FIXME: wtf, why do we have empty relations here?

        relation_registry.new_node(
          mapper.relation.name, mapper.relation_gateway, mapper.aliases)

        mapper.finalize
      end

      mappers.each do |mapper|
        mapper.relationships.each do |relationship|
          connector_builder.call(mapper_registry, relation_registry, relationship)
        end
      end
    end

    def finalize_relationship_mappers
      relation_registry.edges.each do |connector|
        source_mapper_class = mapper_registry[connector.source_model].class
        mapper              = mapper_builder.call(connector, source_mapper_class)

        next if mapper_registry[connector.source_model, connector.relationship]

        mapper_registry.register(mapper, connector.relationship)
      end
    end
  end # class Finalizer
end # module DataMapper

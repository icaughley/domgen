#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

Domgen::TypeDB.config_element('graphql') do
  attr_writer :scalar_type

  def scalar_type
    @scalar_type || (Domgen.error('scalar type not defined'))
  end
end

Domgen::TypeDB.enhance(:text, 'graphql.scalar_type' => 'String')
Domgen::TypeDB.enhance(:integer, 'graphql.scalar_type' => 'Int')
Domgen::TypeDB.enhance(:long, 'graphql.scalar_type' => 'Long')
Domgen::TypeDB.enhance(:real, 'graphql.scalar_type' => 'Float')
Domgen::TypeDB.enhance(:date, 'graphql.scalar_type' => 'Date')
Domgen::TypeDB.enhance(:datetime, 'graphql.scalar_type' => 'DateTime')
Domgen::TypeDB.enhance(:boolean, 'graphql.scalar_type' => 'Boolean')

Domgen::TypeDB.enhance(:point, 'graphql.scalar_type' => 'Point')
Domgen::TypeDB.enhance(:multipoint, 'graphql.scalar_type' => 'MultiPoint')
Domgen::TypeDB.enhance(:linestring, 'graphql.scalar_type' => 'LineString')
Domgen::TypeDB.enhance(:multilinestring, 'graphql.scalar_type' => 'MultiLineString')
Domgen::TypeDB.enhance(:polygon, 'graphql.scalar_type' => 'Polygon')
Domgen::TypeDB.enhance(:multipolygon, 'graphql.scalar_type' => 'MultiPolygon')
Domgen::TypeDB.enhance(:geometry, 'graphql.scalar_type' => 'Geometry')
Domgen::TypeDB.enhance(:pointm, 'graphql.scalar_type' => 'PointM')
Domgen::TypeDB.enhance(:multipointm, 'graphql.scalar_type' => 'MultiPointM')
Domgen::TypeDB.enhance(:linestringm, 'graphql.scalar_type' => 'LineStringM')
Domgen::TypeDB.enhance(:multilinestringm, 'graphql.scalar_type' => 'MultiLineStringM')
Domgen::TypeDB.enhance(:polygonm, 'graphql.scalar_type' => 'PolygonM')
Domgen::TypeDB.enhance(:multipolygonm, 'graphql.scalar_type' => 'MultiPolygonM')

module Domgen
  module Graphql
    module GraphqlCharacteristic
      def type
        Domgen.error("Invoked graphql.type on #{characteristic.qualified_name} when characteristic is a remote_reference") if characteristic.remote_reference?
        if characteristic.reference?
          return characteristic.referenced_entity.graphql.name
        elsif characteristic.enumeration?
          return characteristic.enumeration.graphql.name
        else
          return scalar_type
        end
      end

      attr_writer :scalar_type

      def scalar_type
        return @scalar_type if @scalar_type
        Domgen.error("Invoked graphql.scalar_type on #{characteristic.qualified_name} when characteristic is a non_standard_type") if characteristic.non_standard_type?
        return 'ID' if characteristic.respond_to?(:primary_key?) && characteristic.primary_key?
        Domgen.error("Invoked graphql.scalar_type on #{characteristic.qualified_name} when characteristic is a reference") if characteristic.reference?
        Domgen.error("Invoked graphql.scalar_type on #{characteristic.qualified_name} when characteristic is a remote_reference") if characteristic.remote_reference?
        Domgen.error("Invoked graphql.scalar_type on #{characteristic.qualified_name} when characteristic has no characteristic_type") unless characteristic.characteristic_type
        characteristic.characteristic_type.graphql.scalar_type
      end

      def save_scalar_type
        if @scalar_type
          data_module.repository.graphql.scalar(@scalar_type)
        elsif characteristic.characteristic_type
          data_module.repository.graphql.scalar(characteristic.characteristic_type.graphql.scalar_type)
        end
      end
    end
  end

  FacetManager.facet(:graphql) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::JavaClientServerApplication
      include Domgen::Java::BaseJavaGenerator

      java_artifact :endpoint, :servlet, :server, :graphql, '#{repository.name}GraphQLEndpoint'
      java_artifact :graphqls_servlet, :servlet, :server, :graphql, '#{repository.name}GraphQLSchemaServlet'
      java_artifact :abstract_endpoint, :servlet, :server, :graphql, 'Abstract#{repository.name}GraphQLEndpoint'
      java_artifact :abstract_schema_builder, :servlet, :server, :graphql, 'Abstract#{repository.name}GraphQLSchemaProvider'
      java_artifact :schema_builder, :servlet, :server, :graphql, '#{repository.name}GraphQLSchemaProvider'

      attr_accessor :query_description

      attr_accessor :mutation_description

      attr_accessor :subscription_description

      attr_writer :graphqls_schema_url

      def graphqls_schema_url
        @graphqls_schema_url || "/graphiql/#{Reality::Naming.underscore(repository.name)}.graphqls"
      end

      attr_writer :custom_endpoint

      def custom_endpoint?
        @custom_endpoint.nil? ? false : !!@custom_endpoint
      end

      attr_writer :custom_schema_builder

      def custom_schema_builder?
        @custom_schema_builder.nil? ? false : !!@custom_schema_builder
      end

      attr_writer :api_endpoint

      def api_endpoint
        @api_endpoint || (repository.jaxrs? ? "/#{repository.jaxrs.path}/graphql" : '/api/graphql')
      end

      attr_writer :graphql_keycloak_client

      def graphql_keycloak_client
        @graphql_keycloak_client || (repository.application? && !repository.application.user_experience? ? repository.keycloak.default_client.key : :api)
      end

      attr_writer :graphiql

      def graphiql?
        @graphiql_api_endpoint.nil? ? true : !!@graphiql_api_endpoint
      end

      attr_writer :graphiql_api_endpoint

      def graphiql_api_endpoint
        @graphiql_api_endpoint || '/graphql'
      end

      attr_writer :graphiql_endpoint

      def graphiql_endpoint
        @graphiql_endpoint || '/graphiql'
      end

      attr_writer :graphiql_keycloak_client

      def graphiql_keycloak_client
        @graphiql_keycloak_client || :graphiql
      end

      attr_writer :graphql_schema_name

      def graphql_schema_name
        @graphql_schema_name || repository.name
      end

      attr_writer :context_service_jndi_name

      def context_service_jndi_name
        @context_service_jndi_name || "#{Reality::Naming.camelize(repository.name)}/concurrent/GraphQLContextService"
      end

      def scalars
        @scalars ||= []
      end

      def scalar(scalar)
        s = self.scalars
        s << scalar unless s.include?(scalar)
        s
      end

      def non_standard_scalars
        self.scalars.select {|s| !%w(Byte Short Int Long BigInteger Float BigDecimal String Boolean ID Char).include?(s)}
      end

      def pre_complete
        if self.repository.keycloak?
          if self.graphiql?
            client =
              repository.keycloak.client_by_key?(self.graphiql_keycloak_client) ?
                repository.keycloak.client_by_key(self.graphiql_keycloak_client) :
                repository.keycloak.client(self.graphiql_keycloak_client)

            # This client and endpoint assumes a human is using graphiql to explore the API
            client.protected_url_patterns << "#{self.graphiql_endpoint}/*"
            client.protected_url_patterns << "#{self.graphiql_api_endpoint}/*"
          end

          client =
            repository.keycloak.client_by_key?(self.graphql_keycloak_client) ?
              repository.keycloak.client_by_key(self.graphql_keycloak_client) :
              repository.keycloak.client(self.graphql_keycloak_client)

          client.protected_url_patterns << "#{api_endpoint}/*"
        end
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::ImitJavaPackage

      attr_writer :prefix

      def prefix
        @prefix ||= data_module.name.to_s == data_module.repository.name.to_s ? '' : data_module.name.to_s
      end
    end

    facet.enhance(EnumerationSet) do
      attr_writer :name

      def name
        @name || "#{enumeration.data_module.graphql.prefix}#{enumeration.name}"
      end

      attr_writer :description

      def description
        @description || enumeration.description
      end
    end

    facet.enhance(EnumerationValue) do
      attr_writer :name

      def name
        @name || "#{value.enumeration.data_module.graphql.prefix}#{value.name}"
      end

      attr_writer :description

      def description
        @description || value.description
      end

      attr_accessor :deprecation_reason

      def deprecated?
        !@deprecation_reason.nil?
      end
    end

    facet.enhance(Query) do
      include Domgen::Java::BaseJavaGenerator

      attr_writer :name

      def name
        return @name unless @name.nil?
        type_inset = query.result_entity? ? query.entity.graphql.name : query.struct.graphql.name
        type_inset = Reality::Naming.pluralize(type_inset) if query.multiplicity == :many
        @name || Reality::Naming.camelize("#{query.name_prefix}#{type_inset}#{query.base_name}")
      end

      attr_writer :description

      def description
        @description || query.description
      end

      attr_accessor :deprecation_reason

      def deprecated?
        !@deprecation_reason.nil?
      end

      def pre_complete
        if !query.result_entity? && !query.result_struct?
          # For the time being only queries that return entities or structs are valid
          query.disable_facet(:graphql)
        elsif !query.jpa?
          # queries that have no jpa counterpart can not be automatically loaded so ignore them
          query.disable_facet(:graphql)
        elsif query.query_type != :select && query.dao.jpa? && :requires_new == query.dao.jpa.transaction_type && query.dao.data_module.repository.imit?
          # If we have replicant enabled for project and we have requires_new transaction that modifies data then
          # the current infrastructure will not route it through replicant so we just disable this capability
          query.disable_facet(:graphql)
        elsif query.query_type != :select
          # For now disable all non select querys on DAOs.
          # Eventually we may get around to creating a way to automatically returning values to clients
          # but this will need to wait until it is needed.
        end
      end
    end

    facet.enhance(QueryParameter) do
      include Domgen::Graphql::GraphqlCharacteristic

      attr_writer :name

      def name
        @name || (parameter.reference? ? Reality::Naming.camelize(parameter.referencing_link_name) : Reality::Naming.camelize(parameter.name))
      end

      attr_writer :description

      def description
        @description || parameter.description
      end

      attr_accessor :deprecation_reason

      def deprecated?
        !@deprecation_reason.nil?
      end

      def pre_complete
        save_scalar_type
      end

      protected

      def data_module
        parameter.query.dao.data_module
      end

      def characteristic
        parameter
      end
    end

    facet.enhance(Entity) do
      include Domgen::Java::BaseJavaGenerator

      attr_writer :name

      def name
        @name || "#{entity.data_module.graphql.prefix}#{entity.name}"
      end

      attr_writer :description

      def description
        @description || entity.description
      end
    end

    facet.enhance(Attribute) do
      include Domgen::Java::ImitJavaCharacteristic
      include Domgen::Graphql::GraphqlCharacteristic

      attr_writer :name

      def name
        @name || (attribute.name.to_s.upcase == attribute.name.to_s ? attribute.name.to_s : Reality::Naming.camelize(attribute.name))
      end

      attr_writer :description

      def description
        @description || attribute.description
      end

      attr_accessor :deprecation_reason

      def deprecated?
        !@deprecation_reason.nil?
      end

      def pre_complete
        save_scalar_type
      end

      protected

      def data_module
        attribute.entity.data_module
      end

      def characteristic
        attribute
      end
    end

    facet.enhance(InverseElement) do
      attr_writer :name

      def name
        @name || (inverse.name.to_s.upcase == inverse.name.to_s ? inverse.name.to_s : Reality::Naming.camelize(inverse.name))
      end

      def traversable=(traversable)
        Domgen.error("traversable #{traversable} is invalid") unless inverse.class.inverse_traversable_types.include?(traversable)
        @traversable = traversable
      end

      def traversable?
        @traversable.nil? ? (self.inverse.traversable? && self.inverse.attribute.referenced_entity.graphql?) : @traversable
      end
    end

    facet.enhance(Struct) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :struct_resolver, :data_type, :server, :graphql, '#{struct.name}Resolver', :sub_package => 'internal'

      attr_writer :name

      def name
        @name || "#{struct.data_module.graphql.prefix}#{struct.name}"
      end
    end

    facet.enhance(StructField) do
      include Domgen::Java::ImitJavaCharacteristic

      def type
        if field.struct?
          return field.referenced_struct.graphql.name
        elsif field.enumeration?
          return field.enumeration.graphql.name
        else
          return scalar_type
        end
      end

      attr_writer :scalar_type

      def scalar_type
        return @scalar_type if @scalar_type
        Domgen.error("Invoked graphql.scalar_type on #{field.qualified_name} when field is a non_standard_type") if field.non_standard_type?
        Domgen.error("Invoked graphql.scalar_type on #{field.qualified_name} when field has no characteristic_type") unless field.characteristic_type
        field.characteristic_type.graphql.scalar_type
      end

      protected

      def characteristic
        field
      end
    end
  end
end

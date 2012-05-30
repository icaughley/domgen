module Domgen

  module Characteristic
    attr_reader :name

    def allows_length?
      text? || (enumeration? && enumeration.textual_values?)
    end

    attr_reader :length

    def length=(length)
      error("length on #{name} is invalid as #{characteristic_container.characteristic_kind} is not a string") unless allows_length?
      @length = length
    end

    def has_non_max_length?
      !@length.nil? && @length != :max
    end

    def min_length
      return @min_length if @min_length
      allow_blank? ? 0 : 1
    end

    def min_length=(length)
      error("min_length on #{name} is invalid as #{characteristic_container.characteristic_kind} is not a string") unless allows_length?
      @min_length = length
    end

    attr_writer :allow_blank

    def allow_blank?
      @allow_blank.nil? ? true : @allow_blank
    end

    attr_writer :nullable

    def nullable?
      @nullable.nil? ? false : @nullable
    end

    attr_reader :enumeration

    def enumeration=(enumeration)
      error("enumeration on #{name} is invalid as #{characteristic_container.characteristic_kind} is not an enumeration") unless enumeration?
      @enumeration = enumeration
    end

    def enumeration?
      characteristic_type == :enumeration
    end

    def text?
      characteristic_type == :text
    end

    def reference?
      self.characteristic_type == :reference
    end

    def integer?
      self.characteristic_type == :integer
    end

    def boolean?
      self.characteristic_type == :boolean
    end

    def datetime?
      self.characteristic_type == :datetime
    end

    def date?
      self.characteristic_type == :date
    end

    def struct?
      self.characteristic_type == :struct
    end

    def collection?
      self.collection_type != :none
    end

    def collection_type
      @collection_type || :none
    end

    def collection_type=(collection_type)
      error("collection_type #{collection_type} is invalid") unless [:none, :sequence, :set].include?(collection_type)
      @collection_type = collection_type
    end

    def referenced_struct
      error("referenced_struct on #{name} is invalid as #{characteristic_container.characteristic_kind} is not a struct") unless struct?
      @referenced_struct
    end

    def referenced_struct=(referenced_struct)
      error("struct on #{name} is invalid as #{characteristic_container.characteristic_kind} is not a struct") unless struct?
      @referenced_struct = referenced_struct.is_a?(Symbol) ? self.characteristic_container.data_module.struct_by_name(referenced_struct) : referenced_struct
    end

    def referenced_entity
      error("referenced_entity on #{name} is invalid as #{characteristic_container.characteristic_kind} is not a reference") unless reference?
      @referenced_entity
    end

    def referenced_entity=(referenced_entity)
      error("referenced_entity on #{name} is invalid as #{characteristic_container.characteristic_kind} is not a reference") unless reference?
      @referenced_entity = referenced_entity.is_a?(Symbol) ? self.characteristic_container.data_module.entity_by_name(referenced_entity) : referenced_entity
    end

    # The name of the local field appended with PK of foreign entity
    def referencing_link_name
      error("referencing_link_name on #{name} is invalid as #{characteristic_container.characteristic_kind} is not a reference") unless reference?
      "#{name}#{referenced_entity.primary_key.name}"
    end

    attr_writer :polymorphic

    def polymorphic?
      error("polymorphic? on #{name} is invalid as attribute is not a reference") unless reference?
      @polymorphic.nil? ? !referenced_entity.final? : @polymorphic
    end

    def characteristic_type
      raise "characteristic_type not implemented"
    end

    def characteristic_container
      raise "characteristic_container not implemented"
    end
  end


  module InheritableCharacteristic
    include Characteristic

    def inherited?
      !!@inherited
    end

    def mark_as_inherited
      @inherited = true
    end

    attr_writer :abstract

    def abstract?
      @abstract.nil? ? false : @abstract
    end

    attr_writer :override

    def override?
      @override.nil? ? false : @override
    end
  end


  module CharacteristicContainer
    attr_reader :name

    def boolean(name, options = {}, &block)
      characteristic(name, :boolean, options, &block)
    end

    def text(name, options = {}, &block)
      characteristic(name, :text, options, &block)
    end

    def string(name, length, options = {}, &block)
      if length.class == Range
        options = options.merge({:min_length => length.first, :length => length.last})
      else
        options = options.merge({:length => length})
      end
      characteristic(name, :text, options, &block)
    end

    def integer(name, options = {}, &block)
      characteristic(name, :integer, options, &block)
    end

    def real(name, options = {}, &block)
      characteristic(name, :real, options, &block)
    end

    def datetime(name, options = {}, &block)
      characteristic(name, :datetime, options, &block)
    end

    def date(name, options = {}, &block)
      characteristic(name, :date, options, &block)
    end

    def i_enum(name, values, options = {}, &block)
      enumeration = data_module.enumeration("#{self.name}#{name}", :integer, {:top_level => false, :values => values})
      enumeration(name, enumeration.name, options, &block)
    end

    def s_enum(name, values, options = {}, &block)
      enumeration = data_module.enumeration("#{self.name}#{name}", :text, {:top_level => false, :values => values})
      enumeration(name, enumeration.name, options, &block)
    end

    def enumeration(name, enumeration_key, options = {}, &block)
      enumeration = data_module.enumeration_by_name(enumeration_key)
      params = options.dup
      params[:enumeration] = enumeration
      c = characteristic(name, :enumeration, params, &block)
      c.length = enumeration.max_value_length if enumeration.textual_values?
      c
    end

    def reference(other_type, options = {}, &block)
      name = options.delete(:name)
      if name.nil?
        if other_type.to_s.include? "."
          name = other_type.to_s.sub(/.+\./, '').to_sym
        else
          name = other_type
        end
      end

      characteristic(name.to_s.to_sym, :reference, options.merge({:referenced_entity => other_type}), &block)
    end

    def struct(name, struct_key, options = {}, &block)
      struct = data_module.struct_by_name(struct_key)
      params = options.dup
      params[:referenced_struct] = struct
      characteristic(name, :struct, params, &block)
    end

    protected

    def characteristic_by_name(name)
      characteristic = characteristic_map[name.to_s]
      error("Unable to find #{characteristic_kind} named #{name} on type #{self.name}. Available #{characteristic_kind} set = #{attributes.collect { |a| a.name }.join(', ')}") unless characteristic
      characteristic
    end

    def characteristic_exists?(name)
      !!characteristic_map[name.to_s]
    end

    def characteristic(name, type, options, &block)
      characteristic = new_characteristic(name, type, options, &block)
      error("Attempting to override #{characteristic_kind} #{name} on #{self.name}") if characteristic_map[name.to_s]
      characteristic_map[name.to_s] = characteristic
      characteristic
    end

    def characteristics
      characteristic_map.values
    end

    def verify_characteristics
      self.characteristics.each do |c|
        c.verify
      end
    end

    def characteristic_map
      @characteristics ||= Domgen::OrderedHash.new
    end

    def new_characteristic(name, type, options, &block)
      raise "new_characteristic not implemented"
    end

    def characteristic_kind
      raise "characteristic_kind not implemented"
    end

    # Also need to define data_module
  end

  module InheritableCharacteristicContainer
    include CharacteristicContainer

    attr_accessor :extends

    def direct_subtypes
      @direct_subtypes ||= []
    end

    attr_writer :abstract

    def abstract?
      @abstract.nil? ? false : @abstract
    end

    attr_writer :final

    def final?
      @final.nil? ? !abstract? : @final
    end

    protected

    def declared_characteristics
      characteristics.select { |c| !c.inherited? }
    end

    def inherited_characteristics
      characteristics.select { |c| c.inherited? }
    end

    def perform_extend(data_module, type_key, extends)
      base_type = data_module.send :"#{type_key}_by_name", extends
      Domgen.error("#{type_key} #{name} attempting to extend final #{type_key} #{extends}") if base_type.final?
      base_type.direct_subtypes << self
      base_type.characteristics.collect { |c| c.clone }.each do |characteristic|
        characteristic.instance_variable_set("@#{type_key}", self)
        characteristic.mark_as_inherited
        characteristic_map[characteristic.name.to_s] = characteristic
      end
    end
  end
end

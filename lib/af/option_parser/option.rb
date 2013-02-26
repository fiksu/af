module ::Af::OptionParser
  class Option
    attr_accessor :option_type, :requirements, :short_name, :long_name, :argument_note, :note, :environment_variable
    attr_accessor :default_value, :set, :evaluation_method, :option_group_name, :hidden, :choices
    attr_accessor :value_to_set_target_variable, :do_not_create_accessor
    attr_writer :target_variable

    @@options = {}

    def self.all_options
      return @@options
    end

    def self.all_option_types
      return @@option_types ||= options.map{|o| o.option_type}.uniq
    end

    def initialize(long_name, short_name = nil, option_type = nil, requirements = nil, argument_note = nil,
                   note = nil, environment_variable = nil, default_value = nil, target_variable = nil,
                   value_to_set_target_variable = nil, evaluation_method = nil, option_group_name = nil,
                   hidden = nil, choices = nil, do_not_create_accessor = nil)
      @long_name = long_name
      @short_name = short_name
      @option_type = option_type
      @requirements = requirements
      @argument_note = argument_note
      @note = note
      @environment_variable = environment_variable
      @default_value = default_value
      @target_variable = target_variable
      @value_to_set_target_variable = value_to_set_target_variable
      @evaluation_method = evaluation_method
      @option_group_name = option_group_name
      @hidden = hidden
      @choices = choices
      @do_not_create_accessor = do_not_create_accessor
      @@options[long_name] = self
    end

    def evaluate(argument_value)
      evaluator = @option_type ||
        OptionType.find_by_value(@value_to_set_target_variable) ||
        OptionType.find_by_short_name(:string)
      raise UndeterminedArgumentTypeError.new(@long_name) unless evaluator
      return evaluator.evaluate_argument(@value_to_set_target_variable || argument_value, self)
    end

    def target_variable
      unless @target_variable
        @target_variable = @long_name[2..-1].gsub(/-/, '_').gsub(/[^0-9a-zA-Z]/, '_')
      end
      return @target_variable
    end

    def self.find(long_name)
      return all_options[long_name]
    end

    def self.factory(long_name, short_name = nil, option_type = nil, requirements = nil, argument_note = nil,
                     note = nil, environment_variable = nil, default_value = nil, target_variable = nil,
                     value_to_set_target_variable = nil, evaluation_method = nil, option_group_name = nil,
                     hidden = nil, choices = nil, do_not_create_accessor = nil)
      option = find(long_name) || new(long_name)
      option.option_type = option_type if option_type
      option.requirements = requirements if requirements
      option.short_name = short_name if short_name
      option.argument_note = argument_note if argument_note
      option.note = note if note
      option.environment_variable = environment_variable if environment_variable
      option.default_value = default_value if default_value.present?
      option.target_variable = target_variable if target_variable
      option.value_to_set_target_variable = value_to_set_target_variable if value_to_set_target_variable.present?
      option.evaluation_method = evaluation_method if evaluation_method
      option.option_group_name = option_group_name if option_group_name
      option.hidden = hidden if hidden.present?
      option.choices = choices if choices
      option.do_not_create_accessor = do_not_create_accessor if do_not_create_accessor.present?
      return option
    end
  end
end

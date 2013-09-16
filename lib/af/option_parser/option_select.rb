module ::Af::OptionParser
  class OptionSelect < InstanceVariableSetter
    FACTORY_SETTABLES = [
                          :action,
                          :targets,
                          :error_message
                        ]

    attr_accessor *FACTORY_SETTABLES
    attr_accessor :var_name

    def initialize(var_name, parameters = {})
      super(parameters)
      @var_name = var_name
    end

    #-------------------------
    # *** Instance Methods ***
    #+++++++++++++++++++++++++

    def set_instance_variables(parameters = {})
      super(parameters, FACTORY_SETTABLES)
    end

    def merge(that_option)
      super(that_option, FACTORY_SETTABLES)
    end

    # This methods validates the selected options based
    # on the chosen action.
    #
    # Available actions: one_of, none_or_one_of, one_or_more_of
    #
    # If an invalidation occurs, an OptionSelectError is raised
    # with a specific message.
    def validate
      # If an option_select is used, an array of options must be given
      if targets.blank?
        raise OptionSelectError.new("An array of options must be specified")
      end

      options_set = []
      # Retrieve options assigned to target_variable
      select_option = target_container.try(target_variable.to_sym)
      select_option = [select_option] if !select_option.is_a? Array
      # Assigned options should be included in the targets array
      if select_option.present? && select_option != [nil]
        select_option.each do |option|
          if targets.include?(option)
            options_set << option
          else
            raise OptionSelectError.new("Unrecognized option #{option}. Please choose from: #{targets.join(', ')}")
          end
        end
      end

      if action == :one_of && options_set.size != 1
        raise OptionSelectError.new("You must specify only one of these options: #{targets.join(', ')}")
      elsif action == :none_or_one_of && options_set.size > 1
        raise OptionSelectError.new("You must specify no more than one of these options: #{targets.join(', ')}")
      elsif action == :one_or_more_of && options_set.size < 1
        raise OptionSelectError.new("You must specify at least one of these options: #{targets.join(', ')}")
      end
    end

  end
end

require 'parameters/exceptions'
require 'parameters/class_param'
require 'parameters/instance_param'
require 'parameters/exceptions'
require 'parameters/extensions/meta'

module Parameters
  def self.included(base) # :nodoc:
    base.metaclass_eval do
      #
      # Returns the +Hash+ of parameters for the class.
      #
      def params
        @params ||= {}
      end

      #
      # Sets the values of the class parameters described in the
      # _values_ +Hash+.
      #
      #   Test.params = {:x => 5, :y => 2}
      #   # => {:x=>5, :y=>2}
      #
      def params=(values)
        values.each do |name,value|
          if has_param?(name)
            if (value.kind_of?(Parameters::ClassParam) || value.kind_of?(Parameters::InstanceParam))
              value = value.value
            end

            get_param(name).value = value
          end
        end
      end

      #
      # Adds a new parameters with the specified _name_ and the given
      # _options_ to the Class.
      #
      # _options_ may contain the following keys:
      # <tt>:description</tt>:: The description of the parameter.
      # <tt>:default</tt>:: The default value the parameter will have.
      #
      #   parameter 'var'
      #
      #   parameter 'var', :default => 3, :description => 'my variable' 
      #
      def parameter(name,options={})
        name = name.to_sym

        # add the parameter to the class params list
        params[name] = Parameters::ClassParam.new(name,options[:description],options[:default])

        # define the reader class method for the parameter
        meta_def(name) do
          params[name].value
        end

        # define the writer class method for the parameter
        meta_def("#{name}=") do |value|
          params[name].value = value
        end

        # define the getter/setter instance methods for the parameter
        attr_accessor(name)
      end

      #
      # Returns the class parameter with the specified _name_. If no
      # such class parameter exists, a ParamNotFound exception will be
      # raised.
      #
      def get_param(name)
        name = name.to_sym

        ancestors.each do |ancestor|
          if ancestor.include?(Parameters)
            if ancestor.params.has_key?(name)
              return ancestor.params[name]
            end
          end
        end

        raise(Parameters::ParamNotFound,"parameter #{name.to_s.dump} was not found in class #{self.name.dump}",caller)
      end

      #
      # Returns +true+ if a class parameters with the specified _name_
      # exists, returns +false+ otherwise.
      #
      def has_param?(name)
        name = name.to_sym

        ancestors.each do |ancestor|
          if ancestor.include?(Parameters)
            return true if ancestor.params.has_key?(name)
          end
        end

        return false
      end

      #
      # Iterates over all class parameters, passing each one to the
      # specified _block_.
      #
      def each_param(&block)
        ancestors.each do |ancestor|
          if ancestor.include?(Parameters)
            ancestor.params.each_value(&block)
          end
        end

        return self
      end

      #
      # Returns the description of the class parameters with the
      # specified _name_. If no such class parameter exists, a
      # ParamNotFound exception will be raised.
      #
      def describe_param(name)
        get_param(name).description
      end

      #
      # Returns the value of the class parameters with the specified
      # _name_. If no such class parameter exists, a ParamNotFound
      # exception will be raised.
      #
      def param_value(name)
        get_param(name).value
      end

      #
      # Print the class parameters to the given _output_ stream.
      #
      def print_params(output=STDOUT)
        each_param do |param|
          output.puts param
        end
      end
    end
  end

  #
  # Initalizes the parameters of the object using the given
  # _values_, which can override the default values of
  # parameters.
  #
  def initialize_params(values={})
    self.class.each_param do |param|
      # do not override existing instance value if present
      if instance_variable_get("@#{param.name}".to_sym).nil?
        begin
          if param.value.kind_of?(Proc)
            value = param.value.call(self)
          else
            value = param.value.clone
          end
        rescue TypeError
          value = param.value
        end

        instance_variable_set("@#{param.name}".to_sym,value)
      end

      self.params[param.name] = InstanceParam.new(self,param.name,param.description)
    end

    self.params = values if values.kind_of?(Hash)
  end

  #
  # Initializes the parameters using initialize_params. If a +Hash+
  # is passed in as the first argument, it will be used to set the values
  # of parameters described within the Hash.
  #
  def initialize(*args,&block)
    initialize_params(args.first)
  end

  #
  # Adds a new parameters with the specified _name_ and the given
  # _options_ to the object.
  #
  # _options_ may contain the following keys:
  # <tt>:description</tt>:: The description of the parameter.
  # <tt>:default</tt>:: The default value the parameter will have.
  #
  #   obj.parameter('var')
  #
  #   obj.parameter('var',:default => 3, :description => 'my variable')
  #
  def parameter(name,options={})
    name = name.to_sym
    default = options[:default]
    description = options[:description]

    # resolve the default value
    if default.kind_of?(Proc)
      value = default.call(self)
    else
      value = default
    end

    # set the instance variable
    instance_variable_set("@#{name}".to_sym,value)

    # add the new parameter
    self.params[name] = InstanceParam.new(self,name,description)

    instance_eval %{
      # define the reader method for the parameter
      def #{name}
        instance_variable_get("@#{name}".to_sym)
      end

      # define the writer method for the parameter
      def #{name}=(value)
        instance_variable_set("@#{name}".to_sym,value)
      end
    }

    return params[name]
  end

  #
  # Returns a +Hash+ of the classes params.
  #
  def class_params
    self.class.params
  end

  #
  # Returns a +Hash+ of the instance parameters.
  #
  def params
    @params ||= {}
  end

  #
  # Sets the values of the parameters described in the _values_ +Hash+.
  #
  #   obj.params = {:x => 5, :y => 2}
  #   # => {:x=>5, :y=>2}
  #
  def params=(values)
    values.each do |name,value|
      name = name.to_sym

      if has_param?(name)
        if (value.kind_of?(Parameters::ClassParam) || value.kind_of?(Parameters::InstanceParam))
          value = value.value
        end

        self.params[name].value = value
      end
    end
  end

  #
  # Iterates over each instance parameter, passing each one to the given
  # _block_.
  #
  def each_param(&block)
    self.params.each_value(&block)
  end

  #
  # Returns +true+ if the a parameter with the specified _name_ exists,
  # returns +false+ otherwise.
  #
  #   obj.has_param?('rhost') # => true
  #
  def has_param?(name)
    self.params.has_key?(name.to_sym)
  end

  #
  # Returns the parameter with the specified _name_. If no such parameter
  # exists, a ParamNotFound exception will be raised.
  #
  #   obj.get_param('var') # => InstanceParam
  #
  def get_param(name)
    name = name.to_sym

    unless has_param?(name)
      raise(Parameters::ParamNotFound,"parameter #{name.to_s.dump} was not found within #{self.to_s.dump}",caller)
    end

    return self.params[name]
  end

  #
  # Returns the description of the parameter with the specified _name_.
  # If no such parameter exists, a ParamNotFound exception will be raised.
  #
  #   obj.describe_param('rhost') # => "remote host"
  #
  def describe_param(name)
    get_param(name).description
  end

  #
  # Returns the value of the parameter with the specified _name_. If no
  # such parameter exists, a ParamNotFound exception will be raised.
  #
  #   obj.param_value('rhost') # => 80
  #
  def param_value(name)
    get_param(name).value
  end

  #
  # Print the instance parameters to the given _output_ stream.
  #
  def print_params(output=STDOUT)
    each_param do |param|
      output.puts param
    end
  end

  protected

  #
  # Requires that the parameters with the specified _names_ have
  # non +nil+ values. If a parameter with a +nil+ value is found
  # a MissingParam exception will be raised.
  #
  def require_params(*names)
    names.each do |name|
      name = name.to_s

      unless instance_variable_get("@#{name}".to_sym)
        raise(Parameters::MissingParam,"parameter #{name.dump} has no value",caller)
      end
    end

    return true
  end
end

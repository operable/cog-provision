
require 'cloudformation-ruby-dsl/dsl'

class Cog::Cfn < TemplateDSL
  TEMPLATE_DIR = File.join(File.dirname(__FILE__), '..', '..', 'src', 'cloudformation')

  attr_accessor :groups, :multi_az

  def initialize(parameters = {}, stack_name = nil, aws_region = default_region, aws_profile = nil, nopretty = false)
    super(parameters, stack_name, aws_region, aws_profile, nopretty) {}
    self.groups = {}
    self.include_template("base")
  end

  def include_template(name)
    path = File.join(TEMPLATE_DIR, "#{name}.rb")
    self.load_from_file(path)
  end

  def cog_config(group:, name:, description:,
                 default: nil, allowed: nil, options: {})
    env_name = name.to_s.upcase
    cfn_name = camelize(env_name)
    default = default || ""
    description = "#{env_name}: #{description}"

    options.merge!({ :Description => description, :Type => "String" })
    options[:Default] = default unless default.nil?
    options[:AllowedValues] = allowed unless allowed.nil?

    @groups[group] ||= []
    @groups[group] << cfn_name

    parameter cfn_name, options

    if !allowed.nil? && %w(false true) == allowed.sort
      condition "#{cfn_name}", equal(ref(cfn_name), "true")
    else
      condition "#{cfn_name}Empty", equal(ref(cfn_name), "")
    end
  end

  def parameter_group(name, description)
    {
      :Label => { "default" => description },
      :Parameters => @groups[name]
    }
  end

  def metadata(name, options) default(:Metadata, {})[name] = options end

  def generate
    generate_json(self, true)
  end

  def write(path)
    File.open(path, 'w') { |f| f.write generate_json(self, true) }
  end

  def camelize(str)
    str.split('_').map { |seg| seg.capitalize }.join('')
  end
end

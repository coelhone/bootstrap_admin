module BootstrapAdminHelper
  # =============================================================================
  # This re-implementation of link_to simply looks at the link label and if it
  # falls under certain conditions, then it tries to create a label and/or url
  # accordingly. Else works normally
  #
  # @param *args Same as the original link_to
  # @param &block Same as the original link_to
  #
  # @return [String] link markup
  #
  # @example Assuming locale is set to PT
  #  link_to :Show, @document
  #    # <a href='/documents/1'>Ver</a>
  #
  #  link_to Document
  #    # <a href='/documents'>Documentos</a>
  #
  #  link_to [:edit, @document]
  #    # <a href='/document/1/edit'>Editar Documento</a>
  #
  def link_to(*args, &block)
    super(*args, &block) if block_given?

    # When args[0] is a symbol, then just translate the symbol...
    if args[0].is_a? Symbol
      super(t(args[0]), *args[1..-1])

    # when arg[0] is a ActiveRecord class...
    elsif args[0].is_a?(Class) and args[0] < ActiveRecord::Base
      label = args[0].model_name.human.pluralize
      if args.length == 1
        controller_name = args[0].name.underscore.pluralize
        super(label, url_for(controller: controller_name, action: "index"))
      else
        super(label, *args[1..-1])
      end

    elsif args[0].is_a?(Array) && args[0][0].is_a?(Symbol) && args[0][1] < ActiveRecord::Base
      link_content = t("helpers.submit.#{args[0][0]}", :model => args[0][1].model_name.human)
      super(link_content, *args[1..-1])
    else
      super(*args)
    end
  end

  # =============================================================================
  # Builds the markup to properly display a field, including label and field value.
  #
  # If a block is given, then it uses the block as the field "value"
  # else it looks at what the field value is and if it is:
  #   * a boolean, builds a fake checkbox
  #   * an array, builds a ul list with each element of the array
  #   * else, just uses the string value
  #
  # @param item [ActiveRecord::Base] The item record
  # @param field [Symbol or String] The field to display
  # @param &block [Block] An optional block that yields markup
  #
  # @return [Markup] the necessary markup to display the field
  #
  # @example
  #   display_field @document, :title
  #     # <p><b>Title: </b>So Long, and Thanks For All the Fish</p>
  #
  #   display_field @document, :awesome?
  #     # <p><b>Awesome: </b><span class='checkbox true'><span class='icon'></span></span></p>
  #
  #   display_field @document, :authors
  #     # <p><b>Authors: </b><ul><li>Douglas Adams</li></ul></p>
  #
  #   display_field @document, :details do
  #     "#{@document.title} - #{@document.year}"
  #   end
  #     # <p><b>Title: </b>So Long, and Thanks For All the Fish - 1984</p>
  #
  def display_field item, field, &block
    content_tag :p do
      content_tag(:b) do
        item.class.human_attribute_name(field) + ": "
      end +
      if block_given?
        capture(&block)
      else
        val = render_field item, field
        if val.class.name =~ /(TrueClass|FalseClass)/
          content_tag(:span, :class => "checkbox #{val.to_s}") do
            content_tag(:span, :class=>"icon"){""}
          end
        elsif val.is_a? Array
          content_tag :ul do
            val.map do |uniq_val|
              content_tag(:li, uniq_val.to_s)
            end.join.html_safe
          end
        else
          val.to_s
        end
      end
    end.html_safe
  end

  # =============================================================================
  def render_field item, field
    if self.respond_to?(helper = "#{params[:action]}_#{field}") ||
       self.respond_to?(helper = "#{field}")
      send helper, item
    else
      item.send field
    end
  end

  # =============================================================================
  def render_form_field form, field
    if self.respond_to?(helper = "#{params[:action]}_form_#{field.name}") ||
       self.respond_to?(helper = "form_#{field.name}")
      send helper, form

    elsif field.association?
      form.association field.name

    else
      form.input field.name
    end
  end

  # =============================================================================
  def available_actions
    bootstrap_admin_config.available_actions
  end


  def bootstrap_url_for options = {}
    defaults = {:controller => params[:controller]}.merge options

    ctrl_namespace = defaults[:controller].split("/").first
    # Fix for engines with shared namespace for some reason main_app.url_for doesn't find the route without this "/"
    # It consider the route inside of engine instead of main app.
    defaults[:controller] = "/#{defaults[:controller]}"

    if instance_eval "defined? #{ctrl_namespace}"
      instance_eval("#{ctrl_namespace}.method :url_for").call defaults
    else
      main_app.url_for(defaults)
    end
  end
  alias_method :bootstrap_url, :bootstrap_url_for

  def bootstrap_form_url item
    item_name = item.class.name.underscore.gsub("/","_")
    [item, :as => item_name, :url => bootstrap_url_for(:action => (item.new_record? ? :create : :update), :id => item.id)]
  end

  # =============================================================================
  def index_actions_for item
    actions = []

    if available_actions.include? :show
      actions << link_to(:show, bootstrap_url_for(:action => :show, :id => item.id), class: 'btn')
    end

    if available_actions.include? :edit
      actions << link_to(:edit, bootstrap_url_for(:action => :edit, :id => item.id), class: 'btn')
    end

    if available_actions.include? :destroy
      actions << link_to(:destroy, bootstrap_url_for(:action => :show, :id => item.id), confirm: t(:confirm), method: :delete, class: 'btn btn-danger')
    end

    actions.join("\n").html_safe
  end

  # =====
  def index_default_actions
    if available_actions.include? :new
      model_klass = model_for controller
      link_to([:new, model_klass], bootstrap_url_for(:action => :new), :class => 'btn btn-primary').html_safe
    end
  end

  def show_default_actions
    model_instance = model_instance_for controller
    str = if available_actions.include? :edit
      link_to :edit, bootstrap_url_for(:action => :edit, :id => model_instance.id), :class => 'btn'
    end || ""
    str += link_to :back, bootstrap_url, :class => 'btn'
    str.html_safe
  end


  # =============================================================================
  # @param controller [ActionController::Base]
  # @return [Class] the model class for the current controller
  def model_for controller
    if bootstrap_admin_config.model_name.blank?
      collection_name_for(controller).classify.constantize
    else
      bootstrap_admin_config.model_name.constantize
    end
  end

  # =============================================================================
  # @return [ActiveRecord::Base] the model instance based on the controller name
  def model_instance_for controller
    name = collection_name_for(controller).singularize
    instance_variable_get "@#{name}"
  end

  # =============================================================================
  # @return [ActiveRecord::Base Array] the model instance collection for the current controller
  def collection_for controller
    name = collection_name_for controller
    instance_variable_get "@#{name}"
  end

  # =============================================================================
  # @return [String] the model instance name for the current controller
  def model_name_for controller
    model_for(controller).model_name.to_s.underscore
  end

  # =============================================================================
  # @return [String] the model instance collection name for the current controller
  def collection_name_for controller
    controller.class.name.sub("Controller", "").underscore.split('/').last
  end

  # =============================================================================
  # Finds the model instance attributes to use for the current action.
  #
  # First it checks if the bootstrap_admin_config has fields configured for the
  # current action. If so, it uses those, if not, it tries to guess which
  # attributes to use through the model's "accessible_attributes"
  #
  # @return [BootstrapAdmin::Attribute Array] Attributes to be used on the current
  #                                           action
  #
  def attributes
    return @attributes if @attributes
    model_klass = model_for controller
    fields =  bootstrap_admin_config.send("#{params[:action]}_fields")  ||
              bootstrap_admin_config.send("action_fields")              ||
              find_attributes_for_class(model_klass)

    @attributes = fields.map do |att|
      BootstrapAdmin::Attribute.new att,
                                    model_klass.human_attribute_name(att),
                                    model_klass.type_of(att)
    end
  end

  # =============================================================================
  # Tries to render the action/partial "namespaced" with the current action name
  # if it fails, then simply calls render with whatever args that got passed in.
  #
  # Ex:
  #  # on get to '/admin/some_resource/new'
  #  render_with_fallback 'form' # this will to render 'new_form', if it fails,
  #                              # then it will just call "render 'form'"
  def render_with_fallback *args
    render "#{params[:action]}_#{args.first}", *args[1..-1]
  rescue ActionView::MissingTemplate
    render *args
  end

  # =============================================================================
  # def render_attribute name, type = :index
  #   # content_tag :td do
  #   # if respond_to? "#{attribute.name}_index"
  #   #   %td= send "#{attribute.name}_index", item
  #   # else
  #   #   %td= item.send attribute.name
  #   # end
  # end

  private
    # =============================================================================
    # Translates "*_id" attribute names to association names when needed
    # @param attribute [String] The attribute to "translate"
    # @return [String] The attribute name translated
    def real_attribute_name attribute
      if attribute.match /(.+)_(?:id)(s)?$/
        ($2 ? $1.pluralize : $1).to_sym
        # "#{$1}#{$2}".to_sym
      else
        attribute.to_sym
      end
    end

    # ==============================================================================
    # Finds attributes for the given model class
    # @param model_klass [ActiveRecord::Base] The model to get attributes from
    # @return [Array of Symbol] attributes for the given model
    def find_attributes_for_class model_klass
      attributes = BootstrapAdmin.filter_ignored_fields(model_klass.attribute_names)

      attributes.map{|att| real_attribute_name att }.
                 reject{|att|
                   att.to_s =~ /(.+)_attributes/ &&
                   model_klass.reflect_on_all_associations
                              .map(&:name)
                              .include?($1.to_sym)
                 }
    end

end

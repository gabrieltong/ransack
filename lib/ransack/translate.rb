require 'i18n'

I18n.load_path += Dir[File.join(File.dirname(__FILE__), 'locale', '*.yml')]

module Ransack
  module Translate
    def self.word(key, options = {})
      I18n.translate(:"ransack.#{key}", :default => key.to_s)
    end

    def self.predicate(key, options = {})
      I18n.translate(:"ransack.predicates.#{key}", :default => key.to_s)
    end

    def self.attribute(key, options = {})
      unless context = options.delete(:context)
        raise ArgumentError, "A context is required to translate attributes"
      end

      original_name = key.to_s
      base_class = context.klass
      base_ancestors = base_class.ancestors.select {
        |x| x.respond_to?(:model_name)
      }
      predicate = Predicate.detect_from_string(original_name)
      attributes_str = original_name.sub(/_#{predicate}$/, '')
      attribute_names = attributes_str.split(/_and_|_or_/)
      combinator = attributes_str.match(/_and_/) ? :and : :or
      defaults = base_ancestors.map do |klass|
        :"ransack.attributes.#{i18n_key(klass)}.#{original_name}"
      end

      translated_names = attribute_names.map do |attr|
        attribute_name(context, attr, options[:include_associations])
      end

      interpolations = {}
      interpolations[:attributes] = translated_names.join(
        " #{Translate.word(combinator)} "
        )

      if predicate
        defaults << "%{attributes} %{predicate}"
        interpolations[:predicate] = Translate.predicate(predicate)
      else
        defaults << "%{attributes}"
      end

      defaults << options.delete(:default) if options[:default]
      options.reverse_merge! :count => 1, :default => defaults
      I18n.translate(defaults.shift, options.merge(interpolations))
    end

    def self.association(key, options = {})
      unless context = options.delete(:context)
        raise ArgumentError, "A context is required to translate associations"
      end

      defaults = key.blank? ?
        [:"#{context.klass.i18n_scope}.models.#{i18n_key(context.klass)}"] :
        [:"ransack.associations.#{i18n_key(context.klass)}.#{key}"]
      defaults << context.traverse(key).model_name.human
      options = {:count => 1, :default => defaults}
      I18n.translate(defaults.shift, options)
    end

    private

    def self.attribute_name(context, name, include_associations = nil)
      assoc_path = context.association_path(name)
      associated_class = context.traverse(assoc_path) if assoc_path.present?
      attr_name = name.sub(/^#{assoc_path}_/, '')
      interpolations = {}
      interpolations[:attr_fallback_name] = I18n.translate(
        (associated_class ?
          :"ransack.attributes.#{i18n_key(associated_class)}.#{attr_name}" :
          :"ransack.attributes.#{i18n_key(context.klass)}.#{attr_name}"
        ),
        :default => [
          (
            if associated_class
              :"#{associated_class.i18n_scope}.attributes.#{
                i18n_key(associated_class)}.#{attr_name}"
            else
              :"#{context.klass.i18n_scope}.attributes.#{
                i18n_key(context.klass)}.#{attr_name}"
            end
          ),
          :".attributes.#{attr_name}",
          attr_name.humanize
        ]
      )
      defaults = [
        :"ransack.attributes.#{i18n_key(context.klass)}.#{name}"
      ]
      if include_associations && associated_class
        defaults << '%{association_name} %{attr_fallback_name}'
        interpolations[:association_name] = association(
          assoc_path, :context => context
          )
      else
        defaults << '%{attr_fallback_name}'
      end
      options = {:count => 1, :default => defaults}
      I18n.translate(defaults.shift, options.merge(interpolations))
    end

    def self.i18n_key(klass)
      if ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR == 0
        klass.model_name.i18n_key.to_s.tr('.', '/')
      else
        klass.model_name.i18n_key.to_s
      end
    end
  end
end

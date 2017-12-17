class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  module ApiMethods
    extend ActiveSupport::Concern

    def as_json(options = {})
      options ||= {}
      options[:except] ||= []
      options[:except] += hidden_attributes

      options[:methods] ||= []
      options[:methods] += method_attributes

      super(options)
    end

    def to_xml(options = {}, &block)
      options ||= {}

      options[:except] ||= []
      options[:except] += hidden_attributes

      options[:methods] ||= []
      options[:methods] += method_attributes

      super(options, &block)
    end

    def serializable_hash(*args)
      hash = super(*args)
      hash.transform_keys { |key| key.delete("?") }
    end

    protected

    def hidden_attributes
      [:uploader_ip_addr, :updater_ip_addr, :creator_ip_addr, :ip_addr]
    end

    def method_attributes
      []
    end
  end

  concerning :ActiveRecordExtensions do
    class_methods do
      def without_timeout
        connection.execute("SET STATEMENT_TIMEOUT = 0") unless Rails.env == "test"
        yield
      ensure
        connection.execute("SET STATEMENT_TIMEOUT = #{CurrentUser.user.try(:statement_timeout) || 3_000}") unless Rails.env == "test"
      end

      def with_timeout(n, default_value = nil, new_relic_params = {})
        connection.execute("SET STATEMENT_TIMEOUT = #{n}") unless Rails.env == "test"
        yield
      rescue ::ActiveRecord::StatementInvalid => x
        if Rails.env.production?
          NewRelic::Agent.notice_error(x, :custom_params => new_relic_params.merge(:user_id => CurrentUser.id, :user_ip_addr => CurrentUser.ip_addr))
        end
        return default_value
      ensure
        connection.execute("SET STATEMENT_TIMEOUT = #{CurrentUser.user.try(:statement_timeout) || 3_000}") unless Rails.env == "test"
      end
    end

    %w(execute select_value select_values select_all).each do |method_name|
      define_method("#{method_name}_sql") do |sql, *params|
        self.class.connection.__send__(method_name, self.class.send(:sanitize_sql_array, [sql, *params]))
      end

      self.class.__send__(:define_method, "#{method_name}_sql") do |sql, *params|
        connection.__send__(method_name, send(:sanitize_sql_array, [sql, *params]))
      end
    end
  end

  concerning :PostgresExtensions do
    class_methods do
      def columns(*params)
        super.reject {|x| x.sql_type == "tsvector"}
      end
    end
  end

  def warnings
    @warnings ||= ActiveModel::Errors.new(self)
  end

  include ApiMethods
end

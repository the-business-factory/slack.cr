module Slack::JSONRecords
  macro json_record(klass, *type_declarations)
    struct {{ klass.id }}
      include JSON::Serializable
      include Slack::InitializerMacros

      properties_with_initializer {{ type_declarations.splat }}
    end
  end
end

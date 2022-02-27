enum ContentTypes
  FormEncoded
  JSON

  def to_s
    case self
    when .form_encoded?
      "application/x-www-form-urlencoded"
    when .json?
      "application/json"
    else
      raise "Content type not supported."
    end
  end
end

class InProcessHttp
  Response = Struct.new(:status, :body)

  def initialize(app = Rails.application)
    @session = ActionDispatch::Integration::Session.new(app)
  end

  def get(path, params)
    @session.get(path, params: params)
    Response.new(@session.response.status, @session.response.body)
  end
end

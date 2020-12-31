class Crem::Redirect
  enum Status
    Success
    RedirectTemporary
    RedirectPermanent
  end

  property from : String
  property to : String
  property status : Status

  def initialize(@from, @to, @status : Status); end

  def initialize(@from, @to, status : Int)
    @status =
      case status
      when 20 then Status::Success
      when 30 then Status::RedirectTemporary
      when 31 then Status::RedirectPermanent
      else         raise ArgumentError.new("Status integer must be either 20, 30, or 31 for redirects")
      end
  end

  def server_side?
    @status.success?
  end

  def client_side?
    @status.redirect_temporary? || @status.redirect_permanent?
  end
end

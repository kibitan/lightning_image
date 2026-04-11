require "../extensions/http_server_context"

module LightningImage
  class ConvertHandler
    include HTTP::Handler

    def initialize(@allow_upsize_image : Bool); end

    def call(context)
      context.image_cache.not_nil!.convert_from_source!(allow_upsize_image: @allow_upsize_image)

      call_next(context)
    end
  end
end

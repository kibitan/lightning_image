require "http/server/handler"
require "../models/image_cache"

class HTTP::Server::Context
  property image_cache : LightningImage::ImageCache?
end

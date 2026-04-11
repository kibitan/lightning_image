module LightningImage
  SUPPORTED_FORMATS = ["webp"]
  # SUPPORTED_SOURCE_FORMAT = # TODO: define it with investigating vip option
  # refs: https://www.iana.org/assignments/media-types/media-types.xhtml#image
  SUPPORTED_SOURCE_CONTENT_TYPES = ["image/jpeg", "image/png", "image/gif", "image/webp"]
  SOURCE_DIR = "source"
  FIT_SUFFIX = "_fit"
  WIDTH_HEIGHT_SEPARATOR = "x"
  HEALTH_CHECK_PATH = "/ping"
end

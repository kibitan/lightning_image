require "../spec_helper"
require "../../src/models/allow_list"

describe LightningImage::AllowList do
  describe ".new" do
    it "raises AllowListFileNotFoundError when file path does not exist" do
      expect_raises(LightningImage::AllowList::AllowListFileNotFoundError) do
        LightningImage::AllowList.new("/tmp/allow_list_file_that_does_not_exist_#{Process.pid}_#{Time.utc.to_unix_ms}.txt")
      end
    end
  end

  describe "#allowed?" do
    it "returns true when url matches an allow-list regex" do
      allow_list = LightningImage::AllowList.new(fixture_path("allow_list.txt"))

      allow_list.allowed?("https://example.com/cat.png").should be_true
      allow_list.allowed?("https://evil.com/cat.png").should be_false

      allow_list.allow_list_regexes.should eq([
        Regex.new("^https://example\\.com/.*"),
        Regex.new("^https://images\\.example\\.org/.*"),
      ])
    end

    it "returns true when allow list is empty" do
      allow_list = LightningImage::AllowList.new(fixture_path("empty.txt"))

      allow_list.allowed?("https://example.com/cat.png").should be_true
    end

    it "supports deny-list style regex patterns" do
      allow_list = LightningImage::AllowList.new(fixture_path("deny_list.txt"))

      allow_list.allowed?("https://example.com/cat.png").should be_false
      allow_list.allowed?("https://evil.com/cat.png").should be_true
    end
  end
end

describe LightningImage::AllowEverything do
  describe "#allowed?" do
    it "returns true for any url" do
      allow_everything = LightningImage::AllowEverything.new()

      allow_everything.allowed?("https://example.com/cat.png").should be_true
      allow_everything.allowed?("https://evil.com/cat.png").should be_true
    end
  end
end

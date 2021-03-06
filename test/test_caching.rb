require 'sprockets_test'

class TestCaching < Sprockets::TestCase
  def setup
    reset
  end

  def reset
    @cache = {}

    @env1 = Sprockets::Environment.new(fixture_path('default')) do |env|
      env.append_path(".")
      env.cache = @cache
    end

    @env2 = Sprockets::Environment.new(fixture_path('default')) do |env|
      env.append_path(".")
      env.cache = @cache
    end
  end

  test "same environment instance cache objects are equal" do
    env = @env1

    asset1 = env['gallery.js']
    asset2 = env['gallery.js']

    assert asset1
    assert asset2

    assert asset1.eql?(asset2)
    assert asset2.eql?(asset1)
  end

  test "same cached instance cache objects are equal" do
    cached = @env1.cached

    asset1 = cached['gallery.js']
    asset2 = cached['gallery.js']

    assert asset1
    assert asset2

    assert asset1.eql?(asset2)
    assert asset2.eql?(asset1)
  end

  test "same environment instance is cached at logical and expanded path" do
    env = @env1

    asset1 = env['gallery.js']
    asset2 = env[asset1.pathname]

    assert asset1
    assert asset2

    assert asset1.eql?(asset2)
    assert asset2.eql?(asset1)
  end

  test "same cached instance is cached at logical and expanded path" do
    cached = @env1.cached

    asset1 = cached['gallery.js']
    asset2 = cached[asset1.pathname]

    assert asset1
    assert asset2

    assert asset1.eql?(asset2)
    assert asset2.eql?(asset1)
  end

  test "shared cache objects are eql" do
    asset1 = @env1['gallery.js']
    asset2 = @env2['gallery.js']

    assert asset1
    assert asset2

    assert asset1.eql?(asset2)
    assert asset2.eql?(asset1)
    assert !asset1.equal?(asset2)
  end

  test "keys are different if environment digest changes" do
    @env1['gallery.js']
    old_keys = @cache.keys.sort

    @cache.clear
    @env2.version = '2.0'

    @env2['gallery.js']
    new_keys = @cache.keys.sort

    refute_equal old_keys, new_keys
  end

  test "stale cached asset isn't loaded if file is remove" do
    filename = fixture_path("default/tmp.js")

    sandbox filename do
      File.open(filename, 'w') { |f| f.puts "foo;" }
      assert_equal "foo;\n", @env1["tmp.js"].to_s

      File.unlink(filename)
      assert_nil @env2["tmp.js"]
    end
  end

  test "stale cached asset isn't loaded if dependency is changed and removed" do
    foo = fixture_path("default/foo-tmp.js")
    bar = fixture_path("default/bar-tmp.js")

    sandbox foo, bar do
      File.open(foo, 'w') { |f| f.puts "//= require bar-tmp\nfoo;" }
      File.open(bar, 'w') { |f| f.puts "bar;" }
      assert_equal "bar;\nfoo;\n", @env1["foo-tmp.js"].to_s
      assert_equal "bar;\n", @env1["bar-tmp.js"].to_s

      File.open(foo, 'w') { |f| f.puts "foo;" }
      File.unlink(bar)
      assert_nil @env2["bar-tmp.js"]
      assert_raises Sprockets::FileNotFound do
        @env1["foo-tmp.js"].to_s
      end
    end
  end

  test "stale cached asset isn't loaded if removed from path" do
    env1 = Sprockets::Environment.new(fixture_path('default')) do |env|
      env.append_path("app")
      env.append_path("vendor")
      env.cache = @cache
    end

    env2 = Sprockets::Environment.new(fixture_path('default')) do |env|
      env.append_path("app")
      env.cache = @cache
    end

    assert_equal "jQuery;\n", env1["main.js"].to_s
    assert_equal "jQuery;\n", env1["jquery.js"].to_s

    assert_raises Sprockets::FileNotFound do
      env2["main.js"].to_s
    end
  end

  test "find cached with if-match before existing" do
    filename = fixture_path("default/tmp.js")

    foo_digest = bar_digest = nil

    sandbox filename do
      write(filename, "foo;")
      assert asset = @env1.find_asset(filename)
      assert foo_digest = asset.digest
      assert_equal "foo;\n", asset.to_s

      write(filename, "bar;")
      assert asset = @env1.find_asset(filename)
      assert bar_digest = asset.digest
      assert_equal "bar;\n", asset.to_s
    end

    refute_equal foo_digest, bar_digest
    reset

    sandbox filename do
      refute @env1.find_asset(filename, if_match: foo_digest)
      refute @env1.find_asset(filename, if_match: bar_digest)

      write(filename, "foo;\n")
      assert asset = @env1.find_asset(filename, if_match: foo_digest)
      assert_equal "foo;\n", asset.to_s

      refute @env1.find_asset(filename, if_match: bar_digest)

      write(filename, "bar;\n")
      refute @env1.find_asset(filename, if_match: foo_digest)

      assert asset = @env1.find_asset(filename, if_match: bar_digest)
      assert_equal "bar;\n", asset.to_s
    end
  end

  test "find cached with if-none-match before existing" do
    filename = fixture_path("default/tmp.js")

    foo_digest = bar_digest = nil

    sandbox filename do
      write(filename, "foo;")
      assert asset = @env1.find_asset(filename)
      assert foo_digest = asset.digest
      assert_equal "foo;\n", asset.to_s

      write(filename, "bar;")
      assert asset = @env1.find_asset(filename)
      assert bar_digest = asset.digest
      assert_equal "bar;\n", asset.to_s
    end

    refute_equal foo_digest, bar_digest
    reset

    sandbox filename do
      refute @env1.find_asset(filename, if_none_match: foo_digest)
      refute @env1.find_asset(filename, if_none_match: bar_digest)

      write(filename, "foo;\n")
      refute @env1.find_asset(filename, if_none_match: foo_digest)
      assert asset = @env1.find_asset(filename, if_none_match: bar_digest)
      assert_equal "foo;\n", asset.to_s

      write(filename, "bar;\n")
      assert asset = @env1.find_asset(filename, if_none_match: foo_digest)
      assert_equal "bar;\n", asset.to_s

      refute @env1.find_asset(filename, if_none_match: bar_digest)
    end
  end

  def write(filename, contents)
    if File.exist?(filename)
      File.open(filename, 'w') do |f|
        f.write(contents)
      end
      mtime = File.stat(filename).mtime.to_i + 1
      File.utime(mtime, mtime, filename)
    else
      File.open(filename, 'w') do |f|
        f.write(contents)
      end
    end
  end
end

require 'tmpdir'

class TestFileStoreCaching < Sprockets::TestCase
  def setup
    @cache = Sprockets::Cache::FileStore.new(Dir::tmpdir)

    @env1 = Sprockets::Environment.new(fixture_path('default')) do |env|
      env.append_path(".")
      env.cache = @cache
    end

    @env2 = Sprockets::Environment.new(fixture_path('default')) do |env|
      env.append_path(".")
      env.cache = @cache
    end
  end

  test "shared cache objects are eql" do
    asset1 = @env1['gallery.js']
    asset2 = @env2['gallery.js']

    assert asset1
    assert asset2

    assert asset1.eql?(asset2)
    assert asset2.eql?(asset1)
    assert !asset1.equal?(asset2)
  end
end

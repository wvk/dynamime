RAILS_ENV = 'test'
require File.expand_path(File.join(File.dirname(__FILE__), '../../../../config/environment.rb'))
require 'test/unit'
require '../../../test/test_helper.rb'

class DynamimeTest < Test::Unit::TestCase
  def setup
    Dynamime::Type.unregister :all
    Dynamime::Type.register :foo, :html,'text/foo'
    Dynamime::Type.register :mobile, :html, 'application/vnd.wap.xhtml+xml'
    Dynamime::Type.register :bar, :foo
    Dynamime::Type.register :baz, :bar, 'application/xhtml+xml'
    Dynamime::Type.register :bac, :bar
    Dynamime::Type.register :s60, :mobile
    Dynamime::Type.register :msie, :html, 'text/html'
  end

  def test_result_of_register_type_is_correct
    assert_equal :html, Dynamime::HTML.to_sym
    assert_equal :foo,  Dynamime::FOO.to_sym
    assert_equal :bar,  Dynamime::BAR.to_sym
    assert_equal 'application/xhtml+xml', Dynamime::HTML.to_s
    assert_equal 'text/foo', Dynamime::FOO.to_s
    assert_equal 'text/foo', Dynamime::BAR.to_s
    assert_equal 'application/xhtml+xml', Dynamime::BAZ.to_s
    assert_equal 'text/foo', Dynamime::BAC.to_s
  end

  def test_subtypes_for_returns_one_level_of_subtypes
    assert_equal [Dynamime::BAR], Dynamime::FOO.subtypes
    assert_equal [Dynamime::BAZ, Dynamime::BAC], Dynamime::BAR.subtypes
  end

  def test_supertype_for_returns_supertype
    assert_equal Dynamime::HTML, Dynamime::FOO.supertype
    assert_equal Dynamime::FOO,  Dynamime::BAR.supertype
    assert_equal Dynamime::BAR,  Dynamime::BAZ.supertype
    assert_equal Dynamime::HTML,  Dynamime::BAZ.toplevel_supertype
  end

  def test_supertypes_for_returns_all_supertypes
    assert_equal [Dynamime::BAR, Dynamime::FOO, Dynamime::HTML], Dynamime::BAZ.supertypes
    assert_equal [:bar, :foo, :html], Dynamime::BAZ.supertype_symbols
  end

  def test_subtype_of?
    assert Dynamime::BAR.subtype_of? :foo
    assert Dynamime::BAR.subtype_of? Dynamime::FOO
    assert Dynamime::BAZ.subtype_of? :bar
    assert Dynamime::BAZ.subtype_of? Dynamime::BAR
    assert Dynamime::BAZ.subtype_of? :foo
    assert Dynamime::BAZ.subtype_of? Dynamime::FOO
  end

  def xtest_lookup_by_match_should_match_correct_ua_string
    foo_ua     = 'Mozilla/5.0 (Foo; U; CPU like Mac OS X; en)'
    bar_ua     = 'foo/BAR (Bar; N; Linux; like Foo; de)'
    moz_ua     = 'Mozilla/9.876 (X11; U; Linux 2.2.12-20 i686, en) Gecko/25250101'
    obscure_ua = 'Fribblefrabble/13.42 (Foobar; U; Foonix 2.1.2 x86; fi)'
    s60_ua     = 'Mozilla/5.0 (SymbianOS/9.3; Series60/3.2 NokiaN96-1/1.00; Profile/MIDP-2.1 Configuration/CLDC-1.1;) AppleWebKit/413 (KHTML, like Gecko) Safari/413'

    assert_equal Dynamime::FOO,  Dynamime::Type.lookup_by_match(foo_ua)
    assert_equal Dynamime::BAR,  Dynamime::Type.lookup_by_match(bar_ua)
    assert_equal Dynamime::HTML, Dynamime::Type.lookup_by_match(moz_ua)
    assert_equal Dynamime::HTML, Dynamime::Type.lookup_by_match(obscure_ua)
    assert_equal Dynamime::S60,  Dynamime::Type.lookup_by_match(s60_ua)
    assert_equal 2, Dynamime::Type.possible_matches_for(s60_ua).size
  end

  def test_unregistering_registered_mime_type_succeeds
    assert Dynamime::Type.exists?(:foo), 'mime type foo should exist'
    assert defined? Dynamime::FOO, 'mime type foo should be defined'

    Dynamime::Type.unregister(:foo)

    assert !Dynamime::Type.exists?(:foo), 'mime type foo should not exist anymore'
    assert !defined? Dynamime::FOO, 'mime type foo should not be defined anymore'
  end

  def test_unregistering_all_mime_types_succeeds
    assert Dynamime::Type.exists?(:foo), 'mime type :foo should exist'
    assert Dynamime::Type.exists?(:bar), 'mime type :bar should exist'
    assert Dynamime::Type.exists?(:mobile), 'mime type :mobile should exist'
    Dynamime::Type.unregister(:all)
    assert !Dynamime::Type.exists?(:foo), 'mime type :foo should not exist any more'
    assert !Dynamime::Type.exists?(:bar), 'mime type :bar should not exist any more'
    assert !Dynamime::Type.exists?(:mobile), 'mime type :bar should not exist any more'
  end

  def test_mime_const_equals_dynamime_lookup
    assert Dynamime::Type.exists?(:foo), 'mime type foo should exist'
    assert_equal Dynamime::FOO, Dynamime::Type.lookup_by_extension('foo')
    assert_equal Dynamime::FOO, Dynamime::Type.lookup('text/foo')
  end
end

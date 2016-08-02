require_relative "../lib/rgfa.rb"
require "test/unit"

class TestRGFAEdit < Test::Unit::TestCase

  def test_delete_sequences
    gfa = RGFA.new
    seqs = ["ACCAGCTAGCGAGC", "CGCTAGTGCTG", "GCTAGCTAG"]
    seqs.each_with_index {|seq, i| gfa << "S\t#{i}\t#{seq}" }
    assert_equal(seqs, gfa.segments.map{|s|s.sequence})
    gfa.delete_sequences
    assert_equal(["*","*","*"], gfa.segments.map{|s|s.sequence})
    gfa = RGFA.new
    seqs = ["ACCAGCTAGCGAGC", "CGCTAGTGCTG", "GCTAGCTAG"]
    seqs.each_with_index {|seq, i| gfa << "S\t#{i}\t#{seq}" }
    gfa.rm(:sequences)
    assert_equal(["*","*","*"], gfa.segments.map{|s|s.sequence})
  end

  def test_delete_alignments
    gfa = ["S\t0\t*", "S\t1\t*", "S\t2\t*", "L\t2\t-\t1\t-\t12M",
    "L\t2\t+\t0\t-\t12M", "L\t0\t-\t1\t+\t12M",
    "C\t1\t+\t0\t+\t12\t12M", "P\t4\t2+,0-,1+\t12M,12M,12M"].to_rgfa
    assert_equal([RGFA::CIGAR::Operation.new(12,:M)], gfa.links[0].overlap)
    assert_equal([RGFA::CIGAR::Operation.new(12,:M)],
                 gfa.containments[0].overlap)
    assert_equal([[RGFA::CIGAR::Operation.new(12,:M)],
                  [RGFA::CIGAR::Operation.new(12,:M)],
                  [RGFA::CIGAR::Operation.new(12,:M)]], gfa.paths[0].cigars)
    gfa.delete_alignments
    assert_equal([], gfa.links[0].overlap)
    assert_equal([], gfa.containments[0].overlap)
    assert_equal([[],[],[]], gfa.paths[0].cigars)
    gfa = ["S\t0\t*", "S\t1\t*", "S\t2\t*", "L\t2\t-\t1\t-\t12M",
    "L\t2\t+\t0\t-\t12M", "L\t0\t-\t1\t+\t12M",
    "C\t1\t+\t0\t+\t12\t12M", "P\t4\t2+,0-,1+\t12M,12M,12M"].to_rgfa
    gfa.rm(:alignments)
    assert_equal([], gfa.links[0].overlap)
    assert_equal([], gfa.containments[0].overlap)
    assert_equal([[],[],[]], gfa.paths[0].cigars)
  end

  def test_rename
    gfa = ["S\t0\t*", "S\t1\t*", "S\t2\t*", "L\t0\t+\t2\t-\t12M",
    "C\t1\t+\t0\t+\t12\t12M", "P\t4\t2+,0-\t12M"].to_rgfa
    gfa.rename("0", "X")
    assert_equal([:"X", :"1", :"2"].sort, gfa.segment_names.sort)
    assert_equal("L\tX\t+\t2\t-\t12M", gfa.links[0].to_s)
    assert_equal("C\t1\t+\tX\t+\t12\t12M", gfa.containments[0].to_s)
    assert_equal("P\t4\t2+,X-\t12M", gfa.paths[0].to_s)
    assert_nothing_raised { gfa.send(:validate_connect) }
    assert_equal([], gfa.links_of(["0", :E]))
    assert_equal("L\tX\t+\t2\t-\t12M", gfa.links_of(["X", :E])[0].to_s)
    assert_equal("C\t1\t+\tX\t+\t12\t12M", gfa.contained_in("1")[0].to_s)
    assert_equal([], gfa.containing("0"))
    assert_equal("C\t1\t+\tX\t+\t12\t12M", gfa.containing("X")[0].to_s)
    assert_equal([], gfa.paths_with("0"))
    assert_equal("P\t4\t2+,X-\t12M", gfa.paths_with("X")[0].to_s)
  end

  def test_multiply_segment
    gfa = RGFA.new
    gfa << "H\tVN:Z:1.0"
    s = ["S\t0\t*\tRC:i:600".to_rgfa_line,
         "S\t1\t*\tRC:i:6000".to_rgfa_line,
         "S\t2\t*\tRC:i:60000".to_rgfa_line]
    l = "L\t1\t+\t2\t+\t12M".to_rgfa_line
    c = "C\t1\t+\t0\t+\t12\t12M".to_rgfa_line
    p = "P\t3\t2+,0-\t12M".to_rgfa_line
    (s + [l,c,p]).each {|line| gfa << line }
    assert_equal(s, gfa.segments)
    assert_equal([l], gfa.links)
    assert_equal([c], gfa.containments)
    assert_equal(l, gfa.link(["1", :E], ["2", :B]))
    assert_equal(c, gfa.containment("1", "0"))
    assert_equal(nil, gfa.link(["1a", :E], ["2", :B]))
    assert_equal(nil, gfa.containment("5", "0"))
    assert_equal(6000, gfa.segment("1").RC)
    gfa.multiply("1", 2)
    assert_nothing_raised { gfa.send(:validate_connect) }
    assert_equal(l, gfa.link(["1", :E], ["2", :B]))
    assert_equal(c, gfa.containment("1", "0"))
    assert_not_equal(nil, gfa.link(["1b", :E], ["2", :B]))
    assert_not_equal(nil, gfa.containment("1b", "0"))
    assert_equal(3000, gfa.segment("1").RC)
    assert_equal(3000, gfa.segment("1b").RC)
    gfa.multiply("1b", 3 , copy_names:["6","7"])
    assert_nothing_raised { gfa.send(:validate_connect) }
    assert_equal(l, gfa.link(["1", :E], ["2", :B]))
    assert_not_equal(nil, gfa.link(["1b", :E], ["2", :B]))
    assert_not_equal(nil, gfa.link(["6", :E], ["2", :B]))
    assert_not_equal(nil, gfa.link(["7", :E], ["2", :B]))
    assert_not_equal(nil, gfa.containment("1b", "0"))
    assert_not_equal(nil, gfa.containment("6", "0"))
    assert_not_equal(nil, gfa.containment("7", "0"))
    assert_equal(3000, gfa.segment("1").RC)
    assert_equal(1000, gfa.segment("1b").RC)
    assert_equal(1000, gfa.segment("6").RC)
    assert_equal(1000, gfa.segment("7").RC)
  end

  def test_multiply_segment_copy_names
    gfa = ["H\tVN:Z:1.0",
           "S\t1\t*\tRC:i:600",
           "S\t1b\t*\tRC:i:6000",
           "S\t2\t*\tRC:i:60000",
           "S\t3\t*\tRC:i:60000"].to_rgfa
    gfa.multiply("2", 2, copy_names: :upcase)
    assert_nothing_raised {gfa.segment!("2B")}
    gfa.multiply("2", 2, copy_names: :upcase)
    assert_nothing_raised {gfa.segment!("2C")}
    gfa.multiply("2", 2, copy_names: :copy)
    assert_nothing_raised {gfa.segment!("2_copy")}
    gfa.multiply("2", 2, copy_names: :copy)
    assert_nothing_raised {gfa.segment!("2_copy2")}
    gfa.multiply("2", 2, copy_names: :copy)
    assert_nothing_raised {gfa.segment!("2_copy3")}
    gfa.multiply("2_copy", 2, copy_names: :copy)
    assert_nothing_raised {gfa.segment!("2_copy4")}
    gfa.multiply("2_copy4", 2, copy_names: :copy)
    assert_nothing_raised {gfa.segment!("2_copy5")}
    gfa.multiply("2", 2, copy_names: :number)
    assert_nothing_raised {gfa.segment!("4")}
    gfa.multiply("1b", 2)
    assert_nothing_raised {gfa.segment!("1c")}
    gfa.multiply("1b", 2, copy_names: :number)
    assert_nothing_raised {gfa.segment!("1b2")}
    gfa.multiply("1b", 2, copy_names: :copy)
    assert_nothing_raised {gfa.segment!("1b_copy")}
    gfa.multiply("1b_copy", 2, copy_names: :lowcase)
    assert_nothing_raised {gfa.segment!("1b_copz")}
    gfa.multiply("1b_copy", 2, copy_names: :upcase)
    assert_nothing_raised {gfa.segment!("1b_copyB")}
  end

end
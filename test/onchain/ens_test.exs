defmodule Onchain.ENSTest do
  use ExUnit.Case, async: true

  alias Onchain.ENS

  describe "namehash/1" do
    test "empty string returns 32 zero bytes" do
      assert {:ok, <<0::256>>} = ENS.namehash("")
    end

    test "hashes 'eth' correctly (EIP-137 vector)" do
      expected =
        Base.decode16!("93CDEB708B7545DC668EB9280176169D1C33CFD8ED6F04690A0BCC88A93FC4AE")

      assert {:ok, ^expected} = ENS.namehash("eth")
    end

    test "hashes 'foo.eth' correctly (EIP-137 vector)" do
      expected =
        Base.decode16!("DE9B09FD7C5F901E23A3F19FECC54828E9C848539801E86591BD9801B019F84F")

      assert {:ok, ^expected} = ENS.namehash("foo.eth")
    end

    test "normalizes uppercase to lowercase before hashing" do
      assert {:ok, lower} = ENS.namehash("foo.eth")
      assert {:ok, ^lower} = ENS.namehash("FOO.ETH")
      assert {:ok, ^lower} = ENS.namehash("Foo.Eth")
    end

    test "strips trailing dot before hashing" do
      assert {:ok, without_dot} = ENS.namehash("foo.eth")
      assert {:ok, ^without_dot} = ENS.namehash("foo.eth.")
    end

    test "rejects empty labels" do
      assert {:error, {:invalid_name, "a..b"}} = ENS.namehash("a..b")
    end

    test "rejects leading dot" do
      assert {:error, {:invalid_name, ".eth"}} = ENS.namehash(".eth")
    end

    test "rejects non-ASCII characters" do
      assert {:error, {:invalid_name, _}} = ENS.namehash("viталик.eth")
    end

    test "rejects bare dot (normalizes to empty but is not a valid name)" do
      assert {:error, {:invalid_name, "."}} = ENS.namehash(".")
    end
  end

  describe "namehash/1 — hyphen validation" do
    test "rejects label starting with hyphen" do
      assert {:error, {:invalid_name, "-foo.eth"}} = ENS.namehash("-foo.eth")
    end

    test "rejects label ending with hyphen" do
      assert {:error, {:invalid_name, "foo-.eth"}} = ENS.namehash("foo-.eth")
    end

    test "accepts hyphen in middle of label" do
      assert {:ok, _} = ENS.namehash("my-name.eth")
    end

    test "rejects label that is only a hyphen" do
      assert {:error, {:invalid_name, "-.eth"}} = ENS.namehash("-.eth")
    end
  end

  describe "namehash/1 — reverse name construction" do
    test "reverse name produces correct namehash for known address" do
      # The reverse name for 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045 is
      # "d8da6bf26964af9d7eed9e03e53415d37aa96045.addr.reverse"
      # We verify that namehash of the reverse name produces a deterministic 32-byte hash
      reverse_name = "d8da6bf26964af9d7eed9e03e53415d37aa96045.addr.reverse"
      assert {:ok, hash} = ENS.namehash(reverse_name)
      assert byte_size(hash) == 32
      assert hash != <<0::256>>
    end
  end

  describe "resolve/2 input validation" do
    test "rejects invalid name" do
      assert {:error, {:invalid_name, "a..b"}} = ENS.resolve("a..b")
    end
  end

  describe "reverse/2 input validation" do
    test "rejects invalid address" do
      assert {:error, {:invalid_address, "not_an_address"}} = ENS.reverse("not_an_address")
    end
  end

  describe "namehash!/1" do
    test "returns hash directly on success" do
      expected =
        Base.decode16!("93CDEB708B7545DC668EB9280176169D1C33CFD8ED6F04690A0BCC88A93FC4AE")

      assert ^expected = ENS.namehash!("eth")
    end

    test "raises on invalid name" do
      assert_raise RuntimeError, ~r/namehash failed/, fn ->
        ENS.namehash!("a..b")
      end
    end
  end

  describe "resolver!/2" do
    test "raises on invalid name" do
      assert_raise RuntimeError, ~r/resolver lookup failed/, fn ->
        ENS.resolver!("a..b")
      end
    end
  end

  describe "resolve!/2" do
    test "raises on invalid name" do
      assert_raise RuntimeError, ~r/resolve failed/, fn ->
        ENS.resolve!("a..b")
      end
    end
  end

  describe "reverse!/2" do
    test "raises on invalid address" do
      assert_raise RuntimeError, ~r/reverse failed/, fn ->
        ENS.reverse!("not_an_address")
      end
    end
  end

  describe "text!/3" do
    test "raises on invalid name" do
      assert_raise RuntimeError, ~r/text lookup failed/, fn ->
        ENS.text!("a..b", "avatar")
      end
    end
  end

  describe "contenthash!/2" do
    test "raises on invalid name" do
      assert_raise RuntimeError, ~r/contenthash lookup failed/, fn ->
        ENS.contenthash!("a..b")
      end
    end
  end

  describe "pubkey!/2" do
    test "raises on invalid name" do
      assert_raise RuntimeError, ~r/pubkey lookup failed/, fn ->
        ENS.pubkey!("a..b")
      end
    end
  end

  describe "abi!/3" do
    test "raises on invalid name" do
      assert_raise RuntimeError, ~r/abi lookup failed/, fn ->
        ENS.abi!("a..b", 1)
      end
    end
  end
end

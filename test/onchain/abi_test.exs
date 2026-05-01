defmodule Onchain.ABITest do
  use ExUnit.Case, async: true

  alias Cartouche.Hex.InvalidHex
  alias Onchain.ABI

  describe "encode_call/2" do
    test "encodes balanceOf(address) with valid 20-byte address" do
      addr = <<1::160>>
      assert {:ok, "0x70a08231" <> _params} = ABI.encode_call("balanceOf(address)", [addr])
    end

    test "encodes totalSupply() with empty params (4-byte selector only)" do
      assert {:ok, hex} = ABI.encode_call("totalSupply()", [])
      # 4-byte selector = 8 hex chars + "0x" prefix
      assert hex == "0x18160ddd"
    end

    test "encodes function with multiple params baz(uint256,bool)" do
      assert {:ok, "0x" <> hex_body} = ABI.encode_call("baz(uint256,bool)", [10, true])
      # 4-byte selector + 2 × 32-byte params = 68 bytes = 136 hex chars
      assert byte_size(hex_body) == 136
    end

    test "returns error for invalid signature" do
      assert {:error, {:encode_error, _reason}} = ABI.encode_call("???invalid", [])
    end

    test "returns error for data overflow (uint8 with 9999)" do
      assert {:error, {:encode_error, reason}} = ABI.encode_call("foo(uint8)", [9999])
      assert reason =~ "overflow"
    end

    test "returns error for wrong param count" do
      assert {:error, {:encode_error, _reason}} =
               ABI.encode_call("balanceOf(address)", [<<1::160>>, <<2::160>>])
    end
  end

  describe "encode_call!/2" do
    test "returns hex string for valid call" do
      assert "0x70a08231" <> _ = ABI.encode_call!("balanceOf(address)", [<<1::160>>])
    end

    test "raises on invalid signature" do
      assert_raise MatchError, fn ->
        ABI.encode_call!("???invalid", [])
      end
    end
  end

  describe "decode_response/2" do
    test "decodes single uint256" do
      hex = "0x" <> String.duplicate("0", 62) <> "0a"
      assert {:ok, [10]} = ABI.decode_response("(uint256)", hex)
    end

    test "decodes multiple return values (uint256,uint256)" do
      hex = "0x" <> String.duplicate("0", 62) <> "0a" <> String.duplicate("0", 62) <> "14"
      assert {:ok, [10, 20]} = ABI.decode_response("(uint256,uint256)", hex)
    end

    test "decodes address (returns 20-byte binary)" do
      addr = <<1::160>>
      padded = "0x" <> String.duplicate("0", 24) <> Base.encode16(addr, case: :lower)
      assert {:ok, [^addr]} = ABI.decode_response("(address)", padded)
    end

    test "decodes bool" do
      true_hex = "0x" <> String.duplicate("0", 62) <> "01"
      false_hex = "0x" <> String.duplicate("0", 64)
      assert {:ok, [true]} = ABI.decode_response("(bool)", true_hex)
      assert {:ok, [false]} = ABI.decode_response("(bool)", false_hex)
    end

    test "returns error for invalid hex" do
      assert {:error, {:decode_error, {:invalid_hex, "0xzzzz"}}} =
               ABI.decode_response("(uint256)", "0xzzzz")
    end

    test "returns error for truncated data" do
      assert {:error, {:decode_error, _reason}} = ABI.decode_response("(uint256)", "0x0102")
    end
  end

  describe "decode_response!/2" do
    test "returns decoded list for valid data" do
      hex = "0x" <> String.duplicate("0", 62) <> "0a"
      assert [10] = ABI.decode_response!("(uint256)", hex)
    end

    test "raises on invalid hex" do
      assert_raise InvalidHex, fn ->
        ABI.decode_response!("(uint256)", "0xzzzz")
      end
    end

    test "raises on malformed ABI data" do
      assert_raise MatchError, fn ->
        ABI.decode_response!("(uint256)", "0x0102")
      end
    end
  end

  describe "roundtrip" do
    test "encode params, strip selector, decode back recovers original values" do
      assert {:ok, calldata} = ABI.encode_call("baz(uint256,bool)", [42, true])
      # Strip 4-byte (8 hex char) selector + "0x" prefix, re-add "0x"
      params_hex = "0x" <> String.slice(calldata, 10..-1//1)
      assert {:ok, [42, true]} = ABI.decode_response("(uint256,bool)", params_hex)
    end
  end

  describe "decode_types/2 (alias of decode_response/2)" do
    test "matches decode_response/2 on success" do
      hex = "0x" <> String.duplicate("0", 62) <> "0a"
      assert ABI.decode_types("(uint256)", hex) == ABI.decode_response("(uint256)", hex)
      assert {:ok, [10]} = ABI.decode_types("(uint256)", hex)
    end

    test "matches decode_response/2 on multi-value decoding" do
      hex = "0x" <> String.duplicate("0", 62) <> "0a" <> String.duplicate("0", 62) <> "14"
      assert ABI.decode_types("(uint256,uint256)", hex) == ABI.decode_response("(uint256,uint256)", hex)
      assert {:ok, [10, 20]} = ABI.decode_types("(uint256,uint256)", hex)
    end

    test "matches decode_response/2 on invalid hex" do
      assert ABI.decode_types("(uint256)", "0xzzzz") == ABI.decode_response("(uint256)", "0xzzzz")

      assert {:error, {:decode_error, {:invalid_hex, "0xzzzz"}}} =
               ABI.decode_types("(uint256)", "0xzzzz")
    end

    test "matches decode_response/2 on truncated data" do
      assert ABI.decode_types("(uint256)", "0x0102") == ABI.decode_response("(uint256)", "0x0102")
      assert {:error, {:decode_error, _reason}} = ABI.decode_types("(uint256)", "0x0102")
    end
  end

  describe "decode_types!/2 (alias of decode_response!/2)" do
    test "returns decoded list for valid data" do
      hex = "0x" <> String.duplicate("0", 62) <> "0a"
      assert [10] = ABI.decode_types!("(uint256)", hex)
      assert ABI.decode_types!("(uint256)", hex) == ABI.decode_response!("(uint256)", hex)
    end

    test "raises on invalid hex" do
      assert_raise InvalidHex, fn ->
        ABI.decode_types!("(uint256)", "0xzzzz")
      end
    end

    test "raises on malformed ABI data" do
      assert_raise MatchError, fn ->
        ABI.decode_types!("(uint256)", "0x0102")
      end
    end
  end
end

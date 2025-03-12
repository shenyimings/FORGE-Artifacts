// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { BaseTest } from "../../base/BaseTest.sol";
import { P88 } from "../../../tokens/P88.sol";
import { LZBridgeStrategy } from "../../../tokens/bridge-strategies/LZBridgeStrategy.sol";
import { LZBridgeReceiver } from "../../../tokens/bridge-receiver/LZBridgeReceiver.sol";
import { MockLZEndpoint } from "src/tests/mocks/MockLZEndpoint.sol";

contract BridgeableToken is BaseTest {
  P88 internal p88OnETH;
  P88 internal p88OnPolygon;
  LZBridgeStrategy internal bridgeStratOnETH;
  LZBridgeReceiver internal bridgeReceiverOnETH;
  LZBridgeStrategy internal bridgeStratOnPolygon;
  LZBridgeReceiver internal bridgeReceiverOnPolygon;

  MockLZEndpoint internal lzEndpoint;

  uint256 internal constant ETHEREUM_CHAIN_ID = 1;
  uint256 internal constant POLYGON_CHAIN_ID = 156;

  function setUp() public virtual {
    p88OnETH = new P88(false);
    p88OnPolygon = new P88(true);

    lzEndpoint = new MockLZEndpoint();

    bridgeStratOnETH = new LZBridgeStrategy(address(lzEndpoint));
    bridgeReceiverOnETH = new LZBridgeReceiver(
      address(lzEndpoint),
      address(p88OnETH)
    );

    bridgeStratOnPolygon = new LZBridgeStrategy(address(lzEndpoint));
    bridgeReceiverOnPolygon = new LZBridgeReceiver(
      address(lzEndpoint),
      address(p88OnPolygon)
    );

    uint256[] memory destChainIds = new uint256[](1);
    destChainIds[0] = POLYGON_CHAIN_ID;
    address[] memory destContracts = new address[](1);
    destContracts[0] = address(bridgeReceiverOnPolygon);
    bridgeStratOnETH.setDestinationTokenContracts(destChainIds, destContracts);
    destChainIds[0] = ETHEREUM_CHAIN_ID;
    destContracts[0] = address(bridgeReceiverOnETH);
    bridgeStratOnPolygon.setDestinationTokenContracts(
      destChainIds,
      destContracts
    );

    uint16[] memory srcChainIds = new uint16[](1);
    srcChainIds[0] = uint16(POLYGON_CHAIN_ID);
    bytes[] memory remoteAddresses = new bytes[](1);
    remoteAddresses[0] = abi.encode(address(bridgeStratOnPolygon));
    bridgeReceiverOnETH.setTrustedRemotes(srcChainIds, remoteAddresses);
    srcChainIds[0] = uint16(ETHEREUM_CHAIN_ID);
    remoteAddresses[0] = abi.encode(address(bridgeStratOnETH));
    bridgeReceiverOnPolygon.setTrustedRemotes(srcChainIds, remoteAddresses);

    p88OnETH.setMinter(address(this), true);
    p88OnETH.setBridge(address(bridgeReceiverOnETH), true);
    p88OnPolygon.setBridge(address(bridgeReceiverOnPolygon), true);

    p88OnETH.setBridgeStrategy(address(bridgeStratOnETH), true);
    p88OnPolygon.setBridgeStrategy(address(bridgeStratOnPolygon), true);
  }

  function testCorrectness_bridgeTokenFromETHToPolygon() external {
    p88OnETH.mint(ALICE, 1 ether);

    lzEndpoint.setSource(
      uint16(ETHEREUM_CHAIN_ID),
      abi.encode(bridgeStratOnETH)
    );

    vm.startPrank(ALICE);
    p88OnETH.bridgeToken(
      POLYGON_CHAIN_ID,
      BOB,
      1 ether,
      address(bridgeStratOnETH),
      abi.encode(0)
    );
    vm.stopPrank();

    assertEq(
      p88OnPolygon.balanceOf(BOB),
      1 ether,
      "Bob should receive the bridged token."
    );
    assertEq(
      p88OnETH.balanceOf(ALICE),
      0 ether,
      "Alice should not have any P88 left, as she bridged all her token."
    );
    assertEq(
      p88OnETH.balanceOf(address(p88OnETH)),
      1 ether,
      "Bridged P88 should be locked on Ethereum."
    );
  }

  function testCorrectness_bridgeTokenFromPolygonBackToETH() external {
    p88OnETH.mint(ALICE, 1 ether);

    lzEndpoint.setSource(
      uint16(ETHEREUM_CHAIN_ID),
      abi.encode(bridgeStratOnETH)
    );

    vm.startPrank(ALICE);
    p88OnETH.bridgeToken(
      POLYGON_CHAIN_ID,
      BOB,
      1 ether,
      address(bridgeStratOnETH),
      abi.encode(0)
    );
    vm.stopPrank();

    assertEq(p88OnPolygon.balanceOf(BOB), 1 ether);

    lzEndpoint.setSource(
      uint16(POLYGON_CHAIN_ID),
      abi.encode(bridgeStratOnPolygon)
    );

    vm.startPrank(BOB);
    p88OnPolygon.bridgeToken(
      ETHEREUM_CHAIN_ID,
      ALICE,
      0.5 ether,
      address(bridgeStratOnPolygon),
      abi.encode(0)
    );
    vm.stopPrank();

    assertEq(
      p88OnETH.balanceOf(ALICE),
      0.5 ether,
      "Alice should receive the bridged token."
    );
    assertEq(
      p88OnPolygon.balanceOf(BOB),
      0.5 ether,
      "Bob should have half of his token left, as he bridge the other half to Alice."
    );
    assertEq(
      p88OnPolygon.balanceOf(address(p88OnPolygon)),
      0 ether,
      "P88 should be burnt on Polygon."
    );
    assertEq(
      p88OnETH.balanceOf(address(p88OnETH)),
      0.5 ether,
      "P88 should be transferred from the locked token on Ethereum, not newly minted."
    );
    assertEq(
      p88OnETH.totalSupply(),
      1 ether,
      "Total supply on ETH should stay the same."
    );
  }

  function testRevert_BadStrategy() external {
    p88OnETH.mint(ALICE, 1 ether);
    vm.startPrank(ALICE);

    vm.expectRevert(
      abi.encodeWithSignature("BaseBridgeableToken_BadStrategy()")
    );
    p88OnETH.bridgeToken(
      POLYGON_CHAIN_ID,
      BOB,
      1 ether,
      address(1),
      abi.encode(0)
    );
    vm.stopPrank();
  }

  function testRevert_UnknownChainId() external {
    p88OnETH.mint(ALICE, 1 ether);

    lzEndpoint.setSource(
      uint16(ETHEREUM_CHAIN_ID),
      abi.encode(bridgeStratOnETH)
    );

    vm.startPrank(ALICE);
    vm.expectRevert(
      abi.encodeWithSignature("LZBridgeStrategy_UnknownChainId()")
    );
    p88OnETH.bridgeToken(
      0,
      BOB,
      1 ether,
      address(bridgeStratOnETH),
      abi.encode(0)
    );
    vm.stopPrank();
  }

  function testRevert_InvalidSource() external {
    p88OnETH.mint(ALICE, 1 ether);

    lzEndpoint.setSource(
      uint16(ETHEREUM_CHAIN_ID),
      abi.encode(bridgeStratOnETH)
    );

    uint16[] memory srcChainIds = new uint16[](1);
    bytes[] memory remoteAddresses = new bytes[](1);
    srcChainIds[0] = uint16(ETHEREUM_CHAIN_ID);
    remoteAddresses[0] = abi.encode(address(0));
    bridgeReceiverOnPolygon.setTrustedRemotes(srcChainIds, remoteAddresses);

    vm.startPrank(ALICE);
    vm.expectRevert(
      abi.encodeWithSignature("LZBridgeReceiver_InvalidSource()")
    );
    p88OnETH.bridgeToken(
      POLYGON_CHAIN_ID,
      BOB,
      1 ether,
      address(bridgeStratOnETH),
      abi.encode(0)
    );
    vm.stopPrank();
  }

  function testCorrectness_exploitOnPolygon() external {
    p88OnETH.mint(ALICE, 1000 ether);

    lzEndpoint.setSource(
      uint16(ETHEREUM_CHAIN_ID),
      abi.encode(bridgeStratOnETH)
    );

    vm.startPrank(ALICE);
    p88OnETH.bridgeToken(
      POLYGON_CHAIN_ID,
      BOB,
      1 ether,
      address(bridgeStratOnETH),
      abi.encode(0)
    );
    vm.stopPrank();

    assertEq(p88OnPolygon.balanceOf(BOB), 1 ether);

    lzEndpoint.setSource(
      uint16(POLYGON_CHAIN_ID),
      abi.encode(bridgeStratOnPolygon)
    );

    // Hacker mint the full supply
    p88OnPolygon.setMinter(address(this), true);
    p88OnPolygon.mint(BOB, 999_999 ether);

    vm.startPrank(BOB);
    p88OnPolygon.bridgeToken(
      ETHEREUM_CHAIN_ID,
      ALICE,
      1_000_000 ether,
      address(bridgeStratOnPolygon),
      abi.encode(0)
    );
    vm.stopPrank();

    assertEq(p88OnETH.totalSupply(), 1000 ether);
  }
}

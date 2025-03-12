// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "./Config.sol";
import "./MathMock.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../_mock/MockDecimals18ERC20.sol";

/// @title A BaseTest serves as an abtraction for the testing contract containing all foundry testing functionalities.
/// @author Powaa's engineering team
/**
  @dev please try to use the testing doubles based on these following rules - credit: Martin Fowler's test doubles
  - Dummy: objects are passed around but never actually used. Usually they are just used to fill parameter lists.
  - Fake: objects actually have working implementations, but usually take some shortcut which makes them not suitable for production (an in memory database is a good example).
  - Stubs: provide canned answers to calls made during the test, usually not responding at all to anything outside what's programmed in for the test.
  - Spies: are stubs that also record some information based on how they were called. One form of this might be an email service that records how many messages it was sent.
  - Mocks: very similar to stubs, but interaction-based rather than state-based. It simulates the behavior of the original object, and also records some information about how it was called.
 */
abstract contract BaseTest is Test, Config {
  using Strings for uint256;

  /// @dev EVM init state
  uint64 public constant INIT_BLOCK_NUMBER = 15300000;
  uint64 public constant INIT_BLOCK_TIMESTAMP = 1659940505;

  /// @dev Test utils
  MathMock internal mathMock;
  ProxyAdmin internal proxyAdmin;

  /// @dev Accounts
  address public constant ALICE = address(111);
  address public constant BOB = address(112);
  address public constant CAT = address(113);
  address public constant EVE = address(114);

  /// @dev Configurable consts
  uint256 public constant POWAA_TOTAL_SUPPLY = 1000000000 ether;

  /// @dev POWAA contracts
  ERC20 public POWAAToken;

  /// @dev 3rd-party contracts
  ERC20 public USDC;
  ERC20 public USDT;
  ERC20 public DAI;
  ERC20 public WETH9;
  ERC20 public USDC_ETH_SUSHI_LP;
  ERC20 public USDT_ETH_SUSHI_LP;

  constructor() {
    proxyAdmin = _setupProxyAdmin();
    mathMock = _setupMathMock();
  }

  /// @dev Foundry's setUp method
  function setUp() public virtual {
    // assert init block number & block timestamp
    assertEq(block.number, INIT_BLOCK_NUMBER);
    assertEq(block.timestamp, INIT_BLOCK_TIMESTAMP);

    // setup: wrap addresses to entities
    USDC = ERC20(USDC_ADDRESS);
    USDT = ERC20(USDT_ADDRESS);
    WETH9 = ERC20(WETH9_ADDRESS);
    USDC_ETH_SUSHI_LP = ERC20(USDC_ETH_SUSHI_LP_ADDRESS);
    USDT_ETH_SUSHI_LP = ERC20(USDT_ETH_SUSHI_LP_ADDRESS);

    // deploy: POWAA
    POWAAToken = _setupPOWAAToken(POWAA_TOTAL_SUPPLY);
  }

  // █░█ ▀█▀ █ █░░ █▀
  // █▄█ ░█░ █ █▄▄ ▄█

  function _setupPOWAAToken(uint256 _maxTotalSupply) internal returns (ERC20) {
    MockDecimals18ERC20 _POWAAToken = new MockDecimals18ERC20(
      "POWAA token",
      "POWAA"
    );
    _POWAAToken.mint(address(this), _maxTotalSupply);
    return ERC20(_POWAAToken);
  }

  function _setupProxyAdmin() internal returns (ProxyAdmin) {
    return new ProxyAdmin();
  }

  function _setupMathMock() internal returns (MathMock) {
    return new MathMock();
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {Vm} from "forge-std/Vm.sol";

import {MockProtocol} from "test/mock/MockProtocol.sol";

import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ILlamaRelativeStrategyBase} from "src/interfaces/ILlamaRelativeStrategyBase.sol";
import {ILlamaCore} from "src/interfaces/ILlamaCore.sol";
import {ILlamaExecutor} from "src/interfaces/ILlamaExecutor.sol";
import {ILlamaLens} from "src/interfaces/ILlamaLens.sol";
import {ILlamaPolicy} from "src/interfaces/ILlamaPolicy.sol";

contract LlamaPeripheryTestSetup is Test {
  string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL"); // can't use constant here

  // Llama's Llama instance.
  ILlamaCore constant CORE = ILlamaCore(0x688576dC6b1AbaEe1d7Ee2B7c41Ee5D81BFD293c);
  ILlamaExecutor constant EXECUTOR = ILlamaExecutor(0xdAf00E9786cABB195a8a1Cf102730863aE94Dd75);
  ILlamaPolicy constant POLICY = ILlamaPolicy(0x07CCDBF8bC642007D001CB1F412733A529bE3B04);
  ILlamaAccount constant ACCOUNT = ILlamaAccount(0xf147B323B00bE213FBB4F5cC148FD611a02D8845);
  ILlamaStrategy constant STRATEGY = ILlamaStrategy(0xeE1695FEbA09ADeC2bFb6ADd963A51cF119fF4Fb);
  ILlamaLens constant LENS = ILlamaLens(0x1D74803D4939aFa3CC9fF1B8667bE4d119d925cB);
  address constant RELATIVE_QUANTITY_QUORUM_LOGIC = 0x81F7D26fD7d814bFcEF78239a32c0BA5282C98Dc;

  uint8 public constant CORE_TEAM_ROLE = 1;

  // llama core team members.
  address coreTeam1 = 0x2beC65F165cB63Ca2aa07CC14fE5915EAF6fc294;
  address coreTeam2 = 0x475B3Ca8763e0Fa601dDC47162bD1F87dF465872;
  address coreTeam3 = 0xe56f23CbD1B1071B0540E5068d699f3f071b75a4;
  address coreTeam4 = 0x6b45E38c87bfCa15ee90AAe2AFe3CFC58cE08F75;
  address coreTeam5 = 0xbdfcE43E5D2C7AA8599290d940c9932B8dBC94Ca;

  // This is the address that we're using to deploy modules. It could be
  // replaced with any address that we hold the private key for.
  address LLAMA_MODULE_DEPLOYER = 0x3d9fEa8AeD0249990133132Bb4BC8d07C6a8259a;

  // Mock protocol for action targets.
  MockProtocol public mockProtocol;

  // Function selectors used in tests.
  bytes4 public constant PAUSE_SELECTOR = MockProtocol.pause.selector; // pause(bool)

  // Othes constants.
  uint96 DEFAULT_ROLE_QTY = 1;
  uint96 EMPTY_ROLE_QTY = 0;
  uint64 DEFAULT_ROLE_EXPIRATION = type(uint64).max;

  function setUp() public virtual {
    vm.createSelectFork(MAINNET_RPC_URL, 18_707_845);

    // We deploy the mock protocol to be used as a Target.
    mockProtocol = new MockProtocol(address(EXECUTOR));
  }

  function mineBlock() internal {
    vm.roll(block.number + 1);
    vm.warp(block.timestamp + 1);
  }

  function encodeStrategyConfigs(ILlamaRelativeStrategyBase.Config[] memory strategies)
    internal
    pure
    returns (bytes[] memory encoded)
  {
    encoded = new bytes[](strategies.length);
    for (uint256 i = 0; i < strategies.length; i++) {
      encoded[i] = encodeStrategy(strategies[i]);
    }
  }

  function encodeStrategy(ILlamaRelativeStrategyBase.Config memory strategy)
    internal
    pure
    returns (bytes memory encoded)
  {
    encoded = abi.encode(strategy);
  }
}
